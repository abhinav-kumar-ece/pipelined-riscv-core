// =============================================================
// imm_gen.v — Immediate generator for RV32I
// Extracts and sign-extends the immediate field from an
// instruction, based on which format it uses (from imm_src,
// produced by control_unit.v).
//
// imm_src: 000=I  001=S  010=B  011=U  100=J
// =============================================================
module imm_gen (
    input  wire [31:0] instr,
    input  wire [2:0]  imm_src,
    output reg  [31:0] imm_out
);

    always @(*) begin
        case (imm_src)
            // I-type: bits [31:20] are the 12-bit immediate, sign-extended.
            // Used by: ADDI/ANDI/etc, loads, JALR
            3'b000: imm_out = {{20{instr[31]}}, instr[31:20]};

            // S-type: immediate is SPLIT across two fields so rs1/rs2
            // stay in the same bit positions as R-type. Bits [11:5] and [4:0].
            // Used by: stores
            3'b001: imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: immediate is scattered AND has an implicit bit 0 = 0
            // (branch targets are always 2-byte aligned, so that bit isn't
            // stored -- it's always zero). Notice bit 7 holds imm[11],
            // and bit 31 holds imm[12] (the sign bit) -- this ordering
            // lets bit 31 double as the sign bit for hardware simplicity.
            // Used by: BEQ/BNE/BLT/etc
            3'b010: imm_out = {{19{instr[31]}}, instr[31], instr[7],
                                instr[30:25], instr[11:8], 1'b0};

            // U-type: immediate occupies the upper 20 bits, lower 12 are
            // zero (no sign extension needed -- it's already 32 bits, and
            // by RISC-V convention the "sign" here is just whatever bit 31 is).
            // Used by: LUI, AUIPC
            3'b011: imm_out = {instr[31:12], 12'b0};

            // J-type: same "implicit zero LSB" trick as branches, but for
            // a 20-bit immediate with an even more scrambled bit order
            // (this scrambling exists purely to minimize hardware -- it
            // maximizes bit overlap with the other formats).
            // Used by: JAL
            3'b100: imm_out = {{11{instr[31]}}, instr[31], instr[19:12],
                                instr[20], instr[30:21], 1'b0};

            default: imm_out = 32'b0;
        endcase
    end

endmodule
