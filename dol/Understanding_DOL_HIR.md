---
title: Understanding DOL HIR
description: How High-level Intermediate Representation powers the DOL ecosystem
sidebar_position: 6
---

# Understanding DOL HIR

> The language beneath the language

When you write DOL code, the compiler doesn't go straight from your source to Rust or WASM. It first transforms your code into **HIR (High-level Intermediate Representation)** — a normalized, canonical form that captures *what your code means* without any of the syntax variations.

This guide explains what HIR is, why it matters, and how it enables powerful features across the DOL/VUDO ecosystem.

## What Problem Does HIR Solve?

Consider these three DOL expressions:

```dol
// Version 1: Pipe style
result = data |> filter(valid) |> map(transform) |> collect

// Version 2: Nested calls
result = collect(map(transform, filter(valid, data)))

// Version 3: Intermediate variables
filtered = filter(valid, data)
transformed = map(transform, filtered)
result = collect(transformed)
```

All three do exactly the same thing. But as source text, they look completely different. This creates problems:

- **Search**: How do you find "code that filters then transforms"?
- **Diffing**: Refactoring style changes look like major rewrites
- **Verification**: Proving equivalence requires understanding all syntax forms
- **Caching**: Different formatting → different hashes → cache misses

HIR solves this by normalizing all three to the same representation:

```
Call(collect, [
    Call(map, [transform,
        Call(filter, [valid, data])
    ])
])
```

Same meaning → same HIR → same hash.

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
│   Output    │   Rust, TypeScript, WASM, etc.
└─────────────┘
```

The key insight: **HIR is the last representation where DOL concepts (genes, traits, constraints) are visible**. After this, code becomes platform-specific.

## What HIR Looks Like

HIR has intentionally few forms. Everything else desugars into these:

### Expressions (10 core forms)

| HIR Form | What It Represents |
|----------|-------------------|
| `Literal` | Numbers, strings, booleans |
| `Var` | Variable references (by index, not name) |
| `Call` | Function application (including all pipes!) |
| `Lambda` | Anonymous functions |
| `Match` | Pattern matching (including if/else) |
| `Loop` | All loop forms unified |
| `Seq` | Statement sequences |
| `Struct` | Record construction |
| `Field` | Member access |
| `Array` | Collection construction |

### Desugaring Examples

Your beautiful syntax becomes simple HIR:

```dol
// DOL: Pipe operator
x |> double |> increment

// HIR: Nested calls
Call(increment, [Call(double, [Var(x)])])
```

```dol
// DOL: Function composition
transform = double >> increment

// HIR: Lambda wrapping calls
Lambda([x], Call(increment, [Call(double, [Var(x)])]))
```

```dol
// DOL: If expression
if active { start() } else { stop() }

// HIR: Match on boolean
Match(Var(active), [
    (true, Call(start, [])),
    (false, Call(stop, []))
])
```

```dol
// DOL: For loop
for item in items { process(item) }

// HIR: Higher-order function
Call(for_each, [Var(items), Lambda([item], Call(process, [Var(item)]))])
```

## Why This Matters for You

### 1. Semantic Search in Imaginarium

When you search for Spirits, you're searching HIR, not text:

```
Query: "functions that transform images"

// This finds Spirits even if they use different syntax styles
// Because the query matches on HIR structure:
// - Function with input type matching Image<*>
// - Output type different from input
// - No side effects (Pure)
```

### 2. Smart Diffs When Evolving Spirits

When you update a Spirit, the diff shows semantic changes:

```
Spirit v1.0.0 → v2.0.0

Added:
  + process_batch(items: List<Item>) -> List<Result>
  
Changed:
  ~ process(item: Item) → process(item: Item, timeout: Duration)
    (added parameter)

Unchanged:
  = validate, transform, export (semantically identical)
  
Note: 127 lines changed in source, but only 2 semantic changes
```

### 3. Verified Spirit Composition

Before connecting Spirits in VUDO, the system checks compatibility:

```dol
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

HIR enables proving constraints hold statically:

```dol
gen Account {
    has balance: i64
    
    constraint never_negative {
        this.balance >= 0
    }
    
    fun withdraw(amount: i64) {
        if amount <= this.balance {
            this.balance = this.balance - amount
        }
    }
}

// HIR analyzer proves:
// ✓ withdraw() maintains never_negative
//   - Only modifies balance when amount <= balance
//   - Subtraction cannot produce negative result
//   - All paths preserve invariant
```

### 5. Deterministic Hashing for Trust

In the Mycelium network, Spirits are identified by HIR hash:

```
Spirit: @alice/image-tools v1.2.0
HIR Hash: sha256:7f3a8b2c...

// Any node can verify:
// 1. Parse source → HIR
// 2. Compute hash
// 3. Compare with published hash
// 4. If match → trust established
```

This works because same source always produces identical HIR, regardless of who compiles it or where.

## Content Addressing Deep Dive

Every HIR module has a content-derived identifier:

```dol
module_id = hash(canonical_serialize(hir_module))
```

This enables powerful patterns:

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

HIR tracks effects explicitly:

```dol
// DOL function with side effects
sex fun save_file(path: String, data: String) {
    // ... file operations
}

// HIR representation includes effect annotation
HirFunction {
    name: "save_file",
    effects: { IO, State },  // Explicit!
    body: ...
}
```

This enables:

- **Effect-based search**: "Find pure functions only"
- **Composition safety**: "These Spirits have incompatible effects"
- **Optimization**: "This code can be parallelized (no shared state)"

## Working with HIR (Advanced)

### Inspecting HIR

```bash
# View HIR for a DOL file
dol hir src/my-module.dol

# Output HIR as JSON (for tooling)
dol hir --format json src/my-module.dol

# Compare HIR of two versions
dol hir-diff v1/module.dol v2/module.dol
```

### HIR in MCP (AI Integration)

AI agents can query and manipulate HIR:

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

Response gives the AI structured understanding of your code, enabling intelligent suggestions and transformations.

### Custom HIR Analysis

Write your own analyzers:

```dol
use dol.hir.{HirModule, HirExpr, HirFunction}

/// Find all functions that might panic
fun find_panic_paths(module: HirModule) -> List<PanicPath> {
    let paths = []
    
    for func in module.functions {
        let panics = analyze_panic_potential(func.body)
        if panics.length() > 0 {
            paths.push(PanicPath { 
                function: func.name, 
                paths: panics 
            })
        }
    }
    
    return paths
}
```

## Summary

HIR is the semantic foundation of DOL:

| Aspect | What HIR Provides |
|--------|-------------------|
| **Compilation** | Normalized target for all backends |
| **Search** | Semantic queries across Spirits |
| **Diffing** | Meaningful change detection |
| **Verification** | Static constraint proving |
| **Caching** | Deterministic, content-addressed |
| **Trust** | Verifiable compilation |
| **AI** | Structured code understanding |

You don't usually interact with HIR directly—it works behind the scenes. But understanding it helps you:

- Write code that composes well with others' Spirits
- Trust that your Spirits are verified correctly
- Use ecosystem tools effectively
- Contribute to DOL tooling

---

## Further Reading

- [HIR Architecture Rationale](dol/HIR_ARCHITECTURE.md) — Deep technical dive

### Coming Soon

These guides are planned for future releases:
- **Spirit Composition Guide** — Practical composition patterns (Year 2)
- **Mycelium Trust Model** — How HIR enables distributed trust (Year 2-3)
- **MCP Integration** — AI tooling with HIR (Q3-Q4)

---

*HIR: The meaning beneath the syntax.*
