---
stage: verify
tags: [buckyball, ci, bb-verify, verdict-gate, INFRA, 检索配方]
updated: 2026-09-08
---

# bb-verify.yml 机制说明（verdict-gate / 评论在场 / 只读门禁 / provision 豁免 / INFRA 回流）

## 这是什么

CI 工作流 `packages/verify-runner/ci/bb-verify.yml`（fork/本机部署物料）的五段机制说明。每段：干什么、不变量、
现查配方。配置模板见 `packages/verify-runner/ci/settings.ci.yaml`，机器接线见
`packages/verify-runner/ci/runner-setup.md`（以上 `ci/` 物料均在 harness 仓的 `packages/verify-runner/` 下，非仓根）。

## verdict-gate（Run verify-runner 步骤内）

- 流程：headless 会话跑完 → 从会话 stdout 首行解析 `^VERDICT: (PASS|FAIL)` → PASS 且会话
  exit 0 = 绿；FAIL = 红；解析不到 → 回退查本轮时间窗内 PR comments∪reviews 的首行，
  再没有 → 红（宁红不假绿）。
- 不变量：PASS/FAIL 只由最终回答首行 `VERDICT:` 与 PR 评论承载；dsh 进程退出码只反映会话是否
  正常完成，不作为结论。INFRA 首行不被任何正则当作结论（见下）。

```sh
grep -n "VERDICT" $DSH_PLUGIN/packages/verify-runner/ci/bb-verify.yml | head -30
```

## 评论在场门禁（Gate: verdict present on the PR (no fake green)）

- 干什么：会话绿了还不行——评论/review 两面（comments ∪ reviews）在这一轮时间窗内没有
  `^VERDICT: (PASS|FAIL)` 首行即红。防止「会话说 PASS 但没贴到 PR 上」的假绿。
- 不变量：PASS 报告可能落在 review 而非 comment（`gh pr view --comments` 看不见 reviews），
  所以以 `--json comments,reviews` 两面为准。

```sh
sed -n '/name: "Gate: verdict present on the PR/,/^      - name: "Gate: persistent/p' \
  $DSH_PLUGIN/packages/verify-runner/ci/bb-verify.yml
```

## 只读门禁（Snapshot / Gate: persistent root untouched）

- 干什么：会话开始前对持久化根做 tracked diff 快照，结束后逐字节比较——会话改过任何已跟踪
  文件即红。落实「全程对 $BB 只读」。

```sh
grep -n "tracked\|diff --\|persistent root untouched" $DSH_PLUGIN/packages/verify-runner/ci/bb-verify.yml | head
```

## provision 豁免（provision_exempt）

- 干什么：`compilerTouched=true` 时，若本轮门禁 plan 自己会重跑 compiler build，Provision 步把
  compiler 构建失败从「基建红」降级为「交门禁轮裁决」（set +e 捕获 rc + 日志注记），防止
  「Provision 先红 → INFRA → 重发复现」的死循环；编译器写集不豁免（plan 不含 compiler build
  的那一支），宁红不假绿。
- 判定处唯一：豁免组合表在 Deterministic verdict inputs 步，是
  `src/tools/bbdev-plan.ts` 的 `compilerPrerequisite()` 调用点的**镜像**——唯一事实源是 plan，
  镜像侧注释已指名；plan 增删前置组合必须同步本表。
- 连带：豁免生效且编译器确实失败时，workload clean/build 同因跳过（same-flag-skip），避免把
  门禁轮的裁决面预演成 Provision 红。

```sh
grep -n "provision_exempt\|compilerPrerequisite\|same-flag-skip" $DSH_PLUGIN/packages/verify-runner/ci/bb-verify.yml | head -20
```

## INFRA 回流（Report failure to the PR + hosted report job）

- 干什么：verify 作业内 4 步（Prepare / Deterministic verdict inputs / Provision / Stage
  dsh-plugin）各自 tee 到 `$RUNNER_TEMP/steplogs/<id>.log`；末尾回流步在
  `if: failure() && continue-on-error` 下，当本轮时间窗内**没有**真实结论
  （`^VERDICT: (PASS|FAIL)`）时，剥 ANSI 取首条真错误行 + 失败步骤名，贴首行
  `VERDICT: INFRA` 的评论（隐藏 marker 只含 `run=<id>`，同 run 重入走 PATCH 幂等）。
- 排它性：INFRA 只在基础设施失败时贴，不判 PR 内容；verdict-gate / 回退查询 / 评论在场门禁三处
  正则只认 PASS|FAIL，`VERDICT: INFRA` 不被任何门禁当作结论——消费方见 INFRA 应重发 dispatch。
- 至多一条：去重键 = run_id；机内回流步是权威归因人（拿到真错误行必覆盖既有条目），hosted
  report 作业（ubuntu-latest，needs: verify，if: always()）只在机内没贴上时独立贴，且「绝不把
  已锚定的真错误行降级成占位串」两条写路径共用。
- watchdog 侧不对称：`scripts/bb-verify-watchdog.sh` 的「completed 无结论」判据认
  PASS|FAIL|INFRA（INFRA 也算留痕），与 workflow 侧刻意不同，两侧正则不得向对方看齐。

```sh
sed -n '/name: Report failure to the PR/,/^  report:/p' $DSH_PLUGIN/packages/verify-runner/ci/bb-verify.yml
grep -n "completed\|INFRA" $DSH_PLUGIN/packages/verify-runner/scripts/bb-verify-watchdog.sh | head -12
```

注：`$DSH_PLUGIN` = dsh-plugin 仓根（/home/ROXY/code/bb_work/dsh-plugin，工作区语境下直接可用）。
