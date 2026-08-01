// =============================================================
// riscv_agent.sv
// Bundles sequencer + driver + monitor for one interface.
// =============================================================
class riscv_agent extends uvm_agent;
    `uvm_component_utils(riscv_agent)

    uvm_sequencer #(riscv_seq_item) sqr;
    riscv_driver   drv;
    riscv_monitor  mon;

    function new(string name = "riscv_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(riscv_seq_item)::type_id::create("sqr", this);
        drv = riscv_driver::type_id::create("drv", this);
        mon = riscv_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass
