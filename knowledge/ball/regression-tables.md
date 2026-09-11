---
stage: ball
tags: [regression, stem, ctest, mlirtest, target, chip]
updated: 2026-09-08
---

# 回归清单格式与 stem 生成链

## 这是什么

chip 的 bemu 批回归清单登记每个 ball 的 ctest / mlirtest binary stem，是 CI 按名单跑测试的依据；stem 的第二个 token 是编译器 target 名，不是 chip 目录名。新 ball 的每一行登记必须按本条生成链推导。

## 不变量（稳定事实）

- 位置：`examples/chips/<chip>/regression/batch/bemu/workloads-{elf,pk}.toml`，内容为 `[workloads].tests` 的字符串数组；elf 表条目以 `-baremetal` 结尾、pk 表以 `-linux` 结尾。
- ctest stem：`<chip>-<target>-ctest-<stem>-baremetal`（elf）/ `-linux`（pk）；mlirtest stem：`<chip>-<target>-mlirtest-<bank|ball>_<name>-baremetal`。`<stem>` 是 ctest 文件名去 `.c`，`<bank|ball>_<name>` 是 mlir 文件按组前缀推出的 test id。
- **`<target>` = `_target_name(core) = core.role or core.pkg`**（core 的 role，没有 role 就用 core 包名），不是 chip 目录名、不是 design 文件名；toy / pebble 上三者恰巧同值，是巧合不是规则，别拿它推广。
- verilator 列表只放 small tests；bank tests 仅 bemu；`-rushB.toml` 变体表不进两层判定（pk 执行不作验收：非 rushB 的 verilator batch 只跑 elf-tests）。

## 活仓库现查

- 谁带 bemu 批表（注册前先确认目标 chip 有表）：

  ```bash
  find $BB/examples/chips -path '*/regression/batch/bemu/workloads-elf.toml' | sort
  ```

- 现行 stem 与 target token（升序去重，看实物的形）：

  ```bash
  grep -h 'ctest-\|mlirtest-' $BB/examples/chips/pebble/regression/batch/bemu/workloads-elf.toml | sort -u | head
  ```

- target 名推导链（`_target_name` + `profile.name` 匹配）：

  ```bash
  grep -n -A 1 'def _target_name' $BB/compiler/scripts/pb_to_target_registry.py
  ```

- chip 的 design token（audit 判回归用 `[designs] include` 的文件名 stem 推 `<target>`）：

  ```bash
  grep -n -A 2 '\[designs\]' $BB/examples/chips/<chip>/configs/chip.toml
  ```
