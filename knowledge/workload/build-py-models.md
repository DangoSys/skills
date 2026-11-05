---
stage: workload
tags: [build.py, _MODELS, bind, recipe]
updated: 2026-09-08
---

# build.py `_MODELS` 登记表现查

## 这是什么

父仓 `bb-tests/workloads/scripts/build.py` 的开头有一张 `_MODELS` 表：模型键 →
`(cmake 模型名, ninja 可执行 target)`，是 chip 侧模型注册的一源，bind 轮（chip-designer）
才改它。workload 轮对 `build.py` 零 diff。

## 不变量 / 契约

- `_MODELS: dict[str, tuple[str, str]]`：键为小写模型键，值为
  `(cmake_model, ninja_arg)`，例如 `"bertsmall": ("bertsmall", "buddy-buckyball-bertsmall-run")`。
- 键名就是 `MODEL_LAYOUT` / `--model <键>` 声明行用的那个键。
- 这张表属 bind 轮：workload 轮不登记（写进 `_MODELS` 即越界）。
- 出现 `BUCKYBALL_MODEL` 选项 `string(TOUPPER ...)` 之类的调用点见 `_MODELS` 下方
  (`BUILD_AUTO_DETECT` / `MODEL` 参数），键不对时构建直接报错。

## 活仓库现查

- 表整体（含当前键数）：

  ```bash
  grep -n '_MODELS' -A 25 $BB/bb-tests/workloads/scripts/build.py
  ```

- 某模型键是否已登记、对应 cmake 名与 target：

  ```bash
  grep -n '"<模型键>"' $BB/bb-tests/workloads/scripts/build.py
  ```

- 模型键集合（拿 `--model` 合法取值清单；`_MODELS` 的键后跟 `(`，`_RUSHB` 的键后跟 `{`，按此区分）：

  ```bash
  grep -n '_MODELS' -A 25 $BB/bb-tests/workloads/scripts/build.py \
    | grep -oE '"[a-z0-9-]+": \(' | tr -d '": ('
  ```

- 表之外引用 `_MODELS` 的位置（调用语义）：

  ```bash
  grep -n '_MODELS' $BB/bb-tests/workloads/scripts/build.py
  ```
