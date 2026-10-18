module main_memory_model #(
  parameter int BYTES = 16384,
  parameter int LATENCY = 3
) (
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
  output logic         resp_error
);
  logic [7:0] mem [0:BYTES-1];
  logic pending;
  logic pending_write;
  logic [31:0] pending_addr;
  logic [127:0] pending_wdata;
  logic [15:0] pending_be;
  integer countdown;
  integer i;
  logic [127:0] response_line;

  assign req_ready = !pending;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      pending <= 1'b0;
      pending_write <= 1'b0;
      pending_addr <= 32'd0;
      pending_wdata <= 128'd0;
      pending_be <= 16'd0;
      countdown <= 0;
      resp_valid <= 1'b0;
      resp_rdata <= 128'd0;
      resp_error <= 1'b0;
      for (i = 0; i < BYTES; i = i + 1)
        mem[i] <= 8'd0;
    end else begin
      resp_valid <= 1'b0;
      resp_error <= 1'b0;
      if (!pending && req_valid && req_ready) begin
        pending <= 1'b1;
        pending_write <= req_write;
        pending_addr <= {req_addr[31:4], 4'b0};
        pending_wdata <= req_wdata;
        pending_be <= req_be;
        countdown <= LATENCY;
        if (req_write)
          for (i = 0; i < 16; i = i + 1)
            if (req_be[i])
              mem[{req_addr[31:4], 4'b0} + i] <= req_wdata[(8*i) +: 8];
      end else if (pending) begin
        if (countdown > 0)
          countdown <= countdown - 1;
        else begin
          pending <= 1'b0;
          resp_valid <= 1'b1;
          if (pending_addr + 16 > BYTES) begin
            resp_error <= 1'b1;
            resp_rdata <= 128'd0;
          end else if (pending_write) begin
            resp_rdata <= 128'd0;
          end else begin
            response_line = 128'd0;
            for (i = 0; i < 16; i = i + 1)
              response_line[(8*i) +: 8] = mem[pending_addr + i];
            resp_rdata <= response_line;
          end
        end
      end
    end
  end
endmodule
