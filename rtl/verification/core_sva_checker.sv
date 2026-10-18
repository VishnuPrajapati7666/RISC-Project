module core_sva_checker (
  input logic clk,
  input logic reset,
  input rv32i_pkg::retire_t retire,
  input rv32i_pkg::dmem_req_t dmem_req,
  input rv32i_pkg::dmem_resp_t dmem_resp,
  input logic load_use_stall,
  input logic redirect,
  input rv32i_pkg::id_ex_reg_t id_ex_monitor,
  input rv32i_pkg::if_id_reg_t if_id_monitor,
  input logic [31:0] current_pc
);
  import rv32i_pkg::*;
  logic previous_dmem_valid;
  logic previous_dmem_write;
  logic [31:0] previous_dmem_addr;
  logic [3:0] previous_dmem_be;
  logic previous_retire_valid;
  logic [31:0] previous_retire_pc;

  always_ff @(posedge clk) begin
    if (reset) begin
      previous_dmem_valid <= 1'b0;
      previous_retire_valid <= 1'b0;
    end else begin
      if (retire.valid && retire.rd_write && retire.rd == 5'd0 &&
          retire.rd_value != 32'd0)
        $error("x0 writeback violation at PC %h", retire.pc);
      if (!retire.valid && retire.rd_write)
        $error("invalid instruction produced a register write");
      if (retire.valid && retire.pc == previous_retire_pc &&
          previous_retire_valid)
        $error("duplicate retirement at PC %h", retire.pc);
      if (dmem_req.valid && (dmem_req.addr[1:0] != 2'b00))
        $error("unaligned data-memory request at %h", dmem_req.addr);
      if (dmem_req.valid && dmem_req.byte_enable == 4'b0000)
        $error("memory request has no enabled byte lanes");
      if (previous_dmem_valid && dmem_resp.valid &&
          previous_dmem_write != dmem_req.write)
        $error("memory response ownership changed unexpectedly");
      if (load_use_stall && id_ex_monitor.valid)
        $error("load-use stall did not inject an ID/EX bubble");
      if (redirect && if_id_monitor.valid)
        $error("redirect did not invalidate the younger IF/ID instruction");

      previous_retire_valid <= retire.valid;
      previous_retire_pc <= retire.pc;
      previous_dmem_valid <= dmem_req.valid;
      previous_dmem_write <= dmem_req.write;
      previous_dmem_addr <= dmem_req.addr;
      previous_dmem_be <= dmem_req.byte_enable;
    end
  end
endmodule
