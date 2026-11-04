module iverilog_dump();
initial begin
    $dumpfile("pcie_ptile_if_rx.fst");
    $dumpvars(0, pcie_ptile_if_rx);
end
endmodule
