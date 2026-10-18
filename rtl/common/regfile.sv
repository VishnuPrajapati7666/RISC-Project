module regfile (
  input  logic        clk,
  input  logic        reset,
  input  logic        write_enable,
  input  logic [4:0]  write_addr,
  input  logic [31:0] write_data,
  input  logic [4:0]  read_addr_a,
  input  logic [4:0]  read_addr_b,
  output logic [31:0] read_data_a,
  output logic [31:0] read_data_b
);
  logic [31:0] regs [0:31];
  integer i;

  always_comb begin
    read_data_a = (read_addr_a == 5'd0) ? 32'd0 : regs[read_addr_a];
    read_data_b = (read_addr_b == 5'd0) ? 32'd0 : regs[read_addr_b];
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      for (i = 0; i < 32; i = i + 1)
        regs[i] <= 32'd0;
    end else if (write_enable && (write_addr != 5'd0)) begin
      regs[write_addr] <= write_data;
    end
  end
endmodule
