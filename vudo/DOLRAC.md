## DOL 2.0 Runtime Architecture & Composition

> **Design Document v1.0**  
> **Status:** RFC (Request for Comments)  
> **Last Updated:** December 22, 2025  
> **Repository:** github.com/univrs/metadol

---

## Executive Summary

This document defines how DOL 2.0 code is organized, composed, and executed. It covers:

- **File Organization** — How `.dol` files are structured and named
- **Module System** — Imports, exports, and visibility
- **Spirit Packages** — Package format and manifest
- **Entry Points** — `main` vs library vs spells
- **SEX System** — Side Effect eXecution for unsafe/effectful code
- **Compilation Targets** — WASM, Rust, TypeScript, Python
- **Runtime Models** — DOLOS, standalone, embedded, JIT
- **Séance Sessions** — Collaborative editing and execution

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [File Organization](#file-organization)
3. [Module System](#module-system)
4. [Spirit Packages](#spirit-packages)
5. [Entry Points](#entry-points)
6. [SEX: Side Effect eXecution](#sex-side-effect-execution)
7. [Compilation Targets](#compilation-targets)
8. [Runtime Models](#runtime-models)
9. [Séance Sessions](#séance-sessions)
10. [Complete Examples](#complete-examples)
11. [Open Questions](#open-questions)

---

## Design Principles

| Principle | Description |
|-----------|-------------|
| **Ontology First** | Specification before implementation |
| **Private by Default** | Explicit `pub` for public items |
| **Pure by Default** | Side effects require explicit `sex` |
| **Multi-Target** | One source, many outputs |
| **Progressive** | Start simple, scale to distributed |
| **Interoperable** | Play nice with existing ecosystems |

---

## File Organization

### File Extensions

| Extension | Purpose | Example |
|-----------|---------|---------|
| `.dol` | DOL source file | `container.dol` |
| `.sex.dol` | Sex file (side effects) | `io.sex.dol` |
| `Spirit.dol` | Package manifest | `Spirit.dol` |
| `.seance` | Session state snapshot | `session.seance` |

### File Types by Purpose

```
┌─────────────────────────────────────────────────────────────────┐
│                        DOL File Types                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ONTOLOGY FILES (Specification) — Pure                          │
│  ├── genes/*.dol       - Type definitions                       │
│  ├── traits/*.dol      - Interface contracts                    │
│  ├── constraints/*.dol - Validation rules                       │
│  └── systems/*.dol     - Composed modules                       │
│                                                                 │
│  IMPLEMENTATION FILES (Behavior) — Pure                         │
│  ├── impl/*.dol        - Trait implementations                  │
│  ├── spells/*.dol      - Function libraries                     │
│  └── main.dol          - Entry point                            │
│                                                                 │
│  SEX FILES (Side Effects) — Effectful ⚠️                        │
│  ├── sex/*.dol         - Side effect code                       │
│  ├── *.sex.dol         - Inline sex files                       │
│  └── ffi/*.sex.dol     - Foreign function interface             │
│                                                                 │
│  META FILES (Configuration)                                     │
│  ├── Spirit.dol        - Package manifest                       │
│  ├── tests/*.dol       - Test files                             │
│  └── bench/*.dol       - Benchmark files                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Naming Conventions

```dol
// Ontology: noun-based, describes "what it is"
genes/container.dol       // Container gene
traits/runnable.dol       // Runnable trait
constraints/positive.dol  // Positive constraint

// Implementation: verb-based, describes "what it does"
impl/container.dol        // Container implementation
spells/math.dol           // Math spells (pure functions)
main.dol                  // Entry point

// Sex: effectful operations
sex/globals.dol           // Mutable global state
sex/io.dol                // I/O operations
network.sex.dol           // Network (inline sex file)
```

---

## Module System

### Module Declaration

Every `.dol` file implicitly declares a module based on its path:

```dol
// File: src/container/lifecycle.dol
// Implicit module: container.lifecycle

// Explicit module override (optional)
module container.lifecycle {
    // contents
}
```

### Imports

```dol
// ═══════════════════════════════════════════════════════════════
// IMPORTS
// ═══════════════════════════════════════════════════════════════

// Import specific items
use container.{ Container, ContainerState }

// Import all public items
use container.*

// Import with alias
use container.Container as C

// Import from Spirit (external package)
use @univrs/scheduler.{ Scheduler, Task }

// Import from standard library
use std.collections.{ List, Map }
use std.io.{ read, write }

// Import sex functions (must be in sex context to use)
use sex.io.{ read_file, write_file }
```

### Exports & Visibility

```dol
// ═══════════════════════════════════════════════════════════════
// VISIBILITY MODIFIERS
// ═══════════════════════════════════════════════════════════════

// Private by default (module-internal only)
gen InternalHelper { ... }
fun helper() { ... }

// Public — accessible everywhere
pub gen Container { ... }
pub fun process(x: i64) -> i64 { ... }

// Public within Spirit only
pub(spirit) gen PackageInternal { ... }

// Public to parent module
pub(parent) fun utility() { ... }

// Re-export from another module
pub use container.Container
```

### Visibility Summary

| Modifier | Scope |
|----------|-------|
| (none) | Private to current module |
| `pub` | Public, accessible everywhere |
| `pub(spirit)` | Public within Spirit only |
| `pub(parent)` | Public to parent module |

---

## Spirit Packages

### What is a Spirit?

A **Spirit** is DOL's package unit — a shareable collection of modules with:
- Manifest (`Spirit.dol`)
- Ontology (genes, traits)
- Implementation (spells)
- Optional entry point (main)
- Optional sex code (side effects)

### Spirit Structure

```
my-spirit/
├── Spirit.dol              # Package manifest (DOL syntax)
├── src/
│   ├── lib.dol             # Library root (re-exports)
│   ├── main.dol            # Entry point (optional)
│   ├── genes/
│   │   ├── container.dol
│   │   └── process.dol
│   ├── traits/
│   │   └── runnable.dol
│   ├── spells/
│   │   ├── lifecycle.dol
│   │   └── math.dol
│   ├── impl/
│   │   └── container.dol
│   └── sex/                # ⚠️ Side effect code
│       ├── globals.dol
│       ├── io.dol
│       └── ffi.dol
├── tests/
│   └── container_test.dol
├── examples/
│   └── basic.dol
└── target/                 # Build outputs
    ├── wasm/
    ├── rust/
    └── typescript/
```

### Spirit Manifest (Spirit.dol)

```dol
spirit MySpirit {
    // ═══════════════════════════════════════════════════════════
    // METADATA
    // ═══════════════════════════════════════════════════════════
    
    name: "my-spirit"
    version: "0.1.0"
    authors: ["Your Name <you@example.com>"]
    license: "MIT"
    
    docs {
        A Spirit for container orchestration.
        Provides genes for container lifecycle management.
    }
    
    // ═══════════════════════════════════════════════════════════
    // DEPENDENCIES
    // ═══════════════════════════════════════════════════════════
    
    requires {
        @univrs/std: "^1.0"        // Standard library
        @univrs/network: "^0.5"    // Network utilities
        @community/logging: "^2.0" // Third-party Spirit
    }
    
    // ═══════════════════════════════════════════════════════════
    // BUILD CONFIGURATION
    // ═══════════════════════════════════════════════════════════
    
    targets {
        wasm: { optimize: true, target: "wasm32-wasi" }
        rust: { edition: "2024" }
        typescript: { esm: true, runtime: "deno" }
    }
    
    // ═══════════════════════════════════════════════════════════
    // ENTRY POINTS
    // ═══════════════════════════════════════════════════════════
    
    // Library entry (for use as dependency)
    lib: "src/lib.dol"
    
    // Binary entry (for standalone execution)
    bin: [
        { name: "my-cli", path: "src/main.dol" },
        { name: "my-daemon", path: "src/daemon.dol" }
    ]
}
```

### Package Resolution

| Method | Format | Example |
|--------|--------|---------|
| **Registry** | `@org/name` | `@univrs/std` |
| **Git** | `git+url` | `git+https://github.com/org/repo` |
| **Path** | `path:` | `path:../local-spirit` |
| **Content-Addressed** | `ipfs:` / `dht:` | `ipfs:QmXyz...` (TBD) |

---

## Entry Points

### Library vs Binary

| Type | Purpose | Has `main`? | Output |
|------|---------|-------------|--------|
| **Library** | Reusable code | No | Importable module |
| **Binary** | Executable | Yes | Runnable program |
| **Hybrid** | Both | Optional | Either |

### The `main` Function

```dol
// src/main.dol

use std.io.println
use std.env.args

// Entry point for binary execution
// Note: main can use sex implicitly (I/O is allowed)
pub fun main(args: List<String>) -> Int32 {
    println("Hello from DOL!")
    
    for arg in args {
        println("Arg: " + arg)
    }
    
    return 0  // Exit code
}
```

### Library Root

```dol
// src/lib.dol

// Re-export public API
pub use genes.container.Container
pub use genes.process.Process
pub use traits.runnable.Runnable
pub use spells.lifecycle.{ start, stop, restart }

// DO NOT re-export sex by default — consumers must opt-in
// pub use sex.io.{ read_file, write_file }  // Explicit

docs {
    Container orchestration library.
    
    Quick start:
    ```dol
    use @myorg/containers.{ Container, start }
    
    container = Container { id: 1, name: "web" }
    start(container)
    ```
}
```

### Spell Files

```dol
// src/spells/math.dol — Pure function library

pub fun add(a: i64, b: i64) -> i64 {
    return a + b
}

pub fun fibonacci(n: i64) -> i64 {
    match n {
        0 { return 0 }
        1 { return 1 }
        _ { return fibonacci(n - 1) + fibonacci(n - 2) }
    }
}

// Higher-order spell
pub fun twice(f: Fun<i64, i64>, x: i64) -> i64 {
    return f(f(x))
}

// Pipeline-friendly
pub fun double(x: i64) -> i64 { x * 2 }
pub fun increment(x: i64) -> i64 { x + 1 }

// Usage: 5 |> double >> increment |> twice
```

---

## SEX: Side Effect eXecution

### The Biological Metaphor

In biology, **sex** enables:
- **Genetic recombination** — mixing code across boundaries
- **Mutation** — changing state destructively
- **Crossing barriers** — breaking isolation
- **Creating new combinations** — FFI, interop

In DOL, **sex** represents code that:
- **Mutates global state** — side effects
- **Crosses module boundaries** — unsafe access
- **Performs FFI** — external system calls
- **Breaks referential transparency** — impure functions

### Safety Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                     DOL Safety Hierarchy                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PURE (default)                                                 │
│  ├── No side effects                                            │
│  ├── Referentially transparent                                  │
│  ├── Private by default                                         │
│  └── Safe to parallelize                                        │
│                                                                 │
│  PUB (public)                                                   │
│  ├── Exported from module                                       │
│  ├── Still pure unless in sex context                          │
│  └── API boundary                                               │
│                                                                 │
│  SEX (side effects) ⚠️                                          │
│  ├── Can mutate global state                                    │
│  ├── Can perform I/O                                            │
│  ├── Can call FFI                                               │
│  ├── Must be explicitly marked                                  │
│  └── Compiler tracks effect propagation                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Sex Syntax

#### Sex Functions

```dol
gen StatefulService {
    // Pure function — no sex allowed
    fun pure_compute(x: i64) -> i64 {
        return x * 2
    }
    
    // Sex function — side effects permitted
    sex fun log_and_compute(x: i64) -> i64 {
        println("Computing: " + x)  // I/O side effect
        GLOBAL_COUNTER += 1         // Mutation
        return x * 2
    }
}
```

#### Sex Blocks

```dol
// Inline sex block within mostly-pure function
fun mostly_pure(x: i64) -> i64 {
    result = x * 2
    
    sex {
        // This block can have side effects
        debug_log("Result: " + result)
    }
    
    return result
}
```

#### Global Mutable State

```dol
// sex/globals.dol — Sex file for global state

// Mutable global — only allowed in sex context
sex var GLOBAL_COUNTER: i64 = 0

// Immutable constant — allowed anywhere
const MAX_CONNECTIONS: i64 = 100

// Sex functions to modify global
sex fun increment_counter() -> i64 {
    GLOBAL_COUNTER += 1
    return GLOBAL_COUNTER
}

sex fun reset_counter() {
    GLOBAL_COUNTER = 0
}
```

#### FFI (Foreign Function Interface)

```dol
// sex/ffi.dol — External system calls

// Declare external function (FFI)
sex extern fun libc_malloc(size: u64) -> Ptr<Void>
sex extern fun libc_free(ptr: Ptr<Void>)

// Platform-specific FFI
#cfg(target.linux)
sex extern "C" {
    fun getpid() -> Int32
    fun fork() -> Int32
}

#cfg(target.wasm)
sex extern "wasi" {
    fun fd_write(fd: Int32, iovs: Ptr<IoVec>, len: Int32, nwritten: Ptr<Int32>) -> Int32
}

// Safe wrapper
sex fun allocate<T>(count: u64) -> Ptr<T> {
    size = count * size_of<T>()
    ptr = libc_malloc(size)
    
    if ptr.is_null() {
        panic("Allocation failed")
    }
    
    return ptr.cast<T>()
}
```

#### I/O Operations

```dol
// sex/io.dol — I/O is inherently effectful

use std.fs.{ File, OpenMode }

// File operations are sex
sex fun read_file(path: String) -> Result<String, IoError> {
    file = File.open(path, OpenMode.Read)?
    content = file.read_all()?
    file.close()
    return Ok(content)
}

// Network is sex
sex fun http_get(url: String) -> Result<Response, NetError> {
    return Http.get(url)
}

// Random is sex (non-deterministic)
sex fun random_int(min: i64, max: i64) -> i64 {
    return Random.range(min, max)
}

// Time is sex (non-deterministic)
sex fun now() -> Timestamp {
    return Timestamp.now()
}
```

### Effect Tracking

#### The Sex Type

```dol
// Pure function type
fun add(a: i64, b: i64) -> i64

// Sex function type — effect is part of signature
sex fun log(msg: String) -> Void

// In type annotations
type PureCompute = Fun<i64, i64>
type SexCompute = Sex<Fun<i64, i64>>
```

#### Effect Propagation

```dol
// ❌ ERROR: Cannot call sex function from pure context
fun pure_caller() -> i64 {
    log("hello")  // Compile error: sex in pure context
    return 42
}

// ✅ OK: Sex propagates up
sex fun sex_caller() -> i64 {
    log("hello")  // OK: we're in sex context
    return 42
}

// ✅ OK: Explicit sex block
fun mixed_caller() -> i64 {
    result = 42
    sex { log("hello") }  // OK: inside sex block
    return result
}
```

### Sex Vocabulary Summary

| Term | Meaning | Rust Equivalent |
|------|---------|-----------------|
| `sex` | Side Effect eXecution | `unsafe` |
| `sex fun` | Function with side effects | `fn` with mutation |
| `sex var` | Mutable global variable | `static mut` |
| `sex { }` | Effectful block | `unsafe { }` |
| `sex extern` | FFI declaration | `extern "C"` |
| `*.sex.dol` | File with sex code | — |
| `sex/` | Directory of sex files | — |

### Compiler Enforcement

```
┌─────────────────────────────────────────────────────────────────┐
│                     Sex Compiler Checks                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  E001: Sex in pure context                                      │
│  → Cannot call sex function from pure function                  │
│                                                                 │
│  E002: Mutable global outside sex                               │
│  → sex var must be in .sex.dol or sex/ directory               │
│                                                                 │
│  E003: FFI outside sex                                          │
│  → extern declarations require sex context                      │
│                                                                 │
│  E004: I/O outside sex                                          │
│  → File, Network, Random, Time require sex                     │
│                                                                 │
│  W001: Large sex block                                          │
│  → Consider extracting to sex function                          │
│                                                                 │
│  W002: Sex function without documentation                       │
│  → Sex functions should document side effects                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Compilation Targets

### Multi-Target Architecture

```
                              DOL Source
                                  │
                                  ▼
                         ┌───────────────┐
                         │   DOL Parser  │
                         │   + TypeCheck │
                         │  + Sex Track  │
                         └───────┬───────┘
                                 │
                          Typed AST
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
   ┌───────────┐          ┌───────────┐          ┌───────────┐
   │   Rust    │          │   WASM    │          │TypeScript │
   │  Codegen  │          │  Codegen  │          │  Codegen  │
   └─────┬─────┘          └─────┬─────┘          └─────┬─────┘
         │                      │                      │
         ▼                      ▼                      ▼
   ┌───────────┐          ┌───────────┐          ┌───────────┐
   │   .rs     │          │   .wasm   │          │   .ts     │
   │  files    │          │  binary   │          │  files    │
   └─────┬─────┘          └───────────┘          └─────┬─────┘
         │                      │                      │
         ▼                      ▼                      ▼
   ┌───────────┐          ┌───────────┐          ┌───────────┐
   │  Native   │          │  Browser  │          │   Node    │
   │  Binary   │          │   DOLOS   │          │   Deno    │
   │   CLI     │          │ Wasmtime  │          │  Browser  │
   └───────────┘          └───────────┘          └───────────┘
```

### Target Matrix

| Target | Command | Output | Runtime |
|--------|---------|--------|---------|
| **Rust** | `dol build --target rust` | `.rs` files | Native via `cargo` |
| **WASM** | `dol build --target wasm` | `.wasm` binary | Browser, Wasmtime, VUDO |
| **TypeScript** | `dol build --target typescript` | `.ts` files | Node, Deno, Browser |
| **Python** | `dol build --target python` | `.py` files | Python 3.x |
| **JSON Schema** | `dol build --target jsonschema` | `.json` schemas | Validation |

### Sex in Different Targets

| Target | Sex Implementation |
|--------|-------------------|
| **WASM** | WASI imports, linear memory |
| **Rust** | `unsafe` blocks, `static mut` |
| **TypeScript** | Side effects (JS is impure anyway) |
| **Python** | Global variables, I/O |

### Generated Code Example

**DOL:**
```dol
sex var COUNTER: i64 = 0

sex fun increment() -> i64 {
    COUNTER += 1
    return COUNTER
}
```

**Rust output:**
```rust
static mut COUNTER: i64 = 0;

pub fn increment() -> i64 {
    unsafe {
        COUNTER += 1;
        COUNTER
    }
}
```

**TypeScript output:**
```typescript
let COUNTER: number = 0;

export function increment(): number {
    COUNTER += 1;
    return COUNTER;
}
```

---

## Runtime Models

### 1. DOLOS (Full Platform)

The complete VUDO ecosystem with Spirit orchestration:

```
┌─────────────────────────────────────────────────────────────────┐
│                           DOLOS                                 │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Spirit    │  │   Spirit    │  │   Spirit    │             │
│  │  (web-ui)   │  │  (api-gw)   │  │  (worker)   │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          │                                      │
│                    ┌─────┴─────┐                                │
│                    │  Mycelium │  ← P2P Network                 │
│                    │  Network  │                                │
│                    └─────┬─────┘                                │
│                          │                                      │
│  ┌───────────────────────┼───────────────────────┐             │
│  │                   VUDO VM                      │             │
│  │  ┌─────────┐  ┌─────────────┐  ┌───────────┐  │             │
│  │  │  WASM   │  │   Spirit    │  │ Identity  │  │             │
│  │  │ Runtime │  │  Scheduler  │  │ (Ed25519) │  │             │
│  │  └─────────┘  └─────────────┘  └───────────┘  │             │
│  └───────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Standalone WASM

```bash
# Compile to WASM
dol build --target wasm src/main.dol -o app.wasm

# Run with Wasmtime
wasmtime app.wasm

# Run in browser
<script type="module">
  const { instance } = await WebAssembly.instantiateStreaming(
    fetch('app.wasm')
  );
  instance.exports.main();
</script>
```

### 3. Native via Rust

```bash
# Generate Rust
dol build --target rust src/main.dol -o generated/

# Compile with Cargo
cd generated && cargo build --release

# Run native binary
./target/release/my-spirit
```

### 4. JIT / REPL

```bash
$ dol repl

DOL 2.0 REPL
Type :help for commands

DOL> x = 42
42

DOL> fun double(n: i64) -> i64 { n * 2 }
<function double>

DOL> double(x)
84

DOL> sex { println("Side effect!") }
Side effect!
()

DOL> :type double
Fun<i64, i64>

DOL> :quit
Goodbye! 🍄
```

### 5. Embedded in Host Language

```rust
// Rust host
use dol_runtime::Runtime;

fn main() {
    let mut rt = Runtime::new();
    rt.load_spirit("./my-spirit").unwrap();
    
    let result: i64 = rt.call("math.add", (1, 2)).unwrap();
    println!("Result: {}", result);
}
```

```typescript
// TypeScript host
import { Runtime } from '@dol/runtime';

const rt = new Runtime();
await rt.loadSpirit('./my-spirit');

const result = await rt.call('math.add', [1, 2]);
console.log(`Result: ${result}`);
```

---

## Séance Sessions

### What is a Séance?

A **Séance** is a collaborative editing/execution session where multiple participants can:
- Edit DOL code in real-time
- See live compilation results
- Share execution state
- Invoke Spirits together

### Séance Model

```
┌─────────────────────────────────────────────────────────────────┐
│                         Séance Session                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Participants:                                                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                         │
│  │  Alice  │  │   Bob   │  │  Carol  │                         │
│  │ (Mambo) │  │ (Editor)│  │(Viewer) │                         │
│  └────┬────┘  └────┬────┘  └────┬────┘                         │
│       │            │            │                               │
│       └────────────┼────────────┘                               │
│                    │                                            │
│            ┌───────┴───────┐                                    │
│            │  Shared State │                                    │
│            │  ┌─────────┐  │                                    │
│            │  │  Code   │  │  ← Live DOL source                 │
│            │  │ Buffer  │  │                                    │
│            │  └─────────┘  │                                    │
│            │  ┌─────────┐  │                                    │
│            │  │  AST    │  │  ← Incrementally updated           │
│            │  │  Cache  │  │                                    │
│            │  └─────────┘  │                                    │
│            │  ┌─────────┐  │                                    │
│            │  │ Runtime │  │  ← Live execution                  │
│            │  │  State  │  │                                    │
│            │  └─────────┘  │                                    │
│            └───────────────┘                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Séance API

```dol
use std.seance.{ Seance, Participant, Role }

// Create a new séance
sex fun create_workshop() -> Seance {
    return Seance.create({
        name: "Container Workshop",
        spirits: ["@univrs/containers"],
        access: Role.Invite
    })
}

// Join existing séance
sex fun join_workshop(id: String) -> Seance {
    return Seance.join("seance://" + id)
}

// Collaborative editing
sex fun setup_listeners(seance: Seance) {
    seance.on_edit(fun (change) {
        println("Edit by " + change.author + ": " + change.delta)
    })
}

// Execute spell together
sex fun run_together(seance: Seance, container: Container) -> Result {
    return seance.invoke("containers.start", container)
}

// Snapshot session state
sex fun checkpoint(seance: Seance) {
    seance.save("workshop-checkpoint.seance")
}
```

---

## Complete Examples

### Example 1: Pure Library Spirit

```dol
// Spirit.dol
spirit MathLib {
    name: "@myorg/math"
    version: "1.0.0"
    lib: "src/lib.dol"
}
```

```dol
// src/lib.dol
pub use spells.arithmetic.{ add, subtract, multiply, divide }
pub use spells.trig.{ sin, cos, tan }
pub use genes.complex.Complex
```

```dol
// src/genes/complex.dol
pub gen Complex {
    has real: f64
    has imag: f64
    
    constraint valid {
        !this.real.is_nan && !this.imag.is_nan
    }
}
```

```dol
// src/spells/arithmetic.dol
pub fun add(a: i64, b: i64) -> i64 { a + b }
pub fun subtract(a: i64, b: i64) -> i64 { a - b }
pub fun multiply(a: i64, b: i64) -> i64 { a * b }
pub fun divide(a: i64, b: i64) -> Option<i64> {
    if b == 0 { None } else { Some(a / b) }
}
```

### Example 2: CLI Tool with Sex

```dol
// Spirit.dol
spirit Greeter {
    name: "greeter"
    version: "1.0.0"
    bin: [{ name: "greet", path: "src/main.dol" }]
}
```

```dol
// src/main.dol
use std.io.println
use std.env.args
use sex.state.increment_runs

pub fun main(args: List<String>) -> Int32 {
    name = if args.length > 1 { args[1] } else { "World" }
    
    sex {
        count = increment_runs()
        println("Hello, " + name + "! (Run #" + count + ")")
    }
    
    return 0
}
```

```dol
// src/sex/state.dol
sex var RUN_COUNT: i64 = 0

pub sex fun increment_runs() -> i64 {
    RUN_COUNT += 1
    return RUN_COUNT
}
```

### Example 3: Full-Stack Spirit

```
my-app/
├── Spirit.dol
├── src/
│   ├── lib.dol
│   ├── main.dol
│   ├── genes/
│   │   ├── user.dol
│   │   └── post.dol
│   ├── traits/
│   │   └── persistable.dol
│   ├── spells/
│   │   ├── validation.dol
│   │   └── transform.dol
│   ├── impl/
│   │   ├── user.dol
│   │   └── post.dol
│   └── sex/
│       ├── db.dol          # Database operations
│       ├── http.dol        # HTTP handlers
│       └── globals.dol     # App state
└── tests/
    └── user_test.dol
```

```dol
// src/genes/user.dol
pub gen User {
    has id: u64
    has email: String
    has name: String
    has created_at: Timestamp
    
    constraint valid_email {
        this.email.contains("@")
    }
}
```

```dol
// src/sex/db.dol
use std.db.{ Connection, Query }

sex var DB: Option<Connection> = None

pub sex fun connect(url: String) -> Result<Void, DbError> {
    DB = Some(Connection.open(url)?)
    return Ok(())
}

pub sex fun find_user(id: u64) -> Result<User, DbError> {
    conn = DB.expect("Not connected")
    row = conn.query_one("SELECT * FROM users WHERE id = ?", [id])?
    return Ok(User.from_row(row))
}

pub sex fun save_user(user: User) -> Result<Void, DbError> {
    conn = DB.expect("Not connected")
    conn.execute(
        "INSERT INTO users (email, name) VALUES (?, ?)",
        [user.email, user.name]
    )?
    return Ok(())
}
```

---

## Open Questions

### 1. Effect Polymorphism

Can functions be generic over sex?

```dol
// Option A: Effect parameter
fun map<F: Fun | Sex>(f: F, list: List<A>) -> List<B>

// Option B: Separate functions
fun map(f: Fun<A, B>, list: List<A>) -> List<B>
sex fun map_sex(f: Sex<Fun<A, B>>, list: List<A>) -> List<B>
```

### 2. Effect Regions

Different kinds of effects?

```dol
sex[IO] fun read_file() -> String
sex[State] fun increment() -> i64
sex[IO, State] fun log_and_count() -> Void
```

### 3. Sex Sandboxing

Can sex code run in a sandbox?

```dol
sandbox sex {
    // Effects are captured, not executed
    // Returns a description of what would happen
}
```

### 4. Module Resolution Protocol

How does `@org/spirit` resolve?

| Option | Status |
|--------|--------|
| GitHub/HTTP | Supported (fallback) |
| Content-addressed (IPFS/DHT) | TBD |
| Mycelium Network | TBD |
| Blockchain registry | TBD |

---

## Summary

### The DOL Execution Model

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                      DOL Source (.dol)                          │
│                            │                                    │
│  Visibility: private (default) | pub                            │
│  Purity: pure (default) | sex                                   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    DOL Compiler                          │   │
│  │  Parse → TypeCheck → SexTrack → [Optimize] → Codegen    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│         ┌──────────────────┼──────────────────┐                │
│         ▼                  ▼                  ▼                 │
│    ┌─────────┐       ┌─────────┐       ┌─────────┐             │
│    │  Rust   │       │  WASM   │       │   TS    │             │
│    └────┬────┘       └────┬────┘       └────┬────┘             │
│         ▼                 ▼                 ▼                   │
│    ┌─────────┐       ┌─────────┐       ┌─────────┐             │
│    │ Native  │       │  DOLOS  │       │  Node   │             │
│    │  CLI    │       │ Browser │       │  Deno   │             │
│    └─────────┘       └─────────┘       └─────────┘             │
│                                                                 │
│  Entry Points:                                                  │
│  • main.dol     → Executable (can use sex)                     │
│  • lib.dol      → Library (pure API)                           │
│  • spells/*.dol → Pure functions                               │
│  • sex/*.dol    → Side effects ⚠️                              │
│                                                                 │
│  Packaging:                                                     │
│  • Spirit.dol   → Package manifest (DOL syntax)                │
│  • Mycelium     → Package registry (P2P, TBD)                  │
│                                                                 │
│  Collaboration:                                                 │
│  • Séance       → Live editing session                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Philosophy

> *"Pure code is the default — safe, predictable, parallelizable.*  
> *Sex code is explicit — tracked, contained, documented.*  
> *Because sometimes, to create something new,*  
> *boundaries must be crossed."*

---

*"Systems that can become, what you can imagine!"* 🍄
