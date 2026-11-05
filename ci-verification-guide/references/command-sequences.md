# Command sequences per stage × phase × layer

The ordered bbdev step list the plan produces for every legal combination, with the note text the
session sees. Batch lanes are pruned on toml existence
(`examples/chips/<chip>/regression/batch/<backend>/workloads-<elf|pk>.toml`); a pruned lane is
reported in `skippedLanes`, never silently dropped.

## No-phase (v1 full-batch baseline)

| stage | steps |
|---|---|
| workload | workload clean → workload build → bemu elf batch |
| ball | workload clean → workload build → bemu elf batch |
| chip | config install → compiler build → workload clean → workload build → bemu elf batch |

`compilerTouched` adds config install → compiler build ahead for the non-chip stages. Declared
`models` append, after the batch step, one `workload --build --model` per model, then one probe pair
per declared probe stem (this leg's instrument is the probe; the evidence line is
`probe-evidence`).

## ball/c-bemu

(compilerTouched → config install → compiler build →) workload build → per stem either a bemu sim or,
when the stem has `probe:`, a probe pair (sim `--pk --itrace --mtrace` + paired analysis).

## ball/rtl

(compilerTouched → config install → compiler build →) verilator clean → verilog → build
(`--jobs 16`) → per stem `bebop-verilator sim --no-wave`; the `perf:` stem adds `--pmctrace`. No
probe steps exist here; a `probe:` declaration in this phase is a manifest PRE-FAIL. Instrument: pmc
(evidence line `pmc-evidence`).

## chip/skeleton

config install → compiler build → workload build → the single smoke stem bemu sim. (Always the
config/compiler pair, regardless of compilerTouched.)

## chip/slices

(compilerTouched → config install → compiler build →) one bemu sim per slice stem, first failure
stops the round.

## chip/integrate

(compilerTouched → config install → compiler build →) per self-run slice stem (present only when the
slices gate requires the round to run the slices sequence itself, stems from the manifest) → bemu elf
batch.

## chip/bind

Per declared model: `workload --build --model` → (kernel-lane models only) `kernel --build --model` →
probe pair. `models` must be non-empty. The kernel half is gated on the kernel lane's `KERNEL_MODELS`
(read at plan time from `$BB/bbdev/api/steps/kernel/01_build_event.step.py`); for a model outside the
set the kernel step is skipped with the reason written into that model's workload step note.
Instrument: probe.

## complete layer extras

On top of the above: bemu pk batch, and (ball/chip stages) the verilator chain:
clean → verilog → build → elf batch. Verilator pk batch is never generated — see the scope ruling in
SKILL.md.

## Lane gating facts (verify against the tree)

```sh
# What the upstream matrix declares per chip
grep -n "chip:" -A 6 $BB/.github/workflows/check.yaml | grep -E "chip:|enable_rushb|run_"
# Which tomls exist for a chip
ls $BB/examples/chips/<chip>/regression/batch/*/workloads-*.toml 2>/dev/null
# The pairs upstream registration would consume
find $BB/examples/chips -path "*/regression/batch/*/workloads-*.toml" | sort
```

The plan prunes on the toml, not on the matrix flags: a lane with no toml cannot run even if the
matrix enables it, and a lane the matrix disables is reported as upstream's registration outside this
surface's space (the pk/verilator case).

## Skipped-probe reporting

A declared probe that produced no sim+analysis pair is reported in `skippedProbes` with its reason
(phase outside the probe whitelist, no-phase round without models, or stem absent from `stems`). The
session restates it and never treats it as run evidence.
