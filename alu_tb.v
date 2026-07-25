// Testbench for ALU module — verifies all operations
// =============================================================
// alu_tb.v — self-checking testbench for alu.v
// Not synthesizable hardware — simulation only.
// =============================================================
`timescale 1ns / 1ps

module alu_tb;

    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;

    integer errors = 0;
    integer tests  = 0;

    // "Instantiate" the ALU: create one real instance of it wired
    // to these testbench signals. This is the same syntax you'll
    // use later to wire the ALU into the full datapath.
    alu dut (
        .a(a),
        .b(b),
        .alu_ctrl(alu_ctrl),
        .result(result),
        .zero(zero)
    );

    // Task = reusable procedure. Applies one test case and checks it.
    task check;
        input [31:0] expected;
        input [127:0] name; // just a label string for printing
        begin
            tests = tests + 1;
            #1; // wait 1 time unit for the combinational logic to settle
            if (result !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: a=%h b=%h ctrl=%b -> got=%h expected=%h",
                          name, a, b, alu_ctrl, result, expected);
            end else begin
                $display("PASS [%0s]: result=%h", name, result);
            end
        end
    endtask

    initial begin
        // ADD
        a = 32'd10; b = 32'd15; alu_ctrl = 4'b0000; check(32'd25, "ADD");

        // SUB
        a = 32'd20; b = 32'd8;  alu_ctrl = 4'b0001; check(32'd12, "SUB");

        // AND
        a = 32'hFF00FF00; b = 32'h0F0F0F0F; alu_ctrl = 4'b0010; check(32'h0F000F00, "AND");

        // OR
        a = 32'hFF00FF00; b = 32'h0F0F0F0F; alu_ctrl = 4'b0011; check(32'hFF0FFF0F, "OR");

        // XOR
        a = 32'hFFFFFFFF; b = 32'h0F0F0F0F; alu_ctrl = 4'b0100; check(32'hF0F0F0F0, "XOR");

        // SLL (shift left by 4)
        a = 32'h00000001; b = 32'd4; alu_ctrl = 4'b0101; check(32'h00000010, "SLL");

        // SRL (shift right logical by 4)
        a = 32'hF0000000; b = 32'd4; alu_ctrl = 4'b0110; check(32'h0F000000, "SRL");

        // SRA (shift right arithmetic, sign bit preserved)
        a = 32'hF0000000; b = 32'd4; alu_ctrl = 4'b0111; check(32'hFF000000, "SRA");

        // SLT (signed): -1 < 1 -> true
        a = 32'hFFFFFFFF; b = 32'd1; alu_ctrl = 4'b1000; check(32'd1, "SLT_neg_vs_pos");

        // SLT (signed): 5 < 3 -> false
        a = 32'd5; b = 32'd3; alu_ctrl = 4'b1000; check(32'd0, "SLT_false");

        // SLTU (unsigned): 0xFFFFFFFF is huge unsigned, not < 1
        a = 32'hFFFFFFFF; b = 32'd1; alu_ctrl = 4'b1001; check(32'd0, "SLTU_false");

        // zero flag check
        a = 32'd7; b = 32'd7; alu_ctrl = 4'b0001; #1; // SUB -> 0
        if (zero !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL [zero_flag]: expected zero=1, got zero=%b", zero);
        end else begin
            $display("PASS [zero_flag]: zero=%b", zero);
        end

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
