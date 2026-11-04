TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = pcie_rtile_if
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/$(DUT)_rx.v
VERILOG_SOURCES += ../../rtl/$(DUT)_tx.v
VERILOG_SOURCES += ../../rtl/pcie_rtile_fc_counter.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_demux.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_fc_count.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_fifo.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_fifo_raw.v
VERILOG_SOURCES += ../../rtl/pcie_tlp_fifo_mux.v

# module parameters
export PARAM_SEG_COUNT := 4
export PARAM_SEG_DATA_WIDTH := 256
export PARAM_SEG_EMPTY_WIDTH := 3
export PARAM_SEG_HDR_WIDTH := 128
export PARAM_SEG_PRFX_WIDTH := 32
export PARAM_TLP_DATA_WIDTH := 1024
export PARAM_TLP_STRB_WIDTH := 32
export PARAM_TLP_HDR_WIDTH := 128
export PARAM_TLP_SEG_COUNT := 1
export PARAM_TX_SEQ_NUM_WIDTH := 6
export PARAM_MAX_PAYLOAD_SIZE := 2
export PARAM_IO_BAR_INDEX := 3

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-P $(TOPLEVEL).$(subst PARAM_,,$(v))=$($(v)))

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-G$(subst PARAM_,,$(v))=$($(v)))

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
