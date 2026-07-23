// =============================================================
// riscv_pipelined_hazards_tb.v — testbench for the pipeline WITH
// forwarding + hazard detection.
//
// Before running: copy hazard_program.hex's contents into program.hex
//
// This program has ZERO NOPs -- every instruction is back-to-back
// dependent on the one(s) before it, deliberately exercising:
//   - EX/MEM forwarding (x2 into 'add', x3 into 'sw')
//   - MEM/WB forwarding (x1 into 'add')
//   - the load-use hazard + stall + forward (x4 into the final 'add')
// If forwarding or hazard detection has ANY bug, this program
// will compute wrong values -- unlike the skeleton test, there is
// no NOP margin to hide a mistake.
//
//   x1=5, x2=3, x3=x1+x2=8, mem[0]=8, x4=mem[0]=8, x5=x4+x4=16
// =============================================================
`timescale 1ns / 1ps

module riscv_pipelined_hazards_tb;

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

        // Only 6 instructions, but the load-use hazard adds a stall
        // cycle, plus normal 5-stage pipeline drain -- run generously.
        repeat (20) @(negedge clk);

        check32(dut.regfile_inst.regfile[1], 32'd5,  "x1_addi_5");
        check32(dut.regfile_inst.regfile[2], 32'd3,  "x2_addi_3");
        check32(dut.regfile_inst.regfile[3], 32'd8,  "x3_add_forwarded_both_ways");
        check32(dut.regfile_inst.regfile[4], 32'd8,  "x4_loaded_from_mem");
        check32(dut.regfile_inst.regfile[5], 32'd16, "x5_load_use_hazard_stall_and_forward");

        check32({dut.dmem_inst.mem[3], dut.dmem_inst.mem[2],
                  dut.dmem_inst.mem[1], dut.dmem_inst.mem[0]},
                 32'd8, "dmem_word0_stored_by_sw_forwarded");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED -- forwarding and hazard detection work!");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
