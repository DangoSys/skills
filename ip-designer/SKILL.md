---
name: ip-designer
description: Design, implement, and verify reusable Buckyball hardware IP, including Chisel hierarchy, shared parameters, verification-top RTL export, common UVM components, and coverage closure. Use for IP work such as AXI, Bank, and BankSet; use chip-designer for chip topology and ball-align for Ball semantics across software and hardware.
---

# Buckyball IP Design

Develop an IP as a reusable module with an explicit interface contract and independently verified tops. Use the repository's existing implementation and verification infrastructure. This skill records IP-specific conventions; general coding principles remain in `programming-principles`.

## Establish the Contract

Identify the intended tops and their responsibilities before restructuring existing code. Resolve address units, capacity, masking, response behavior, reset behavior, backpressure, ordering, and required concurrency from the user's requirements and callers. Preserve explicit choices across iterations; an existing implementation is evidence, not the specification.

Distinguish storage organization from access semantics. A scratchpad is not synonymous with a collection of banks. Renaming an existing controller does not establish the intended composition or interface. Do not silently trade parallel access for serialized service: make the outstanding-request and throughput contract explicit.

## Chisel Hierarchy and Parameters

- Follow the neighboring `axis` IP: mark reusable module classes `@instantiable`, expose their IO with `@public`, and instantiate children through `Instantiate(new Child(p))`, with `Instance[Child]` where a type is declared. Classes still extend `Module`.
- A composite IP must instantiate the leaf modules whose behavior it reuses. Do not duplicate their storage or datapath implementation inside the composite.
- For a homogeneous hierarchy, use one shared parameter object and derive widths and capacities from it. Do not introduce per-instance parameter lists for identical children.
- For Bank specifically, retain only `BankSetParams`: both `Bank(p)` and `BankSet(p)` receive it, and all children use the same `p`. Do not recreate `BankParams` or pass depth separately.
- Update actual callers when changing module names, parameter ownership, or instantiation style. Avoid unnecessary hierarchy-name prefixes in IP class names.

## Package and Export

The current IP verification loader resolves `arch/src/main/scala/framework/mem-core/<ip>/`. An IP there owns:

- `build.sc`: independent Mill build and the selected main class.
- `src/main/scala/`: Chisel interfaces, implementation, parameters, and `Emit.scala`.
- `src/csrc/`: Rust reference model and DPI binding, built through Cargo.
- `src/main/resources/`: DUT wiring, IP-specific verification behavior, filelists, and reviewed exclusions.

Keep one `Emit.scala` entrypoint. Export only the agreed verification tops, one SystemVerilog file per top, with required child module definitions in that file. Do not independently emit every internal module, use `--split-verilog`, or add wrappers solely for emission. The emitter directly constructs `new Top(p)`; child instantiation inside a module uses `Instantiate`.

Bank currently has two selected tops: `Bank` and `BankSet`. Other IPs need their own agreed set. Each testbench compiles its top's RTL file independently, avoiding duplicate module definitions from combining self-contained exports. Inspect the actual generated filenames and module hierarchy after changing exports.

## Reuse Verification Infrastructure

Use shared pieces before adding IP-local infrastructure:

- `verify/uvm/src/ip/`: reference-model interface, checked environment, ordered scoreboard, test timeout and completion control.
- `verify/uvm/src/protocol/axis/`: AXI4-Stream interface, items, source agent, monitor, sink backpressure, assertions, and protocol coverage.

Move genuinely reusable protocol behavior into `verify`; keep DUT wiring, interface-specific translation, reference-model semantics, scenarios, and functional coverage points local. Do not force a Bank request interface into AXI merely to reuse a driver. Current shared AXI components parameterize data width and cover TDATA, TKEEP, and TLAST; inspect and extend them when additional protocol fields are required.

Connect observed input handshakes to the reference model and observed outputs to result checking. Keep model semantics independent of RTL scheduling. Define what reset cancels and what memory contents it preserves; do not invent initialized contents for uninitialized memory.

A sequence finishing is not evidence that outputs were checked. Wait for the required comparisons and retain unmatched transactions until they are reported or explicitly cancelled by the reset contract. Fix demonstrated framework defects in the framework and add only the focused regression needed to establish the fix.

Use an explicit testbench drive/sample schedule. Falling-edge stimulus is a scheduling choice, not a DUT requirement. If adopting rising-edge-only operation, use a shared clocking-block or equivalent scheduling contract; never mechanically replace edge names and introduce races.

## Build and Run

Register the IP in `verify/uvm/ip.toml`. Add it to a chip's `[uvm].ips` only when it belongs in that chip's default regression. The current loader discovers resource `*.f` files, uses `<stem>_tb` as each top, and selects `protocol_test`; align the artifacts with these conventions.

Filelists use `@VERIFY@`, `@RESOURCES@`, and `@RTL@`. Use project `bbdev_uvm_build(chip=..., ip=...)` and `bbdev_uvm_run(chip=..., ip=...)` MCP tools and poll returned tasks to completion. Diagnose service failures separately from compile or RTL failures; do not silently substitute a private build flow. For coverage-only changes, reuse the existing simulation database through the repository's reporting implementation when RTL and stimulus are unchanged.

## Close Coverage, Then Stop

1. Establish the exact parameter configuration, DUT instance scope, metrics, and target. For the current Bank workflow, the agreed code metrics are line, condition, and toggle, with a 100% target after justified exclusions. Keep testbench/protocol coverage distinct from DUT code coverage.
2. Check that the report actually contains DUT data. In an unsplit file, a generated SRAM `coverage exclude_file` directive can also exclude its parent DUT. Scope the memory-model exclusion correctly; missing metrics are not a coverage success.
3. Inspect individual holes. Add or adjust stimulus for reachable behavior. Prefer adjusting existing scenarios over adding random iterations. Compare coverage before and after deleting potentially redundant stimulus; keep the deletion only when relevant coverage and checks remain intact.
4. Waive only identified objects with a reason: constants, constraints of the legal-input contract, assertion-failure diagnostics outside the normal functional coverage scope, or conditions proven unreachable by the control structure. Distinguish environmental assumptions from design invariants. Do not waive an item simply because the current test never exercises it, and never exclude logic by generated names such as `_GEN`.
5. For VCS, export candidates with URG `-dump full_exclusions`, then select the reviewed objects into a same-stem resource `.el` file. Preserve the tool-generated instance, metric checksum, object signature, and specific bit range or condition vector. Annotate each exclusion. Do not blanket-exclude an entire signal or expression when only part is justified.
6. Use `bbdev/api/steps/uvm/scripts/uvm_common.py` reporting support. It retains the full report and provides DUT `rtl_raw/` and `rtl/` reports. Validate exclusions against the current tool-exported checksums before applying them; URG may otherwise remap stale entries by signature. Never use `-excl_bypass_checks` to make obsolete waivers apply.
7. Once the agreed coverage target and functional checks pass, stop. Reopen testing for a relevant design change, a demonstrated bug, or a new coverage gap. Do not add cases merely because more cases can be imagined.

Report the tested configuration and scope, functional outcome, raw versus waived coverage, and any remaining gaps. Coverage closure for one configuration does not establish all parameter combinations or performance requirements.
