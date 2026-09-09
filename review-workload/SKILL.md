---
name: review-workload
description: "Workload-stage pre-PR review checklist. Use when reviewing a workload-round diff (initial ModelTest e2e model adaptation): write-set containment, gitlink consistency, manifest fields, model-dir completeness, CMake registrations, expected-value tracking, annotation rules."
---

# Review: workload stage

Purpose: catch pre-submission problems in a workload-stage deliverable — one ModelTest e2e model directory (`bb-tests/workloads/src/ModelTest/e2e/models/models/<X>/`), its two registration points, and the parent PR. Pure static review: parse the diff, read the PR body, read the PR-head checkout `$BB` read-only. Never build, never simulate, never write. Path variables: `$BB` = the buckyball checkout, `$DSH_PLUGIN` = the dsh-plugin repo root.

Inputs: the git diff (gitlink changes appear as a pointer line in the parent diff), the stage, and the PR body when the caller has it (evidence manifest under the 「改了哪些文件」 marker or a `## Changes` heading).

Run A→C in order. Items that do not apply are marked 未判 (not judged), never skipped silently. If a repository-side shape the recipe anchors on has changed structurally, report 需人工确认 (needs human adjudication) instead of FAIL — that is repo drift, not an author error.

## A. Range and pointers (diff level)

1. **Write-set containment.** Allowed diff paths: the e2e gitlink pointer (`bb-tests/workloads/src/ModelTest/e2e`), `bb-tests/workloads/src/ModelTest/e2e/models/CMakeLists.txt`, `bb-tests/workloads/src/ModelTest/e2e/models/models/CMakeLists.txt`, and `bb-tests/workloads/src/ModelTest/e2e/models/models/<X>/`. How: `git -C $BB diff --name-only <merge-base>` for the whole PR and classify each path (a gitlink shows only as its path in the parent diff; inspect the submodule for what it points to). Zero-diff requirement: `bbdev/**` (incl. `MODEL_LAYOUT` in `bbdev/api/steps/workload/01_build_event.step.py`), `bb-tests/workloads/scripts/build.py` (`_MODELS`), `bb-tests/workloads/src/ModelTest/e2e/models/archs/buckyball/**`, `scripts/**`. Report: FAIL naming each out-of-scope path.
2. **Gitlink consistency.** Parent gitlink equals the submodule branch tip; the submodule branch contains latest main; its commit set is exactly this round's write set (no extra rounds, no subsequent-stage assets). How: `git -C $BB ls-tree HEAD bb-tests/workloads/src/ModelTest/e2e` vs `git -C <e2e> rev-parse HEAD`; `git -C <e2e> merge-base --is-ancestor main HEAD`; `git -C <e2e> log --oneline main..HEAD`. Report: FAIL on a tip mismatch, on extra commits (name them), or on a branch not based on current main.
3. **Manifest pre-check.** `stage: workload` present; `chip:` present and non-empty; no `phase:` / `probe:` / `perf:` / `ball-expect:` lines (workload stage has no phase dimension, probes have no execution carrier); no `--model` declaration line (an unbound model is not this round's subject); `round:` a positive integer when written; each field line is a whole-line declaration (optional bullet/backtick decoration, trailing inline `#` comment tolerated). How: read the PR body; when a CI-captured `pr-context.json` is available (`gh pr view --json body,headRefOid,comments,reviews`), run `node $DSH_PLUGIN/packages/verify-runner/scripts/validate-manifest.mjs --context pr-context.json --repo-root $BB` and report every PRE-FAIL line. Report: FAIL with the offending line.

## B. Artifact completeness

4. **Model directory essentials.** The directory must carry, at top level: an importer (`*.py`), a driver (`*-main.cpp`), `CMakeLists.txt`, `.gitignore`, `HANDOFF.md`. How: `find $BB/bb-tests/workloads/src/ModelTest/e2e/models/models/<X> -maxdepth 1 -type f`. Report: FAIL naming each missing kind.
5. **HANDOFF sections and reproduce command.** Five headings present, matched as markdown headings: `Artifacts`, `Canonical Reference`, `Local Run`, `Build Binding`, `Known Limitation`; the reproduce command appears in the text with whitespace folded. How: `grep -nE '^#+ *(Artifacts|Canonical Reference|Local Run|Build Binding|Known Limitation)' <X>/HANDOFF.md`; compare the command after collapsing each side's whitespace runs to one space. Report: FAIL naming missing headings or the missing command.
6. **The two CMake registration points.** In `models/models/CMakeLists.txt`: a `set(MODEL_<FLAG>_DIR ...)` entry and an `if (MODEL_<FLAG>)` guard wrapping `add_subdirectory(<X>)`, the flag matching the directory name after normalization (lowercase, strip non-alphanumerics); in `models/CMakeLists.txt`: the new flag in the MODEL reset list. How: `sed -n '1,40p' <file>` and compare flags by the normalization rule. Structural change in the CMake shape → 需人工确认, not FAIL.
7. **Expected-value source.** Declared source resolves to a path inside the model directory (reject `..` traversal), the file exists, and: declared tracked → no `.gitignore` rule at `<X>/.gitignore` or `models/models/.gitignore` claims it (`git -C $BB check-ignore -v <path>` or read the two files; a rule hits when the path equals the rule body or a prefix-segment glob matches); declared untracked → HANDOFF states the value is generated by the reproduce command. Report: FAIL on traversal, missing file, claimed-by-ignore, or a missing regeneration statement.
8. **Generated artifacts must not reach the diff.** Importer outputs (`*.mlir`, `*.data`, `*.payload/`, `output/`) appearing as diff paths (or as added files) mean the commit escaped the ignore rules — a `.gitignore` rule at the directory level must already cover them. Report: FAIL naming the file plus the rule that should have covered it, or the missing rule.

## C. Form and annotation

9. **Expected-value encoding form.** The value must be encoded as either a fail-hard driver (a `constexpr`-style expected constant in `*-main.cpp` with the mismatch branch `return 1`) or a reference script in the directory (the `python3 <x>-ppl.py --weights <arg0.data>` shape). How: `grep -nE 'constexpr|return 1' <X>/*-main.cpp`; list `*.py` next to the driver. Neither form present → 需人工确认 (the model may legitimately use a third shape), never silently accepted.
10. **Team-extra form annotation.** When the directory carries `--jit-check`, a `pytorch-<x>-*.py --check` companion, a `reference/<x>_manifest.json`, or a `.rax` package (the `buddy-cli` host-CPU path), HANDOFF.md must explicitly mark the form as a team addition. How: `grep -rnE 'jit-check|--check|manifest\.json|\.rax' <X>`; then `grep -n '团队附加' <X>/HANDOFF.md`. Report: FAIL when a form appears without the annotation.
11. **No executable target.** `models/models/<X>/CMakeLists.txt` must not call `add_executable` (run executables live on the `archs/` side; this stage is model-side only). How: `grep -n 'add_executable' <X>/CMakeLists.txt`. Report: FAIL naming the target.

## Notes

- Stage parameterization: in a workload round, `MODEL_LAYOUT` / `_MODELS` / `archs/buckyball/**` are **zero-diff** (item 1); their consistency is a bind-round concern and belongs to that round's review.
- All facts outside the diff are verified read-only; when a fact cannot be established (submodule not checked out, CI capture missing), report 需人工裁决 with what you could and could not see.
