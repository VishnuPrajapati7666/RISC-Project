module dcache #(
  parameter int LINES = 64
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        cpu_req_valid,
  output logic        cpu_req_ready,
  input  logic        cpu_req_write,
  input  logic [31:0] cpu_req_addr,
  input  logic [31:0] cpu_req_wdata,
  input  logic [3:0]  cpu_req_be,
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
  output logic [63:0]  miss_count,
  output logic [63:0]  write_count
);
  typedef enum logic [2:0] {S_IDLE, S_READ_REQ, S_READ_WAIT,
                            S_WRITE_REQ, S_WRITE_WAIT, S_RESP} state_t;
  state_t state;
  logic [21:0] tags [0:LINES-1];
  logic [127:0] data [0:LINES-1];
  logic valids [0:LINES-1];
  logic [31:0] pending_addr;
  logic [31:0] pending_wdata;
  logic [3:0] pending_be;
  logic pending_write;
  logic [5:0] pending_index;
  logic [21:0] pending_tag;
  logic [31:0] response_word;
  logic response_error;
  logic [127:0] write_line;
  logic [15:0] write_line_be;
  integer i;
  integer j;

  function automatic [127:0] make_write_line(
    input logic [31:0] wdata,
    input logic [31:0] addr,
    input logic [3:0]  be
  );
    integer k;
    begin
      make_write_line = 128'd0;
      for (k = 0; k < 4; k = k + 1)
        if (be[k])
          make_write_line[(8 * (addr[3:0] + k)) +: 8] = wdata[(8*k) +: 8];
    end
  endfunction

  function automatic [15:0] make_write_be(
    input logic [31:0] addr,
    input logic [3:0]  be
  );
    integer k;
    begin
      make_write_be = 16'd0;
      for (k = 0; k < 4; k = k + 1)
        if (be[k])
          make_write_be[addr[3:0] + k] = 1'b1;
    end
  endfunction

  always_comb begin
    cpu_req_ready = (state == S_IDLE);
    cpu_resp_valid = (state == S_RESP);
    cpu_resp_rdata = response_word;
    cpu_resp_error = (state == S_RESP) && response_error;
    mem_req_valid = (state == S_READ_REQ) || (state == S_WRITE_REQ);
    mem_req_addr = {pending_addr[31:4], 4'b0};
    mem_req_write = (state == S_WRITE_REQ);
    mem_req_wdata = write_line;
    mem_req_be = write_line_be;
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= S_IDLE;
      pending_addr <= 32'd0;
      pending_wdata <= 32'd0;
      pending_be <= 4'd0;
      pending_write <= 1'b0;
      pending_index <= 6'd0;
      pending_tag <= 22'd0;
      response_word <= 32'd0;
      response_error <= 1'b0;
      write_line <= 128'd0;
      write_line_be <= 16'd0;
      miss_count <= 64'd0;
      write_count <= 64'd0;
      for (i = 0; i < LINES; i = i + 1) begin
        valids[i] <= 1'b0;
        tags[i] <= 22'd0;
        data[i] <= 128'd0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          if (cpu_req_valid) begin
            pending_addr <= cpu_req_addr;
            pending_wdata <= cpu_req_wdata;
            pending_be <= cpu_req_be;
            pending_write <= cpu_req_write;
            pending_index <= cpu_req_addr[9:4];
            pending_tag <= cpu_req_addr[31:10];
            if (!cpu_req_write && valids[cpu_req_addr[9:4]] &&
                tags[cpu_req_addr[9:4]] == cpu_req_addr[31:10]) begin
              response_word <= data[cpu_req_addr[9:4]]
                >> (8 * cpu_req_addr[3:0]);
              response_error <= 1'b0;
              state <= S_RESP;
            end else if (cpu_req_write) begin
              write_line <= make_write_line(cpu_req_wdata, cpu_req_addr,
                                            cpu_req_be);
              write_line_be <= make_write_be(cpu_req_addr, cpu_req_be);
              if (valids[cpu_req_addr[9:4]] &&
                  tags[cpu_req_addr[9:4]] == cpu_req_addr[31:10]) begin
                for (j = 0; j < 4; j = j + 1)
                  if (cpu_req_be[j])
                    data[cpu_req_addr[9:4]]
                      [(8 * cpu_req_addr[3:0]) + (8 * j) +: 8]
                      <= cpu_req_wdata[(8 * j) +: 8];
              end
              state <= S_WRITE_REQ;
            end else begin
              state <= S_READ_REQ;
              miss_count <= miss_count + 64'd1;
            end
          end
        end
        S_READ_REQ: begin
          if (mem_req_ready) state <= S_READ_WAIT;
        end
        S_READ_WAIT: begin
          if (mem_resp_valid) begin
            response_error <= mem_resp_error;
            if (!mem_resp_error) begin
              valids[pending_index] <= 1'b1;
              tags[pending_index] <= pending_tag;
              data[pending_index] <= mem_resp_rdata;
              response_word <= mem_resp_rdata >> (8 * pending_addr[3:0]);
            end
            state <= S_RESP;
          end
        end
        S_WRITE_REQ: begin
          if (mem_req_ready) begin
            write_count <= write_count + 64'd1;
            state <= S_WRITE_WAIT;
          end
        end
        S_WRITE_WAIT: begin
          if (mem_resp_valid) begin
            response_error <= mem_resp_error;
            state <= S_RESP;
          end
        end
        S_RESP: begin
          response_error <= 1'b0;
          state <= S_IDLE;
        end
        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
