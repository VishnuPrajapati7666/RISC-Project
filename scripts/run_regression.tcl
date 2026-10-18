set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root results]
file mkdir $out
set iverilog C:/iverilog/bin/iverilog.exe
set vvp C:/iverilog/bin/vvp.exe
set common [list rtl/common/rv32i_pkg.sv rtl/common/alu.sv rtl/common/regfile.sv rtl/common/imm_gen.sv]
set cache [list rtl/cache/icache.sv rtl/cache/dcache.sv rtl/cache/cache_arbiter.sv rtl/memory/memory_controller.sv rtl/memory/main_memory_model.sv]
set core [list rtl/core/decoder.sv rtl/core/if_stage.sv rtl/core/id_stage.sv rtl/core/ex_stage.sv rtl/core/mem_stage.sv rtl/core/wb_stage.sv rtl/core/branch_unit.sv rtl/core/pipeline_core.sv rtl/core/single_cycle_core.sv rtl/memory/reference_memory.sv]
set tests [list \
  [list stage6_cache_tb [concat $common $cache tb/stage6_cache_tb.sv]] \
  [list rv32i_soc_tb [concat $common $core $cache rtl/top/rv32i_soc_top.sv rtl/verification/core_sva_checker.sv tb/rv32i_soc_tb.sv]]]
set log_file [open [file join $out regression.log] w]
foreach test $tests {
  lassign $test name files
  set vvp_file [file join $out ${name}.vvp]
  puts $log_file "=== $name ==="
  if {[catch {exec $iverilog -g2012 -o $vvp_file {*}$files} result]} {
    puts $log_file $result
    close $log_file
    error "compile failed for $name"
  }
  if {[catch {exec $vvp_file} result]} {
    puts $log_file $result
    close $log_file
    error "simulation failed for $name"
  }
  puts $log_file $result
}
close $log_file
puts "Regression PASS; log written to $out/regression.log"
