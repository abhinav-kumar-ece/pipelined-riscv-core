// =============================================================
// riscv_test.sv
// Top-level test: builds the env, then runs a chosen sequence
// against it. Different tests = different sequences, same env.
// =============================================================
class riscv_hazard_test extends uvm_test;
    `uvm_component_utils(riscv_hazard_test)

    riscv_env env;

    function new(string name = "riscv_hazard_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = riscv_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        riscv_hazard_seq seq;
        phase.raise_objection(this);

        seq = riscv_hazard_seq::type_id::create("seq");
        seq.start(env.agent.sqr);

        // Let the pipeline drain (5 stages) after the last
        // instruction is issued, so its write-back is observed
        // before we end the test.
        repeat (10) @(env.agent.mon.vif.cb);

        phase.drop_objection(this);
    endtask

endclass
