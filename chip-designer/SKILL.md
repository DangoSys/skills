---
name: chip-designer
description: "Lead creation of a new Buckyball chip: choose topology and core composition, define inter-core contracts, create the chip configuration skeleton, and sequence integration. Use when creating or leading a chip rather than implementing one Ball or core. Build and simulation use project MCP tools only."
---

# Chip Design

Own chip topology and integration boundaries. Do not take ownership of a core's Ball ISA, RTL, compiler, or emulator unless the user explicitly expands the scope. Default to leaving `arch/src/main/scala/framework/` unchanged; framework gaps belong to mainline work.

## Design Flow

1. Explain why an existing chip does not fit the workload. Identify independent compute stages, data exchanged between them, and their relative latency.
2. Choose topology before implementation. Prefer a small number of core types; choose replica counts from measured or estimated stage latency. Define SharedMem regions, shape/dtype/layout contracts, ownership, and mismatch behavior. Invalid shape or layout must fail explicitly.
3. Create the configuration skeleton using existing chips as templates:
   - `examples/chips/<chip>/configs/chip.toml` selects `designs/*.toml` and simulation configs;
   - `configs/designs/*.toml` declares tiles;
   - `configs/designs/tiles/*.toml` declares `sharedMem` and `[[cores]]` entries that include `examples/cores/<core>/configs/default.toml`;
   - `arch/src/main/scala/CustomConfigs.scala`, `sims/verilator/TargetConfigs.scala`, and `sims/p2e/TargetConfigs.scala` define target configs;
   - add chip `emu/`, `workloads/`, and regression TOMLs only when their consumers exist.
4. Give each core owner a brief containing its mission, fixed inter-core contract, acceptance tests, and non-goals. Do not delegate topology or contract decisions as an open-ended task.
5. Integrate in order: core/slice unit test, pairwise SharedMem test, then end-to-end workload. Add a regression entry only for a supported binary; exclude an unsupported binary from a batch list without deleting its CMake target.

## Existing References

- `examples/chips/poly/`: heterogeneous prefill/decode cores with SharedMem and chip-level emulation.
- `examples/chips/goban/`: multi-core chip configuration and emulation.
- `examples/chips/toy/`: minimal virtual single-core chip layout.

## Constraints

- Do not add a private model partitioning flow unless the repository contains and documents the required tooling.
- Do not silently resize, truncate, or default mismatched inter-core data.
- Do not edit Ball registration and Ball implementation in the same change unless the user explicitly requests the coupled change.
- Invoke build, workload, simulation, and synthesis through `bbdev_*` MCP tools; poll each returned `trace_id` to a terminal successful result before advancing.
