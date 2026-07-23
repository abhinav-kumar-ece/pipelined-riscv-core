// =============================================================
// riscv_singlecycle_tb.v — end-to-end testbench for the full CPU
// Loads program.hex, runs it, then checks the final register file
// and memory state against hand-calculated expected values.
//
// Uses hierarchical references (dut.regfile_inst.regfile[n]) to
// peek inside the CPU -- this only works in simulation, it's not
// something real hardware allows, but it's the standard way to
// "probe" internal state from a testbench.
// =============================================================
`timescale 1ns / 1ps

module riscv_singlecycle_tb;

    reg clk, rst;
    integer errors = 0;
    integer tests  = 0;

    riscv_singlecycle dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    task check32;
        input [31:0] actual;
        input [31:0] expected;
        input [127:0] name;
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
        clk = 0;
        rst = 1;
        @(negedge clk);   // hold reset across a clock edge
        rst = 0;

        // 8 instructions execute (one per clock, single-cycle) plus a
        // little headroom -- run 12 cycles to be safe.
        repeat (12) @(negedge clk);

        $display("========================================");
        $display("Final register file contents:");
        $display("========================================");

        check32(dut.regfile_inst.regfile[1], 32'd5, "x1_addi_5");
        check32(dut.regfile_inst.regfile[2], 32'd3, "x2_addi_3");
        check32(dut.regfile_inst.regfile[3], 32'd8, "x3_add_result");
        check32(dut.regfile_inst.regfile[4], 32'd8, "x4_loaded_from_mem");
        check32(dut.regfile_inst.regfile[5], 32'd0, "x5_skipped_by_branch");
        check32(dut.regfile_inst.regfile[6], 32'd7, "x6_branch_target_reached");

        // Reassemble the stored word from dmem's byte array (little-endian)
        check32({dut.dmem_inst.mem[3], dut.dmem_inst.mem[2],
                  dut.dmem_inst.mem[1], dut.dmem_inst.mem[0]},
                 32'd8, "dmem_word0_stored_by_sw");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED -- your CPU correctly ran a real program!");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
