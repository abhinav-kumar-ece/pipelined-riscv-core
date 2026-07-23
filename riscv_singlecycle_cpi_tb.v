// =============================================================
// riscv_singlecycle_cpi_tb.v — CPI measurement for the SINGLE-CYCLE core
//
// Before running: copy cpi_benchmark.hex's contents into program.hex
//
// Runs the "sum 1 to 10" loop and counts how many clock cycles
// elapse until the answer (x1=55) is correctly computed. Divides
// by the known dynamic instruction count (33: 3 setup + 10 loop
// iterations x 3 instructions each) to get CPI.
//
// For a single-cycle design, CPI should come out to almost
// exactly 1.0 by construction (one instruction always completes
// per clock cycle, with no exceptions) -- this test exists to
// empirically CONFIRM that, not just assume it, and to produce
// a real, citable number for the paper's results section.
// =============================================================
`timescale 1ns / 1ps

module riscv_singlecycle_cpi_tb;

    reg clk, rst;
    integer cycle_count;
    reg     done;

    riscv_singlecycle dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    // Count clock cycles starting from when reset is released.
    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else if (!done) begin
            cycle_count <= cycle_count + 1;
        end
    end

    initial begin
        clk = 0; rst = 1; done = 0; cycle_count = 0;
        @(negedge clk);
        rst = 0;

        // Poll until x1 reaches the expected final value (55), or
        // give up after a generous cycle budget (safety net in case
        // of an unrelated bug -- avoids an infinite loop in simulation).
        wait (dut.regfile_inst.regfile[1] == 32'd20 || cycle_count > 500);
        @(posedge clk); // let this cycle's count register settle
        done = 1;

        $display("========================================");
        $display("SINGLE-CYCLE CORE — CPI MEASUREMENT (Benchmark 2: branch-free chain)");
        $display("========================================");
        if (dut.regfile_inst.regfile[1] !== 32'd20) begin
            $display("ERROR: program did not produce the expected result");
            $display("x1 = %0d (expected 20)", dut.regfile_inst.regfile[1]);
        end else begin
            $display("Result verified correct: x1 = %0d", dut.regfile_inst.regfile[1]);
            $display("Total clock cycles elapsed: %0d", cycle_count);
            $display("Dynamic instructions executed: 20");
            $display("CPI = %0d / 20 = %f", cycle_count, cycle_count / 20.0);
        end
        $display("========================================");

        $finish;
    end

endmodule
