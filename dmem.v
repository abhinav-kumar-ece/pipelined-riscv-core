// =============================================================
// dmem.v — Data memory for RV32I loads/stores
// Byte-addressable, supports byte/halfword/word width, and
// sign/zero extension for loads, per the RISC-V funct3 encoding.
//
// funct3 for loads:  000=LB  001=LH  010=LW  100=LBU  101=LHU
// funct3 for stores: 000=SB  001=SH  010=SW
// =============================================================
module dmem #(
    parameter DEPTH_BYTES = 1024   // 1KB of byte-addressable memory
)(
    input  wire        clk,
    input  wire [31:0] addr,        // byte address
    input  wire [31:0] write_data,
    input  wire        mem_write,   // 1 = perform a store this cycle
    input  wire [2:0]  funct3,      // access size + signedness
    output reg  [31:0] read_data    // combinational read, always valid
);

    // Byte-addressable storage: simplest way to correctly support
    // byte/halfword/word access without manual byte-lane muxing logic.
    reg [7:0] mem [0:DEPTH_BYTES-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH_BYTES; i = i + 1)
            mem[i] = 8'b0;
    end

    // ---- Synchronous write ----
    always @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB - store byte
                    mem[addr] <= write_data[7:0];
                end
                3'b001: begin // SH - store halfword
                    mem[addr]   <= write_data[7:0];
                    mem[addr+1] <= write_data[15:8];
                end
                3'b010: begin // SW - store word
                    mem[addr]   <= write_data[7:0];
                    mem[addr+1] <= write_data[15:8];
                    mem[addr+2] <= write_data[23:16];
                    mem[addr+3] <= write_data[31:24];
                end
                default: ; // undefined funct3 for a store -- do nothing
            endcase
        end
    end

    // ---- Combinational read with sign/zero extension ----
    always @(*) begin
        case (funct3)
            3'b000: read_data = {{24{mem[addr][7]}}, mem[addr]};                  // LB  (sign-extend)
            3'b001: read_data = {{16{mem[addr+1][7]}}, mem[addr+1], mem[addr]};   // LH  (sign-extend)
            3'b010: read_data = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]}; // LW
            3'b100: read_data = {24'b0, mem[addr]};                              // LBU (zero-extend)
            3'b101: read_data = {16'b0, mem[addr+1], mem[addr]};                 // LHU (zero-extend)
            default: read_data = 32'b0;
        endcase
    end

endmodule
