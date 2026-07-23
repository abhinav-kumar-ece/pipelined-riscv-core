// =============================================================
// alu.v — 32-bit ALU for RV32I
// Combinational: output changes immediately when inputs change,
// no clock involved.
// =============================================================
module alu (
    input  wire [31:0] a,          // operand 1 (rs1)
    input  wire [31:0] b,          // operand 2 (rs2, or immediate)
    input  wire [3:0]  alu_ctrl,   // which operation to perform
    output reg  [31:0] result,     // the answer
    output wire         zero        // 1 if result == 0 (used for branches later)
);

    // ALU control encoding (arbitrary, but we'll reuse these exact
    // codes in the control unit later, so write them down)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;  // shift left logical
    localparam ALU_SRL  = 4'b0110;  // shift right logical
    localparam ALU_SRA  = 4'b0111;  // shift right arithmetic
    localparam ALU_SLT  = 4'b1000;  // set less than (signed)
    localparam ALU_SLTU = 4'b1001;  // set less than (unsigned)

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            // RISC-V shift amount is the low 5 bits of b (shamt)
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            default:  result = 32'hDEAD_BEEF; // easy-to-spot bug marker
        endcase
    end

    assign zero = (result == 32'b0);

endmodule
