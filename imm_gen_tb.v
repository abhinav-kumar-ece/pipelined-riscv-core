// Testbench for immediate generator — verifies sign extension
// =============================================================
// imm_gen_tb.v — testbench for imm_gen.v
// Each test instruction was hand-encoded bit-by-bit from a real
// RV32I instruction, so a wrong bit position in imm_gen.v will
// show up as a FAIL here.
// =============================================================
`timescale 1ns / 1ps

module imm_gen_tb;

    reg  [31:0] instr;
    reg  [2:0]  imm_src;
    wire [31:0] imm_out;

    integer errors = 0;
    integer tests  = 0;

    imm_gen dut (
        .instr(instr),
        .imm_src(imm_src),
        .imm_out(imm_out)
    );

    task check;
        input [31:0] expected;
        input [127:0] name;
        begin
            tests = tests + 1;
            #1;
            if (imm_out !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: instr=%h got=%h expected=%h", name, instr, imm_out, expected);
            end else begin
                $display("PASS [%0s]: imm_out=%h", name, imm_out);
            end
        end
    endtask

    initial begin
        // I-type: ADDI x1, x0, -5  -> imm should sign-extend to -5
        instr = 32'hFFB00093; imm_src = 3'b000;
        check(32'hFFFFFFFB, "I_type_ADDI_neg5");

        // S-type: SW x2, -20(x1)  -> imm should sign-extend to -20
        instr = 32'hFE20A623; imm_src = 3'b001;
        check(32'hFFFFFFEC, "S_type_SW_neg20");

        // B-type: BEQ x1, x2, +8  -> imm should be +8 (positive, LSB implicit 0)
        instr = 32'h00208463; imm_src = 3'b010;
        check(32'h00000008, "B_type_BEQ_pos8");

        // B-type: BEQ x1, x2, -4  -> imm should sign-extend to -4
        // (tests the sign-extension bits, not just a positive case)
        instr = 32'hFE208EE3; imm_src = 3'b010;
        check(32'hFFFFFFFC, "B_type_BEQ_neg4");

        // U-type: LUI x1, 0x12345 -> imm occupies upper 20 bits, lower 12 zero
        instr = 32'h123450B7; imm_src = 3'b011;
        check(32'h12345000, "U_type_LUI");

        // J-type: JAL x1, +256 -> imm should be +256 (LSB implicit 0)
        instr = 32'h100000EF; imm_src = 3'b100;
        check(32'h00000100, "J_type_JAL_pos256");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
