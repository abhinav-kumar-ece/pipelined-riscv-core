// =============================================================
// riscv_env.sv
// Top-level verification environment: agent + scoreboard,
// wired together via TLM analysis ports.
// =============================================================
class riscv_env extends uvm_env;
    `uvm_component_utils(riscv_env)

    riscv_agent      agent;
    riscv_scoreboard sb;

    function new(string name = "riscv_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = riscv_agent::type_id::create("agent", this);
        sb    = riscv_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Monitor's observed results -> scoreboard
        agent.mon.ap.connect(sb.ap_imp);
        // Driver's issued instructions -> scoreboard (for program-order tracking)
        agent.drv.issued_ap.connect(sb.issued_imp);
    endfunction

endclass
