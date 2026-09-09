# PR evidence manifest template

Read before writing the evidence list into the PR description (stage 5
delivery / bind round). The machine-checked field 口径 (comment-on-own-line,
whole-line `--model`, probe/perf phase whitelists, non-empty exclude reasons)
is owned by the chip-designer playbook "分阶段交付"; verify-runner's machine
check is the authority. Fill from the template below, delete every optional
line you do not use — a `<…>` placeholder left in is a failure.

```
stage: chip
# phase: skeleton | slices | integrate; bind is the separate multi-submodule PR
phase: skeleton
# round: optional, positive integer, which round
round: 1
# chip: required, the examples/chips/<chip>/ directory name
chip: <chip>
# --model declaration: bind round only, one model per whole line (the key is
# the MODEL_LAYOUT / _MODELS key); [binding] reads ONLY these lines — a --model
# carried in a command is not a declaration
--model <model key>
# probe: optional, one line per stem with minutes; allowed only in no-phase /
# c-bemu / bind rounds; delete when unused
probe: <stem> <minutes>
# perf: optional, a single stem token; pairs per instrumentation (rtl round →
# pmc-evidence from this round's own --pmctrace, c-bemu / no phase → the probe
# evidence of the same stem); forbidden in skeleton / slices / integrate
perf: <stem>
# ball-expect: optional, one line per stem with the uppercase mnemonics it must
# execute (comma-separated); only in rounds that produce probe steps and only
# for a stem that round really runs
ball-expect: <stem> <MNEMONIC>
- 改了哪些文件：逐条路径
- 预期应跑的测试：
  - skeleton 轮：冒烟 ELF stem（该 chip 下已有 ctest）
  - slices 轮：slice ELF stem 序列（按切分顺序）
  - integrate 轮：regression batch 覆盖的 elf-tests
  - bind 轮：模型 run stem 逐模型列出（build.py _MODELS 的 ninja 目标）
# capacity: optional — mandatory when stage-0 capacity evidence was produced;
# one block per core
capacity:
  - core: <core>
    # peakBanks must equal Σ(concurrent×cols) of this block's region rows
    # (excluded regions do not count)
    peakBanks: <Σ(concurrent×cols)>
    regions:
      # exclude sits at the END of the region line as [exclude="<理由>"] — it is
      # a field of the region, NOT the line-leading exclude: keyword (that one
      # serves mlirtest stems). Empty reason = rejected; a block whose regions
      # are ALL excluded judged nothing and fails.
      - <region> elements=<element count> elemBytes=<bytes> cols=<columns> [concurrent=<peak live copies>] [sharedPool=true] [exclude="<reason>"]
# exclude: optional, one line per stem with reason; serves the mlirtest
# coverage lanes only (non-empty reason required)
exclude: <stem> — <reason>
- 骨架自查结论（buckyball_chip_audit 输出摘要；bind 轮附绑定向自查清单，容量轮附 core-capacity-fit 摘要）
```

Notes:

- The whole file is pasted into the PR description body; update the body
  BEFORE pushing each round (CI reads the body at trigger time).
- `- 改了哪些文件` style free-text lines are exempt from the placeholder
  rule; only `probe:` / `perf:` / `ball-expect:` / `--model` declaration lines
  are machine-checked.
- Machine input on the verify side treats values as "to end of line": never
  write an inline `#` comment (`chip: toy  # required` parses as `chip`
  missing). Comments occupy their own lines.
