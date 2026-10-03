# skills

Skills help you develop with [buckyball](https://github.com/DangoSys/buckyball).
They follow the [Agent Skills Standard](https://agentskills.io/specification).

## Install

```bash
npx skills add DangoSys/skills
```

## Skills

| Skill | Use |
|-------|-----|
| `ball-align` | Align a Ball across ctest / bemu / compiler / MLIR / RTL / UVM to one contract |
| `chip-designer` | Lead a new chip: topology, subgraph cut, contracts; do not implement cores |
| `ip-designer` | Develop reusable IP: Chisel hierarchy, shared parameters, top export, UVM reuse, and coverage closure |
| `check` | Ball registration consistency check |
| `model-port` | Coordinate model integration, regressions, and complete P2E validation |
| `model-optimize` | Design chip-specific layouts, bank reuse, quantization, and scheduling |
| `debug-compiler` | Model import, layouts, MLIR/bank lowering, and compiler failures |
| `debug-bemu` | Emulator/model correctness against a declared reference |
| `debug-verilator` | Small RTL failures: diff first, then itrace/mtrace |
| `debug-p2e` | P2E build, runtime, boot, and hardware workload failures |
| `debug-performance` | FPGA end-to-end cycles, long operations, bank reuse, and bottlenecks |
| `waveform` | Waveform analysis via `waveform-mcp` |
| `repo-install` | Repository setup with network/proxy handling |
| `programming-principles` | Practical principles for implementation and review |
