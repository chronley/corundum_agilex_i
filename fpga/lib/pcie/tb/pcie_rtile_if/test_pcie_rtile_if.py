#!/usr/bin/env python
"""
R-Tile PCIe interface adapter testbench
"""

import itertools
import logging
import os
import random
import sys

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.pcie.core.tlp import Tlp, TlpType

try:
    from pcie_rtile import (
        RtileRxBus, RtileTxBus, RtilePcieSource, RtilePcieSink,
        RtileTxCreditSource, RtileRxCreditSink,
    )
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    try:
        from pcie_rtile import (
            RtileRxBus, RtileTxBus, RtilePcieSource, RtilePcieSink,
            RtileTxCreditSource, RtileRxCreditSink,
        )
    finally:
        del sys.path[0]

try:
    from pcie_if import PcieIfSink, PcieIfSource, PcieIfRxBus, PcieIfTxBus, PcieIfFrame
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    try:
        from pcie_if import PcieIfSink, PcieIfSource, PcieIfRxBus, PcieIfTxBus, PcieIfFrame
    finally:
        del sys.path[0]


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.rx_source = RtilePcieSource(RtileRxBus(dut), dut.clk, dut.rst)
        self.rx_credit = RtileRxCreditSink(dut, dut.clk)
        self.tx_sink = RtilePcieSink(RtileTxBus(dut), dut.clk, dut.rst)

        self.req_sink = PcieIfSink(PcieIfRxBus.from_prefix(dut, "rx_req_tlp"), dut.clk, dut.rst)
        self.cpl_sink = PcieIfSink(PcieIfRxBus.from_prefix(dut, "rx_cpl_tlp"), dut.clk, dut.rst)

        self.msi_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_msi_wr_req_tlp"), dut.clk, dut.rst)
        self.cpl_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_cpl_tlp"), dut.clk, dut.rst)
        self.rd_req_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_rd_req_tlp"), dut.clk, dut.rst)
        self.wr_req_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_wr_req_tlp"), dut.clk, dut.rst)

    async def cycle_reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


def make_tlp(fmt_type, tag, addr, data=None, length=None):
    tlp = Tlp()
    tlp.fmt_type = fmt_type
    tlp.requester_id = 0
    tlp.tag = tag
    tlp.addr = addr
    if data is not None:
        tlp.set_data(data)
        tlp.length = len(data) // 4
        if fmt_type in (TlpType.CPL, TlpType.CPL_DATA, TlpType.CPL_LOCKED, TlpType.CPL_LOCKED_DATA):
            tlp.byte_count = len(data)
    else:
        tlp.length = length
    return tlp


async def run_test_rx(dut, seed=0):
    tb = TB(dut)

    await tb.cycle_reset()

    # wait for the RX credit init state machine to complete
    for _ in range(64):
        await RisingEdge(dut.clk)
        if int(dut.p0_rx_st_hcrdt_init_o.value) == 0 and int(dut.p0_rx_st_dcrdt_init_o.value) == 0:
            break
    assert int(dut.p0_rx_st_hcrdt_init_o.value) == 0
    assert int(dut.p0_rx_st_dcrdt_init_o.value) == 0

    rng = random.Random(seed)

    req_tlps = []
    cpl_tlps = []

    # random mix of posted (MEM_WRITE), non-posted (MEM_READ) and completions
    for i in range(16):
        kind = rng.randrange(3)
        tag = rng.randrange(256)
        addr = rng.randrange(0x100000)
        length = rng.randrange(1, 33)
        if kind == 0:
            data = bytearray(rng.getrandbits(8) for _ in range(length*4))
            req_tlps.append(make_tlp(TlpType.MEM_WRITE, tag, addr, data))
        elif kind == 1:
            req_tlps.append(make_tlp(TlpType.MEM_READ, tag, addr, length=length))
        else:
            data = bytearray(rng.getrandbits(8) for _ in range(length*4))
            cpl_tlps.append(make_tlp(TlpType.CPL_DATA, tag, 0, data))

    for tlp in req_tlps + cpl_tlps:
        tb.rx_source.send(tlp)

    for tlp in req_tlps:
        rx_frame = await tb.req_sink.recv()
        rx = rx_frame.to_tlp()
        assert rx == tlp, f"request mismatch:\n  got {rx}\n  exp {tlp}"

    for tlp in cpl_tlps:
        rx_frame = await tb.cpl_sink.recv()
        rx = rx_frame.to_tlp()
        assert rx == tlp, f"completion mismatch:\n  got {rx}\n  exp {tlp}"

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_tx(dut, seed=0):
    tb = TB(dut)

    await tb.cycle_reset()

    # start the TX credit model after reset to avoid racing the reset pulse
    tb.tx_credit = RtileTxCreditSource(dut, dut.clk, infinite=True)

    # allow the TX credit init/update handshake to complete
    for _ in range(64):
        await RisingEdge(dut.clk)

    rng = random.Random(seed)

    expected = {}
    senders = []

    # random mix from the four TX input ports
    for i in range(8):
        kind = rng.randrange(4)
        tag = 0x40 + i
        addr = rng.randrange(0x100000)
        length = rng.randrange(1, 17)
        if kind == 0:
            tlp = make_tlp(TlpType.MEM_WRITE, tag, addr, bytearray(rng.getrandbits(8) for _ in range(4)))
            senders.append((tb.msi_source, tlp))
        elif kind == 1:
            tlp = make_tlp(TlpType.CPL_DATA, tag, 0, bytearray(rng.getrandbits(8) for _ in range(length*4)))
            senders.append((tb.cpl_source, tlp))
        elif kind == 2:
            tlp = make_tlp(TlpType.MEM_READ, tag, addr, length=length)
            senders.append((tb.rd_req_source, tlp))
        else:
            tlp = make_tlp(TlpType.MEM_WRITE, tag, addr, bytearray(rng.getrandbits(8) for _ in range(length*4)))
            senders.append((tb.wr_req_source, tlp))
        expected[tlp.tag] = tlp

    for source, tlp in senders:
        await source.send(PcieIfFrame.from_tlp(tlp))

    received = []
    for _ in range(len(senders)):
        received.append(await tb.tx_sink.recv())

    assert len(received) == len(senders)

    for rx in received:
        exp = expected[rx.tag]
        assert rx == exp, f"TLP mismatch:\n  got {rx}\n  exp {exp}"

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_rx_credit(dut, seed=0):
    tb = TB(dut)

    await tb.cycle_reset()

    # verify finite credits (non-zero update counts) are advertised during init
    saw_nonzero_update = False
    for _ in range(64):
        await RisingEdge(dut.clk)
        if int(dut.p0_rx_st_hcrdt_update_o.value) and int(dut.p0_rx_st_hcrdt_update_cnt_o.value) != 0:
            saw_nonzero_update = True
        if int(dut.p0_rx_st_dcrdt_update_o.value) and int(dut.p0_rx_st_dcrdt_update_cnt_o.value) != 0:
            saw_nonzero_update = True
        if int(dut.p0_rx_st_hcrdt_init_o.value) == 0 and int(dut.p0_rx_st_dcrdt_init_o.value) == 0:
            break

    assert saw_nonzero_update, "finite RX credits were not advertised during initialization"
    assert int(dut.p0_rx_st_hcrdt_init_o.value) == 0
    assert int(dut.p0_rx_st_dcrdt_init_o.value) == 0

    # verify credits are returned as TLPs are drained
    rng = random.Random(seed)

    return_count = [0]

    async def monitor_return():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.p0_rx_st_hcrdt_init_o.value) == 0 and int(dut.p0_rx_st_dcrdt_init_o.value) == 0:
                if int(dut.p0_rx_st_hcrdt_update_o.value) or int(dut.p0_rx_st_dcrdt_update_o.value):
                    return_count[0] += 1

    cocotb.start_soon(monitor_return())

    req_tlps = []
    for i in range(8):
        length = rng.randrange(1, 17)
        data = bytearray(rng.getrandbits(8) for _ in range(length*4))
        req_tlps.append(make_tlp(TlpType.MEM_WRITE, rng.randrange(256), rng.randrange(0x100000), data))

    for tlp in req_tlps:
        tb.rx_source.send(tlp)

    for tlp in req_tlps:
        rx_frame = await tb.req_sink.recv()
        assert rx_frame.to_tlp() == tlp

    for _ in range(16):
        await RisingEdge(dut.clk)

    assert return_count[0] > 0, "RX credits were not returned after draining TLPs"

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_tx_credit(dut, seed=0):
    tb = TB(dut)

    await tb.cycle_reset()

    # finite credits for the TX credit model (not infinite)
    tb.tx_credit = RtileTxCreditSource(dut, dut.clk, infinite=False)

    # allow the TX credit init/update handshake to complete
    for _ in range(64):
        await RisingEdge(dut.clk)
        if int(dut.p0_tx_st_hcrdt_init_i.value) == 0 and int(dut.p0_tx_st_dcrdt_init_i.value) == 0:
            break

    rng = random.Random(seed)

    expected = {}
    senders = []

    for i in range(8):
        kind = rng.randrange(4)
        tag = 0x40 + i
        addr = rng.randrange(0x100000)
        length = rng.randrange(1, 17)
        if kind == 0:
            tlp = make_tlp(TlpType.MEM_WRITE, tag, addr, bytearray(rng.getrandbits(8) for _ in range(4)))
            senders.append((tb.msi_source, tlp))
        elif kind == 1:
            tlp = make_tlp(TlpType.CPL_DATA, tag, 0, bytearray(rng.getrandbits(8) for _ in range(length*4)))
            senders.append((tb.cpl_source, tlp))
        elif kind == 2:
            tlp = make_tlp(TlpType.MEM_READ, tag, addr, length=length)
            senders.append((tb.rd_req_source, tlp))
        else:
            tlp = make_tlp(TlpType.MEM_WRITE, tag, addr, bytearray(rng.getrandbits(8) for _ in range(length*4)))
            senders.append((tb.wr_req_source, tlp))
        expected[tlp.tag] = tlp

    for source, tlp in senders:
        await source.send(PcieIfFrame.from_tlp(tlp))

    received = []
    for _ in range(len(senders)):
        received.append(await tb.tx_sink.recv())

    assert len(received) == len(senders)

    for rx in received:
        exp = expected[rx.tag]
        assert rx == exp, f"TLP mismatch:\n  got {rx}\n  exp {exp}"

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


if cocotb.SIM_NAME:
    for test in [run_test_rx, run_test_tx, run_test_rx_credit, run_test_tx_credit]:
        factory = TestFactory(test)
        factory.add_option("seed", [0, 1, 2, 3])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("data_width", [1024])
def test_pcie_rtile_if(request, data_width):
    dut = "pcie_rtile_if"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, f"{dut}_rx.v"),
        os.path.join(rtl_dir, f"{dut}_tx.v"),
        os.path.join(rtl_dir, "pcie_rtile_fc_counter.v"),
        os.path.join(rtl_dir, "pcie_tlp_demux.v"),
        os.path.join(rtl_dir, "pcie_tlp_fc_count.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_raw.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_mux.v"),
    ]

    parameters = {}

    parameters['SEG_COUNT'] = 4
    parameters['SEG_DATA_WIDTH'] = 256
    parameters['SEG_EMPTY_WIDTH'] = 3
    parameters['SEG_HDR_WIDTH'] = 128
    parameters['SEG_PRFX_WIDTH'] = 32
    parameters['TLP_DATA_WIDTH'] = data_width
    parameters['TLP_STRB_WIDTH'] = data_width // 32
    parameters['TLP_HDR_WIDTH'] = 128
    parameters['TLP_SEG_COUNT'] = 1
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['MAX_PAYLOAD_SIZE'] = 2
    parameters['IO_BAR_INDEX'] = 3

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
