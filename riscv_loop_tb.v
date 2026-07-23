// =============================================================
// riscv_loop_tb.v — tests a real loop with a BACKWARD branch
//
// Before running: copy loop_program.hex's contents into program.hex
//
// Program (sums 1+2+3+4+5 using a BNE-controlled loop):
//   addr 0:  addi x1, x0, 0     # x1 = sum = 0
//   addr 4:  addi x2, x0, 1     # x2 = i = 1
//   addr 8:  addi x3, x0, 6     # x3 = limit = 6
//   addr 12: add  x1, x1, x2    # <- loop target: sum += i
//   addr 16: addi x2, x2, 1     # i++
//   addr 20: bne  x2, x3, -8    # if i != 6, jump back to addr 12
//
// Expected: x1 = 15 (1+2+3+4+5), x2 = 6, x3 = 6
// =============================================================
`timescale 1ns / 1ps

module riscv_loop_tb;

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

        // 18 cycles needed for all 5 loop iterations (traced by hand --
        // see project notes); extra cycles are harmless since uninitialized
        // memory beyond the program decodes to safe no-ops.
        repeat (20) @(negedge clk);

        check32(dut.regfile_inst.regfile[1], 32'd15, "x1_loop_sum_1to5");
        check32(dut.regfile_inst.regfile[2], 32'd6,  "x2_final_counter");
        check32(dut.regfile_inst.regfile[3], 32'd6,  "x3_limit_unchanged");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED -- backward branch / loop works!");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
