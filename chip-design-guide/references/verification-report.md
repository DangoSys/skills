# Reading verification reports and the perf iteration contract

Read when a verification round comes back or when you start a performance
optimization round.

## PASS / FAIL loop

- PASS = `gh pr review` approval plus evidence (commands run + results): the
  task wraps up — final summary carries the PR link, the audit result and the
  verification evidence.
- FAIL = a structured report: failed command, log tail, suspected attribution,
  nextest JUnit list. The next round uses those three as the modification
  input — fix what the report points at, push to update the PR, wait for the
  next round. Loop until PASS. Never re-derive the failure from memory; a
  failure's attribution is a hypothesis until the next report confirms it.

## Perf iteration contract (family clause)

Every optimization round writes THREE paragraphs in the PR description:

1. what was changed, based on WHICH hotspot of the last probe round
   (funct + cycle count) — this is the only accepted basis for the change;
2. which metric is expected to improve — and by what reasoning;
3. the verification basis (candidate evidence you expect in the reply).

When the posted analysis is NON-EMPTY (funct cycle share / mean_rows /
bank_depth / matrix-instruction (M,N,K) histogram), those three paragraphs
are mandatory for the next round's PR. When the analysis stream is EMPTY
(host-fallback shape), only annotate "performance instrumentation not
applicable" — write no performance conclusion off an empty stream.

Evidence rules:

- Emu cycle estimates (a ball's own `latency`) reconcile ONLY against RTL
  measured cycles. On the bemu side `span_cycles` IS the sum of those
  `latencies` — comparing `latency` against it is an identity, never a valid
  check; never report it as one.
- Only `--pmctrace` elapsed (the posted `pmc-evidence` line) measures the
  `latency` claim independently; when the estimate deviates from it by more
  than an order of magnitude, report it as a leftover risk.
- An optimization claim WITHOUT a prior probe round is an unproven claim:
  do not assert it as evidence.

Trace facts (raw data behind the summaries): `log/<timestamp>-*-bemu-*/bdb.ndjson`
holds one JSON object per line with a `"type"` field (itrace / mtrace /
pmctrace); there are no `[ITRACE]`/`[MTRACE]` marker lines; a 0-byte file is an
empty event stream, not a format issue. See the bb-knowledge
verification-trace recipe.

## Attribution tree

Ask one question first: did bemu pass?

- bemu passes / RTL fails → RTL side: timing or DPI (waveform skill); a
  cross-layer inconsistency (RTL ↔ bemu ↔ golden) goes to the ball-align skill.
- bemu fails → fix semantics first (golden model / dispatch chain); everything
  on the RTL side is secondary until the semantics pass.

Same order as ball design phase 6: bemu first, RTL second.
