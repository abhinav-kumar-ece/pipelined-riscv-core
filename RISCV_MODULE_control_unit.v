// =============================================================
// control_unit.v — decodes an RV32I instruction into control
// signals for the single-cycle datapath.
//
// Two-part decoder (standard textbook structure):
//   1. Main decoder: opcode -> most control signals + alu_op
//   2. ALU decoder:  alu_op + funct3 + funct7[5] -> exact alu_ctrl
// =============================================================
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire        funct7_5,     // bit 30 of the instruction

    output reg         reg_write,
    output reg  [2:0]  imm_src,      // which immediate format: 0=I 1=S 2=B 3=U 4=J
    output reg  [1:0]  alu_src_a,    // ALU operand A source: 00=rs1 01=PC 10=zero
    output reg         alu_src_b,    // ALU operand B source: 0=rs2  1=immediate
    output reg         mem_write,
    output reg  [1:0]  result_src,   // writeback source: 00=ALU 01=mem_data 10=PC+4
    output reg         branch,
    output reg         jump,
    output reg  [3:0]  alu_ctrl      // matches the encoding used in alu.v
);

    // ---- Opcodes ----
    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_ITYPE  = 7'b0010011;  // ADDI, ANDI, etc.
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;

    // ---- ALU control codes (must match alu.v exactly) ----
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    reg [1:0] alu_op; // intermediate: tells the ALU decoder how much freedom it has

    // ---- Part 1: Main decoder ----
    always @(*) begin
        // Safe defaults so every path is covered (avoids accidental latches)
        reg_write  = 1'b0;
        imm_src    = 3'b000;
        alu_src_a  = 2'b00;
        alu_src_b  = 1'b0;
        mem_write  = 1'b0;
        result_src = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            OP_RTYPE: begin
                reg_write  = 1'b1;
                alu_src_a  = 2'b00; // rs1
                alu_src_b  = 1'b0;  // rs2
                alu_op     = 2'b10; // let ALU decoder read funct3/funct7
            end

            OP_ITYPE: begin // ADDI, ANDI, SLLI, etc.
                reg_write  = 1'b1;
                imm_src    = 3'b000; // I-type
                alu_src_a  = 2'b00;
                alu_src_b  = 1'b1;  // immediate
                alu_op     = 2'b10;
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                imm_src    = 3'b000; // I-type
                alu_src_a  = 2'b00;
                alu_src_b  = 1'b1;  // immediate (address offset)
                result_src = 2'b01; // writeback = memory data
                alu_op     = 2'b00; // ALU just does an ADD for the address
            end

            OP_STORE: begin
                imm_src    = 3'b001; // S-type
                alu_src_a  = 2'b00;
                alu_src_b  = 1'b1;
                mem_write  = 1'b1;
                alu_op     = 2'b00; // ADD for address
            end

            OP_BRANCH: begin
                imm_src    = 3'b010; // B-type
                alu_src_a  = 2'b00;
                alu_src_b  = 1'b0;  // compare rs1 vs rs2
                branch     = 1'b1;
                alu_op     = 2'b01; // ALU does a SUB so datapath can check equality/sign
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                imm_src    = 3'b100; // J-type
                alu_src_a  = 2'b01;  // PC
                alu_src_b  = 1'b1;   // immediate
                result_src = 2'b10;  // writeback = PC+4 (return address)
                jump       = 1'b1;
                alu_op     = 2'b00;  // ADD -> target = PC + imm
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                imm_src    = 3'b000; // I-type
                alu_src_a  = 2'b00;  // rs1
                alu_src_b  = 1'b1;   // immediate
                result_src = 2'b10;  // writeback = PC+4
                jump       = 1'b1;
                alu_op     = 2'b00;  // ADD -> target = rs1 + imm
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                imm_src    = 3'b011; // U-type
                alu_src_a  = 2'b10;  // zero
                alu_src_b  = 1'b1;   // immediate
                alu_op     = 2'b00;  // ADD -> result = 0 + imm = imm
            end

            OP_AUIPC: begin
                reg_write  = 1'b1;
                imm_src    = 3'b011; // U-type
                alu_src_a  = 2'b01;  // PC
                alu_src_b  = 1'b1;   // immediate
                alu_op     = 2'b00;  // ADD -> result = PC + imm
            end

            default: begin
                // Unrecognized opcode -- all defaults above already
                // make this a safe no-op (no writes, no side effects).
            end
        endcase
    end

    // ---- Part 2: ALU decoder ----
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = ALU_ADD; // loads, stores, jumps, LUI, AUIPC
            2'b01: begin
                // Branches: which ALU op depends on which branch instruction.
                // BEQ/BNE only need equality -> SUB (checked via zero flag).
                // BLT/BGE need a signed less-than result.
                // BLTU/BGEU need an unsigned less-than result.
                case (funct3)
                    3'b000, 3'b001: alu_ctrl = ALU_SUB;  // BEQ, BNE
                    3'b100, 3'b101: alu_ctrl = ALU_SLT;  // BLT, BGE
                    3'b110, 3'b111: alu_ctrl = ALU_SLTU; // BLTU, BGEU
                    default:        alu_ctrl = ALU_SUB;
                endcase
            end
            2'b10: begin
                // R-type or I-type ALU op: decode via funct3
                // (funct7_5 only distinguishes ADD/SUB and SRL/SRA)
                case (funct3)
                    3'b000: alu_ctrl = (funct7_5 && opcode[5]) ? ALU_SUB : ALU_ADD; // opcode[5]=1 only for R-type
                    3'b001: alu_ctrl = ALU_SLL;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b101: alu_ctrl = funct7_5 ? ALU_SRA : ALU_SRL;
                    3'b110: alu_ctrl = ALU_OR;
                    3'b111: alu_ctrl = ALU_AND;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end
            default: alu_ctrl = ALU_ADD;
        endcase
    end

endmodule
