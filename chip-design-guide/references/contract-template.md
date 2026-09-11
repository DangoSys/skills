# Slice contract.toml template

One file per slice, locked once written — the dispatch brief points at it.
Read when cutting a graph (stage 2). The `[policy] mismatch = "error"` value
is a hard rule: shape mismatch is an error, never silently resized.

```toml
[slice]
id = "prefill_0"
subgraph = "sg_prefill"
core = "prefill"
instance = 0

[io.in]
name = "tokens"
dtype = "i32"
shape = [1, 128]
sharedmem_region = "tokens"

[io.out]
name = "kv_cache"
dtype = "f16"
shape = [1, 32, 128, 64]
sharedmem_region = "kv_cache"

[policy]
mismatch = "error"
```

- `id` must be unique across slices; `core` names a core package of the
  design; `instance` is the core instance index within its tile/role.
- `sharedmem_region` names the tile's shared-memory region the io lives in;
  the region's shape/dtype contract is what the capacity evidence chain
  judges later. Keep the io shapes in sync with the actual model slice —
  the brief locks them.
- The repository has no committed example (per historical records);
  `compiler/thirdparty/buddy-mlir/docs/LayerPartitioning.md` is the toolchain
  doc that explains what the partition produces.
