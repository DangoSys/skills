---
name: debug-p2e
description: Diagnose Buckyball P2E bitstream/runtime builds, FPGA loading, Linux boot, workload failures, and hardware output differences. Use for P2E execution after emulator and small RTL gates are green.
---

# P2E Debugging

Identify the chip/configuration, RTL revision, diff capability, bitstream, complete
runtime case, logical image, firmware ELF/hex, and FPGA location. Confirm focused
BEMU and Verilator gates before using a full model to investigate operator semantics.

## Locate the red stage

- **Build/environment:** preserve the first Nix/Rust/VVAC/Vivado error. Check source
  inclusion, generated chip artifacts, selected RTL directory, and dependencies.
  Do not classify missing files or tools as accelerator numerical failures.
- **Bitstream/runtime:** bitstream existence alone is insufficient. Verify matching
  `rtcfg`, runtime libraries, and executable from the same case. Use a fresh task
  output directory; never clean another task's case.
  After interruption, check live processes and saved checkpoints before retrying.
  For a stopped case with a routed DCP and bitstream, the explicit
  `--resume-post-route` build option preserves completed synthesis/PNR and reruns
  the SDK's timing collection/runtime-data stages. Do not mark a partial case
  successful or resume over a still-running builder.
  With a validated matching case, explicit `--reuse-runtime` runs its existing
  executable, rtcfg, and libraries without rebuilding. The complete case and diff
capability are checked before queueing. Keep its trace-protocol marker unchanged;
  a legacy blocking case and a nonblocking case have different runtime contracts.
- **Board/loading:** check the selected FPGA and loading/runtime messages. Do not
  reprogram a board known to be running another task; resolve its ownership first.
- **Boot/image:** inspect UART, boot hart count/DTB, image base address, Linux/rootfs,
  input/resource installation, executable ABI, and memory/exit diagnostics.
- **Accelerator:** enable diff on the first focused P2E case with a diff-capable
  bitstream/runtime. On crash, mismatch, or lost progress, inspect diff then
  **itrace and mtrace** at the first failing instruction/bank transaction. Use
  `$debug-bemu` or `$debug-verilator` for the corresponding semantic/timing layer.
- **Model output:** compare UART/tensor outputs to the declared reference. Separate
  preprocessing/layout/quantization defects from Linux/runtime and hardware issues.

Keep waveform capture off initially. Use `$waveform` only after trace evidence leaves
a specific timing/handshake question unresolved and the P2E case supports capture.

Re-run a failure only after a targeted correction. Check small diff cases, the full
model, and an affected existing workload/model. Record terminal return status, UART
results, bitstream/image identity, and the actual comparison performed. Booting or
loading the FPGA is not a successful model port; follow `$model-port` through output
validation. Do not call BEMU measurements P2E timing or claim full-logit equality from
classification agreement alone.

For performance, read FPGA `Cycle count` and layer intervals from the actual UART
and follow `$debug-performance`. Golden-emulator stdout can contain its own cycle
records. Stdout buffering can also place trace lines after the classification;
use their recorded start/end values rather than console arrival order.

When asked for run duration, use the current `p2e_timing.log` and label its values
as host wall-clock time. Distinguish model RUN-to-PASS from boot/setup and total
command time; bitstream builds are a separate operation. Do not use duration as a
substitute for the requested FPGA cycle target.

Prefer project `bbdev_*` MCP tools and poll terminal results. If the user authorizes
CLI fallback for MCP failure, use `nix develop -c bbdev`; inspect current help and
retain logs/exit codes. Do not replace the documented flow with private build scripts.
