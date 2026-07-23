// =============================================================
// riscv_pipelined_tb.v — testbench for the pipeline SKELETON
//
// Before running: copy pipeline_program.hex's contents into program.hex
//
// This program is deliberately hazard-free (NOPs inserted between
// every dependent instruction) since this skeleton has no
// forwarding/stall logic yet. It re-runs the same computation as
// the very first single-cycle integration test, so a pass here
// proves the pipeline wiring itself (stage registers, signal
// carry-through) is correct before hazard logic is layered on top.
//
//   x1 = 5, x2 = 3, x3 = x1+x2 = 8, mem[0] = 8, x4 = mem[0] = 8
// =============================================================
`timescale 1ns / 1ps

module riscv_pipelined_tb;

    reg clk, rst;
    integer errors = 0;
    integer tests  = 0;

    riscv_pipelined dut (
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

        // 15 instructions total, plus 4 extra cycles for the pipeline to
        // drain (an instruction fetched at cycle N doesn't write back
        // until cycle N+4 in a 5-stage pipeline) -- run well past that.
        repeat (25) @(negedge clk);

        check32(dut.regfile_inst.regfile[1], 32'd5, "x1_addi_5");
        check32(dut.regfile_inst.regfile[2], 32'd3, "x2_addi_3");
        check32(dut.regfile_inst.regfile[3], 32'd8, "x3_add_result");
        check32(dut.regfile_inst.regfile[4], 32'd8, "x4_loaded_from_mem");

        check32({dut.dmem_inst.mem[3], dut.dmem_inst.mem[2],
                  dut.dmem_inst.mem[1], dut.dmem_inst.mem[0]},
                 32'd8, "dmem_word0_stored_by_sw");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED -- pipeline skeleton wiring is correct!");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
