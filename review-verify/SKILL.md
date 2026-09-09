---
name: review-verify
description: "Verify-stage pre-PR review checklist. Use when reviewing verify-stage products before PR submission: the evidence manifest, PR-body evidence block, and VERDICT reply text (not the CI). Schema rules, evidence consistency, VERDICT format, evidence-line lint, perf delta, slices gate, hygiene."
---

# Review: verify stage

Purpose: catch pre-submission problems in the verify stage's artifacts — the evidence manifest in the PR body (fields `stage`/`chip`/`phase`/`round`/`probe`/`perf`/`ball-expect`/`--model`), the evidence lines in the PR reply (comment or review), and the VERDICT report itself. This is a static text review: no bbdev run, no tree mutation, no VERDICT production. The CI's own scripts are the reference implementation — the deterministic gates live in `$DSH_PLUGIN/packages/verify-runner/scripts/` (`validate-manifest.mjs`, `manifest.mjs`, `binding-check.mjs`, `slices-verify.mjs`, `probe-loop-check.mjs`, `infer-stage.mjs`); when a CI-captured `pr-context.json` is available (`gh pr view --json body,headRefOid,comments,reviews`), running those scripts is the strongest form of the check. Port their rules; never weaken them. Path variables below: `$BB` = the buckyball checkout (PR head), `$DSH_PLUGIN` = the dsh-plugin repo root.

Inputs: the diff, the stage, the PR body, and the reply texts (comments ∪ reviews). Run 1→10 in order; each verdict line names the artifact and the facts it was derived from. Items not applicable are marked 未判 with the reason.

## 1. Manifest schema rules

`stage:` ∈ {workload, ball, chip} (mandatory, first field); `chip:` mandatory (no default-toy assumption) and the directory exists in the checkout (`examples/chips/<c>`) — a same-named `examples/cores/<c>` entry is a core, not a chip; `phase:` ∈ the stage's legal set (ball: c-bemu|rtl; chip: skeleton|slices|integrate|bind; workload: none); `round:` a positive integer when written. Field lines are whole-line declarations (line start + optional bullet/backtick, trailing inline `#` comment stripped), probe: `probe: <stem> <分钟>` (integer minutes, `分钟`/`min` suffix tolerated), perf: `perf: <stem>` (one token), `ball-expect: <stem> <MNEMONIC>[,<MNEMONIC>…]` (uppercase underscore mnemonics, comma-separated), `--model <key>` one key per whole line (prose mentions and fenced command examples are NOT declarations). Any `<stem>`-style unfilled placeholder is the 「清单模板未填」 verdict on its own. How: `node $DSH_PLUGIN/packages/verify-runner/scripts/validate-manifest.mjs --context pr-context.json --repo-root $BB` when the capture exists; otherwise grep the body line-by-line with the DECOR anchor ``^\s*(?:[-*]\s*)?`?`` (the `DECOR` constant in `manifest.mjs`) before the field name. Report: FAIL with the offending line.

## 2. Evidence self-consistency (cross-face)

Stage inference (widest stage of the round's declared stages) vs the declared `stage:` — conflict → note; model write set vs `--model` declarations: a model key claimed in `--model` lines must be backed by a real write (diff path under `bb-tests/workloads/src/ModelTest` or `bbdev` pointer moving with a `MODEL_LAYOUT` mention) or by one of the declared registration points — a declaration without a write (or a write without a declaration) → FAIL; probe/perf phase whitelist: only `c-bemu`, `bind` and the no-phase baseline consume probes (a baseline round with no `--model` lines runs no probe at all — probe/perf there is 「不落地」), `rtl` perf self-produces `pmc-evidence` via `--pmctrace` and needs no probe line, `skeleton`/`slices`/`integrate` round probes are dead. How: `node $DSH_PLUGIN/packages/verify-runner/scripts/binding-check.mjs --context pr-context.json --repo-root $BB` + `$DSH_PLUGIN/packages/verify-runner/scripts/infer-stage.mjs --context pr-context.json` when captures exist; otherwise reconcile diff paths with the manifest fields. Report: FAIL per rule; 需人工裁决 when the write set cannot be established.

## 3. VERDICT reply format contract

First line matches `^VERDICT: (PASS|FAIL)`; a `head sha:` line exists and equals `headRefOid` (40 hex chars, exact case, no abbreviation); the verdict block records stage/phase/layer/round as declared; a FAIL carries the four elements — the command verbatim, the log tail, the suspected cause, and the JUnit facts; a bind-round PASS must carry the literal string 「功能收敛未证，需 complete 层或更长预算补全跑」. How: test the first line with the regex, extract the sha line, check the four elements' presence in the FAIL body. Report: FAIL naming each missing element.

## 4. Evidence-line lint (four strict forms)

Accepted forms (line-anchored, key names and field order strict, decoration tolerated): `probe-evidence: <stem> cycles=<N>`; `<chip>/<stem>` prefix variant; `cycles=none (instrument-not-applicable)` sentinel; `pmc-evidence: … calls=<N> elapsed_avg=<f> elapsed_max=<f> elapsed_min=<f>`. One round, one instrument: an `rtl` round must not carry probe-evidence lines and vice versa (rtl = pmc instrument, c-bemu/no-phase = probe instrument). A line that *tries* to be evidence but fails the shape is named, not dropped. How: grep each reply body for `probe-evidence`/`pmc-evidence` lines and compare against the round's phase. Report: FAIL naming each malformed or misplaced line.

## 5. perf round delta obligation

A round declaring `perf:` owes a same-instrument delta in the same reply — `cycles: <prev> → <now>（Δ …）` or `elapsed_avg: …` per instrument; no delta → FAIL「性能结论无证据」; a word-salad claim — 「明显变快」/「符合预期的取舍」/ any no-number framing — is named; a previous-round sentinel (instrument-not-applicable) means this round has no comparison base and must recite the not-applicable clause instead of claiming a baseline. How: `node $DSH_PLUGIN/packages/verify-runner/scripts/probe-loop-check.mjs --context pr-context.json` (with capture) or grep the reply for the delta pattern and for the blacklist words. Report: FAIL on missing delta, note baseline/sentinel cases.

## 6. slices-gate evidence prerequisite

An `integrate` round claiming 「上一轮 slices 已过」 needs a prior PASS reply that declares its own `phase: slices` on a DECOR-anchored line and whose recorded head sha matches the current PR head; without it the claim is unsupported. How: `node $DSH_PLUGIN/packages/verify-runner/scripts/slices-verify.mjs --context pr-context.json` (comments ∪ reviews, both faces) or manual search for `VERDICT: PASS` + `phase: slices` declaration + `head sha:` in the same reply. Report: FAIL on missing evidence; note when the gate is N/A.

## 7. Reply-face facts

The verdict report lands in comments ∪ reviews (a PASS as a review is invisible to a comments-only scan — check both); the first line is matchable by `^VERDICT: (PASS|FAIL)` (INFRA-class exclusion must be stated); more than one repost of the same verdict → flag (2+ duplicates); marker idempotency is run-only. How: list both faces, dedupe first lines, count. Report: warn per finding.

## 8. No-execution / no-rewrite assertion

The report's command list replays `bbdev-plan`'s output for the same (stage, phase, layer, chip, stems, models, probes, perf, compilerTouched) — command names, ops, and args must not be hand-assembled; no placeholder residue (`<[A-Z][A-Z0-9-]*:[^>]*>`); no command outside the existing whitelist. How: compare the report's commands against the plan capture (or against `src/tools/bbdev-plan.ts`'s builder when no capture exists); `grep -nE '<[A-Z][A-Z0-9-]*:[^>]*>'` on the reply. Report: FAIL naming each deviation or residue.

## 9. Read-only / no-fallback statement lint

Fallback phrasing — 「缺省 toy」, 「退回到」, 「用最新一个」, any "default to X" without a declared basis — is named; `skippedLanes`/`skippedProbes` entries must be recorded with a reason and matched against the round's plans. How: grep the reply for the fallback words and check every skip entry's reason. Report: warn naming each phrase, FAIL on an unexplained skip.

## 10. Baseline-reference residue

`check.yaml`/`regression.yml` line numbers, fork drill PR numbers, and the pinned shas must not appear in prompt text, replies, or manifests — replacing them with knowledge-base retrieval or deleting them is the fix. How: `grep -nE 'check\.yaml:[0-9]+|regression\.yml:[0-9]+|9bb40565|90560b4|6e389513|8f73458|7cb39e5'` on the artifacts. Report: FAIL (must-fix residue) naming each occurrence. (The sha list itself is a residue landmark, not a live pin — verify against the actual residue, not the list.)

## Out of scope

The CI verdict itself (whether the round actually passed — CI decides that), run logs, and build results: this checklist reviews the artifacts' internal consistency and contract adherence only.
