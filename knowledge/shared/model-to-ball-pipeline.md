---
stage: shared
tags: [model-to-ball, pattern-chain, linalg-to-tile, tile-hook, bank-ssa, bind]
updated: 2026-09-09
---

# 模型算子落到 ball 的四关 pattern 链

## 这是什么

「派生一个 ball」和「模型管线会把算子降到这个 ball 上」是两件事。模型图里的算子要
真正落到 ball，需要一条四关 pattern 链全部在位，缺一关模型路径就不可达。这篇讲链
的四个环节、ball 交付与模型落 ball 的边界，以及怎么在活树上逐关核实。结论来自
phase9 SiLU 根源调研（rollout-evidence/phase9/silu-root-cause.md），那里对 SmolLM
实测过：管线为 silu 站点生成的 ball op 数是 0，断点在第一关「图侧识别」。

## 不变量 / 契约

**四关链（缺一关，模型路径不可达）：**

1. 图侧识别：`-convert-linalg-to-tile` 里注册了认出该算子的 pattern（写死的注册
   清单，模板先例是 `ReluGenericLowering` 认 `max(x,0)` 形态的 linalg.generic）。
2. Tile 方言有对应 op：`Tile.td` 里有 `tile_<算子>`。
3. tile→ball lowering：ball 侧有 `LowerTileToBuckyball/*.cpp`（hook 生成器扫到该
   目录就自动发 TILE_HOOK，无需手改注册表），core 侧 pass 里 populate 了对应
   pattern。
4. bank-SSA 分片发射器：core 侧 `LowerBuckyball/` 下有把整站点 memref 按 ball
   契约切成调用序列的 `*ToBankSSAPatterns.cpp`，并在 core 的 populate 里注册。

**ball 交付 ≠ 模型落 ball。** ball 的交付终点 = 双 phase（c-bemu / rtl）+
MLIRTest。MLIRTest 的 bank/ball 两层 `.mlir` 是手写调用形状，消费 ball 不需要
pattern 链。模型落不落 ball 取决于上面四关，四关都在编译器侧（buddy-mlir midend
与 core compiler），在 ball 写集之外。ball 实现者不负责、也不应承诺模型路径。
链不存在时 ball 照常交付，但 bind 轮的预期必须如实写「模型路径不可达（缺
pattern 链）」，不能写成「模型将落到 ball」。

**「6144」是 bank 行数，不是代码行数。** 站点几何的换算：1×16×1536 fp32 =
24,576 元素，bank 行 = 16 B = 4 个 fp32 lane，24,576 ÷ 4 = 6,144 个 bank 行/站
点。ball 契约 n ≤ 256（单 group = 64 行 × 4 lane），一个站点 = 96 次调用。没有
任何地方会生成 6144 行代码；链补齐后一个站点产生的是约 96 ×（mvin + ball +
mvout）的 op 序列。

**分片发射机制已实证存在，爆炸不来自机制本身。** transpose 的分片发射器按编译期
行列双循环把站点切块、每块发一组 mvin/transpose/mvout，机制是通的。phase8/phase9
实测的百万行爆炸来自两点：transpose 站点拖动的数据量（百万级 host 常驻元素过
24 KiB bank 池），以及非连续访存要求的逐元素 gather/scatter 打包循环。连续
dense 逐元素算子（silu 类）两点都不沾：stride=1 直接 mvin/mvout，只搬激活张量。

**现状基线（用配方现查，别背）：** 四关全通的只有 matmul / transpose / smatmul /
quant / conv 这条老链上的几家；relu 处于中间态——有识别 pattern 和 tile op，
tile→ball 没接线；silu / gelu / layernorm 的链不存在。GELU 比 SiLU 复杂、同样卡
在第一关——落不落 ball 不取决于算子数学复杂度，只取决于有没有人按算子手写这条
链。

## 活仓库现查

第一关：图侧识别 pattern 的注册清单（清单里没有该算子 = 链断在第一关）。

```
sed -n '/populateLowerLinalgToTileConversionPatterns/,/^}/p' \
  $BB/compiler/thirdparty/buddy-mlir/midend/lib/Conversion/LowerLinalgToTile/LowerLinalgToTile.cpp
```

第二关：Tile 方言 op 全清单。

```
grep -nE '^def [A-Za-z0-9_]+Op' \
  $BB/compiler/thirdparty/buddy-mlir/midend/include/Dialect/Tile/Tile.td
```

第二关快捷判据：查某个算子有没有 tile op（无输出 = 没有）。

```
grep -in '<算子名>' \
  $BB/compiler/thirdparty/buddy-mlir/midend/include/Dialect/Tile/Tile.td
```

第三关：hook 注册表里的 TILE_HOOK 清单（生成物，构建过 pebble 才存在）。

```
grep -nE 'BUCKYBALL_(TILE|BANK_SSA)_HOOK' \
  $BB/compiler/thirdparty/buddy-mlir/build/pebble/external_dialects/BuckyballBallLoweringHooks.inc
```

第三关源侧等价判据（构建树不在时用）：ball 有没有 tile→ball lowering 源文件
（无输出 = 没有）。

```
find $BB/examples/balls/<ball>/compiler -path '*LowerTileToBuckyball*' -name '*.cpp'
```

第四关：分片发射器枚举（清单里没有该算子的对应物 = 链断在第四关）。

```
find $BB/examples/cores/pebble/compiler/src/Conversion/LowerBuckyball \
  -name '*ToBankSSAPatterns.cpp' -printf '%f\n'
```

第四关注册核对：core 的 populate 函数里注册了哪几家。

```
grep -n 'populate.*ToBankSSAPatterns' \
  $BB/examples/cores/pebble/compiler/src/Conversion/LowerBuckyball/CoreBankSSALowering.cpp
```

分片发射先例实物（「一站点多调用」的模板，编译期双循环 + 每块一组 mvin/op/mvout）：

```
sed -n '216,255p' \
  $BB/examples/cores/pebble/compiler/src/Conversion/LowerBuckyball/MemTransposeToBankSSAPatterns.cpp
```
