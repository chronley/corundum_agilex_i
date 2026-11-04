#!/usr/bin/env python
"""
R-Tile PCIe interface adapter testbench
"""

import itertools
import logging
import os
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


async def run_test_rx(dut):
    tb = TB(dut)

    await tb.cycle_reset()

    # wait for the RX credit init state machine to complete
    for _ in range(32):
        await RisingEdge(dut.clk)
    assert int(dut.p0_rx_st_hcrdt_init_o.value) == 0
    assert int(dut.p0_rx_st_dcrdt_init_o.value) == 0

    req_tlps = []
    cpl_tlps = []

    for i in range(4):
        data = bytearray(itertools.islice(itertools.cycle(range(256)), 64*(i+1)))
        req_tlps.append(make_tlp(TlpType.MEM_WRITE, 0x10+i, 0x1000 + 0x100*i, data))

    for i in range(4):
        req_tlps.append(make_tlp(TlpType.MEM_READ, 0x20+i, 0x2000 + 0x10*i, length=8))

    for i in range(4):
        data = bytearray(itertools.islice(itertools.cycle(range(256)), 32*(i+1)))
        cpl_tlps.append(make_tlp(TlpType.CPL_DATA, 0x30+i, 0, data))

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
async def run_test_tx(dut):
    tb = TB(dut)

    await tb.cycle_reset()

    # start the TX credit model after reset to avoid racing the reset pulse
    tb.tx_credit = RtileTxCreditSource(dut, dut.clk, infinite=True)

    # allow the TX credit init/update handshake to complete
    for _ in range(32):
        await RisingEdge(dut.clk)

    expected = {}
    senders = []

    for i in range(2):
        tlp = make_tlp(TlpType.MEM_WRITE, 0x40+i, 0x1000, bytearray(itertools.islice(itertools.cycle(range(256)), 4)))
        expected[tlp.tag] = tlp
        senders.append((tb.msi_source, tlp))

    for i in range(2):
        tlp = make_tlp(TlpType.CPL_DATA, 0x50+i, 0, bytearray(itertools.islice(itertools.cycle(range(256)), 32)))
        expected[tlp.tag] = tlp
        senders.append((tb.cpl_source, tlp))

    for i in range(2):
        tlp = make_tlp(TlpType.MEM_READ, 0x60+i, 0x2000, length=8)
        expected[tlp.tag] = tlp
        senders.append((tb.rd_req_source, tlp))

    for i in range(2):
        tlp = make_tlp(TlpType.MEM_WRITE, 0x70+i, 0x3000, bytearray(itertools.islice(itertools.cycle(range(256)), 64)))
        expected[tlp.tag] = tlp
        senders.append((tb.wr_req_source, tlp))

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
    factory = TestFactory(run_test_rx)
    factory.generate_tests()

    factory = TestFactory(run_test_tx)
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
