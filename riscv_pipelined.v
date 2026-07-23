// =============================================================
// riscv_pipelined.v — 5-stage pipelined RV32I CPU (SKELETON)
//
// Stages: IF (fetch) -> ID (decode+regread) -> EX (ALU) ->
//         MEM (data memory) -> WB (writeback)
//
// *** THIS VERSION HAS NO HAZARD HANDLING YET ***
// It will give WRONG answers on programs with back-to-back
// dependent instructions, or branches immediately preceded by
// other instructions, because:
//   - data hazards: a later stage may read a register before an
//     earlier, still-in-flight instruction has written it back
//   - control hazards: by the time a branch resolves (in EX),
//     the two instructions after it have already been fetched,
//     as if the branch would not be taken.
// This is intentional -- the "skeleton" step. Forwarding and
// hazard detection get added next, on top of this working base.
// =============================================================
module riscv_pipelined (
    input wire clk,
    input wire rst
);

    // ---------------------- IF STAGE ------------------------
    reg  [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4_IF;

    always @(posedge clk or posedge rst) begin
        if (rst) pc <= 32'b0;
        else     pc <= pc_next;
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
            instr_ID    <= 32'b0;
            pc_ID       <= 32'b0;
            pc_plus4_ID <= 32'b0;
        end else begin
            instr_ID    <= instr_IF;
            pc_ID       <= pc;
            pc_plus4_ID <= pc_plus4_IF;
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
    reg        reg_write_EX, alu_src_b_EX, mem_write_EX, branch_EX, jump_EX, is_jalr_EX;
    reg [1:0]  alu_src_a_EX, result_src_EX;
    reg [3:0]  alu_ctrl_EX;
    reg [2:0]  funct3_EX;
    reg [31:0] rs1_data_EX, rs2_data_EX, imm_ext_EX, pc_EX, pc_plus4_EX;
    reg [4:0]  rd_addr_EX;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_write_EX <= 1'b0; alu_src_b_EX <= 1'b0; mem_write_EX <= 1'b0;
            branch_EX <= 1'b0; jump_EX <= 1'b0; is_jalr_EX <= 1'b0;
            alu_src_a_EX <= 2'b0; result_src_EX <= 2'b0; alu_ctrl_EX <= 4'b0;
            funct3_EX <= 3'b0; rs1_data_EX <= 32'b0; rs2_data_EX <= 32'b0;
            imm_ext_EX <= 32'b0; pc_EX <= 32'b0; pc_plus4_EX <= 32'b0;
            rd_addr_EX <= 5'b0;
        end else begin
            reg_write_EX <= reg_write_ID; alu_src_b_EX <= alu_src_b_ID;
            mem_write_EX <= mem_write_ID; branch_EX <= branch_ID;
            jump_EX <= jump_ID; is_jalr_EX <= is_jalr_ID;
            alu_src_a_EX <= alu_src_a_ID; result_src_EX <= result_src_ID;
            alu_ctrl_EX <= alu_ctrl_ID; funct3_EX <= funct3_ID;
            rs1_data_EX <= rs1_data_ID; rs2_data_EX <= rs2_data_ID;
            imm_ext_EX <= imm_ext_ID; pc_EX <= pc_ID; pc_plus4_EX <= pc_plus4_ID;
            rd_addr_EX <= rd_addr_ID;
        end
    end

    // ---------------------- EX STAGE ------------------------
    reg [31:0] alu_operand_a_EX;
    always @(*) begin
        case (alu_src_a_EX)
            2'b00: alu_operand_a_EX = rs1_data_EX;
            2'b01: alu_operand_a_EX = pc_EX;
            2'b10: alu_operand_a_EX = 32'b0;
            default: alu_operand_a_EX = rs1_data_EX;
        endcase
    end
    wire [31:0] alu_operand_b_EX = alu_src_b_EX ? imm_ext_EX : rs2_data_EX;

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

    // Control-hazard note: by the time branch_taken_EX is known here (EX
    // stage), IF and ID have already fetched/decoded the next two
    // instructions unconditionally. Flushing those when the branch is
    // taken is added in the next step.
    assign pc_next = (branch_taken_EX || jump_EX) ? pc_target_EX : pc_plus4_IF;

    // ---- EX/MEM pipeline register ----
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
            alu_result_MEM <= alu_result_EX; rs2_data_MEM <= rs2_data_EX;
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

endmodule
