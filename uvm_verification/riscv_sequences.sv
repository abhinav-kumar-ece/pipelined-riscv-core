// =============================================================
// riscv_sequences.sv
// Sequences generate streams of riscv_seq_item transactions.
// =============================================================

// ---- Sequence 1: basic constrained-random instructions ----
class riscv_random_seq extends uvm_sequence #(riscv_seq_item);
    `uvm_object_utils(riscv_random_seq)

    int num_instrs = 20;

    function new(string name = "riscv_random_seq");
        super.new(name);
    endfunction

    task body();
        riscv_seq_item item;
        repeat (num_instrs) begin
            item = riscv_seq_item::type_id::create("item");
            start_item(item);
            assert(item.randomize());
            finish_item(item);
        end
    endtask
endclass


// ---- Sequence 2: directed hazard-stress sequence ----
// Purpose: deliberately create back-to-back register dependencies
// (RAW hazards) so the forwarding unit and hazard detection logic
// get exercised, not just "random" traffic that might miss them.
class riscv_hazard_seq extends uvm_sequence #(riscv_seq_item);
    `uvm_object_utils(riscv_hazard_seq)

    function new(string name = "riscv_hazard_seq");
        super.new(name);
    endfunction

    // Helper: build an R-type instruction (e.g. ADD rd, rs1, rs2)
    function bit [31:0] make_rtype(bit [4:0] rd, rs1, rs2,
                                    bit [2:0] funct3, bit [6:0] funct7);
        return {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

    // Helper: build a LOAD instruction (LW rd, imm(rs1))
    function bit [31:0] make_load(bit [4:0] rd, rs1, bit [11:0] imm);
        return {imm, rs1, 3'b010, rd, 7'b0000011};
    endfunction

    task body();
        riscv_seq_item item;
        bit [31:0] instr_list[$];

        // Case 1: back-to-back ALU dependency (tests EX/MEM forwarding)
        // ADD x3, x1, x2      -> x3 written in EX
        // ADD x4, x3, x1      -> immediately needs x3 (no bubble should occur)
        instr_list.push_back(make_rtype(5'd3, 5'd1, 5'd2, 3'b000, 7'b0000000));
        instr_list.push_back(make_rtype(5'd4, 5'd3, 5'd1, 3'b000, 7'b0000000));

        // Case 2: load-use hazard (tests stall logic, the one case
        // forwarding alone can't fix)
        // LW x5, 0(x1)        -> x5 loaded from memory
        // ADD x6, x5, x1      -> needs x5 immediately -> MUST stall 1 cycle
        instr_list.push_back(make_load(5'd5, 5'd1, 12'd0));
        instr_list.push_back(make_rtype(5'd6, 5'd5, 5'd1, 3'b000, 7'b0000000));

        // Case 3: two-instruction-back dependency (tests MEM/WB forwarding)
        // ADD x7, x1, x2
        // ADDI x0, x0, 0      -> unrelated bubble instruction
        // ADD x8, x7, x1      -> needs x7 from two instructions back
        instr_list.push_back(make_rtype(5'd7, 5'd1, 5'd2, 3'b000, 7'b0000000));
        instr_list.push_back({12'd0, 5'd0, 3'b000, 5'd0, 7'b0010011}); // ADDI x0,x0,0 (NOP)
        instr_list.push_back(make_rtype(5'd8, 5'd7, 5'd1, 3'b000, 7'b0000000));

        foreach (instr_list[i]) begin
            item = riscv_seq_item::type_id::create("item");
            start_item(item);
            item.instr = instr_list[i];
            // Skip randomize() here -- we want these EXACT instructions
            finish_item(item);
        end
    endtask
endclass
