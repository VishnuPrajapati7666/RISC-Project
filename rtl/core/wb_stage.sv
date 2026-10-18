module wb_stage (
  input  rv32i_pkg::mem_wb_reg_t mem_wb,
  output logic                  write_enable,
  output logic [4:0]            write_addr,
  output logic [31:0]           write_data,
  output rv32i_pkg::retire_t    retire
);
  always_comb begin
    write_enable = mem_wb.valid && mem_wb.reg_write && (mem_wb.rd != 5'd0);
    write_addr = mem_wb.rd;
    write_data = mem_wb.mem_read ? mem_wb.load_data : mem_wb.alu_result;
    retire = '0;
    retire.valid = mem_wb.valid;
    retire.pc = mem_wb.pc;
    retire.instr = mem_wb.instr;
    retire.rd = mem_wb.rd;
    retire.rd_value = write_data;
    retire.rd_write = write_enable;
    retire.trap = 1'b0;
  end
endmodule
