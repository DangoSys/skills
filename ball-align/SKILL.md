---
name: ball-align
description: Align a Buckyball Ball's C tests, BEMU behavior, compiler lowering, MLIR tests, RTL, and UVM to one explicit contract. Use when a Ball semantic change spans layers, BEMU and RTL disagree, ISA fields are renamed, or tests must be synchronized after a contract change.
---

# Ball Alignment

Treat the documented C test semantics as the functional reference. Keep BEMU, compiler lowering, MLIR, RTL, and UVM consistent with the same explicit contract.

## Contract First

Before editing, identify:

1. ISA fields and their source of truth.
2. Element width, address calculation, and per-iteration read/write footprint.
3. Valid inputs, invalid inputs, and the required failure behavior.
4. Output layout, including packing and zero-fill behavior.
5. Every affected consumer: ISA macro, emulator, compiler lowering, MLIR test, C test, RTL, UVM, and regression list.

Do not leave a field with multiple meanings or preserve a compatibility fallback that hides an invalid input. Derive address and capacity limits from the active configuration and bank row width.

## Align and Verify

1. Use `$check` to validate the selected registration before and after registration work.
2. Compare expected output and rejection behavior at every changed layer. Search source separately for encoding literals; `validate` checks TOML only.
3. Keep compiler stages distinct: Bank operation, physical-bank assignment, Ball operation, then instruction lowering.
4. Add or update focused C/MLIR/UVM cases in the layer that owns the contract. Place Ball-local tests under `examples/balls/<ball>/workloads/`; add supported workloads to the target chip's regression TOML.
5. Use `$verify` for the BEMU then RTL verification sequence. Use `$waveform` only when timing evidence is required.

## RTL Checks

- Capture command fields on `cmdReq.fire`.
- Respect one-cycle SRAM read latency from request handshake to response.
- Keep `status.idle` and `status.running` consistent with the state machine.
- Use explicit Chisel widths and prevent in-place writes that can overwrite unread source data.

## Delivery

Report the contract, changed layers, focused test evidence, and remaining unsupported coverage. Build and simulation use project `bbdev_*` MCP tools only; poll submitted tasks to terminal success.
