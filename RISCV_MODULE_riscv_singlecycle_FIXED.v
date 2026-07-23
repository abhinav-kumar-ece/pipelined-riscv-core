// =============================================================
// riscv_singlecycle.v — Top-level single-cycle RV32I CPU
// Wires together: PC, imem, regfile, imm_gen, control_unit,
// alu, dmem.
// =============================================================
module riscv_singlecycle (
    input wire clk,
    input wire rst
);

    // ---------------- Program Counter ----------------
    reg  [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    wire [31:0] pc_target;   // branch/jump target = pc + imm (or rs1+imm for JALR)

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'b0;
        else
            pc <= pc_next;
    end

    assign pc_plus4 = pc + 32'd4;

    // ---------------- Instruction Memory ----------------
    wire [31:0] instr;
    imem imem_inst (
        .addr(pc),
        .instr(instr)
    );

    // Field extraction (fixed positions for every RV32I instruction)
    wire [6:0] opcode  = instr[6:0];
    wire [4:0] rd_addr = instr[11:7];
    wire [2:0] funct3  = instr[14:12];
    wire [4:0] rs1_addr= instr[19:15];
    wire [4:0] rs2_addr= instr[24:20];
    wire       funct7_5= instr[30];

    // ---------------- Control Unit ----------------
    wire        reg_write, alu_src_b, mem_write, branch, jump;
    wire [2:0]  imm_src;
    wire [1:0]  alu_src_a, result_src;
    wire [3:0]  alu_ctrl;

    control_unit ctrl_inst (
        .opcode(opcode), .funct3(funct3), .funct7_5(funct7_5),
        .reg_write(reg_write), .imm_src(imm_src), .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b), .mem_write(mem_write), .result_src(result_src),
        .branch(branch), .jump(jump), .alu_ctrl(alu_ctrl)
    );

    // ---------------- Register File ----------------
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] rd_data; // writeback value, driven below

    regfile regfile_inst (
        .clk(clk), .we(reg_write),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    // ---------------- Immediate Generator ----------------
    wire [31:0] imm_ext;
    imm_gen imm_gen_inst (
        .instr(instr), .imm_src(imm_src), .imm_out(imm_ext)
    );

    // ---------------- ALU operand muxes ----------------
    // alu_src_a: 00=rs1  01=PC  10=zero
    reg [31:0] alu_operand_a;
    always @(*) begin
        case (alu_src_a)
            2'b00: alu_operand_a = rs1_data;
            2'b01: alu_operand_a = pc;
            2'b10: alu_operand_a = 32'b0;
            default: alu_operand_a = rs1_data;
        endcase
    end

    // alu_src_b: 0=rs2  1=immediate
    wire [31:0] alu_operand_b = alu_src_b ? imm_ext : rs2_data;

    // ---------------- ALU ----------------
    wire [31:0] alu_result;
    wire        alu_zero;

    alu alu_inst (
        .a(alu_operand_a), .b(alu_operand_b), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(alu_zero)
    );

    // ---------------- Data Memory ----------------
    wire [31:0] mem_read_data;
    dmem dmem_inst (
        .clk(clk), .addr(alu_result), .write_data(rs2_data),
        .mem_write(mem_write), .funct3(funct3),
        .read_data(mem_read_data)
    );

    // ---------------- Writeback mux ----------------
    // result_src: 00=ALU result  01=memory data  10=PC+4
    reg [31:0] rd_data_mux;
    always @(*) begin
        case (result_src)
            2'b00: rd_data_mux = alu_result;
            2'b01: rd_data_mux = mem_read_data;
            2'b10: rd_data_mux = pc_plus4;
            default: rd_data_mux = alu_result;
        endcase
    end
    assign rd_data = rd_data_mux;

    // ---------------- Next PC logic ----------------
    // Branch: taken depends on which branch instruction it is.
    //   funct3=000 (BEQ):  taken if zero=1          (rs1 == rs2)
    //   funct3=001 (BNE):  taken if zero=0          (rs1 != rs2)
    //   funct3=100 (BLT):  taken if SLT result=1    (rs1 <  rs2, signed)
    //   funct3=101 (BGE):  taken if SLT result=0    (rs1 >= rs2, signed)
    //   funct3=110 (BLTU): taken if SLTU result=1   (rs1 <  rs2, unsigned)
    //   funct3=111 (BGEU): taken if SLTU result=0   (rs1 >= rs2, unsigned)
    // The control unit already picked SUB/SLT/SLTU appropriately based on
    // funct3, so alu_result here holds exactly the comparison we need --
    // we just have to read it the right way for each case.
    wire lt_result = (alu_result == 32'd1);
    wire branch_taken = branch &&
                         ((funct3 == 3'b000 && alu_zero)   ||
                          (funct3 == 3'b001 && !alu_zero)  ||
                          (funct3 == 3'b100 && lt_result)  ||
                          (funct3 == 3'b101 && !lt_result) ||
                          (funct3 == 3'b110 && lt_result)  ||
                          (funct3 == 3'b111 && !lt_result));

    // Target address: PC + imm for branches/JAL, but rs1 + imm for JALR.
    // NOTE: for branches, the main ALU is busy computing rs1-rs2 for the
    // comparison (alu_zero), so it CANNOT also supply pc+imm -- that's
    // why real single-cycle datapaths always include a small dedicated
    // adder just for this. For JALR specifically, alu_src_a was set to
    // rs1 (not PC) by the control unit, so the main ALU's result IS
    // already rs1+imm and we can reuse it directly for that one case.
    wire [31:0] pc_imm_adder = pc + imm_ext;
    wire        is_jalr = (opcode == 7'b1100111);
    assign pc_target = is_jalr ? alu_result : pc_imm_adder;

    assign pc_next = (branch_taken || jump) ? pc_target : pc_plus4;

endmodule
