// =============================================================
// riscv_scoreboard.sv
//
// The reference model: a simple, purely functional (non-pipelined,
// non-timed) model of RV32I execution. It tracks what the
// architectural register file SHOULD contain, instruction by
// instruction, in program order.
//
// The scoreboard's job: for every write-back the MONITOR observes
// coming out of the real pipelined DUT, check it against what
// this reference model predicts. Any mismatch = a real bug in
// the pipeline's forwarding/hazard logic (or the RTL generally).
//
// NOTE: this reference model currently supports R-type ALU ops,
// I-type ALU ops, and LW/SW -- enough to check the directed
// hazard_seq scenarios. Extending it to the full RV32I ISA
// (branches, JAL/JALR, all funct3/funct7 combinations) would be
// the natural next step for full-coverage verification.
// =============================================================
// Declares a second, distinctly-named analysis_imp type so this
// scoreboard can subscribe to TWO different analysis ports (one
// from the monitor, one from the driver) without a write() clash.
`uvm_analysis_imp_decl(_issued)

class riscv_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(riscv_scoreboard)

    uvm_analysis_imp #(riscv_result_item, riscv_scoreboard) ap_imp;          // from monitor
    uvm_analysis_imp_issued #(riscv_seq_item, riscv_scoreboard) issued_imp;  // from driver

    // Reference architectural register file (the "golden" state)
    bit [31:0] ref_regfile [0:31];

    // Reference data memory (mirrors dmem for store checking)
    bit [31:0] ref_dmem [0:255];

    // Queue of instructions the driver has issued, in program
    // order, so we know what SHOULD retire next.
    bit [31:0] pending_instrs[$];

    int pass_count = 0;
    int fail_count = 0;

    function new(string name = "riscv_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_imp     = new("ap_imp", this);
        issued_imp = new("issued_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        foreach (ref_regfile[i]) ref_regfile[i] = 32'b0;
        foreach (ref_dmem[i])    ref_dmem[i]    = 32'b0;
    endfunction

    // Analysis_imp callback for the DRIVER's issued_ap: fires each
    // time a new instruction is issued into program order.
    function void write_issued(riscv_seq_item t);
        pending_instrs.push_back(t.instr);
    endfunction

    // UVM analysis_imp callback: fires every time the MONITOR
    // broadcasts an observed write-back/memory-write event.
    function void write(riscv_result_item t);
        bit [31:0] expected_instr;
        bit [6:0]  opcode;
        bit [4:0]  rd, rs1, rs2;
        bit [2:0]  funct3;
        bit [6:0]  funct7;
        bit [31:0] imm_i;
        bit [31:0] expected_val;

        if (pending_instrs.size() == 0) begin
            `uvm_warning("SCOREBOARD", "Observed write-back with no pending instruction to check against")
            return;
        end

        expected_instr = pending_instrs.pop_front();
        opcode = expected_instr[6:0];
        rd     = expected_instr[11:7];
        funct3 = expected_instr[14:12];
        rs1    = expected_instr[19:15];
        rs2    = expected_instr[24:20];
        funct7 = expected_instr[31:25];
        imm_i  = {{20{expected_instr[31]}}, expected_instr[31:20]}; // sign-extended I-imm

        case (opcode)
            7'b0110011: begin // R-type
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: expected_val = ref_regfile[rs1] + ref_regfile[rs2]; // ADD
                    {7'b0100000, 3'b000}: expected_val = ref_regfile[rs1] - ref_regfile[rs2]; // SUB
                    {7'b0000000, 3'b111}: expected_val = ref_regfile[rs1] & ref_regfile[rs2]; // AND
                    {7'b0000000, 3'b110}: expected_val = ref_regfile[rs1] | ref_regfile[rs2]; // OR
                    default: expected_val = 32'hDEAD_BEEF; // unmodeled R-type variant
                endcase
                if (rd != 5'b0) ref_regfile[rd] = expected_val;
            end

            7'b0010011: begin // I-type ALU (e.g. ADDI)
                expected_val = ref_regfile[rs1] + imm_i;
                if (rd != 5'b0) ref_regfile[rd] = expected_val;
            end

            7'b0000011: begin // LOAD (LW)
                expected_val = ref_dmem[(ref_regfile[rs1] + imm_i) >> 2];
                if (rd != 5'b0) ref_regfile[rd] = expected_val;
            end

            7'b0100011: begin // STORE (SW) -- no register write-back
                expected_val = 32'bx; // not applicable
            end

            default: expected_val = 32'hDEAD_BEEF; // unmodeled opcode
        endcase

        // ---- Check register write-back ----
        if (t.reg_write) begin
            if (rd == 5'b0) begin
                // x0 writes are architecturally discarded -- nothing to check
            end else if (t.rd_addr !== rd) begin
                `uvm_error("SCOREBOARD",
                    $sformatf("rd_addr MISMATCH: DUT wrote x%0d, expected x%0d", t.rd_addr, rd))
                fail_count++;
            end else if (t.rd_data !== expected_val) begin
                `uvm_error("SCOREBOARD",
                    $sformatf("DATA MISMATCH on x%0d: DUT=0x%0h, expected=0x%0h",
                              rd, t.rd_data, expected_val))
                fail_count++;
            end else begin
                `uvm_info("SCOREBOARD",
                    $sformatf("PASS: x%0d = 0x%0h", rd, t.rd_data), UVM_LOW)
                pass_count++;
            end
        end

        // ---- Check memory write-back (stores) ----
        if (t.mem_write) begin
            bit [31:0] expected_addr = ref_regfile[rs1] + imm_i;
            ref_dmem[expected_addr >> 2] = ref_regfile[rs2]; // update golden model
            if (t.mem_addr !== expected_addr || t.mem_wdata !== ref_regfile[rs2]) begin
                `uvm_error("SCOREBOARD",
                    $sformatf("STORE MISMATCH: DUT addr=0x%0h data=0x%0h, expected addr=0x%0h data=0x%0h",
                              t.mem_addr, t.mem_wdata, expected_addr, ref_regfile[rs2]))
                fail_count++;
            end else begin
                pass_count++;
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD",
            $sformatf("=== FINAL RESULT: %0d PASS, %0d FAIL ===", pass_count, fail_count),
            UVM_NONE)
    endfunction

endclass
