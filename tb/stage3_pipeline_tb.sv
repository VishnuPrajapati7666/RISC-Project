module stage3_pipeline_tb;
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
  logic [31:0] image [0:63];
  integer i;
  integer retire_count;
  logic [31:0] retired_pcs [0:255];
  integer retired_slots;

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
    .mem_wb_monitor(mem_wb_monitor)
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
    retire_count = 0;
    retired_slots = 0;
    for (i = 0; i < 64; i = i + 1)
      image[i] = 32'h0000_0013;
    $readmemh("tb/programs/stage3_nop_padded.hex", image);
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
    repeat (80) @(posedge clk);

    for (i = 0; i < 32; i = i + 1) begin
      if (reference.u_regfile.regs[i] !== pipeline.u_regfile.regs[i])
        $fatal(1, "register mismatch x%0d ref=%h pipe=%h", i,
               reference.u_regfile.regs[i], pipeline.u_regfile.regs[i]);
    end
    if (pipeline.u_regfile.regs[8] !== 32'd3 ||
        pipeline.u_regfile.regs[9] !== 32'd4 ||
        pipeline.u_regfile.regs[10] !== 32'd99)
      $fatal(1, "NOP-padded program architectural result mismatch");
    for (i = 0; i < 256*4; i = i + 1) begin
      if (ref_mem.mem[i] !== pipe_mem.mem[i])
        $fatal(1, "memory mismatch byte %0d ref=%h pipe=%h",
               i, ref_mem.mem[i], pipe_mem.mem[i]);
    end
    if (pipeline.u_regfile.regs[0] !== 32'd0)
      $fatal(1, "pipeline x0 changed");
    if (pipe_minstret == 0)
      $fatal(1, "pipeline retired no instructions");
    $display("stage3_pipeline_tb PASS: pipe_cycles=%0d pipe_retired=%0d",
             pipe_mcycle, pipe_minstret);
    $finish;
  end

  always @(posedge clk) begin
    if (!reset && pipe_retire.valid) begin
      for (i = 0; i < retired_slots; i = i + 1)
        if (retired_pcs[i] == pipe_retire.pc)
          $fatal(1, "instruction retired more than once at PC %h",
                 pipe_retire.pc);
      retired_pcs[retired_slots] <= pipe_retire.pc;
      retired_slots <= retired_slots + 1;
      retire_count <= retire_count + 1;
    end
  end
endmodule
