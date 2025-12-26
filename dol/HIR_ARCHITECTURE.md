# DOL HIR Architecture Rationale

> **Document Version:** 1.0.0  
> **Status:** Approved  
> **Last Updated:** December 2025  
> **Authors:** Univrs Core Team  
> **Location:** univrs-docs/dol/HIR-ARCHITECTURE.md

---

## Executive Summary

This document defines the architectural rationale for DOL's High-level Intermediate Representation (HIR). HIR is not merely a compiler implementation detail—it is the **canonical semantic representation** that unifies the entire DOL/VUDO/Univrs ecosystem.

Every tool that needs to understand DOL code speaks HIR: compilers, analyzers, search engines, verifiers, diff tools, and AI agents. This shared foundation enables ecosystem-wide interoperability, deterministic compilation, and semantic operations that would be impossible with source text alone.

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Design Goals](#design-goals)
3. [Architecture Overview](#architecture-overview)
4. [HIR Specification](#hir-specification)
5. [Ecosystem Integration](#ecosystem-integration)
6. [Content Addressing](#content-addressing)
7. [Comparison with Alternatives](#comparison-with-alternatives)
8. [Implementation Strategy](#implementation-strategy)
9. [Future Directions](#future-directions)

---

## Problem Statement

### The Challenge of Source-Level Operations

Operating directly on DOL source code creates several ecosystem-wide problems:

| Problem | Impact |
|---------|--------|
| **Non-determinism** | Same logic with different formatting produces different hashes |
| **Parsing overhead** | Every tool must parse source, duplicating effort |
| **Syntax coupling** | Tools break when syntax evolves |
| **Shallow analysis** | Text-based tools miss semantic meaning |
| **Difficult composition** | Verifying Spirit compatibility requires execution |

### Concrete Examples

**Scenario 1: Imaginarium Search**

A user searches for "Spirits that transform images to grayscale". Text search finds keyword matches. Semantic search on HIR finds:

```
Functions where:
  - input type matches Image<*>
  - output type matches Image<Grayscale>
  - OR trait implementation includes Transformer<Image, Grayscale>
```

**Scenario 2: Evolution Diffing**

Developer refactors code, changing 500 lines. Text diff shows chaos. HIR diff shows:

```
Changed: process() - added timeout parameter
Added: process_batch() - new function
Unchanged: All other functions (semantically identical)
```

**Scenario 3: Distributed Verification**

Node A compiles a Spirit. Node B wants to verify without re-parsing. With source:

```
Node A: source → parse → compile → hash(binary) = X
Node B: source → parse → compile → hash(binary) = Y  (different whitespace handling!)
```

With HIR:

```
Node A: source → HIR → hash(HIR) = X
Node B: source → HIR → hash(HIR) = X  ✓ Deterministic
```

---

## Design Goals

### Primary Goals

1. **Canonical Representation**
   - Same semantic meaning produces identical HIR
   - Formatting, comments, sugar variations normalize away

2. **Minimal Core**
   - 10-15 expression forms maximum
   - Everything else desugars to core forms
   - Simpler tools, fewer edge cases

3. **Complete Coverage**
   - Every DOL construct representable in HIR
   - No semantic loss during lowering
   - Round-trip possible (HIR → source)

4. **Content Addressable**
   - Every HIR node hashable
   - Enables deduplication, caching, verification
   - Foundation for Mycelium distributed operations

5. **Analysis Friendly**
   - Structure supports pattern matching
   - Type information always present
   - Effect annotations explicit

### Non-Goals

- HIR is **not** optimized for execution (that's Target IR)
- HIR is **not** a serialization format for source (that's the parser's job)
- HIR does **not** preserve source formatting (intentionally)

---

## Architecture Overview

### Position in Compilation Pipeline

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ DOL Source  │────►│   Parser    │────►│   AST       │────►│   Lower     │
│   (.dol)    │     │             │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └──────┬──────┘
                                                                   │
                                                                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Output    │◄────│   Backend   │◄────│  Optimize   │◄────│    HIR      │
│ (rs/ts/wasm)│     │             │     │  (optional) │     │  (canonical)│
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

### HIR as Ecosystem Hub

```
                              ┌─────────────────┐
                              │   Imaginarium   │
                              │  Search/Index   │
                              └────────┬────────┘
                                       │
┌──────────────┐                       │                 ┌──────────────┐
│  DOL Source  │───┐                   │                 │   AI/MCP     │
└──────────────┘   │                   │                 │   Agents     │
                   │    ┌──────────────┴──────────────┐  └──────┬───────┘
┌──────────────┐   │    │                             │         │
│ Visual Editor│───┼───►│      HIR (Canonical)        │◄────────┤
│   (Tauri)    │   │    │                             │         │
└──────────────┘   │    └──────────────┬──────────────┘  ┌──────┴───────┐
                   │                   │                 │   Verifier   │
┌──────────────┐   │                   │                 │   (Proofs)   │
│  Séance      │───┘    ┌──────────────┼──────────────┐  └──────────────┘
│  (Collab)    │        │              │              │
└──────────────┘        ▼              ▼              ▼
                   ┌─────────┐   ┌─────────┐   ┌─────────┐
                   │  Rust   │   │  WASM   │   │   TS    │
                   │ Backend │   │ Backend │   │ Backend │
                   └─────────┘   └─────────┘   └─────────┘
```

---

## HIR Specification

### Core Types

#### HirModule

Top-level compilation unit:

```dol
gene HirModule {
    has id: ContentHash          // SHA-256 of normalized content
    has name: String             // Module path (e.g., "dol.parser")
    has version: Version         // Semantic version
    has imports: List<HirImport>
    has exports: List<String>
    has types: List<HirTypeDecl>
    has functions: List<HirFunction>
    has traits: List<HirTrait>
    has constraints: List<HirConstraint>
}
```

#### HirExpr

Normalized expression forms (exhaustive list):

```dol
gene HirExpr {
    type: enum {
        // Atoms
        Literal { value: HirLiteral, ty: HirType }
        Var { index: LocalIndex, ty: HirType }
        
        // Function application (all calls, pipes, compose normalize here)
        Call { func: Box<HirExpr>, args: List<HirExpr>, ty: HirType }
        
        // Abstraction
        Lambda { 
            params: List<HirParam>, 
            captures: List<LocalIndex>,
            body: Box<HirExpr>, 
            ty: HirType 
        }
        
        // Control flow
        Match { 
            scrutinee: Box<HirExpr>, 
            arms: List<HirMatchArm>,
            ty: HirType 
        }
        Loop { 
            body: Box<HirExpr>,
            ty: HirType  // type of break value
        }
        
        // Sequencing
        Seq { 
            stmts: List<HirStmt>,
            result: Box<HirExpr>,
            ty: HirType
        }
        
        // Data construction
        Struct { name: String, fields: List<(String, HirExpr)>, ty: HirType }
        Tuple { elements: List<HirExpr>, ty: HirType }
        Array { elements: List<HirExpr>, ty: HirType }
        
        // Data access
        Field { object: Box<HirExpr>, name: String, ty: HirType }
        Index { object: Box<HirExpr>, index: Box<HirExpr>, ty: HirType }
        
        // Special
        Return { value: Option<Box<HirExpr>>, ty: HirType }
        Break { value: Option<Box<HirExpr>>, ty: HirType }
        Continue { ty: HirType }
    }
}
```

#### Desugaring Rules

| DOL Syntax | HIR Form |
|------------|----------|
| `x \|> f` | `Call { func: f, args: [x] }` |
| `f >> g` | `Lambda { body: Call { func: g, args: [Call { func: f, args: [Var(0)] }] } }` |
| `f <\| x` | `Call { func: f, args: [x] }` |
| `[| f x y |]` | `Call { func: "apply", args: [Call { func: "map", args: [x, f] }, y] }` |
| `if c { a } else { b }` | `Match { scrutinee: c, arms: [true→a, false→b] }` |
| `for x in iter { body }` | `Call { func: "for_each", args: [iter, Lambda { body }] }` |
| `while c { body }` | `Loop { body: Match { scrutinee: c, arms: [true→body, false→Break] } }` |

### Effect System

Every function carries effect annotations:

```dol
gene HirEffects {
    type: enum {
        Pure           // No side effects
        IO             // File, network, console
        State          // Mutable state access
        Panic          // May panic/abort
        FFI            // Foreign function calls
        Async          // Async operations
    }
}

gene HirFunction {
    has name: String
    has params: List<HirParam>
    has return_type: HirType
    has effects: Set<HirEffects>  // Effect annotation
    has body: HirExpr
}
```

Effects map to DOL's SEX system:
- `sex fun` → effects include State, IO, FFI as appropriate
- `sex { }` block → effects propagate to enclosing function
- Pure functions → effects = { Pure }

---

## Ecosystem Integration

### 1. Imaginarium Search

HIR enables semantic search across published Spirits:

```dol
// Search query as HIR pattern
query: HirPattern = HirPattern {
    kind: Function,
    where: [
        input_matches("Image<*>"),
        output_matches("Image<Grayscale>"),
        effects_subset({ Pure, State })
    ]
}

// Index structure
index: SpiritIndex = {
    by_trait: Map<TraitName, List<SpiritId>>,
    by_signature: Map<SignatureHash, List<SpiritId>>,
    by_effect: Map<EffectSet, List<SpiritId>>,
    by_structure: HirPatternTree
}

// Query execution
results = index.query(query)
```

### 2. Evolution Diffing

Compare Spirit versions semantically:

```dol
diff: HirDiff = hir_diff(spirit_v1, spirit_v2)

// Returns structured changes
diff.added      // New functions, types, traits
diff.removed    // Deleted items
diff.changed    // Modified signatures or bodies
diff.renamed    // Detected renames (same body, different name)
diff.moved      // Reorganized but equivalent
```

### 3. Constraint Verification

Prove constraints statically by analyzing HIR:

```dol
constraint BalanceNonNegative {
    this.balance >= 0
}

// Analyzer walks HIR looking for:
// 1. All assignments to balance
// 2. Whether each assignment provably maintains >= 0
// 3. Generate proof or counterexample

result: VerifyResult = verify_constraint(account_hir, "BalanceNonNegative")
match result {
    Verified { proof } { /* Constraint proven */ }
    Counterexample { path, values } { /* Found violation */ }
    Unknown { reason } { /* Could not determine */ }
}
```

### 4. Spirit Composition

Verify Spirits compose correctly before execution:

```dol
// Check type compatibility at Spirit boundaries
check: ComposeResult = check_composition([
    ("@alice/image-loader", "load"),
    ("@bob/transformer", "transform"),
    ("@carol/exporter", "export")
])

match check {
    Compatible { pipeline } { /* Wire them up */ }
    TypeMismatch { from, to, position } { 
        suggest_adapter(from, to)
    }
    EffectConflict { effects } {
        /* Incompatible effect requirements */
    }
}
```

### 5. Distributed Compilation

Share compilation work across Mycelium nodes:

```
Node A (resource-limited):
    source.dol → HIR (lightweight operation)
    broadcast: HIR + hash to network

Node B (powerful):
    receive: HIR
    verify: hash(HIR) matches
    compile: HIR → optimized WASM
    return: WASM binary + proof

Node A:
    verify: proof is valid
    cache: WASM by HIR hash
    execute: WASM
```

### 6. AI Agent Integration (MCP)

Expose HIR via Model Context Protocol:

```json
{
    "tool": "dol/hir/query",
    "params": {
        "spirit": "@univrs/scheduler",
        "query": {
            "find": "functions",
            "where": { "calls": "database.*" }
        }
    }
}
```

Response enables AI to understand code structure, suggest changes, and generate transformations that preserve semantics.

---

## Content Addressing

### Hash Computation

Every HIR node has a deterministic hash:

```dol
fun compute_hash(module: HirModule) -> ContentHash {
    // Canonical serialization (sorted fields, normalized whitespace)
    let bytes = canonical_serialize(module)
    return sha256(bytes)
}

// Properties:
// 1. Same semantic content → same hash (always)
// 2. Different formatting → same hash (normalization)
// 3. Different variable names → different hash (semantics differ)
```

### Use Cases

| Use Case | How Content Addressing Helps |
|----------|------------------------------|
| **Deduplication** | Same logic from different sources → store once |
| **Caching** | Compile once, cache by hash, reuse everywhere |
| **Attribution** | Prove derivative works share HIR subtrees |
| **Trust** | Verify Spirit matches claimed source |
| **Sync** | Only transfer HIR that nodes don't have |

### Hash Stability

HIR hash must be stable across:
- Compiler versions (within major version)
- Platforms (no endianness issues)
- Time (no timestamps in hash input)

This enables long-term caching and distributed verification.

---

## Comparison with Alternatives

### Why Not Just Use AST?

| Aspect | AST | HIR |
|--------|-----|-----|
| Syntax sugar | Preserved | Desugared |
| Formatting info | Spans, whitespace | Stripped |
| Normalization | None | Full |
| Hash stability | Poor | Excellent |
| Analysis complexity | High | Low |

AST is for parsing and source-level operations. HIR is for semantic operations.

### Why Not Use LLVM IR / WASM Directly?

| Aspect | HIR | LLVM IR / WASM |
|--------|-----|----------------|
| Abstraction level | DOL semantics | Machine semantics |
| Genes/Traits visible | Yes | No |
| Constraints preserved | Yes | No |
| Human comprehensible | Yes | Partially |
| Multi-target | Yes | Single target |

HIR preserves DOL-level concepts. Target IR is for execution.

### Why Not Use JSON Schema / Protobuf?

Those are serialization formats. HIR is a semantic representation that happens to be serializable. The type system, effect tracking, and structural guarantees go beyond what schema languages provide.

---

## Implementation Strategy

### Phase 1: Core Types (2 weeks)

Define HIR types in DOL:
- `dol/hir.dol` - Type definitions
- `dol/hir_hash.dol` - Hashing
- `dol/hir_serde.dol` - Serialization

### Phase 2: Lowering (3 weeks)

Transform AST to HIR:
- `dol/lower_expr.dol` - Expression lowering
- `dol/lower_stmt.dol` - Statement lowering  
- `dol/lower_decl.dol` - Declaration lowering
- `dol/lower.dol` - Entry point

### Phase 3: Codegen Refactor (2 weeks)

Update codegen to consume HIR:
- Refactor `dol/codegen.dol`
- Define `dol/backend.dol` trait
- Verify all tests pass

### Phase 4: Ecosystem Tools (4 weeks)

Build tools on HIR foundation:
- `dol/hir_search.dol` - Semantic search
- `dol/hir_diff.dol` - Semantic diffing
- `dol/hir_verify.dol` - Constraint verification
- `dol/hir_mcp.dol` - MCP integration

---

## Future Directions

### Optimization Passes

HIR enables transformations before codegen:
- Inlining small functions
- Constant folding
- Dead code elimination
- Effect-based parallelization

### Formal Verification

HIR's structure supports theorem proving:
- Extract constraints as logical propositions
- Generate proof obligations
- Integrate with SMT solvers

### Cross-Spirit Analysis

Analyze multiple Spirits together:
- Detect potential deadlocks
- Verify protocol compliance
- Optimize cross-Spirit calls

### Visual Programming

HIR as the editing substrate:
- Visual editors manipulate HIR directly
- Bidirectional: HIR ↔ visual ↔ source
- Always semantically valid

---

## Conclusion

HIR is the semantic backbone of the DOL/VUDO/Univrs ecosystem. By establishing a canonical, content-addressable representation of code meaning, we enable:

1. **Deterministic operations** across distributed nodes
2. **Semantic tools** that understand code, not just text
3. **Multi-target compilation** from a single source of truth
4. **AI integration** with reliable code understanding
5. **Ecosystem interoperability** where all tools share one language

The investment in HIR pays dividends across every layer of the stack—from compiler internals to end-user search. It transforms DOL from a language into a platform.

---

*"The system that knows what it means, can mean what it knows."*

— VUDO Philosophy
