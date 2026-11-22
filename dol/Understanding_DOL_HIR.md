---
title: Understanding DOL HIR
description: How High-level Intermediate Representation powers the DOL ecosystem
sidebar_position: 6
---

# Understanding DOL HIR

> The language beneath the language

When you write DOL code and generate Rust, the compiler doesn't go straight from your source to Rust. It first transforms your code into **HIR (High-level Intermediate Representation)** — a normalized, canonical form that captures *what your code means* without any of the syntax variations.

This guide explains what HIR is, why it matters, and how it is intended to enable features across the DOL/VUDO ecosystem.

> **Status (DOL 0.8.2):** AST → HIR lowering is real (`metadol::lower::lower_file`), and HIR feeds the Rust code generator (`src/codegen/hir_rust.rs`). The WASM backend compiles directly from the AST and uses HIR only for diagnostics; TypeScript and JSON Schema codegen also work from the AST. HIR content hashing, effect annotations, semantic search/diff, composition checking and constraint proving are **planned — not implemented**. Sections below are marked accordingly.

## What Problem Does HIR Solve?

Consider these three DOL expressions:

```dol
fun version1(data: Vec<i64>) -> Vec<i64> {
    // Version 1: Pipe style
    return data |> filter(valid) |> map(transform) |> collect
}

fun version2(data: Vec<i64>) -> Vec<i64> {
    // Version 2: Nested calls
    return collect(map(transform, filter(valid, data)))
}

fun version3(data: Vec<i64>) -> Vec<i64> {
    // Version 3: Intermediate variables
    val filtered = filter(valid, data)
    val transformed = map(transform, filtered)
    return collect(transformed)
}
```

All three do exactly the same thing. But as source text, they look completely different. This creates problems:

- **Search**: How do you find "code that filters then transforms"?
- **Diffing**: Refactoring style changes look like major rewrites
- **Verification**: Proving equivalence requires understanding all syntax forms
- **Caching**: Different formatting → different hashes → cache misses

HIR's goal is to normalize all three to the same representation (in 0.8.2 the pipe forms lower to nested `Call`s; version 3 still lowers to separate `val` statements):

```
Call(collect, [
    Call(map, [transform,
        Call(filter, [valid, data])
    ])
])
```

Same meaning → same HIR → same hash (hashing is planned — not implemented).

## HIR in the Compilation Pipeline

```
┌─────────────┐
│ DOL Source  │   Your .dol files with pipes, lambdas, sugar
└──────┬──────┘
       │ parse
       ▼
┌─────────────┐
│    AST      │   Syntax tree preserving all source structure
└──────┬──────┘
       │ lower
       ▼
┌─────────────┐
│    HIR      │   Normalized semantic representation ← YOU ARE HERE
└──────┬──────┘
       │ codegen
       ▼
┌─────────────┐
│   Output    │   Rust (via HIR)
└─────────────┘
```

> In 0.8.2 only the Rust backend runs through HIR. WASM, TypeScript and JSON Schema are generated directly from the AST.

The key insight: **HIR is the last representation where DOL concepts (genes, traits, constraints) are visible**. After this, code becomes platform-specific.

## What HIR Looks Like

HIR has intentionally few forms. Everything else desugars into these (`src/hir/types.rs`, DOL 0.8.2):

### Expressions (12 forms)

| HIR Form | What It Represents |
|----------|-------------------|
| `Literal` | Numbers, strings, booleans, unit |
| `Var` | Variable references (by interned symbol) |
| `Binary` / `Unary` | Operators |
| `Call` | Function application (including pipes) |
| `MethodCall` | Method calls |
| `Field` / `Index` | Member and index access |
| `Block` | Statement sequences with optional result |
| `If` | Conditionals |
| `Match` | Pattern matching |
| `Lambda` | Anonymous functions |

Statements have 6 forms (`Val`, `Var`, `Assign`, `Expr`, `Return`, `Break`); there are also 4 declaration forms, 8 type forms and 6 pattern forms.

### Desugaring Examples

Your syntax becomes simpler HIR:

```dol
fun pipe_example(x: i64) -> i64 {
    // DOL: Pipe operator
    return x |> double |> increment
}
```

```text
// HIR: Nested calls
Call(increment, [Call(double, [Var(x)])])
```

```dol
fun compose_example() -> i64 {
    // DOL: Function composition
    val transform = double >> increment
    return transform(1)
}
```

```text
// HIR: Lambda wrapping calls
Lambda([x], Call(increment, [Call(double, [Var(x)])]))
```

```dol
fun if_example(active: bool) {
    // DOL: If expression
    if active { start() } else { stop() }
}
```

```text
// HIR: If is kept as its own form
If(Var(active), Block([Call(start, [])]), Block([Call(stop, [])]))
```

```dol
fun for_example(items: Vec<i64>) {
    // DOL: For loop
    for item in items { process(item) }
}
```

```text
// HIR (simplified in 0.8.2): a block containing a match on next()
Block([Match(Call(next, [...]), [
    (Some(item), Block([Call(process, [Var(item)])])),
    (None, Block([Break]))
])])
```

## Why This Matters for You

> **Planned — not implemented.** Items 1–5 below describe the intended ecosystem. None of them (Imaginarium semantic search, semantic diffs, composition checking, static constraint proving, HIR hashing in the Mycelium network) exists in DOL 0.8.2.

### 1. Semantic Search in Imaginarium

When you search for Spirits, you would be searching HIR, not text:

```
Query: "functions that transform images"

// This finds Spirits even if they use different syntax styles
// Because the query matches on HIR structure:
// - Function with input type matching Image<*>
// - Output type different from input
// - No side effects (Pure)
```

### 2. Smart Diffs When Evolving Spirits

When you update a Spirit, the diff would show semantic changes:

```
Spirit v1.0.0 → v2.0.0

Added:
  + process_batch(items: Vec<Item>) -> Vec<Result>
  
Changed:
  ~ process(item: Item) → process(item: Item, timeout: Duration)
    (added parameter)

Unchanged:
  = validate, transform, export (semantically identical)
  
Note: 127 lines changed in source, but only 2 semantic changes
```

### 3. Verified Spirit Composition

Before connecting Spirits in VUDO, the system would check compatibility:

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
// Composing three Spirits
pipeline = ImageLoader >> ColorTransformer >> Exporter

// HIR analysis reveals:
// ✓ ImageLoader outputs Image<RGB>
// ✓ ColorTransformer accepts Image<*>
// ✓ ColorTransformer outputs Image<Grayscale>
// ✗ Exporter expects Image<RGB>, not Image<Grayscale>
//
// Suggestion: Insert GrayscaleToRgb adapter at position 2
```

### 4. Constraint Verification Without Running

HIR would enable proving constraints hold statically. (In 0.8.2 a `rule` nested inside a `gen` parses but its body is dropped, and the type checker does not enforce statement types.)

> **Planned — not implemented:** static constraint proving does not exist in DOL 0.8.2; the code below parses but nothing verifies it.

```dol
gen Account {
    has balance: i64
    
    rule never_negative {
        this.balance >= 0
    }
    
    fun withdraw(amount: i64) {
        if amount <= this.balance {
            this.balance = this.balance - amount
        }
    }
}

// Planned: an HIR analyzer would prove:
// ✓ withdraw() maintains never_negative
//   - Only modifies balance when amount <= balance
//   - Subtraction cannot produce negative result
//   - All paths preserve invariant
```

### 5. Deterministic Hashing for Trust

In the Mycelium network, Spirits would be identified by HIR hash:

```
Spirit: @alice/image-tools v1.2.0
HIR Hash: sha256:7f3a8b2c...

// Any node can verify:
// 1. Parse source → HIR
// 2. Compute hash
// 3. Compare with published hash
// 4. If match → trust established
```

This would work because the same source always produces identical HIR, regardless of who compiles it or where.

## Content Addressing Deep Dive

> **Planned — not implemented:** HIR modules have no content-derived identifier in DOL 0.8.2 (`HirId` is a plain `u32`). The patterns and numbers below are illustrative, not measured.

Every HIR module would have a content-derived identifier:

```text
module_id = hash(canonical_serialize(hir_module))
```

This would enable:

### Deduplication

```
// Two developers independently write the same helper
// Both produce identical HIR → same hash → stored once

@alice/utils/string-helpers  →  hir:sha256:abc123
@bob/common/text-utils       →  hir:sha256:abc123

// Mycelium stores one copy, both reference it
```

### Incremental Caching

```
// You change one function in a large module
// Only that function's HIR changes
// Other functions: cache hit
// Changed function: recompile

Compile time: 50ms (vs 2s full rebuild)
```

### Attribution Chains

```
// Carol forks Alice's Spirit, adds features
// HIR shows which parts came from Alice

@carol/extended-tools:
  Functions from @alice/original: 12 (attributed)
  Functions added by Carol: 3 (new)
  
// Alice receives credit for her contribution
```

## HIR and Effects (SEX System)

> **Planned — not implemented:** HIR functions in 0.8.2 carry no effect annotations; `sex` is tracked only in the AST.

HIR would track effects explicitly:

```dol
// DOL function with side effects
sex fun save_file(path: string, data: string) {
    // ... file operations
}
```

```text
// Planned HIR representation with effect annotation
HirFunction {
    name: "save_file",
    effects: { IO, State },  // Explicit!
    body: ...
}
```

This would enable:

- **Effect-based search**: "Find pure functions only"
- **Composition safety**: "These Spirits have incompatible effects"
- **Optimization**: "This code can be parallelized (no shared state)"

## Working with HIR (Advanced)

### Inspecting HIR

There is no `dol` binary and no HIR command in the CLI (0.8.2 ships `dol-parse`, `dol-check`, `dol-test`, `dol-codegen`, `dol-migrate`, `dol-mcp`, `dol-build`, `dol-build-crate`). HIR is available through the Rust library API of the `dol` crate (library name `metadol`):

```rust
let (hir, ctx) = metadol::lower::lower_file(source)?;
let mut printer = metadol::hir::print::HirPrinter::new(&ctx.symbols);
printer.print_module(&hir);
println!("{}", printer.finish());
```

### HIR in MCP (AI Integration)

> **Planned — not implemented:** `dol-mcp` has no HIR tool (its tools include `parse`, `typecheck`, `compile_rust`, `compile_wasm`, `list_macros`, `expand_macro`, `recommend_crdt`).

AI agents would be able to query HIR:

```json
{
    "tool": "dol/hir/query",
    "params": {
        "spirit": "@univrs/scheduler",
        "find": "functions",
        "where": {
            "calls_any": ["database.*", "network.*"],
            "effects_include": "IO"
        }
    }
}
```

The response would give the AI structured understanding of your code, enabling intelligent suggestions and transformations.

### Custom HIR Analysis

Custom analyzers are written in Rust against the `metadol::hir` API, e.g. by implementing the `metadol::hir::visit::HirVisitor` trait and walking a lowered module with `walk_module`. Writing HIR analyzers in DOL itself is planned — not implemented.

## Summary

HIR is the intended semantic foundation of DOL:

| Aspect | What HIR Provides | Status (0.8.2) |
|--------|-------------------|----------------|
| **Compilation** | Normalized target for backends | Rust backend only; WASM/TS/JSON Schema use the AST |
| **Search** | Semantic queries across Spirits | Planned — not implemented |
| **Diffing** | Meaningful change detection | Planned — not implemented |
| **Verification** | Static constraint proving | Planned — not implemented |
| **Caching** | Deterministic, content-addressed | Planned — not implemented |
| **Trust** | Verifiable compilation | Planned — not implemented |
| **AI** | Structured code understanding | Planned — not implemented |

You don't usually interact with HIR directly—it works behind the scenes. Understanding it helps you contribute to DOL tooling.

---

## Further Reading

- [HIR Architecture Rationale](HIR_ARCHITECTURE.md) — Deep technical dive

### Coming Soon

Planned — not implemented (no dates committed):
- **Spirit Composition Guide** — Practical composition patterns
- **Mycelium Trust Model** — How HIR would enable distributed trust
- **MCP Integration** — AI tooling with HIR

---

*HIR: The meaning beneath the syntax.*
