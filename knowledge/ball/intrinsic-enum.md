---
stage: ball
tags: [intrinsic, llvm, fork, enum, compiler, submodule]
updated: 2026-09-08
---

# LLVM fork 冻结 intrinsic 枚举

## 这是什么

ball 的编译器 LLVM 出口引用 `llvm::Intrinsic::riscv_bb_<mnemonic>` 枚举。这个枚举由 vendored LLVM fork（`compiler/thirdparty/buddy-mlir/llvm`）声明，是**冻结**的：ball 无法往 fork 里加条目，引用一个不存在的枚举就是编译期挂。本文件是这条约束与现查配方。

## 不变量（稳定事实）

- `mlir-tblgen -gen-llvmir-conversions` 把每个 `LLVM_IntrOpBase` op 转成**无条件**的 `llvm::Intrinsic::<enumName>` 引用——方言 `*.td` 继承 `Buckyball_IntrOpBase` 就必然生成对冻结枚举的引用，枚举里没有它 = 编译失败。
- 唯一的合法出口形态：方言 `*.td` **不**继承 IntrOp base，在 `Transforms/LegalizeForLLVMExport.cpp` 里发通用 `CustomIntrOp` + `buckyball_target::getBuckyballFunct7("<MNEMONIC>")`（现有 ball 全部如此）。
- 枚举的声明文件集合随 fork 的 pin 变（入口 `IntrinsicsRISCVBuckyballExt.td` 加它 include 的 per-core 扩展），所以**不背文件名单**，一律 glob 现查。
- nested `llvm` 是子模块的子模块：`git submodule status` 里带 `+` 表示工作树不是 fork 记录的 commit——两个不同 commit 声明两个不同的 `int_riscv_bb_*` 集合，必须先对齐再查。

## 活仓库现查

- 对齐状态（两级都查；带 `+` 就先对齐：`git -C $BB/compiler/thirdparty/buddy-mlir submodule update --init --recursive llvm`）：

  ```bash
  git -C $BB submodule status compiler/thirdparty/buddy-mlir
  git -C $BB/compiler/thirdparty/buddy-mlir submodule status llvm
  ```

- 冻结枚举集合（路径含 `<ball>` 相关的 mnemonics 可直接 grep 核对）：

  ```bash
  grep -rhoe 'int_riscv_bb_[A-Za-z0-9_]*' $BB/compiler/thirdparty/buddy-mlir/llvm/llvm/include/llvm/IR/*.td | sort -u
  ```
