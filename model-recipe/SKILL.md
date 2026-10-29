---
name: model-recipe
description: Write or review a Buckyball model definition (stack/models/models/<model>/model*.py) and the importer and frontend steps of its recipes (stack/models/archs/<arch>/<model>/), including whole-graph import, permute passes and their numerical verification.
---

# Model Recipe

A model is defined once under `stack/models/models/<model>/`; every recipe that
compiles it (`archs/{x86,nv,gemmini}/<model>`, their `origin/`, and
`archs/buckyball/<design>/<model>`) imports that definition and adds only its
own frontend steps. Use [model-port](../model-port/SKILL.md) for the end-to-end
port and [model-optimize](../model-optimize/SKILL.md) for chip design.

## Model files

- A model that is one graph has one `model.py`. A model whose graphs a runner
  chains has one `model-<graph>.py` per graph (`model-text_encoder.py`,
  `model-unet.py`, ...). `<graph>` names the whole chain: the function
  `forward_<graph>`, the group `subgraph0_<graph>` and the parameters
  `arg<i>_<graph>.data`.
- Each file holds the `nn.Module` of the graph, `load()` (the checkpoint-loaded
  module in eval mode, ready to import: in-place activations off and other
  capture settings that keep the numerics) and `inputs()` (a tuple of example
  inputs). Every user, including the model's own graph and prepare scripts,
  takes them the same way; hyphens in module names are fine:

  ```python
  lenet = import_module("models.models.lenet.model")
  model = lenet.load()
  (graph,) = compiler.importer(model, *lenet.inputs())
  ```

  A recipe that changes the module itself before capture (folding batch norms
  for its Balls) does it on `model` in its importer, as a frontend step.
- One graph is the whole computation of one invocation. Import it whole when
  Dynamo can capture it: a VLA with a fixed number of denoising steps unrolls
  into one graph with shared weights. Keep the graph to one step when the step
  count is large or data dependent: one diffusion step, one decoder step of an
  LLM with its KV cache as graph inputs and outputs.
- Target-independent rewrites that keep the numerics belong in the model file:
  whole-image position ids instead of scattered ones, RoPE halves written with
  `cat` instead of slice assignment, grouped-query attention without repeating
  KV per query head, a prefix cache the expert reads without cloning or
  concatenating. Check each rewrite in PyTorch against the original module
  first. Target-dependent steps (permute, quantization) stay in the recipe's
  `frontend/`.
- Shared code between the graph files of one model is copied, not factored.

## Importer

`buddy-pytorch-importer.py` of a recipe is a straight script, no argparse, no
helper functions:

1. `model_dir = Path(__file__).resolve().parent`, `output = model_dir / "output"`.
2. Import the model file, `(graph,) = compiler.importer(module.load(), *module.inputs())`
   with `torch._inductor.decomposition.decompositions` unless the recipe needs
   another table, and `graph.dump(output / "01-import.txt")`.
3. Each frontend step from `frontend/<step>/graph.py`, followed by its dump
   (`02-permuted.txt`, ...).
4. Lowering and export (when the recipe has reached that step): `graph.fuse_ops([simply_fuse])`,
   `GraphDriver`, `subgraph0*.mlir`, `forward*.mlir`, one parameter pack per
   dtype in the order of the packed arguments.

Keep existing file headers. The CMake of a recipe lists every step's dump as an
output, depends on `frontend/*.py`, and ends with `add_subdirectory(origin)`
when an origin flavor exists.

## Permute

- Linear: turn `t(W)` into `permute(W, [1, 0])`, `decompose_addmm_to_mm_add`,
  then `transpose_matmul_fusion`; the weight keeps its `[out, in]` layout.
  Import with the inductor decompositions so `aten.t` already is a permute.
- Convolutions on x86/nv/gemmini: one NHWC region around the convolutions
  (conv `NHWC_FCHW`, pools and batch norm `NHWC`, means over `[1, 2]`, cat and
  split on axis 3, elementwise layers whose 4-D inputs are all in the region);
  one permute into the region before its first user and one out of it where a
  non-region node reads it. Never insert nodes between placeholders: they take
  the function arguments in body order.
- A pass works on op types, never on node names.

## Verification

Run every changed importer and compare with PyTorch, not only with a previous
dump:

- JIT the graph after the step: `graph.compile()`, then
  `compiler._dynamo_run_for_graph(graph)(*params, *inputs)`. Graph inputs come
  in first-use order, and module attributes Dynamo lifts (yolo anchors) are
  inputs too: take the example inputs `DynamoCompiler._compile_fx` receives,
  minus the parameters, instead of guessing the order. Randomize the float
  example inputs before capture so PyTorch and the graph see the same values.
  Disable `torch._dynamo.mark_dynamic` (the JIT lowers static shapes only),
  drop the importer's trace config, and leave `eliminate-memref-copy` out of
  the JIT pipeline: it turns cache updates into in-place writes of input
  buffers the Python call does not keep alive.
- Reading the argument order of a compiled `forward` for a runner: follow each
  argument of `forward.mlir` into `subgraph0.mlir` and look at its first use
  (a mask is cast to i1, token ids index an embedding); never infer it from
  the Python signature.
- Check the unmodified graph too: a mismatch there is a Buddy lowering bug, not
  the step's.
- When a refactor must not change outputs, compare the exported files byte for
  byte with the previous importer's (MLIR may differ only in a trailing newline).

## Buddy lowerings fixed in this repository

When a check fails on the unmodified graph too, suspect the lowering. These
were wrong and are fixed; keep the behaviour when touching them:

- `max_pool2d` with padding rounds the output down like PyTorch (trailing
  padding gives up the remainder), never symmetric SAME padding.
- `_to_copy` converts every dtype pair (float to int truncates).
- `cumsum` is a parallel `linalg.generic`, `index_put` without accumulation one
  `scf.parallel` of scalar copies: host-side loops over device buffers crash
  the nv pipeline.
- `embedding` reshapes any index tensor to `[1, N]` for `tosa.gather`.
- Scaled dot-product attention adds a float mask in four dimensions, so masks
  broadcast over batch, head and query.
- Batch norm and adaptive average pooling honour `_layout` (`NHWC`).
