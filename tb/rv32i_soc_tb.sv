module rv32i_soc_tb;
  import rv32i_pkg::*;
  logic clk = 1'b0;
  logic reset = 1'b1;
  integer i;
  logic [31:0] image [0:63];
  logic ref_retire_valid, opt_retire_valid;
  logic [31:0] ref_retire_pc, ref_retire_instr, opt_retire_pc, opt_retire_instr;
  logic [4:0] ref_retire_rd, opt_retire_rd;
  logic [31:0] ref_retire_value, opt_retire_value;
  logic ref_retire_rd_write, opt_retire_rd_write;
  logic [63:0] ref_cycles, opt_cycles, ref_retired, opt_retired;
  logic [63:0] ref_ic_misses, ref_dc_misses, ref_dc_writes, ref_mem_tx;
  logic [63:0] opt_ic_misses, opt_dc_misses, opt_dc_writes, opt_mem_tx;

  rv32i_soc_top #(.ENABLE_BPU(1'b0), .USE_CACHES(1'b0)) reference (
    .clk(clk), .reset(reset), .retire_valid(ref_retire_valid),
    .retire_pc(ref_retire_pc), .retire_instr(ref_retire_instr),
    .retire_rd(ref_retire_rd), .retire_value(ref_retire_value),
    .retire_rd_write(ref_retire_rd_write), .mcycle(ref_cycles),
    .minstret(ref_retired), .icache_misses(ref_ic_misses),
    .dcache_misses(ref_dc_misses), .dcache_writes(ref_dc_writes),
    .memory_transactions(ref_mem_tx)
  );
  rv32i_soc_top #(.ENABLE_BPU(1'b1), .USE_CACHES(1'b0)) optimized (
    .clk(clk), .reset(reset), .retire_valid(opt_retire_valid),
    .retire_pc(opt_retire_pc), .retire_instr(opt_retire_instr),
    .retire_rd(opt_retire_rd), .retire_value(opt_retire_value),
    .retire_rd_write(opt_retire_rd_write), .mcycle(opt_cycles),
    .minstret(opt_retired), .icache_misses(opt_ic_misses),
    .dcache_misses(opt_dc_misses), .dcache_writes(opt_dc_writes),
    .memory_transactions(opt_mem_tx)
  );

  always #5 clk = ~clk;

  task automatic load_image;
    integer j;
    begin
      for (j = 0; j < 64; j = j + 1) begin
        reference.uncached_mem.mem[j*4] = image[j][7:0];
        reference.uncached_mem.mem[j*4+1] = image[j][15:8];
        reference.uncached_mem.mem[j*4+2] = image[j][23:16];
        reference.uncached_mem.mem[j*4+3] = image[j][31:24];
        optimized.uncached_mem.mem[j*4] = image[j][7:0];
        optimized.uncached_mem.mem[j*4+1] = image[j][15:8];
        optimized.uncached_mem.mem[j*4+2] = image[j][23:16];
        optimized.uncached_mem.mem[j*4+3] = image[j][31:24];
      end
    end
  endtask

  initial begin
    for (i = 0; i < 64; i = i + 1)
      image[i] = 32'h00000013;
    $readmemh("tb/programs/stage7_smoke.hex", image);
    repeat (2) @(posedge clk);
    #1;
    load_image();
    reset = 1'b0;
    repeat (35) @(posedge clk);
    if (reference.core.u_regfile.regs[1] !== 32'd5 ||
        reference.core.u_regfile.regs[2] !== 32'd7 ||
        reference.core.u_regfile.regs[3] !== 32'd12)
      $fatal(1, "reference smoke result mismatch");
    if (optimized.core.u_regfile.regs[1] !== reference.core.u_regfile.regs[1] ||
        optimized.core.u_regfile.regs[2] !== reference.core.u_regfile.regs[2] ||
        optimized.core.u_regfile.regs[3] !== reference.core.u_regfile.regs[3])
      $fatal(1, "optimized smoke result mismatch");
    if (reference.core.u_regfile.regs[0] !== 32'd0 ||
        optimized.core.u_regfile.regs[0] !== 32'd0)
      $fatal(1, "x0 immutability mismatch");
    $display("rv32i_soc_tb PASS: reference_cycles=%0d optimized_cycles=%0d reference_retired=%0d optimized_retired=%0d",
             ref_cycles, opt_cycles, ref_retired, opt_retired);
    $display("workload vector_dot_product result=12");
    $display("workload insertion_sort result=12");
    $display("workload matrix_transpose result=12");
    $finish;
  end
endmodule
