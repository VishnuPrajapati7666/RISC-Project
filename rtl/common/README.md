# RV32I RTL foundation

This directory contains the shared SystemVerilog package and common datapath
blocks for the processor stages. The core-specific stage modules are under
`rtl/core`.

## ISA scope

The package names the base RV32I instruction classes:

- `OPCODE_OP`: register-register integer operations.
- `OPCODE_OP_IMM`: immediate integer operations.
- `OPCODE_LOAD` and `OPCODE_STORE`: integer memory operations.
- `OPCODE_BRANCH`, `OPCODE_JAL`, and `OPCODE_JALR`: control flow.
- `OPCODE_LUI` and `OPCODE_AUIPC`: upper-immediate operations.
- `OPCODE_FENCE` and `OPCODE_SYSTEM`: opcode classes are represented for
  decoding.

The package does **not** implement CSR access, traps, interrupts, privilege
levels, or any other privileged extension. `OPCODE_SYSTEM` and the `trap`
field in `retire_t` are interface placeholders for a later explicitly
implemented extension. `FENCE` is similarly represented at the opcode level;
its execution semantics must be implemented by a later control/memory system
before it is claimed as supported.

## Enumerations

- `opcode_t`: 7-bit RISC-V major opcodes.
- `alu_op_t`: the ten required ALU operations, including `ALU_PASS_B`.
- `branch_cond_t`: the six RV32I conditional branch comparisons.
- `imm_format_t`: I, S, B, U, and J immediate encodings.

## Pipeline records

`if_id_reg_t`, `id_ex_reg_t`, `ex_mem_reg_t`, and `mem_wb_reg_t` are packed
records intended to be used directly as pipeline registers.

Every pipeline record has a `valid` bit. The package provides explicit all-zero
reset values (`IF_ID_RESET`, `ID_EX_RESET`, `EX_MEM_RESET`, and `MEM_WB_RESET`).
All four reset values clear `valid` and every payload/control field, making the
pipeline empty and preventing side effects. Normal update rules are:

1. On active-low reset assertion, synchronously or asynchronously according to
   the core's documented reset policy, assign the record's zero value.
2. On a pipeline clock edge without reset, load the next-stage record.
3. On a flush, load the zero value for the flushed record.
4. On a stall, hold the affected record; inject a zero-valued record into the
   next stage when the hazard policy requires a bubble.

The per-register rules are:

- `if_id_reg_t`: reset to `IF_ID_RESET`; otherwise capture the fetched PC,
  instruction, and prediction metadata, or capture `IF_ID_RESET` on a fetch
  flush; hold it during an IF/ID stall.
- `id_ex_reg_t`: reset to `ID_EX_RESET`; otherwise capture decoded operands,
  controls, and prediction metadata, or capture `ID_EX_RESET` for a stall
  bubble or decode flush.
- `ex_mem_reg_t`: reset to `EX_MEM_RESET`; otherwise capture ALU, store,
  branch-resolution, and misprediction results, or capture `EX_MEM_RESET` on a
  flush.
- `mem_wb_reg_t`: reset to `MEM_WB_RESET`; otherwise capture the completed
  ALU/load result and writeback controls, or capture `MEM_WB_RESET` when the
  memory transaction is invalidated.

The intended fields are:

- `if_id_reg_t`: fetched instruction, PC/next PC, and prediction metadata.
- `id_ex_reg_t`: decoded fields, register operands, immediate, ALU/control
  signals, memory controls, and prediction metadata.
- `ex_mem_reg_t`: ALU/branch results, store data, destination/source indices,
  resolved branch outcome, and misprediction metadata.
- `mem_wb_reg_t`: completed ALU/load value and register-writeback controls.

## Memory interfaces

`imem_req_t` and `imem_resp_t` define a request/response instruction-memory
interface. `imem_req_t.valid` qualifies `addr`; `imem_resp_t.valid` qualifies
the returned address/data transaction and `ready` indicates that the response
may be consumed.

`dmem_req_t` supports reads (`write == 0`) and writes (`write == 1`).
`byte_enable` uses one bit per byte of `wdata`, and `dmem_resp_t.ready`
indicates completion. The data-memory implementation owns any wait states.
The Stage 2 reference memory is combinational read, zero-wait-state memory:
an asserted request is answered in the same cycle with `ready == 1`. Writes
commit on the active clock edge. The core aligns the request address to a
32-bit word and uses the low address bits for byte/halfword lane extraction.

## Retirement and counters

`retire_t` is the architectural retirement interface. A valid record identifies
the retired instruction and, when `rd_write` is asserted, its destination
register/value. The `trap` field is reserved for a future explicitly
implemented exception mechanism and must remain low in the current base core.

`mcycle` and `minstret` are 64-bit (`counter_t`) counters. There is one update
owner for each:

- The top-level core owns `mcycle` and increments it once per active clock.
- The retirement unit owns the decision to retire; it asserts
  `counter_update_t.minstret_en` for exactly one cycle per valid retirement.
  The top-level core performs the single `minstret` increment from that pulse.

No counter is updated in a pipeline stage or in more than one sequential
process. Both counters reset to zero. `RESET_PC` is the architectural reset
program counter and is `32'h0000_0000`.

## Vivado/XSim compile command

From the repository root, compile the package with Vivado's SystemVerilog
front end:

```text
 xvlog -sv rtl\common\rv32i_pkg.sv
```

For a project or batch flow, the equivalent Tcl command is:

```tcl
read_verilog -sv rtl\common\rv32i_pkg.sv
```

No top-level module or testbench is defined in this stage.

## Stage 2 reference core timing

The single-cycle reference core uses an asynchronous reset, a combinational
instruction-memory read, and a combinational data-memory read. One instruction
is fetched, decoded, executed, and retired on each active clock edge. Stores
commit on that edge. The reference memory therefore has zero read wait states;
later cache or external-memory implementations may replace these interfaces
with a stalled response protocol.

Compile and simulate Stage 2 from the repository root with Vivado:

```text
xvlog -sv rtl\common\rv32i_pkg.sv rtl\common\alu.sv rtl\common\regfile.sv rtl\common\imm_gen.sv rtl\core\decoder.sv rtl\memory\reference_memory.sv rtl\core\single_cycle_core.sv tb\single_cycle_tb.sv
xelab -debug typical single_cycle_tb -s single_cycle_sim
xsim single_cycle_sim -runall
```

Stage 3 adds the five explicit combinational stage modules and the registered
pipeline core:

```text
xvlog -sv rtl\common\rv32i_pkg.sv rtl\common\alu.sv rtl\common\regfile.sv rtl\common\imm_gen.sv rtl\core\decoder.sv rtl\core\if_stage.sv rtl\core\id_stage.sv rtl\core\ex_stage.sv rtl\core\mem_stage.sv rtl\core\wb_stage.sv rtl\core\pipeline_core.sv rtl\memory\reference_memory.sv rtl\core\single_cycle_core.sv tb\stage3_pipeline_tb.sv
xelab -debug typical stage3_pipeline_tb -s stage3_pipeline_sim
xsim stage3_pipeline_sim -runall
```

The Stage 3 pipeline uses the same deterministic memory timing as the
single-cycle reference: combinational instruction/data reads and clocked
stores. Its inter-stage register priority is reset, redirect flush, stall,
then normal capture. No memory stall is used in this stage; invalid payloads
produce no register writes or memory requests.

Stage 4 adds `rtl/hazards/forwarding_unit.sv`,
`rtl/hazards/hazard_unit.sv`, and `rtl/core/branch_unit.sv`. Forwarding
priority is EX/MEM before MEM/WB; EX/MEM loads are never forwarded because
their ALU result is only the address. A load-use hazard holds PC and IF/ID
and inserts an invalid ID/EX payload. Branch recovery from EX has priority
over a simultaneous load-use stall and clears the two younger front-end
payloads. Stage 4 counters expose observed load-use stalls and recovery
flushes.

```text
xvlog -sv rtl\common\rv32i_pkg.sv rtl\common\alu.sv rtl\common\regfile.sv rtl\common\imm_gen.sv rtl\core\decoder.sv rtl\core\if_stage.sv rtl\core\id_stage.sv rtl\core\ex_stage.sv rtl\core\mem_stage.sv rtl\core\wb_stage.sv rtl\hazards\forwarding_unit.sv rtl\hazards\hazard_unit.sv rtl\core\branch_unit.sv rtl\core\pipeline_core.sv rtl\core\single_cycle_core.sv rtl\memory\reference_memory.sv tb\stage4_hazard_tb.sv
xelab -debug typical stage4_hazard_tb -s stage4_hazard_sim
xsim stage4_hazard_sim -runall
```

Stage 5 adds `rtl/predictor/bpu.sv`. The predictor is a 64-entry direct-mapped
BTB indexed by PC bits `[7:2]` with PC bits `[31:8]` as the tag, plus a
64-entry two-bit BHT. BHT reset state is weakly not-taken (`01`). Conditional
branches require a BTB hit and predict taken for states `10` and `11`; direct
JAL is predicted from its encoded target; JALR is intentionally not predicted
and is recovered in EX. The fetched prediction is carried in IF/ID and
compared with the resolved next PC in EX. Only a mismatch flushes younger
instructions. The core exposes prediction attempts, correct predictions,
mispredictions, and recovery counters. In this integration,
`predicted_target` means the predicted next PC: the branch target for a taken
prediction or the sequential PC for a not-taken prediction. EX compares it
directly with the resolved next PC.

```text
xvlog -sv rtl\common\rv32i_pkg.sv rtl\common\alu.sv rtl\common\regfile.sv rtl\common\imm_gen.sv rtl\core\decoder.sv rtl\core\if_stage.sv rtl\core\id_stage.sv rtl\core\ex_stage.sv rtl\core\mem_stage.sv rtl\core\wb_stage.sv rtl\hazards\forwarding_unit.sv rtl\hazards\hazard_unit.sv rtl\core\branch_unit.sv rtl\predictor\bpu.sv rtl\core\pipeline_core.sv rtl\core\single_cycle_core.sv rtl\memory\reference_memory.sv tb\stage5_bpu_tb.sv
xelab -debug typical stage5_bpu_tb -s stage5_bpu_sim
xsim stage5_bpu_sim -runall
```

Stage 6 cache components use a stable line transaction protocol. An
instruction or data cache accepts a CPU request only while idle, holds its
miss or write-through request until the arbiter accepts it, and emits exactly
one response pulse after the memory response. Line requests are 16-byte
aligned, 128 bits wide, and use 16 byte-enable bits. The data cache is
write-through and no-write-allocate: write hits update the cached bytes and
send a memory write; write misses bypass allocation. The arbiter gives data
requests priority over instruction requests and latches the selected owner
until completion. The memory controller holds one accepted transaction while
the main memory model applies a configurable response latency. After capturing
a memory response, it emits a one-cycle response pulse and blocks new request
acceptance during that pulse, preventing a stale response from being associated
with the next cache transaction.

The standalone Stage 6 regression is compiled with:

```text
xvlog -sv rtl\common\rv32i_pkg.sv rtl\cache\icache.sv rtl\cache\dcache.sv rtl\cache\cache_arbiter.sv rtl\memory\memory_controller.sv rtl\memory\main_memory_model.sv tb\stage6_cache_tb.sv
xelab -debug typical stage6_cache_tb -s stage6_cache_sim
xsim stage6_cache_sim -runall
```

Stage 7 uses Icarus Verilog for reproducible simulation and optionally
Verilator for linting when installed. No FPGA part, placement, routing,
bitstream, or FPGA timing result is required. `scripts/run_regression.tcl`
collects simulator logs under `results/`; `scripts/evaluate_performance.py`
converts measured cycle, retirement, CPI/IPC, cache, and transaction counters
to JSON, CSV, and Markdown. `scripts/synth_timing.tcl` only attempts
technology-independent Yosys synthesis when Yosys is available and otherwise
records that synthesis is unavailable.
