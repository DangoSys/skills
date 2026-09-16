---
stage: verify
tags: [buckyball, bbdev-plan, check.yaml, 检索配方, 决策日志]
updated: 2026-09-08
---

# bbdev-plan 命令映射与 check.yaml 的对照（检索配方 + 决策记录）

## 这是什么

`buckyball_bbdev_plan` 生成的命令序列与上游 `.github/workflows/check.yaml` 的 chip-check job
之间的对应关系，以及「如何核对这一映射」的检索配方。

## 决策记录（2026-09-08）

**选择：保留静态映射（不 plan 时现读 check.yaml），只删行号注释与 pin；映射核对以检索配方
进知识库。** 理由：

- plan 的 stage×phase×layer 展开（skeleton/slices/integrate/bind、c-bemu/rtl、probe 成对步骤、
  compilerTouched 前置）是分阶段验证契约的构造，不在 check.yaml 里；现读即使可行也只覆盖
  无 phase 基线一条腿，其余仍硬编码——「换源自动跟随」的收益覆盖不了成本。
- chip-check 是 GitHub Actions 矩阵 job：YAML 嵌套 + `${{ matrix.* }}` 插值 + `if:` 条件表达式
  （含四开关合取），要现读就得内置一个 workflow-YAML 解释器（新抽象 + 大段脆弱解析），违背
  KISS 与「不堆 helper」。
- lane 裁剪与 kernel 白名单已经在「从树实读」的路径上：batch 命令按
  `examples/chips/<chip>/regression/batch/<backend>/workloads-<elf|pk>.toml` 的存在性裁剪，
  KERNEL_MODELS 从 `$BB/bbdev` 源码现读（bbdev-plan.ts 的 `readKernelModels`）。这些才是会
  随上游换源漂移的数据。
- 原来「机检对齐」的载体（selftest-tools.mjs 对 check.yaml 字面逐字断言、contract-sync-check.mjs）
  已随基线对齐验证清除，映射的对齐语义降级为「契约 + 检索配方核对」，由人/agent 按需核对。

## 映射不变量（让核对有对象的稳定侧）

- 基础链顺序与 chip-check 非 rushB 链一致：config install → compiler build → workload clean →
  workload build → bemu elf batch；complete 层再叠加 bemu pk 批与 verilator
  clean/verilog/build/elf 批。
- 永不生成 verilator pk 批：上游非 rushB 链只到 elf-tests，pk-tests 只在 rushB 段，本验证面
  两层都不进 rushB 空间（范围裁决，不是 lane 状态声明）。
- batch 泳道按 toml 实物裁剪；跨 chip 串行由 CI 作业级保证（concurrency + flock）。

## 活仓库现查（核对配方）

```sh
# 1) 看 chip-check 的矩阵开关与泳道步骤
sed -n '/^  chip-check:/,$p' $BB/.github/workflows/check.yaml

# 2) 看 plan 的生成代码（bbdev-plan.ts 在 dsh-plugin 仓）
grep -n "buildVerificationPlan\|batch(\|compilerPrerequisite\|modelCoverage" \
  $DSH_PLUGIN/packages/verify-runner/src/tools/bbdev-plan.ts

# 3) 核对某 chip 的 lane toml 实物与 plan 的裁剪口径是否一致
ls $BB/examples/chips/<chip>/regression/batch/*/workloads-*.toml

# 4) 核对 bind 腿的 kernel 白名单入口（plan 实读的文件）
grep -n "KERNEL_MODELS" $BB/bbdev/api/steps/kernel/01_build_event.step.py
```

## 已知镜像与遗留

- `STAGE_PHASES` / `PROBE_PHASES` 在 `src/tools/bbdev-plan.ts` 与 `scripts/manifest.mjs` 各有一份
  字面拷贝（plan 是构建产物，不能 import CI 脚本）。原有两道机检门
  （contract-sync-check.mjs、selftest-deterministic.mjs 的代码常量门）已随改造删除，现为文档化
  镜像：两处常量必须同步改——核对方法 = 逐项对比两处常量字面（或看 selftest 失败时先查这两处）。
- CI 侧 provision 豁免组合表（ci/bb-verify.yml）是 plan 侧 `compilerPrerequisite()` 调用点的
  镜像，唯一事实源是 plan；CI 运行时读不了插件代码，所以保留镜像并已注明（见 ci-workflow.md）。
