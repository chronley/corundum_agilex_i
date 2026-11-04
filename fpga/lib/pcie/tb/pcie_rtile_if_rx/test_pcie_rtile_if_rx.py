#!/usr/bin/env python
"""
R-Tile PCIe interface adapter (receive) testbench
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
    from pcie_rtile import RtileRxBus, RtilePcieSource
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    try:
        from pcie_rtile import RtileRxBus, RtilePcieSource
    finally:
        del sys.path[0]

try:
    from pcie_if import PcieIfSink, PcieIfRxBus
except ImportError:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    try:
        from pcie_if import PcieIfSink, PcieIfRxBus
    finally:
        del sys.path[0]


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())

        self.source = RtilePcieSource(RtileRxBus(dut), dut.clk, dut.rst)
        self.req_sink = PcieIfSink(PcieIfRxBus.from_prefix(dut, "rx_req_tlp"), dut.clk, dut.rst)
        self.cpl_sink = PcieIfSink(PcieIfRxBus.from_prefix(dut, "rx_cpl_tlp"), dut.clk, dut.rst)

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


def make_mem_write(tag, addr, data):
    tlp = Tlp()
    tlp.fmt_type = TlpType.MEM_WRITE
    tlp.requester_id = 0
    tlp.tag = tag
    tlp.addr = addr
    tlp.set_data(data)
    tlp.length = len(data) // 4
    return tlp


def make_mem_read(tag, addr, length):
    tlp = Tlp()
    tlp.fmt_type = TlpType.MEM_READ
    tlp.requester_id = 0
    tlp.tag = tag
    tlp.addr = addr
    tlp.length = length
    return tlp


def make_cpl_data(tag, cpl_id, data):
    tlp = Tlp()
    tlp.fmt_type = TlpType.CPL_DATA
    tlp.completer_id = cpl_id
    tlp.requester_id = 0
    tlp.tag = tag
    tlp.set_data(data)
    tlp.length = len(data) // 4
    tlp.byte_count = len(data)
    return tlp


async def run_test(dut):
    tb = TB(dut)

    await tb.cycle_reset()

    req_tlps = []
    cpl_tlps = []

    # posted writes with data -> request port
    for i in range(4):
        data = bytearray(itertools.islice(itertools.cycle(range(256)), 64*(i+1)))
        req_tlps.append(make_mem_write(i, 0x1000 + 0x100*i, data))

    # header-only memory reads -> request port (exercises dvalid|hvalid decode)
    for i in range(4):
        req_tlps.append(make_mem_read(i, 0x2000 + 0x10*i, 8))

    # completions with data -> completion port
    for i in range(4):
        data = bytearray(itertools.islice(itertools.cycle(range(256)), 32*(i+1)))
        cpl_tlps.append(make_cpl_data(i, 0, data))

    for tlp in req_tlps + cpl_tlps:
        tb.source.send(tlp)

    for tlp in req_tlps:
        rx_frame = await tb.req_sink.recv()
        rx = rx_frame.to_tlp()
        assert rx == tlp, f"request mismatch:\n  got {rx}\n  exp {tlp}"

    for tlp in cpl_tlps:
        rx_frame = await tb.cpl_sink.recv()
        rx = rx_frame.to_tlp()
        assert rx == tlp, f"completion mismatch:\n  got {rx}\n  exp {tlp}"

    assert tb.req_sink.empty()
    assert tb.cpl_sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


@pytest.mark.parametrize("data_width", [1024])
def test_pcie_rtile_if_rx(request, data_width):
    dut = "pcie_rtile_if_rx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "pcie_tlp_demux.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo.v"),
        os.path.join(rtl_dir, "pcie_tlp_fifo_raw.v"),
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
