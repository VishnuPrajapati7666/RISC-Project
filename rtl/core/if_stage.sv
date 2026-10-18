module if_stage (
  input  logic                 reset,
  input  logic [31:0]          pc,
  input  rv32i_pkg::imem_resp_t imem_resp,
  input  logic [31:0]          predicted_next_pc,
  input  logic [31:0]          predicted_target,
  input  logic                 predicted_taken,
  input  logic                 prediction_valid,
  output rv32i_pkg::imem_req_t  imem_req,
  output rv32i_pkg::if_id_reg_t  payload
);
  import rv32i_pkg::*;

  always_comb begin
    imem_req = '0;
    imem_req.valid = !reset;
    imem_req.addr = pc;
    payload = IF_ID_RESET;
    payload.valid = imem_resp.valid && imem_resp.ready;
    payload.pc = pc;
    payload.instr = imem_resp.rdata;
    payload.pc_next = pc + 32'd4;
    payload.predicted_target = predicted_target;
    payload.predicted_taken = predicted_taken;
    payload.predictor_valid = prediction_valid;
  end
endmodule
