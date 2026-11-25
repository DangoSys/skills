---
name: device-designer
description: "Lead creation of a new Buckyball design (device): choose topology and hart/thread composition, define inter-hart contracts, create the design skeleton, and sequence integration. Use when creating or leading a design rather than implementing one Ball, thread or hart. Build and simulation use project MCP tools only."
---

# Design (Device) Creation

Own the design's topology and integration boundaries. Do not take ownership of a component's Ball ISA, RTL, compiler or emulator unless the user explicitly expands the scope. Default to leaving `arch/src/main/scala/` unchanged; framework gaps belong to mainline work.

## Design Flow

1. Explain why an existing design does not fit the workload. Identify its stages (for a multi-hart device, the semantic graph classes the frontend cuts the model into), the data exchanged between them, and which run in parallel or in sequence.
2. Choose topology before implementation. Group stages into hart classes by what the hardware must do (not one class per graph class); a hart may bind several graphs; choose replica counts from the parallelism and latency of the stages. Hart classes and counts are configuration and must stay easy to change. Define the inter-hart contracts: which values move between harts, their shape/dtype/layout, ownership, and mismatch behavior; invalid shape or layout fails explicitly.
3. Create the design skeleton under `examples/designs/<design>/`, using existing designs as templates. The root holds only `devices/`, `harts/`, `threads/` and `balls/`, one folder per heterogeneous type, each with its own `arch/ stack/ emu/ configs/ workloads/`; customization is written in each folder, copying identical code is fine:
   - `devices/<device>/configs/design.toml` includes `default.toml` and `sims/default.toml`. Configuration lives only here and in the type folders it includes (IP defaults < design < sim config); every system reads the generated `design.pb`, never the TOML.
   - `devices/<device>/configs/default.toml` lists `ddr`, `clint`, `plic`, `scu` and the `[[harts]]` instances: each includes `harts/<type>/configs/default.toml` (its `component`, `[[threads]]` including `threads/<type>/configs/default.toml`, `[sharedMem]`, `accelerator`) and sets the instance's `hartId`, `nodeId` and cache nodes.
   - `devices/<device>/configs/sims/default.toml` names the device config class (`[targets.device]`). Config TOML Tops sit beside `design.toml` as `devices/<device>/configs/<Design><Name>Config.toml` (named by what they are, e.g. `PolyHart2Config`, never by a tool): `include = "design.toml"`, then the few values they replace. Each device has exactly one `<Design>DefaultConfig.toml`, which every tool (BEMU, Verilator, P2E, DC, tapeout) uses when a command names no `--config`; another config is named with `--config <path relative to examples/designs>`.
   - `devices/<device>/arch/DeviceTop.scala`: the CBus instantiates and connects the configured harts; never instantiate harts one by one in the top. Topology (links, shared memory networks) is written in the code of the layer that owns it, not generated from configuration. `devices/<device>/arch/build.sc` lists every arch directory of the design.
   - `devices/<device>/sims/device/{arch,emu,stack,workloads,regression}`: the device simulation entry (one shared scaffolding for all device configs). Hart and thread entries (`harts/<type>/sims/hart`, `threads/<type>/sims/thread`) run on the framework's virtual SoC (`arch/src/main/scala/hart/sims`), never the design SoC; a Ball entry generates Verilog, runs UVM and evaluates area.
   - `harts/<type>/emu`: one crate per hart type, registered in `HARTS`; Balls register in `BALLS`. Each level builds its own stack project; a hart type builds its own `libhart-compiler.so`.
   - Add workloads and regression TOMLs only when their consumers exist.
4. Components live in `examples/prefab/{harts,threads,balls}` or inside the design when the design owns them. Interfaces: Hart → HLink, Thread → TLink, Ball → BLink. The SharedMem inside a hart is invisible to threads (software and hardware): threads see plain DDR semantics; hart-level and device-level shared memory are separate code bases.
5. Give each component owner a brief with its mission, fixed contracts, acceptance tests and non-goals. Do not delegate topology or contract decisions as an open-ended task.
6. Integrate in order: component unit tests, pairwise inter-hart test, then end-to-end workload. Add a regression entry only for a supported binary.

## Commands

- `nix develop -c bbdev <step> "--config <design>/devices/<device>/configs/<Config>.toml --device <device> …"` from the repo root, or the `bbdev_*` MCP tools; poll each returned `trace_id` to a terminal successful result before advancing. Exactly one of `--device`, `--hart`, `--thread`, `--ball` names the component of the config to simulate; there is no `--design`.
- Every command installs its own `examples/designs/<design>/output/sims/<level>/<name>/<Config>/generated/design.pb`; everything for that selection (RTL, workloads, stack, emu) lives in that directory.

## Existing References

- `examples/designs/poly/`: heterogeneous device — a reduce hart with a direct accelerator plus poly harts with attention/ffn threads; tensor-parallel model partition.
- `examples/designs/goban/`: one hart with matmul threads driven by the kernel.
- `examples/designs/pebble/`, `examples/designs/toy/`: single-hart designs with a direct accelerator.
- `examples/designs/multi-rocket/`: several plain CPU harts.

## Constraints

- Designs never depend on each other; shared code goes to the framework or the component.
- Do not silently resize, truncate, or default mismatched inter-hart data.
- Do not edit Ball registration and Ball implementation in the same change unless the user explicitly requests the coupled change.
