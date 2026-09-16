---
name: workload-integration-guide
description: "Workload-stage model integration for Buckyball ModelTest e2e: model-directory files, the two CMake registration points, .rax+buddy-cli vs offline run pathways, expected values, environment prerequisites, HANDOFF sections, gitlink delivery. Use when you add, adapt, import, or audit a workload."
---

# Workload integration guide

The workload stage turns a HuggingFace model into
`bb-tests/workloads/src/ModelTest/e2e/models/models/<X>/` plus its two registration
entries. Workflow discipline (stage boundary, step order, manifest fields, ACCEPT
gate) is enforced by the harness plugin's playbook; this skill carries the
knowledge behind it.

Live-tree facts (which models exist, exact CMake flag spellings, .gitignore
conventions, `build.py` registry state) come from the `bb-knowledge` skill's
workload topics — treat anything not re-derived from the tree as stale.

## Deliverable anatomy

Create `<X>/` under `e2e/models/models/` with:

- `import-*.py` — traces the upstream model, exports MLIR plus weight files. A host-CPU JIT check (`--jit-check`-style switch) is a team-added shape, not an upstream one.
- `*-main.cpp` — runs the imported graph and hits a hard-coded expected value, exiting non-zero on mismatch.
- `CMakeLists.txt` — build binding. It must not declare an executable: `*-run` targets live in `archs/` and belong to the later binding stage.
- `.gitignore` — keeps importer artifacts out of git. The parent `models/models/.gitignore` already covers coarse generated paths; per-directory rules cover the rest.
- `HANDOFF.md` — the handoff contract with five fixed sections (names below).
- Optional `README.md` — human-facing usage; follow an existing model's README shape (see `Whisper/README.md`) and keep the expected output visible.

Directory extras: `quant/` and `trace/` are the quantization and cycle-trace stages of the same model — read them, never copy. `specs/`, `*Runner*.cpp`, `codegen/` and `include/` belong to the `.rax` pathway described below.

## Registration

Two files must mention the new model:

1. `e2e/models/CMakeLists.txt` — the MODEL reset list (`foreach(model_flag IN ITEMS ...)` block).
2. `e2e/models/models/CMakeLists.txt` — `set(MODEL_<FLAG>_DIR ...)` plus an `if (MODEL_<FLAG>)` guard wrapping `add_subdirectory(<X>)`.

The flag is not always the bare uppercased directory name (e.g. the directory
`MiniMaxH3FL2VA` registers as `MINIMAX_H3_FL2VA`), so read the existing entries
and derive the flag from them instead of assuming.

## Run pathways

Pick one of the two legitimate host runs per model shape:

- `.rax` + `buddy-cli` (preferred, chip-agnostic host CPU): the directory carries `specs/<name>.json`, a runner plugin (`*Runner.cpp` / `*RunnerPlugin.cpp`) and the codegen hook. Packaging happens in buddy-mlir through `tools/buddy-codegen/build_model.py --spec <spec> --build-dir <build>`, producing a `<model>.rax` that `buddy-cli --model <model>.rax` loads and executes on the host. Record the packaging command and its repository in HANDOFF when you use this path.
- Offline compare: models without a chip-agnostic executable path run the original implementation, or feed the exported weights back into it (`python3 <x>-ppl.py --weights <arg0.data>` style), and compare against the expected value.

Which existing models take which path is a live-tree fact: a model with `specs/`
plus `*Runner*.cpp` is packaged-shaped; a model whose importer only emits MLIR
plus weight files is offline-compare-shaped.

## Environment

Everything runs inside `nix develop` at the buckyball repo root. The shell must
start from the repo root — the `sourceme.sh` presence check fails anywhere else,
and the shellHook assigns `$BB_ROOT` there. Before importing, confirm:

- buddy-mlir is built: `sourceme.sh` injects `PYTHONPATH` and `BUDDY_MLIR_BUILD_DIR`, and `e2e/models/CMakeLists.txt` FATAL_ERRORs when `BUDDY_MLIR_BUILD_DIR` is absent.
- `torch` / `transformers` versions are not pinned anywhere upstream — record the actually used versions in HANDOFF.
- HuggingFace is reachable. If not, set `HF_ENDPOINT` to a mirror; private models need `HF_TOKEN` in the launch environment (the model-info tool reports the 401).

Tokenizer: commit a `vocab.txt` inside the model directory and read it from the
C++ side with `Text<long long, 2>::tokenizeBert(vocabDir, <seq_len>)` (the Bert
driver is the precedent) — no third-party tokenizer.

## Expected value

Primary criterion: a hard-coded discrete expectation with fail-hard — the driver
computes an argmax-class conclusion, compares against a `constexpr` expectation,
and exits non-zero on mismatch. For MLM / generative models without a single
discrete conclusion: the driver prints the argmax landing point and a bundled
offline reference script (e.g. `python3 <x>-ppl.py --weights <arg0.data>`) emits
the reference metric.

Element-wise tolerance comparison is not the workload-stage criterion — it
belongs to the quant/trace compare tools. A tolerance may appear as an auxiliary
gate inside the offline script, never as the conclusion.

Team-added shapes upstream does not have — `--jit-check` switches,
`pytorch-<x>-*.py --check` checkers, `reference/<x>_manifest.json` — must be
labeled in HANDOFF as team-added, not presented as upstream form.

## HANDOFF.md sections

`HANDOFF.md` lives at `<X>/HANDOFF.md`, for reviewers and later stages:

- Artifacts — files this workload produces.
- Canonical Reference — where the expected value comes from (HF weights / original implementation plus the producing command), the expected value itself, and the reproduce command.
- Local Run — device (CPU/GPU), the chosen run command, elapsed time.
- Build Binding — configure/build commands used, if any.
- Known Limitation — known limits and uncovered items.

Every assertion cites a command output or a file path. The expected value must be
literal in the document: a reader never runs anything to know what "correct" is.

## Delivery

Multi-submodule delivery: the write set goes to a feature branch of the e2e
submodule (buddy-examples fork); the parent-repo (buckyball fork) PR carries that
submodule's gitlink — a parent-side pointer to one submodule commit
(`.gitmodules` declares the path's url/branch). Model files only enter the
submodule; the parent-side diff is just the pointer moving.

Parent-side write rules: always carry the e2e gitlink; carry the bbdev gitlink
only when bbdev `MODEL_LAYOUT` changed (not at this stage); `build.py::_MODELS`
entries belong to the binding stage. The branch is based on newest main and
contains only this workload's write set.
