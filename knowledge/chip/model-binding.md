---
stage: chip
tags: [model-binding, MODEL_LAYOUT, _MODELS, archs, layout]
updated: 2026-09-08
---

# 模型绑定四处写集（活仓库现状）

## 这是什么

bind 轮的写集横跨 bbdev 与 e2e 两个子仓 + 父仓一个普通文件，共四处。判据只认
「检出树实物」：`chips_for_model()` 扫描 `archs/buckyball/<chip>/<Layout>/`
目录决定 (chip, model) 是否合法，**除此之外没有任何自动发现**——四处写集少一处
即红。本文记录四处的位置、键名约定与现查配方。

## 不变量 / 契约

- ① bbdev `api/steps/workload/01_build_event.step.py` 的 `MODEL_LAYOUT` dict：
  模型键 → layout 目录名。只认 `MODEL_LAYOUT` 一处（`MODEL_TARGETS` /
  `MODEL_CMAKE` 已不存在）；回归评估侧（`api/steps/regression/scripts/model_layout.py`）
  从这里动态 import 同一份表，单一事实源，不存在两份字面量漂移的面
  （workload 侧才是 `workload --build` 的闸门）。
- ② e2e 子仓 `models/archs/buckyball/<chip>/<Layout>/` 目录：键与 ① 的 layout
  名对应；白名单内 chip 参照 pebble 同名 layout，白名单外参照 poly（Gemma4/Qwen3）
  形态。
- ③ e2e 子仓 `models/archs/buckyball/CMakeLists.txt` 三处条目（按 layout 名大写）：
  `set(BUCKYBALL_<X>_DIR …)`、`BUCKYBALL_ALL_MODELS` 白名单项、`if(MODEL_<X> …)`
  wiring block。白名单缺项 = 传 `-DMODEL_<X>=ON` 直接 FATAL_ERROR；wiring 缺项 =
  layout 不被 add_subdirectory，ninja run 目标不存在。
- ④ 父仓 `bb-tests/workloads/scripts/build.py` 的 `_MODELS` dict：模型键 →
  `(cmake -D 值, ninja run 目标)`。它是父仓跟踪的**普通文件**，不随 gitlink 走；
  缺条目 = workload 步骤 raise unknown workload model。
- bind 轮 `--model <模型键>` 声明行：整行一条、一个模型一行，键 = ①/④ 里的键名；
  `[binding]` 只认这种行，命令序列里带的 `--model` 不算声明。
- 哪些 chip 在**白名单内**（现有 layout 目录的芯片，含绑定向 `chips_for_model`
  可解析的集合）——以活仓库 layout 目录清单为准，见下方配方；**toy / multi-rocket
  零 layout**（给它们做首次绑定 = 上游未覆盖路径，要先过 archs CMakeLists 的两道闸）。

## 活仓库现查

```bash
# ① MODEL_LAYOUT 当前键值（bbdev 子仓；缺子仓时该路径不存在）
sed -n '35,52p' $BB/bbdev/api/steps/workload/01_build_event.step.py

# ② 全部 (chip, layout) 目录现状（谁有 layout、toy 有没有）
find $BB/bb-tests/workloads/src/ModelTest/e2e/models/archs/buckyball \
  -mindepth 2 -maxdepth 2 -type d | sort

# ③ archs CMakeLists 的白名单与 wiring 形态
grep -n 'BUCKYBALL_ALL_MODELS\|if(MODEL_' \
  $BB/bb-tests/workloads/src/ModelTest/e2e/models/archs/buckyball/CMakeLists.txt | head

# ④ 父仓 _MODELS 当前键值
sed -n '11,30p' $BB/bb-tests/workloads/scripts/build.py

# 回归侧的 MODEL_LAYOUT 是 import 来的（验证单源形态，应显示 import 而非字面量表）
grep -n 'MODEL_LAYOUT' $BB/bbdev/api/steps/regression/scripts/model_layout.py | head
```
