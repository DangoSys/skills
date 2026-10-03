---
name: model-port
description: Port a new model or model/chip adaptation to Buckyball, coordinating reference preparation, chip design, integration, regressions, and complete P2E validation.
---

# Model Port

Model/chip adaptations are designs within a shared framework. This skill owns the
porting workflow and completion gates. Use [model-optimize](../model-optimize/SKILL.md)
for the required chip-design step; keep its layout, bank, and scheduling guidance there.

## Establish the port

Identify the target chips/configurations, checkpoint, input shape and preprocessing,
reference outputs, numerical requirements, and any explicit performance target.
Preserve the original model as the reference before chip-specific rewrites. Use the
same prepared checkpoint and input when comparing designs; do not silently retrain
an existing model for a new chip adaptation.

Read current working implementations and recipes instead of assuming old README
instructions still describe the repository. Preserve unrelated work and existing models.

- Shared preparation, packaging, and evaluation: `stack/models/models/<model>/`.
- Chip recipes: `stack/models/archs/buckyball/<chip>/<model>/`; `examples/models/`
  links to this directory.
- Chip topology/configuration: `examples/chips/<chip>/configs/`.
- Operator implementations: `examples/balls/` and `examples/cores/`.

## Workflow and gates

1. Prepare the shared model, input, and reference. Add the chip recipe using the
   current framework's build, package, and execution interfaces.
2. **Apply $model-optimize to design each chip recipe.** Record the chosen numerical
   and execution contract. Verify model rewrites against the original reference.
   Optimization beyond this design step follows the user's declared scope/target.
3. Build through `bbdev_model_build(chip, model)`. Use `$debug-compiler` for import
   or lowering failures; a successful build is not an execution result.
4. Run the full model through `bbdev_bemu_sim(chip, model)` and compare numerical
   outputs. Use `$debug-bemu` for mismatches. Add independent small cases for changed
   semantics using `$workload-tests`; use `$ball-align` when a Ball contract spans layers.
5. Run focused small Verilator cases with diff enabled on the first run and waveform
   capture off. Follow `$debug-verilator` on failure. Full models and large BankOps
   belong on BEMU/P2E. Re-run affected existing operator/model cases and every
   explicitly required configuration; state actual regression coverage.
6. Build the native Linux image through `bbdev_kernel_build(chip, model)` with hart
   counts matching the chip. Validate Linux execution when available; use
   `$debug-bemu` for Linux DMA residency faults and `$debug-p2e` for boot/runtime issues.
7. Export RTL and build a matching P2E bitstream/runtime case. Use `$debug-p2e` for
   artifact identity, workload-to-hex conversion, logical image names, case reuse,
   resource ownership, and build recovery. Validate focused P2E cases with diff.
8. Run the full model through `bbdev_bebop_p2e_runworkload`, check actual UART and
   exit status, and validate outputs against the declared numerical contract.
   When performance is required, use `$debug-performance` to confirm the target.

The port is complete only after **full-model P2E execution and output validation**
pass for the requested chips/configurations, including required regressions and any
performance acceptance criterion. BEMU, boot success, and small RTL gates are
intermediate results. Report an external blocker without claiming completion.

## Tools and delivery

Prefer project `bbdev_*` MCP tools and poll tasks to a terminal result. With
user-authorized fallback for a broken MCP entry, use `nix develop -c bbdev` and
retain commands, logs, and exit status.

Report checkpoint/input, recipes/artifacts, numerical comparisons, matched P2E
bitstream/image/runtime identities, regression coverage, and remaining limitations.
Use FPGA end-to-end model cycles for performance acceptance; use `$debug-p2e` for
requested host run durations. Distinguish model weights, executable/package, firmware,
and bitstream sizes. A single-input check does not establish dataset accuracy, and
Top-5 agreement alone does not establish equality of all logits.
