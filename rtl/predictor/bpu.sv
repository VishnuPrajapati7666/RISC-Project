module bpu (
  input  logic        clk,
  input  logic        reset,
  input  logic [31:0] fetch_pc,
  input  logic [31:0] fetch_instr,
  output logic [31:0] predicted_next_pc,
  output logic [31:0] predicted_target,
  output logic        predicted_taken,
  output logic        prediction_valid,
  output logic        btb_hit,
  input  logic        resolve_valid,
  input  logic [31:0] resolve_pc,
  input  logic [31:0] resolve_target,
  input  logic        resolve_taken,
  input  logic        resolve_conditional,
  input  logic        resolve_jump
);
  import rv32i_pkg::*;

  logic        btb_valid [0:63];
  logic [23:0] btb_tag   [0:63];
  logic [31:0] btb_target[0:63];
  logic [1:0]  bht       [0:63];
  integer i;

  logic [5:0] fetch_index;
  logic [5:0] resolve_index;
  logic [23:0] fetch_tag;
  logic [23:0] resolve_tag;
  logic [6:0] fetch_opcode;
  logic is_branch;
  logic is_jal;
  logic is_jalr;
  logic [31:0] jal_target;
  logic [31:0] jal_imm;
  logic [31:0] btb_target_value;
  logic [1:0]  bht_value;

  assign fetch_index = fetch_pc[7:2];
  assign fetch_tag = fetch_pc[31:8];
  assign resolve_index = resolve_pc[7:2];
  assign resolve_tag = resolve_pc[31:8];
  assign fetch_opcode = fetch_instr[6:0];
  assign is_branch = (fetch_opcode == OPCODE_BRANCH);
  assign is_jal = (fetch_opcode == OPCODE_JAL);
  assign is_jalr = (fetch_opcode == OPCODE_JALR);

  assign jal_imm = {{11{fetch_instr[31]}}, fetch_instr[31],
                    fetch_instr[19:12], fetch_instr[20],
                    fetch_instr[30:21], 1'b0};
  assign jal_target = fetch_pc + jal_imm;
  assign btb_hit = btb_valid[fetch_index] &&
                   (btb_tag[fetch_index] == fetch_tag);
  assign btb_target_value = btb_target[fetch_index];
  assign bht_value = bht[fetch_index];

  // Policy:
  // - conditional branches use the BTB and predict taken for BHT states 10/11;
  // - direct JAL is always predicted taken from its encoded target;
  // - JALR is not predicted because its target depends on a register;
  // - all other instructions predict sequential execution.
  always_comb begin
    predicted_next_pc = fetch_pc + 32'd4;
    predicted_target = fetch_pc + 32'd4;
    predicted_taken = 1'b0;
    prediction_valid = 1'b0;

    if (is_branch && btb_hit) begin
      prediction_valid = 1'b1;
      predicted_taken = (bht_value >= 2'b10);
      predicted_target = predicted_taken ? btb_target_value
                                         : (fetch_pc + 32'd4);
      predicted_next_pc = predicted_target;
    end else if (is_jal) begin
      prediction_valid = 1'b1;
      predicted_taken = 1'b1;
      predicted_target = jal_target;
      predicted_next_pc = jal_target;
    end else if (is_jalr) begin
      prediction_valid = 1'b0;
    end
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      for (i = 0; i < 64; i = i + 1) begin
        btb_valid[i] <= 1'b0;
        btb_tag[i] <= 24'd0;
        btb_target[i] <= 32'd0;
        bht[i] <= 2'b01;
      end
    end else if (resolve_valid) begin
      if (resolve_conditional) begin
        if (resolve_taken) begin
          if (bht[resolve_index] != 2'b11)
            bht[resolve_index] <= bht[resolve_index] + 2'b01;
        end else if (bht[resolve_index] != 2'b00) begin
          bht[resolve_index] <= bht[resolve_index] - 2'b01;
        end
      end

      if (resolve_taken || resolve_jump) begin
        btb_valid[resolve_index] <= 1'b1;
        btb_tag[resolve_index] <= resolve_tag;
        btb_target[resolve_index] <= resolve_target;
      end
    end
  end
endmodule
