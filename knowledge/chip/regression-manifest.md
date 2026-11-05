---
stage: chip
tags: [regression, batch, manifest, stem, exclude]
updated: 2026-09-08
---

# regression batch 清单（stem 命名规则见 ../ball/regression-tables.md）

## 这是什么

chip 的回归验证面由 `regression/batch/<lane>/workloads-<variant>.toml` 清单驱动：
`[workloads] search_path` 指定二进制相对根，`tests` 数组列出实际会仿真的 stem
列表。lane = bemu / verilator / p2e，variant = elf / pk（另见 `-rushB`、
`-diff` 等，是否造由 chip 特性决定）。**chip 根本没有 `regression/` 目录 = 上游
没注册这条 lane**——这是「未注册」与「注册了但漏跑」的分界，两侧不能混为一谈。

## 不变量 / 契约

- ctest / mlirtest 的 stem 命名规则（含 `<target>` = `_target_name(core)` 推导、
  产物后缀约定）见 [../ball/regression-tables.md](../ball/regression-tables.md)
  ——单一事实源在那里，本文件不复制。
- 清单里列了但 CMake 没有 = 陈旧；CMake 有但清单没有 = 漏跑（该 stem 构建出来但
  没人仿真）。两条方向都要人工核对。
- `exclude:` 行只出现在 **PR 证据清单**里（`exclude: <stem> — <理由>`，理由非空才
  接受），batch TOML 本身不含排除语义——批清单不跑的做法是「不列进 tests」。
- 现有 chip 的常驻排除（如某些 bank matadd / conv2d stem 带家族裁决理由）随 PR
  证据清单走，不在树里；要引用它们就用检索配方找当时该 chip 清单与 manifest。

## 活仓库现查

```bash
# 某 chip 全部 lane × variant 清单文件
find $BB/examples/chips/toy/regression/batch -name 'workloads-*.toml' | sort

# 全部 chip 的 regression 目录存在性（缺目录 = 该 lane 未注册）
find $BB/examples/chips -maxdepth 2 -name regression -type d

# 某清单的 search_path 与 ctest stem 样例
sed -n '1,20p' $BB/examples/chips/pebble/regression/batch/bemu/workloads-elf.toml

# 某清单里 mlirtest 条目（空则 = 该 chip 清单一侧 mlirtest 零登记）
grep 'mlirtest' $BB/examples/chips/pebble/regression/batch/bemu/workloads-elf.toml | head

# stem 命名规则的实物出处（CMake 宏怎么拼名字）
grep -n 'BUCKYBALL_WORKLOAD_CHIP}\|mlirtest' $BB/bb-tests/workloads/src/MLIRTest/CMakeLists.txt | head

# ctest stem 出处（add_buckyball_ctests 宏与 BUCKYBALL_CTEST_TARGET 的约定）
sed -n '40,90p' $BB/bb-tests/workloads/src/CTest/CMakeLists.txt
grep -n 'BUCKYBALL_CTEST_TARGET' $BB/examples/chips/toy/workloads/CMakeLists.txt
```
