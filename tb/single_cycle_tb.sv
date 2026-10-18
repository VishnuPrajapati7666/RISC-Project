module single_cycle_tb;
  import rv32i_pkg::*;

  logic clk = 1'b0;
  logic reset = 1'b1;
  imem_req_t imem_req;
  imem_resp_t imem_resp;
  dmem_req_t dmem_req;
  dmem_resp_t dmem_resp;
  retire_t retire;
  logic [63:0] mcycle, minstret;
  logic [31:0] current_pc;

  single_cycle_core dut (
    .clk(clk), .reset(reset), .imem_resp(imem_resp), .imem_req(imem_req),
    .dmem_resp(dmem_resp), .dmem_req(dmem_req), .retire(retire),
    .mcycle(mcycle), .minstret(minstret), .current_pc(current_pc)
  );
  reference_memory #(.WORDS(256)) mem (
    .clk(clk), .reset(reset), .imem_req(imem_req), .imem_resp(imem_resp),
    .dmem_req(dmem_req), .dmem_resp(dmem_resp)
  );

  always #5 clk = ~clk;

  task automatic put_word(input int unsigned addr, input logic [31:0] word);
    begin
      mem.mem[addr] = word[7:0];
      mem.mem[addr+1] = word[15:8];
      mem.mem[addr+2] = word[23:16];
      mem.mem[addr+3] = word[31:24];
    end
  endtask

  function automatic [31:0] r(input int rd, input int rs1, input int rs2,
                               input logic [2:0] f3, input logic [6:0] f7);
    r = {f7, rs2[4:0], rs1[4:0], f3, rd[4:0], 7'b0110011};
  endfunction
  function automatic [31:0] i(input int rd, input int rs1, input int imm,
                               input logic [2:0] f3);
    i = {imm[11:0], rs1[4:0], f3, rd[4:0], 7'b0010011};
  endfunction
  function automatic [31:0] lw(input int rd, input int rs1, input int imm,
                                input logic [2:0] f3);
    lw = {imm[11:0], rs1[4:0], f3, rd[4:0], 7'b0000011};
  endfunction
  function automatic [31:0] s(input int rs2, input int rs1, input int imm,
                               input logic [2:0] f3);
    s = {imm[11:5], rs2[4:0], rs1[4:0], f3, imm[4:0], 7'b0100011};
  endfunction
  function automatic [31:0] b(input int rs2, input int rs1, input int imm,
                               input logic [2:0] f3);
    b = {imm[12], imm[10:5], rs2[4:0], rs1[4:0], f3,
         imm[4:1], imm[11], 1'b0, 7'b1100011};
  endfunction
  function automatic [31:0] u(input int rd, input int imm20,
                               input logic [6:0] op);
    u = {imm20[19:0], rd[4:0], op};
  endfunction
  function automatic [31:0] j(input int rd, input int imm);
    j = {imm[20], imm[10:1], imm[11], imm[19:12], rd[4:0], 7'b1101111};
  endfunction
  function automatic [31:0] jr(input int rd, input int rs1, input int imm);
    jr = {imm[11:0], rs1[4:0], 3'b000, rd[4:0], 7'b1100111};
  endfunction

  initial begin
    repeat (2) @(posedge clk);
    reset <= 1'b0;
    #1;
    put_word(0,  i(1, 0, 5, 3'b000));        // x1 = 5
    put_word(4,  i(2, 0, -2, 3'b000));       // x2 = -2
    put_word(8,  r(3, 1, 2, 3'b000, 7'b0));  // x3 = 3
    put_word(12, i(4, 3, 2, 3'b001));        // x4 = 12
    put_word(16, r(5, 2, 1, 3'b010, 7'b0));  // x5 = signed less-than
    put_word(20, r(6, 1, 2, 3'b011, 7'b0));  // x6 = unsigned less-than
    put_word(24, u(7, 20'h12345, 7'b0110111));// x7 = 0x12345000
    put_word(28, u(8, 0, 7'b0010111));       // x8 = current PC
    put_word(32, s(3, 0, 64, 3'b010));       // sw x3, 64(x0)
    put_word(36, s(2, 0, 65, 3'b000));       // sb x2, 65(x0)
    put_word(40, lw(9, 0, 65, 3'b100));      // lbu x9 = 254
    put_word(44, lw(10, 0, 65, 3'b000));     // lb x10 = -2
    put_word(48, s(1, 0, 66, 3'b001));       // sh x1, 66(x0)
    put_word(52, lw(11, 0, 66, 3'b101));     // lhu x11 = 5
    put_word(56, b(3, 3, 8, 3'b000));        // taken BEQ, skip 60
    put_word(60, i(0, 0, 99, 3'b000));       // must not execute
    put_word(64, j(12, 12));                 // x12 = 68, target 76
    put_word(68, i(0, 0, 99, 3'b000));       // skipped by JAL
    put_word(72, 32'h0000_0013);             // padding
    put_word(76, jr(13, 0, 84));             // x13 = 80, target 84
    put_word(80, i(0, 0, 99, 3'b000));       // skipped by JALR
    put_word(84, 32'h0000_000f);             // FENCE no-op
    put_word(88, i(0, 0, 0, 3'b000));       // NOP
    put_word(92,  b(2, 1, 8, 3'b001));      // BNE taken
    put_word(96,  i(14, 0, 1, 3'b000));     // skipped
    put_word(100, i(14, 0, 2, 3'b000));     // x14 = 2
    put_word(104, b(1, 2, 8, 3'b100));      // BLT taken
    put_word(108, i(15, 0, 1, 3'b000));     // skipped
    put_word(112, i(15, 0, 2, 3'b000));     // x15 = 2
    put_word(116, b(2, 1, 8, 3'b101));      // BGE taken
    put_word(120, i(16, 0, 1, 3'b000));     // skipped
    put_word(124, i(16, 0, 2, 3'b000));     // x16 = 2
    put_word(128, b(2, 1, 8, 3'b110));      // BLTU taken
    put_word(132, i(17, 0, 1, 3'b000));     // skipped
    put_word(136, i(17, 0, 2, 3'b000));     // x17 = 2
    put_word(140, b(1, 2, 8, 3'b111));      // BGEU taken
    put_word(144, i(18, 0, 1, 3'b000));     // skipped
    put_word(148, i(18, 0, 2, 3'b000));     // x18 = 2
    put_word(152, r(19, 2, 1, 3'b101, 7'b0100000)); // SRA: -2 >> 5
    put_word(156, r(20, 2, 1, 3'b101, 7'b0000000)); // SRL
    repeat (40) @(posedge clk);
    if (dut.u_regfile.regs[0] !== 32'd0) $fatal(1, "x0 changed");
    if (dut.u_regfile.regs[1] !== 32'd5) $fatal(1, "x1 mismatch");
    if (dut.u_regfile.regs[2] !== 32'hffff_fffe) $fatal(1, "x2 mismatch");
    if (dut.u_regfile.regs[3] !== 32'd3) $fatal(1, "x3 mismatch");
    if (dut.u_regfile.regs[4] !== 32'd12) $fatal(1, "x4 mismatch");
    if (dut.u_regfile.regs[5] !== 32'd1) $fatal(1, "x5 mismatch");
    if (dut.u_regfile.regs[6] !== 32'd1) $fatal(1, "x6 mismatch");
    if (dut.u_regfile.regs[7] !== 32'h1234_5000) $fatal(1, "x7 mismatch");
    if (dut.u_regfile.regs[8] !== 32'd28) $fatal(1, "x8 mismatch");
    if (dut.u_regfile.regs[9] !== 32'd254) $fatal(1, "x9 mismatch");
    if (dut.u_regfile.regs[10] !== 32'hffff_fffe) $fatal(1, "x10 mismatch");
    if (dut.u_regfile.regs[11] !== 32'd5) $fatal(1, "x11 mismatch");
    if (dut.u_regfile.regs[12] !== 32'd68) $fatal(1, "x12 JAL link mismatch");
    if (dut.u_regfile.regs[13] !== 32'd80) $fatal(1, "x13 JALR link mismatch");
    if (dut.u_regfile.regs[14] !== 32'd2 ||
        dut.u_regfile.regs[15] !== 32'd2 ||
        dut.u_regfile.regs[16] !== 32'd2 ||
        dut.u_regfile.regs[17] !== 32'd2 ||
        dut.u_regfile.regs[18] !== 32'd2)
      $fatal(1, "branch outcome mismatch");
    if (dut.u_regfile.regs[19] !== 32'hffff_ffff ||
        dut.u_regfile.regs[20] !== 32'h07ff_ffff)
      $fatal(1, "shift result mismatch");
    if (mem.mem[64] !== 8'd3 || mem.mem[65] !== 8'hfe ||
        mem.mem[66] !== 8'd5 || mem.mem[67] !== 8'd0)
      $fatal(1, "memory state mismatch");
    if (minstret == 0) $fatal(1, "no instructions retired");
    $display("single_cycle_tb PASS: mcycle=%0d minstret=%0d", mcycle, minstret);
    $finish;
  end
endmodule
