// =============================================================
// dmem_tb.v — testbench for dmem.v
// Tests store/load at byte, halfword, and word granularity,
// plus sign extension (LB/LH) vs zero extension (LBU/LHU).
// =============================================================
`timescale 1ns / 1ps

module dmem_tb;

    reg         clk;
    reg  [31:0] addr;
    reg  [31:0] write_data;
    reg         mem_write;
    reg  [2:0]  funct3;
    wire [31:0] read_data;

    integer errors = 0;
    integer tests  = 0;

    dmem dut (
        .clk(clk),
        .addr(addr),
        .write_data(write_data),
        .mem_write(mem_write),
        .funct3(funct3),
        .read_data(read_data)
    );

    always #5 clk = ~clk;

    task check;
        input [31:0] expected;
        input [127:0] name;
        begin
            tests = tests + 1;
            #1;
            if (read_data !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: read_data=%h expected=%h", name, read_data, expected);
            end else begin
                $display("PASS [%0s]: read_data=%h", name, read_data);
            end
        end
    endtask

    initial begin
        clk = 0; mem_write = 0; addr = 0; write_data = 0; funct3 = 0;

        // ---- SW then LW: store a full word at address 0, read it back ----
        @(negedge clk);
        addr = 32'd0; write_data = 32'hDEADBEEF; funct3 = 3'b010; mem_write = 1; // SW
        @(negedge clk);
        mem_write = 0;
        funct3 = 3'b010; // LW
        check(32'hDEADBEEF, "SW_then_LW");

        // ---- SB then LBU: store a single byte, read unsigned ----
        @(negedge clk);
        addr = 32'd10; write_data = 32'h000000AB; funct3 = 3'b000; mem_write = 1; // SB
        @(negedge clk);
        mem_write = 0;
        funct3 = 3'b100; // LBU
        check(32'h000000AB, "SB_then_LBU");

        // ---- Same byte read as LB (signed): 0xAB has top bit set -> sign-extends to 0xFFFFFFAB ----
        funct3 = 3'b000; // LB
        check(32'hFFFFFFAB, "SB_then_LB_signed");

        // ---- SH then LHU: store a halfword, read unsigned ----
        @(negedge clk);
        addr = 32'd20; write_data = 32'h00007FFF; funct3 = 3'b001; mem_write = 1; // SH
        @(negedge clk);
        mem_write = 0;
        funct3 = 3'b101; // LHU
        check(32'h00007FFF, "SH_then_LHU");

        // ---- Halfword with sign bit set: 0x8000 -> sign-extends to 0xFFFF8000 ----
        @(negedge clk);
        addr = 32'd24; write_data = 32'h00008000; funct3 = 3'b001; mem_write = 1; // SH
        @(negedge clk);
        mem_write = 0;
        funct3 = 3'b001; // LH
        check(32'hFFFF8000, "SH_then_LH_signed");

        $display("----------------------------------------");
        $display("TESTS RUN: %0d   FAILURES: %0d", tests, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
