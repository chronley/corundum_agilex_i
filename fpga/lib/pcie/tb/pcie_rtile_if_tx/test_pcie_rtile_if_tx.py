#!/usr/bin/env python
"""
R-Tile PCIe interface adapter (transmit) testbench
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
    from pcie_rtile import RtileTxBus, RtilePcieSink, RtileTxCreditSource
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    try:
        from pcie_rtile import RtileTxBus, RtilePcieSink, RtileTxCreditSource
    finally:
        del sys.path[0]

try:
    from pcie_if import PcieIfSource, PcieIfTxBus, PcieIfFrame
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    try:
        from pcie_if import PcieIfSource, PcieIfTxBus, PcieIfFrame
    finally:
        del sys.path[0]


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.msi_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_msi_wr_req_tlp"), dut.clk, dut.rst)
        self.cpl_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_cpl_tlp"), dut.clk, dut.rst)
        self.rd_req_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_rd_req_tlp"), dut.clk, dut.rst)
        self.wr_req_source = PcieIfSource(PcieIfTxBus.from_prefix(dut, "tx_wr_req_tlp"), dut.clk, dut.rst)
        self.sink = RtilePcieSink(RtileTxBus(dut), dut.clk, dut.rst)

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


async def run_test(dut):
    tb = TB(dut)

    await tb.cycle_reset()

    # start the TX credit model after reset to avoid racing the reset pulse
    tb.credit_source = RtileTxCreditSource(dut, dut.clk, infinite=True)

    # allow the credit init/update handshake to complete
    for _ in range(16):
        await RisingEdge(dut.clk)

    expected = {}
    senders = []

    # MSI writes (single dword) -> port 0
    for i in range(2):
        tlp = make_tlp(TlpType.MEM_WRITE, 0x10+i, 0x1000, bytearray(itertools.islice(itertools.cycle(range(256)), 4)))
        expected[tlp.tag] = tlp
        senders.append((tb.msi_source, tlp))

    # completions with data -> port 1
    for i in range(2):
        tlp = make_tlp(TlpType.CPL_DATA, 0x20+i, 0, bytearray(itertools.islice(itertools.cycle(range(256)), 32)))
        expected[tlp.tag] = tlp
        senders.append((tb.cpl_source, tlp))

    # header-only read requests -> port 2
    for i in range(2):
        tlp = make_tlp(TlpType.MEM_READ, 0x30+i, 0x2000, length=8)
        expected[tlp.tag] = tlp
        senders.append((tb.rd_req_source, tlp))

    # write requests with data -> port 3
    for i in range(2):
        tlp = make_tlp(TlpType.MEM_WRITE, 0x40+i, 0x3000, bytearray(itertools.islice(itertools.cycle(range(256)), 64)))
        expected[tlp.tag] = tlp
        senders.append((tb.wr_req_source, tlp))

    for source, tlp in senders:
        await source.send(PcieIfFrame.from_tlp(tlp))

    received = []
    for _ in range(len(senders)):
        rx = await tb.sink.recv()
        received.append(rx)

    assert len(received) == len(senders)

    for rx in received:
        exp = expected[rx.tag]
        assert rx == exp, f"TLP mismatch:\n  got {rx}\n  exp {exp}"

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("data_width", [1024])
def test_pcie_rtile_if_tx(request, data_width):
    dut = "pcie_rtile_if_tx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "pcie_rtile_fc_counter.v"),
        os.path.join(rtl_dir, "pcie_tlp_fc_count.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_raw.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_mux.v"),
    ]

    parameters = {}

    parameters['SEG_COUNT'] = 4
    parameters['SEG_DATA_WIDTH'] = 256
    parameters['SEG_HDR_WIDTH'] = 128
    parameters['SEG_PRFX_WIDTH'] = 32
    parameters['TLP_DATA_WIDTH'] = data_width
    parameters['TLP_STRB_WIDTH'] = data_width // 32
    parameters['TLP_HDR_WIDTH'] = 128
    parameters['TLP_SEG_COUNT'] = 1
    parameters['TX_SEQ_NUM_WIDTH'] = 6
    parameters['MAX_PAYLOAD_SIZE'] = 2

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
