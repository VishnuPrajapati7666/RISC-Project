module branch_unit (
  input  rv32i_pkg::id_ex_reg_t id_ex,
  input  logic [31:0]           operand_a,
  input  logic [31:0]           operand_b,
  output logic                  branch_taken,
  output logic                  redirect,
  output logic [31:0]           target,
  output logic [31:0]           actual_next_pc
);
  import rv32i_pkg::*;

  always_comb begin
    branch_taken = 1'b0;
    unique case (id_ex.branch_cond)
      BR_BEQ:  branch_taken = (operand_a == operand_b);
      BR_BNE:  branch_taken = (operand_a != operand_b);
      BR_BLT:  branch_taken = ($signed(operand_a) < $signed(operand_b));
      BR_BGE:  branch_taken = ($signed(operand_a) >= $signed(operand_b));
      BR_BLTU: branch_taken = (operand_a < operand_b);
      BR_BGEU: branch_taken = (operand_a >= operand_b);
      default: branch_taken = 1'b0;
    endcase

    target = id_ex.jalr
      ? ((operand_a + id_ex.immediate) & 32'hffff_fffe)
      : (id_ex.pc + id_ex.immediate);
    actual_next_pc = id_ex.pc_next;
    if (id_ex.branch && branch_taken)
      actual_next_pc = target;
    else if (id_ex.jump)
      actual_next_pc = target;
    redirect = id_ex.valid && (actual_next_pc != id_ex.predicted_target);
  end
endmodule
