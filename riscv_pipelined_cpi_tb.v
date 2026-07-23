// =============================================================
// riscv_pipelined_cpi_tb.v — CPI measurement for the PIPELINED core
//
// Before running: copy cpi_benchmark.hex's contents into program.hex
//
// Runs the SAME "sum 1 to 10" program as the single-cycle CPI
// test, on riscv_pipelined_hazards, and measures real cycle count.
// Also tallies stall and flush cycles separately, since those are
// exactly the pipeline's overhead sources -- good, specific data
// for the paper's discussion of where pipelining's CPI cost comes
// from (here: branch-flush penalty from 9 taken backward branches,
// each costing 2 bubble cycles under this design's no-branch-
// prediction, resolve-in-EX policy).
// =============================================================
`timescale 1ns / 1ps

module riscv_pipelined_cpi_tb;

    reg clk, rst;
    integer cycle_count;
    integer stall_count;
    integer flush_count;
    reg     done;

    riscv_pipelined_hazards dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
            stall_count <= 0;
            flush_count <= 0;
        end else if (!done) begin
            cycle_count <= cycle_count + 1;
            if (dut.stall) stall_count <= stall_count + 1;
            if (dut.flush) flush_count <= flush_count + 1;
        end
    end

    initial begin
        clk = 0; rst = 1; done = 0; cycle_count = 0;
        stall_count = 0; flush_count = 0;
        @(negedge clk);
        rst = 0;

        wait (dut.regfile_inst.regfile[1] == 32'd20 || cycle_count > 500);
        @(posedge clk);
        done = 1;

        $display("========================================");
        $display("PIPELINED CORE — CPI MEASUREMENT (Benchmark 2: branch-free chain)");
        $display("========================================");
        if (dut.regfile_inst.regfile[1] !== 32'd20) begin
            $display("ERROR: program did not produce the expected result");
            $display("x1 = %0d (expected 20)", dut.regfile_inst.regfile[1]);
        end else begin
            $display("Result verified correct: x1 = %0d", dut.regfile_inst.regfile[1]);
            $display("Total clock cycles elapsed: %0d", cycle_count);
            $display("  ...of which stall cycles: %0d", stall_count);
            $display("  ...of which flush cycles: %0d", flush_count);
            $display("Dynamic instructions executed: 20");
            $display("CPI = %0d / 20 = %f", cycle_count, cycle_count / 20.0);
        end
        $display("========================================");

        $finish;
    end

endmodule
