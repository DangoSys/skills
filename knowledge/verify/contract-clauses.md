---
stage: verify
tags: [buckyball, 契约, 分阶段验证, 分阶段交付]
updated: 2026-09-08
---

# 契约条款清单的家（文档指针）

## 这是什么

verify-runner 的判定块消费条目、阶段/相位白名单、判据口径的**规范文本**住在哪份文档里。
本文件只当指针和索引用，不复制条款原文——条款的家是 docs/ 下的契约文档与代码本体
（判定五脚本 + prompt.ts），任何一处改动以那份规范文本为准。

## 家在哪（稳定锚点）

| 主题 | 规范文本位置 |
|---|---|
| 分阶段验证（CI 判定块与命令序列、§2.1 阶段识别 / §2.3 分层门禁、INFRA 语义、lane 登记表、单作业理由） | `dsh-plugin/docs/verify-runner-staged-verification.md` |
| 分阶段交付（写作/交付纪律、逐条机检口径） | `dsh-plugin/docs/phased-delivery.md` |
| 判定块消费条目（编号与上表 §2.1 对应） | `packages/verify-runner/src/prompt.ts`「CI 判定块消费（硬约束）」 |
| 相位白名单 / 声明行形态（`probe:`/`perf:`/`ball-expect`/`--model` 的语法门） | `packages/verify-runner/scripts/validate-manifest.mjs` 与 `manifest.mjs` |
| 绑定三源 ground truth 与豁免/覆盖判据 | `packages/verify-runner/scripts/binding-check.mjs` |
| stage 推断（ball 接线 carve-out、compilerTouched） | `packages/verify-runner/scripts/infer-stage.mjs` |
| 上轮 probe 取证检索（perf-gate 判据） | `packages/verify-runner/scripts/probe-loop-check.mjs` |

## 不变量（稳定事实）

- 判定块消费条目与《分阶段验证》《分阶段交付》同编号条目一一对应；prompt 是机检口径的常驻侧，
  契约文档是规范侧，两边同步改。
- 条款计数类叙述（如「共 N 条」）是散文，不当作数字断言；要数条款就看文档标题结构
  （看 `grep -n "^### \|^## " docs/verify-runner-staged-verification.md`），不靠某次读数。
- 家族条款（性能优化三轮段）在四个插件各有措辞差异，属有意为之：verify 侧按应当项表述，
  coding 侧按自查闸门表述；不要统一措辞（见 prompt.ts probe 轮小节的迭代契约条）。

## 活仓库现查

```sh
# 两份契约文档的章节结构
grep -n "^## \|^### " $DSH_PLUGIN/docs/verify-runner-staged-verification.md $DSH_PLUGIN/docs/phased-delivery.md

# 判定脚本的判据条款（各脚本头注即判据清单）
sed -n '1,60p' $DSH_PLUGIN/packages/verify-runner/scripts/binding-check.mjs
```

注：$DSH_PLUGIN = dsh-plugin 仓根（/home/ROXY/code/bb_work/dsh-plugin，工作区语境下直接可用）。
