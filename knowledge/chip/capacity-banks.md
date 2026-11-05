---
stage: chip
tags: [capacity, bank, memdomain, sharedMem, D1-D5]
updated: 2026-09-08
---

# 容量事实源与银行几何

## 这是什么

单核容量判定的全部数值事实来自 `examples/cores/<core>/configs/memdomains/*.toml`
的 `[bank]` 表（`num`/`width`/`entries`）。银行池是 **core 级私有**：每个 core 实例
各自铺出自己的 `SramBank` 数组，全树没有跨 core 的共享 bank 集合；编译期的
physical-bank 分配也只在当前 target 自己的 `bankNum` 里找槽位，借不到别的池。
本文记录这些不变量与「共享池」的真相，现值一律现查。

## 不变量 / 契约

- `[bank]` 三键必须都是正整数，`width` 必须是 8 的倍数；行字节 `rowB = width / 8`，
  每 bank 字节数 `bankB = entries × rowB`，单核私有池 `pool = num × bankB`。
  形状坏了管线直接死（`bank_params`），所以现查时见到异常值要先怀疑写入失误。
- 私有池的 `num` 是**槽位维**（并发段分配上限），`entries` 是**深度维**——上游
  physical-bank 分配只判槽位维（`need = row × col` 在 `bankNum` 里找**连续**空位），
  深度维全链无人静态判，这也是阶段 0 必须自己判 D1 的原因。
- 共享池（tile 的 `[sharedMem] enable = true`）：RTL 侧铺 `bankNum × nCores` 个
  `SramBank`（`nCores` = 该 tile 的 core 数），每个槽的深度仍等于私有池的
  `bankEntries`——**外溢换来的是更宽的槽集合，不是更深的槽**。tile 里写的
  `[sharedMem] entries` 只是申报值，不是每槽深度。
- c-bemu 验证面**不建模共享池**（只镜像私有池的映射表），外溢结论只能到 RTL 面
  取证，不得声称 bemu 已验证；单核 tile（`nCores = 1`）的共享池与私有池槽数相同，
  别指望它扩容。
- D1–D5 的判定公式与「先优化再判死」的流程是方法论，见 skill `chip-design-guide`；
  本文只提供公式所需的物理事实。

## 活仓库现查

```bash
# 全部 core 的 [bank] 现值（num/width/entries）
grep -A4 '^\[bank\]' $BB/examples/cores/*/configs/memdomains/default.toml

# 某 core 的完整 memdomain（含 [dma]/[tlb] 等附属事实）
sed -n '1,40p' $BB/examples/cores/pebble/configs/memdomains/default.toml

# 某 tile 的 [sharedMem] 申报值（enable/entries，注意它不是每槽深度）
grep -A4 '\[sharedMem\]' $BB/examples/chips/goban/configs/designs/tiles/default.toml

# 某 chip 全部 tile 的 sharedMem 开关一目表（文件多时的最简筛选）
grep -l 'sharedMem' $BB/examples/chips/*/configs/designs/tiles/*.toml

# 上游 physical-bank 分配只判槽位维的实物（连续空位搜索）
grep -n 'tryAlloc\|need' $BB/compiler/src/Conversion/LowerBuckyball/PhysicalBankState.cpp | head
```
