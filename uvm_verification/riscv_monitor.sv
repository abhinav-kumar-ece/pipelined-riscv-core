// =============================================================
// riscv_monitor.sv
// Passively watches DUT debug outputs every clock edge and
// packages what it sees into riscv_result_item transactions,
// broadcast to anyone listening (the scoreboard) via an
// analysis port. The monitor NEVER drives signals -- it only
// observes. This separation (driver drives, monitor observes)
// is a core UVM principle: it lets the same monitor be reused
// even in a pure "passive checking on real silicon" context.
// =============================================================
class riscv_monitor extends uvm_monitor;
    `uvm_component_utils(riscv_monitor)

    virtual riscv_if vif;

    // Analysis port: broadcasts observed transactions outward.
    // The scoreboard will subscribe to this.
    uvm_analysis_port #(riscv_result_item) ap;

    function new(string name = "riscv_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual riscv_if)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "Virtual interface not set in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        riscv_result_item item;

        forever begin
            @(vif.cb);

            item = riscv_result_item::type_id::create("item");

            item.pc        = vif.cb.debug_pc;
            item.reg_write = vif.cb.debug_reg_write_WB;
            item.rd_addr   = vif.cb.debug_rd_addr_WB;
            item.rd_data   = vif.cb.debug_rd_data_WB;

            item.mem_write = vif.cb.debug_mem_write_MEM;
            item.mem_addr  = vif.cb.debug_mem_addr_MEM;
            item.mem_wdata = vif.cb.debug_mem_wdata_MEM;

            // Only bother broadcasting cycles where something
            // actually happened -- keeps the scoreboard's job
            // simple (it doesn't have to filter out "nothing
            // happened this cycle" noise).
            if (item.reg_write || item.mem_write)
                ap.write(item);
        end
    endtask

endclass
