# DOL Changelog

All notable changes to DOL (Design Ontology Language) will be documented in this file.

> Dates are crates.io publish dates (or the git tag date where a version was not published). Earlier revisions of this page listed every date one year too early.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.8.2] - 2026-11-20 - "Spirit Hosting H0"

Spirit Hosting Plan H0 ("toolchain truth"): DOL-compiled Spirits now link and run in the VUDO VM.

### Changed
- **Host ABI unified with the VUDO VM** (univrs/dol#34). Bodiless `sex fun host_*` declarations import from module `vudo` with the VM linker's exact signatures (`src/wasm/host_abi.rs`, 15 host functions). Previously they imported from `loa` and could not link.
- A `sex fun` the VM does not provide (unknown name, wrong arity, float where the host expects an integer) is now a compile error.
- `compile_source` and the Spirit pipeline emit real WASM instead of a placeholder module (univrs/dol#31).

### Added
- String literals, `string` parameters and typed string locals passed to `host_*` functions lower to `(ptr, len)`. Modules that import pointer-taking host functions export `memory`.
- `dol-abi`: `vm_host_functions()` (the 15 VM host functions).
- `dol-build` CLI (DOL → WASM), wasm-bindgen annotations, `dol-abi` crate, LLVM native backend (`dol-native`, beta, not in CI), meta-programming system, CRDT/Automerge codegen.

### Deprecated
- `dol-abi::standard_host_functions()` (the 22 `vudo_*` names). Use `vm_host_functions()`.

### Fixed
- Clippy lints that kept the CI `Check` job red.
- MCP doc tests; `.dol` examples updated to v0.8 lowercase type syntax.

### Notes
- Minimum supported Rust version is 1.84.
- Tests (root crate): 2,183 with default features; 2,405 with `cli,serde,wasm`.

## [0.8.1] - 2026-01-26

Published to crates.io on 2026-01-26. The upstream DOL `CHANGELOG.md` has no 0.8.1 entry; notable commits between the `v0.8.0` and `v0.8.1` tags:

- WASM-safe `thread_local` pattern for `sex var` in Rust codegen
- Game of Life Spirit example; Art and scientific-modeling Spirit packages (these examples are labeled "DOL v0.9.0", but no 0.9.0 has been released)
- Parser/error fixes for the v0.8.0 `gen`/`docs` keywords; DOL-in-DOL sources updated to v0.8.0 syntax

## [0.8.0] - 2026-01-17 - "Clarity"

### Language Changes

#### New Preferred Keywords
- `gen` replaces `gene` for genome declarations
- `rule` replaces `constraint` for constraint declarations
- `evo` replaces `evolves` for evolution declarations
- `docs` replaces `exegesis` for documentation blocks

#### Modernized Type Names (Rust-aligned)
- `string` replaces `String`
- `bool` replaces `Bool`
- `i8`, `i16`, `i32`, `i64` replace `Int8`, `Int16`, `Int32`, `Int64`
- `u8`, `u16`, `u32`, `u64` replace `UInt8`, `UInt16`, `UInt32`, `UInt64`
- `f32`, `f64` replace `Float32`, `Float64`
- `()` replaces `Void` for unit type
- `Vec<T>` replaces `List<T>` for vectors

#### Deprecated Syntax (warnings in 0.8, errors in 0.9)
The old keywords and types are deprecated but still supported with compiler warnings.

### New Features
- **Tree Shaking** - Dead code elimination with `--tree-shake` flag
- **Migration Tool** - `dol-migrate 0.7-to-0.8` for automatic syntax conversion
- **WASM Feature Split** - Separate browser-compatible and native runtime features

## [0.7.2] - 2026-01-15 - "Visibility & GDL"

### Added
- **Visibility System** - `pub`, `pub(spirit)`, `pub(parent)` access modifiers
- **`this` Keyword** - Standardized instance self-reference
- **GDL Domain Genes** - Geometric Deep Learning primitives
  - Symmetry group genes with verified group laws
  - Graph gene with `permute_nodes` operation
  - Equivariant layer traits and message passing
  - Property-based tests for mathematical invariants

## [0.7.1] - 2026-01-04 - "Polish"

### Changed
- Removed "production-ready" claim from README
- Expanded exclude list for cleaner crate publish
- Added example DOL files demonstrating language features

### Fixed
- CI WASM test step that was hanging on Ubuntu runners

## [0.7.0] - 2026-01-04 - "VUDO Integration"

### Added
- **VUDO CLI** - `vudo run`, `vudo compile`, `vudo check` commands
- **@vudo/runtime** - TypeScript runtime package for Node.js and browser
- **SEX System** - Side Effect eXecution infrastructure (Week 1)
- **String Literals in WASM** - Proper string compilation (Week 2)

### Fixed
- Duplicate global section in WASM
- Enum type comparison bugs
- Missing `WasmImport` struct and `LocalsTable` fields
- `SexVar` declaration variant

## [0.6.0] - 2026-01-01 - "Gene Inheritance"

### Added
- **Gene Inheritance for WASM** - Full support for gene inheritance hierarchies in WASM compilation

## [0.5.0-phase0] - 2025-12 (not tagged or published) - "ENR Bridge"

### Added
- ENR (Economic Network Resources) integration phase 0
- Network bridge infrastructure
- Economic layer primitives

## [0.4.0] - 2025-12-28 - "HIR Complete"

### Added
- **Complete HIR Implementation** - High-level Intermediate Representation
- Compilation pipeline work (HIR → WASM). The MLIR path is feature-gated stub code and not in CI.
- DOL-in-DOL bootstrap sources (`dol/*.dol`). These parse, but the generated Rust crate does not compile (850 errors at v0.8.2), so DOL is **not** self-hosting.
- 1,156 passing tests

## [0.3.0] - 2025-12-27 - "HIR"

### Language Changes
- `val` for immutable bindings (replaces `let`)
- `var` for mutable bindings (replaces `let mut`)
- `type` as preferred type declaration keyword
- `extends` for inheritance (replaces `derives from`)
- `forall` as unified quantifier (replaces `each`/`all`)

### Internal Changes
- Added HIR (High-level Intermediate Representation)
- Reduced AST complexity from 50+ to 22 node types
- Added migration tool: `dol-migrate --from 0.2 --to 0.3`

## [0.2.3] - 2025-12-27 - "Stage2"

### Milestone
- Claimed "full self-hosting verified (Stage 2 bootstrap)". This does not reproduce: `stage1/` contains only a `Cargo.toml`, `stage2/` does not exist, and the bootstrap-generated crate fails with 850 compile errors at v0.8.2.
- 1,532 passing tests

## [0.2.2] - 2025-12-26 - "Bootstrap"

### Added
- **bootstrap.dol** - Wrapper types for DOL parser compatibility
- Named wildcard pattern support (`args: _` syntax)

### Milestone
- Claimed: DOL self-hosting bootstrap generates valid Rust (2,544 lines, 0 errors). Re-checked at v0.8.2 it gives 19 errors.

## [0.2.1] - 2025-12-25 - "Community"

### Added
- CHANGELOG.md
- GitHub Issue Templates
- Release Workflow with automated builds

## [0.2.0] - 2025-12-27 - "Meta-Programming"

### Added
- **Quote/Eval System** - `'expr` captures AST, `!quoted` evaluates
- **Reflection System** - `?Type` returns `TypeInfo`
- **Macro System** - 20 built-in macros
- **Idiom Brackets** - `[| f x y |]` applicative functor syntax
- **AST Transform Framework** - Visitor and Fold patterns

## [0.1.0] - 2025-12-24 - "Genesis"

### Added
- **DOL 2.0 Parser** - Full modern DOL syntax support
- **SEX System** - Side Effect eXecution for explicit effect tracking
- **Code Generation** - Rust, TypeScript, JSON Schema targets
- **CLI Tools** - dol-parse, dol-test, dol-check, dol-codegen, dol-mcp
- **Documentation** - EBNF Grammar, Specification, Tutorials

## [0.0.1] - 2025-12-19 - "Prototype"

### Added
- Initial DOL parser implementation
- Lexer using `logos` crate
- Recursive descent parser
- Basic AST definitions
- Gene, Trait, System, Constraint, Evolution declarations

---

[Unreleased]: https://github.com/univrs/dol/compare/v0.8.2...HEAD
[0.8.2]: https://github.com/univrs/dol/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/univrs/dol/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/univrs/dol/compare/v0.7.2...v0.8.0
[0.7.2]: https://github.com/univrs/dol/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/univrs/dol/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/univrs/dol/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/univrs/dol/compare/v0.5.0-phase0...v0.6.0
[0.5.0-phase0]: https://github.com/univrs/dol/compare/v0.4.0...v0.5.0-phase0
[0.4.0]: https://github.com/univrs/dol/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/univrs/dol/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/univrs/dol/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/univrs/dol/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/univrs/dol/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/univrs/dol/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/univrs/dol/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/univrs/dol/releases/tag/v0.0.1
