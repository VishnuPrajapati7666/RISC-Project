module stage4_hazard_tb;
  import rv32i_pkg::*;

  logic clk = 1'b0;
  logic reset = 1'b1;
  imem_req_t ref_imem_req, pipe_imem_req;
  imem_resp_t ref_imem_resp, pipe_imem_resp;
  dmem_req_t ref_dmem_req, pipe_dmem_req;
  dmem_resp_t ref_dmem_resp, pipe_dmem_resp;
  retire_t ref_retire, pipe_retire;
  logic [63:0] ref_mcycle, ref_minstret, pipe_mcycle, pipe_minstret;
  logic [31:0] ref_pc, pipe_pc;
  if_id_reg_t if_id_monitor;
  id_ex_reg_t id_ex_monitor;
  ex_mem_reg_t ex_mem_monitor;
  mem_wb_reg_t mem_wb_monitor;
  logic [63:0] stall_cycles, flush_cycles;
  logic [1:0] forward_a, forward_b;
  logic load_use_stall, redirect;
  logic [31:0] image [0:63];
  logic [31:0] retired_pcs [0:127];
  integer i;
  integer retired_count;
  integer retired_slots;
  logic saw_ex_mem_forward;
  logic saw_mem_wb_forward;

  single_cycle_core reference (
    .clk(clk), .reset(reset), .imem_resp(ref_imem_resp),
    .imem_req(ref_imem_req), .dmem_resp(ref_dmem_resp),
    .dmem_req(ref_dmem_req), .retire(ref_retire),
    .mcycle(ref_mcycle), .minstret(ref_minstret), .current_pc(ref_pc)
  );
  pipeline_core pipeline (
    .clk(clk), .reset(reset), .imem_resp(pipe_imem_resp),
    .imem_req(pipe_imem_req), .dmem_resp(pipe_dmem_resp),
    .dmem_req(pipe_dmem_req), .retire(pipe_retire),
    .mcycle(pipe_mcycle), .minstret(pipe_minstret),
    .current_pc(pipe_pc), .if_id_monitor(if_id_monitor),
    .id_ex_monitor(id_ex_monitor), .ex_mem_monitor(ex_mem_monitor),
    .mem_wb_monitor(mem_wb_monitor), .stall_cycles(stall_cycles),
    .flush_cycles(flush_cycles), .forward_a_monitor(forward_a),
    .forward_b_monitor(forward_b),
    .load_use_stall_monitor(load_use_stall),
    .redirect_monitor(redirect)
  );
  reference_memory #(.WORDS(256)) ref_mem (
    .clk(clk), .reset(reset), .imem_req(ref_imem_req),
    .imem_resp(ref_imem_resp), .dmem_req(ref_dmem_req),
    .dmem_resp(ref_dmem_resp)
  );
  reference_memory #(.WORDS(256)) pipe_mem (
    .clk(clk), .reset(reset), .imem_req(pipe_imem_req),
    .imem_resp(pipe_imem_resp), .dmem_req(pipe_dmem_req),
    .dmem_resp(pipe_dmem_resp)
  );

  always #5 clk = ~clk;

  initial begin
    retired_count = 0;
    retired_slots = 0;
    saw_ex_mem_forward = 1'b0;
    saw_mem_wb_forward = 1'b0;
    for (i = 0; i < 64; i = i + 1)
      image[i] = 32'h0000_0013;
    $readmemh("tb/programs/stage4_hazard.hex", image);
    repeat (2) @(posedge clk);
    #1;
    for (i = 0; i < 64; i = i + 1) begin
      ref_mem.mem[i*4] = image[i][7:0];
      ref_mem.mem[i*4+1] = image[i][15:8];
      ref_mem.mem[i*4+2] = image[i][23:16];
      ref_mem.mem[i*4+3] = image[i][31:24];
      pipe_mem.mem[i*4] = image[i][7:0];
      pipe_mem.mem[i*4+1] = image[i][15:8];
      pipe_mem.mem[i*4+2] = image[i][23:16];
      pipe_mem.mem[i*4+3] = image[i][31:24];
    end
    reset <= 1'b0;
    repeat (55) @(posedge clk);

    for (i = 0; i < 32; i = i + 1)
      if (reference.u_regfile.regs[i] !== pipeline.u_regfile.regs[i])
        $fatal(1, "register mismatch x%0d ref=%h pipe=%h", i,
               reference.u_regfile.regs[i], pipeline.u_regfile.regs[i]);
    for (i = 0; i < 256*4; i = i + 1)
      if (ref_mem.mem[i] !== pipe_mem.mem[i])
        $fatal(1, "memory mismatch byte %0d ref=%h pipe=%h",
               i, ref_mem.mem[i], pipe_mem.mem[i]);

    if (pipeline.u_regfile.regs[1] !== 32'd8 ||
        pipeline.u_regfile.regs[2] !== 32'd16 ||
        pipeline.u_regfile.regs[3] !== 32'd17 ||
        pipeline.u_regfile.regs[4] !== 32'd17 ||
        pipeline.u_regfile.regs[5] !== 32'd19)
      $fatal(1, "RAW/load-use result mismatch");
    if (pipeline.u_regfile.regs[6] !== 32'd7 ||
        pipeline.u_regfile.regs[7] !== 32'd8)
      $fatal(1, "taken-branch wrong-path instruction committed");
    if (pipeline.u_regfile.regs[8] !== 32'd3 ||
        pipeline.u_regfile.regs[9] !== 32'd6 ||
        pipeline.u_regfile.regs[10] !== 32'd5)
      $fatal(1, "repeated-destination forwarding mismatch");
    if (pipe_mem.mem[200] !== 8'd17)
      $fatal(1, "store forwarding result mismatch");
    if (stall_cycles == 0)
      $fatal(1, "load-use stall was not observed");
    if (!saw_ex_mem_forward || !saw_mem_wb_forward)
      $fatal(1, "both forwarding paths were not observed");
    if (flush_cycles < 2)
      $fatal(1, "branch/jump recovery was not observed");
    if (retired_count == 0 || pipe_minstret == 0)
      $fatal(1, "no pipeline retirement observed");
    $display("stage4_hazard_tb PASS: cycles=%0d retired=%0d stalls=%0d flushes=%0d",
             pipe_mcycle, pipe_minstret, stall_cycles, flush_cycles);
    $finish;
  end

  always @(posedge clk) begin
    if (!reset && (forward_a == 2'b01 || forward_b == 2'b01))
      saw_ex_mem_forward <= 1'b1;
    if (!reset && (forward_a == 2'b10 || forward_b == 2'b10))
      saw_mem_wb_forward <= 1'b1;
    if (!reset && pipe_retire.valid) begin
      for (i = 0; i < retired_slots; i = i + 1)
        if (retired_pcs[i] == pipe_retire.pc)
          $fatal(1, "duplicate retirement at PC %h", pipe_retire.pc);
      retired_pcs[retired_slots] <= pipe_retire.pc;
      retired_slots <= retired_slots + 1;
      retired_count <= retired_count + 1;
    end
  end

  assert property (@(posedge clk) disable iff (reset)
    load_use_stall |=> (!id_ex_monitor.valid));
  assert property (@(posedge clk) disable iff (reset)
    load_use_stall |=> (if_id_monitor.pc == $past(pipe_pc)));
  assert property (@(posedge clk) disable iff (reset)
    redirect |=> (!if_id_monitor.valid && !id_ex_monitor.valid));
  assert property (@(posedge clk) disable iff (reset)
    (forward_a == 2'b01) |->
      (id_ex_monitor.valid && id_ex_monitor.uses_rs1 &&
       ex_mem_monitor.valid && ex_mem_monitor.reg_write &&
       !ex_mem_monitor.mem_read && ex_mem_monitor.rd != 5'd0 &&
       ex_mem_monitor.rd == id_ex_monitor.rs1));
  assert property (@(posedge clk) disable iff (reset)
    (forward_b == 2'b01) |->
      (id_ex_monitor.valid && id_ex_monitor.uses_rs2 &&
       ex_mem_monitor.valid && ex_mem_monitor.reg_write &&
       !ex_mem_monitor.mem_read && ex_mem_monitor.rd != 5'd0 &&
       ex_mem_monitor.rd == id_ex_monitor.rs2));
endmodule
