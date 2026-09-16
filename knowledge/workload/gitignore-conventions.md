---
stage: workload
tags: [e2e, gitignore, recipe]
updated: 2026-09-08
---

# e2e 模型树 .gitignore 惯例现查

## 这是什么

模型目录把 importer 生成物挡在库外靠两层 `.gitignore`：
`models/models/.gitignore`（父级，盖住粗粒度生成物）+ 各模型目录自己的
`.gitignore`（盖住该模型特有产物）。本文件给现查配方；哪些目录有、各目录
写了什么都不固定，全部以活树为准。

## 不变量 / 契约

- importer 生成物（`output/`、`*.payload/`、`*.rax`、`*.pt` / `*.pth` 等）必须被
  ignore；模型目录特有的落盘物（`*.mlir`、`*.data` 等）靠目录自己那份盖。
- 声明为入库的期望值来源（如 `reference/` 下的参考张量）不得被任何一层
  ignore 规则命中：命中即「以为交了实为未跟踪」。
- 判定一个具体路径是否被忽略，用 git 自己的语义（`git check-ignore`），
  不要手工复刻匹配规则。

## 活仓库现查

`$M` = `$BB/bb-tests/workloads/src/ModelTest/e2e/models`。

- 哪些模型目录没有自己的 `.gitignore`：

  ```bash
  for d in $M/models/*/; do [ -f "$d.gitignore" ] || basename "$d"; done
  ```

- 父级规则内容：

  ```bash
  cat $M/models/.gitignore
  ```

- 各目录自带的规则汇总（看模型树惯用的模式）：

  ```bash
  grep -rh '^[^#[:space:]]' $M/models/*/.gitignore | sort | uniq -c | sort -rn | head -20
  ```

- 某路径是否被忽略、被哪条规则命中（在 e2e 子仓里跑；e2e 是独立 git 仓库，
  `git check-ignore` 读的是它自己的 index/规则）：

  ```bash
  git -C $M/models check-ignore -v <相对 models/ 的路径>
  ```

  退出码 0 = 被忽略（`-v` 显示命中规则与文件）；非 0 = 未忽略。

- 某目录的期望值文件是否会被目录或父级规则吞掉（连同符号链接语义一并交给 git）：

  ```bash
  git -C $M/models check-ignore -v <X>/<期望值相对路径>
  ```
