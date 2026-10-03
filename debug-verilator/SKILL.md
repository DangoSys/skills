---
name: debug-verilator
description: Diagnose Buckyball small-workload RTL failures, hangs, or BEMU/Verilator differences using diff, itrace, and mtrace. Use after the corresponding BEMU contract is green.
---

# Verilator Debugging

Use a small deterministic workload under the intended chip configuration. Confirm
its build and BEMU result before investigating RTL. Follow `$ball-align` for fixes
that span ISA, emulator, compiler, RTL, or UVM.

## First run and failure localization

1. **Enable `diff=true` on the first Verilator run**, normally with `no_wave=true`.
   Build a matching diff-capable simulator. Reuse `*_sim` only when that binary
   represents the current RTL and configuration.
2. If the run crashes, mismatches, or stops making progress, inspect the first diff
   discrepancy and **itrace/mtrace**. If needed, re-run the same small case with
   those trace options enabled. Do not begin by opening a waveform.
3. Align instruction ID, PC/opcode, ROB/sub-ROB tag, bank identity, address/group,
   and command completion. Check the producer's writes, consumer's reads, and
   output packing before forming a timing hypothesis.
4. Use bounded state/handshake diagnostics when traces narrow the failing state
   but omit the needed internal event. Remove temporary diagnostics after the fix.
5. Use `$waveform` **only as a last resort** when diff and execution/memory traces
   cannot resolve the remaining cycle-level handshake question. State that question
   and inspect only its relevant signals/time interval.

Keep the first actionable failing instruction. Input corruption, missing completion,
incorrect accumulation, and a wrong result tag require different fixes; do not patch
unverified guesses. A running process alone does not establish progress, and an MCP
timeout does not prove that compilation stopped. Inspect the owned job and task state
before retrying; avoid overlapping clean/build jobs for one simulator directory.

Keep reference checking small too. Precompute a deterministic mathematical golden
at compile time when possible; a tiny accelerator case can otherwise spend most
of its RTL execution in a large CPU reference loop. Preserve independent reference
semantics when shortening the checker.

Check simulator build identity after another backend builds into the same target
directory. An old marker can coexist with a newly linked executable lacking the
Verilator runner. For loader/GLIBCXX errors, inspect DRAMSim and SDK library paths
before debugging RTL; use the project's simulator-scoped runtime-library selection.

After a targeted fix, repeat the failing case and affected existing small cases with
diff. Run existing UVM coverage after RTL is green. Collect `pmctrace` when hardware
performance evidence is needed and distinguish simulator sample indices from cycles.

Prefer project MCP build/simulation tools, polling trace IDs to terminal results.
With user-authorized fallback for MCP failure, use `nix develop -c bbdev`, inspect
current help, and retain logs/exit status. Do not run a full model in Verilator.
