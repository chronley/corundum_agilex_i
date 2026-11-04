"""
R-Tile Avalon-ST PCIe interface bus functional model (BFM) for cocotb.
"""

import logging
import struct

import cocotb
from cocotb.queue import Queue
from cocotb.triggers import RisingEdge

from cocotbext.pcie.core.tlp import Tlp


SEG_DWORDS = 8  # 256-bit segment holds 8 dwords


def _sig_int(sig, default=0):
    try:
        return int(sig.value)
    except (ValueError, TypeError):
        return default


class RtileRxSeg:
    def __init__(self, entity, n):
        p = f"p0_rx_st{n}_"
        self.data = getattr(entity, p + "data_i")
        self.hdr = getattr(entity, p + "hdr_i")
        self.prefix = getattr(entity, p + "prefix_i")
        self.sop = getattr(entity, p + "sop_i")
        self.eop = getattr(entity, p + "eop_i")
        self.dvalid = getattr(entity, p + "dvalid_i")
        self.hvalid = getattr(entity, p + "hvalid_i")
        self.pvalid = getattr(entity, p + "pvalid_i")
        self.bar = getattr(entity, p + "bar_i")
        self.empty = getattr(entity, p + "empty_i")
        self.vfactive = getattr(entity, p + "vfactive_i")
        self.vfnum = getattr(entity, p + "vfnum_i")
        self.pfnum = getattr(entity, p + "pfnum_i")


class RtileRxBus:
    def __init__(self, entity, seg_count=4):
        self.seg_count = seg_count
        self.seg = [RtileRxSeg(entity, n) for n in range(seg_count)]
        self.ready = entity.p0_rx_st_ready_o
        self.seg_width = len(self.seg[0].data)
        self.seg_dwords = self.seg_width // 32


class RtileTxSeg:
    def __init__(self, entity, n):
        p = f"p0_tx_st{n}_"
        self.data = getattr(entity, p + "data_o")
        self.hdr = getattr(entity, p + "hdr_o")
        self.prefix = getattr(entity, p + "prefix_o")
        self.sop = getattr(entity, p + "sop_o")
        self.eop = getattr(entity, p + "eop_o")
        self.dvalid = getattr(entity, p + "dvalid_o")
        self.hvalid = getattr(entity, p + "hvalid_o")
        self.pvalid = getattr(entity, p + "pvalid_o")


class RtileTxBus:
    def __init__(self, entity, seg_count=4):
        self.seg_count = seg_count
        self.seg = [RtileTxSeg(entity, n) for n in range(seg_count)]
        self.ready = entity.p0_tx_st_ready_i
        self.seg_width = len(self.seg[0].data)
        self.seg_dwords = self.seg_width // 32


def _tlp_hdr(tlp):
    return int.from_bytes(tlp.pack_header().ljust(16, b'\x00'), 'big')


def _tlp_dwords(tlp):
    data = tlp.get_data()
    if not data:
        return []
    return list(struct.unpack('<%dL' % (len(data)//4), data))


class RtilePcieSource:
    """Drives the R-Tile RX AVST interface from a queue of Tlp objects."""

    def __init__(self, bus, clock, reset=None):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        self.log = logging.getLogger("cocotb.rtile.rx_source")
        self.queue = Queue()
        self.pause = False
        self.bar = 0
        self.pfnum = 0
        self.queue_occupancy = 0
        cocotb.start_soon(self._run())

    def send(self, tlp):
        self.queue.put_nowait(tlp)
        self.queue_occupancy += 1

    def empty(self):
        return self.queue.empty()

    def _idle(self):
        for seg in self.bus.seg:
            seg.data.value = 0
            seg.hdr.value = 0
            seg.prefix.value = 0
            seg.sop.value = 0
            seg.eop.value = 0
            seg.dvalid.value = 0
            seg.hvalid.value = 0
            seg.pvalid.value = 0
            seg.bar.value = 0
            seg.empty.value = 0
            seg.vfactive.value = 0
            seg.vfnum.value = 0
            seg.pfnum.value = 0

    async def _run(self):
        while True:
            self._idle()
            await RisingEdge(self.clock)

            if self.queue.empty() or self.pause:
                continue

            tlp = self.queue.get_nowait()
            self.queue_occupancy -= 1
            self.log.info("TX frame: %r", tlp)

            hdr = _tlp_hdr(tlp)
            dwords = _tlp_dwords(tlp)
            chunks = [dwords[i:i+SEG_DWORDS] for i in range(0, len(dwords), SEG_DWORDS)]
            if not chunks:
                chunks = [[]]  # header-only TLP

            ci = 0
            while ci < len(chunks):
                for k in range(self.bus.seg_count):
                    if ci >= len(chunks):
                        break
                    chunk = chunks[ci]
                    seg = self.bus.seg[k]

                    if ci == 0:
                        seg.hdr.value = hdr
                        seg.sop.value = 1
                        seg.hvalid.value = 1
                        seg.bar.value = self.bar
                        seg.pfnum.value = self.pfnum

                    if ci == len(chunks) - 1:
                        seg.eop.value = 1
                        seg.empty.value = SEG_DWORDS - len(chunk) if chunk else 0

                    if chunk:
                        v = 0
                        for i, dw in enumerate(chunk):
                            v |= dw << (32*i)
                        seg.data.value = v
                        seg.dvalid.value = 1

                    ci += 1

                await RisingEdge(self.clock)
                self._idle()
class RtilePcieSink:
    """Monitors the R-Tile TX AVST interface and reassembles Tlp objects."""

    def __init__(self, bus, clock, reset=None):
        self.bus = bus
        self.clock = clock
        self.reset = reset
        self.log = logging.getLogger("cocotb.rtile.tx_sink")
        self.queue = Queue()
        self.pause = False
        self.queue_occupancy = 0
        self.bus.ready.setimmediatevalue(0)
        cocotb.start_soon(self._run())

    def recv(self):
        return self.queue.get()

    def empty(self):
        return self.queue.empty()

    async def _run(self):
        frame = None
        dword_count = 0
        hdr = 0

        while True:
            # drive ready for the upcoming clock edge
            ready = 1 if not self.pause else 0
            self.bus.ready.value = ready

            await RisingEdge(self.clock)

            # sample the values present at this edge
            for seg in self.bus.seg:
                if not ready or not seg.dvalid.value:
                    continue

                if seg.sop.value:
                    assert frame is None, "framing error: sop asserted in frame"
                    hdr = int(seg.hdr.value)
                    frame = Tlp.unpack_header(hdr.to_bytes(16, 'big'))
                    if hdr & (1 << 126):
                        dword_count = (hdr >> 96) & 0x3ff
                        if dword_count == 0:
                            dword_count = 1024
                    else:
                        dword_count = 0

                assert frame is not None, "framing error: data transferred outside of frame"

                data = int(seg.data.value)
                for k in range(self.bus.seg_dwords):
                    if dword_count <= 0:
                        break
                    frame.data.extend(struct.pack('<L', (data >> (32*k)) & 0xffffffff))
                    dword_count -= 1

                if seg.eop.value:
                    assert dword_count == 0, "framing error: incorrect length or early eop"
                    self.log.info("RX frame: %r", frame)
                    self.queue.put_nowait(frame)
                    self.queue_occupancy += 1
                    frame = None


class RtileTxCreditSource:
    """IP-side model that drives the R-Tile TX credit init/update interface."""

    def __init__(self, dut, clock, infinite=True, reset=None):
        self.dut = dut
        self.clock = clock
        self.infinite = infinite
        self.reset = reset
        dut.p0_tx_st_hcrdt_init_i.setimmediatevalue(0)
        dut.p0_tx_st_hcrdt_update_i.setimmediatevalue(0)
        dut.p0_tx_st_hcrdt_update_cnt_i.setimmediatevalue(0)
        dut.p0_tx_st_dcrdt_init_i.setimmediatevalue(0)
        dut.p0_tx_st_dcrdt_update_i.setimmediatevalue(0)
        dut.p0_tx_st_dcrdt_update_cnt_i.setimmediatevalue(0)
        cocotb.start_soon(self._run())

    async def _run(self):
        d = self.dut

        # wait for reset deassertion before starting the credit handshake
        if self.reset is not None:
            while self.reset.value:
                await RisingEdge(self.clock)

        # credit init phase
        d.p0_tx_st_hcrdt_init_i.value = 0b111
        d.p0_tx_st_dcrdt_init_i.value = 0b111

        # wait for the application to acknowledge init
        while True:
            ack_h = _sig_int(d.p0_tx_st_hcrdt_init_ack_o)
            ack_d = _sig_int(d.p0_tx_st_dcrdt_init_ack_o)
            if ack_h == 0b111 and ack_d == 0b111:
                break
            await RisingEdge(self.clock)

        if self.infinite:
            # advertise infinite credits: one update pulse with count = 0
            d.p0_tx_st_hcrdt_update_i.value = 0b111
            d.p0_tx_st_dcrdt_update_i.value = 0b111
            d.p0_tx_st_hcrdt_update_cnt_i.value = 0
            d.p0_tx_st_dcrdt_update_cnt_i.value = 0
            await RisingEdge(self.clock)
            d.p0_tx_st_hcrdt_update_i.value = 0
            d.p0_tx_st_dcrdt_update_i.value = 0
        else:
            # finite credits: 256 header / 4096 data credits in chunks
            for _ in range(16):
                d.p0_tx_st_hcrdt_update_i.value = 0b111
                d.p0_tx_st_hcrdt_update_cnt_i.value = (3 << 0) | (3 << 2) | (3 << 4)
                d.p0_tx_st_dcrdt_update_i.value = 0b111
                d.p0_tx_st_dcrdt_update_cnt_i.value = (15 << 0) | (15 << 4) | (15 << 8)
                await RisingEdge(self.clock)
            d.p0_tx_st_hcrdt_update_i.value = 0
            d.p0_tx_st_dcrdt_update_i.value = 0

        # two cycle separation between update and init deassertion
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        d.p0_tx_st_hcrdt_init_i.value = 0
        d.p0_tx_st_dcrdt_init_i.value = 0


class RtileRxCreditSink:
    """IP-side model that acknowledges the application's RX credit init."""

    def __init__(self, dut, clock):
        self.dut = dut
        self.clock = clock
        dut.p0_rx_st_hcrdt_init_ack_i.setimmediatevalue(0)
        dut.p0_rx_st_dcrdt_init_ack_i.setimmediatevalue(0)
        cocotb.start_soon(self._run())

    async def _run(self):
        d = self.dut
        while True:
            # ack while init is asserted
            d.p0_rx_st_hcrdt_init_ack_i.value = _sig_int(d.p0_rx_st_hcrdt_init_o)
            d.p0_rx_st_dcrdt_init_ack_i.value = _sig_int(d.p0_rx_st_dcrdt_init_o)
            await RisingEdge(self.clock)
