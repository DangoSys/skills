# Templates: exact shapes to copy

View the live templates before writing anything — they are the ground truth and they move. Every path below is a stable anchor; read the file, do not recall its content.

## ISA header (stage 1)

Live template: `$BB/examples/balls/relu/workloads/isa/relu.h`

Shape:
- include `<bbhw/isa/bb_func7.h>` and `<bbhw/isa/isa.h>`;
- macro body encodes the instruction via `BUCKYBALL_INSTRUCTION_R_R` with BB_BANK0 / BB_BANK1 / BB_ITER;
- the funct7 argument is only ever `BB_FUNC7(<MNEMONIC>)` — a mnemonic resolved through the registry, never a number.

## ctest (stage 1)

Live template: `$BB/examples/balls/relu/workloads/ctests/relu_test.c`, registered in `$BB/examples/balls/relu/workloads/ctests/CMakeLists.txt` via `add_buckyball_ctests`.

Shape:
- `#include <isa/<ball>.h>` to get the ball's macros;
- sequence: `bb_mem_alloc → bb_mvin → bb_op → bb_mvout → bb_fence`, compare against the software expected value, print PASSED/FAILED;
- one `.c` ≤ 100 lines (`CTEST_MAX_LINES`); the same-directory `CMakeLists.txt` must list every `.c` with `add_buckyball_ctests`.

## bemu crate (stage 2)

Live template: `$BB/examples/balls/relu/emu/src/lib.rs` and `$BB/examples/balls/relu/emu/src/50_relu.rs`.

Shape (`lib.rs`):
- `pub const BALL_CLASS: &str = "<fqcn>"` — string-identical to the registry row's `ballClass`;
- `#[path = "<funct7>_<ball>.rs"] mod <name>;` per instruction file;
- `execute_known` / `cycles_after_issue` returning `Option<u64>`, `None` on a ballClass/funct mismatch;
- `exec` panic on illegal input.

Naming note: the numbered filename prefix is a local convention, not an upstream rule — some upstream files are bare-named, and the prefix need not equal the registered funct7. Dispatch is by mnemonic; only the registry ballISA row owns the number.

## RTL wrapper (stage 3)

Live template: `$BB/examples/balls/relu/arch/src/main/scala/ReluBall.scala` (+ compute unit in `Relu.scala`).

Shape:
- `@instantiable class <X>Ball(b: GlobalConfig) extends Module with HasBlink`;
- `package` + `class` spell the registry `ballClass` exactly;
- `inBW`/`outBW` from `b.ballDomain.ballIdMappings` keyed by ballName;
- `io = IO(new BlinkIO(b, inBW, outBW))`; tie off unconnected ports (subRobReq / mmioRead).

## dialect TD (stage 4)

Live templates: `$BB/examples/balls/relu/compiler/` — the dialect folder, `Transforms/LegalizeForLLVMExport.cpp`, plus the core-side usage in `$BB/examples/cores/pebble/compiler/`.

Shape:
- exactly one `*.td` under `compiler/src/Dialect/Buckyball/`; the op must not inherit `Buckyball_IntrOpBase` — emit through the generic `CustomIntrOp` + `buckyball_target::getBuckyballFunct7("<MNEMONIC>")` form in `LegalizeForLLVMExport.cpp` (live proofs: every ball's legalize file).

## MLIRTest triplet (stage 4)

Live template: `$BB/examples/balls/transpose/workloads/mlir_tests/` (bank + ball directories, each with `transpose_16x16_i8.mlir` + `_main.cpp` + `CMakeLists.txt`; the group root `mlir_tests/CMakeLists.txt` only does `add_subdirectory(bank)` + `add_subdirectory(ball)`).

Shape per test:
- `<name>.mlir` — bank layer holds the bank Op, ball layer the lowered ball Op; no funct7 literals in the lit `// CHECK` lines either;
- `<name>_main.cpp`; group `CMakeLists.txt` sets `BUCKYBALL_MLIR_GROUP_TARGET balls-mlir-tests-build`, `BUCKYBALL_MLIR_TEST_PREFIX bank|ball`, then `add_buckyball_mlir_test(<name> TARGET ${BUCKYBALL_MLIR_ACTIVE_TARGET})`.
