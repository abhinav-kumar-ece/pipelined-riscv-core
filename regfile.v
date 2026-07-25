// Register file — 32 x 32-bit registers for RV32I
   // Two read ports, one write port, x0 hardwired to zero
// =============================================================
// regfile.v — 32 x 32-bit register file for RV32I
// 2 combinational read ports, 1 synchronous write port.
// x0 is hardwired to zero.
// =============================================================
module regfile (
    input  wire        clk,
    input  wire        we,          // write enable
    input  wire [4:0]  rs1_addr,    // read address 1
    input  wire [4:0]  rs2_addr,    // read address 2
    input  wire [4:0]  rd_addr,     // write address
    input  wire [31:0] rd_data,     // data to write
    output wire [31:0] rs1_data,    // read data 1
    output wire [31:0] rs2_data     // read data 2
);

    // 32 registers, each 32 bits wide
    reg [31:0] regfile [0:31];

    integer i;
    initial begin
        // Only needed for simulation cleanliness (avoids 'x' in waveforms).
        // Real hardware doesn't reset to zero unless you add an explicit
        // reset — we'll revisit this when we build the full core.
        for (i = 0; i < 32; i = i + 1)
            regfile[i] = 32'b0;
    end

    // ---- Synchronous write ----
    always @(posedge clk) begin
        if (we && rd_addr != 5'd0) begin  // x0 is never writable
            regfile[rd_addr] <= rd_data;
        end
    end

    // ---- Combinational reads ----
    // x0 always reads as zero, even though regfile[0] is also kept at
    // zero above -- this extra guard makes the "x0 is always zero" rule
    // explicit and bug-proof regardless of what's in the array.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'b0 : regfile[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'b0 : regfile[rs2_addr];

endmodule
