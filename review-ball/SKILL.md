---
name: review-ball
description: "Ball-stage pre-PR review checklist. Use when reviewing a ball-round diff (new ball under examples/balls/<ball>): ISA header macros, bemu golden model, balldomain TOML registration, MLIR dialect, Scala RTL wrapper, regression lists, funct7/collision knowledge queries."
---

# Review: ball stage

Purpose: catch pre-submission problems in a ball-stage deliverable (`examples/balls/<ball>/**` plus registration points in the target core's `configs/balldomains/*.toml`). Pure static review: parse the diff, read the PR-head checkout `$BB` read-only. Never build, never simulate, never write.

Inputs: the git diff, the stage, the PR body when available. Run A→F in order, then the knowledge queries in the last section where a checklist item needs live-repo facts. Items not applicable are marked 未判; a recipe whose repo-side shape has structurally drifted → 需人工确认, not FAIL.

Reference templates (read as needed): `examples/balls/relu/` (minimal ball: arch + configs + emu + compiler + ctests), `examples/balls/transpose/` (mlir_tests pair), `examples/balls/matadd/` (verify/ option), `examples/balls/gemmini/` (one file, many funct7s — legal precedent).

## A. C header / ISA macros

1. **Include order** in `workloads/isa/<ball>.h`: `<bbhw/isa/bb_func7.h>` then `<bbhw/isa/isa.h>` (template relu.h shape). How: `sed -n '1,20p' $BB/examples/balls/<ball>/workloads/isa/<ball>.h`. Report: FAIL naming a missing or reordered include.
2. **No funct7 numeric literals.** Only `BB_FUNC7(<MNEMONIC>)` mnemonic references; reject `#define X_FUNC7 50`, `BB_FUNC7(50)`, `funct7 = 50`, and a numeric last argument in `BUCKYBALL_INSTRUCTION_*` — the `[uUlL]*` suffix class still counts as numeric. How: `grep -nE '[A-Za-z0-9_]*FUNC7[A-Za-z0-9_]*[[:space:]]*(=[[:space:]]*)?(0x[0-9a-fA-F]+|[0-9]+)'` and `grep -nE 'BB_FUNC7[[:space:]]*\([[:space:]]*(0x[0-9a-fA-F]+|[0-9]+)'` and `grep -nE 'funct7[[:space:]]*[:=]'` over the ball's sources. Report: FAIL naming each hit.
3. **Macro body encoding.** `BUCKYBALL_INSTRUCTION_R_R` carries the three argument slots `BB_BANK0(bank_id) | BB_BANK1(group) | BB_ITER(iter)`; the slot constants must exist (see isa.h of `bb-tests/workloads/lib/bbhw/isa/`). How: read the macro body; `grep -n 'define BB_BANK0\|define BB_BANK1\|define BB_ITER' $BB/bb-tests/workloads/lib/bbhw/isa/*.h`. Report: FAIL naming the missing slot.
4. **ctest file size.** Each `workloads/ctests/*.c` is a single file of ≤100 lines (the build-time FATAL mirrors it) and functional code must not be moved into a `.h` to dodge the limit. How: `wc -l` each `.c`; `grep -n 'function' *.h` suspicion check. Report: FAIL naming an over-limit or a dodge.
5. **ctest registration.** Every `.c` is registered via `add_buckyball_ctests` in `workloads/ctests/CMakeLists.txt`. How: compare `ls *.c` against the registration list (`grep -n 'add_buckyball_ctests'`). Report: FAIL naming an unregistered test.

## B. bemu golden model

6. **`const BALL_CLASS`.** Exists in `emu/src/lib.rs` (or the `<funct7>_<ball>.rs` module) and equals the `ballClass` of the target core's `ballIdMappings` row — string equality, no normalization. How: `grep -rn 'BALL_CLASS' $BB/examples/balls/<ball>/emu/src/`; `grep -n 'ballClass' $BB/examples/cores/<core>/configs/balldomains/*.toml`. Report: FAIL on mismatch.
7. **`execute_known` / `cycles_after_issue` signatures.** Return `Option<u64>` — `None` means "not this instruction". How: `grep -nE 'fn (execute_known|cycles_after_issue)' $BB/examples/balls/<ball>/emu/src/**/*.rs`. Report: FAIL on a non-Option signature.
8. **Instruction file referenced.** Each `emu/src/<funct7>_<ball>.rs` is referenced from `lib.rs` via `#[path = "..."]`. How: `grep -n '#\[path' $BB/examples/balls/<ball>/emu/src/lib.rs`; a shipped `NN_*.rs` without a reference → warn (dead file). Report: warn naming the dead file.
9. **No sentinel fallbacks in `exec`.** `.unwrap_or(` / `.unwrap_or_default(` / `Ok(None)` sentinels that swallow "not-a-match" semantics → warn; `unwrap_or_else(|| panic!(...))` is fine. How: `grep -nE 'unwrap_or(\(|_default)|Ok\(None\)' $BB/examples/balls/<ball>/emu/src/**/*.rs`. Report: warn naming each; a branch that silently defaults a match → FAIL 需人工裁决 checked against 7.

## C. balldomain TOML registration

10. **Table arithmetic.** `ballNum` == `ballIdMappings` row count; ballIds consecutive from 0 with no holes; no duplicate `ballId`/`ballName`; no duplicate `funct7`/`mnemonic` within one `ballISA` (per core). How: extract with `grep -nE 'ballNum|ballId[[:space:]]*=|ballName[[:space:]]*=|mnemonic[[:space:]]*=|funct7[[:space:]]*='` and reconcile. Report: FAIL per violated rule.
11. **Cross-references.** Every `ballISA` row's `bid` names a registered `ballId`; every ball has ≥1 ISA row; each `config=` (after relative resolution from the balldomain file) exists; `inBW`/`outBW` positive. How: `grep -nE 'ballId[[:space:]]*=|bid[[:space:]]*=|config[[:space:]]*=|inBW|outBW'`; `test -f "$BB/<resolved>"`. Report: FAIL naming each broken row.
12. **The one true registry.** This ball's rows must land in the registry file the core's aggregate config points at (`balldomain = "..."` in `examples/cores/<core>/configs/default.toml`) — no variant registry is selectable. How: `grep -n 'balldomain' $BB/examples/cores/<core>/configs/default.toml`, then confirm the diff touches exactly that registry. Report: FAIL naming a non-selected registry touched.
13. **Both tables present.** `ballIdMappings` and `ballISA` both appear in the file the ball registers into. How: `grep -nE 'ballIdMappings|ballISA'`. Report: FAIL naming the missing table.

## D. MLIR dialect / pass

14. **Dialect shape.** Exactly one `*.td` in `compiler/src/Dialect/Buckyball/`; `Transforms/LegalizeForLLVMExport.cpp` exists (the `_ball_compilers` build-dead-mirror). How: `find $BB/examples/balls/<ball>/compiler/src/Dialect/Buckyball -type f`. Report: FAIL naming a second `.td` or a missing legalize file.
15. **No `Buckyball_IntrOpBase` inheritance.** The `*.td` must not inherit `Buckyball_IntrOpBase<"<mnemonic>">` (it would generate unconditional `llvm::Intrinsic::riscv_bb_<mnemonic>` references); the accepted shape is `CustomIntrOp` + `buckyball_target::getBuckyballFunct7("<MNEMONIC>")` (relu/layernorm/int8add/smatmul precedents). How: `grep -n 'Buckyball_IntrOpBase\|CustomIntrOp\|getBuckyballFunct7' $BB/examples/balls/<ball>/compiler/src/Dialect/Buckyball/**`. Report: FAIL naming the inheritance (they only build when the mnemonic exists in the frozen enum).
16. **MLIR funct7 discipline.** Same no-numeric-literal rule in `.mlir` sources — the `// CHECK` lines of the lit tests are assertions too. How: `grep -nE 'funct7[[:space:]]*[:=][[:space:]]*(0x[0-9a-fA-F]+|[0-9]+)' $BB/examples/balls/<ball>/compiler/src/Dialect/Buckyball/**/*.mlir`. Report: FAIL naming each.
17. **Single-core wiring.** The ball's legalize sources appear in the core's `Transforms/CMakeLists.txt` list; in `LegalizeForLLVMExport.cpp`, `populate<ballName>LegalizeForLLVMExportPatterns` and `configure<ballName>LegalizeForExportTarget` each appear ≥2 times (declaration + call). How: first locate the core compiler tree (`find $BB/examples/cores/<core>/compiler -name 'LegalizeForLLVMExport.cpp' -o -name 'CMakeLists.txt'`), then `grep -rn '<ballName>'` on the resolved paths. Report: FAIL naming the missing declaration/call.

## E. Scala RTL

18. **Wrapper class.** A wrapper class carrying all three: `HasBlink` trait, a `ballIdMappings` lookup, and `BlinkIO`. How: `grep -rln 'HasBlink' $BB/examples/balls/<ball>/arch/src/main/scala/` and check each hit for the lookup and `BlinkIO`. Report: FAIL naming a class missing one.
19. **Package + class identity.** `package` + `class` equals the registered `ballClass` FQCN exactly (BBus reflection constructs via `(GlobalConfig)` — a runtime mismatch, surfaced as a dead ball). How: `grep -rn '^package\|^class' $BB/examples/balls/<ball>/arch/src/main/scala/*.scala`; compare with `grep -n 'ballClass' $BB/examples/cores/<core>/configs/balldomains/*.toml`. Report: FAIL naming the mismatch.
20. **RTL hard-constraint self-check (knowledge, no general machine check).** The wrapper must satisfy the hard constraints: SRAM read = 1 cycle; `cmdReq.fire` latches ALL fields; FSM `idle→read→compute→write→complete→idle` maps to `status.idle/running`; explicit widths with `+&`; same-bank read/write that would corrupt source data must be gated; unconnected ports tied off. How: read the Scala wrapper and each FSM state; mark each sub-check with a verdict line — PASS / FAIL / 未判 (with reason). Report: FAIL naming the violated constraint.

## F. Regression lists

21. **ctest stems in both tables.** Each ctest stem appears as `<chip>-<target>-ctest-<stem>-baremetal` (elf) and `-linux` (pk), where `<target>` is the compiler target (`core.role` or `core.pkg`). How: `grep -rn 'ctest-' $BB/examples/chips/<chip>/regression/batch/**/workloads-*.toml` and reconcile with the ball's `workloads/ctests/CMakeLists.txt`. Report: FAIL naming entries missing on either face.
22. **MLIRTest entries.** Each MLIRTest id (`<bank|ball>_<name>`) appears as `<chip>-<target>-mlirtest-<id>-baremetal` in the elf table (blocking); no `.mlir` = dead test (FAIL); the mlir_tests trio (`.mlir` + `_main.cpp` + the group's CMakeLists) is complete. How: `find $BB/examples/balls/<ball>/workloads/mlir_tests -type f`; grep the chip regression lists. Report: FAIL per rule.
23. **Lane placement.** verilator lists only small tests; bank tests run only on bemu (compare with the precedence in existing chips' tables). How: `grep -rn 'bank' $BB/examples/chips/<chip>/regression/batch/**/*.toml` and check lane placement. Report: warn / 需人工裁决 where the precedent is ambiguous — a lane reassignment must be reasoned, not silent.

## Knowledge queries (only when an item above needs live facts)

- **funct7 reserved set** (item 17-style collision checks): derive from the base macro files — `find $BB/bb-tests/workloads/lib/bbhw/isa -name '[0-9][0-9]_*.c' | sort` (the two-digit filename prefix is the funct7) — plus their `*_FUNC7` defines, `InitFunct` in `arch/src/main/scala/framework/balldomain/isa/BallISA.scala`, and the ISA table in `bbdev/api/steps/bebop/bemu/scripts/bemu_analysis.py`. Never carry the set from memory; report the derivation path with the answer.
- **ISA occupancy/free ranges**: use the `buckyball_isa_occupancy`-style free ranges if available; treat them as "not yet claimed", and always overlay the reserved set above.
- **Frozen intrinsic enum** (`llvm::Intrinsic::riscv_bb_*` validity): check `git submodule status` first (a `+` means uncommitted — 需人工裁决), then `grep -rn 'int_riscv_' $BB/compiler/thirdparty/buddy-mlir/llvm/llvm/include/llvm/IR/*.td` — the file list moves with the pin, so enumerate, don't assume.
- **Wiring precedents**: `grep -rn '<ballName>' $BB/examples/cores/*/compiler/src/Dialect/Buckyball/Transforms/CMakeLists.txt` and core dispatch files — pebble's Transforms list is greppable live (`grep -n 'examples/balls/' $BB/examples/cores/pebble/compiler/src/Dialect/Buckyball/Transforms/CMakeLists.txt`), and matadd's legalize is wired from its own ball directory, not a core dialect dir. Follow the precedent, don't invent a new wiring.
- **Verifier semantics note**: `freeRanges` in an occupancy tool means "unclaimed", not "safe" — safe requires the reserved-set overlay.
