# Reading a verification report: log layers and failure patterns

The report's carrier (PASS → PR review comment, FAIL → PR comment), its section structure and the attribution tree ("did bemu pass?") live in the design contract's report-reading rules. This file is the RTL-side debugging detail: the five log layers and the seven failure patterns.

## The five log layers (RTL lane only)

Trace layers are written by the RTL-side DPI and only appear in verilator/bebop runs — bemu has none of them:

1. `bbdev/server.log` — build and compile errors first;
2. `stdout.log` — PASSED/FAILED output, panics;
3. `disasm.log` — the custom3 instruction stream: check the `mvin → op → mvout → fence` order;
4. `$BB/log/<timestamp>-*/bdb.ndjson` — trace lines by type:
   - `{"type":"itrace"}` — clk / event / rob_id / funct / bank_enable / pc / rs1 / rs2;
   - `{"type":"mtrace"}` / `{"type":"mtrace_issue"}` — bank addresses and data;
   - `{"type":"pmctrace"}` — elapsed, the RTL-side real-time counter (the only value that can falsify emu `latency`);
5. waveform.

## The seven failure patterns

Work through them in order, against the log layers:

1. **Ball never responds** — `itrace` shows ISSUE but no COMPLETE for the op. Look for a stuck FSM state or a never-fired response; check `status.idle/running` mapping first.
2. **All-zero output** — data comes back but every element is 0. Distinguish from (3) by checking whether the value is written at all; likely the `mvin`/`mvout` addressing, the row width (16B vs 64B), or a zero-filled accumulation.
3. **Output unchanged** — mvout delivers the input unchanged. The op's read of bank data never happened (SRAM handshake), or the compute wrote to the wrong bank.
4. **Partial data wrong** — a slice of elements is off. Tracking iter / stride / boundaries: an off-by-one in the loop bounds, the stride, or the bank row mapping.
5. **SRAM 1-cycle timing** — data wrong by exactly one row/line. `resp.valid` timing: read data on the next cycle after `req.fire`, never same-cycle.
6. **bank_id conflict** — two requests address the same bank, or an op overlaps its own read/write bank. Block same-bank read/write pair in the wrapper; same-bank conflicting ops must be rejected or serialized.
7. **rob_id not latched** — completion goes to the wrong rob_id. `cmdReq.fire` must latch every field including rob_id; a `fire`-guarded pass-through loses it.

After identifying the layer and pattern, fix the owning layer only: bemu golden-model problems are never fixed in RTL (gold = ctest semantics), and a `latency` estimate is never patched to match RTL measurements — a mismatch at an order of magnitude is reported as a residual risk instead.
