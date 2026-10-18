package rv32i_pkg;

  // RV32I base opcodes. SYSTEM and FENCE are named separately because their
  // decode and architectural side effects are distinct from arithmetic ops.
  typedef enum logic [6:0] {
    OPCODE_LOAD    = 7'b0000011,
    OPCODE_OP_IMM  = 7'b0010011,
    OPCODE_AUIPC   = 7'b0010111,
    OPCODE_STORE   = 7'b0100011,
    OPCODE_OP      = 7'b0110011,
    OPCODE_LUI     = 7'b0110111,
    OPCODE_BRANCH  = 7'b1100011,
    OPCODE_JALR    = 7'b1100111,
    OPCODE_JAL     = 7'b1101111,
    OPCODE_FENCE   = 7'b0001111,
    OPCODE_SYSTEM  = 7'b1110011
  } opcode_t;

  typedef enum logic [3:0] {
    ALU_ADD    = 4'd0,
    ALU_SUB    = 4'd1,
    ALU_SLL    = 4'd2,
    ALU_SLT    = 4'd3,
    ALU_SLTU   = 4'd4,
    ALU_XOR    = 4'd5,
    ALU_SRL    = 4'd6,
    ALU_SRA    = 4'd7,
    ALU_OR     = 4'd8,
    ALU_AND    = 4'd9,
    ALU_PASS_B = 4'd10
  } alu_op_t;

  typedef enum logic [2:0] {
    BR_BEQ  = 3'd0,
    BR_BNE  = 3'd1,
    BR_BLT  = 3'd2,
    BR_BGE  = 3'd3,
    BR_BLTU = 3'd4,
    BR_BGEU = 3'd5
  } branch_cond_t;

  typedef enum logic [2:0] {
    IMM_I = 3'd0,
    IMM_S = 3'd1,
    IMM_B = 3'd2,
    IMM_U = 3'd3,
    IMM_J = 3'd4
  } imm_format_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] pc_next;
    logic [31:0] predicted_target;
    logic        predicted_taken;
    logic        predictor_valid;
  } if_id_reg_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] pc_next;
    opcode_t     opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;
    logic [31:0] rs1_value;
    logic [31:0] rs2_value;
    logic [31:0] immediate;
    imm_format_t immediate_format;
    alu_op_t     alu_op;
    branch_cond_t branch_cond;
    logic        alu_src_immediate;
    logic        reg_write;
    logic        mem_read;
    logic        mem_write;
    logic [1:0]  mem_size;
    logic        mem_unsigned;
    logic        branch;
    logic        jump;
    logic        jalr;
    logic        uses_rs1;
    logic        uses_rs2;
    logic        predicted_taken;
    logic [31:0] predicted_target;
    logic        predictor_valid;
  } id_ex_reg_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] pc_next;
    logic [31:0] alu_result;
    logic [31:0] store_data;
    logic [31:0] branch_target;
    logic [31:0] predicted_target;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [2:0]  funct3;
    logic        reg_write;
    logic        mem_read;
    logic        mem_write;
    logic [1:0]  mem_size;
    logic        mem_unsigned;
    logic        branch;
    logic        jump;
    logic        jalr;
    logic        branch_taken;
    logic        predicted_taken;
    logic        predictor_valid;
    logic        mispredict;
  } ex_mem_reg_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] alu_result;
    logic [31:0] load_data;
    logic [4:0]  rd;
    logic        reg_write;
    logic        mem_read;
    logic        mem_unsigned;
    logic [1:0]  mem_size;
  } mem_wb_reg_t;

  localparam if_id_reg_t  IF_ID_RESET  = '0;
  localparam id_ex_reg_t  ID_EX_RESET  = '0;
  localparam ex_mem_reg_t EX_MEM_RESET = '0;
  localparam mem_wb_reg_t MEM_WB_RESET = '0;

  typedef struct packed {
    logic        valid;
    logic [31:0] addr;
    logic [31:0] rdata;
    logic        ready;
  } imem_resp_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] addr;
  } imem_req_t;

  typedef struct packed {
    logic        valid;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  byte_enable;
  } dmem_req_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] rdata;
    logic        ready;
  } dmem_resp_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] instr;
    logic [4:0]  rd;
    logic [31:0] rd_value;
    logic        rd_write;
    logic        trap;
  } retire_t;

  typedef struct packed {
    logic        mcycle_en;
    logic        minstret_en;
  } counter_update_t;

  // Counter ownership:
  // - The top-level core owns and updates mcycle once per rising clock while
  //   reset is inactive.
  // - The retirement unit owns and asserts minstret_en for each valid,
  //   architecturally retired instruction. The top level performs the single
  //   minstret increment using that pulse.
  typedef logic [63:0] counter_t;

  localparam logic [31:0] RESET_PC = 32'h0000_0000;

endpackage
