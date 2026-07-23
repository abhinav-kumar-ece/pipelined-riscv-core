// =============================================================
// riscv_pipelined_hazards.v — 5-stage pipelined RV32I CPU
// WITH forwarding and hazard detection.
//
// Builds on the verified pipeline skeleton by adding:
//   1. FORWARDING (bypassing): EX-stage ALU operands can be
//      sourced from the EX/MEM or MEM/WB pipeline registers
//      instead of the (possibly stale) ID/EX register file read.
//      This handles back-to-back ALU dependencies with zero
//      stall cycles.
//   2. LOAD-USE HAZARD DETECTION: the one case forwarding cannot
//      fix, since a load's data isn't available until the END of
//      its MEM stage. When the instruction in EX is a load and
//      the instruction right behind it in ID needs that result,
//      the pipeline stalls (freezes PC + IF/ID, bubbles ID/EX)
//      for exactly one cycle.
//   3. CONTROL HAZARD FLUSH: when a branch/jump resolves as
//      taken in EX, the two instructions already speculatively
//      fetched behind it (sitting in IF and ID) are squashed.
// =============================================================
module riscv_pipelined_hazards (
    input wire clk,
    input wire rst,
    output wire [31:0] debug_pc,
    output wire [31:0] debug_alu_result_EX,
    output wire [31:0] debug_rd_data_WB
);

    // ---------------------- Hazard control signals ------------
    wire stall; // load-use hazard: freeze PC/IF-ID, bubble ID/EX
    wire flush; // branch/jump taken: squash IF/ID and ID/EX

    // ---------------------- IF STAGE ------------------------
    reg  [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4_IF;

    always @(posedge clk or posedge rst) begin
        if (rst)        pc <= 32'b0;
        else if (stall) pc <= pc;          // hold: load-use hazard
        else            pc <= pc_next;
    end

    assign pc_plus4_IF = pc + 32'd4;

    wire [31:0] instr_IF;
    imem imem_inst (
        .addr(pc),
        .instr(instr_IF)
    );

    // ---- IF/ID pipeline register ----
    reg [31:0] instr_ID, pc_ID, pc_plus4_ID;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            instr_ID <= 32'b0; pc_ID <= 32'b0; pc_plus4_ID <= 32'b0;
        end else if (flush) begin
            // squash the wrongly-fetched instruction sitting in IF
            instr_ID <= 32'b0; pc_ID <= 32'b0; pc_plus4_ID <= 32'b0;
        end else if (stall) begin
            // hold: keep the same (not-yet-ready-to-proceed) instruction
            instr_ID <= instr_ID; pc_ID <= pc_ID; pc_plus4_ID <= pc_plus4_ID;
        end else begin
            instr_ID <= instr_IF; pc_ID <= pc; pc_plus4_ID <= pc_plus4_IF;
        end
    end

    // ---------------------- ID STAGE ------------------------
    wire [6:0] opcode_ID   = instr_ID[6:0];
    wire [4:0] rd_addr_ID  = instr_ID[11:7];
    wire [2:0] funct3_ID   = instr_ID[14:12];
    wire [4:0] rs1_addr_ID = instr_ID[19:15];
    wire [4:0] rs2_addr_ID = instr_ID[24:20];
    wire       funct7_5_ID = instr_ID[30];

    wire        reg_write_ID, alu_src_b_ID, mem_write_ID, branch_ID, jump_ID;
    wire [2:0]  imm_src_ID;
    wire [1:0]  alu_src_a_ID, result_src_ID;
    wire [3:0]  alu_ctrl_ID;

    control_unit ctrl_inst (
        .opcode(opcode_ID), .funct3(funct3_ID), .funct7_5(funct7_5_ID),
        .reg_write(reg_write_ID), .imm_src(imm_src_ID), .alu_src_a(alu_src_a_ID),
        .alu_src_b(alu_src_b_ID), .mem_write(mem_write_ID), .result_src(result_src_ID),
        .branch(branch_ID), .jump(jump_ID), .alu_ctrl(alu_ctrl_ID)
    );

    wire [31:0] rs1_data_ID, rs2_data_ID;
    wire [31:0] rd_data_WB; // driven by WB stage, wired back here

    regfile regfile_inst (
        .clk(clk), .we(reg_write_WB),
        .rs1_addr(rs1_addr_ID), .rs2_addr(rs2_addr_ID), .rd_addr(rd_addr_WB),
        .rd_data(rd_data_WB),
        .rs1_data(rs1_data_ID), .rs2_data(rs2_data_ID)
    );

    wire [31:0] imm_ext_ID;
    imm_gen imm_gen_inst (
        .instr(instr_ID), .imm_src(imm_src_ID), .imm_out(imm_ext_ID)
    );

    wire is_jalr_ID = (opcode_ID == 7'b1100111);

    // ---- ID/EX pipeline register ----
    // NOTE: now also carries rs1_addr/rs2_addr (needed by the
    // forwarding unit to compare against downstream destinations).
    reg        reg_write_EX, alu_src_b_EX, mem_write_EX, branch_EX, jump_EX, is_jalr_EX;
    reg [1:0]  alu_src_a_EX, result_src_EX;
    reg [3:0]  alu_ctrl_EX;
    reg [2:0]  funct3_EX;
    reg [31:0] rs1_data_EX, rs2_data_EX, imm_ext_EX, pc_EX, pc_plus4_EX;
    reg [4:0]  rd_addr_EX, rs1_addr_EX, rs2_addr_EX;

    always @(posedge clk or posedge rst) begin
        if (rst || flush || stall) begin
            // bubble: on reset, on a branch flush, AND on a load-use
            // stall (the currently-decoded instruction must NOT be
            // allowed into EX yet -- it waits another cycle in ID).
            reg_write_EX <= 1'b0; alu_src_b_EX <= 1'b0; mem_write_EX <= 1'b0;
            branch_EX <= 1'b0; jump_EX <= 1'b0; is_jalr_EX <= 1'b0;
            alu_src_a_EX <= 2'b0; result_src_EX <= 2'b0; alu_ctrl_EX <= 4'b0;
            funct3_EX <= 3'b0; rs1_data_EX <= 32'b0; rs2_data_EX <= 32'b0;
            imm_ext_EX <= 32'b0; pc_EX <= 32'b0; pc_plus4_EX <= 32'b0;
            rd_addr_EX <= 5'b0; rs1_addr_EX <= 5'b0; rs2_addr_EX <= 5'b0;
        end else begin
            reg_write_EX <= reg_write_ID; alu_src_b_EX <= alu_src_b_ID;
            mem_write_EX <= mem_write_ID; branch_EX <= branch_ID;
            jump_EX <= jump_ID; is_jalr_EX <= is_jalr_ID;
            alu_src_a_EX <= alu_src_a_ID; result_src_EX <= result_src_ID;
            alu_ctrl_EX <= alu_ctrl_ID; funct3_EX <= funct3_ID;
            rs1_data_EX <= rs1_data_ID; rs2_data_EX <= rs2_data_ID;
            imm_ext_EX <= imm_ext_ID; pc_EX <= pc_ID; pc_plus4_EX <= pc_plus4_ID;
            rd_addr_EX <= rd_addr_ID; rs1_addr_EX <= rs1_addr_ID; rs2_addr_EX <= rs2_addr_ID;
        end
    end

    // ---------------------- EX STAGE ------------------------

    // ---- Forwarding unit ----
    // ForwardA/ForwardB: 00 = no forward (use ID/EX's own register
    // read), 10 = forward from EX/MEM (the instruction one ahead,
    // whose ALU result is now sitting in the EX/MEM register),
    // 01 = forward from MEM/WB (two instructions ahead, about to
    // write back this very cycle). EX/MEM checked first since it's
    // the more recent (correct) value if both could apply.
    wire fwdA_from_MEM = reg_write_MEM && (rd_addr_MEM != 5'b0) && (rd_addr_MEM == rs1_addr_EX);
    wire fwdA_from_WB  = reg_write_WB  && (rd_addr_WB  != 5'b0) && (rd_addr_WB  == rs1_addr_EX);
    wire fwdB_from_MEM = reg_write_MEM && (rd_addr_MEM != 5'b0) && (rd_addr_MEM == rs2_addr_EX);
    wire fwdB_from_WB  = reg_write_WB  && (rd_addr_WB  != 5'b0) && (rd_addr_WB  == rs2_addr_EX);

    wire [1:0] forwardA = fwdA_from_MEM ? 2'b10 : fwdA_from_WB ? 2'b01 : 2'b00;
    wire [1:0] forwardB = fwdB_from_MEM ? 2'b10 : fwdB_from_WB ? 2'b01 : 2'b00;

    reg [31:0] rs1_forwarded, rs2_forwarded;
    always @(*) begin
        case (forwardA)
            2'b10: rs1_forwarded = alu_result_MEM;
            2'b01: rs1_forwarded = rd_data_WB;
            default: rs1_forwarded = rs1_data_EX;
        endcase
        case (forwardB)
            2'b10: rs2_forwarded = alu_result_MEM;
            2'b01: rs2_forwarded = rd_data_WB;
            default: rs2_forwarded = rs2_data_EX;
        endcase
    end

    reg [31:0] alu_operand_a_EX;
    always @(*) begin
        case (alu_src_a_EX)
            2'b00: alu_operand_a_EX = rs1_forwarded; // was rs1_data_EX
            2'b01: alu_operand_a_EX = pc_EX;
            2'b10: alu_operand_a_EX = 32'b0;
            default: alu_operand_a_EX = rs1_forwarded;
        endcase
    end
    // was: alu_src_b_EX ? imm_ext_EX : rs2_data_EX
    wire [31:0] alu_operand_b_EX = alu_src_b_EX ? imm_ext_EX : rs2_forwarded;

    wire [31:0] alu_result_EX;
    wire        alu_zero_EX;
    alu alu_inst (
        .a(alu_operand_a_EX), .b(alu_operand_b_EX), .alu_ctrl(alu_ctrl_EX),
        .result(alu_result_EX), .zero(alu_zero_EX)
    );

    wire [31:0] pc_imm_adder_EX = pc_EX + imm_ext_EX;
    wire [31:0] pc_target_EX = is_jalr_EX ? alu_result_EX : pc_imm_adder_EX;

    wire lt_result_EX = (alu_result_EX == 32'd1);
    wire branch_taken_EX = branch_EX &&
                            ((funct3_EX == 3'b000 && alu_zero_EX)   ||
                             (funct3_EX == 3'b001 && !alu_zero_EX)  ||
                             (funct3_EX == 3'b100 && lt_result_EX)  ||
                             (funct3_EX == 3'b101 && !lt_result_EX) ||
                             (funct3_EX == 3'b110 && lt_result_EX)  ||
                             (funct3_EX == 3'b111 && !lt_result_EX));

    assign flush = branch_taken_EX || jump_EX;
    assign pc_next = flush ? pc_target_EX : pc_plus4_IF;

    // ---- Hazard detection unit ----
    // Load-use hazard: the instruction currently in EX is a load
    // (result_src_EX == 01, i.e. its result comes from memory, not
    // ready until the END of MEM stage) AND the instruction right
    // behind it, currently in ID, needs that same register. There's
    // no way to forward data that doesn't exist yet -- must stall.
    wire ex_is_load = (result_src_EX == 2'b01);
    assign stall = ex_is_load && (rd_addr_EX != 5'b0) &&
                   ((rd_addr_EX == rs1_addr_ID) || (rd_addr_EX == rs2_addr_ID));

    // ---- EX/MEM pipeline register ----
    // NOTE: rs2_data_MEM now carries rs2_forwarded (not the raw,
    // possibly-stale rs2_data_EX) so that STORE instructions write
    // the correct, forwarded value to memory too.
    reg        reg_write_MEM, mem_write_MEM;
    reg [1:0]  result_src_MEM;
    reg [2:0]  funct3_MEM;
    reg [31:0] alu_result_MEM, rs2_data_MEM, pc_plus4_MEM;
    reg [4:0]  rd_addr_MEM;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_write_MEM <= 1'b0; mem_write_MEM <= 1'b0; result_src_MEM <= 2'b0;
            funct3_MEM <= 3'b0; alu_result_MEM <= 32'b0; rs2_data_MEM <= 32'b0;
            pc_plus4_MEM <= 32'b0; rd_addr_MEM <= 5'b0;
        end else begin
            reg_write_MEM <= reg_write_EX; mem_write_MEM <= mem_write_EX;
            result_src_MEM <= result_src_EX; funct3_MEM <= funct3_EX;
            alu_result_MEM <= alu_result_EX; rs2_data_MEM <= rs2_forwarded;
            pc_plus4_MEM <= pc_plus4_EX; rd_addr_MEM <= rd_addr_EX;
        end
    end

    // ---------------------- MEM STAGE ------------------------
    wire [31:0] mem_read_data_MEM;
    dmem dmem_inst (
        .clk(clk), .addr(alu_result_MEM), .write_data(rs2_data_MEM),
        .mem_write(mem_write_MEM), .funct3(funct3_MEM),
        .read_data(mem_read_data_MEM)
    );

    // ---- MEM/WB pipeline register ----
    reg        reg_write_WB;
    reg [1:0]  result_src_WB;
    reg [31:0] alu_result_WB, mem_read_data_WB, pc_plus4_WB;
    reg [4:0]  rd_addr_WB;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_write_WB <= 1'b0; result_src_WB <= 2'b0;
            alu_result_WB <= 32'b0; mem_read_data_WB <= 32'b0;
            pc_plus4_WB <= 32'b0; rd_addr_WB <= 5'b0;
        end else begin
            reg_write_WB <= reg_write_MEM; result_src_WB <= result_src_MEM;
            alu_result_WB <= alu_result_MEM; mem_read_data_WB <= mem_read_data_MEM;
            pc_plus4_WB <= pc_plus4_MEM; rd_addr_WB <= rd_addr_MEM;
        end
    end

    // ---------------------- WB STAGE ------------------------
    reg [31:0] rd_data_mux_WB;
    always @(*) begin
        case (result_src_WB)
            2'b00: rd_data_mux_WB = alu_result_WB;
            2'b01: rd_data_mux_WB = mem_read_data_WB;
            2'b10: rd_data_mux_WB = pc_plus4_WB;
            default: rd_data_mux_WB = alu_result_WB;
        endcase
    end
    assign rd_data_WB = rd_data_mux_WB; // feeds back to regfile's write port in ID
                                         // AND to the forwarding unit in EX

    // ---------------- Debug outputs (keeps synthesis from removing the design) ----------------
    assign debug_pc = pc;
    assign debug_alu_result_EX = alu_result_EX;
    assign debug_rd_data_WB = rd_data_WB;

endmodule
