// Testbench for instruction memory — verifies instruction fetch
// =============================================================
// imem_tb.v — testbench for imem.v
// Requires program.hex to be added as a Simulation Source too,
// so Vivado copies it into the simulation working directory.
// =============================================================
`timescale 1ns / 1ps

module imem_tb;

    reg  [31:0] addr;
    wire [31:0] instr;

    integer errors = 0;
    integer tests  = 0;

    imem dut (
        .addr(addr),
        .instr(instr)
    );

    task check;
        input [31:0] expected;
        input [127:0] name;
        begin
            tests = tests + 1;
            #1;
            if (instr !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: addr=%0d got=%h expected=%h", name, addr, instr, expected);
            end else begin
                $display("PASS [%0s]: addr=%0d instr=%h", name, addr, instr);
            end
        end
    endtask

    initial begin
        #1; // let $readmemh finish loading at time 0

        addr = 32'd0;  check(32'h00000013, "word_0");
        addr = 32'd4;  check(32'h00500093, "word_1");
        addr = 32'd8;  check(32'h00A00113, "word_2");
        addr = 32'd12; check(32'h002081B3, "word_3");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
