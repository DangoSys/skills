---
name: ball-align
description: Align a Buckyball Ball's C tests, BEMU behavior, compiler lowering, MLIR tests, RTL, and UVM to one explicit contract. Use when a Ball semantic change spans layers, BEMU and RTL disagree, ISA fields are renamed, or tests must be synchronized after a contract change.
---

# Ball Alignment

Treat the documented C test semantics as the functional reference. Build top-down
through a strict, stage-gated pipeline. **A stage is a gate: the next stage may
not start until the current one is green.** Fix only the red stage and everything
above it — never reach ahead.

## Pipeline (strict order)

```
Stage 0  Contract (no code)
Stage 1  C test -> BEMU golden model     GATE: ctest green on BEMU
Stage 2  Compiler + MLIR test            GATE: mlirtest green on BEMU
Stage 3  RTL                             GATE: Verilator small tests green
Stage 4  PPA + UVM verification
```

> 前一个环节没完成，下一个环节不能走 — a red stage blocks every later stage.
> Stage 1 red → do not write the compiler or RTL. Stage 2 red → do not touch RTL.
> Stage 3 red → do not run PPA or UVM.

## Stage 0 — Contract first (before any code)

Write down and confirm with the user; stop if any item is missing:

1. ISA fields and their source of truth.
2. Element width, address calculation, and per-iteration read/write footprint.
3. Valid inputs, invalid inputs, and the required failure behavior.
4. Output layout, including packing and zero-fill.
5. Every affected consumer: ISA macro, emulator, compiler lowering, MLIR test, C test, RTL, UVM, and regression list.

Hard rules:

- **Register new Balls in the `toy` core only.** `toy` is the maintenance core
  for new and experimental Balls; production cores (`pebble`, `goban`, `prefill`,
  `decode`, `rocket`) have fixed, meaningful Ball sets and must not gain new Balls.
- No field with multiple meanings; no compatibility fallback that hides an invalid input.
- Address and capacity from the active configuration and bank row width; do not
  raise limits before small tests are green.
- Use `$check` to validate registration before and after registration work.

## Stage 1 — C test + BEMU golden model

Write the **C test first**: it pins the golden semantics every later layer must
match. Then write the **BEMU model** bit-for-bit against that C reference. Both
share the same legal/illegal checks and fail hard (panic/assert) — no soft defaults.

- Small tests: short shapes, hand vectors, edge and illegal inputs.
- Bank tests: `iter≈BANK_LINES`, `srand`/`rand`; soft numeric may report LOSS — **BEMU only**.

**Gate:** the C test must pass on BEMU (`bbdev_bemu_sim` / `bbdev_bemu_batch`).
Do not write the compiler or RTL before this passes.

## Stage 2 — Compiler + MLIR test (on BEMU)

After Stage 1 is green:

- Keep the `bank` Op and the lowered `ball` Op separate (see transpose).
- Lower in order: bank Op → assign-physical-banks → ball Op → instruction. Keep
  lit files per layer; do not mix them.
- MLIR tests live under `examples/balls/<ball>/workloads/mlir_tests/` (not under
  the chip); FileCheck plus an mlirtest ELF.
- New ctest / mlirtest → add to the chip BEMU `workloads-elf.toml` + `workloads-pk.toml`.

**Gate:** the MLIR test must pass on **BEMU** (run the mlirtest ELF). Do not
touch RTL before this passes.

## Stage 3 — RTL

After Stage 2 is green:

- Capture command fields on `cmdReq.fire`.
- Respect one-cycle SRAM read latency from request handshake to response.
- Keep `status.idle` / `status.running` consistent with the state machine.
- Use explicit Chisel widths; block in-place same-bank writes that overwrite unread source data.
- Verilator lists take **small tests only**, not bank tests.

**Gate:** Verilator **small tests** green (`bbdev_bebop_verilator_sim`, or
non-bebop `bbdev_verilator_sim`). BEMU green + Verilator red → RTL/timing; use
`$waveform` / `$debug`. Full Verilator builds often MCP-timeout: check whether
the server is still compiling and call `*_sim` directly once the binary/marker is ready.

## Stage 4 — PPA + UVM verification

After Stage 3 is green:

- Sync integration tests (real consumers; update on contract changes).
- UVM: stimulus/scoreboard on the same contract — only after RTL small tests are green.
- PPA: area/power/timing from the regression/eval flow; PMC from `bdb.ndjson` /
  `bdb.log` `pmctrace` (`elapsed`).

## Delivery

Report the contract, changed layers, per-stage evidence, and remaining unsupported
coverage. Build and simulation use the project `bbdev_*` MCP tools only; poll
submitted tasks to terminal success.
