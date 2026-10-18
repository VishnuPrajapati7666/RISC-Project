module single_cycle_core (
  input  logic                  clk,
  input  logic                  reset,
  input  rv32i_pkg::imem_resp_t imem_resp,
  output rv32i_pkg::imem_req_t  imem_req,
  input  rv32i_pkg::dmem_resp_t dmem_resp,
  output rv32i_pkg::dmem_req_t  dmem_req,
  output rv32i_pkg::retire_t    retire,
  output logic [63:0]           mcycle,
  output logic [63:0]           minstret,
  output logic [31:0]           current_pc
);
  import rv32i_pkg::*;

  logic [31:0] pc;
  logic [31:0] instruction;
  logic        dec_valid;
  opcode_t    opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rs1, rs2, rd;
  imm_format_t imm_format;
  alu_op_t alu_op;
  branch_cond_t branch_cond;
  logic alu_src_imm, reg_write, mem_read, mem_write, mem_unsigned;
  logic branch, jump, jalr, uses_rs1, uses_rs2;
  logic [1:0] mem_size;
  logic [31:0] rs1_value, rs2_value, immediate, alu_b, alu_result;
  logic [31:0] writeback_value;
  logic [31:0] next_pc;
  logic branch_taken;
  logic [31:0] target;
  logic [31:0] load_value;
  logic [31:0] shifted_load;
  logic [3:0] byte_enable;
  logic [31:0] store_data;
  logic rf_we;

  assign imem_req.valid = !reset;
  assign imem_req.addr = pc;
  assign instruction = imem_resp.rdata;
  assign current_pc = pc;

  decoder u_decoder (
    .instruction(instruction), .valid(dec_valid), .opcode(opcode),
    .funct3(funct3), .funct7(funct7), .rs1(rs1), .rs2(rs2), .rd(rd),
    .immediate_format(imm_format), .alu_op(alu_op),
    .branch_cond(branch_cond), .alu_src_immediate(alu_src_imm),
    .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
    .mem_size(mem_size), .mem_unsigned(mem_unsigned), .branch(branch),
    .jump(jump), .jalr(jalr), .uses_rs1(uses_rs1), .uses_rs2(uses_rs2)
  );

  imm_gen u_imm_gen (
    .format(imm_format), .instruction(instruction), .immediate(immediate)
  );

  regfile u_regfile (
    .clk(clk), .reset(reset), .write_enable(rf_we), .write_addr(rd),
    .write_data(writeback_value), .read_addr_a(rs1), .read_addr_b(rs2),
    .read_data_a(rs1_value), .read_data_b(rs2_value)
  );

  assign alu_b = (opcode == OPCODE_AUIPC) ? immediate :
                 (alu_src_imm ? immediate : rs2_value);

  alu u_alu (.op(alu_op), .a((opcode == OPCODE_AUIPC) ? pc : rs1_value),
             .b(alu_b), .y(alu_result));

  always_comb begin
    branch_taken = 1'b0;
    unique case (branch_cond)
      BR_BEQ:  branch_taken = (rs1_value == rs2_value);
      BR_BNE:  branch_taken = (rs1_value != rs2_value);
      BR_BLT:  branch_taken = ($signed(rs1_value) < $signed(rs2_value));
      BR_BGE:  branch_taken = ($signed(rs1_value) >= $signed(rs2_value));
      BR_BLTU: branch_taken = (rs1_value < rs2_value);
      BR_BGEU: branch_taken = (rs1_value >= rs2_value);
      default: branch_taken = 1'b0;
    endcase

    target = jalr ? ((rs1_value + immediate) & 32'hffff_fffe)
                  : (pc + immediate);
    next_pc = pc + 32'd4;
    if (branch && branch_taken) next_pc = target;
    else if (jump) next_pc = target;

    store_data = rs2_value;
    byte_enable = 4'b0000;
    if (mem_write) begin
      unique case (mem_size)
        2'b00: begin
          byte_enable = 4'b0001 << alu_result[1:0];
          store_data = rs2_value << (8 * alu_result[1:0]);
        end
        2'b01: begin
          byte_enable = 4'b0011 << {alu_result[1], 1'b0};
          store_data = rs2_value << (16 * alu_result[1]);
        end
        default: begin
          byte_enable = 4'b1111;
          store_data = rs2_value;
        end
      endcase
    end

    dmem_req = '0;
    dmem_req.valid = mem_read || mem_write;
    dmem_req.write = mem_write;
    dmem_req.addr = {alu_result[31:2], 2'b00};
    dmem_req.wdata = store_data;
    dmem_req.byte_enable = byte_enable;

    shifted_load = dmem_resp.rdata >> (8 * alu_result[1:0]);
    load_value = dmem_resp.rdata;
    unique case (mem_size)
      2'b00: load_value = mem_unsigned
        ? {24'd0, shifted_load[7:0]}
        : {{24{shifted_load[7]}}, shifted_load[7:0]};
      2'b01: load_value = mem_unsigned
        ? {16'd0, shifted_load[15:0]}
        : {{16{shifted_load[15]}}, shifted_load[15:0]};
      default: load_value = dmem_resp.rdata;
    endcase

    writeback_value = mem_read ? load_value :
                      (jump ? pc + 32'd4 : alu_result);
    rf_we = dec_valid && reg_write && (rd != 5'd0);

    retire = '0;
    retire.valid = dec_valid && imem_resp.valid;
    retire.pc = pc;
    retire.instr = instruction;
    retire.rd = rd;
    retire.rd_value = writeback_value;
    retire.rd_write = rf_we;
    retire.trap = 1'b0;
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      pc <= RESET_PC;
      mcycle <= 64'd0;
      minstret <= 64'd0;
    end else begin
      pc <= next_pc;
      mcycle <= mcycle + 64'd1;
      if (retire.valid) minstret <= minstret + 64'd1;
    end
  end
endmodule
