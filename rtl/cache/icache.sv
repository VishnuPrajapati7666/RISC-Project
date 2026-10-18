module icache #(
  parameter int LINES = 64
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        cpu_req_valid,
  output logic        cpu_req_ready,
  input  logic [31:0] cpu_req_addr,
  output logic        cpu_resp_valid,
  output logic [31:0] cpu_resp_rdata,
  output logic        cpu_resp_error,
  output logic        mem_req_valid,
  input  logic        mem_req_ready,
  output logic [31:0] mem_req_addr,
  output logic        mem_req_write,
  output logic [127:0] mem_req_wdata,
  output logic [15:0] mem_req_be,
  input  logic        mem_resp_valid,
  input  logic [127:0] mem_resp_rdata,
  input  logic        mem_resp_error,
  output logic [63:0]  miss_count
);
  typedef enum logic [1:0] {S_IDLE, S_MISS_REQ, S_MISS_WAIT, S_RESP} state_t;
  state_t state;
  logic [31:0] tags [0:LINES-1];
  logic [127:0] data [0:LINES-1];
  logic valids [0:LINES-1];
  logic [5:0] miss_index;
  logic [21:0] miss_tag;
  logic [31:0] miss_addr;
  logic [31:0] response_word;
  logic response_error;
  integer i;

  always_comb begin
    cpu_req_ready = (state == S_IDLE);
    cpu_resp_valid = (state == S_RESP);
    cpu_resp_rdata = response_word;
    cpu_resp_error = (state == S_RESP) && response_error;
    mem_req_valid = (state == S_MISS_REQ);
    mem_req_addr = {miss_addr[31:4], 4'b0};
    mem_req_write = 1'b0;
    mem_req_wdata = 128'd0;
    mem_req_be = 16'd0;
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= S_IDLE;
      miss_index <= 6'd0;
      miss_tag <= 22'd0;
      miss_addr <= 32'd0;
      response_word <= 32'd0;
      response_error <= 1'b0;
      miss_count <= 64'd0;
      for (i = 0; i < LINES; i = i + 1) begin
        valids[i] <= 1'b0;
        tags[i] <= 32'd0;
        data[i] <= 128'd0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          if (cpu_req_valid) begin
            if (valids[cpu_req_addr[9:4]] &&
                tags[cpu_req_addr[9:4]][21:0] == cpu_req_addr[31:10]) begin
              response_word <= data[cpu_req_addr[9:4]]
                >> (8 * cpu_req_addr[3:0]);
              response_error <= 1'b0;
              state <= S_RESP;
            end else begin
              miss_index <= cpu_req_addr[9:4];
              miss_tag <= cpu_req_addr[31:10];
              miss_addr <= cpu_req_addr;
              state <= S_MISS_REQ;
              miss_count <= miss_count + 64'd1;
            end
          end
        end
        S_MISS_REQ: begin
          if (mem_req_ready)
            state <= S_MISS_WAIT;
        end
        S_MISS_WAIT: begin
          if (mem_resp_valid) begin
            response_error <= mem_resp_error;
            if (!mem_resp_error) begin
              valids[miss_index] <= 1'b1;
              tags[miss_index] <= {10'd0, miss_tag};
              data[miss_index] <= mem_resp_rdata;
              response_word <= mem_resp_rdata >> (8 * miss_addr[3:0]);
            end
            state <= S_RESP;
          end
        end
        S_RESP: state <= S_IDLE;
        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
