module mem_stage (
  input  rv32i_pkg::ex_mem_reg_t ex_mem,
  input  rv32i_pkg::dmem_resp_t  dmem_resp,
  output rv32i_pkg::dmem_req_t  dmem_req,
  output rv32i_pkg::mem_wb_reg_t mem_wb_next
);
  import rv32i_pkg::*;
  logic [31:0] shifted_load;
  logic [31:0] load_value;
  logic [31:0] store_data;
  logic [3:0] byte_enable;

  always_comb begin
    store_data = ex_mem.store_data;
    byte_enable = 4'b0000;
    if (ex_mem.mem_write) begin
      unique case (ex_mem.mem_size)
        2'b00: begin
          byte_enable = 4'b0001 << ex_mem.alu_result[1:0];
          store_data = ex_mem.store_data << (8 * ex_mem.alu_result[1:0]);
        end
        2'b01: begin
          byte_enable = 4'b0011 << {ex_mem.alu_result[1], 1'b0};
          store_data = ex_mem.store_data << (16 * ex_mem.alu_result[1]);
        end
        default: byte_enable = 4'b1111;
      endcase
    end
    dmem_req = '0;
    dmem_req.valid = ex_mem.valid && (ex_mem.mem_read || ex_mem.mem_write);
    dmem_req.write = ex_mem.valid && ex_mem.mem_write;
    dmem_req.addr = {ex_mem.alu_result[31:2], 2'b00};
    dmem_req.wdata = store_data;
    dmem_req.byte_enable = byte_enable;

    shifted_load = dmem_resp.rdata >> (8 * ex_mem.alu_result[1:0]);
    load_value = dmem_resp.rdata;
    unique case (ex_mem.mem_size)
      2'b00: load_value = ex_mem.mem_unsigned
        ? {24'd0, shifted_load[7:0]}
        : {{24{shifted_load[7]}}, shifted_load[7:0]};
      2'b01: load_value = ex_mem.mem_unsigned
        ? {16'd0, shifted_load[15:0]}
        : {{16{shifted_load[15]}}, shifted_load[15:0]};
      default: load_value = dmem_resp.rdata;
    endcase

    mem_wb_next = MEM_WB_RESET;
    mem_wb_next.valid = ex_mem.valid;
    mem_wb_next.pc = ex_mem.pc;
    mem_wb_next.instr = ex_mem.instr;
    mem_wb_next.alu_result = ex_mem.alu_result;
    mem_wb_next.load_data = load_value;
    mem_wb_next.rd = ex_mem.rd;
    mem_wb_next.reg_write = ex_mem.reg_write;
    mem_wb_next.mem_read = ex_mem.mem_read;
    mem_wb_next.mem_unsigned = ex_mem.mem_unsigned;
    mem_wb_next.mem_size = ex_mem.mem_size;
  end
endmodule
