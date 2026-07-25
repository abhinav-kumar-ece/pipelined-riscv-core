// Testbench for register file — verifies read/write behavior
// =============================================================
// regfile_tb.v — self-checking testbench for regfile.v
// =============================================================
`timescale 1ns / 1ps

module regfile_tb;

    reg         clk;
    reg         we;
    reg  [4:0]  rs1_addr, rs2_addr, rd_addr;
    reg  [31:0] rd_data;
    wire [31:0] rs1_data, rs2_data;

    integer errors = 0;
    integer tests  = 0;

    regfile dut (
        .clk(clk),
        .we(we),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // Clock generator: toggle every 5ns -> 10ns period (100MHz)
    always #5 clk = ~clk;

    task check_rs1;
        input [31:0] expected;
        input [127:0] name;
        begin
            tests = tests + 1;
            if (rs1_data !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: rs1_data=%h expected=%h", name, rs1_data, expected);
            end else begin
                $display("PASS [%0s]: rs1_data=%h", name, rs1_data);
            end
        end
    endtask

    initial begin
        clk = 0;
        we  = 0;
        rs1_addr = 0; rs2_addr = 0; rd_addr = 0; rd_data = 0;

        // Test 1: x0 always reads zero, even if we try to write it
        @(negedge clk);
        rd_addr = 5'd0; rd_data = 32'hFFFFFFFF; we = 1;
        @(negedge clk); // let the write attempt happen on the posedge in between
        we = 0;
        rs1_addr = 5'd0;
        #1 check_rs1(32'd0, "x0_always_zero");

        // Test 2: write x5 = 123, then read it back on rs1
        @(negedge clk);
        rd_addr = 5'd5; rd_data = 32'd123; we = 1;
        @(negedge clk);
        we = 0;
        rs1_addr = 5'd5;
        #1 check_rs1(32'd123, "write_then_read_x5");

        // Test 3: write x10 = 999, read simultaneously on rs1 and rs2
        @(negedge clk);
        rd_addr = 5'd10; rd_data = 32'd999; we = 1;
        @(negedge clk);
        we = 0;
        rs1_addr = 5'd10; rs2_addr = 5'd5; // rs2 should still show x5=123 from before
        #1;
        tests = tests + 1;
        if (rs1_data !== 32'd999 || rs2_data !== 32'd123) begin
            errors = errors + 1;
            $display("FAIL [dual_read]: rs1=%0d rs2=%0d expected rs1=999 rs2=123",
                       rs1_data, rs2_data);
        end else begin
            $display("PASS [dual_read]: rs1=%0d rs2=%0d", rs1_data, rs2_data);
        end

        // Test 4: write enable low -> write must NOT happen
        @(negedge clk);
        rd_addr = 5'd7; rd_data = 32'd555; we = 0; // we is OFF
        @(negedge clk);
        rs1_addr = 5'd7;
        #1 check_rs1(32'd0, "we_low_blocks_write");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
