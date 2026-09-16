---
stage: ball
tags: [funct7, isa, encoding, reserved, selection]
updated: 2026-09-08
---

# funct7 编码约束与保留区

## 这是什么

buckyball 的 CUSTOM_3 指令用 7 位 funct7 编码；新 ball 在阶段 0 选码时必须避开框架保留区，并满足 enable 位与读写语义的对应关系。本文是这条约束的不变量与活仓库现查配方（数值不给现值，按配方查）。

## 不变量（稳定事实）

- funct7 是 7 位字段：`[6:4]` = enable 位，`[3:0]` = opcode。enable 图例：`000` none / `001` 1rd / `010` 1wr / `011` 1rd+1wr / `100` 2rd+1wr / `101..111` 保留（扩展 opcode 空间）。
- funct7 不得与**目标 core** balldomain 注册表内已注册的 funct7 重复（一票否决）。cross-core 对同一 mnemonic 的复用合法（占用图会把这种行列入 `conflicts` 的 `mnemonic-collision`）。
- **撞基础 ISA 的拦截时机**：注册表 validate 不查它；是 `bebop-bemu --analysis`（`bemu_analysis.py` 的 ISA 表）抛 `ValueError("ballISA funct7 N (MNEMONIC) collides with ISA <name>")` 才炸——也就是说球能注册、能构建、能跑完仿真，只在取证分析那步死掉。保留区是**选码期**就要避开的，不是等工具报错。
- 基础 ISA 表有名字但无对应数字前缀 `.c` 文件的项不会被占用图认领；选码前必须按配方现查，不能只看 `freeRanges`。

## 活仓库现查

- 基础 mem/frontend 宏前缀（文件名两位数字前缀即 funct7）：

  ```bash
  find $BB/bb-tests/workloads/lib/bbhw/isa -name '[0-9][0-9]_*.c' | sort
  ```

- BALL_INIT（framework 从 `BallISA.scala` 的 `InitFunct` 取值，注册表 ballISA 行撞上它直接被 `BallDomainDecoder.scala` 的 `require` 拒绝）：

  ```bash
  grep -n 'InitFunct' $BB/arch/src/main/scala/framework/balldomain/isa/BallISA.scala
  grep -n -A 2 'framework-reserved' $BB/arch/src/main/scala/framework/balldomain/decoder/BallDomainDecoder.scala
  ```

- analysis 侧 ISA 表（有名字但可能没有对应 `.c` 文件的条目，撞它的球在 `--analysis` 期才死）：

  ```bash
  grep -n -A 9 '^ISA = {' $BB/bbdev/api/steps/bebop/bemu/scripts/bemu_analysis.py
  ```

- 已认领 / 冲突概览：调 `buckyball_isa_occupancy`（`freeRanges` 只表示「未被认领」，不含上表两处框架值）。
