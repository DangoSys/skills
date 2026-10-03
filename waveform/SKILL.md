---
name: waveform
description: Analyze Buckyball VCD or FST waveforms with waveform-mcp when waveform analysis is explicitly requested, or when diff and itrace/mtrace leave a specific timing question unresolved. Use debug-verilator or debug-p2e first for failure debugging.
---

# Waveform Analysis

For failure debugging, first follow `$debug-verilator` or `$debug-p2e`: enable
diff on the initial focused run, then inspect itrace/mtrace when it fails.
Waveforms are a last resort for a specific timing question those traces cannot
answer. When the user explicitly requests waveform analysis, perform it directly.

1. Locate a `.vcd` or `.fst` under the simulation log directory and open it with `open_waveform(file_path=...)`.
2. Call `list_signals` before reading a path. Pass `recursive=true` or `recursive=false` explicitly; do not depend on the tool default. Signal hierarchy and Chisel-generated names vary by chip and build.
3. Use `find_conditional_events(waveform_id=..., condition=..., start_time_index?=..., end_time_index?=..., limit?=...)` for handshakes and edges. Use `find_signal_events` with the same time-index parameter names for transitions. Use `read_signal` for exact values and `get_signal_info` for widths.
4. Close the waveform with `close_waveform` when analysis is complete.

## Checks

- Command issue: `cmdReq.valid && cmdReq.ready`.
- Command completion: `cmdResp.valid && cmdResp.ready`.
- SRAM: locate request and response on clock edges; verify `resp.valid` on the next clock cycle after `req.fire`.
- FSM: inspect state-register transitions around the failed transaction.
- Data: read bank request address/data and response data at the relevant clock edges.

Waveform time indices are simulator sample points, not automatically clock-cycle numbers. Find the clock signal and correlate request and response with successive active clock edges; do not assume `time_index + 1` is one cycle.

Use exact paths returned by `list_signals`. Typical hierarchy names such as `TOP`, `bbtile`, `ballDomain`, `bbus`, and `balls_0` are examples only.
