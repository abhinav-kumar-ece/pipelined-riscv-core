// =============================================================
// riscv_seq_item.sv
// One RV32I instruction, as a UVM sequence item.
// This is what flows: sequence -> driver -> DUT (via imem)
// =============================================================
class riscv_seq_item extends uvm_sequence_item;

    // Raw 32-bit encoded instruction, as it would appear in imem
    rand bit [31:0] instr;

    // Decoded fields (for readability / constraint convenience;
    // these are derived, not independently randomized)
    bit [6:0] opcode;
    bit [4:0] rd, rs1, rs2;
    bit [2:0] funct3;
    bit [6:0] funct7;
    bit [31:0] imm;

    `uvm_object_utils_begin(riscv_seq_item)
        `uvm_field_int(instr, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "riscv_seq_item");
        super.new(name);
    endfunction

    // Common RV32I opcode constraints so random instructions are
    // actually valid/meaningful (not garbage bit patterns)
    constraint valid_opcode_c {
        opcode inside {
            7'b0110011, // R-type (ADD, SUB, AND, OR, ...)
            7'b0010011, // I-type ALU (ADDI, ANDI, ...)
            7'b0000011, // LOAD
            7'b0100011, // STORE
            7'b1100011, // BRANCH
            7'b1101111, // JAL
            7'b1100111  // JALR
        };
    }

    // Decode after randomization so fields are always consistent
    // with the randomized instr value
    function void post_randomize();
        opcode = instr[6:0];
        rd     = instr[11:7];
        funct3 = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        funct7 = instr[31:25];
    endfunction

endclass
