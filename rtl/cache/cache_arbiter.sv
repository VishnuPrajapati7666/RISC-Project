module cache_arbiter (
  input  logic         clk,
  input  logic         reset,
  input  logic         i_req_valid,
  output logic         i_req_ready,
  input  logic [31:0]  i_req_addr,
  input  logic         i_req_write,
  input  logic [127:0] i_req_wdata,
  input  logic [15:0]  i_req_be,
  output logic         i_resp_valid,
  output logic [127:0] i_resp_rdata,
  output logic         i_resp_error,
  input  logic         d_req_valid,
  output logic         d_req_ready,
  input  logic [31:0]  d_req_addr,
  input  logic         d_req_write,
  input  logic [127:0] d_req_wdata,
  input  logic [15:0]  d_req_be,
  output logic         d_resp_valid,
  output logic [127:0] d_resp_rdata,
  output logic         d_resp_error,
  output logic         mem_req_valid,
  input  logic         mem_req_ready,
  output logic [31:0]  mem_req_addr,
  output logic         mem_req_write,
  output logic [127:0] mem_req_wdata,
  output logic [15:0]  mem_req_be,
  input  logic         mem_resp_valid,
  input  logic [127:0] mem_resp_rdata,
  input  logic         mem_resp_error
);
  logic busy;
  logic owner_d;
  logic [31:0] active_addr;
  logic active_write;
  logic [127:0] active_wdata;
  logic [15:0] active_be;

  always_comb begin
    i_req_ready = !busy && !d_req_valid && mem_req_ready;
    d_req_ready = !busy && mem_req_ready;
    mem_req_valid = busy ? 1'b1 : (d_req_valid || i_req_valid);
    mem_req_addr = busy ? active_addr : (d_req_valid ? d_req_addr : i_req_addr);
    mem_req_write = busy ? active_write :
                    (d_req_valid ? d_req_write : i_req_write);
    mem_req_wdata = busy ? active_wdata :
                    (d_req_valid ? d_req_wdata : i_req_wdata);
    mem_req_be = busy ? active_be : (d_req_valid ? d_req_be : i_req_be);
    i_resp_valid = mem_resp_valid && !owner_d;
    d_resp_valid = mem_resp_valid && owner_d;
    i_resp_rdata = mem_resp_rdata;
    d_resp_rdata = mem_resp_rdata;
    i_resp_error = mem_resp_error && !owner_d;
    d_resp_error = mem_resp_error && owner_d;
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      busy <= 1'b0;
      owner_d <= 1'b0;
      active_addr <= 32'd0;
      active_write <= 1'b0;
      active_wdata <= 128'd0;
      active_be <= 16'd0;
    end else begin
      if (!busy && mem_req_valid && mem_req_ready) begin
        busy <= 1'b1;
        owner_d <= d_req_valid;
        active_addr <= d_req_valid ? d_req_addr : i_req_addr;
        active_write <= d_req_valid ? d_req_write : i_req_write;
        active_wdata <= d_req_valid ? d_req_wdata : i_req_wdata;
        active_be <= d_req_valid ? d_req_be : i_req_be;
      end else if (busy && mem_resp_valid) begin
        busy <= 1'b0;
      end
    end
  end
endmodule
