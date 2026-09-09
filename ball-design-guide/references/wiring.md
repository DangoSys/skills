# Stage 4 wiring: registry, compiler, regression

Full wiring methodology for registering a new ball. Repository facts (exact rows, filenames, enum sets) come from `bb-knowledge`; the shape below is what must exist.

## Registry edits (core side)

The core's aggregate `configs/default.toml` points its `balldomain=` at the one active registry (`examples/cores/<core>/configs/balldomains/*.toml`, top-level; no variant selection). Three edits:

1. `ballIdMappings`: one row `{ ballId, ballName, ballClass, config, inBW, outBW }` — `config` is a path relative to the registry file, must resolve to an existing ball config TOML.
2. `ballNum`: +1.
3. `ballISA`: one row per funct7 `{ mnemonic, funct7, bid }` with `bid` = the mapping row's ballId.

Run `buckyball_ball_audit` right after; its core-registry check is the machine gate (ballNum == row count, consecutive unique ballIds, unique ballNames/mnemonics/funct7s, ≥1 isa row per ball, positive bandwidth).

## Ball-side minimum compiler set (mandatory)

`_ball_compilers` (in `compiler/scripts/pb_to_target_registry.py`, called from `compiler/CMakeLists.txt`) `_die`s the build when a registered ball lacks either:

1. exactly one `*.td` under `compiler/src/Dialect/Buckyball/` (0 or ≥2 both die);
2. `compiler/src/Dialect/Buckyball/Transforms/LegalizeForLLVMExport.cpp`.

Optional extras: `Conversion/LowerBuckyball/*.cpp` and `Conversion/LowerTileToBuckyball/*.cpp` — the generated lowering hooks (`_emit_lowering_hooks`) reference them only when present; absence is not a violation.

## LLVM export form (the one legal shape)

`mlir-tblgen -gen-llvmir-conversions` turns every `LLVM_IntrOpBase` op into an unconditional `llvm::Intrinsic::<enumName>` reference. The LLVM fork's enum is frozen — a ball cannot add to it, and `Buckyball_IntrOpBase<"<mnem>">` on an unlisted mnemonic is a compile-time failure. The tree's only shape: the dialect `*.td` does not inherit the IntrOp base; `LegalizeForLLVMExport.cpp` emits generic `CustomIntrOp` + `buckyball_target::getBuckyballFunct7("<MNEMONIC>")`. To check a mnemonic against the live enum, use the `bb-knowledge` intrinsic recipe (check submodule state first — a `+` means the enum is from a drifted fork).

## Core-side wiring (single-core chip, five sites)

On a single-core build `compiler/CMakeLists.txt` add_subdirectory's the one core compiler package; the core's own CMake files are a hand-maintained per-ball manifest. To wire the new ball:

1. `examples/cores/<core>/compiler/src/CMakeLists.txt`: add the ball's dialect dir to `<CORE>_BALL_COMPILER_DIALECT_DIRS`.
2. `examples/cores/<core>/compiler/src/Dialect/Buckyball/<CORE>Buckyball.td`: add `include "<Ball>.td"`.
3. `examples/cores/<core>/compiler/src/Dialect/Buckyball/Transforms/CMakeLists.txt`: list the ball's `LegalizeForLLVMExport.cpp` in `add_mlir_dialect_library` (**build gate** — missing = link-time `undefined reference`).
4. `examples/cores/<core>/compiler/src/Dialect/Buckyball/Transforms/LegalizeForLLVMExport.cpp`: declare `populate<ballName>LegalizeForLLVMExportPatterns` and `configure<ballName>LegalizeForExportTarget` (**build gate**).
5. same file: call each once from the two export entry points (**build gate** — declaration-only compiles but never runs).

Sites 1 and 2 are include/doc surfaces: `foreach` existence checks only cover listed dirs, and the op set/include paths are generated. They are not gates, but they are part of the manifest's completeness — the audit reports them in the detail only. A core whose manifest compiles no ball at all (the toy shape) or ships no compiler package cannot speak about this ball; the audit notes it as not judged.

The audit's compiler-integration check judges sites 3/4/5 mechanically: every compiled legalize source in the core manifest, and each symbol occurring at least twice (declaration + call) in the core's legalize file.

## MLIRTest (mandatory, phase-5 minimum)

`workloads/mlir_tests/{bank,ball}/` triplets per `references/templates.md`; stem `<chip>-<target>-mlirtest-<bank|ball>_<name>-baremetal|linux`; every stem registered in the chip's bemu `workloads-elf.toml` (-baremetal) and `workloads-pk.toml` (-linux). The cmake side `continue()`s on a missing `mlir_tests` (so CI builds stay green), and the audit's mlir-regression check is what makes it mandatory — unregistered = blocking.

## Regression stem (chip side)

`examples/chips/<chip>/regression/batch/bemu/workloads-{elf,pk}.toml` `[workloads].tests` lists stems; derive the target token from `_target_name(core) = core.role or core.pkg` (not the chip dir name, not the design filename); on toy/pebble all three happen to agree — do not generalize from that coincidence. Verilator lists take small tests only; bank tests stay bemu-only; pk stems are registered but pk *execution* is not part of acceptance (non-rushB verilator runs elf-tests only; rushB lanes are out of scope, `enable_rushb: true` chips only).
