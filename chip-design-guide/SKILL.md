---
name: chip-design-guide
description: "Guide for designing a new Buckyball chip: D1-D5 capacity chain, skeleton schema, contract.toml, mlirtest stems and batch manifests, model-binding write-set, bind round, perf iteration contract. Use when designing a chip, writing its configs or evidence manifest, deriving stems."
---

# Chip Design Guide

This is the domain-knowledge reference for the chip stages. Discipline (write-set
boundaries, delivery rules, machine-checked manifest fields) lives in the
chip-designer playbook; this guide carries the method and the reference
implementations. Facts about the live checkout are never quoted here: every
value you need comes from a recipe run against the repository.

## Working with the live repository

- Treat every fact as current only after you `grep` it yourself; expand `$BB`
  to the actual checkout path when running a recipe. Stable anchors only
  (directory paths, file names, symbol names) — never line numbers or pins.
- Use the `bb-knowledge` skill for its recipes (chip-toml-schema,
  capacity-banks, funct7-reserved, regression-manifest, mlirtest-wiring,
  model-binding, verification-trace, model-to-ball-pipeline): this guide
  names what to look for, the recipes give the exact commands.

## Stage 0 — capacity evidence chain (single-core fit)

The facts come from the index tool plus the capacity-banks recipe: the core's
`[bank]` geometry `{num, width, entries}` (`examples/cores/<core>/configs/
memdomains/`) and, for spillover, the `[sharedMem] enable` of EVERY resolved
tile. The pool is core-private; banks are never pooled across cores.
1. **Row math**: `rowB = width / 8`; `bankB = entries × rowB`; private pool
   `pool = num × bankB`; `lines(S) = ceil(elements × elemBytes / rowB)`;
   `cols(S) = ceil(lines / entries)`.
2. **D1 — single region fits**: `lines <= cols × entries`.
3. **D2 — encodable columns**: `1 <= cols <= 32` (upper bound: the MSET column
   range; lower: the physical-bank allocation's shape check; `cols = 0`, the
   "whole pool" shorthand, is rejected — write the real column count).
4. **D3 — concurrency slots**: peak simultaneously-live `Σ concurrent × cols
   <= num`. The compiler-side physical-bank allocation judges ONLY this
   dimension (a CONTIGUOUS run of `need = row × col` slots); nobody judges
   depth statically — that is why stage 0 judges D1 itself. D3 is necessary
   but not sufficient: fragmentation can still fail allocation at compile time
   (`out of physical banks`), a compile-time fact, not your judgement.
5. **D5 — shared-pool spillover**: admissible only when EVERY tile hosting
   this core writes `[sharedMem] enable = true` (a sibling tile's `true` does
   not vouch for a `enable = false` tile). Spill re-judges D3 against
   `bankNum × nCores` slots — a WIDER slot set, never a deeper one: every
   shared bank is the same `SramBank` with `bankEntries` rows, so D1 keeps its
   `lines <= cols × entries` bound and the tile's `[sharedMem] entries` is a
   declared value, not a per-slot depth. A single-core tile (`nCores = 1`) has
   the same slot count as the private pool — no gain. c-bemu does not model the
   shared pool, so a spill conclusion is RTL-side evidence only.
6. **Operator-internal shape predicates (D4)**: read each ball op's `*.td`
   definition and its legalization for explicit rows/cols/iter constraints —
   never guess from memory.
7. **Optimize before declaring failure**: if D1/D3 miss, first try different
   tiling (row-group split, smaller blocks, serializing to lower peak
   `Σ cols`) without changing op semantics. Still missing → announce the
   failure and exit the whole flow. Report format: required vs bound (two
   numbers) + the sharding parameters tried + the conclusion.
8. **PPA evidence**: `dc --area` / `dc --power` (needs the chip's `tapeout/`
   contract) or `yosys --run`; scale-up reference: toy's 1t4c / 1t8c / 1t16c
   and the goban topology family.
9. **Probe rounds (fork-private convention)**: performance PRs earn evidence
   through a probe round — CI runs `bebop-bemu --analysis` and posts the
   summary (funct hotspots + cycle counts) back to the PR; cite that post.
   The before/after cycle-count delta is the ONLY acceptance criterion.
   No posted summary → no performance claim, no invented numbers.

## Stage 1 — topology and naming

- Prefer ONE tile; express heterogeneity with core types, not tiles. Core
  selection: five domain references and the compiler package presence.
- funct7 collision is a veto: a new ball's funct7 must not collide with the
  selected core's balldomain (index reports `funct7Duplicates`) nor with the
  base-ISA table / framework-reserved value (recipe: funct7-reserved). A
  collision fails not at registration but at evidence time — check first.
- Multi-core: copy counts by stage-relative latency (TTFT-critical stages get
  more cores for realtime scenarios). Naming: chip and core names are separate
  (precedent: chip `poly`, cores `prefill`/`decode`); `prefill`/`decode` stay
  reserved for the LLM pipeline.

## Stage 2 — graph cut (multi-stage / multi-core only)

- Use the buddy-mlir toolchain: import per model, one
  `codegen/partition_strategy.py` per model, `verify_layer_partition.py` to
  check, producing `partition_manifest.json` and slice groups. Never write
  your own Dynamo partition script.
- One `contract.toml` per slice, locking `[slice]` / `[io.in]` / `[io.out]` /
  `[policy]` (`mismatch = "error"`; template `references/contract-template.md`).
  Toolchain docs: `compiler/thirdparty/buddy-mlir/docs/LayerPartitioning.md`.
- Slices that cannot be cut: say so plainly (stage-only); do not invent an
  out-of-band partitioner, do not push it to the core designer, and do not
  require full-model E2E green before cutting.

## Stage 3 — skeleton checklist (8 mandatory + 1 optional)

Read `references/skeleton-schema.md` before building (full 8+1 checklist with
an on-disk schema example and a live-tree recipe per item). Build under
`examples/chips/<chip>/`, note which reference chip each item copies
(toy / pebble / poly / goban), and verify against the live tree.

Four hard contracts (any violation fails the gate):

- `configs/chip.toml`: `[designs] include` must point at this chip's design
  file and `[sims]` must carry non-empty `verilator` and `p2e` keys.
- design `[top] nTiles` must equal the `[[tiles]]` row count or the
  `[tileTemplate] count` expansion.
- every `WithBuckyballTiles` argument in `CustomConfigs.scala` must land under
  `examples/chips/<chip>/` (the config artifact is generated, never hand-written).
- sim config class names (`Buckyball<Chip>VerilatorConfig`,
  `P2E<Chip>Config`) are globally unique; `workloads/CMakeLists.txt` must
  define the `chip-workloads-build` target.

`arch/` and `configs/` are walked by the build automatically — no registration
step. Balldomain registries live under `examples/cores/<core>/configs/balldomains/`.

## Stems and batch manifests

- ctest stem: `<chip>-<core>-ctest-<test>` + suffix (`-baremetal` for elf
  lists, `-linux` for pk lists); `<core>` is the `[[cores]] name` role, else
  the package; the CMake side requires `BUCKYBALL_CTEST_TARGET` set (naming in
  `bb-tests/workloads/src/CTest/CMakeLists.txt`).
- mlirtest stem: `<chip>-<target>-mlirtest-<prefix>_<name>` + same suffixes;
  `<prefix>` is the source's direct parent directory; the macro prevents
  double-prefixing when `BUCKYBALL_MLIR_TEST_PREFIX` already carries the group
  token, and a chip-local bespoke generator spells its full stem itself.
- **Cross-check both directions**: every ball-side mlirtest under the
  referenced cores and every chip-side stem the wired `add_subdirectory`
  groups produce must appear in the chip's bemu elf batch. List-present-but-
  stem-missing = miss; list-absent because the chip has no `regression/`
  directory = lane not registered upstream (report as unjudged, never silent).
- `exclude: <stem> — <理由>` lives in the PR evidence manifest (non-empty
  reason only); batch TOMLs never carry excludes.
- Verdicts the audit no longer performs live: a `.mlir` in a wired group that
  no generator call names is dead weight (nothing builds it, nothing to list);
  a call whose stem is not derivable (interpolated `TARGET ${VAR}`,
  `foreach`-generated names, unrecognized local function) is unjudgeable —
  say so, never invent a stem.

## Stage 5 — delivery and the CI sequence

- The upstream sequence (read the live text, don't trust a copy):
  `bbdev config --install` → `compiler --build '--chip <chip>'` →
  `workload --clean` + `workload --build '--chip <chip>'` → bemu batch
  `elf-tests` then `pk-tests` → verilator `--clean/--verilog/--build` →
  verilator batch `elf-tests`. Recipe:
  `grep -n 'nix develop -c bbdev' $BB/.github/workflows/check.yaml`
- Ordering semantics to state in the evidence list: slice unit tests first,
  then sharedMem pairwise, then E2E. Command details live in the toolchain
  docs (passed as the playbook's dynamic path parameter).
- PR evidence list per field rules: the chip-designer playbook "分阶段交付"
  owns the machine-checked field 口径 (whole-line `--model`, probe/perf phase
  whitelists, non-empty exclude reasons); template `references/manifest-template.md`.

## Stage 6 — model binding and the bind round

- Write-set is chip-side territory, four places, any one missing is red:
  ① bbdev `MODEL_LAYOUT` entry (only for a NEW model key); ② e2e layout dir
  `models/archs/buckyball/<chip>/<Layout>/`; ③ three entries in the e2e
  `models/archs/buckyball/CMakeLists.txt` (`BUCKYBALL_<X>_DIR` variable,
  `BUCKYBALL_ALL_MODELS` whitelist item, `if(MODEL_<X> …)` wiring block); ④ the
  parent-repo `bb-tests/workloads/scripts/build.py` `_MODELS` entry (a
  parent-tracked plain file, not submodule content).
- Precedent split: chips WITH layout dirs copy the pebble shape; chips outside
  the whitelist (e.g. toy, multi-rocket) copy the poly/Gemma4 shape — the two
  goban/pebble-only variables are not available to them, and the archs
  CMakeLists gates may require e2e branches; first-time binding outside the
  whitelist is an upstream-uncovered path — expect the two gates.
- Bind round command sequence (the only source): `workload --build
  '--chip <c> --model <m>'` → `kernel --build '--chip <c> --model <m>'` → per
  model `bebop-bemu --sim '--chip <c> --binary <stem> --pk'` (the run target
  is a Linux-ABI static ELF — always `--pk`; `--pk` is bemu's in-process
  proxy kernel, and the kernel step's `fw_payload` only feeds the closed
  `bebop-p2e` lane). Only models the kernel lane knows are generated.
- Multi-submodule PR paradigm: feature branches in BOTH subrepos; the parent
  PR carries the gitlink bump + `.gitmodules` change + the `_MODELS` entry,
  with one `--model <model key>` line per model in the evidence list.

### Bind expectations vs the pattern chain

A derived ball existing in the tree does NOT mean the model pipeline lowers
to it: model-side lowering needs a four-gate pattern chain (linalg→tile
recognition, Tile dialect op, tile→ball hook, bank-SSA sharding emitter).
Run the recipes in `knowledge/shared/model-to-ball-pipeline.md` before
declaring a bind expectation. Chain missing → the ball still delivers
(MLIRTest layer), but the expectation must state "model path unreachable
(missing pattern chain)" — never "the model will lower to the ball".

## Reading verification reports

Read `references/verification-report.md` before writing a perf-round evidence
list or interpreting a FAIL report (PASS/FAIL loop, perf iteration contract,
`latency`/`span_cycles` identity, bemu-first attribution tree).

## Reference files

- `references/manifest-template.md` — evidence manifest template; read before writing the manifest.
- `references/skeleton-schema.md` — 8+1 skeleton checklist with recipes; read when building the skeleton.
- `references/contract-template.md` — slice `contract.toml` template; read when cutting a graph.
- `references/verification-report.md` — report reading and perf iteration contract; read after a verification round.
