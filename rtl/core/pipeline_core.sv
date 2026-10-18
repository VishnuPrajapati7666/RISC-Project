module pipeline_core #(
  parameter ENABLE_BPU = 1'b1
) (
  input  logic                  clk,
  input  logic                  reset,
  input  rv32i_pkg::imem_resp_t imem_resp,
  output rv32i_pkg::imem_req_t  imem_req,
  input rv32i_pkg::dmem_resp_t dmem_resp,
  output rv32i_pkg::dmem_req_t  dmem_req,
  output rv32i_pkg::retire_t    retire,
  output logic [63:0]           mcycle,
  output logic [63:0]           minstret,
  output logic [31:0]           current_pc,
  output rv32i_pkg::if_id_reg_t if_id_monitor,
  output rv32i_pkg::id_ex_reg_t id_ex_monitor,
  output rv32i_pkg::ex_mem_reg_t ex_mem_monitor,
  output rv32i_pkg::mem_wb_reg_t mem_wb_monitor,
  output logic [63:0]           stall_cycles,
  output logic [63:0]           flush_cycles,
  output logic [1:0]            forward_a_monitor,
  output logic [1:0]            forward_b_monitor,
  output logic                  load_use_stall_monitor,
  output logic                  redirect_monitor,
  output logic [63:0]           prediction_attempts,
  output logic [63:0]           prediction_correct,
  output logic [63:0]           prediction_mispredicts
);
  import rv32i_pkg::*;

  logic [31:0] pc;
  if_id_reg_t if_id_reg, if_id_next;
  id_ex_reg_t id_ex_reg, id_ex_next;
  ex_mem_reg_t ex_mem_reg, ex_mem_next;
  mem_wb_reg_t mem_wb_reg, mem_wb_next;
  logic [31:0] rs1_value, rs2_value;
  logic [4:0] rs1_addr, rs2_addr;
  logic decoded_valid, decoded_uses_rs1, decoded_uses_rs2;
  logic [4:0] decoded_rs1, decoded_rs2;
  logic [31:0] forwarded_rs1, forwarded_rs2;
  logic [1:0] forward_a_sel, forward_b_sel;
  logic load_use_stall;
  logic [63:0] stall_cycles_reg;
  logic [63:0] flush_cycles_reg;
  logic [63:0] prediction_attempts_reg;
  logic [63:0] prediction_correct_reg;
  logic [63:0] prediction_mispredicts_reg;
  logic rf_write_enable;
  logic [4:0] rf_write_addr;
  logic [31:0] rf_write_data;
  logic redirect;
  logic [31:0] redirect_pc;
  logic [31:0] bpu_next_pc;
  logic [31:0] bpu_target;
  logic bpu_taken;
  logic bpu_valid;
  logic btb_hit;
  logic resolve_valid, resolve_conditional, resolve_taken;
  logic [31:0] resolve_pc, resolve_target;
  logic [31:0] predicted_next_pc;
  logic [31:0] predicted_target;
  logic predicted_taken, prediction_valid;
  logic data_wait_reg;
  logic frontend_stall;
  logic data_stall;
  logic mem_complete;
  dmem_req_t raw_dmem_req;
  mem_wb_reg_t raw_mem_wb_next;

  if_stage u_if (
    .reset(reset), .pc(pc), .imem_resp(imem_resp),
    .predicted_next_pc(predicted_next_pc),
    .predicted_target(predicted_target),
    .predicted_taken(predicted_taken),
    .prediction_valid(prediction_valid),
    .imem_req(imem_req), .payload(if_id_next)
  );
  bpu u_bpu (
    .clk(clk), .reset(reset), .fetch_pc(pc), .fetch_instr(imem_resp.rdata),
    .predicted_next_pc(bpu_next_pc), .predicted_target(bpu_target),
    .predicted_taken(bpu_taken), .prediction_valid(bpu_valid),
    .btb_hit(btb_hit), .resolve_valid(resolve_valid),
    .resolve_pc(resolve_pc), .resolve_target(resolve_target),
    .resolve_taken(resolve_taken),
    .resolve_conditional(resolve_conditional),
    .resolve_jump(id_ex_reg.valid && id_ex_reg.jump)
  );
  id_stage u_id (
    .if_id(if_id_reg), .rs1_value(rs1_value), .rs2_value(rs2_value),
    .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
    .decoded_valid(decoded_valid), .decoded_uses_rs1(decoded_uses_rs1),
    .decoded_uses_rs2(decoded_uses_rs2), .decoded_rs1(decoded_rs1),
    .decoded_rs2(decoded_rs2), .id_ex_next(id_ex_next)
  );
  forwarding_unit u_forward (
    .id_ex_valid(id_ex_reg.valid), .uses_rs1(id_ex_reg.uses_rs1),
    .uses_rs2(id_ex_reg.uses_rs2), .rs1(id_ex_reg.rs1), .rs2(id_ex_reg.rs2),
    .rs1_value(id_ex_reg.rs1_value), .rs2_value(id_ex_reg.rs2_value),
    .ex_mem_valid(ex_mem_reg.valid), .ex_mem_reg_write(ex_mem_reg.reg_write),
    .ex_mem_mem_read(ex_mem_reg.mem_read), .ex_mem_rd(ex_mem_reg.rd),
    .ex_mem_value(ex_mem_reg.alu_result),
    .mem_wb_valid(mem_wb_reg.valid), .mem_wb_reg_write(mem_wb_reg.reg_write),
    .mem_wb_rd(mem_wb_reg.rd), .mem_wb_value(rf_write_data),
    .forward_a_sel(forward_a_sel), .forward_b_sel(forward_b_sel),
    .operand_a(forwarded_rs1), .operand_b(forwarded_rs2)
  );
  hazard_unit u_hazard (
    .if_id_valid(if_id_reg.valid), .if_id_uses_rs1(decoded_uses_rs1),
    .if_id_uses_rs2(decoded_uses_rs2), .if_id_rs1(decoded_rs1),
    .if_id_rs2(decoded_rs2), .id_ex_valid(id_ex_reg.valid),
    .id_ex_mem_read(id_ex_reg.mem_read), .id_ex_rd(id_ex_reg.rd),
    .load_use_stall(load_use_stall)
  );
  ex_stage u_ex (
    .id_ex(id_ex_reg), .ex_mem_next(ex_mem_next),
    .operand_a(forwarded_rs1), .operand_b(forwarded_rs2),
    .redirect(redirect), .redirect_pc(redirect_pc),
    .resolve_valid(resolve_valid),
    .resolve_conditional(resolve_conditional),
    .resolve_taken(resolve_taken),
    .resolve_pc(resolve_pc),
    .resolve_target(resolve_target)
  );
  mem_stage u_mem (
    .ex_mem(ex_mem_reg), .dmem_resp(dmem_resp),
    .dmem_req(raw_dmem_req), .mem_wb_next(raw_mem_wb_next)
  );
  wb_stage u_wb (
    .mem_wb(mem_wb_reg), .write_enable(rf_write_enable),
    .write_addr(rf_write_addr), .write_data(rf_write_data),
    .retire(retire)
  );
  regfile u_regfile (
    .clk(clk), .reset(reset), .write_enable(rf_write_enable),
    .write_addr(rf_write_addr), .write_data(rf_write_data),
    .read_addr_a(rs1_addr), .read_addr_b(rs2_addr),
    .read_data_a(rs1_value), .read_data_b(rs2_value)
  );

  assign current_pc = pc;
  always_comb begin
    dmem_req = raw_dmem_req;
    dmem_req.valid = raw_dmem_req.valid && !data_wait_reg;
  end
  assign frontend_stall = imem_req.valid &&
                          !(imem_resp.valid && imem_resp.ready);
  assign mem_complete = !ex_mem_reg.valid ||
                        !(ex_mem_reg.mem_read || ex_mem_reg.mem_write) ||
                        (data_wait_reg ? dmem_resp.valid :
                         (dmem_resp.ready && dmem_resp.valid));
  assign data_stall = ex_mem_reg.valid &&
                      (ex_mem_reg.mem_read || ex_mem_reg.mem_write) &&
                      !mem_complete;
  assign predicted_next_pc = ENABLE_BPU ? bpu_next_pc : (pc + 32'd4);
  assign predicted_target = ENABLE_BPU ? bpu_target : (pc + 32'd4);
  assign predicted_taken = ENABLE_BPU ? bpu_taken : 1'b0;
  assign prediction_valid = ENABLE_BPU ? bpu_valid : 1'b0;
  assign if_id_monitor = if_id_reg;
  assign id_ex_monitor = id_ex_reg;
  assign ex_mem_monitor = ex_mem_reg;
  assign mem_wb_monitor = mem_wb_reg;
  assign stall_cycles = stall_cycles_reg;
  assign flush_cycles = flush_cycles_reg;
  assign forward_a_monitor = forward_a_sel;
  assign forward_b_monitor = forward_b_sel;
  assign load_use_stall_monitor = load_use_stall;
  assign redirect_monitor = redirect;
  assign prediction_attempts = prediction_attempts_reg;
  assign prediction_correct = prediction_correct_reg;
  assign prediction_mispredicts = prediction_mispredicts_reg;

  // Priority for the front-end registers is reset > older EX recovery >
  // load-use stall > ordinary advancement. A recovery flush discards both
  // younger front-end payloads; a load-use stall holds IF/ID and PC while
  // inserting one invalid ID/EX bubble.
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      pc <= RESET_PC;
      if_id_reg <= IF_ID_RESET;
      id_ex_reg <= ID_EX_RESET;
      ex_mem_reg <= EX_MEM_RESET;
      mem_wb_reg <= MEM_WB_RESET;
      mcycle <= 64'd0;
      minstret <= 64'd0;
      stall_cycles_reg <= 64'd0;
      flush_cycles_reg <= 64'd0;
      prediction_attempts_reg <= 64'd0;
      prediction_correct_reg <= 64'd0;
      prediction_mispredicts_reg <= 64'd0;
      data_wait_reg <= 1'b0;
    end else begin
      if (raw_dmem_req.valid && dmem_resp.ready && !dmem_resp.valid)
        data_wait_reg <= 1'b1;
      else if (data_wait_reg && dmem_resp.valid)
        data_wait_reg <= 1'b0;

      if (data_stall) begin
        pc <= pc;
        if_id_reg <= if_id_reg;
        id_ex_reg <= id_ex_reg;
        ex_mem_reg <= ex_mem_reg;
        mem_wb_reg <= raw_mem_wb_next;
      end else if (redirect) begin
        pc <= redirect_pc;
        if_id_reg <= IF_ID_RESET;
        id_ex_reg <= ID_EX_RESET;
        flush_cycles_reg <= flush_cycles_reg + 64'd1;
      end else if (load_use_stall) begin
        pc <= pc;
        if_id_reg <= if_id_reg;
        id_ex_reg <= ID_EX_RESET;
        stall_cycles_reg <= stall_cycles_reg + 64'd1;
      end else if (frontend_stall) begin
        pc <= pc;
        if_id_reg <= if_id_reg;
        id_ex_reg <= id_ex_reg;
      end else begin
        pc <= predicted_next_pc;
        if_id_reg <= if_id_next;
        id_ex_reg <= id_ex_next;
      end
      if (!data_stall)
        ex_mem_reg <= ex_mem_next;
      if (!data_stall || mem_complete)
        mem_wb_reg <= raw_mem_wb_next;
      mcycle <= mcycle + 64'd1;
      if (retire.valid) minstret <= minstret + 64'd1;
      if (resolve_valid && resolve_conditional) begin
        prediction_attempts_reg <= prediction_attempts_reg + 64'd1;
        if (redirect)
          prediction_mispredicts_reg <= prediction_mispredicts_reg + 64'd1;
        else
          prediction_correct_reg <= prediction_correct_reg + 64'd1;
      end
    end
  end
endmodule
