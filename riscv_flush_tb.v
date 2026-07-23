// =============================================================
// riscv_flush_tb.v — tests control-hazard flush logic
//
// Before running: copy flush_program.hex's contents into program.hex
//
// Program: a taken branch immediately followed by two "trap"
// instructions that write x10=99 and x11=99. If flush logic is
// broken, these speculatively-fetched wrong-path instructions
// would incorrectly execute and corrupt x10/x11. If flush works
// correctly, they are squashed entirely -- x10 and x11 must stay
// at their reset value of 0, and control must land cleanly on
// the instruction after the two trapped ones (x6=7).
//
//   x1=1, x2=1, branch taken -> x10=0 (flushed), x11=0 (flushed),
//   x6=7 (correct landing instruction)
// =============================================================
`timescale 1ns / 1ps

module riscv_flush_tb;

    reg clk, rst;
    integer errors = 0;
    integer tests  = 0;

    riscv_pipelined_hazards dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    task check32;
        input [31:0] actual; input [31:0] expected; input [127:0] name;
        begin
            tests = tests + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: got=%0d expected=%0d", name, actual, expected);
            end else begin
                $display("PASS [%0s]: %0d", name, actual);
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1;
        @(negedge clk);
        rst = 0;

        repeat (40) @(negedge clk);

        check32(dut.regfile_inst.regfile[1],  32'd1, "x1_setup");
        check32(dut.regfile_inst.regfile[2],  32'd1, "x2_setup");
        check32(dut.regfile_inst.regfile[10], 32'd0, "x10_trap_MUST_be_flushed");
        check32(dut.regfile_inst.regfile[11], 32'd0, "x11_trap_MUST_be_flushed");
        check32(dut.regfile_inst.regfile[6],  32'd7, "x6_correct_landing_instruction");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED -- branch flush correctly squashes wrong-path instructions!");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
