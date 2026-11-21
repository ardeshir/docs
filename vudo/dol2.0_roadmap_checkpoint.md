# DOL 2.0 Roadmap Checkpoint

> **Document Version:** 4.0.0
> **Last Updated:** December 29, 2025 (corrected November 2026)
> **Status:** Historical snapshot of v0.4.0 "HIR Complete". See *Current status* below.
> **Repository:** [github.com/univrs/dol](https://github.com/univrs/dol)

> **Current status (November 2026).** This page is a historical checkpoint written at v0.4.0. The latest release is
> **DOL 0.8.2** (crates.io, 2026-11-20). "DOL 2.0" is a historical *language-generation label* (DOL + functions,
> pattern matching, control flow, meta-programming), **not a version number**. No DOL 2.0 specification document
> exists; the de facto spec is `src/lexer.rs` + `src/parser.rs` at v0.8.2 plus `CHANGELOG.md`. Current syntax is
> the v0.8 "Clarity" set (`gen`/`rule`/`evo`/`docs`, lowercase Rust-style types); old forms still parse with
> warnings and become errors at v0.9. Test counts at 0.8.2: **2,183** (default features) / **2,405**
> (`cli,serde,wasm`). Claims below that turned out to be false have been corrected inline.

---

## Executive Summary

Design Ontology Language (DOL) 2.0 represents a major evolution from the specification-only DOL 1.x to a **Turing-complete programming language** with functional composition and multi-target code generation. A type checker exists, but as of 0.8.2 type errors are **not enforced** by `dol-check` or the validator. This checkpoint documents our progress from concept to working compiler.

### Key Milestones (as recorded at v0.4.0, corrected)

| Milestone | Status | Release | Tests (at the time) |
|-----------|--------|---------|-------|
| DOL 2.0 Specification | ❌ No specification document exists | — | — |
| Q1: Lexer + Parser + TypeChecker + Codegen | ✅ Complete | v0.1.0 "Genesis" | 631 passing |
| Q2: Meta-Programming | ✅ Complete | v0.2.0 "Meta-Programming" | 590 passing |
| Q3: MCP Server | ✅ MCP server (`dol-mcp`). MLIR codegen is a feature-gated stub, not in CI | v0.2.1 | 700+ passing |
| Q4: Self-Hosting Bootstrap | ❌ Not reproducible: the crate generated from the `dol/*.dol` bootstrap sources fails with 850 compile errors | v0.2.2 "Bootstrap" | 741+ passing |
| Q4: Stage2 Self-Hosting | ❌ Not real: `stage1/` contains only a `Cargo.toml`, `stage2/` does not exist | v0.2.3 "Stage2" | — |
| HIR Architecture | ✅ Complete | v0.3.0 "Pragmatic Evolution" | 466 passing |
| HIR + WASM pipeline | ✅ HIR and a direct WASM backend exist. MLIR is not in the pipeline; the WASM backend does not use HIR | v0.4.0 "HIR Complete" | 1,156 passing |
| **Latest release (Nov 2026)** | **0.8.2** — Spirit Hosting H0: DOL-compiled Spirits link and run in the VUDO VM | **2026-11-20** | **2,183 / 2,405** |

---

## Table of Contents

1. [DOL 1.x → DOL 2.0: What Changed](#dol-1x--dol-20-what-changed)
2. [Language Features](#language-features)
3. [Compiler Architecture](#compiler-architecture)
4. [Phase 1: Lexer & Parser](#phase-1-lexer--parser)
5. [Phase 2: Type System](#phase-2-type-system)
6. [Phase 3: Code Generation](#phase-3-code-generation)
7. [CLI Tools](#cli-tools)
8. [Vocabulary System](#vocabulary-system)
9. [Roadmap: What's Next](#roadmap-whats-next)
10. [Migration Guide: DOL 1.x → 2.0](#migration-guide-dol-1x--20)
11. [Contributing](#contributing)

---

## DOL 1.x → DOL 2.0: What Changed

### DOL 1.x (Specification Language)

DOL 1.x was a **declarative specification language** for defining ontological contracts:

```dol
// DOL 1.x - Declaration only
gen ProcessId {
  type: u64
  rule positive { this.value > 0 }
  docs { A process knows its identity. }
}
```

**Limitations:**
- No control flow
- No functions with bodies
- No expressions beyond constraints
- Required external runtime for execution

### DOL 2.0 (Programming Language)

DOL 2.0 is a **Turing-complete functional language** that compiles to multiple targets:

```dol
// DOL 2.0 - Full programming language
gen Calculator {
  type: Module
  
  fun fibonacci(n: i64) -> i64 {
    match n {
      0 { return 0 }
      1 { return 1 }
      _ { return fibonacci(n - 1) + fibonacci(n - 2) }
    }
  }
  
  fun pipeline(x: i64) -> i64 {
    return x |> double >> increment |> square
  }
  
  rule valid_input {
    this.n >= 0
  }
  
  docs {
    Mathematical operations with full type safety.
  }
}
```

### Comparison Table

| Feature | DOL 1.x | DOL 2.0 |
|---------|---------|---------|
| Gene definitions | ✅ | ✅ |
| Trait definitions | ✅ | ✅ |
| Constraints (`rule`) | ✅ | ✅ Enhanced |
| Exegesis (`docs`) | ✅ | ✅ |
| Control flow | ❌ | ✅ `if/else/match/for/while/loop` |
| Functions with bodies | ❌ | ✅ |
| Lambda expressions | ❌ | ✅ `\|x: i64\| x * 2` |
| Pipe operators | ❌ | ✅ `\|>` `>>` `<\|` |
| Pattern matching | ❌ | ✅ With guards |
| Type inference | ❌ | ⚠️ Type checker exists; type errors are not enforced by `dol-check`/validator (0.8.2) |
| Meta-programming | ❌ | ✅ `'` `!` `#` `?` |
| Compiles to Rust | ❌ | ✅ |
| Compiles to WASM | ❌ | ✅ Beta, language subset (direct WASM backend; VUDO host ABI since 0.8.2) |
| Self-hosting | ❌ | ❌ Planned — not implemented |

---

## Language Features

### Operators by Category

#### Composition Operators

| Operator | Name | Description | Example |
|----------|------|-------------|---------|
| `\|>` | Pipe | Forward function application | `x \|> f` → `f(x)` |
| `>>` | Compose | Function composition (left-to-right) | `f >> g` → `(x) -> g(f(x))` |
| `<\|` | Back-pipe | Reverse function application | `f <\| x` → `f(x)` |
| `@` | Apply | Applicative apply | `f @ x` |
| `:=` | Bind | Monadic bind | `m := f` |

#### Meta-Programming Operators

| Operator | Name | Description | Example |
|----------|------|-------------|---------|
| `'` | Quote | Defer evaluation | `'expr` |
| `!` | Eval | Force evaluation | `!quoted` |
| `#` | Macro | Macro expansion | `#macro_name` |
| `?` | Reflect | Runtime reflection | `?type` |
| `[\|` | Idiom Open | Begin idiom bracket | `[\| f x y \|]` |
| `\|]` | Idiom Close | End idiom bracket | |

#### Control Flow Keywords

| Keyword | Description | Example |
|---------|-------------|---------|
| `if` | Conditional branch | `if x > 0 { ... }` |
| `else` | Alternative branch | `else { ... }` |
| `match` | Pattern matching | `match x { 0 { } _ { } }` |
| `for` | Iteration | `for item in items { }` |
| `while` | Conditional loop | `while x > 0 { }` |
| `loop` | Infinite loop | `loop { break }` |
| `break` | Exit loop | `break` |
| `continue` | Next iteration | `continue` |
| `return` | Return value | `return x` |
| `if` (in match arm) | Pattern guard | `x if x > 0 { ... }` |

#### Type & Lambda Operators

| Operator | Name | Description | Example |
|----------|------|-------------|---------|
| `->` | Arrow | Function return / function type | `(i64) -> bool` |
| `=>` | Fat Arrow | Constraint implication | `A => B` |
| `\|` | Bar | Union types / match arms | `A \| B` |
| `_` | Wildcard | Match anything | `match x { _ { } }` |

### Type System

#### Primitive Types

Since v0.8.0 "Clarity", DOL uses Rust-aligned lowercase type names. The legacy names (`Int32`, `String`, `Void`, …) still parse with deprecation warnings and become errors at v0.9.

| Type | Rust Equivalent | Legacy name (deprecated) |
|------|-----------------|-------------|
| `()` | `()` | `Void` |
| `bool` | `bool` | `Bool` |
| `i8` / `i16` / `i32` / `i64` / `i128` | same | `Int8` / `Int16` / `Int32` / `Int64` |
| `u8` / `u16` / `u32` / `u64` / `u128` | same | `UInt8` / `UInt16` / `UInt32` / `UInt64` |
| `f32` / `f64` | same | `Float32` / `Float64` |
| `string` | `String` | `String` |

#### Compound Types

| Type | Rust Equivalent | Example |
|------|-----------------|---------|
| `Vec<T>` | `Vec<T>` | `Vec<i32>` (legacy: `List<T>`) |
| `Map<K, V>` | `HashMap<K, V>` | `Map<string, i64>` |
| `Option<T>` | `Option<T>` | `Option<string>` |
| `Result<T, E>` | `Result<T, E>` | `Result<i32, string>` |
| `(A) -> B` | `fn(A) -> B` | `(i32) -> bool` |
| `(A, B, ...)` | `(A, B, ...)` | `(i32, string)` |

#### Type Inference

The type checker (`src/typechecker.rs`) implements **bidirectional type inference**. Note: as of 0.8.2 its results are **not enforced** — `validate_statement_types` is an empty placeholder, so a function such as `fun f() -> i64 { return "hello" + true }` passes `dol-check --typecheck`, HIR lowering and WASM compilation.

```dol
// Literals infer their types
fun literals() -> i64 {
  val x = 42          // x: i64 (inferred)
  val y = 3.14        // y: f64 (inferred)
  val z = "hello"     // z: string (inferred)
  return x
}

fun double(n: i32) -> i32 {
  return n * 2
}

fun increment(n: i32) -> i32 {
  return n + 1
}

// Pipes propagate types
fun piped() -> i32 {
  return 10 |> double >> increment
}
```

---

## Compiler Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        DOL 2.0 Compiler                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐    ┌─────────┐    ┌───────────┐    ┌───────────┐  │
│  │  Source │ -> │  Lexer  │ -> │   Parser  │ -> │    AST    │  │
│  │  (.dol) │    │         │    │  (Pratt)  │    │           │  │
│  └─────────┘    └─────────┘    └───────────┘    └─────┬─────┘  │
│                                                       │        │
│                                                       ▼        │
│                                               ┌───────────┐    │
│                                               │   Type    │    │
│                                               │  Checker  │    │
│                                               └─────┬─────┘    │
│                                                     │          │
│                     ┌───────────────────────────────┼────┐     │
│                     │                               │    │     │
│                     ▼                               ▼    ▼     │
│              ┌───────────┐                   ┌─────────────┐   │
│              │   Rust    │                   │    WASM     │   │
│              │  Codegen  │                   │   Codegen   │   │
│              └─────┬─────┘                   └──────┬──────┘   │
│                    │                                │          │
│                    ▼                                ▼          │
│              ┌───────────┐                   ┌───────────┐     │
│              │   .rs     │                   │   WASM    │     │
│              │  files    │                   │  binary   │     │
│              └───────────┘                   └───────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

> **Correction (0.8.2):** WASM is produced by a direct WASM backend (`src/wasm`), not via MLIR. `src/mlir` is a feature-gated stub that does not build without MLIR headers and is not in CI. The WASM backend works from the AST; HIR is kept for diagnostics only. Rust and TypeScript / JSON Schema codegen exist (`dol-codegen`); only 14 of 41 example files produce Rust that compiles standalone.

### Crate Structure

```
dol/
├── src/
│   ├── lib.rs              # Library root, re-exports
│   ├── lexer.rs            # Tokenization (logos)
│   ├── ast.rs              # Abstract Syntax Tree nodes
│   ├── parser.rs           # Recursive descent parser
│   ├── pratt.rs            # Pratt parser for expressions
│   ├── typechecker.rs      # Type inference & checking
│   ├── codegen/
│   │   ├── mod.rs          # Codegen traits
│   │   └── rust.rs         # Rust code generator
│   └── bin/
│       ├── dol-parse.rs    # Parse CLI
│       ├── dol-check.rs    # Type check CLI
│       ├── dol-test.rs     # Test runner CLI
│       └── dol-codegen.rs  # Code generation CLI
├── examples/
│   ├── genes/              # Gene definitions
│   ├── traits/             # Trait definitions
│   └── stdlib/             # Standard library (10 files)
└── tests/
    ├── lexer_tests.rs
    ├── parser_tests.rs
    ├── typechecker_tests.rs
    └── codegen_tests.rs
```

---

## Phase 1: Lexer & Parser

**Commit:** `91f4b4d`  
**Tests:** 272 passing  
**Status:** ✅ Complete

### Lexer (src/lexer.rs)

Built with [logos](https://github.com/maciejhirsz/logos) for high-performance tokenization.

#### Token Categories

| Category | Tokens |
|----------|--------|
| Keywords | `gen`, `trait`, `system`, `rule`, `evo`, `docs`, `fun`, `return`, `match`, `if`, `else`, `for`, `while`, `loop`, `break`, `continue`, `where`, `in`, `requires`, `law`, `type`, `has`, `is` (v0.8 preferred forms; legacy `gene`, `constraint`, `evolves`, `exegesis` are deprecated) |
| Types | `i8`…`i128`, `u8`…`u128`, `f32`, `f64`, `bool`, `string`, `()`, `Self` (v0.8; legacy `Int32`, `String`, `Void`, … are deprecated) |
| Operators | `\|>`, `>>`, `<\|`, `@`, `:=`, `->`, `=>`, `==`, `!=`, `>=`, `<=`, `>`, `<`, `+`, `-`, `*`, `/`, `%`, `&&`, `\|\|`, `!`, `'`, `#`, `?`, `[\|`, `\|]` |
| Delimiters | `{`, `}`, `(`, `)`, `[`, `]`, `:`, `,`, `.`, `_` |
| Literals | Integers, Floats, Strings, Booleans |
| Identifiers | `[a-zA-Z_][a-zA-Z0-9_]*` |

### Parser (src/parser.rs + src/pratt.rs)

Hybrid parser combining:
- **Recursive descent** for declarations (gene, trait, system)
- **Pratt parsing** for expressions with operator precedence

#### Operator Precedence Table

| Level | Operators | Associativity | Description |
|-------|-----------|---------------|-------------|
| 1 | `\|\|` | Left | Logical OR |
| 2 | `&&` | Left | Logical AND |
| 3 | `==` `!=` | Left | Equality |
| 4 | `<` `>` `<=` `>=` | Left | Comparison |
| 5 | `\|>` `<\|` | Left | Pipe |
| 6 | `>>` | Left | Compose |
| 7 | `:=` | Right | Bind |
| 8 | `@` | Left | Apply |
| 9 | `+` `-` | Left | Additive |
| 10 | `*` `/` `%` | Left | Multiplicative |
| 11 | `**` | Right | Power |
| 12 | `!` `-` `'` `?` | Prefix | Unary |
| 13 | `.` `()` `[]` | Left | Postfix/Call |

### AST Nodes (src/ast.rs)

```rust
// Top-level declarations
enum Declaration {
    Gene { name, body },
    Trait { name, type_params, body },
    System { name, body },
    Constraint { name, body },
    Evolution { from, to, body },
    Function { name, params, return_type, body },
}

// Expressions
enum Expr {
    Literal(Literal),
    Identifier(String),
    Binary { op, left, right },
    Unary { op, operand },
    Call { callee, args },
    Lambda { params, body },
    If { condition, then_branch, else_branch },
    Match { scrutinee, arms },
    Block { statements, expr },
    // ...
}

// Statements
enum Stmt {
    Let { name, type_ann, value },
    Expr(Expr),
    Return(Option<Expr>),
    For { var, iter, body },
    While { condition, body },
    Loop { body },
    Break,
    Continue,
}
```

---

## Phase 2: Type System

**Commit:** `ae0e688`  
**File:** `src/typechecker.rs` (1,193 lines)  
**Tests:** 87 passing  
**Status:** ⚠️ Implemented, but not enforced: as of 0.8.2 `validate_statement_types` (`src/validator.rs`) is an empty placeholder, so type errors do not fail validation, `dol-check --typecheck`, or compilation.

### Type Representation

```rust
enum Type {
    // Primitives
    Void, Bool,
    Int8, Int16, Int32, i64,
    UInt8, UInt16, UInt32, UInt64,
    Float32, Float64,
    String,
    
    // Compound
    Function { params: Vec<Type>, ret: Box<Type> },
    Tuple(Vec<Type>),
    
    // Parametric
    Generic { name: String, params: Vec<Type> },
    
    // Inference
    Var(usize),      // Type variable for unification
    Unknown,         // Not yet inferred
    Any,             // Accepts anything
    Error,           // Type error occurred
}
```

### Type Environment

```rust
struct TypeEnv {
    bindings: HashMap<String, Type>,
    parent: Option<Box<TypeEnv>>,
}

impl TypeEnv {
    fn child(&self) -> TypeEnv;       // Create nested scope
    fn bind(&mut self, name, ty);     // Add binding
    fn lookup(&self, name) -> Option<Type>;  // Find in scope chain
}
```

### Inference Rules

| Expression | Inferred Type |
|------------|---------------|
| `42` | `i64` |
| `3.14` | `f64` |
| `true` / `false` | `bool` |
| `"hello"` | `string` |
| `a + b` | Unify numeric types |
| `a && b` | `bool` (requires bool operands) |
| `a == b` | `bool` (requires same type operands) |
| `f(x)` | Return type of `f` |
| `x \|> f` | Return type of `f` |
| `f >> g` | `(A) -> C` where `f: A→B`, `g: B→C` |
| `\|x: T\| e` | `(T) -> typeof(e)` |
| `if c { a } else { b }` | Unify types of `a` and `b` |
| `match x { ... }` | Unify all arm types |

### Type Errors

```rust
enum TypeError {
    Mismatch { expected: Type, found: Type, span: Span },
    UndefinedVariable { name: String, span: Span },
    NotCallable { ty: Type, span: Span },
    ArityMismatch { expected: usize, found: usize, span: Span },
    NotNumeric { ty: Type, span: Span },
    IncompatibleBranches { then_ty: Type, else_ty: Type, span: Span },
}
```

---

## Phase 3: Code Generation

### 3.2: Rust Code Generator

**Commit:** `7c61b46`  
**File:** `src/codegen/rust.rs` (617 lines)  
**Tests:** 8 passing  
**Status:** ✅ Complete

#### DOL → Rust Mapping

Verified against `dol-codegen` 0.8.2:

| DOL Declaration | Generated Rust |
|-----------------|----------------|
| `gen Name { has field: type }` | `struct Name { field: Type }` plus `new()` |
| `trait name { has … / is … }` | `trait Name {}` (predicate statements produce no methods) |
| `rule name { … }` | `fn validate_name<T>(value: &T) -> bool { true }` — a stub; the rule body is not translated |
| `system name @ v { requires … }` | `mod name { /* requirements as doc comments */ }` |
| `evo name @ v2 > v1 { … }` | `/* Changelog comment */` |

#### Type Mapping

| DOL Type | Rust Type |
|----------|-----------|
| `i8` … `i128`, `u8` … `u128` | same |
| `f32`, `f64` | same |
| `bool` | `bool` |
| `string` | `String` |
| `()` | `()` |
| `Vec<T>` | `Vec<T>` |
| `Map<K, V>` | `std::collections::HashMap<K, V>` |
| `Option<T>` | `Option<T>` |
| `Result<T, E>` | `Result<T, E>` |

Legacy names (`Int32`, `String`, `Void`, `List<T>`, …) are still accepted with deprecation warnings.

#### Example: DOL → Rust

**Input (container.dol):**
```dol
gen Container {
  has id: u64
  has name: string
  has running: bool

  rule valid_id {
    this.id > 0
  }
}

docs {
  A container is an isolated execution environment.
}
```

**Output (container.rs)** — actual `dol-codegen` 0.8.2 output, header comments omitted:
```rust
/// A container is an isolated execution environment.
#[derive(Debug, Clone, PartialEq)]
pub struct Container {
    pub id: u64,
    pub name: String,
    pub running: bool,
}

impl Container {
    pub fn new(id: u64, name: String, running: bool) -> Self {
        Self {
            id,
            name,
            running,
        }
    }
}
```

> **Correction:** an earlier version of this page showed a generated `validate_valid_id()` method. That is not what
> the compiler does: a `rule` nested inside a `gen` is parsed but its body is dropped, so no validation code is emitted.

---

## CLI Tools

All CLI binaries require the `cli` feature: `cargo install dol --features cli`. At 0.8.2 the binaries are
`dol-parse`, `dol-check`, `dol-test`, `dol-codegen`, `dol-migrate`, `dol-mcp`, `dol-build` and `dol-build-crate`.

> **Known limitation (0.8.2):** `dol-parse` and `dol-check` only parse the **first declaration** in each file;
> everything after it is silently ignored. A green result does not mean the whole file parses.

### dol-parse

Parse DOL files and output AST:

```bash
# Parse single file
dol-parse examples/genes/container.exists.dol

# Output JSON AST (formats: pretty, json, compact, debug)
dol-parse --format json examples/genes/container.exists.dol

# Recurse into a directory and run validation
dol-parse --recursive --validate examples/
```

### dol-check

Validate DOL files (CI gate):

```bash
# Check single file
dol-check examples/genes/container.exists.dol

# Check directory
dol-check examples/

# Strict mode (warnings as errors)
dol-check --strict examples/

# Run the type checker (type errors are reported but not enforced at 0.8.2)
dol-check --typecheck examples/
```

### dol-test

Generate Rust tests from `.dol.test` specification files:

```bash
# Generate tests from a single file (default output: tests/generated)
dol-test examples/container.lifecycle.dol.test

# Generate stubs only (unimplemented!() bodies)
dol-test --stubs examples/container.lifecycle.dol.test
```

### dol-codegen

Generate code from DOL:

```bash
# Generate Rust (default)
dol-codegen examples/genes/container.exists.dol

# Output to file
dol-codegen -o generated.rs examples/genes/container.exists.dol

# Recursive directory processing
dol-codegen --recursive examples/

# Other targets: rust (default), typescript, jsonschema
dol-codegen --target typescript examples/genes/container.exists.dol
```

WASM is not a `dol-codegen` target. DOL → WASM is done by the library's direct WASM backend (`wasm-compile` feature), which is what the VUDO toolchain uses. `dol-build` (Spirit → Rust → wasm32) exists but fails on all 9 example Spirits at 0.8.2.

---

## Vocabulary System

DOL 2.0 maintains the **dual vocabulary** system for developer and creator audiences:

### Developer Vocabulary (Technical)

| Term | Description |
|------|-------------|
| Gene | Fundamental unit of specification |
| Trait | Interface contract with laws |
| System | Composed module of genes |
| Constraint | Validation rule |
| Evolution | Version migration path |
| Exegesis | Self-documentation |

### Creator Vocabulary (Mystical)

| Technical | Creator | Description |
|-----------|---------|-------------|
| Module | Spirit | Shareable .dol package |
| Function | Spell | Executable transformation |
| Session | Séance | Collaborative editing session |
| Service | Loa | Autonomous background service |
| Network | Mycelium | P2P communication fabric |
| Hub | Mitan | Central coordination point |
| Token | Gris-Gris | Authentication credential |
| Admin | Mambo | System administrator |
| Creator | Bondye | Original author |

---

## Roadmap: What's Next

> **Note:** "Year 1 / Year 2 / Year 3" and their quarters are relative planning labels, not calendar dates.
> Statuses below were corrected in November 2026 against the 0.8.2 code.

### Year 1: Genesis — "The language that writes itself"

| Quarter | Milestone | Status |
|---------|-----------|--------|
| Q1 | DOL Turing Extensions | ✅ Complete (v0.1.0) |
| | - Lexer + Parser | ✅ Complete |
| | - Type Checker | ⚠️ Exists; type errors not enforced (0.8.2) |
| | - Rust Codegen | ✅ Exists; only 14/41 example files produce Rust that compiles standalone |
| Q2 | Meta-Programming | ✅ Complete (v0.2.0) |
| | - Quote/Eval (`'`, `!`) | ✅ 34 tests |
| | - Idiom Brackets (`[| |]`) | ✅ 27 tests |
| | - Reflection (`?`) | ✅ 17 tests |
| | - 18 Built-in Macros (`#`) | ✅ 25+ tests |
| Q3 | MCP Server | ✅ `dol-mcp` (v0.2.1) |
| | - MLIR Codegen | ❌ Stub: feature-gated, does not build without MLIR headers, not in CI |
| | - WASM Backend | ✅ Beta: direct WASM backend covering a language subset |
| | - MCP Integration | ✅ Complete |
| Q4 | Self-Hosting | ❌ Planned — not implemented |
| | - DOL compiles DOL | ❌ Not real: the crate generated from the bootstrap sources fails with 850 compile errors |
| | - Bootstrap compiler | ❌ `stage1/` contains only a `Cargo.toml`; `stage2/` does not exist |

### Year 2: Manifestation — "The machine that runs Spirits"

| Quarter | Milestone | Status (Nov 2026) |
|---------|-----------|-------------------|
| Q1 | VUDO VM (WASM runtime) | ✅ Exists in `univrs/vudo`. Since DOL 0.8.2 (H0), DOL-compiled Spirits link and run in the VM; `univrs/vudo` CI compiles DOL → WASM and runs it |
| Q2 | DOLOS (Spirit orchestration) | ⏳ In progress: the `univrs-network` Spirit host runs `vudo_vm` but does not compile DOL |
| Q3 | Tauri IDE (Visual editor) | Planned — not implemented |
| Q4 | Mycelium Network (P2P) | ⏳ `mycelial-network` exists in `univrs-network`; Spirit exchange over it is planned — not implemented |

### Year 3: Emergence — "The garden that grows itself"

All Planned — not implemented.

| Quarter | Milestone |
|---------|-----------|
| Q1 | Mycelial Credits (Economics) |
| Q2 | Spirit Marketplace |
| Q3 | Browser IDE |
| Q4 | Imaginarium Launch |

### Current milestones (Nov 2026)

1. ✅ **H0 "toolchain truth"** (DOL 0.8.2): bodiless `sex fun host_*` declarations import from WASM module `vudo` with the VUDO VM linker's exact signatures (15 host functions, `src/wasm/host_abi.rs`).
2. ⏳ **H1+**: Spirit lifecycle and fuel limits, in progress in `univrs-vudo` / `univrs-network` (not yet documented in the dol repo).
3. ⏳ **v0.9**: legacy keywords and PascalCase types become errors (planned).
4. Self-hosting, package registry, LSP server: Planned — not implemented.
5. 1.0: exit criteria not yet defined.

---

## Migration Guide: DOL 1.x → 2.0

### Backward Compatibility

The DOL 1.x declaration forms (`gene`, `trait`, `constraint`, `system`, `evolves`, `exegesis`) still parse, but since
v0.8.0 the old keywords and PascalCase type names emit **deprecation warnings** and are planned to become **errors in
v0.9**. Use `dol-migrate 0.7-to-0.8 <path>` to convert files to the v0.8 syntax.

> **Correction:** an earlier version claimed "10/10 stdlib files pass". Parsed as whole files at 0.8.2, only 1 of 8
> stdlib files parses (the CLI only checks the first declaration in a file, which inflated earlier pass rates).

### New Features Available

When migrating, you can optionally adopt:

#### 1. Function Bodies

```dol
// DOL 1.x style: declaration only
gen math.ops {
  math has add
}

// Functions with bodies
fun add(a: i32, b: i32) -> i32 {
  return a + b
}
```

#### 2. Pattern Matching

```dol
fun describe(n: i32) -> string {
  match n {
    0 { return "zero" }
    x if x > 0 { return "positive" }
    _ { return "negative" }
  }
}
```

#### 3. Pipe Operators

```dol
fun process(x: i32) -> i32 {
  return x |> validate >> transform |> finalize
}
```

#### 4. Lambda Expressions

```dol
fun lambdas(items: Vec<i64>) -> Vec<i64> {
  val doubled = items.map(|x: i64| x * 2)
  return doubled.filter(|x: i64| x > 0)
}
```

### Breaking Changes

None between DOL 1.x and the first DOL 2.0 releases. Since v0.8.0, the old keywords and type names are deprecated
(warnings) and are planned to become errors in v0.9.

---

## Contributing

### Development Setup

```bash
# Clone repository
git clone https://github.com/univrs/dol.git
cd dol

# Build
cargo build

# Run tests
cargo test

# Run all tests with output
cargo test -- --nocapture

# Format code
cargo fmt

# Lint
cargo clippy
```

### Test Coverage

| Module | Tests | Status |
|--------|-------|--------|
| Lexer | 80+ | ✅ |
| Parser | 150+ | ✅ |
| Type Checker | 87 | ✅ |
| Rust Codegen | 8 | ✅ |
| **Total** | **367** | ✅ |

The table above is the count at the time of the original checkpoint. At 0.8.2 the root crate has **2,183** passing tests with default features and **2,405** with `--features cli,serde,wasm` (0 failures). The `crates/*`, `apps/*` and `llvm-backend` sub-projects are not built in CI.

### Adding New Features

1. Write failing test in `tests/`
2. Implement feature in `src/`
3. Run `cargo test`
4. Run `cargo fmt && cargo clippy`
5. Submit PR

### Documentation

- **API Docs:** `cargo doc --open`
- **Book:** [book.univrs.io](https://book.univrs.io)
- **Learn:** [learn.univrs.io](https://learn.univrs.io)

---

## References

- [DOL CHANGELOG](https://github.com/univrs/dol/blob/main/CHANGELOG.md) (no DOL 2.0 specification document exists; the parser source is the de facto spec)
- [VUDO Landing](https://vudo.univrs.io)
- [Univrs Documentation](https://learn.univrs.io)
- [GitHub Repository](https://github.com/univrs/dol)

---

*"Systems designed to evolve and adapt to change."*

— The VUDO Team
