// Testbench for control unit — verifies opcode decoding
   // and control signal generation for all instruction types
// =============================================================
// control_unit_tb.v — testbench for control_unit.v
// Feeds in the opcode/funct3/funct7 for one real instruction of
// each type and checks every control signal comes out right.
// =============================================================
`timescale 1ns / 1ps

module control_unit_tb;

    reg  [6:0] opcode;
    reg  [2:0] funct3;
    reg        funct7_5;

    wire        reg_write;
    wire [2:0]  imm_src;
    wire [1:0]  alu_src_a;
    wire        alu_src_b;
    wire        mem_write;
    wire [1:0]  result_src;
    wire        branch;
    wire        jump;
    wire [3:0]  alu_ctrl;

    integer errors = 0;
    integer tests  = 0;

    control_unit dut (
        .opcode(opcode), .funct3(funct3), .funct7_5(funct7_5),
        .reg_write(reg_write), .imm_src(imm_src), .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b), .mem_write(mem_write), .result_src(result_src),
        .branch(branch), .jump(jump), .alu_ctrl(alu_ctrl)
    );

    // Packs all outputs into one vector so we can compare with one line
    function [14:0] pack;
        input rw; input [2:0] isrc; input [1:0] asa; input asb;
        input mw; input [1:0] rsrc; input br; input jp; input [3:0] ac;
        begin
            pack = {rw, isrc, asa, asb, mw, rsrc, br, jp, ac};
        end
    endfunction

    task check;
        input [14:0] expected;
        input [127:0] name;
        reg [14:0] actual;
        begin
            tests = tests + 1;
            #1;
            actual = {reg_write, imm_src, alu_src_a, alu_src_b, mem_write,
                      result_src, branch, jump, alu_ctrl};
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: got=%b expected=%b", name, actual, expected);
            end else begin
                $display("PASS [%0s]", name);
            end
        end
    endtask

    initial begin
        // ADD x3,x1,x2  -> R-type, funct3=000, funct7_5=0 -> ALU_ADD(0000)
        opcode=7'b0110011; funct3=3'b000; funct7_5=1'b0;
        check(pack(1,3'b000,2'b00,1'b0,0,2'b00,0,0,4'b0000), "ADD");

        // SUB x3,x1,x2  -> R-type, funct3=000, funct7_5=1 -> ALU_SUB(0001)
        opcode=7'b0110011; funct3=3'b000; funct7_5=1'b1;
        check(pack(1,3'b000,2'b00,1'b0,0,2'b00,0,0,4'b0001), "SUB");

        // ADDI x1,x0,5  -> I-type ALU, funct3=000, funct7_5 irrelevant(0) -> ALU_ADD
        opcode=7'b0010011; funct3=3'b000; funct7_5=1'b0;
        check(pack(1,3'b000,2'b00,1'b1,0,2'b00,0,0,4'b0000), "ADDI");

        // LW x1,0(x2)   -> Load, result_src=01, ALU_ADD for address
        opcode=7'b0000011; funct3=3'b010; funct7_5=1'b0;
        check(pack(1,3'b000,2'b00,1'b1,0,2'b01,0,0,4'b0000), "LW");

        // SW x1,0(x2)   -> Store, mem_write=1, imm_src=S-type(001)
        opcode=7'b0100011; funct3=3'b010; funct7_5=1'b0;
        check(pack(0,3'b001,2'b00,1'b1,1,2'b00,0,0,4'b0000), "SW");

        // BEQ x1,x2,off -> Branch, branch=1, imm_src=B-type(010), ALU_SUB
        opcode=7'b1100011; funct3=3'b000; funct7_5=1'b0;
        check(pack(0,3'b010,2'b00,1'b0,0,2'b00,1,0,4'b0001), "BEQ");

        // BLT x1,x2,off -> Branch, funct3=100 -> needs ALU_SLT(1000), not SUB
        opcode=7'b1100011; funct3=3'b100; funct7_5=1'b0;
        check(pack(0,3'b010,2'b00,1'b0,0,2'b00,1,0,4'b1000), "BLT");

        // BGE x1,x2,off -> same ALU op as BLT (SLT) -- branch_taken logic
        // in the datapath is what inverts the sense, not the ALU choice
        opcode=7'b1100011; funct3=3'b101; funct7_5=1'b0;
        check(pack(0,3'b010,2'b00,1'b0,0,2'b00,1,0,4'b1000), "BGE");

        // BLTU x1,x2,off -> needs ALU_SLTU(1001), unsigned compare
        opcode=7'b1100011; funct3=3'b110; funct7_5=1'b0;
        check(pack(0,3'b010,2'b00,1'b0,0,2'b00,1,0,4'b1001), "BLTU");

        // BGEU x1,x2,off -> same ALU op as BLTU (SLTU)
        opcode=7'b1100011; funct3=3'b111; funct7_5=1'b0;
        check(pack(0,3'b010,2'b00,1'b0,0,2'b00,1,0,4'b1001), "BGEU");

        // JAL x1,off    -> jump=1, alu_src_a=PC(01), result_src=PC+4(10)
        opcode=7'b1101111; funct3=3'b000; funct7_5=1'b0;
        check(pack(1,3'b100,2'b01,1'b1,0,2'b10,0,1,4'b0000), "JAL");

        // JALR x1,0(x2) -> jump=1, alu_src_a=rs1(00), result_src=PC+4(10)
        opcode=7'b1100111; funct3=3'b000; funct7_5=1'b0;
        check(pack(1,3'b000,2'b00,1'b1,0,2'b10,0,1,4'b0000), "JALR");

        // LUI x1,imm    -> alu_src_a=zero(10), imm_src=U-type(011)
        opcode=7'b0110111; funct3=3'b000; funct7_5=1'b0;
        check(pack(1,3'b011,2'b10,1'b1,0,2'b00,0,0,4'b0000), "LUI");

        // AUIPC x1,imm  -> alu_src_a=PC(01), imm_src=U-type(011)
        opcode=7'b0010111; funct3=3'b000; funct7_5=1'b0;
        check(pack(1,3'b011,2'b01,1'b1,0,2'b00,0,0,4'b0000), "AUIPC");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
