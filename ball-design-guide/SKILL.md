---
name: ball-design-guide
description: "Design methodology for a new Buckyball ball: contract questions, funct7/ballId selection, isa/ctest templates, bemu golden model, Blink RTL wrapper, core wiring, MLIRTest, regression stems, verification-report reading. Use when designing, implementing, wiring, delivering or debugging a ball."
---

# Ball Design Guide

How to implement one new Buckyball ball (operator) so it builds, registers and passes CI. This is methodology and structure; live repository facts (registries, encodings, regression tables, the frozen intrinsic enum) are fetched through the `bb-knowledge` skill, never memorized here. Work happens against a local checkout; commands below use `$BB` for its root.

## Scope boundary: ball delivery vs model-side lowering

The ball's delivery endpoint is the dual phase (c-bemu / rtl) plus MLIRTest. Whether the model pipeline lowers an operator to this ball depends on a four-gate pattern chain in the compiler (linalg→tile recognition, Tile dialect op, tile→ball hook, bank-SSA sharding emitter — see `knowledge/shared/model-to-ball-pipeline.md`), which lives outside the ball write-set. The ball implementer does not own it and must not promise it: deliver the ball, and when the chain is missing state plainly that the model path is unreachable — never imply the model will lower to the ball.

## When to read which file

- This file: the stage-by-stage flow, the rules that gate each stage, and the PR-body evidence-manifest template.
- `references/templates.md`: the exact shapes to copy (isa header, ctest, bemu crate, RTL wrapper) and how to view the live templates.
- `references/wiring.md`: stage 4 in full — registry rows, the five core wiring sites, the LLVM-export rule, MLIRTest triplets.
- `references/report-debug.md`: the five log layers and the seven failure patterns to read a failed verification report.

## Stage 0 — Lock the contract, then pick codes

Answer the five contract questions in writing and attribute each one to the brief (missing ones must be marked, never invented): operator semantics; ISA field and shape source; element width and per-iter footprint; illegal-input table (same checks on every layer); output layout and naming.

Pick `ballId`, `funct7`, `inBW`/`outBW` only after checking the live tree, never from memory:

- Check the reserved set first: `bb-knowledge` has the recipe (base ISA files named with two-digit funct7 prefixes — `[0-9][0-9]_*.c`, not a literal `NN_*.c` glob — `BallISA.scala` InitFunct, the analysis-side ISA table). A collision with a base ISA value only surfaces as a `ValueError` during `--analysis` — registration and builds stay green until then.
- Run `buckyball_isa_occupancy` for the occupancy map. `freeRanges` means *unclaimed* only — it does not subtract framework-reserved values.
- funct7 is a 7-bit CUSTOM_3 field: `[6:4]`=enable, `[3:0]`=opcode. Enable legend: `000` none, `001` 1rd, `010` 1wr, `011` 1rd+1wr, `100` 2rd+1wr, `101..111` reserved. The registry row's `inBW`/`outBW` must supply the ports the instruction family needs.
- funct7 must not collide with the target core registry's ballISA rows (veto). Cross-core reuse of a funct7 for the same mnemonic is legal and shows up in `conflicts` as `mnemonic-collision`.
- ballId numbers from 0 with no holes; one ball may hang several funct7 rows off one `ballIdMappings` row.

## Stage 1 — C tests first, macros via mnemonic

- Copy the live templates: isa header from `$BB/examples/balls/relu/workloads/isa/relu.h`, ctest from `$BB/examples/balls/relu/workloads/ctests/relu_test.c`, registration list from the same dir's `CMakeLists.txt` (`add_buckyball_ctests`). See `references/templates.md`.
- Never hardcode a funct7 number in a ball's isa header or its `.mlir` files: `#define X_FUNC7 50`, `BB_FUNC7(50)`, `funct7 = 50` and `BUCKYBALL_INSTRUCTION_*(.., 50)` as the last argument are all violations — the value is generated into `ballISA.h` from the registry, so a literal silently survives a renumbering. Use `BB_FUNC7(<MNEMONIC>)` only.
- One ctest `.c` file ≤ 100 lines — the build enforces it (`buckyball_enforce_ctest_line_limit`), and moving functional code into `.h` to evade it is explicitly forbidden. Split into focused tests.
- Two test shapes: `small` (short shape, hand-written vectors, boundaries, illegal inputs) and `bank` (random vectors, iter≈BANK_LINES, bemu only — never in the verilator list).

## Stage 2 — bemu golden model

- `emu/src/lib.rs` must carry exactly three symbols the generated dispatcher chains: `const BALL_CLASS: &str` (exact string equality with the registry `ballClass`), `execute_known` and `cycles_after_issue`, both returning `Option<u64>` (miss = `None`). There is no core-side emu file to wire; the dispatch chain is generated at build time.
- One instruction file per funct7. The numeral lives only in the registry row; lib.rs dispatches by mnemonic, so the instruction file carries no funct7 constant and the file name does not matter to dispatch.
- `exec` must `panic!` on illegal input — no sentinel returns. `.unwrap_or(..)` / `Ok(None)` shapes are flagged as non-blocking warnings by the audit (a saturation clamp and a swallowed error are for a human to tell apart).

## Stage 3 — RTL wrapper and compute unit

- Files go under `$BB/examples/balls/<ball>/arch/src/main/scala/`; `arch/build.sbt` globs them, no registration. BBus instantiates by reflecting the registry `ballClass` FQCN with a `(GlobalConfig)` constructor, so `package` + `class` must spell it exactly.
- Wrapper shape: `@instantiable class XBall(b: GlobalConfig) extends Module with HasBlink`, look up `inBW`/`outBW` from `b.ballDomain.ballIdMappings`, `io = IO(new BlinkIO(b, inBW, outBW))`, tie off unused ports. See `references/templates.md`.
- Hard constraints (self-check list for stage 3): SRAM read is 1 cycle (`resp.valid` the cycle after `req.fire`, never same-cycle data); latch every field on `cmdReq.fire` including rob_id; FSM `idle → read → compute → write → complete → idle` with correct `status.idle/running`; explicit widths (`+&`); block same-bank read/write that would destroy source data.

## Stage 4 — Register, then wire

Full detail in `references/wiring.md`. The shape: three registry edits (mappings row, `ballNum` +1, ISA rows), then the ball-local minimum compiler set (exactly one dialect `*.td` + `Transforms/LegalizeForLLVMExport.cpp`), then on a single-core chip the core-side five wiring sites — sites 3, 4, 5 are build gates (missing 3 = link-time `undefined reference`; missing 4 or 5 = compiled but never called), sites 1 and 2 are include/doc surfaces. Then MLIRTest triplets and both regression stems.

- The LLVM-export form is one: the dialect `*.td` must **not** inherit `Buckyball_IntrOpBase` (that emits an unconditional `llvm::Intrinsic::riscv_bb_<mnemonic>` reference; the fork's enum is frozen and cannot be extended by a ball). Emit `CustomIntrOp` + `buckyball_target::getBuckyballFunct7("<MNEMONIC>")` in `LegalizeForLLVMExport.cpp`. Check the actual enum via `bb-knowledge`'s intrinsic recipe.
- regression stem = `<chip>-<target>-ctest-<stem>-<baremetal|linux>`; mlirtest stem = `<chip>-<target>-mlirtest-<id>-<baremetal|linux>`. `<target>` is the compiler target name — derive it from `_target_name(core) = core.role or core.pkg` (see `bb-knowledge`), not from the chip directory name.

## Reading a failed verification report

The attribution tree lives in the design contract's report section (first question: did bemu pass?). For the RTL lane, the entry path is the five log layers and the seven failure patterns — `references/report-debug.md` lists each pattern with its tell and where to fix.

## Evidence manifest template (PR body)

Copy this block into the PR body and fill in the `<…>` slots; delete any optional line you do not use (a leftover placeholder is judged "unfilled template" and PRE-FAILs). The shape rules the machine checks (`validate-manifest.mjs`) are listed in the ball-designer playbook's staged-delivery section; field semantics are owned by the verify-runner prompt.

```
stage: ball
# phase 取值：c-bemu | rtl
phase: c-bemu
# round 可选，正整数，第几轮；不用就整行删
round: 1
# chip 必填：examples/chips/ 下的实物目录名（不是 core 名，也没有缺省）
chip: <chip>
# probe 可选、可多行，逐 stem 声明 probe 预算（分钟，缺省 3，验证侧语义解释；
# 该 stem 走 sim + analysis 成对步骤）。只允许写在无 phase / c-bemu / bind 轮，
# rtl 轮写它 = PRE-FAIL；不用就整行删
probe: <stem> <分钟>
# perf 可选，单 token：本轮是性能轮。rtl 轮对 pmc-evidence.elapsed_avg（本轮自产，
# 不要求 probe: 行），c-bemu 轮对 probe-evidence.cycles（必须有同 stem 的 probe: 行）
perf: <stem>
# ball-expect 可选、可多行：逐 stem 声明 ball 落点期望（mnemonic 大写下划线、逗号
# 分隔）——probe 轮零事件（空流）时它就是该 stem 记 PASS 还是 FAIL 的分界；stem
# 必须是本轮真会跑的那个（即本轮 probe: / perf: 声明过的 stem），否则 PRE-FAIL；
# 不用就整行删
ball-expect: <stem> <MNEMONIC>
- 改了哪些文件：逐条路径
- 预期应跑的测试：本 ball 全部 ctest 与 mlirtest 的 binary stem 逐个列出，
  命名 <chip>-<target>-ctest-<stem>-baremetal（如 pebble 的 transpose：
  pebble-pebble-ctest-transpose_i8_16x16_test-baremetal；<target> = 编译器
  target 名 = core.role or core.pkg，按上文「chip 回归 TOML」段那条生成链取，
  别拿 chip 名顶替）与 <chip>-<target>-mlirtest-<bank|ball>_<name>-baremetal
- audit 输出摘要
```

## Rules that are easy to violate

- The old "default to toy" assumption is gone: the evidence list's `chip:` is required and must name a real `examples/chips/<chip>/` directory.
- Do not quote repository facts from memory — recipes exist precisely because the tree moved before. `buckyball_ball_audit` judges what it can read (nine structural checks) and reports what it cannot as not judged; a fresh submodule state (`git submodule status` showing `+`) means the intrinsic enum is unreadable until aligned.
