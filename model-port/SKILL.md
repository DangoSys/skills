---
name: model-port
description: Port a new model or model/device adaptation to Buckyball, coordinating reference preparation, device design, integration, regressions, and complete P2E validation.
---

# Model Port

Model/device adaptations are designs within a shared framework. This skill owns the
porting workflow and completion gates. Use [model-optimize](../model-optimize/SKILL.md)
for the required device-design step; keep its layout, bank, and scheduling guidance there.

## Establish the port

Identify the target devices/configurations, checkpoint, input shape and preprocessing,
reference outputs, numerical requirements, and any explicit performance target.
Preserve the original model as the reference before device-specific rewrites. Use the
same prepared checkpoint and input when comparing designs; do not silently retrain
an existing model for a new device adaptation.

Read current working implementations and recipes instead of assuming old README
instructions still describe the repository. Preserve unrelated work and existing models.

- Shared preparation, the model definition, and evaluation:
  `stack/models/models/<model>/`; see [model-recipe](../model-recipe/SKILL.md)
  for the model files, importers and frontend steps.
- Design recipes: `stack/models/archs/buckyball/<design>/<model>/`; reference
  recipes for x86, nv and gemmini: `stack/models/archs/<arch>/<model>/`.
- Design topology/configuration: `examples/designs/<design>/devices/<device>/configs/`.
- Operator implementations: `examples/prefab/balls/` and `examples/prefab/threads/`.

## Workflow and gates

1. Prepare the shared model, input, and reference. Add the device recipe using the
   current framework's build, package, and execution interfaces.
2. **Apply $model-optimize to design each device recipe.** Record the chosen numerical
   and execution contract. Verify model rewrites against the original reference.
   Optimization beyond this design step follows the user's declared scope/target.
3. Build through `bbdev_model_build(device, model)`. Use `$debug-compiler` for import
   or lowering failures; a successful build is not an execution result.
4. Run the full model through `bbdev_bemu_sim(device, model)` and compare numerical
   outputs. Use `$debug-bemu` for mismatches. Add independent small cases for changed
   semantics using `$workload-tests`; use `$ball-align` when a Ball contract spans layers.
5. Run focused small Verilator cases with diff enabled on the first run and waveform
   capture off. Follow `$debug-verilator` on failure. Full models and large BankOps
   belong on BEMU/P2E. Re-run affected existing operator/model cases and every
   explicitly required configuration; state actual regression coverage.
6. Build the native Linux image through `bbdev_kernel_build(device, model)` with hart
   counts matching the device. Validate Linux execution when available; use
   `$debug-bemu` for Linux DMA residency faults and `$debug-p2e` for boot/runtime issues.
7. Export RTL and build a matching P2E bitstream/runtime case. Use `$debug-p2e` for
   artifact identity, workload-to-hex conversion, logical image names, case reuse,
   resource ownership, and build recovery. Validate focused P2E cases with diff.
8. Run the full model through `bbdev_bebop_p2e_runworkload`, check actual UART and
   exit status, and validate outputs against the declared numerical contract.
   When performance is required, use `$debug-performance` to confirm the target.

The port is complete only after **full-model P2E execution and output validation**
pass for the requested devices/configurations, including required regressions and any
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
