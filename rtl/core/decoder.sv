module decoder (
  input  logic [31:0] instruction,
  output logic        valid,
  output rv32i_pkg::opcode_t opcode,
  output logic [2:0] funct3,
  output logic [6:0] funct7,
  output logic [4:0] rs1,
  output logic [4:0] rs2,
  output logic [4:0] rd,
  output rv32i_pkg::imm_format_t immediate_format,
  output rv32i_pkg::alu_op_t alu_op,
  output rv32i_pkg::branch_cond_t branch_cond,
  output logic        alu_src_immediate,
  output logic        reg_write,
  output logic        mem_read,
  output logic        mem_write,
  output logic [1:0]  mem_size,
  output logic        mem_unsigned,
  output logic        branch,
  output logic        jump,
  output logic        jalr,
  output logic        uses_rs1,
  output logic        uses_rs2
);
  import rv32i_pkg::*;

  always_comb begin
    opcode = opcode_t'(instruction[6:0]);
    funct3 = instruction[14:12];
    funct7 = instruction[31:25];
    rs1 = instruction[19:15];
    rs2 = instruction[24:20];
    rd = instruction[11:7];
    valid = 1'b1;
    immediate_format = IMM_I;
    alu_op = ALU_ADD;
    branch_cond = BR_BEQ;
    alu_src_immediate = 1'b0;
    reg_write = 1'b0;
    mem_read = 1'b0;
    mem_write = 1'b0;
    mem_size = 2'b10;
    mem_unsigned = 1'b0;
    branch = 1'b0;
    jump = 1'b0;
    jalr = 1'b0;
    uses_rs1 = 1'b0;
    uses_rs2 = 1'b0;

    unique case (opcode)
      OPCODE_OP: begin
        reg_write = 1'b1;
        uses_rs1 = 1'b1;
        uses_rs2 = 1'b1;
        unique case (funct3)
          3'b000: begin
            if (funct7 == 7'b0100000) alu_op = ALU_SUB;
            else alu_op = ALU_ADD;
          end
          3'b001: alu_op = ALU_SLL;
          3'b010: alu_op = ALU_SLT;
          3'b011: alu_op = ALU_SLTU;
          3'b100: alu_op = ALU_XOR;
          3'b101: begin
            if (funct7 == 7'b0100000) alu_op = ALU_SRA;
            else alu_op = ALU_SRL;
          end
          3'b110: alu_op = ALU_OR;
          3'b111: alu_op = ALU_AND;
          default: begin valid = 1'b0; reg_write = 1'b0; end
        endcase
      end
      OPCODE_OP_IMM: begin
        reg_write = 1'b1;
        uses_rs1 = 1'b1;
        alu_src_immediate = 1'b1;
        unique case (funct3)
          3'b000: alu_op = ALU_ADD;
          3'b010: alu_op = ALU_SLT;
          3'b011: alu_op = ALU_SLTU;
          3'b100: alu_op = ALU_XOR;
          3'b110: alu_op = ALU_OR;
          3'b111: alu_op = ALU_AND;
          3'b001: alu_op = ALU_SLL;
          3'b101: begin
            if (instruction[30]) alu_op = ALU_SRA;
            else alu_op = ALU_SRL;
          end
          default: begin valid = 1'b0; reg_write = 1'b0; end
        endcase
      end
      OPCODE_LOAD: begin
        reg_write = 1'b1;
        mem_read = 1'b1;
        uses_rs1 = 1'b1;
        alu_src_immediate = 1'b1;
        alu_op = ALU_ADD;
        immediate_format = IMM_I;
        unique case (funct3)
          3'b000: begin mem_size = 2'b00; mem_unsigned = 1'b0; end
          3'b001: begin mem_size = 2'b01; mem_unsigned = 1'b0; end
          3'b010: begin mem_size = 2'b10; mem_unsigned = 1'b0; end
          3'b100: begin mem_size = 2'b00; mem_unsigned = 1'b1; end
          3'b101: begin mem_size = 2'b01; mem_unsigned = 1'b1; end
          default: begin valid = 1'b0; reg_write = 1'b0; mem_read = 1'b0; end
        endcase
      end
      OPCODE_STORE: begin
        mem_write = 1'b1;
        uses_rs1 = 1'b1;
        uses_rs2 = 1'b1;
        alu_src_immediate = 1'b1;
        alu_op = ALU_ADD;
        immediate_format = IMM_S;
        unique case (funct3)
          3'b000: mem_size = 2'b00;
          3'b001: mem_size = 2'b01;
          3'b010: mem_size = 2'b10;
          default: begin valid = 1'b0; mem_write = 1'b0; end
        endcase
      end
      OPCODE_BRANCH: begin
        branch = 1'b1;
        uses_rs1 = 1'b1;
        uses_rs2 = 1'b1;
        immediate_format = IMM_B;
        unique case (funct3)
          3'b000: branch_cond = BR_BEQ;
          3'b001: branch_cond = BR_BNE;
          3'b100: branch_cond = BR_BLT;
          3'b101: branch_cond = BR_BGE;
          3'b110: branch_cond = BR_BLTU;
          3'b111: branch_cond = BR_BGEU;
          default: begin valid = 1'b0; branch = 1'b0; end
        endcase
      end
      OPCODE_JAL: begin
        jump = 1'b1;
        reg_write = 1'b1;
        immediate_format = IMM_J;
        alu_op = ALU_ADD;
      end
      OPCODE_JALR: begin
        jump = 1'b1;
        jalr = 1'b1;
        reg_write = 1'b1;
        uses_rs1 = 1'b1;
        immediate_format = IMM_I;
        alu_op = ALU_ADD;
      end
      OPCODE_LUI: begin
        reg_write = 1'b1;
        alu_src_immediate = 1'b1;
        immediate_format = IMM_U;
        alu_op = ALU_PASS_B;
      end
      OPCODE_AUIPC: begin
        reg_write = 1'b1;
        immediate_format = IMM_U;
        alu_op = ALU_ADD;
      end
      OPCODE_FENCE: begin
        // Reference memory is single-cycle and globally ordered; FENCE is a
        // completed no-op in this implementation.
      end
      default: begin
        valid = 1'b0;
      end
    endcase
  end
endmodule
