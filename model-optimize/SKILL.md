---
name: model-optimize
description: Design or optimize Buckyball model recipes for target chips, specializing quantization, offline layouts, bank reuse, operator mapping, and scheduling. Use during model-port's design step or for an existing model design.
---

# Model Optimization

Own the chip-specific model design. Reuse the shared framework and specialize the
recipe to the backend. Change the framework when a concrete design exposes a
reusable correctness or performance gap. Read the target's active bank geometry,
ISA, execution conventions, and existing recipes before selecting the design.

Declare numerical requirements and the design/performance objective. During a port,
perform the design step required by [model-port](../model-port/SKILL.md); do not infer
an extra speed target or hardware expansion. For a measured bottleneck, use
[debug-performance](../debug-performance/SKILL.md) to obtain the evidence and baseline.

## Design exploration

Start with the agreed workload, numerical contract, latency/throughput goals,
and resource constraints. Include the relevant input lengths, concurrency, and
execution phases; one short request does not establish a general design optimum.

Work from workload and operator/dataflow requirements through subgraph partitioning,
Core/Ball resources, tile composition, and chip/interconnect placement. Revisit an
earlier layer when later evidence changes its assumptions. Compare a small set of
explained candidates rather than changing several layers at once.

At each layer, establish the baseline, state the hypothesis, identify the evidence
needed to distinguish candidates, and agree on the design choice with the user.
Continue gathering evidence while a choice is open. Do not treat initial core ratios,
tile counts, or equal task submission counts as proof of balanced useful work.

Design exploration is a human-agent workflow. Bring evidence, alternatives, costs,
and uncertainties to the user; use their domain experience and constraints to choose
the next experiment. Authorization to investigate is not agreement to a design.
Before changing architecture, subgraph partitioning, resource counts, interfaces, or
repository organization, establish the intended change and scope together. Silence
does not settle an open design choice.

Within an agreed experiment, continue routine inspection, measurements, builds,
verification, and fixes without repeatedly requesting confirmation. Return to the
discussion when evidence changes the premise or the experiment needs broader scope.
Keep unrelated local modifications intact and avoid speculative restructuring.

Inspect actual lowered subgraphs, submission/wait boundaries, physical padding,
bank lifetimes, and transfer counts. Available cores and SRAM only help when the
compiled dataflow can use them. Preserve reduction order when bitwise comparison
is required, even if independent tasks are rescheduled.

Distinguish active worker execution from waiting before diagnosing emulator overhead.
Resolve sampled guest PCs to the compiled functions: activation quantization, tensor
packing, copies, and parameter initialization can dominate even when Ball execution
is fast. Check whether newly allocated parameter storage is zeroed immediately before
a complete file read overwrites it.

Preserve transpose and broadcast views until their consumers choose a bank layout.
For grouped-query attention, group query rows by KV head before QK and PV rather
than materializing one KV copy per query head. Validate row order, softmax axes,
cache updates, and accumulation order independently.

Compare worker-count candidates on identical submitted work and report private SRAM
alongside latency. A serial fused subgraph does not use additional workers merely
because successive calls rotate between them. Keep measured simulator gains separate
from projected FPGA or chip gains.

Inspect the final temporary tensor sizes as well as the Python operation. A dilated
window may materialize every intermediate position before selecting its taps.
Fuse a static slice into a pure producer when the index mapping proves equivalence.
For copies, coalesce a common contiguous suffix before copying element by element.
Validate offsets, noncontiguous layouts, empty dimensions, and the final model output.

Check direct subgraph calls against the IR produced by a fresh normal capture.
Deduplication can change the argument list even when a cropped prior artifact passes
numerical tests. Match the runtime task protocol, simulator, program, configuration,
and weights before timing a candidate. Reject an ABI mismatch rather than interpreting
its early exit as a numerical or scheduling failure.

Preserve raw output precision in difftest artifacts. A matching PCM16 waveform does
not establish bitwise equality of the underlying FP32 samples. Save the actual decoder
inputs so a prior program can replay them without repeating unrelated model stages.

For temporal convolution partitions, derive the halo from every dependency in the
subgraph. Select owned output rows before the expensive operation rather than computing
the halo outputs and discarding them. Check that quantization groups and accumulation
order remain local to each output row. Validate boundary and tail spans with actual
weights, then compare assembled raw outputs against the prior complete subgraph.
Submit independent spans from the controller to local worker entry points, avoiding
nested dispatch. Keep one workspace alive until all jobs finish and give each job an
independent input view or copy before assembling results.

Keep source-derived operation/byte counts, analytical estimates, BEMU host time,
RTL cycles, and FPGA measurements distinct. Virtual clock settings and retired
instruction rates do not establish equivalent chip throughput. A functional bank
model can compute final results directly while a separate calibrated model estimates
target timing.

Before comparing scheduling candidates by BEMU host time, repeat identical work
across equivalent cores. Investigate schedule-dependent emulator overhead, including
shared clocks and locks, before attributing a timing difference to the chip design.

Add a counter or analysis tool when a concrete question lacks observable evidence.
Define its measured event, unit, scope, and overhead; reuse that tool across designs.
Avoid collecting large traces when compact counters answer the question.
Discuss the need, output contract, repository location, and maintenance cost before
introducing a new maintained tool or abstraction.

Retain experiment records with the design: workload/configuration and source or
artifact identity; baseline and candidate difference; hypothesis and acceptance
criteria; command/tool versions and raw evidence paths; numerical and performance
results; decision, limitations, and unresolved questions. Include failed candidates.
Temporary unmaintained test sources may be removed after validation; retain the
inputs, outputs, logs, and invocation needed to assess the result.

Promote confirmed reusable methods into this skill. Keep model/chip-specific choices
with the design and mark untested proposals as hypotheses. Update lessons from actual
experiments without turning an isolated example into a universal rule.

## Layout and numerical contract

Keep preparation, packaging, and evaluation shared where their contracts match.
Put chip weight permutation, physical padding, and layout choices in `permute/`.
Before adding a high-rank activation transpose, establish whether it is necessary;
align producer/consumer layouts and permute weights offline when that removes it.

Preserve known strides and dynamic offsets into packed payloads so lowering can
select direct DMA without reading the wrong weights. Check whether reduction/output
tails force runtime repacking. Physical padding and logical output trimming must
preserve the original result, and calibration must see physical channels before
trimming. Specify quantization, rounding, accumulation precision, and bias/scale
boundaries; validate rewrites separately from quantized accelerator execution.

## Bank reuse and scheduling

Buckyball hides latency with **long in-flight operations**. Once a bank is acquired,
use as many meaningful rows as the operation and layout permit, and reuse its data.
Batch contiguous work, amortize DMA/configuration, and keep independent operations
in flight. Avoid frequent exchanges of a few rows between producer and consumer Balls.

Budget input, weight, accumulator, and temporary banks together. Use active compute
bank dimensions, not unrelated MMIO capacity. SRAM depth and ISA address fields are
separate constraints: DMA-loaded storage may permit a larger tile than recursively
assembled scratch storage. Choose legal tiles and offsets without truncation.

Split unfolding/reduction dimensions and accumulate partial products when necessary.
Fusion must reuse work; inspect recursive producer recomputation and choose
materialization boundaries from the bank budget and measured cost. Declare runtime
features the recipe actually uses instead of requiring unused kernels whose footprint
excludes a supported configuration.

Keep capacity unchanged unless a hardware change is authorized. When adding a larger
configuration, preserve and independently validate required smaller configurations.
Use distinct configuration/build identities as needed and share implementations where
semantics match. More capacity does not guarantee fewer cycles; select defaults from
measured results and the user's constraints.

## Validate the design

Use independent small cases and affected existing consumers for numerical, packing,
tail, addressability, and scheduling changes. Follow `$debug-compiler`, `$debug-bemu`,
`$debug-verilator`, or `$debug-p2e` at the failing layer. Follow `$ball-align` when the
operator contract changes across layers.

Return the chosen design, numerical evidence, measured gains/tradeoffs, and regression
coverage to the porting workflow. Hardware performance claims require correct full-model P2E
execution and the declared FPGA cycle target, as specified by `$debug-performance`.
