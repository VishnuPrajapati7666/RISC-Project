module id_stage (
  input  rv32i_pkg::if_id_reg_t if_id,
  input  logic [31:0]           rs1_value,
  input  logic [31:0]           rs2_value,
  output logic [4:0]            rs1_addr,
  output logic [4:0]            rs2_addr,
  output logic                  decoded_valid,
  output logic                  decoded_uses_rs1,
  output logic                  decoded_uses_rs2,
  output logic [4:0]            decoded_rs1,
  output logic [4:0]            decoded_rs2,
  output rv32i_pkg::id_ex_reg_t id_ex_next
);
  import rv32i_pkg::*;
  logic dec_valid;
  opcode_t opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rs1, rs2, rd;
  imm_format_t immediate_format;
  alu_op_t alu_op;
  branch_cond_t branch_cond;
  logic alu_src_immediate, reg_write, mem_read, mem_write, mem_unsigned;
  logic branch, jump, jalr, uses_rs1, uses_rs2;
  logic [1:0] mem_size;
  logic [31:0] immediate;

  decoder u_decoder (
    .instruction(if_id.instr), .valid(dec_valid), .opcode(opcode),
    .funct3(funct3), .funct7(funct7), .rs1(rs1), .rs2(rs2), .rd(rd),
    .immediate_format(immediate_format), .alu_op(alu_op),
    .branch_cond(branch_cond), .alu_src_immediate(alu_src_immediate),
    .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
    .mem_size(mem_size), .mem_unsigned(mem_unsigned), .branch(branch),
    .jump(jump), .jalr(jalr), .uses_rs1(uses_rs1), .uses_rs2(uses_rs2)
  );
  imm_gen u_imm_gen (
    .format(immediate_format), .instruction(if_id.instr),
    .immediate(immediate)
  );

  always_comb begin
    rs1_addr = rs1;
    rs2_addr = rs2;
    decoded_valid = dec_valid;
    decoded_uses_rs1 = uses_rs1;
    decoded_uses_rs2 = uses_rs2;
    decoded_rs1 = rs1;
    decoded_rs2 = rs2;
    id_ex_next = ID_EX_RESET;
    id_ex_next.valid = if_id.valid && dec_valid;
    id_ex_next.pc = if_id.pc;
    id_ex_next.instr = if_id.instr;
    id_ex_next.pc_next = if_id.pc_next;
    id_ex_next.opcode = opcode;
    id_ex_next.funct3 = funct3;
    id_ex_next.funct7 = funct7;
    id_ex_next.rs1 = rs1;
    id_ex_next.rs2 = rs2;
    id_ex_next.rd = rd;
    id_ex_next.rs1_value = rs1_value;
    id_ex_next.rs2_value = rs2_value;
    id_ex_next.immediate = immediate;
    id_ex_next.immediate_format = immediate_format;
    id_ex_next.alu_op = alu_op;
    id_ex_next.branch_cond = branch_cond;
    id_ex_next.alu_src_immediate = alu_src_immediate;
    id_ex_next.reg_write = reg_write;
    id_ex_next.mem_read = mem_read;
    id_ex_next.mem_write = mem_write;
    id_ex_next.mem_size = mem_size;
    id_ex_next.mem_unsigned = mem_unsigned;
    id_ex_next.branch = branch;
    id_ex_next.jump = jump;
    id_ex_next.jalr = jalr;
    id_ex_next.uses_rs1 = uses_rs1;
    id_ex_next.uses_rs2 = uses_rs2;
    id_ex_next.predicted_taken = if_id.predicted_taken;
    id_ex_next.predicted_target = if_id.predicted_target;
    id_ex_next.predictor_valid = if_id.predictor_valid;
  end
endmodule
