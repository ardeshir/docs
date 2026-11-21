# DOL → WASM Compiler - Completion Report

**Date:** 2026-01-02
**Status:** Historical report (Phase 4, v0.6.0) — see the v0.8.2 update below
**Version:** v0.6.0

> **Note (2026-11, verified against DOL v0.8.2):** This is a point-in-time report from January 2026.
> Some capabilities listed here are partial or stubbed; corrections are marked inline.
> The current state of the WASM backend and the VUDO host ABI is summarised in
> the **Update: DOL 0.8.2 — VUDO Host ABI** section directly below.

---

## Update: DOL 0.8.2 — VUDO Host ABI

DOL 0.8.2 (released 2026-11-20, Spirit Hosting milestone H0 "toolchain truth") makes DOL-compiled
Spirits link and run in the VUDO VM:

- **Host imports come from module `vudo`.** A bodiless `sex fun host_*` declaration becomes a WASM
  import from module `vudo` with the VM linker's exact signature (`src/wasm/host_abi.rs`). Before
  0.8.2 these imported from `loa` and could not link.
- **15 host functions:** `host_time_now`, `host_random_bytes`, `host_log`, `host_storage_read`,
  `host_storage_write`, `host_storage_delete`, `host_network_connect`, `host_network_listen`,
  `host_network_broadcast`, `host_credit_balance`, `host_credit_transfer`, `host_credit_reserve`,
  `host_credit_release`, `host_credit_consume`, `host_credit_available`. Name and signature parity
  with the VM linker (`univrs/vudo`, `vudo_vm/src/linker.rs`) is tested.
- **Mismatches are compile errors.** A `sex fun host_*` the VM does not provide (unknown name, wrong
  arity, float where the host expects an integer) fails to compile.
- **Strings lower to `(ptr, len)`.** String literals, `string` parameters and typed string locals
  passed to `host_*` functions are lowered to a pointer/length pair, and modules that import
  pointer-taking host functions export `memory`.
- `compile_source` and the Spirit pipeline emit real WASM instead of a placeholder module.
- `dol-abi` gains `vm_host_functions()` (the 15 VM host functions); `standard_host_functions()`
  (22 `vudo_*` names) is deprecated.

```dol
sex fun host_log(level: i64, msg: string) -> i64

sex fun hello() -> i64 {
    return host_log(2, "hello from DOL")
}
```

In the `univrs/vudo` CI, a program like this is compiled to WASM with `dol = "0.8.2"` and run by
`vudo run`, which prints `[VUDO:INFO] hello from DOL`.

**Known gaps in the WASM backend at 0.8.2:**
- Not supported: lambdas, tuples, lists, `sex { }` blocks, `?`, quote/meta, idiom brackets, `this`,
  casts, and `for` over anything other than a range.
- Gene layouts reject `u64` and `string` fields.
- `println` is unknown (so the `examples/native` programs do not compile to WASM).
- Declarative-only files (genes/traits with no functions) compile to an empty module.
- No type enforcement: ill-typed function bodies are not rejected before codegen.

---

## Executive Summary

Phase 4 of the DOL WASM compiler development is complete. The compiler successfully transforms DOL source code into executable WebAssembly modules, enabling Spirit execution in the Univrs ecosystem.

### Key Metrics

| Metric | Value |
|--------|-------|
| **Total Tests Passing** | 445+ (all DOL tests) |
| **WASM Execution Tests** | 44 passing, 3 ignored |
| **ENR DOL Specs Parsing** | 5/6 files (83%) |
| **Supported WASM Types** | i32, i64, f32, f64, string literals, enums; generic types are passed as opaque `i32` pointers (see note below) |
| **Control Flow Constructs** | if/else, match, while, for, loop, break |

---

## Completed Work

### 1. Cross-Repo Assessment (Phase 0)

Assessed 4 repositories for integration readiness:

| Repository | Status | Key Finding |
|------------|--------|-------------|
| **univrs-dol** | Ready | 445 tests passing, full WASM pipeline |
| **univrs-enr** | Ready | 6 DOL spec files (~3095 lines) |
| **univrs-identity** | Ready | Ed25519 production-ready |
| **univrs-vudo** | Ready | 92 tests, 15 host functions |

### 2. WASM Compiler Features (Already Implemented)

The assessment revealed that most compiler features were already implemented:

#### Local Variables & Assignments
- Variable declarations with type annotations
- Variable reassignment in loops
- Scoped local variables

#### Control Flow
- **If/Else**: Branch-based conditional execution
- **Match**: Pattern matching with default arms
- **While Loops**: Condition-based iteration
- **For Loops**: Range-based iteration (0..n)
- **Loop/Break**: Infinite loops with break statements

#### Gene (Struct) Support
- Memory layout calculation for fields
- Field offset computation
- Gene inheritance with topological sorting
- Method compilation with implicit `self` parameter

### 3. New Compiler Enhancements

#### Generic Type Support
Added WASM *type mapping* for generic types (they are represented as opaque `i32` pointers; there is
no collection runtime behind them):
```rust
// Supported generic types → i32 pointers
List<T>, Vec<T>, Option<T>, Map<K,V>, HashMap<K,V>, Result<T,E>
```

#### Iterator Method Calls
Accepted these method names on collections. **Correction (v0.8.2):** most are compiled as
pass-throughs that return the receiver pointer unchanged (closure arguments are dropped;
`collect`/`sum`/`unwrap` are `TODO` in `src/wasm/compiler.rs`), so they do not compute results:
- `iter()`, `into_iter()`, `map()`, `filter()`, `collect()`
- `sum()`, `len()`, `is_empty()`, `push()`, `pop()`, `get()`
- `keys()`, `values()`, `clone()`, `unwrap()`, `is_some()`, `is_none()`

#### Const Declaration Support
Added parsing and code generation for constant declarations:
```dol
const FAILURE_THRESHOLD: i32 = 3
```

### 4. ENR DOL Specs Compilation

Parsed 5 of 6 ENR DOL specification files. **Caveat:** at the time, parse checks only read the first declaration of each file (the same limitation `dol-parse`/`dol-check` still have at v0.8.2), so these results describe the first declaration only:

| File | Status | Declarations Found |
|------|--------|-------------------|
| core.dol | PASS | NodeId gene |
| entropy.dol | PASS | HOP_ENTROPY_BASE const |
| nexus.dol | PASS | MIN_NEXUS_UPTIME const |
| revival.dol | PASS | ENTROPY_TAX_RATE const |
| septal.dol | PASS | FAILURE_THRESHOLD const |
| pricing.dol | FAIL | Trait method syntax needs enhancement |

### 5. Hello World Spirit End-to-End Tests

Added 4 comprehensive Spirit integration tests:

1. **test_hello_world_spirit_e2e**: Basic Spirit compilation and execution
2. **test_spirit_with_computation**: Fibonacci computation with loops
3. **test_spirit_enr_entropy**: ENR entropy cost calculation
4. **test_spirit_control_flow**: Match-based request dispatcher

All tests demonstrate the complete pipeline:
```
DOL Source → Parse → AST → WASM Compile → Wasmtime Execute → Verify Results
```

---

## Technical Architecture

### WASM Module Structure

```
┌─────────────────────────────────────────┐
│            WASM Module                  │
├─────────────────────────────────────────┤
│ Type Section                            │
│   - Function signatures (params/returns)│
├─────────────────────────────────────────┤
│ Function Section                        │
│   - Function type indices               │
├─────────────────────────────────────────┤
│ Memory Section                          │
│   - 1 page (64KB) linear memory         │
├─────────────────────────────────────────┤
│ Export Section                          │
│   - Exported function names             │
├─────────────────────────────────────────┤
│ Code Section                            │
│   - WASM bytecode for each function     │
├─────────────────────────────────────────┤
│ Data Section                            │
│   - String literals                     │
│   - Static data                         │
└─────────────────────────────────────────┘
```

### Compilation Pipeline

```
                                    ┌──────────────┐
 DOL Source  ──────────────────────►│    Lexer     │
                                    └──────┬───────┘
                                           │ Tokens
                                    ┌──────▼───────┐
                                    │    Parser    │
                                    └──────┬───────┘
                                           │ AST
                                    ┌──────▼───────┐
                                    │  Validator   │
                                    └──────┬───────┘
                                           │ Valid AST
                                    ┌──────▼───────┐
                                    │ WasmCompiler │
                                    └──────┬───────┘
                                           │ WASM Bytes
                                    ┌──────▼───────┐
                                    │ WasmRuntime  │
                                    └──────┬───────┘
                                           │
                                    ┌──────▼───────┐
                                    │  Execution   │
                                    └──────────────┘
```

---

## Test Coverage Summary

### WASM Execution Tests (44 passing)

| Category | Tests | Status |
|----------|-------|--------|
| Module Validation | 5 | All Pass |
| Runtime Initialization | 2 | All Pass |
| Basic Execution | 3 | All Pass |
| Function Calls | 3 | All Pass |
| Gene Methods | 3 | All Pass |
| Control Flow | 2 | All Pass |
| Loops | 5 | All Pass |
| Gene Inheritance | 3 | All Pass |
| Enum Types | 7 | All Pass |
| String Literals | 4 | All Pass |
| Spirit E2E | 4 | All Pass |
| Error Handling | 3 | All Pass |

---

## Known Limitations

1. **Multi-function file compilation**: Cross-function references in compile_file need enhancement
2. **Trait method syntax**: `is method_name(...) -> Type` in traits needs parser support
3. **Gene field assignment**: Direct field assignment without `this.` prefix in methods

---

## Files Modified

### Parser/AST
- `src/ast.rs`: Added `Declaration::Const(VarDecl)` variant
- `src/parser.rs`: Added const declaration parsing

### Code Generation
- `src/wasm/compiler.rs`: Generic types, method calls, enum support
- `src/codegen/jsonschema.rs`: Const handling
- `src/codegen/rust.rs`: Const handling
- `src/codegen/typescript.rs`: Const handling

### Other
- `src/validator.rs`: Const handling
- `src/transform/visitor.rs`: Const handling
- `src/lower/decl.rs`: Const handling
- `src/bin/dol-parse.rs`: Const handling
- `src/bin/dol-check.rs`: Const handling

### Tests
- `tests/wasm_execution.rs`: Added 4 Hello World Spirit tests

---

## Next Steps (Future Phases)

1. **Multi-function compilation**: Enable cross-function references in DolFile compilation
2. **Trait implementation**: Full trait method parsing and compilation
3. **VUDO VM integration**: Connect DOL WASM to VUDO host functions — *done in 0.8.2 (H0), see the update above*
4. **Spirit runtime**: Complete Spirit lifecycle management
5. **ENR integration**: Full ENR spec compilation to deployable Spirits

---

## Conclusion

Phase 4 successfully established the DOL → WASM compilation pipeline. The compiler can transform DOL source code into executable WebAssembly modules that run in the Wasmtime runtime. With 44 WASM tests passing and 83% of ENR DOL specs parsing successfully, the foundation is ready for Spirit execution in the Univrs ecosystem.
