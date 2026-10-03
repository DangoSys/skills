---
name: debug-compiler
description: Diagnose Buckyball model import, graph transformation, MLIR lowering, layout, bank allocation, and compiler performance failures. Use when the failure precedes emulator or RTL execution.
---

# Compiler Debugging

Locate the first failing stage: model rewrite, graph import/grouping, quantization,
layout, dialect verification, bank lowering/allocation, LLVM IR, or machine code.
Retain the exact command, input graph, target configuration, and first diagnostic.

- Verify the original model and chip rewrite separately. Quantization must not
  hide a changed preprocessing, pooling, bias, reduction, or flattening contract.
- Follow parameter identity/order through import and packing; inspect shapes,
  strides, dtypes, scales, and producer/consumer layouts at the failing boundary.
- Before adding a high-rank transpose, test whether aligned layouts or offline
  weight permutation remove it. Put model layout decisions in `permute/`.
- Use actual compute-bank dimensions. Reduce tiles or split reduction/graph
  regions when the design exceeds them; do not silently enlarge capacity.
- A fused region can recursively recompute its producers. Inspect its lowering
  and materialization boundaries when IR size or runtime work grows sharply.
- For a performance target, use `$debug-performance`. Preserve fixed argument
  strides with dynamic offsets into packed payloads; forcing offset zero can make
  direct DMA read the wrong weights. Tile capacity must also respect ISA row bases.
- Distinguish DMA-loaded storage from recursively assembled scratch tiles. A narrow
  row-base field can limit scratch assembly without limiting a whole-bank DMA load;
  applying one conservative limit to every path can break valid larger-bank users.
- Verify physical padding and logical trimming independently. Calibration hooks
  must see the physical Linear/Conv channels before a wrapper trims the output;
  retain the original model as the reference for logical outputs.
- For a slow compilation, inspect the live process/pass before assuming a hang.
  Preserve intermediate MLIR/LLVM IR when useful. Fix graph/lowering expansion
  before accumulating optimization-disable flags; validate any retained tradeoff.

Reproduce a semantic defect with a small independent C/MLIR case, fix the red
stage, and run it plus affected existing cases. A lowering marker's indexing map
can be consumed by a later pass; inspect that consumer before changing the map.
Do not adjust output comparisons or the golden model to conceal a mismatch.

Use project MCP build tools. With user-authorized fallback, use
`nix develop -c bbdev`; report logs/exit status. Distinguish an environment/source
packaging error from a compiler defect. Nix Git-source packaging can omit a new
untracked file that local compilation sees; inspect inclusion before altering code.

Once compilation is green, continue with BEMU and `$debug-bemu` as needed.
