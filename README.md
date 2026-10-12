# 5-Stage Pipelined RV32I Processor

A 32-bit RISC-V processor core implemented in **SystemVerilog**, featuring a classic five-stage pipeline, data forwarding, load-use hazard detection, pipeline stalling, and branch flushing. The design is simulated using **Icarus Verilog** and verified with a custom SystemVerilog testbench.

The project demonstrates fundamental RTL design and computer architecture concepts, including instruction execution, pipeline control, memory operations, and hazard resolution.

## Overview

| Property | Details |
|---|---|
| Architecture | RISC-V, 32-bit |
| Instruction set | RV32I subset implemented by the design |
| Pipeline | 5 stages |
| HDL | SystemVerilog |
| Simulation | Icarus Verilog (`iverilog` / `vvp`) |
| Additional tool | Verilator (optional) |
| Memory initialization | `$readmemh` |
| Verification | SystemVerilog testbench with automated checks |

## Key Features

- **Five-stage pipelining** — instruction fetch, decode, execute, memory access, and writeback.
- **Data forwarding** — resolves supported read-after-write (RAW) dependencies without unnecessary stalls.
- **Load-use hazard detection** — inserts a bubble when a dependent instruction requires data that is not yet available.
- **Pipeline control** — stalls the PC and IF/ID pipeline register when required.
- **Branch handling** — flushes younger instructions when a branch is taken.
- **Register file** — 32-bit registers with two source operands and a destination register.
- **Instruction memory** — loads machine-code instructions from `program.hex`.
- **Data memory** — supports the implemented load and store operations.
- **Automated verification** — checks the combined execution sequence, including forwarding, memory operations, load-use handling, and branch behavior.

## Architecture

### Five-stage pipeline

```text
       ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
       │    IF    │───▶│    ID    │───▶│    EX    │───▶│   MEM    │───▶│    WB    │
       └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
             │               │               │               │               │
             ▼               ▼               ▼               ▼               ▼
       Instruction      Decode and        ALU and          Data          Register
          fetch         register read    branch logic     memory         writeback

                     ┌──────────────────────────────┐
                     │       Hazard Control         │
                     │ Forwarding · Stall · Flush   │
                     └──────────────────────────────┘
```

### Pipeline stages

| Stage | Name | Responsibility |
|---|---|---|
| IF | Instruction Fetch | Fetches instructions and advances or redirects the program counter. |
| ID | Instruction Decode | Decodes instructions, reads source registers, and prepares control signals. |
| EX | Execute | Performs ALU operations, evaluates branch conditions, and calculates addresses. |
| MEM | Memory Access | Performs the implemented data-memory reads and writes. |
| WB | Writeback | Writes the selected result back to the register file. |

Pipeline registers carry instruction data and control signals between successive stages, allowing multiple instructions to be in flight simultaneously.

## Hazard Detection and Resolution

Instruction dependencies and control-flow changes require careful handling in a pipelined processor. This design implements forwarding, stalling, and flushing to manage the tested hazards.

### 1. Data forwarding

A read-after-write (RAW) hazard occurs when an instruction needs a result produced by an earlier instruction that has not yet been written back to the register file.

The forwarding logic selects an available result from a later pipeline stage and supplies it directly to the execute-stage operand path.

**Example:**

```asm
ADDI x1, x0, 5
ADDI x2, x0, 10
ADD  x3, x1, x2
ADD  x4, x2, x3
```

Expected register values:

```text
x1 = 5
x2 = 10
x3 = 15
x4 = 25
```

The dependent arithmetic operations produce the expected results in the simulation.

### 2. Load-use hazard

A load-use hazard occurs when an instruction immediately depends on data being loaded from memory.

The hazard detection logic holds the program counter and IF/ID register for one cycle and inserts a bubble into the execute-stage path, allowing the loaded value to become available before the dependent operation proceeds.

**Example:**

```asm
SW   x4, 0(x0)
LW   x5, 0(x0)
ADD  x6, x5, x1
ADDI x7, x6, 2
```

Expected results:

```text
Memory[0] = 25
x5        = 25
x6        = 30
x7        = 32
```

The simulation trace shows the PC holding at `0x0000001c` during cycle 8, followed by the dependent computation completing with `x6 = 30`.

### 3. Control hazard and branch flushing

A taken branch changes the instruction-fetch path. Instructions fetched along the wrong path must be prevented from updating architectural state.

The processor flushes younger pipeline instructions when the branch is taken, allowing execution to continue from the branch target.

**Example:**

```asm
BEQ  x1, x1, 12
ADDI x8, x0, 99
ADDI x8, x0, 88
ADDI x9, x0, 42
```

The branch is taken because both operands refer to `x1`. The intended wrong-path instructions must not commit their results, and the target instruction produces:

```text
x9 = 42
```

The supplied testbench reports that the combined branch-flush test passes.

## Project Structure

```text
risc_v_5stage_pipeline/
├── rtl/
│   ├── riscv_top.sv         # Top-level processor
│   ├── instruction_mem.sv   # Instruction memory
│   ├── reg_file.sv          # Register file
│   ├── alu.sv               # Arithmetic logic unit
│   ├── control_unit.sv      # Instruction control and branch logic
│   ├── hazard_unit.sv       # Forwarding, stall, and flush control
│   ├── imm.sv               # Immediate generator
│   └── data_mem.sv          # Data memory
├── tb/
│   └── riscv_top_tb.sv      # Processor testbench
├── program.hex              # Machine-code test program
└── README.md
```

## Getting Started

### Prerequisites

Install the following tools:

- **Icarus Verilog** — SystemVerilog compilation and simulation.
- **VVP** — executes the compiled simulation.
- **Verilator** — optional additional linting and RTL analysis.

The commands below assume you are running them from the repository root and have the directory structure shown above.

### Compile the design

```bash
iverilog -g2012 -o riscv_sim rtl/*.sv tb/riscv_top_tb.sv
```

The `-g2012` flag enables Icarus Verilog's SystemVerilog 2012 language mode.

### Run the simulation

```bash
vvp riscv_sim
```

The testbench prints cycle-by-cycle execution information, including the program counter, decoded instruction, and selected register values. It then runs the combined verification checks.

### Clean generated output

```bash
rm -f riscv_sim
```

This cleanup command is suitable for Linux, macOS, and compatible Unix shells.

## Verification Results

The processor was simulated using the provided `program.hex` and `riscv_top_tb.sv` testbench.

### Test summary

| Verification scenario | Expected result | Observed result |
|---|---|---|
| ALU data forwarding | `x3 = 15` | `x3 = 15` |
| Chained data dependency | `x4 = 25` | `x4 = 25` |
| Store and load | `x5 = 25` | `x5 = 25` |
| Load-use dependency | `x6 = 30` | `x6 = 30` |
| Dependent arithmetic | `x7 = 32` | Consistent with the supplied program's intended result; not printed in the trace |
| Taken branch | Reach target instruction | Target result observed |
| Branch target execution | `x9 = 42` | `x9 = 42` |

### Simulation evidence

The following excerpt is taken from the supplied simulation log:

```text
[Cycle  7] IF_PC:0x0000001c | ID_Inst:0x00128333 | x1:5 x2:10 x3:15 x4:0  x5:0  x6:0  x9:0
[Cycle  8] IF_PC:0x0000001c | ID_Inst:0x00128333 | x1:5 x2:10 x3:15 x4:25 x5:0  x6:0  x9:0
[Cycle  9] IF_PC:0x00000020 | ID_Inst:0x00230393 | x1:5 x2:10 x3:15 x4:25 x5:0  x6:0  x9:0
[Cycle 10] IF_PC:0x00000024 | ID_Inst:0x00000013 | x1:5 x2:10 x3:15 x4:25 x5:25 x6:0  x9:0
[Cycle 18] IF_PC:0x00000044 | ID_Inst:0xxxxxxxxx | x1:5 x2:10 x3:15 x4:25 x5:25 x6:30 x9:42
```

The complete supplied run ends with:

```text
=======================================================================
                   VERIFYING COMBINED CPU TEST STATE
=======================================================================
[SUCCESS] All Combined Forwarding, Load-Use Stall, Memory, and Branch Flush tests PASSED!
=======================================================================
tb/riscv_top_tb.sv:87: $finish called at 256000 (1ps)
```

**Verification status:** The provided testbench reports success for its combined forwarding, load-use stall, memory, and branch-flush checks. This is simulation-based verification of the supplied test sequence, not a claim of exhaustive RV32I compliance or physical hardware validation.

*Note:* The `0xxxxxxxxx` instruction values later in the trace indicate unknown instruction-memory data beyond the initialized program. They are not valid instructions and should not be interpreted as meaningful execution results.

## Future Improvements

Potential extensions to this project include:

- Expand instruction coverage and add directed tests for additional RV32I operations.
- Add randomized instruction testing and broader reference-model comparisons.
- Generate waveform traces for pipeline registers, forwarding selections, stalls, and flush signals.
- Add synthesis and FPGA implementation support.
- Evaluate timing, resource utilization, and maximum operating frequency after synthesis.

These are possible next steps, not features claimed to be implemented in the current design.

## Skills Demonstrated

- SystemVerilog RTL design
- RISC-V instruction execution and processor microarchitecture
- Five-stage pipelining
- Data forwarding and RAW hazard resolution
- Pipeline stalls and control hazard flushing
- Register files, ALUs, and memory interfaces
- Testbench development and simulation-based verification
- Icarus Verilog compilation and debugging

## Author

**Raviteja P.**  
Electronics & Communication Engineering

---

*This project is intended for educational and portfolio purposes, demonstrating practical understanding of pipelined processor design and RTL verification.*
