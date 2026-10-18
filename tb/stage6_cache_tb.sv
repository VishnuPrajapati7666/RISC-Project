module stage6_cache_tb;
  logic clk = 1'b0;
  logic reset = 1'b1;
  always #5 clk = ~clk;

  logic i_req_valid, i_req_ready;
  logic [31:0] i_req_addr;
  logic i_resp_valid, i_resp_error;
  logic [31:0] i_resp_rdata;
  logic d_req_valid, d_req_ready, d_req_write;
  logic [31:0] d_req_addr, d_req_wdata;
  logic [3:0] d_req_be;
  logic d_resp_valid, d_resp_error;
  logic [31:0] d_resp_rdata;
  logic [63:0] i_misses, d_misses, d_writes;

  logic i_mem_valid, i_mem_ready, i_mem_write;
  logic [31:0] i_mem_addr;
  logic [127:0] i_mem_wdata;
  logic [15:0] i_mem_be;
  logic i_mem_resp_valid, i_mem_resp_error;
  logic [127:0] i_mem_resp_data;
  logic d_mem_valid, d_mem_ready, d_mem_write;
  logic [31:0] d_mem_addr;
  logic [127:0] d_mem_wdata;
  logic [15:0] d_mem_be;
  logic d_mem_resp_valid, d_mem_resp_error;
  logic [127:0] d_mem_resp_data;

  logic arb_mem_valid, arb_mem_ready, arb_mem_write;
  logic [31:0] arb_mem_addr;
  logic [127:0] arb_mem_wdata;
  logic [15:0] arb_mem_be;
  logic arb_resp_valid, arb_resp_error;
  logic [127:0] arb_resp_data;
  logic ctrl_mem_valid, ctrl_mem_ready, ctrl_mem_write;
  logic [31:0] ctrl_mem_addr;
  logic [127:0] ctrl_mem_wdata;
  logic [15:0] ctrl_mem_be;
  logic ctrl_resp_valid, ctrl_resp_error;
  logic [127:0] ctrl_resp_data;

  icache ic (
    .clk(clk), .reset(reset), .cpu_req_valid(i_req_valid),
    .cpu_req_ready(i_req_ready), .cpu_req_addr(i_req_addr),
    .cpu_resp_valid(i_resp_valid), .cpu_resp_rdata(i_resp_rdata),
    .cpu_resp_error(i_resp_error), .mem_req_valid(i_mem_valid),
    .mem_req_ready(i_mem_ready), .mem_req_addr(i_mem_addr),
    .mem_req_write(i_mem_write), .mem_req_wdata(i_mem_wdata),
    .mem_req_be(i_mem_be), .mem_resp_valid(i_mem_resp_valid),
    .mem_resp_rdata(i_mem_resp_data), .mem_resp_error(i_mem_resp_error),
    .miss_count(i_misses)
  );
  dcache dc (
    .clk(clk), .reset(reset), .cpu_req_valid(d_req_valid),
    .cpu_req_ready(d_req_ready), .cpu_req_write(d_req_write),
    .cpu_req_addr(d_req_addr), .cpu_req_wdata(d_req_wdata),
    .cpu_req_be(d_req_be), .cpu_resp_valid(d_resp_valid),
    .cpu_resp_rdata(d_resp_rdata), .cpu_resp_error(d_resp_error),
    .mem_req_valid(d_mem_valid), .mem_req_ready(d_mem_ready),
    .mem_req_addr(d_mem_addr), .mem_req_write(d_mem_write),
    .mem_req_wdata(d_mem_wdata), .mem_req_be(d_mem_be),
    .mem_resp_valid(d_mem_resp_valid), .mem_resp_rdata(d_mem_resp_data),
    .mem_resp_error(d_mem_resp_error), .miss_count(d_misses),
    .write_count(d_writes)
  );
  cache_arbiter arb (
    .clk(clk), .reset(reset), .i_req_valid(i_mem_valid),
    .i_req_ready(i_mem_ready), .i_req_addr(i_mem_addr),
    .i_req_write(i_mem_write), .i_req_wdata(i_mem_wdata),
    .i_req_be(i_mem_be), .i_resp_valid(i_mem_resp_valid),
    .i_resp_rdata(i_mem_resp_data), .i_resp_error(i_mem_resp_error),
    .d_req_valid(d_mem_valid), .d_req_ready(d_mem_ready),
    .d_req_addr(d_mem_addr), .d_req_write(d_mem_write),
    .d_req_wdata(d_mem_wdata), .d_req_be(d_mem_be),
    .d_resp_valid(d_mem_resp_valid), .d_resp_rdata(d_mem_resp_data),
    .d_resp_error(d_mem_resp_error), .mem_req_valid(arb_mem_valid),
    .mem_req_ready(arb_mem_ready), .mem_req_addr(arb_mem_addr),
    .mem_req_write(arb_mem_write), .mem_req_wdata(arb_mem_wdata),
    .mem_req_be(arb_mem_be), .mem_resp_valid(arb_resp_valid),
    .mem_resp_rdata(arb_resp_data), .mem_resp_error(arb_resp_error)
  );
  memory_controller ctrl (
    .clk(clk), .reset(reset), .req_valid(arb_mem_valid),
    .req_ready(arb_mem_ready), .req_addr(arb_mem_addr),
    .req_write(arb_mem_write), .req_wdata(arb_mem_wdata),
    .req_be(arb_mem_be), .resp_valid(arb_resp_valid),
    .resp_rdata(arb_resp_data), .resp_error(arb_resp_error),
    .mem_req_valid(ctrl_mem_valid), .mem_req_ready(ctrl_mem_ready),
    .mem_req_addr(ctrl_mem_addr), .mem_req_write(ctrl_mem_write),
    .mem_req_wdata(ctrl_mem_wdata), .mem_req_be(ctrl_mem_be),
    .mem_resp_valid(ctrl_resp_valid), .mem_resp_rdata(ctrl_resp_data),
    .mem_resp_error(ctrl_resp_error)
  );
  main_memory_model #(.BYTES(4096), .LATENCY(3)) main_mem (
    .clk(clk), .reset(reset), .req_valid(ctrl_mem_valid),
    .req_ready(ctrl_mem_ready), .req_addr(ctrl_mem_addr),
    .req_write(ctrl_mem_write), .req_wdata(ctrl_mem_wdata),
    .req_be(ctrl_mem_be), .resp_valid(ctrl_resp_valid),
    .resp_rdata(ctrl_resp_data), .resp_error(ctrl_resp_error)
  );

  task automatic issue_i(input logic [31:0] addr, output logic [31:0] data);
    begin
      while (i_resp_valid) @(negedge clk);
      @(negedge clk);
      i_req_addr = addr; i_req_valid = 1'b1;
      while (!i_req_ready) @(negedge clk);
      @(negedge clk); i_req_valid = 1'b0;
      while (!i_resp_valid) @(negedge clk);
      data = i_resp_rdata;
      if (i_resp_error) $fatal(1, "instruction error at %h", addr);
    end
  endtask
  task automatic issue_d_write(input logic [31:0] addr,
                               input logic [31:0] data,
                               input logic [3:0] be);
    begin
      while (d_resp_valid) @(negedge clk);
      @(negedge clk);
      d_req_addr = addr; d_req_wdata = data; d_req_be = be;
      d_req_write = 1'b1; d_req_valid = 1'b1;
      while (!d_req_ready) @(negedge clk);
      @(negedge clk); d_req_valid = 1'b0;
      while (!d_resp_valid) @(negedge clk);
      if (d_resp_error) $fatal(1, "data write error at %h", addr);
    end
  endtask
  task automatic issue_d_read(input logic [31:0] addr,
                              output logic [31:0] data);
    begin
      while (d_resp_valid) @(negedge clk);
      @(negedge clk);
      d_req_addr = addr; d_req_wdata = 32'd0; d_req_be = 4'b0;
      d_req_write = 1'b0; d_req_valid = 1'b1;
      while (!d_req_ready) @(negedge clk);
      @(negedge clk); d_req_valid = 1'b0;
      while (!d_resp_valid) @(negedge clk);
      data = d_resp_rdata;
      if (d_resp_error) $fatal(1, "data read error at %h", addr);
    end
  endtask

  logic [31:0] value, simultaneous_d_value;
  initial begin
    i_req_valid = 1'b0;
    d_req_valid = 1'b0;
    d_req_write = 1'b0;
    i_req_addr = 32'd0;
    d_req_addr = 32'd0;
    d_req_wdata = 32'd0;
    d_req_be = 4'd0;
    repeat (2) @(posedge clk);
    #1;
    main_mem.mem[16] = 8'h78;
    main_mem.mem[17] = 8'h56;
    main_mem.mem[18] = 8'h34;
    main_mem.mem[19] = 8'h12;
    main_mem.mem[32] = 8'h11;
    main_mem.mem[33] = 8'h22;
    main_mem.mem[34] = 8'h33;
    main_mem.mem[35] = 8'h44;
    main_mem.mem[1040] = 8'hef;
    main_mem.mem[1041] = 8'hbe;
    main_mem.mem[1042] = 8'had;
    main_mem.mem[1043] = 8'hde;
    reset = 1'b0;

    issue_i(32'd16, value);
    if (value !== 32'h12345678) $fatal(1, "cold I miss data mismatch");
    issue_i(32'd16, value);
    if (value !== 32'h12345678 || i_misses !== 64'd1)
      $fatal(1, "I-cache hit/miss behavior mismatch");

    issue_d_read(32'd32, value);
    if (value !== 32'h44332211) $fatal(1, "cold D miss mismatch");
    issue_d_read(32'd33, value);
    if (value !== 32'h00443322 || d_misses !== 64'd1)
      $fatal(1, "D-cache byte-offset hit mismatch");
    issue_d_write(32'd33, 32'h000000aa, 4'b0001);
    if (main_mem.mem[33] !== 8'haa || d_writes !== 64'd1)
      $fatal(1, "write-through byte write mismatch");
    issue_d_read(32'd32, value);
    if (value !== 32'h4433aa11) $fatal(1, "updated cache line mismatch");

    // Same index as address 0x20, different tag: this must cause a conflict
    // miss and replace the direct-mapped line.
    issue_d_read(32'd1056, value);
    if (value !== 32'h00000000 || d_misses !== 64'd2)
      $fatal(1, "D-cache conflict replacement mismatch");

    issue_d_write(32'd80, 32'hdeadbeef, 4'b1111);
    if (d_misses !== 64'd2 || main_mem.mem[80] !== 8'hef ||
        main_mem.mem[83] !== 8'hde)
      $fatal(1, "write miss no-allocate mismatch");
    issue_d_read(32'd80, value);
    if (value !== 32'hdeadbeef) $fatal(1, "write-through readback mismatch");

    // Exercise simultaneous front-end/data requests. Data has documented
    // arbiter priority; the instruction request remains pending and must
    // still complete.
    while (i_resp_valid || d_resp_valid) @(negedge clk);
    @(negedge clk);
    i_req_addr = 32'd16;
    i_req_valid = 1'b1;
    d_req_addr = 32'd80;
    d_req_wdata = 32'd0;
    d_req_be = 4'd0;
    d_req_write = 1'b0;
    d_req_valid = 1'b1;
    while (!d_req_ready) @(negedge clk);
    @(negedge clk);
    d_req_valid = 1'b0;
    while (!d_resp_valid) @(negedge clk);
    simultaneous_d_value = d_resp_rdata;
    while (!i_req_ready) @(negedge clk);
    @(negedge clk);
    i_req_valid = 1'b0;
    while (!i_resp_valid) @(negedge clk);
    if (i_resp_rdata !== 32'h12345678)
      $fatal(1, "simultaneous I/D request mismatch");

    if (i_misses == 0 || d_misses == 0)
      $fatal(1, "cache misses were not measured");
    $display("stage6_cache_tb PASS: i_misses=%0d d_misses=%0d writes=%0d",
             i_misses, d_misses, d_writes);
    $finish;
  end
endmodule
