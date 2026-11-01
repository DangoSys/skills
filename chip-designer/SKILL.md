---
name: chip-designer
description: "Lead creation of a new Buckyball design (chip): choose topology and core/thread composition, define inter-core contracts, create the design skeleton, and sequence integration. Use when creating or leading a design rather than implementing one Ball, thread or core. Build and simulation use project MCP tools only."
---

# Design (Chip) Creation

Own the design's topology and integration boundaries. Do not take ownership of a component's Ball ISA, RTL, compiler or emulator unless the user explicitly expands the scope. Default to leaving `arch/src/main/scala/framework/` unchanged; framework gaps belong to mainline work.

## Design Flow

1. Explain why an existing design does not fit the workload. Identify its stages (for a multi-core device, the semantic graph classes the frontend cuts the model into), the data exchanged between them, and which run in parallel or in sequence.
2. Choose topology before implementation. Group stages into core classes by what the hardware must do (not one class per graph class); a core may bind several graphs; choose replica counts from the parallelism and latency of the stages. Core classes and counts are configuration and must stay easy to change. Define the inter-core contracts: which values move between cores, their shape/dtype/layout, ownership, and mismatch behavior; invalid shape or layout fails explicitly.
3. Create the design skeleton under `examples/designs/<design>/`, using existing designs as templates:
   - `configs/design.toml` includes `device/default.toml` and `sims/default.toml`. Configuration lives only here (IP defaults < design < sim config); every system reads the generated `design.pb`, never the TOML.
   - `configs/device/default.toml` lists `ddr`, `clint`, `plic`, `scu` and the `[[cores]]`, each including `cores/<core>/default.toml` with its `component`, `hartId`, `[[threads]]` (each with a `component` and an `include` of the thread's default config), `[sharedMem]` and, for cores with a direct accelerator, `accelerator`.
   - `configs/sims/default.toml` names the device config class (`[targets.device]`) and registers device configs `[targets.device.configs]` as name → override TOML (`<Design>VerilatorConfig`, `<Design>P2EConfig`, …). Commands always name a config.
   - `arch/device/DeviceTop.scala`: the CBus instantiates and connects the configured cores; never instantiate cores one by one in the top. Topology (links, shared memory networks) is written in the code of the layer that owns it, not generated from configuration.
   - `sims/device/{arch,emu,stack,workloads,regression}`: the simulation entry (one shared scaffolding for all device configs).
   - `emu/src/device/core`: the design's emulator models, registered in `CORES`/`BALLS`; `stack/device` (and `stack/device/core` for a design-owned core): the per-level software stacks.
   - Add workloads and regression TOMLs only when their consumers exist.
4. Components live in `examples/prefab/{cores,threads,balls}` or inside the design when the design owns them. Interfaces: Core → CLink, Thread → TLink, Ball → BLink. The SharedMem inside a core is invisible to threads (software and hardware): threads see plain DDR semantics; core-level and device-level shared memory are separate code bases.
5. Give each component owner a brief with its mission, fixed contracts, acceptance tests and non-goals. Do not delegate topology or contract decisions as an open-ended task.
6. Integrate in order: component unit tests, pairwise inter-core test, then end-to-end workload. Add a regression entry only for a supported binary.

## Commands

- `nix develop -c bbdev <step> … --design <design> --device <Config>` from the repo root, or the `bbdev_*` MCP tools; poll each returned `trace_id` to a terminal successful result before advancing.
- `bbdev config --install` writes `examples/designs/<design>/output/sims/device/<Config>/generated/design.pb`; everything for that config (RTL, workloads, stack, emu, logs) lives under `output/sims/device/<Config>/`. Re-run it after any TOML change.

## Existing References

- `examples/designs/poly/`: heterogeneous device — a reduce core with a direct accelerator plus poly cores with attention/ffn threads; tensor-parallel model partition.
- `examples/designs/goban/`: one core with matmul threads driven by the engine.
- `examples/designs/pebble/`, `examples/designs/toy/`: single-core designs with a direct accelerator.
- `examples/designs/multi-rocket/`: several plain CPU cores.

## Constraints

- Designs never depend on each other; shared code goes to the framework or the component.
- Do not silently resize, truncate, or default mismatched inter-core data.
- Do not edit Ball registration and Ball implementation in the same change unless the user explicitly requests the coupled change.
