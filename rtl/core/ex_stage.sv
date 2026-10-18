module ex_stage (
  input  rv32i_pkg::id_ex_reg_t  id_ex,
  input  logic [31:0]            operand_a,
  input  logic [31:0]            operand_b,
  output rv32i_pkg::ex_mem_reg_t ex_mem_next,
  output logic                   redirect,
  output logic [31:0]            redirect_pc,
  output logic                   resolve_valid,
  output logic                   resolve_conditional,
  output logic                   resolve_taken,
  output logic [31:0]            resolve_pc,
  output logic [31:0]            resolve_target
);
  import rv32i_pkg::*;
  logic [31:0] alu_b;
  logic [31:0] alu_result;
  logic [31:0] result_value;
  logic branch_taken;
  logic [31:0] target;
  logic [31:0] fallthrough;
  logic branch_redirect;
  logic [31:0] actual_next_pc;

  branch_unit u_branch (
    .id_ex(id_ex), .operand_a(operand_a), .operand_b(operand_b),
    .branch_taken(branch_taken), .redirect(branch_redirect),
    .target(target), .actual_next_pc(actual_next_pc)
  );

  assign alu_b = id_ex.alu_src_immediate ? id_ex.immediate : operand_b;
  alu u_alu (
    .op(id_ex.alu_op),
    .a((id_ex.opcode == OPCODE_AUIPC) ? id_ex.pc : operand_a),
    .b(alu_b),
    .y(alu_result)
  );

  always_comb begin
    fallthrough = id_ex.pc_next;
    result_value = id_ex.jump ? id_ex.pc_next : alu_result;
    redirect = branch_redirect;
    redirect_pc = actual_next_pc;
    resolve_valid = id_ex.valid && (id_ex.branch || id_ex.jump);
    resolve_conditional = id_ex.valid && id_ex.branch;
    resolve_taken = id_ex.valid && (id_ex.jump || branch_taken);
    resolve_pc = id_ex.pc;
    resolve_target = target;

    ex_mem_next = EX_MEM_RESET;
    ex_mem_next.valid = id_ex.valid;
    ex_mem_next.pc = id_ex.pc;
    ex_mem_next.instr = id_ex.instr;
    ex_mem_next.pc_next = id_ex.pc_next;
    ex_mem_next.alu_result = result_value;
    // This value is already forwarded, so a store observes the newest
    // producer at the EX/MEM memory-write point.
    ex_mem_next.store_data = operand_b;
    ex_mem_next.branch_target = target;
    ex_mem_next.predicted_target = id_ex.predicted_target;
    ex_mem_next.rd = id_ex.rd;
    ex_mem_next.rs1 = id_ex.rs1;
    ex_mem_next.rs2 = id_ex.rs2;
    ex_mem_next.funct3 = id_ex.funct3;
    ex_mem_next.reg_write = id_ex.reg_write;
    ex_mem_next.mem_read = id_ex.mem_read;
    ex_mem_next.mem_write = id_ex.mem_write;
    ex_mem_next.mem_size = id_ex.mem_size;
    ex_mem_next.mem_unsigned = id_ex.mem_unsigned;
    ex_mem_next.branch = id_ex.branch;
    ex_mem_next.jump = id_ex.jump;
    ex_mem_next.jalr = id_ex.jalr;
    ex_mem_next.branch_taken = branch_taken;
    ex_mem_next.predicted_taken = id_ex.predicted_taken;
    ex_mem_next.predictor_valid = id_ex.predictor_valid;
    ex_mem_next.mispredict = redirect;
  end
endmodule
