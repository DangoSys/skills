# skills

Agent skills for developing with [buckyball](https://github.com/DangoSys/buckyball).
They follow the [Agent Skills Standard](https://agentskills.io/specification).

These skills assume a buckyball checkout (MCP `buckyball-dev`, `examples/balls/`, chip TOMLs).
They are not a standalone language pack.

## Install

```bash
npx skills add DangoSys/skills
```

This copies the skills into `.agents/skills/` (Cursor / Codex discover that path).
Update later with `npx skills update`.

Install one skill:

```bash
npx skills add DangoSys/skills --skill ball-align
```

The buckyball repo itself vendors this tree as a git submodule at `.agents/skills/`.
Use `npx skills add` in other DangoSys checkouts that should share the same workflows.

## Skills

| Skill | Use |
|-------|-----|
| `ball-align` | Align a Ball across ctest / bemu / compiler / MLIR / RTL / UVM to one contract |
| `chip-designer` | Lead a new chip: topology, subgraph cut, contracts; do not implement cores |
| `check` | Ball registration consistency check |
| `verify` | Ball functional verification (build → sim → PMC) |
| `waveform` | Waveform analysis via `waveform-mcp` |
