// =============================================================
// riscv_if.sv
// Interface wiring the UVM testbench to riscv_pipelined_hazards'
// actual debug ports (names match the RTL exactly).
// =============================================================
interface riscv_if(input logic clk);
    logic        rst;

    logic [31:0] debug_pc;
    logic [31:0] debug_alu_result_EX;
    logic [31:0] debug_rd_data_WB;
    logic [4:0]  debug_rd_addr_WB;
    logic        debug_reg_write_WB;
    logic        debug_mem_write_MEM;
    logic [31:0] debug_mem_addr_MEM;
    logic [31:0] debug_mem_wdata_MEM;

    clocking cb @(posedge clk);
        output rst;
        input  debug_pc, debug_alu_result_EX, debug_rd_data_WB,
               debug_rd_addr_WB, debug_reg_write_WB,
               debug_mem_write_MEM, debug_mem_addr_MEM, debug_mem_wdata_MEM;
    endclocking
endinterface
