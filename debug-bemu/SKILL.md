---
name: debug-bemu
description: Diagnose Buckyball BEMU failures or numerical mismatches against C, PyTorch, or another declared reference. Use for emulator semantics and compiled-model execution, not RTL timing.
---

# BEMU Debugging

Confirm the exact chip, executable/model artifact, input, and reference. Read the
active ISA/configuration and reproduce the first failure through project tools.
Build success, process startup, and a running CPU are not correctness results.

For a model mismatch, compare the earliest available tensor/operator boundary:
preprocessing, offline weights, activation/weight quantization, bias, accumulation,
pooling, flattening, and outputs. Check shape, stride, packing, tail zero fill,
signedness, overflow, and rounding. Use `$debug-compiler` when the imported graph
or lowering is already wrong.

For Linux DMA page faults, identify the buffer and failing page before changing
the emulator. Untouched calloc padding or a DMA-only destination can lack backing
pages. Check page residency and access permissions in the model/runtime; do not
silently map a faulting DMA address or alter tensor data to conceal the defect.

For CPU external-input optimizations, prove when each input can affect architectural
state. Disabled local IRQ enables do not make pending CSR reads unobservable, and
disabled global IRQ enables do not eliminate WFI wake conditions. Compare fixed
input snapshots against the optimized provider at each step, including CSR reads,
IRQ priority/delegation, timer MMIO, cycle inhibition, and WFI boundaries.

For an operator mismatch, use an independent small C reference and inspect
itrace/mtrace around its command and bank reads/writes. Pin the documented
contract before changing the emulator. Follow `$ball-align`: C+BEMU must be green
before compiler/MLIR changes are accepted, and MLIR+BEMU before RTL changes.

For a slow run, check progress in instruction/operation completions and map the
current PC to the actual executable. Distinguish repeated computation or costly
fusion from a stopped command. Do not claim a layer/percentage from elapsed time.

Re-run the failing case after a targeted fix and cover affected existing consumers.
Full models and large bank cases belong on BEMU or P2E, not full-model Verilator.
Label BEMU cycle counts as BEMU evidence; they are not RTL/P2E timing or PPA.
An accelerator instruction's functional execution cost is not its hardware latency.
Use BEMU to localize semantic differences and excessive CPU/lowering work, then
confirm a hardware performance hypothesis with `$debug-performance` on RTL/P2E.

Explicit model-only `--reuse-simulator` can run a previously built matching
simulator during model iteration. Check its chip geometry and instruction semantics;
rebuild when either changes. A cached simulator must not hide a semantic regression.

Prefer project `bbdev_*` MCP tools and poll terminal results. If the user authorizes
fallback for a broken MCP entry, use `nix develop -c bbdev` and retain logs/exit codes.
