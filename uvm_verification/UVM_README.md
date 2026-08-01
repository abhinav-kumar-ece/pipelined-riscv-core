# Pipelined RISC-V (RV32I) Core

A 5-stage pipelined RV32I RISC-V CPU implemented in Verilog, verified through simulation
in Xilinx Vivado, with synthesis and post-implementation timing analysis on a Xilinx
Spartan-7 (xc7s50csga324-1) target. No FPGA board required — fully verified in simulation
and via Vivado's synthesis/implementation flow.

## Project structure

This repo contains two CPU implementations built incrementally:

1. **Single-cycle core** (`riscv_singlecycle.v`) — a complete RV32I datapath executing
   one instruction per clock cycle.
2. **Pipelined core** (`riscv_pipelined_hazards.v`) — a 5-stage pipeline (IF/ID/EX/MEM/WB)
   with full hazard handling:
   - **Data forwarding** (EX/MEM and MEM/WB bypass paths)
   - **Load-use hazard detection** (pipeline stall + bubble insertion)
   - **Control hazard handling** (branch/jump flush of speculatively fetched instructions)

Shared submodules: `alu.v`, `regfile.v`, `control_unit.v`, `imm_gen.v`, `imem.v`, `dmem.v`.

## Verification

Every module was unit-tested in isolation before integration:

| Module | Tests |
|---|---|
| `alu.v` | 12/12 passing |
| `regfile.v` | 4/4 passing |
| `imem.v` | 4/4 passing |
| `dmem.v` | 5/5 passing |
| `control_unit.v` | 14/14 passing (includes full RV32I branch set) |
| `imm_gen.v` | 6/6 passing |

The pipelined core was verified with dedicated integration tests covering:
- A hazard-free program (skeleton pipeline, no forwarding)
- A back-to-back hazard program exercising EX/MEM forwarding, MEM/WB forwarding, and
  load-use stalling all in a single run — all correct on first attempt
- A dedicated branch-flush test (taken branch squashing two speculatively-fetched
  "trap" instructions)

## Results

### CPI (Cycles Per Instruction)

Two benchmark programs were run on both cores using dedicated cycle-counting testbenches.

**Benchmark 1 — branch-heavy loop** (sum 1 to 10, backward branch, 33 dynamic instructions):

| Core | Cycles | CPI | Stalls | Flushes |
|---|---|---|---|---|
| Single-cycle | 31 | ~0.94 | n/a | n/a |
| Pipelined | 99 | ~3.0 | 0 | 10 |

**Benchmark 2 — branch-free dependency chain** (20x `addi x1,x1,1`, every instruction
depends on the previous one, 20 dynamic instructions):

| Core | Cycles | CPI | Stalls | Flushes |
|---|---|---|---|---|
| Single-cycle | 19 | ~0.95 | n/a | n/a |
| Pipelined | 24 | 1.2 | 0 | 0 |

**Interpretation:** CPI alone never favors pipelining — single-cycle CPI is always ~1.0
by construction, and pipelined CPI is always ≥1.0 due to fill overhead and hazard cost.
Benchmark 2 shows near-ideal pipeline behavior (just the 4-cycle fill overhead, zero
stalls/flushes despite maximal data dependency — strong evidence forwarding logic is
correct). Benchmark 1 shows the real cost of this design's branch resolution policy
(resolved in EX, no prediction): every taken branch costs a fixed 2-cycle flush penalty.

### Synthesis & Timing (Xilinx xc7s50csga324-1, 10 ns / 100 MHz constraint)

**Synthesis-level utilization:**

| Metric | Single-cycle | Pipelined |
|---|---|---|
| Slice LUTs | 35 | 160 |
| Slice Registers | 30 | 165 |
| CARRY4 | 16 | 16 |

**Post-implementation (place & route) timing:**

| Metric | Single-cycle | Pipelined |
|---|---|---|
| WNS | 4.835 ns | 4.840 ns |
| Critical path delay | 5.165 ns | 5.160 ns |
| **Fmax** | **~193.6 MHz** | **~193.8 MHz** |

**Key finding:** at the synthesis level, the pipelined core showed a modest Fmax
advantage (~216 MHz vs ~208 MHz) from shorter per-stage logic depth. After full
place-and-route, that advantage effectively disappeared — both cores converge to
~193.6-193.8 MHz. This suggests that at this design's scale, physical routing overhead
dominates over logic-depth reduction, and synthesis-only timing estimates can be
misleading for small designs. The pipeline's real, consistent cost is hardware: ~4.6x
more LUTs and ~5.5x more registers for the same ISA functionality.

## Tools

- Xilinx Vivado 2024.2
- Target device: xc7s50csga324-1 (Spartan-7)
- All verification done via behavioral simulation (XSIM); no physical FPGA board used

## Status

Core RTL design, verification, and synthesis/timing analysis are complete. A written
report/paper discussing methodology and results in full is in progress.
