---
stage: chip
tags: [funct7, isa, ball-registry, reserved]
updated: 2026-09-08
---

# funct7 保留值契约

事实源在 ball 侧：见 `../ball/funct7-encoding.md`（两层禁区结构、出处与现查配方都在那里，不双写）。

chip 侧只补一条工具边界：`buckyball_core_ball_index` 的 `funct7Duplicates` 只查所选 core
注册表内的同域重复，不覆盖基础 ISA 表与框架自留值——撞后两层的球注册不炸、取证时炸。
