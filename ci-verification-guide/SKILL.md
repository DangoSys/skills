---
name: ci-verification-guide
description: "How the buckyball verification pipeline builds and reads its runs: per stage/phase/layer command sequences, probe-round mechanics (budget, log-dir backfill, evidence-line grammar, zero-event classification), verdict and report formats, NDJSON event shapes, and the command whitelist rationale. Use when planning, executing, interpreting or reporting a buckyball PR verification run, or when asked about bbdev plan sequences, probe evidence lines, or perf-gate delta rules."
---

# CI Verification Guide

Background knowledge for buckyball PR verification runs. The playbook's hard discipline
(verdict consumption, tool discipline, report contract) lives in the session prompt and is not
repeated here; this guide carries the mechanics behind it.

## Command sequences

The plan maps (stage, phase, layer, chip, stems, models, probes, probeBudget, perf, compilerTouched)
to one ordered step list. Sequence rules:

- **No-phase baseline** (the v1 full-batch baseline; phase absent): workload clean → workload build →
  bemu elf batch; stage `chip` prepends config install → compiler build; declared `models` append one
  `workload --build --model` per model, then probe pairs for the declared probe stems. `compilerTouched`
  prepends config install → compiler build for non-chip stages too.
- **ball/c-bemu**: (compilerTouched → config install → compiler build →) workload build → one bemu sim
  per stem; a stem with `probe:` becomes a probe pair (c-bemu's instrument is the probe).
- **ball/rtl**: (compilerTouched → config install → compiler build →) verilator clean → verilog →
  build → one `bebop-verilator sim --no-wave` per stem; the `perf:` stem adds `--pmctrace` (rtl's
  instrument is pmc; it generates NO probe steps, and a `probe:` declaration here is a manifest
  PRE-FAIL).
- **chip/skeleton**: config install → compiler build → workload build → one smoke stem sim (stems
  must be non-empty).
- **chip/slices**: (compilerTouched → config install → compiler build →) one bemu sim per slice stem,
  first failure stops the round.
- **chip/integrate**: (compilerTouched → … →) sims for the self-run slices stems (when the slices
  gate requires it) → bemu elf batch.
- **chip/bind**: per declared model `workload --build --model`, then (kernel-lane models only)
  `kernel --build --model`, then the probe pair — the upstream regression.yml paired run. `models`
  must be non-empty.
- **complete layer** adds bemu pk batch + the verilator elf chain.
- **Batch lanes** are pruned when `examples/chips/<chip>/regression/batch/<backend>/workloads-<elf|pk>.toml`
  is absent from the tree (reported in `skippedLanes`, never silently dropped). Verilator pk is never
  generated: the upstream non-rushB chain runs elf-tests only, pk-tests is rushB-only, and this
  verification surface never enters the rushB space.
- **compilerTouched** is a PR-level judgment (whole PR write-set touching
  `examples/balls/<b>/compiler/**` or `examples/cores/<c>/compiler/**`). Phases that consume the
  compiler's product — no-phase baseline off a non-chip stage, c-bemu, rtl, slices, integrate — then
  prepend config install → compiler build. skeleton always prepends them; bind never does (its
  `workload --build --model` does consume the product, so a broken compiler fails in Provision
  instead — that is deliberate).

### Checking the sequence against the upstream file

The order mirrors the upstream chip-check chain. To re-check the mapping against the live checkout:

```sh
# chip-check job's matrix + non-rushB step order
grep -n "chip-check" -A 60 $BB/.github/workflows/check.yaml
# where verilator reaches pk-tests (rushB only)
grep -n "pk-tests\|rushB" $BB/.github/workflows/check.yaml
# the paired workload+kernel run in regression.yml
grep -n "kernel --build\|workload --build" $BB/.github/workflows/regression.yml
```

The plan's stage/phase legs and probe pairs exist only in the verification contract, not upstream, so
the check is about the base chain and the lane tomls, not every step.

## Probe round

The probe round answers "where is it slow", never "is it correct". It covers bind-round model stems and
stems with a `probe: <stem> <minutes>` declaration. Probe phases: `c-bemu`, `bind`, and the no-phase
baseline with declared models only — the manifest's phase whitelist PRE-FAILs any `probe:` outside them.

Flow (strict order, each step submitted through the trio):

1. Submit the plan-generated sim step (`bebop-bemu --sim … --pk --itrace --mtrace`).
2. Poll status up to the budget (default 3 min; the declaration's minutes override). Cancel at budget —
   a budget-to-point `cancelled` is expected, not a failure.
3. Submit the paired analysis step with `--log-dir` replaced by the ONE candidate that
   `buckyball_bbdev_probe_logdir({chip, stem, simStartedAt})` returns (it globs
   `$BB/log/*-<chip>-*-bemu-<stem>`, filters by mtime vs the sim's startedAt, and throws on zero or
   multiple candidates; never glob by hand, never pick "the newest one" yourself).
4. Post evidence: cycles run, funct cycle-share top-5, mtrace bank occupancy, plus one machine-readable
   evidence line for this round's instrument (see references/probe-events.md for the exact grammar).
   Numbers come verbatim from the probe-read tool's `analysisText`; if it is missing, report
   "analysis.txt 不存在" and follow the failure semantics.

Failure classification (event counts from the probe-read tool; strict, no downgrade path):

- Zero-byte / zero-itrace stream: if the manifest declares no ball-expectation for the stem, this is
  the host-fallback shape — PASS with the note "零 ball-op: host fallback 形态 (probe 仪器不适用)";
  if it does declare one, FAIL "ball 未执行 (layout 管线断点)". The analysis step exiting 1 here is
  covered by this branch (upstream analyser throws `no itrace events in <bdb>` by design) — do not add
  a second "analysis 失败" FAIL.
- Any other analysis failure (truncated last line, `itrace span is 0 cycles`) → FAIL
  "probe trace 分析失败", quote the error verbatim; no retry, no trimming, no silent rerun.
- Probe-read throws (log-dir or bdb.ndjson missing) → FAIL "probe log-dir 未找到".

Judgment callouts for the report: model-level workload fully running >20 min is an unoptimized signal;
optimized-vs-unoptimized sim time differs 10x+. Delta math is per-instrument only: rtl rounds compare
`pmc-evidence` elapsed_avg, c-bemu/bind/no-phase compare `probe-evidence` cycles — never subtract
across instruments. A `perf:` round must present a same-instrument delta (else FAIL "性能结论无证据");
incomparable budgets → "预算不可比，本轮不作性能结论"; no baseline → mark baseline, never claim an
optimization effect.

Optimization-iteration contract: a coding-side PR should state three items in its description — which
probe hotspot (funct + cycle count) was addressed, what changed, which metric is expected to improve.
This verification surface has NO machine gate on those three items: missing them is a note at most,
never a FAIL, and having them is not performance evidence. The gates are the evidence line and the
same-instrument delta.

## Verdict and report formats

- First line of the final answer: `VERDICT: PASS` or `VERDICT: FAIL`. The process exit code only
  reflects session completion, not the verdict.
- Both the PR reply and the final answer carry a `head sha: <40-hex>` line (the PR's headRefOid,
  verbatim — no abbreviation, no case change). Integrate rounds' slices gate matches this line against
  the current head to accept a previous PASS.
- PASS: `gh pr review <PR> --approve` plus a comment (judgment block restated, commands run with exit
  codes, key output). When the bind round PASSes on probe evidence, the conclusion must state
  「功能收敛未证，需 complete 层或更长预算补全跑」.
- FAIL: `gh pr comment <PR>` with four elements — failed command verbatim, log tail, suspected
  attribution (from the decision tree: workload build → registration/build; bemu batch → semantics/
  integration; verilator after bemu → RTL), and JUnit facts from the junit-read tool.
- Mechanism descriptions in the report must match session evidence verbatim; if unsure, omit.

## NDJSON event shapes

Trace files are NDJSON — one event object per line (exact keys and semantics: see
references/probe-events.md). PMCTRACE exists only in RTL/verilator sims, never in bemu traces.

## Whitelist rationale

- `config install` — only producer of `chip.pb`; runs ahead of compiler build in the upstream chain.
  It is args-free upstream (a boolean switch), so it must be submitted with NO args.
- `kernel build` — open for the bind leg's paired run with `workload --build --model` (regression.yml).
  Only models in the kernel lane's own `KERNEL_MODELS` get the step (read from the tree at plan time —
  `$BB/bbdev/api/steps/kernel/01_build_event.step.py`); anything else makes `kernel --build` raise
  `unknown kernel model`, a guaranteed red. It is NOT a probe prerequisite: `--pk` is bemu's
  in-process proxy kernel and never boots `fw_payload`.
- `bebop-p2e` — closed; it is the only consumer of `fw_payload`, outside this verification surface.
- `uvm` — closed: `uvm --run` is a live upstream gate but needs VCS/urg.
- `ip (generate|replace)`, `firesim`, `yosys`, `dc`, legacy `verilator`/`vcs` — closed; the `bebop-*`
  front doors cover this surface.
- Sub-args are ONE argv string (bbdev shlex-parses it); pre-split args are rejected with
  "must be quoted as one string".

## Reference files

Read the matching one when you need the full detail:

- `references/probe-events.md` — evidence-line grammar (all four forms + sentinel literal, per-round
  instrument exclusivity), NDJSON event keys, and how the NEXT round's perf gate parses them.
- `references/command-sequences.md` — per-phase step tables with lane gating and notes.
