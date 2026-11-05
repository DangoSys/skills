---
stage: chip
tags: [schema, chip.toml, design, tile, core-config, balldomain]
updated: 2026-09-08
---

# chip 配置 TOML schema

## 这是什么

新 chip 的配置面由五类 TOML 组成：chip 清单（chip.toml）、design 文件、tile 文件、
core 聚合配置（default.toml）与 balldomain 注册表。它们按 include 链串起来，是
bbdev config 管线与 chip 构建的输入。本文记录每类的必要键与行规则（不变量），
并给出活仓库里可作为范例的文件位置（现查配方）。

## 不变量 / 契约

- chip.toml：`[designs] include` 必填，值是相对 `configs/` 的设计文件（如
  `designs/toy.toml`）；`[sims]` 表必填，`verilator` 与 `p2e` 两键必为非空字符串
  （值 = Scala 配置类名）——config 管线按键名读取。
- design 文件：`[top] nTiles` 必填；`[[tiles]]` 行（tile_id + include）或
  `[tileTemplate]`（include + count）至少其一；`nTiles` 必须等于 `[[tiles]]` 条数
  或 `[tileTemplate] count` 展开数（管线硬校验）。tile include 相对 design 文件
  所在目录解析。
- tile 文件：`[[cores]]`（core_id + include）或 `[coreTemplate]`（include + count）
  至少其一；core include 相对 tile 文件目录解析，解析后必须落在
  `examples/cores/<pkg>/configs/` 下；`[sharedMem]` 若写则 `enable` 为布尔、
  `entries` 为正整数；`[privateDCache]` 同理可选。
- core 聚合配置 `examples/cores/<core>/configs/default.toml`：五域键
  `balldomain`/`memdomain`/`frontend`/`gpdomain`/`core` 各为一条相对 `configs/`
  的路径（纯 Rocket 核心如 rocket 可以都不写；`memdomain` 缺省时管线默认读
  `memdomains/default.toml`，`balldomain` 同理默认 `balldomains/default.toml`）。
- 注册表 `examples/cores/<core>/configs/balldomains/<name>.toml`：`ballNum` 可选；
  `ballIdMappings` 行（ballId/ballName/ballClass 必填，可选 config/inBW/outBW）
  + `ballISA` 行（mnemonic/funct7 必填，`bid` 必须指向本注册表已注册的 ballId）。
  空注册表（rocket 类）合法。`configs/balldomains/balls/` 下的 TOML 是 per-ball
  变体配置、不是注册表，不列举。
- Scala 侧：`CustomConfigs.scala` 的 `Buckyball<Chip>Config` 需接
  `WithBuckyballTiles("<本 chip 的 configs/generated/chip.pb">)`——chip.pb 是
  `bbdev config --install` 的生成产物、不是手写文件；仿真配置类名
  `Buckyball<Chip>VerilatorConfig` / `P2E<Chip>Config` 跨全部 chip 全局唯一。

## 活仓库现查

```bash
# chip 清单与 design 头
sed -n '1,15p' $BB/examples/chips/toy/configs/chip.toml
sed -n '1,12p' $BB/examples/chips/toy/configs/designs/toy.toml
# tile 文件全貌（[sharedMem] 与 [[cores]] include 的写法）
sed -n '1,40p' $BB/examples/chips/toy/configs/designs/tiles/default.toml
# 某 chip 的多 tile 拓扑族（全部 tile 文件名）
ls $BB/examples/chips/goban/configs/designs/tiles/
# 注册表行规则范例（ballIdMappings / ballISA 的实际写法）
sed -n '1,30p' $BB/examples/cores/toy/configs/balldomains/default.toml
# 某 core 的聚合配置五域引用
sed -n '1,20p' $BB/examples/cores/pebble/configs/default.toml
# 某 chip 的 CustomConfigs.scala（WithBuckyballTiles 写法）
sed -n '1,30p' $BB/examples/chips/toy/arch/src/main/scala/CustomConfigs.scala
```
