---
name: verify
description: Verify functional correctness of a Buckyball Ball. Use when users ask to test a Ball, validate a completed Ball change, compare BEMU and RTL behavior, or collect Ball performance evidence. Use project MCP tools for builds and simulation.
---

# Ball Verification

Use this skill to verify existing work. Report missing implementation, registration, ISA, workload, or UVM artifacts; do not create them unless the user asks for implementation.

## Preconditions

1. Run `validate(chip=..., balldomain?=...)` through MCP.
2. Confirm the Ball implementation under `examples/balls/<ball>/arch/src/main/scala/`, its selected core registration under `examples/cores/<core>/configs/balldomains/`, and the relevant workload/ISA files exist.
3. Identify the exact workload binary and target chip. The chip's Verilator configuration is selected by `examples/chips/<chip>/configs/chip.toml`; it is not a parameter to `bbdev_bebop_verilator_run`.

## Verification Order

1. Submit `bbdev_workload_build(chip=...)`; poll `bbdev_task_status(trace_id)` until `success=true` and `returncode=0`.
2. Submit `bbdev_bemu_sim(chip=..., binary=...)` for the focused test and poll it to completion.
3. Submit `bbdev_bebop_verilator_run(chip=..., binary=...)` for the corresponding RTL test and poll it to completion. If the generated simulator already exists, `bbdev_bebop_verilator_sim(chip=..., binary=...)` is appropriate.
4. When the Ball has UVM coverage and RTL is green, run `bbdev_uvm_run(chip=..., ball=...)` and poll it to completion.

When BEMU passes and RTL fails, inspect the RTL timing and handshake behavior using `$waveform`; do not assume a missing debug skill.

## Performance Evidence

Request `pmctrace=true` on the chosen Verilator simulation when needed, locate its log directory (normally containing `bdb.ndjson`), and extract `[PMCTRACE] BALL` records. Report invocation count and min, max, and mean `elapsed` cycles. Do not compare unrelated workloads or configurations.

## Failure Handling

Keep the first actionable failure and its stage. Re-run only after a targeted fix, then repeat the previously failing case and the focused regression. Build, simulation, and test operations must use project `bbdev_*` MCP tools; do not call `bbdev` CLI or `nix develop -c bbdev` directly.
