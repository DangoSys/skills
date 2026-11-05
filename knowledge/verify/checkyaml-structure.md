---
stage: verify
tags: [buckyball, check.yaml, ci, 检索配方]
updated: 2026-09-08
---

# check.yaml 的 job/stage 结构（现查配方）

## 这是什么

buckyball 上游 CI 主工作流 `.github/workflows/check.yaml`（$BB 活树）的结构速览与现查配方。
verify-runner 的命令序列以其中的 chip-check job 为参照（见 plan-mapping.md），prompt/skill 里
引用 check.yaml 时只准用文件名/job 名这类稳定锚点，行号与 pin 一律现查。

## 结构不变量（稳定事实）

- 触发器：push/pull_request 到 main；权限 contents: read + checks: write；concurrency 组
  `buckyball-ci-check`。
- job：`pre-commit`（runs-on: check）与 `chip-check`（矩阵 job，name = `${{ matrix.chip }}`，
  needs: pre-commit，runs-on: check）。
- chip-check 用 `strategy.matrix.include` 展开 5 个 chip（toy / pebble / goban / poly /
  multi-rocket），每个条目带 4 个布尔开关：`enable_rushb`、`run_bemu_elf_tests`、
  `run_bemu_pk_tests`、`run_verilator_batch_tests`。
- 各泳道步骤（非 rushB）：
  - Build compiler and workloads：`bbdev config --install` → `compiler --build` →
    `workload --clean` → `workload --build`（都是 `'--chip ${{ matrix.chip }}'`）。
  - bemu ELF batch / bemu PK batch：各由对应 `run_*` 开关门控，
    `bebop-bemu --batch '--chip … --test elf|pk-tests --clean-before'`。
  - verilator batch：由 `run_verilator_batch_tests` 门控，clean → verilog → build（`--jobs 16`）→
    batch elf-tests。
  - rushB batch：四开关全真才跑，且只在此段出现 verilator pk-tests。
- 每个步骤都过 `ci_repo_lock.sh enter` 的仓库锁；junit 检测步骤的 glob 是
  `bebop/target/${{ matrix.chip }}/nextest/junit-bbdev-*.xml`。

## 活仓库现查

```sh
# chip-check job 全貌（矩阵 + 步骤）
sed -n '/^  chip-check:/,$p' $BB/.github/workflows/check.yaml

# 某 chip 的矩阵开关（上例第一个条目）
sed -n '/chip-check:/,/^    env:/p' $BB/.github/workflows/check.yaml

# verilator pk-tests 只出现在 rushB 段的证据
grep -n "pk-tests" $BB/.github/workflows/check.yaml

# 仓库锁脚本的实际调用
grep -n "ci_repo_lock" $BB/.github/workflows/check.yaml
```

注：清单里「toy/pebble enable_rushb=true、goban/poly 全关、multi-rocket 只开
run_verilator_batch_tests」这类具体值属于上游数据，会随上游变更，需要时用上面的配方现查，
不要当作不变量写进文档。
