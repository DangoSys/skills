---
name: workload-tests
description: Design, add, reorganize, or review Buckyball Ball, core, and chip workload tests and their regression manifests.
---

# Workload Tests

Use this skill for tests under `examples/*/workloads`, `bb-tests/workloads`,
and chip regression manifests. Keep the test's layer, scale, backend, and name
explicit.

## Test layers

| Layer | Purpose | Scale | Primary backend |
|---|---|---|---|
| CTest | One Ball instruction or a small direct consumer | About 32x16 | Verilator and BEMU |
| BallOp MLIR | One Ball dialect operation and its lowering | Small | Verilator and BEMU |
| BankOp MLIR | Bank SSA allocation, mapping, and at least one bank's worth of meaningful work | Active bank geometry | BEMU |
| Core | Integration of the Balls belonging to one core | Small, realistic composition | BEMU and Verilator where supported |
| Chip | Cross-core, memory-domain, or multi-Ball integration | Small, realistic composition | BEMU; Verilator where supported |

Do not call a test `full_bank` merely because it is a BankOp. Name the operation,
layout, data pattern, or boundary it proves, for example
`im2col_k3_windows` or `toint8_i32_pack16`.

## Source and coverage rules

- One focused test per source file. No multiple `main`s, multiple `RUN` cases,
  or case-switching test files.
- A test source, including generated MLIR input, must not exceed 100 lines.
  Split by behavior instead of moving test logic into a large shared helper.
- Preserve distinct coverage when reorganizing. Do not delete an old test until
  a registered replacement covers the same behavior at the correct layer.
  Kernel-size, padding, layout, tail, accumulation, and sequencing variants
  are distinct coverage unless proven otherwise.
- Keep CTest and BallOp inputs small and hand-checkable. BankOp tests must
  exercise real computation over at least one configured bank, not a
  unit-scale, identity-table, or no-op data path dressed up as a bank test.
- Do not add standalone "contract tests." If a Ball cannot operate at the
  active geometry, make its CMake configuration fail with the Ball name,
  required geometry, and actual generated values.

## Parameters and configuration

- Geometry and topology come from the active chip's `chip.pb` and generated
  headers (`params.h`, `topology.h`), never from fixed bank depths, widths,
  core counts, or shared-bank bases in a test.
- Derive row/lanes/counts from generated parameters where the Ball ISA does not
  fix them. ISA-fixed dimensions such as a 16x16 array may remain explicit.
- A test must continue to mean the same thing after valid chip parameter
  changes. Reject unsupported geometries at configuration time; do not clamp,
  silently shrink, or provide a fallback.

## Multicore chip tests

- Build one workload ELF. It dispatches with `bb_get_core_id()`; the framework
  does not know role names or choose a leader after boot.
- `bb_get_core_id()` returns `{tile, core}`. Tiles are homogeneous; core-level
  paths may differ within a tile.
- Put heterogeneous paths in separate C files in one workload directory. The
  `*-main.cpp` file only owns shared state and dispatches by `{tile, core}`.
- Use the shared bare-metal/Linux multicore runtime. Core 0 performs the
  existing level-one boot and reports completion; do not recreate a parallel
  boot protocol in individual tests.

## Registration and regression

- Workload names always begin with `<chip>-<core>-`. The two naming entry
  points are `buckyball_ctest_name(core, test_id)`, which produces
  `<chip>-<core>-ctest-<test_id>`, and
  `buckyball_mlirtest_name(core, test_id)`, which produces
  `<chip>-<core>-mlirtest-<test_id>`. Each test owns its `test_id`.
  For example, CTest IDs may be `mvin_2d`, `core-conv_pipeline`, or
  `chip-shared_transpose`; MLIR IDs may be `ball_transpose_i8` or
  `bank_quant_i32_pack16`. Do not add local name-formatting helpers.
- Every active test must be registered in its local CMake file and built by its
  layer's aggregate target. A source present on disk but absent from an
  aggregate is not coverage.
- Regression manifests list only the complete workload file name:

  ```toml
  [workloads]
  tests = ["pebble-pebble-ctest-example-baremetal"]
  ```

  A workload file name must be unique under `bb-tests/output`. The runner scans
  that output root and fails if the name is missing or has multiple matches.
  Do not use `search_path`, paths in the manifest, per-workload `pk`/trace
  flags, or a separate rushB maintenance manifest. Backend selection and
  tracing belong to the runner; rushB is an auxiliary execution mode over the
  same workload set.
- Add small CTests and BallOps to Verilator manifests. Add BankOps to BEMU
  manifests. Add core/chip tests to every backend that actually supports that
  chip; do not claim coverage through stale or non-existent artifacts.
- After a rename or move, verify every manifest file name has exactly one match
  in the freshly synchronized output.

## Completion checks

1. Enforce the line limit and confirm one test per source.
2. Build the relevant CTest and MLIR aggregate targets with `-O2`.
3. Run the appropriate BEMU and Verilator regressions. Use BEMU trace when
   diagnosing or when the batch configuration enables it; trace is a backend
   setting, not a workload attribute.
4. Report the tests added, migrated, and deliberately removed, plus any
   unsupported geometry that now fails explicitly.
