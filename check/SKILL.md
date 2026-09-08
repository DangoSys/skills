---
name: check
description: Validate Buckyball Ball registration consistency. Use when users ask to inspect registration status, validate a BallDomain configuration, troubleshoot registration issues, or check a registration change.
---

# Registration Check

Call MCP tool `validate(chip=..., balldomain?=...)`. Default `chip` is `toy`.

The tool resolves the selected BallDomain from the chip's generated topology. Registrations live under `examples/cores/<core>/configs/balldomains/`, not under the chip directory. The current implementation requires the chip to resolve to one unique topology core; for heterogeneous chips, validate each core's BallDomain explicitly. Pass a stem such as `default` or a `.toml` path only when selecting a non-default domain.

Report the tool's pass/fail result for:

1. `ballNum` equals `ballIdMappings` length.
2. `ballId` is exactly `0, 1, 2, ...` with no duplicates or gaps.
3. `ballName`, `funct7`, and mnemonic are unique within this BallDomain.
4. Each ISA `bid` exists and every Ball has at least one ISA entry.
5. Each Ball config path exists and `inBW`/`outBW` are positive.

Expand each Ball's nested `isa` entries into a summary table with `ballId`, `ballName`, `funct7`, `mnemonic`, `inBW`, `outBW`, and `config`.

`validate` does not scan source headers or MLIR for hardcoded encodings. When that check is needed, inspect the relevant Ball/compiler sources separately and report it as a distinct result.

Do not edit registration files during a check. For a deterministic correction, explain the proposed change and request permission before modifying TOML; treat adding an ISA row or renumbering `ballId` as a semantic change, not an automatic fix.
