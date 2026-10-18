module rv32i_soc_top #(
  parameter ENABLE_BPU = 1'b1,
  parameter USE_CACHES = 1'b0,
  parameter int MEMORY_BYTES = 16384,
  parameter int CACHE_LATENCY = 3
) (
  input logic clk,
  input logic reset,
  output logic retire_valid,
  output logic [31:0] retire_pc,
  output logic [31:0] retire_instr,
  output logic [4:0] retire_rd,
  output logic [31:0] retire_value,
  output logic retire_rd_write,
  output logic [63:0] mcycle,
  output logic [63:0] minstret,
  output logic [63:0] icache_misses,
  output logic [63:0] dcache_misses,
  output logic [63:0] dcache_writes,
  output logic [63:0] memory_transactions
);
  import rv32i_pkg::*;
  imem_req_t core_imem_req;
  imem_resp_t core_imem_resp;
  dmem_req_t core_dmem_req;
  dmem_resp_t core_dmem_resp;
  imem_resp_t uncached_imem_resp;
  dmem_resp_t uncached_dmem_resp;
  retire_t core_retire;
  logic [31:0] core_current_pc;
  if_id_reg_t core_if_id;
  id_ex_reg_t core_id_ex;
  ex_mem_reg_t core_ex_mem;
  mem_wb_reg_t core_mem_wb;
  logic [63:0] core_stalls, core_flushes;
  logic [1:0] core_forward_a, core_forward_b;
  logic core_load_use_stall, core_redirect;
  logic [63:0] core_pred_attempts, core_pred_correct, core_pred_misses;

  logic ic_cpu_ready, ic_resp_valid, ic_resp_error;
  logic [31:0] ic_resp_data;
  logic dc_cpu_ready, dc_resp_valid, dc_resp_error;
  logic [31:0] dc_resp_data;
  logic ic_mem_valid, ic_mem_ready, ic_mem_write;
  logic [31:0] ic_mem_addr;
  logic [127:0] ic_mem_wdata, ic_mem_resp_data;
  logic [15:0] ic_mem_be;
  logic ic_mem_resp_valid, ic_mem_resp_error;
  logic dc_mem_valid, dc_mem_ready, dc_mem_write;
  logic [31:0] dc_mem_addr;
  logic [127:0] dc_mem_wdata, dc_mem_resp_data;
  logic [15:0] dc_mem_be;
  logic dc_mem_resp_valid, dc_mem_resp_error;
  logic arb_mem_valid, arb_mem_ready, arb_mem_write;
  logic [31:0] arb_mem_addr;
  logic [127:0] arb_mem_wdata, arb_mem_resp_data;
  logic [15:0] arb_mem_be;
  logic arb_resp_valid, arb_resp_error;
  logic ctrl_mem_valid, ctrl_mem_ready, ctrl_mem_write;
  logic [31:0] ctrl_mem_addr;
  logic [127:0] ctrl_mem_wdata, ctrl_mem_resp_data;
  logic [15:0] ctrl_mem_be;
  logic ctrl_resp_valid, ctrl_resp_error;
  logic [63:0] memory_transactions_reg;

  pipeline_core #(.ENABLE_BPU(ENABLE_BPU)) core (
    .clk(clk), .reset(reset), .imem_resp(core_imem_resp),
    .imem_req(core_imem_req), .dmem_resp(core_dmem_resp),
    .dmem_req(core_dmem_req), .retire(core_retire), .mcycle(mcycle),
    .minstret(minstret), .current_pc(core_current_pc),
    .if_id_monitor(core_if_id), .id_ex_monitor(core_id_ex),
    .ex_mem_monitor(core_ex_mem), .mem_wb_monitor(core_mem_wb),
    .stall_cycles(core_stalls), .flush_cycles(core_flushes),
    .forward_a_monitor(core_forward_a), .forward_b_monitor(core_forward_b),
    .load_use_stall_monitor(core_load_use_stall),
    .redirect_monitor(core_redirect),
    .prediction_attempts(core_pred_attempts),
    .prediction_correct(core_pred_correct),
    .prediction_mispredicts(core_pred_misses)
  );
  reference_memory #(.WORDS(MEMORY_BYTES/4)) uncached_mem (
    .clk(clk), .reset(reset), .imem_req(core_imem_req),
    .imem_resp(uncached_imem_resp), .dmem_req(core_dmem_req),
    .dmem_resp(uncached_dmem_resp)
  );

  generate
    if (USE_CACHES) begin : g_cached
  icache ic (
    .clk(clk), .reset(reset), .cpu_req_valid(USE_CACHES && core_imem_req.valid),
    .cpu_req_ready(ic_cpu_ready), .cpu_req_addr(core_imem_req.addr),
    .cpu_resp_valid(ic_resp_valid), .cpu_resp_rdata(ic_resp_data),
    .cpu_resp_error(ic_resp_error), .mem_req_valid(ic_mem_valid),
    .mem_req_ready(ic_mem_ready), .mem_req_addr(ic_mem_addr),
    .mem_req_write(ic_mem_write), .mem_req_wdata(ic_mem_wdata),
    .mem_req_be(ic_mem_be), .mem_resp_valid(ic_mem_resp_valid),
    .mem_resp_rdata(ic_mem_resp_data), .mem_resp_error(ic_mem_resp_error),
    .miss_count(icache_misses)
  );
  dcache dc (
    .clk(clk), .reset(reset), .cpu_req_valid(USE_CACHES && core_dmem_req.valid),
    .cpu_req_ready(dc_cpu_ready), .cpu_req_write(core_dmem_req.write),
    .cpu_req_addr(core_dmem_req.addr), .cpu_req_wdata(core_dmem_req.wdata),
    .cpu_req_be(core_dmem_req.byte_enable), .cpu_resp_valid(dc_resp_valid),
    .cpu_resp_rdata(dc_resp_data), .cpu_resp_error(dc_resp_error),
    .mem_req_valid(dc_mem_valid), .mem_req_ready(dc_mem_ready),
    .mem_req_addr(dc_mem_addr), .mem_req_write(dc_mem_write),
    .mem_req_wdata(dc_mem_wdata), .mem_req_be(dc_mem_be),
    .mem_resp_valid(dc_mem_resp_valid), .mem_resp_rdata(dc_mem_resp_data),
    .mem_resp_error(dc_mem_resp_error), .miss_count(dcache_misses),
    .write_count(dcache_writes)
  );
  cache_arbiter arb (
    .clk(clk), .reset(reset), .i_req_valid(ic_mem_valid),
    .i_req_ready(ic_mem_ready), .i_req_addr(ic_mem_addr),
    .i_req_write(ic_mem_write), .i_req_wdata(ic_mem_wdata),
    .i_req_be(ic_mem_be), .i_resp_valid(ic_mem_resp_valid),
    .i_resp_rdata(ic_mem_resp_data), .i_resp_error(ic_mem_resp_error),
    .d_req_valid(dc_mem_valid), .d_req_ready(dc_mem_ready),
    .d_req_addr(dc_mem_addr), .d_req_write(dc_mem_write),
    .d_req_wdata(dc_mem_wdata), .d_req_be(dc_mem_be),
    .d_resp_valid(dc_mem_resp_valid), .d_resp_rdata(dc_mem_resp_data),
    .d_resp_error(dc_mem_resp_error), .mem_req_valid(arb_mem_valid),
    .mem_req_ready(arb_mem_ready), .mem_req_addr(arb_mem_addr),
    .mem_req_write(arb_mem_write), .mem_req_wdata(arb_mem_wdata),
    .mem_req_be(arb_mem_be), .mem_resp_valid(arb_resp_valid),
    .mem_resp_rdata(arb_mem_resp_data), .mem_resp_error(arb_resp_error)
  );
  memory_controller ctrl (
    .clk(clk), .reset(reset), .req_valid(arb_mem_valid),
    .req_ready(arb_mem_ready), .req_addr(arb_mem_addr),
    .req_write(arb_mem_write), .req_wdata(arb_mem_wdata),
    .req_be(arb_mem_be), .resp_valid(arb_resp_valid),
    .resp_rdata(arb_mem_resp_data), .resp_error(arb_resp_error),
    .mem_req_valid(ctrl_mem_valid), .mem_req_ready(ctrl_mem_ready),
    .mem_req_addr(ctrl_mem_addr), .mem_req_write(ctrl_mem_write),
    .mem_req_wdata(ctrl_mem_wdata), .mem_req_be(ctrl_mem_be),
    .mem_resp_valid(ctrl_resp_valid), .mem_resp_rdata(ctrl_mem_resp_data),
    .mem_resp_error(ctrl_resp_error)
  );
  main_memory_model #(.BYTES(MEMORY_BYTES), .LATENCY(CACHE_LATENCY)) main_mem (
    .clk(clk), .reset(reset), .req_valid(ctrl_mem_valid),
    .req_ready(ctrl_mem_ready), .req_addr(ctrl_mem_addr),
    .req_write(ctrl_mem_write), .req_wdata(ctrl_mem_wdata),
    .req_be(ctrl_mem_be), .resp_valid(ctrl_resp_valid),
    .resp_rdata(ctrl_mem_resp_data), .resp_error(ctrl_resp_error)
  );
    end
  endgenerate

  always_comb begin
    core_imem_resp = '0;
    core_dmem_resp = '0;
    core_imem_resp = uncached_imem_resp;
    core_dmem_resp = uncached_dmem_resp;
    if (USE_CACHES) begin
      core_imem_resp.valid = ic_resp_valid;
      core_imem_resp.rdata = ic_resp_data;
      core_imem_resp.ready = 1'b1;
      core_dmem_resp.valid = dc_resp_valid;
      core_dmem_resp.rdata = dc_resp_data;
      core_dmem_resp.ready = dc_cpu_ready;
    end
  end
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      memory_transactions_reg <= 64'd0;
    else if (USE_CACHES && ctrl_mem_valid && ctrl_mem_ready)
      memory_transactions_reg <= memory_transactions_reg + 64'd1;
  end
  assign memory_transactions = memory_transactions_reg;
  assign retire_valid = core_retire.valid;
  assign retire_pc = core_retire.pc;
  assign retire_instr = core_retire.instr;
  assign retire_rd = core_retire.rd;
  assign retire_value = core_retire.rd_value;
  assign retire_rd_write = core_retire.rd_write;
endmodule
