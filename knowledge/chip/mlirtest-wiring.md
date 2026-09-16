---
stage: chip
tags: [mlirtest, cmake, wiring, mlir_tests]
updated: 2026-09-08
---

# MLIRTest 接线事实

## 这是什么

MLIR 验证面分两处，接线方式不同：**ball 侧**
`examples/balls/<ball>/workloads/mlir_tests/` 由
`buckyball_add_ball_workload_subdirs(mlir_tests)` 织入（registry 加球 = 自动进构建）；
**chip 侧** `examples/chips/<chip>/workloads/mlir_tests/` 由该目录 CMakeLists 自己的
`add_subdirectory` 链接入。两处都靠 `add_buckyball_mlir_test(<name> TARGET <t>)`
宏产二进制；chip 侧还可能有本地 bespoke 生成器（`function(...)` 内在
`BAREMETAL_BIN` 行把名字写死）。

## 不变量 / 契约

- 标准宏命名：`${BUCKYBALL_WORKLOAD_CHIP}-${ARG_TARGET}-mlirtest-${TEST_ID}-baremetal`
  （`TEST_ID` = 源文件名前接 `BUCKYBALL_MLIR_TEST_PREFIX`；linux 后缀同款）。宏要求
  `BUCKYBALL_MLIR_TEST_PREFIX` 已 set、`BUCKYBALL_WORKLOAD_CHIP` 非空，缺一即构建期
  FATAL_ERROR。
- chip 侧只判 **`add_subdirectory` 链真正接入**的组目录：链外的组目录的二进制根本
  不构建，不存在「该列未列」的问题；既不判死也不判 fail。
- 本地 bespoke 生成器：stem 由函数体自己写死，`BUCKYBALL_MLIR_TEST_PREFIX` **不再
  叠加**——叠加会造出实物不存在的名字。
- 结果面：清单该列未列 = 该 stem 构建出来但没人仿真（漏跑）；组目录里没有任何生成器
  调用点名的 `.mlir` = 根本不构建（死源，不是验证面）；有调用但 stem 推不出来的
  （TARGET 是 `${VAR}` 插值、foreach 生成、本地函数体认不出）单独告警，不判死。
- stem 推导的完整方法论（含逐条 grep 步骤）在 skill `chip-design-guide`；
  本文只记接线事实与位置。

## 活仓库现查

```bash
# chip 侧接入链（顶层的 add_subdirectory 连到哪些组）
grep -n 'add_subdirectory' $BB/examples/chips/toy/workloads/mlir_tests/CMakeLists.txt

# chip 侧所有 .mlir 源（按组目录分）
find $BB/examples/chips/toy/workloads/mlir_tests -name '*.mlir' | sort

# 标准宏定义（命名 + 前置要求）
sed -n '16,55p' $BB/bb-tests/workloads/src/MLIRTest/CMakeLists.txt

# chip 侧宏调用与 BUCKYBALL_MLIR_TEST_PREFIX 声明的实际形态（标准派，pebble）
grep -rn 'BUCKYBALL_MLIR_TEST_PREFIX\|add_buckyball_mlir_test' $BB/examples/chips/pebble/workloads/mlir_tests --include=CMakeLists.txt | head

# chip 侧 bespoke 生成器的实际形态（toy：function + 行首调用）
grep -rn 'function(add_\|add_linalg_conv2d_test' $BB/examples/chips/toy/workloads/mlir_tests --include=CMakeLists.txt | head

# ball 侧 mlir_tests（某个 ball 的验证面）
find $BB/examples/balls -path '*/workloads/mlir_tests/*.mlir' | head

# registry 挂 ball → mlir_tests 织入的宏（定义与调用点都在 CMakeLists.txt，不在 *.cmake）
grep -rn 'buckyball_add_ball_workload_subdirs' $BB/bb-tests/workloads --include=CMakeLists.txt --include='*.cmake' | grep -v '/build/' | head
```
