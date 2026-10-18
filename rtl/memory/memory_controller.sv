module memory_controller (
  input  logic         clk,
  input  logic         reset,
  input  logic         req_valid,
  output logic         req_ready,
  input  logic [31:0]  req_addr,
  input  logic         req_write,
  input  logic [127:0] req_wdata,
  input  logic [15:0]  req_be,
  output logic         resp_valid,
  output logic [127:0] resp_rdata,
  output logic         resp_error,
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
  logic active;
  logic [31:0] addr_q;
  logic write_q;
  logic [127:0] wdata_q;
  logic [15:0] be_q;
  logic resp_valid_q;
  logic [127:0] resp_rdata_q;
  logic resp_error_q;

  assign req_ready = !active && !resp_valid_q;
  assign mem_req_valid = active;
  assign mem_req_addr = addr_q;
  assign mem_req_write = write_q;
  assign mem_req_wdata = wdata_q;
  assign mem_req_be = be_q;
  assign resp_valid = resp_valid_q;
  assign resp_rdata = resp_rdata_q;
  assign resp_error = resp_error_q;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      active <= 1'b0;
      addr_q <= 32'd0;
      write_q <= 1'b0;
      wdata_q <= 128'd0;
      be_q <= 16'd0;
      resp_valid_q <= 1'b0;
      resp_rdata_q <= 128'd0;
      resp_error_q <= 1'b0;
    end else begin
      resp_valid_q <= 1'b0;
      if (!active && req_valid && req_ready) begin
        active <= 1'b1;
        addr_q <= req_addr;
        write_q <= req_write;
        wdata_q <= req_wdata;
        be_q <= req_be;
      end else if (active && mem_resp_valid) begin
        active <= 1'b0;
        resp_valid_q <= 1'b1;
        resp_rdata_q <= mem_resp_rdata;
        resp_error_q <= mem_resp_error;
      end
    end
  end
endmodule
