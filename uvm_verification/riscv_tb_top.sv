// =============================================================
// riscv_tb_top.sv
// Testbench top: instantiates the DUT, the interface, and
// kicks off UVM. This is the "harness" everything else attaches to.
// =============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;

`include "riscv_seq_item.sv"
`include "riscv_result_item.sv"
`include "riscv_sequences.sv"
`include "riscv_if.sv"
`include "riscv_driver.sv"
`include "riscv_monitor.sv"
`include "riscv_scoreboard.sv"
`include "riscv_agent.sv"
`include "riscv_env.sv"
`include "riscv_test.sv"

module riscv_top;

    logic clk = 0;
    always #5 clk = ~clk; // 100MHz, matches your LibreLane clock target

    riscv_if vif(clk);

    // DUT instantiation -- matches driver's hierarchical backdoor path
    riscv_pipelined_hazards dut (
        .clk(clk),
        .rst(vif.rst),
        .debug_pc(vif.debug_pc),
        .debug_alu_result_EX(vif.debug_alu_result_EX),
        .debug_rd_data_WB(vif.debug_rd_data_WB),
        .debug_rd_addr_WB(vif.debug_rd_addr_WB),
        .debug_reg_write_WB(vif.debug_reg_write_WB),
        .debug_mem_write_MEM(vif.debug_mem_write_MEM),
        .debug_mem_addr_MEM(vif.debug_mem_addr_MEM),
        .debug_mem_wdata_MEM(vif.debug_mem_wdata_MEM)
    );

    initial begin
        uvm_config_db#(virtual riscv_if)::set(null, "*", "vif", vif);
        run_test("riscv_hazard_test");
    end

endmodule
