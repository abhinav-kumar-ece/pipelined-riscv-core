// Instruction memory — stores program instructions for fetch stage
// =============================================================
// imem.v — Instruction memory for RV32I
// Read-only from the CPU's perspective, word-addressed via PC.
// Loaded at simulation start from a hex file using $readmemh.
// =============================================================
module imem #(
    parameter DEPTH = 256   // number of 32-bit words (1KB) -- plenty for test programs
)(
    input  wire [31:0] addr,     // byte address (from PC)
    output wire [31:0] instr     // instruction at that address
);

    reg [31:0] mem [0:DEPTH-1];

    // Loads mem[] from program.hex at time 0, before simulation runs.
    // Each line in program.hex is one 32-bit instruction in hex, e.g.:
    //   00500093
    //   00A00113
    // File must sit in the same directory Vivado runs simulation from
    // (Vivado copies simulation sources into its sim folder -- add
    // program.hex as a Simulation Source, same as a testbench, so it
    // gets copied alongside).
    initial begin
        $readmemh("C:/project/Pipelined_RISCV_Core/riscv_core/riscv_core.srcs/sim_1/imports/Downloads/program.hex", mem);
    end

    // PC gives a BYTE address, but each instruction is 4 bytes, so we
    // divide by 4 (i.e. drop the low 2 bits) to get the word index.
    assign instr = mem[addr[31:2]];

endmodule
