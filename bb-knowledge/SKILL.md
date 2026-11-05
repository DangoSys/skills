---
name: bb-knowledge
description: "Knowledge base for the buckyball repository workflow: stage-grouped markdown files (chip/ball/workload/verify/shared) stating repository invariants plus live-repo lookup recipes for current values. Use when a task needs buckyball repository facts, reference examples, or current schemas — ball/funct7 counts, TOML schema keys, regression manifests, check.yaml structure, probe evidence grammar, registration write sets — or when any claimed repository fact must be re-derived from the live checkout."
---

# Buckyball knowledge base

One lookup point for buckyball workflow knowledge. Every KB file carries two things: the
invariant (what does not move) and the recipes (how to re-derive what does). State invariants
freely; never state a current value without running a recipe against the live checkout. The
stage guides (`chip-design-guide`, `ball-design-guide`, `workload-integration-guide`,
`ci-verification-guide`) carry methodology and point here for repository facts.

## Where it lives

`../knowledge/` — relative to this file. The KB sits inside the skills root
(`$BB/.agents/skills/knowledge/` in the final layout, `out/skills/knowledge/` in staging),
one level up from this skill, so the same relative path holds in both. File layout:
`INDEX.md` (the map) plus `chip/ ball/ workload/ verify/ shared/` topic files. Each file has
`stage` and `tags` in frontmatter and a 活仓库现查 section whose commands use `$BB` for the
buckyball repo root (`$DSH_PLUGIN` for the dsh-plugin repo root, where a command needs it).

## Lookup

1. Read `../knowledge/INDEX.md` first — topics grouped by stage, one line each with tags.
   Jump straight to the file from there.
2. Or grep instead of browsing:
   - by frontmatter stage: `grep -l 'stage: chip' ../knowledge -r` (swap in the stage)
   - by body keyword: `grep -rln 'funct7\|MODEL_LAYOUT\|check.yaml' ../knowledge`
3. Open the file, read the invariant section, then run each recipe in 活仓库现查 against the
   live repository before quoting any value. Recipes are verbatim commands; the repository
   root is `$BB`.
4. No matching topic: grep the live repository directly. Canonical starting points:
   - enumerate examples: `ls $BB/examples/chips $BB/examples/balls $BB/examples/cores`
   - check.yaml structure: `sed -n '/^  chip-check:/,$p' $BB/.github/workflows/check.yaml`
   - bbdev source symbols: `grep -rn '<symbol>' $BB/bbdev/api/steps --include='*.py'`

## Rules

- Repository facts are never quoted from memory — invariants yes, values only after a recipe
  run. If a recipe cannot be run (checkout missing, submodule unaligned), say exactly what
  you could not verify instead of filling it in.
- One topic lives in exactly one file; other files refer to it (见 xxx.md) instead of
  repeating it. Prefer the narrowest file for the question at hand.
- A recipe that fails against the live tree (file moved, symbol renamed) is KB drift. Record
  the drift; do not silently substitute a remembered value.
- Current-value assertions like "as of today there are N" do not belong in KB files. Read
  what the recipe returns, not what a neighboring file says.
