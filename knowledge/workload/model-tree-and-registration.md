---
stage: workload
tags: [e2e, models, cmake, registration, recipe]
updated: 2026-09-08
---

# e2e 模型目录结构与注册点现查

## 这是什么

buckyball 的 ModelTest e2e 把每个模型放在
`bb-tests/workloads/src/ModelTest/e2e/models/models/<X>/` 下，新 workload 必须：
新建该目录 + 在两处 CMake 文件里登记它。本文件给出现查配方，不抄现值
（目录清单、旗标拼写、注册写法都会随上游变动；「截至某日有 N 个」这类统计
请一律用配方现查）。

## 不变量 / 契约

- 模型目录固定挂在 `e2e/models/models/` 下；`e2e/models/` 下还有 `archs/`（chip 绑定，bind 轮才动）。
- 两处注册点：
  1. `e2e/models/CMakeLists.txt` 的 **MODEL reset 列表**（`foreach(model_flag IN ITEMS ...)` 块，先全部 OFF 再按 `MODEL` 变量逐个 ON）。
  2. `e2e/models/models/CMakeLists.txt` 的 **`set(MODEL_<FLAG>_DIR ...)` + `if(MODEL_<FLAG>)` 守卫包住 `add_subdirectory(<X>)`**。
- 模型旗标不总是裸大写目录名：目录 `MiniMaxH3FL2VA` 的旗标是 `MINIMAX_H3_FL2VA`（`set` 行、reset 列表、守卫三处一致）。判定标志形态请现查，别从目录名推。
- 模型目录的 `CMakeLists.txt` 不产可执行文件；`*-run` target 在 `archs/` 侧，属 bind 轮。

## 活仓库现查

`$BB` = buckyball 仓根。一段路径写全：
`$BB/bb-tests/workloads/src/ModelTest/e2e/models`（下文简写 `$M`）。

- 现有模型目录清单：

  ```bash
  ls $BB/bb-tests/workloads/src/ModelTest/e2e/models/models/
  ```

- 每个模型目录的字面形态（看有没有 importer / driver / specs/ / runner 插件）：

  ```bash
  for d in $BB/bb-tests/workloads/src/ModelTest/e2e/models/models/*/; do
    echo "== $(basename "$d"): $(ls "$d" | tr '\n' ' ')"
  done
  ```

- reset 列表当前写法与旗标：

  ```bash
  grep -n 'foreach(model_flag IN ITEMS' -A 30 \
    $BB/bb-tests/workloads/src/ModelTest/e2e/models/CMakeLists.txt
  ```

- `models/models/CMakeLists.txt` 里某模型的登记三行（旗标拼写以现查为准）：

  ```bash
  grep -nE 'MODEL_<FLAG>_DIR|if *\(MODEL_<FLAG>\)|add_subdirectory\(<X>\)' \
    $BB/bb-tests/workloads/src/ModelTest/e2e/models/models/CMakeLists.txt
  ```

- 全部 `set(MODEL_*_DIR ...)` 行（拿旗标对照表）：

  ```bash
  grep -n 'set(MODEL_[A-Z0-9_]*_DIR' \
    $BB/bb-tests/workloads/src/ModelTest/e2e/models/models/CMakeLists.txt
  ```

- 全树 `add_subdirectory` 调用（确认某目录被登记过）：

  ```bash
  grep -rn 'add_subdirectory(' $BB/bb-tests/workloads/src/ModelTest/e2e/models/models/CMakeLists.txt
  ```
