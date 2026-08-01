// =============================================================
// riscv_result_item.sv
// What the MONITOR observes coming OUT of the DUT each cycle:
// a register write-back event and/or a memory write event.
// This is a separate transaction type from riscv_seq_item
// (which represents what goes IN) -- input and output are
// different kinds of data, so they get different classes.
// =============================================================
class riscv_result_item extends uvm_sequence_item;

    bit [31:0] pc;

    // Register write-back (WB stage)
    bit        reg_write;
    bit [4:0]  rd_addr;
    bit [31:0] rd_data;

    // Memory write (MEM stage)
    bit        mem_write;
    bit [31:0] mem_addr;
    bit [31:0] mem_wdata;

    `uvm_object_utils_begin(riscv_result_item)
        `uvm_field_int(pc,        UVM_ALL_ON)
        `uvm_field_int(reg_write, UVM_ALL_ON)
        `uvm_field_int(rd_addr,   UVM_ALL_ON)
        `uvm_field_int(rd_data,   UVM_ALL_ON)
        `uvm_field_int(mem_write, UVM_ALL_ON)
        `uvm_field_int(mem_addr,  UVM_ALL_ON)
        `uvm_field_int(mem_wdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "riscv_result_item");
        super.new(name);
    endfunction

endclass
