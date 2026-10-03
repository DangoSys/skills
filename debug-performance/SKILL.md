---
name: debug-performance
description: Analyze and optimize Buckyball model performance using FPGA end-to-end cycles, layer timing, operation lengths, bank reuse, and measured bottlenecks.
---

# Performance Debugging

Establish the requested performance metric first. Model performance normally means
**FPGA-measured end-to-end forward cycles**, including CPU work, accelerator work,
and data movement. Host simulation duration, boot time, compilation time, and BEMU
cycles do not establish this result. Keep the same checkpoint, input, inference
boundary, chip configuration, and tracing mode when comparing designs.

Report FPGA cycles by default for a model optimization. If the user asks how long
a P2E run takes, report host wall-clock duration separately: model RUN-to-PASS,
setup/Linux boot, and total command duration. Keep bitstream synthesis/PNR separate.
Use the current run's timing log; do not turn one observed duration into a fixed
estimate, or infer that diff improves performance from a faster wall-clock run.

Read the actual FPGA UART log and its `Cycle count`, rather than combined host
stdout. A diff run can print golden-emulator cycle records too; those are not FPGA
measurements. Do not combine overlapping trace scopes or sum a diff session with
the workload duration. Validate with diff first; use a matching performance run
without diff when isolating instrumentation overhead. Report actual cycles and
the baseline-relative change, with bitstream/image identities and correctness.

## Locate the bottleneck

1. Enable model cycle tracing through the recipe and inspect per-layer or fused
   region intervals in actual FPGA UART. Map trace IDs to the generated graph.
   If a region dominates, subdivide it or inspect available Ball/memory counters.
2. Separate CPU packing, quantization, and copies from DMA, unfolding, compute,
   and dependency stalls. BEMU helps expose CPU work and excessive lowering; use
   RTL/P2E evidence for accelerator timing and utilization.
3. Decode instructions with the selected chip's generated ISA. `funct7` meanings
   are chip-local. Bank trace events are writes, not a timing percentage or
   necessarily one event per instruction. Map PCs to graph regions before drawing
   conclusions from counts.
4. Inspect effective rows and useful work per operation, SRAM traffic and reuse,
   number of outstanding operations, and producer/consumer dependencies. Explain
   why the measured region is slow instead of stopping at “model execution”.

## Apply and validate an optimization

Use [model-optimize](../model-optimize/SKILL.md) for layout, bank-budget, reuse,
operator mapping, and scheduling decisions. Bring the measured hotspot and baseline
into that design step, then remeasure the changed region and end-to-end FPGA cycles.
Keep numerical and regression gates intact; do not infer a gain from bank capacity
or instruction counts alone.

Follow `$debug-compiler` for lowering defects, `$debug-bemu` for numerical defects,
and `$debug-verilator`/`$debug-p2e` for hardware failures. Use small independent
reference cases and affected existing models. A performance optimization is complete
only after correct full-model P2E execution satisfies the FPGA cycle target.
