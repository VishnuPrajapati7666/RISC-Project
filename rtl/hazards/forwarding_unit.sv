module forwarding_unit (
  input  logic        id_ex_valid,
  input  logic        uses_rs1,
  input  logic        uses_rs2,
  input  logic [4:0]  rs1,
  input  logic [4:0]  rs2,
  input  logic [31:0] rs1_value,
  input  logic [31:0] rs2_value,
  input  logic        ex_mem_valid,
  input  logic        ex_mem_reg_write,
  input  logic        ex_mem_mem_read,
  input  logic [4:0]  ex_mem_rd,
  input  logic [31:0] ex_mem_value,
  input  logic        mem_wb_valid,
  input  logic        mem_wb_reg_write,
  input  logic [4:0]  mem_wb_rd,
  input  logic [31:0] mem_wb_value,
  output logic [1:0]  forward_a_sel,
  output logic [1:0]  forward_b_sel,
  output logic [31:0] operand_a,
  output logic [31:0] operand_b
);
  localparam logic [1:0] FWD_REGISTER = 2'b00;
  localparam logic [1:0] FWD_EX_MEM  = 2'b01;
  localparam logic [1:0] FWD_MEM_WB  = 2'b10;

  always_comb begin
    forward_a_sel = FWD_REGISTER;
    forward_b_sel = FWD_REGISTER;
    operand_a = rs1_value;
    operand_b = rs2_value;

    // EX/MEM wins over MEM/WB because it contains the newer instruction.
    // A load's EX/MEM ALU result is only an address, never a forwardable value.
    if (id_ex_valid && uses_rs1 && (rs1 != 5'd0)) begin
      if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
          (ex_mem_rd != 5'd0) && (ex_mem_rd == rs1)) begin
        forward_a_sel = FWD_EX_MEM;
        operand_a = ex_mem_value;
      end else if (mem_wb_valid && mem_wb_reg_write &&
                   (mem_wb_rd != 5'd0) && (mem_wb_rd == rs1)) begin
        forward_a_sel = FWD_MEM_WB;
        operand_a = mem_wb_value;
      end
    end

    if (id_ex_valid && uses_rs2 && (rs2 != 5'd0)) begin
      if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
          (ex_mem_rd != 5'd0) && (ex_mem_rd == rs2)) begin
        forward_b_sel = FWD_EX_MEM;
        operand_b = ex_mem_value;
      end else if (mem_wb_valid && mem_wb_reg_write &&
                   (mem_wb_rd != 5'd0) && (mem_wb_rd == rs2)) begin
        forward_b_sel = FWD_MEM_WB;
        operand_b = mem_wb_value;
      end
    end
  end
endmodule
