module stage5_bpu_tb;
  import rv32i_pkg::*;

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic bpu_resolve_valid;
  logic [31:0] bpu_fetch_pc, bpu_fetch_instr;
  logic [31:0] bpu_resolve_pc, bpu_resolve_target;
  logic bpu_resolve_taken, bpu_resolve_conditional, bpu_resolve_jump;
  logic [31:0] bpu_next_pc, bpu_target;
  logic bpu_pred_taken, bpu_pred_valid, bpu_hit;

  bpu predictor (
    .clk(clk), .reset(reset), .fetch_pc(bpu_fetch_pc),
    .fetch_instr(bpu_fetch_instr), .predicted_next_pc(bpu_next_pc),
    .predicted_target(bpu_target), .predicted_taken(bpu_pred_taken),
    .prediction_valid(bpu_pred_valid), .btb_hit(bpu_hit),
    .resolve_valid(bpu_resolve_valid), .resolve_pc(bpu_resolve_pc),
    .resolve_target(bpu_resolve_target), .resolve_taken(bpu_resolve_taken),
    .resolve_conditional(bpu_resolve_conditional),
    .resolve_jump(bpu_resolve_jump)
  );

  logic ref_reset, pred_reset;
  imem_req_t ref_imem_req, pred_imem_req;
  imem_resp_t ref_imem_resp, pred_imem_resp;
  dmem_req_t ref_dmem_req, pred_dmem_req;
  dmem_resp_t ref_dmem_resp, pred_dmem_resp;
  retire_t ref_retire, pred_retire;
  logic [63:0] ref_cycle, ref_retired, pred_cycle, pred_retired;
  logic [31:0] ref_pc, pred_pc;
  logic [63:0] ref_stalls, ref_flushes, pred_stalls, pred_flushes;
  logic [63:0] ref_attempts, ref_correct, ref_misses;
  logic [63:0] pred_attempts, pred_correct, pred_misses;
  logic [1:0] ref_fa, ref_fb, pred_fa, pred_fb;
  logic ref_lu, ref_redirect, pred_lu, pred_redirect;
  if_id_reg_t ref_ifid, pred_ifid;
  id_ex_reg_t ref_idex, pred_idex;
  ex_mem_reg_t ref_exmem, pred_exmem;
  mem_wb_reg_t ref_memwb, pred_memwb;
  logic [31:0] image [0:63];
  integer i;
  real measured_accuracy;

  pipeline_core #(.ENABLE_BPU(1'b0)) reference (
    .clk(clk), .reset(ref_reset), .imem_resp(ref_imem_resp),
    .imem_req(ref_imem_req), .dmem_resp(ref_dmem_resp),
    .dmem_req(ref_dmem_req), .retire(ref_retire),
    .mcycle(ref_cycle), .minstret(ref_retired), .current_pc(ref_pc),
    .if_id_monitor(ref_ifid), .id_ex_monitor(ref_idex),
    .ex_mem_monitor(ref_exmem), .mem_wb_monitor(ref_memwb),
    .stall_cycles(ref_stalls), .flush_cycles(ref_flushes),
    .forward_a_monitor(ref_fa), .forward_b_monitor(ref_fb),
    .load_use_stall_monitor(ref_lu), .redirect_monitor(ref_redirect),
    .prediction_attempts(ref_attempts),
    .prediction_correct(ref_correct),
    .prediction_mispredicts(ref_misses)
  );
  pipeline_core #(.ENABLE_BPU(1'b1)) predicted (
    .clk(clk), .reset(pred_reset), .imem_resp(pred_imem_resp),
    .imem_req(pred_imem_req), .dmem_resp(pred_dmem_resp),
    .dmem_req(pred_dmem_req), .retire(pred_retire),
    .mcycle(pred_cycle), .minstret(pred_retired), .current_pc(pred_pc),
    .if_id_monitor(pred_ifid), .id_ex_monitor(pred_idex),
    .ex_mem_monitor(pred_exmem), .mem_wb_monitor(pred_memwb),
    .stall_cycles(pred_stalls), .flush_cycles(pred_flushes),
    .forward_a_monitor(pred_fa), .forward_b_monitor(pred_fb),
    .load_use_stall_monitor(pred_lu), .redirect_monitor(pred_redirect),
    .prediction_attempts(pred_attempts),
    .prediction_correct(pred_correct),
    .prediction_mispredicts(pred_misses)
  );
  reference_memory #(.WORDS(256)) ref_mem (
    .clk(clk), .reset(ref_reset), .imem_req(ref_imem_req),
    .imem_resp(ref_imem_resp), .dmem_req(ref_dmem_req),
    .dmem_resp(ref_dmem_resp)
  );
  reference_memory #(.WORDS(256)) pred_mem (
    .clk(clk), .reset(pred_reset), .imem_req(pred_imem_req),
    .imem_resp(pred_imem_resp), .dmem_req(pred_dmem_req),
    .dmem_resp(pred_dmem_resp)
  );

  always #5 clk = ~clk;

  task automatic resolve_branch(input logic taken);
    begin
      @(negedge clk);
      bpu_resolve_valid = 1'b1;
      bpu_resolve_pc = 32'd0;
      bpu_resolve_target = 32'd64;
      bpu_resolve_taken = taken;
      bpu_resolve_conditional = 1'b1;
      bpu_resolve_jump = 1'b0;
      @(negedge clk);
      bpu_resolve_valid = 1'b0;
    end
  endtask

  initial begin
    ref_reset = 1'b1;
    pred_reset = 1'b1;
    bpu_resolve_valid = 1'b0;
    bpu_resolve_pc = 32'd0;
    bpu_resolve_target = 32'd64;
    bpu_resolve_taken = 1'b0;
    bpu_resolve_conditional = 1'b0;
    bpu_resolve_jump = 1'b0;
    bpu_fetch_pc = 32'd0;
    bpu_fetch_instr = 32'h0000_0063;

    repeat (2) @(posedge clk);
    #1;
    if (predictor.bht[0] !== 2'b01)
      $fatal(1, "BHT reset state mismatch");
    reset = 1'b0;
    resolve_branch(1'b1);
    if (predictor.bht[0] !== 2'b10)
      $fatal(1, "BHT taken transition 01->10 failed");
    if (!predictor.btb_valid[0] || predictor.btb_target[0] !== 32'd64 ||
        predictor.btb_tag[0] !== 24'd0)
      $fatal(1, "BTB update mismatch");
    resolve_branch(1'b1);
    if (predictor.bht[0] !== 2'b11)
      $fatal(1, "BHT taken transition 10->11 failed");
    resolve_branch(1'b1);
    if (predictor.bht[0] !== 2'b11)
      $fatal(1, "BHT upper saturation failed");
    #1;
    if (!bpu_pred_taken || bpu_next_pc !== 32'd64)
      $fatal(1, "strong-taken prediction mismatch");
    resolve_branch(1'b0);
    if (predictor.bht[0] !== 2'b10)
      $fatal(1, "BHT not-taken transition 11->10 failed");
    resolve_branch(1'b0);
    resolve_branch(1'b0);
    if (predictor.bht[0] !== 2'b00)
      $fatal(1, "BHT lower saturation failed");
    #1;
    if (bpu_pred_taken || bpu_next_pc !== 32'd4)
      $fatal(1, "strong-not-taken prediction mismatch");

    $readmemh("tb/programs/stage5_branches.hex", image);
    for (i = 0; i < 64; i = i + 1) begin
      ref_mem.mem[i*4] = image[i][7:0];
      ref_mem.mem[i*4+1] = image[i][15:8];
      ref_mem.mem[i*4+2] = image[i][23:16];
      ref_mem.mem[i*4+3] = image[i][31:24];
      pred_mem.mem[i*4] = image[i][7:0];
      pred_mem.mem[i*4+1] = image[i][15:8];
      pred_mem.mem[i*4+2] = image[i][23:16];
      pred_mem.mem[i*4+3] = image[i][31:24];
    end
    ref_reset = 1'b0;
    pred_reset = 1'b0;
    repeat (90) @(posedge clk);

    for (i = 0; i < 32; i = i + 1)
      if (reference.u_regfile.regs[i] !== predicted.u_regfile.regs[i])
        $fatal(1, "architectural register mismatch x%0d ref=%h pred=%h",
               i, reference.u_regfile.regs[i], predicted.u_regfile.regs[i]);
    for (i = 0; i < 256*4; i = i + 1)
      if (ref_mem.mem[i] !== pred_mem.mem[i])
        $fatal(1, "architectural memory mismatch byte %0d", i);

    if (predicted.u_regfile.regs[1] !== 32'd3 ||
        predicted.u_regfile.regs[2] !== 32'd3 ||
        predicted.u_regfile.regs[3] !== 32'd3 ||
        predicted.u_regfile.regs[4] !== 32'd7 ||
        predicted.u_regfile.regs[5] !== 32'd5 ||
        predicted.u_regfile.regs[7] !== 32'd7)
      $fatal(1, "branch benchmark final state mismatch");
    if (pred_attempts == 0 || pred_misses == 0 || pred_correct == 0)
      $fatal(1, "prediction statistics were not recorded");
    if (pred_flushes >= ref_flushes)
      $fatal(1, "predictor did not reduce recovery flushes");

    measured_accuracy = (100.0 * pred_correct) / pred_attempts;
    $display("stage5_bpu_tb PASS: baseline_cycles=%0d predicted_cycles=%0d attempts=%0d correct=%0d mispredicts=%0d baseline_flushes=%0d predicted_flushes=%0d",
             ref_cycle, pred_cycle, pred_attempts, pred_correct, pred_misses,
             ref_flushes, pred_flushes);
    $display("measured conditional-branch prediction accuracy=%0.2f%%",
             measured_accuracy);
    $finish;
  end
endmodule
