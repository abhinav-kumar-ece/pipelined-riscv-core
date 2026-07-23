// =============================================================
// riscv_branchtypes_tb.v — tests BLT, BGE, BLTU, BGEU specifically
//
// Before running: copy branchtypes_program.hex's contents into program.hex
//
// Program logic: sets up register values, then runs one of each new
// branch type. Each branch SHOULD be taken, skipping a "marker"
// instruction (addi xN, x0, 1) right after it. If a branch type is
// broken (not taken when it should be), its marker register will end
// up 1 instead of 0 -- an unambiguous pass/fail signal per branch type.
//
//   x1=3, x2=7                        (small positive numbers)
//   BLT  x1,x2  -> 3 < 7 signed        -> should take -> x10 marker
//   BGE  x2,x1  -> 7 >= 3 signed       -> should take -> x11 marker
//   x3=-1 (0xFFFFFFFF as unsigned = huge), x4=1
//   BLTU x4,x3  -> 1 < 0xFFFFFFFF unsigned -> should take -> x12 marker
//   BGEU x3,x4  -> 0xFFFFFFFF >= 1 unsigned -> should take -> x13 marker
//   x14=42                             (proves the program ran to completion)
// =============================================================
`timescale 1ns / 1ps

module riscv_branchtypes_tb;

    reg clk, rst;
    integer errors = 0;
    integer tests  = 0;

    riscv_singlecycle dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    task check32;
        input [31:0] actual; input [31:0] expected; input [127:0] name;
        begin
            tests = tests + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: got=%0d (%h) expected=%0d (%h)",
                           name, actual, actual, expected, expected);
            end else begin
                $display("PASS [%0s]: %0d", name, actual);
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1;
        @(negedge clk);
        rst = 0;

        // 9 instructions actually execute (4 "marker" instructions are
        // correctly skipped if everything works); run 12 for margin.
        repeat (12) @(negedge clk);

        check32(dut.regfile_inst.regfile[1],  32'd3,          "x1_setup");
        check32(dut.regfile_inst.regfile[2],  32'd7,          "x2_setup");
        check32(dut.regfile_inst.regfile[3],  32'hFFFFFFFF,   "x3_neg1_as_unsigned");
        check32(dut.regfile_inst.regfile[4],  32'd1,          "x4_setup");
        check32(dut.regfile_inst.regfile[10], 32'd0,          "BLT_marker_should_be_skipped");
        check32(dut.regfile_inst.regfile[11], 32'd0,          "BGE_marker_should_be_skipped");
        check32(dut.regfile_inst.regfile[12], 32'd0,          "BLTU_marker_should_be_skipped");
        check32(dut.regfile_inst.regfile[13], 32'd0,          "BGEU_marker_should_be_skipped");
        check32(dut.regfile_inst.regfile[14], 32'd42,         "x14_program_completed");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED -- BLT/BGE/BLTU/BGEU all correct!");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
