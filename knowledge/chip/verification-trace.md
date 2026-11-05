---
stage: chip
tags: [verification, trace, ndjson, log]
updated: 2026-09-08
---

# 验证产物与 trace 格式

## 这是什么

CI 验证会话（verify-runner）执行 bbdev 命令后的产物落在
`${repoPath}/log/<时间戳>-*-bemu-*/bdb.ndjson`——bemu 运行目录的逐事件 trace，
NDJSON 一行一个 JSON 对象。报告回贴里的分析摘要（probe analysis、pmc-evidence）
是它的加工产物；原始 trace 是定位修改点的据实出处。

## 不变量 / 契约

- 目录命名 = `<时间戳>-<chip>-<sims 配置类>-bemu-<stem>` 一类形态（同一次的
  verilator 运行另带 `-verilator-` 段）；`log/` 下按运行目录分。
- 行格式：每一行是一个完整 JSON 对象，带 `"type"` 字段，如
  `{"type":"itrace",…}` / `{"type":"mtrace",…}` / `{"type":"pmctrace",…}`；
  **没有** `[ITRACE]` / `[MTRACE]` 这类标记行——不要把行尾字符串当字段。
- trace 可能为空文件（0 字节 = 零事件流）：读之前先看文件大小，空文件不是格式问题，
  是「该跑什么都没跑」的证据。
- `span_cycles`（bemu 侧）是 ball 自身 `latency` 的累加和——拿 `latency` 与它
  对账是恒等式，不能当成一项检验；独立测量 `latency` 的只有 `--pmctrace` 的
  elapsed（回贴的 `pmc-evidence` 行）。

## 活仓库现查

```bash
# 最新一条 bemu 运行目录与 trace 文件
find $BB/log -maxdepth 1 -type d -name '*-bemu-*' | sort | tail -3

# 挑第一个非空 trace 看行形态（每行一个 JSON 事件对象）
f=$(find $BB/log -name bdb.ndjson -size +0c | head -1); head -c 400 "$f"

# trace 的事件类型名单（哪些 "type" 出现过）
f=$(find $BB/log -name bdb.ndjson -size +0c | head -1)
grep -o '"type":"[a-z]*"' "$f" | sort | uniq -c
```
