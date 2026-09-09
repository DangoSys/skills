# 知识库索引

本目录最终落在 `$BB/.agents/skills/knowledge/`（与 skill 同仓）。目录内**永远不要出现
SKILL.md**：skills 根的直属目录一旦带 SKILL.md 就会被 dsh 当成 skill 加载。

buckyball 工作流知识库，按 stage 分目录：`chip/`、`ball/`、`workload/`、`verify/`、
`shared/`。每个文件的结构固定：一段「这是什么」→「不变量 / 契约」
（稳定事实）→「活仓库现查」（检索配方，一条配方一句说明加一条命令）。现值一律按配方
在活树上现查，文件不抄现值；单一事实只写在一个文件里，别处引用只写「见 xxx.md」。

配方命令里的两个路径变量：

- `$BB` = buckyball 仓根（当前 checkout：`/home/ROXY/code/bb_work/buckyball`）
- `$DSH_PLUGIN` = dsh-plugin 仓根（`/home/ROXY/code/bb_work/dsh-plugin`），只在
  verify 几篇涉及 CI 物料时用

## chip（7 个）

- `chip-toml-schema.md` — chip 配置五类 TOML（chip.toml / design / tile / core 聚合配置 /
  balldomain 注册表）的必要键与 include 链规则，Scala 侧 `WithBuckyballTiles` 与仿真
  类名约定。
  tags: schema, chip.toml, design, tile, core-config, balldomain
- `capacity-banks.md` — 单核容量判定的事实源：memdomains `[bank]` 三键几何、行字节与
  池公式、D1–D5 要用到的物理事实；共享池的真相是槽变宽、深度不变。
  tags: capacity, bank, memdomain, sharedMem, D1-D5
- `funct7-reserved.md` — 指针：funct7 两层禁区的事实源在 `ball/funct7-encoding.md`，
  本文件只补 chip 侧工具边界（`funct7Duplicates` 不覆盖基础 ISA 表与框架自留值）。
  tags: funct7, isa, ball-registry, reserved
- `mlirtest-wiring.md` — MLIRTest 两处接线：ball 侧 registry 织入、chip 侧
  `add_subdirectory` 链；标准宏命名与 bespoke 生成器例外。
  tags: mlirtest, cmake, wiring, mlir_tests
- `model-binding.md` — bind 轮四处写集：bbdev `MODEL_LAYOUT`、e2e layout 目录、
  archs CMakeLists 三处条目、父仓 `build.py` `_MODELS`；白名单内/外的芯片各按哪种
  先例抄。
  tags: model-binding, MODEL_LAYOUT, _MODELS, archs, layout
- `regression-manifest.md` — regression 批清单（`batch/<lane>/workloads-<variant>.toml`）
  的结构、`exclude:` 只出现在 PR 证据清单、无 `regression/` 目录 = lane 未注册
  （与漏跑是两回事）；ctest / mlirtest stem 命名链的事实源在
  `ball/regression-tables.md`，本文只留指针。
  tags: regression, batch, manifest, stem, exclude
- `verification-trace.md` — 验证产物落点（`log/<时间戳>-*-bemu-*/bdb.ndjson`）、
  NDJSON 行格式、空 trace 的语义、`span_cycles` 是 latency 累加和这一恒等式。
  tags: verification, trace, ndjson, log

## ball（4 个）

- `balldomain-registry.md` — core 的 balldomain 注册表是 ball 集成的唯一事实源：
  `ballIdMappings` / `ballISA` 双表行规则、`ballNum` 连续无洞等 audit 机检不变量。
  tags: balldomain, registry, toml, registration, core
- `funct7-encoding.md` — funct7 的 7 位字段划分（enable `[6:4]` / opcode `[3:0]`）、
  与基础 ISA 撞值在 `--analysis` 才死、占用图 `freeRanges` 只表示未认领。
  tags: funct7, isa, encoding, reserved, selection
- `intrinsic-enum.md` — LLVM fork 的 intrinsic 枚举是冻结的：唯一合法出口 =
  `CustomIntrOp` + `getBuckyballFunct7`；查枚举前先对齐两级 submodule。
  tags: intrinsic, llvm, fork, enum, compiler, submodule
- `regression-tables.md` — bemu 批清单 stem 生成链，其中 `<target>` = `core.role or
  core.pkg`（不是 chip 目录名）；verilator 只放 small、bank 只走 bemu。
  tags: regression, stem, ctest, mlirtest, target, chip

## workload（3 个）

- `build-py-models.md` — 父仓 `bb-tests/workloads/scripts/build.py` 的 `_MODELS` 表
  （模型键 → cmake 名 + ninja 目标）；这张表属 bind 轮，workload 轮对 `build.py`
  零 diff。
  tags: build.py, _MODELS, bind, recipe
- `gitignore-conventions.md` — e2e 模型树两层 `.gitignore` 的分工（父级盖粗粒度、
  目录自己盖特有产物）；入库期望值不得被任何一层命中；判忽略用 `git check-ignore`。
  tags: e2e, gitignore, recipe
- `model-tree-and-registration.md` — e2e 模型目录固定位置与两处 CMake 登记（MODEL
  reset 列表 + `MODEL_<FLAG>_DIR` / `if(MODEL_<FLAG>)` 守卫）；旗标拼写以现查为准，
  别从目录名推。
  tags: e2e, models, cmake, registration, recipe

## shared（1 个）

- `model-to-ball-pipeline.md` — 模型算子落 ball 的四关 pattern 链（图侧识别 → tile
  op → tile→ball hook → 分片发射器）、ball 交付与模型落 ball 的边界、「6144 是
  bank 行数不是代码行数」与逐关检索配方。
  tags: model-to-ball, pattern-chain, linalg-to-tile, tile-hook, bank-ssa, bind

## verify（4 个）

- `checkyaml-structure.md` — `.github/workflows/check.yaml` 的 job 结构速览
  （pre-commit / chip-check 矩阵、四条泳道与开关、rushB 条件）；引用它只用
  job/步骤/文件名锚，行号与 pin 一律现查。
  tags: buckyball, check.yaml, ci, 检索配方
- `ci-workflow.md` — `ci/bb-verify.yml` 的五段机制：verdict-gate、评论在场门禁、
  只读门禁、provision 豁免、INFRA 回流；含镜像侧（豁免组合表）与 plan 唯一事实源
  的关系。
  tags: buckyball, ci, bb-verify, verdict-gate, INFRA, 检索配方
- `contract-clauses.md` — 契条款规范文本的指针表（分阶段验证 / 分阶段交付 / prompt
  消费条 / 五个判定脚本）；「共 N 条」这类叙述不是数字断言。
  tags: buckyball, 契约, 分阶段验证, 分阶段交付
- `plan-mapping.md` — `bbdev-plan` 命令序列与 check.yaml chip-check 的对照、核对配方，
  以及「映射只以契约 + 配方核对、不做机检」的决策记录。
  tags: buckyball, bbdev-plan, check.yaml, 检索配方, 决策日志
