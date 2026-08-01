// =============================================================
// riscv_driver.sv
// Drives riscv_seq_item transactions into the DUT.
//
// NOTE ON APPROACH: riscv_pipelined_hazards' imem is read-only
// from the CPU's side (loaded once via $readmemh, no write port
// exists by design -- this matches real instruction memories).
// So the driver uses a BACKDOOR WRITE: it pokes new instructions
// directly into imem_inst.mem[] via hierarchical reference, then
// pulses the clock and lets the pipeline fetch/execute naturally.
// This is standard practice for verifying designs whose memories
// have no dedicated write port.
// =============================================================
class riscv_driver extends uvm_driver #(riscv_seq_item);
    `uvm_component_utils(riscv_driver)

    virtual riscv_if vif;
    uvm_analysis_port #(riscv_seq_item) issued_ap; // broadcasts issued instrs to scoreboard

    function new(string name = "riscv_driver", uvm_component parent = null);
        super.new(name, parent);
        issued_ap = new("issued_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual riscv_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRIVER", "Virtual interface not set in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        riscv_seq_item item;
        int write_addr = 0;

        // Hold reset for a couple cycles at start
        vif.cb.rst <= 1'b1;
        repeat (2) @(vif.cb);
        vif.cb.rst <= 1'b0;

        forever begin
            seq_item_port.get_next_item(item);

            // Backdoor: place this instruction at the next free
            // word slot in instruction memory. Hierarchical path
            // matches your top module's instance name (imem_inst).
            force_instr_into_imem(write_addr, item.instr);
            write_addr++;
            issued_ap.write(item); // tell scoreboard: this instruction is now in program order

            // Let the pipeline fetch/execute this cycle
            @(vif.cb);

            seq_item_port.item_done();
        end
    endtask

    // Backdoor memory poke -- hierarchical reference into the DUT.
    // Path assumes TB top instantiates DUT as "riscv_top.dut".
    // Adjust the path prefix to match your actual harness module.
    task force_instr_into_imem(int addr, bit [31:0] instr);
        riscv_top.dut.imem_inst.mem[addr] = instr;
    endtask

endclass
