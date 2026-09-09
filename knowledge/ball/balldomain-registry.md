---
stage: ball
tags: [balldomain, registry, toml, registration, core]
updated: 2026-09-08
---

# balldomain 注册表

## 这是什么

core 的 balldomain 注册表是 ball 集成的唯一事实源：ball 的行、每行挂的 ISA（mnemonic/funct7）、以及 ball 的 config 文件在此登记。新 ball 的阶段 4 改动就落在这里；注册表也驱动 `ballISA.h` 生成、编译器 target 注册与 bemu 分发链。

## 不变量（稳定事实）

- 位置：`examples/cores/<core>/configs/balldomains/*.toml`（顶层文件即注册表；其下 `balls/` 子目录是 per-ball 配置覆盖，不是注册表）。core 的聚合配置 `configs/default.toml` 用 `balldomain=` 指向唯一注册表——每 core 一份，无变体选择。rocket 类 core 只带空注册表（`ballNum = 0`）。
- 一个 TOML 必须同时带 `ballIdMappings` 与 `ballISA` 两个数组（两者缺一即判「不是注册表」——这是本插件家族自定规则，非上游检查）。
- `ballIdMappings` 行：`ballId` / `ballName` / `ballClass` 必填；`config` 取值相对注册表文件解析、必须指向存在的 ball configs TOML（悬空即抛错）；`inBW`/`outBW` 正数。
- `ballISA` 行：`mnemonic` / `funct7` 必填，`bid` 必须指向本注册表内已注册的 ballId。
- 不变量（audit 的 core-registry 机检本体）：`ballNum` == 映射行数；ballId 从 0 连续无洞；ballId / ballName 无重复；ballISA 内 funct7 / mnemonic 无重复；每球 ≥1 条 ISA；带宽为正。

## 活仓库现查

- 全部注册表清单（只看顶层）：

  ```bash
  find $BB/examples/cores -name '*.toml' -path '*configs/balldomains/*' ! -path '*/configs/balldomains/balls/*' | sort
  ```

- 某 ball 注册在哪些 core（按 ballClass 全等搜；可换成 ballName）：

  ```bash
  grep -rln 'examples.balls.<ball>.<Ball>Ball' $BB/examples/cores/*/configs/balldomains/*.toml
  ```

- 某 core 的注册表指向（聚合配置）：

  ```bash
  grep -n 'balldomain' $BB/examples/cores/<core>/configs/default.toml
  ```

- 一个注册表里全部 mnemonic/funct7 行：

  ```bash
  grep -n 'mnemonic =\|funct7 =\|ballId =\|ballName =' $BB/examples/cores/<core>/configs/balldomains/default.toml | head -60
  ```
