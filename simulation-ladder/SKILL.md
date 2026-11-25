---
name: simulation-ladder
description: Choose the fastest Buckyball feedback tool and bound every simulation. Use before starting or continuing any BEMU, Verilator, or FPGA/P2E run, when a run exceeds 20 minutes, when BEMU and RTL disagree on timing, or when deciding where to fast-forward to a bug.
---

# Simulation Ladder

Use the fastest tool that can answer the question. Iterate on the faster level and
use the slower level only to confirm the result.

| Level | Job | Not its job |
|---|---|---|
| GPU, BEMU | Fast-forward to a point of interest; iterate many rounds | Final RTL correctness |
| Verilator | Iterate RTL locally and approach the whole by parts; confirm BEMU results | Finding hot spots BEMU could show |
| FPGA/P2E | Confirm correctness on long code; run workloads end to end | Fast-forwarding to locate a bug |

## Limits

- Any simulation past 20 minutes: stop and question why it is worth running.
- Verilator must not exceed 30 minutes. Split the workload or fix the cause.
- BEMU must not fall below 250 MHz, except when the host is overloaded. Check the
  load before blaming BEMU, and measure again on a quiet host.

## Rules

- Iterate on the emulator first. Verilator exists to verify correctness, ideally in
  one round.
- If the emulator cannot show an effect that RTL shows, that is an emulator bug. Fix
  the emulator instead of moving the iteration to Verilator.
- If a Verilator test is too long, cut it into local parts that together approach the
  whole. Do not lengthen the run.
- To reach a bug deep in a workload, fast-forward with GPU or BEMU. Do not use the
  FPGA for this.
- Before a long run, state the question it answers and why no faster level can
  answer it.
