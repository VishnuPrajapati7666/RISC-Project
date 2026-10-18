set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root results]
file mkdir $out
set report [file join $out synthesis_timing.md]
set f [open $report w]
puts $f "# Technology-independent synthesis status"
puts $f ""
puts $f "This project has no FPGA target part and does not run placement, routing, bitstream, or FPGA timing analysis."
puts $f ""
if {[catch {exec yosys -V} version]} {
  puts $f "Yosys: unavailable"
  puts $f ""
  puts $f "RTL elaboration remains covered by the Icarus regression. Install Yosys to generate technology-independent area and cell reports."
} else {
  puts $f "Yosys: $version"
  set files [list rtl/common/rv32i_pkg.sv rtl/common/alu.sv rtl/common/regfile.sv rtl/common/imm_gen.sv rtl/core/decoder.sv rtl/core/if_stage.sv rtl/core/id_stage.sv rtl/core/ex_stage.sv rtl/core/mem_stage.sv rtl/core/wb_stage.sv rtl/core/branch_unit.sv rtl/core/pipeline_core.sv rtl/top/rv32i_soc_top.sv]
  set yosys_script [file join $out yosys.ys]
  set ys [open $yosys_script w]
  puts $ys "read_verilog -sv {*}$files"
  puts $ys "hierarchy -top rv32i_soc_top"
  puts $ys "proc; opt; stat -json $out/yosys_stat.json"
  close $ys
  if {[catch {exec yosys -s $yosys_script} result]} {
    puts $f "Yosys execution failed: $result"
  } else {
    puts $f "Technology-independent synthesis completed; see yosys_stat.json."
  }
}
close $f
puts "Wrote $report"
