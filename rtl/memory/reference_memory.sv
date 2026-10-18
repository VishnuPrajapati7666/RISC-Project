module reference_memory #(
  parameter int WORDS = 1024
) (
  input  logic                    clk,
  input  logic                    reset,
  input  rv32i_pkg::imem_req_t    imem_req,
  output rv32i_pkg::imem_resp_t   imem_resp,
  input  rv32i_pkg::dmem_req_t    dmem_req,
  output rv32i_pkg::dmem_resp_t   dmem_resp
);
  // Reference timing: reads are combinational and complete in the request
  // cycle; writes commit on the following rising edge.
  logic [7:0] mem [0:(WORDS * 4) - 1];
  integer i;
  logic [31:0] imem_word;
  logic [31:0] dmem_word;
  integer ia;
  integer da;

  always_comb begin
    imem_word = 32'd0;
    ia = imem_req.addr;
    if (ia >= 0 && ia + 3 < WORDS * 4)
      imem_word = {mem[ia + 3], mem[ia + 2], mem[ia + 1], mem[ia]};
    imem_resp = '0;
    imem_resp.valid = imem_req.valid;
    imem_resp.addr = imem_req.addr;
    imem_resp.rdata = imem_word;
    imem_resp.ready = imem_req.valid;

    dmem_word = 32'd0;
    da = dmem_req.addr;
    if (da >= 0 && da + 3 < WORDS * 4)
      dmem_word = {mem[da + 3], mem[da + 2], mem[da + 1], mem[da]};
    dmem_resp = '0;
    dmem_resp.valid = dmem_req.valid;
    dmem_resp.rdata = dmem_word;
    dmem_resp.ready = dmem_req.valid;
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      for (i = 0; i < WORDS * 4; i = i + 1)
        mem[i] <= 8'd0;
    end else if (dmem_req.valid && dmem_req.write) begin
      if (dmem_req.byte_enable[0]) mem[dmem_req.addr]     <= dmem_req.wdata[7:0];
      if (dmem_req.byte_enable[1]) mem[dmem_req.addr + 1] <= dmem_req.wdata[15:8];
      if (dmem_req.byte_enable[2]) mem[dmem_req.addr + 2] <= dmem_req.wdata[23:16];
      if (dmem_req.byte_enable[3]) mem[dmem_req.addr + 3] <= dmem_req.wdata[31:24];
    end
  end
endmodule
