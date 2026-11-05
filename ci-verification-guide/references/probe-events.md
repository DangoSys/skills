# Probe events, evidence lines and the next-round perf gate

## Evidence line grammar (one line, one instrument, posted in the round's report)

Probe instrument (c-bemu / bind / no-phase with models):

```
probe-evidence: <stem> cycles=<span_cycles>
```

Multi-chip PR (chip-qualified shape):

```
probe-evidence: <chip>/<stem> cycles=<N>
```

Zero-event round (host-fallback shape) — the sentinel. `none` and the parenthesized literal are fixed
strings; do not rewrite as `cycles=0`, do not drop the parenthesis, do not omit the line:

```
probe-evidence: <stem> cycles=none (instrument-not-applicable)
```

PMC instrument (rtl round, the `perf:` stem ran with `--pmctrace`):

```
pmc-evidence: <stem> calls=<n> elapsed_avg=<x> elapsed_max=<y> elapsed_min=<z>
```

Rules:

- A round posts exactly the line for ITS instrument: rtl rounds never post `probe-evidence:` (their
  plan has no probe steps); other phases never post `pmc-evidence:` (they produce no pmctrace).
  A cross-instrument line would forge a comparison baseline.
- Line-decoration tolerance (leading whitespace, `-`/`*` bullets, paired backticks) is tolerated by
  the retrieving side; key names and field order are NOT — `周期数=` or `probe_evidence:` is treated
  as evidence not delivered.
- Any probe-instrument line — numbers line AND the zero-event sentinel — must sit in the SAME report
  as the round's `probe: <stem> <minutes>` declaration line: the next round's perf gate reads
  `prev-budget` only from that same report. Without it the next round always gets `unknown` =
  "budget not comparable". The evidence line itself carries no budget field; if the declaration is
  absent, do not invent one.
- Prose without an evidence line = evidence not delivered (nothing for the next round to compare).

`cycles` is the analysis report's `span_cycles` verbatim. `span_cycles` is printed by
`$BB/bbdev/api/steps/bebop/bemu/scripts/bemu_analysis.py` (symbol-level check:

```sh
grep -n "span_cycles\|no itrace events" $BB/bbdev/api/steps/bebop/bemu/scripts/bemu_analysis.py
```

## NDJSON event shapes

`bdb.ndjson`, one event object per line, immediately flushed:

- `{"type":"itrace", ...}` — every ball-op completion (the only itrace producer). Field set carries the
  per-funct cycle spans summed into `span_cycles`.
- `{"type":"mtrace","event":"read|write", ...}` — mvin/mvout memory traffic; the only mtrace producer.
- `{"type":"pmctrace", ...}` — RTL/verilator sims only, produced by `--pmctrace`; carries `elapsed`
  values aggregated into the pmc-evidence line (calls, avg/max/min).

Zero-event shape: a fully-scalar host-fallback run physically emits no itrace (no ball-op executed).
This is why the zero-byte branch exists at all — check the analyser's throw on zero events:
`grep -n "no itrace events" $BB/bbdev/api/steps/bebop/bemu/scripts/bemu_analysis.py`.

## How the next round's perf gate reads these

The perf gate (`probe-loop-check.mjs` semantics) merges comments ∪ reviews into one timeline (each
side has its own order; the array tail is NOT the PR's time order), takes the latest hit per
(stem, instrument), and returns:

- `instrument` — the phase of the round that owns the line: rtl → pmc, else probe.
- `prev-cycles` / `prev-pmc` / `prev-elapsed-avg` — the corresponding numbers, one side always
  `(无)`-worth null.
- `prev-found` — whether a same-instrument line exists at all.
- `prev-sentinel` — true when the line is the zero-event sentinel literal.
- `prev-budget` — read from the `probe: <stem> <分钟>` declaration in the SAME report as the hit line.
- `baseline` — no previous same-instrument data.

The consuming round then applies the four gates: instrument alignment (no cross-instrument deltas),
delta obligation when prev-found, budget comparability, and the sentinel/baseline two-shape handling.
