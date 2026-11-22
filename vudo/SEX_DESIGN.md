# SEX in DOL: Side Effect eXecution

> **Design Document v0.1**  
> **Status:** RFC, partially implemented (status corrected November 2026 against DOL 0.8.2)  
> **Vocabulary:** `sex` = Side Effect eXecution (or: Shared External eXchange)

> **Implementation status at DOL 0.8.2**
>
> | Feature | Status |
> |---------|--------|
> | `sex fun`, `sex var`, `sex { }` blocks, `const` | ✅ Parse. The WASM backend does not support `sex { }` blocks. |
> | Bodiless `sex fun host_*` → VUDO VM host functions | ✅ Shipped in 0.8.2 (see "VUDO host ABI" under Runtime Behavior below) |
> | `.sex.dol` files and `sex/` directories as sex context | ✅ `metadol::sex::file_sex_context` |
> | Lint rules E001–E004, W001–W002 | ⚠️ Implemented as a library (`metadol::SexLinter`), but not run by `dol-check` or the compiler: effects are **not enforced** |
> | `sex extern`, generic functions (`fun f<T>`), `#cfg`, `#![allow]`, `Sex<…>` effect types, effect regions | ❌ Planned — not implemented |
> | `+=` compound assignment | ❌ Does not parse; write `x = x + 1` |

---

## The Biological Metaphor

In biology, **sex** is the mechanism for:
- **Genetic recombination** — mixing code across boundaries
- **Mutation** — changing state destructively
- **Crossing barriers** — breaking isolation
- **Creating new combinations** — FFI, interop

In DOL, **sex** represents code that:
- **Mutates global state** — side effects
- **Crosses module boundaries** — unsafe access
- **Performs FFI** — external system calls
- **Breaks referential transparency** — impure functions

---

## Design Overview

### File Convention

| Pattern | Meaning |
|---------|---------|
| `*.sex.dol` | Sex file — contains unsafe/effectful code |
| `sex/` | Sex directory — all files are sex context |
| `sex { }` | Sex block — unsafe scope within pure code |

### Visibility & Safety Model

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
│  SEX (side effects)                                             │
│  ├── Can mutate global state                                    │
│  ├── Can perform I/O                                            │
│  ├── Can call FFI                                               │
│  ├── Must be explicitly marked                                  │
│  └── Compiler tracks effect propagation                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Syntax

### Sex Blocks

```dol
gen StatefulService {
    // Pure function — no sex allowed
    fun pure_compute(x: i64) -> i64 {
        return x * 2
    }
    
    // Sex block — side effects permitted
    sex fun log_and_compute(x: i64) -> i64 {
        println("Computing: " + x)  // I/O side effect
        GLOBAL_COUNTER = GLOBAL_COUNTER + 1  // Mutation
        return x * 2
    }
    
    // Inline sex block within pure function
    fun mostly_pure(x: i64) -> i64 {
        val result = x * 2
        
        sex {
            // This block can have side effects
            debug_log("Result: " + result)
        }
        
        return result
    }
}
```

### Global Mutable State

```dol
// globals.sex.dol — Sex file for global state

// Mutable global — only allowed in sex context
sex var GLOBAL_COUNTER: i64 = 0

// Global constant — allowed anywhere (immutable)
const MAX_CONNECTIONS: i64 = 100

// Sex function to modify global
sex fun increment_counter() -> i64 {
    GLOBAL_COUNTER = GLOBAL_COUNTER + 1
    return GLOBAL_COUNTER
}

// Sex function to reset
sex fun reset_counter() {
    GLOBAL_COUNTER = 0
}
```

### FFI (Foreign Function Interface)

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
// ffi.sex.dol — External system calls

// Declare external function (FFI)
sex extern fun libc_malloc(size: u64) -> Ptr<Void>
sex extern fun libc_free(ptr: Ptr<Void>)

// Wrap unsafe FFI in sex function
sex fun allocate<T>(count: u64) -> Ptr<T> {
    size = count * size_of<T>()
    ptr = libc_malloc(size)
    
    if ptr.is_null() {
        panic("Allocation failed")
    }
    
    return ptr.cast<T>()
}

// Raw pointer operations
sex fun unsafe_read<T>(ptr: Ptr<T>, offset: i64) -> T {
    return ptr.offset(offset).deref()
}
```

### I/O Operations

```dol
// io.sex.dol — I/O is inherently effectful

use std.fs.{ File, OpenMode }

// File operations are sex
sex fun read_file(path: string) -> Result<string, IoError> {
    file = File.open(path, OpenMode.Read)?
    content = file.read_all()?
    file.close()
    return Ok(content)
}

// Network is sex
sex fun http_get(url: string) -> Result<Response, NetError> {
    // Side effect: network request
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

---

## Effect Tracking

### The Sex Type

Functions with side effects are marked with `sex` in their signature:

```dol
// Pure function
fun add(a: i64, b: i64) -> i64 {
    return a + b
}

// Sex function — effect is part of the signature
sex fun log(msg: string) -> ()
```

Effect types in type annotations are planned:

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
type PureCompute = Fun<i64, i64>
type SexCompute = Sex<Fun<i64, i64>>
```

### Effect Propagation

The intended rule is that sex propagates to callers.

> **Not enforced at 0.8.2:** the E001 check below exists in `metadol::SexLinter`, but neither `dol-check` nor the
> compiler runs it, so `pure_caller` currently compiles without error.

```dol
// ❌ Intended ERROR (E001): Cannot call sex function from pure context
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
    val result = 42
    sex {
        log("hello")  // OK: inside sex block
    }
    return result
}
```

### Sex Boundaries

```dol
// At module boundary, sex must be declared
pub sex fun dangerous_operation() -> Result<(), Error> {
    // Callers know this has side effects
}

// Pure public function
pub fun safe_operation(x: i64) -> i64 {
    // Callers know this is pure
    return x * 2
}
```

---

## Directory Structure

```
my-spirit/
├── Spirit.dol
├── src/
│   ├── lib.dol           # Pure library root
│   ├── main.dol          # Entry point (can use sex)
│   ├── genes/
│   │   └── container.dol # Pure gen definitions
│   ├── spells/
│   │   └── math.dol      # Pure functions
│   └── sex/              # ⚠️ Sex directory
│       ├── globals.dol   # Global mutable state
│       ├── io.dol        # I/O operations
│       ├── ffi.dol       # Foreign function interface
│       └── unsafe.dol    # Pointer operations
```

Or using `.sex.dol` extension:

```
my-spirit/
├── Spirit.dol
├── src/
│   ├── lib.dol
│   ├── container.dol       # Pure
│   ├── container.sex.dol   # Sex operations for Container
│   ├── network.sex.dol     # Network I/O
│   └── state.sex.dol       # Global state
```

---

## Use Cases

### 1. Database Access

```dol
// db.sex.dol

sex var DB_CONNECTION: Option<Connection> = None

sex fun connect(url: string) -> Result<(), DbError> {
    DB_CONNECTION = Some(Connection.open(url)?)
    return Ok(())
}

sex fun query(sql: string) -> Result<Rows, DbError> {
    val conn = DB_CONNECTION.expect("Not connected")
    return conn.execute(sql)
}

sex fun disconnect() {
    if DB_CONNECTION.is_some() {
        DB_CONNECTION.unwrap().close()
        DB_CONNECTION = None
    }
}
```

### 2. Caching

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
// cache.sex.dol

sex var CACHE: Map<String, Any> = Map.new()

sex fun get_cached<T>(key: String) -> Option<T> {
    return CACHE.get(key).map(|v| v.cast<T>())
}

sex fun set_cached<T>(key: String, value: T) {
    CACHE.insert(key, value.as_any())
}

sex fun invalidate(key: String) {
    CACHE.remove(key)
}

// Memoization helper
sex fun memoize<A, B>(key: String, compute: Fun<A, B>, arg: A) -> B {
    cached = get_cached<B>(key)
    if cached.is_some() {
        return cached.unwrap()
    }
    
    result = compute(arg)
    set_cached(key, result)
    return result
}
```

### 3. Logging & Telemetry

```dol
// telemetry.sex.dol

sex var LOG_LEVEL: LogLevel = LogLevel.Info

sex fun set_log_level(level: LogLevel) {
    LOG_LEVEL = level
}

sex fun log(level: LogLevel, msg: string) {
    if level >= LOG_LEVEL {
        val timestamp = now()
        println("[" + timestamp + "] " + level.to_string() + ": " + msg)
    }
}

sex fun debug(msg: string) { log(LogLevel.Debug, msg) }
sex fun info(msg: string) { log(LogLevel.Info, msg) }
sex fun warn(msg: string) { log(LogLevel.Warn, msg) }
sex fun error(msg: string) { log(LogLevel.Error, msg) }
```

### 4. FFI to System Libraries

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
// system.sex.dol

#cfg(target.linux)
sex extern "C" {
    fun getpid() -> Int32
    fun fork() -> Int32
    fun execve(path: Ptr<Char>, argv: Ptr<Ptr<Char>>, envp: Ptr<Ptr<Char>>) -> Int32
}

#cfg(target.wasm)
sex extern "wasi" {
    fun fd_write(fd: Int32, iovs: Ptr<IoVec>, iovs_len: Int32, nwritten: Ptr<Int32>) -> Int32
}

// Safe wrapper
sex fun get_process_id() -> Int32 {
    #cfg(target.linux) {
        return getpid()
    }
    #cfg(target.wasm) {
        return 0  // WASM doesn't have PIDs
    }
}
```

---

## Compiler Enforcement

### Sex Lint Rules

These rules are implemented in `metadol::SexLinter` (`src/sex/lint.rs`), but at 0.8.2 they are not run by `dol-check`
or by the compiler.

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

### Escape Hatches

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
// For when you REALLY need to break the rules

// Trust me, I know what I'm doing
#[allow(sex_in_pure)]
fun technically_pure_but_logs() -> i64 {
    sex { debug("shhh") }
    return 42
}

// Suppress all sex warnings in this module
#![allow(sex_warnings)]
```

---

## Runtime Behavior

### Sex in Different Targets

| Target | Sex Implementation (0.8.2) |
|--------|-------------------|
| **WASM** | Bodiless `sex fun host_*` declarations become imports from module `vudo` (VUDO VM host ABI, see below). `sex { }` blocks are not supported by the WASM backend. |
| **Rust** | `sex var` → `thread_local!` `RefCell` (WASM-safe; replaced `static mut` in 0.8.1) |
| **TypeScript** | `sex var` → `export let`; function bodies are emitted as `// TODO: implement` stubs |

There is no Python target; `dol-codegen` targets are `rust`, `typescript` and `jsonschema`.

### VUDO host ABI (DOL 0.8.2)

DOL 0.8.2 ("Spirit Hosting H0") makes `sex fun` the bridge to the VUDO VM:

- A **bodiless** `sex fun host_*` declaration compiles to a WASM import from module **`vudo`**, with the VUDO VM
  linker's exact signature (`src/wasm/host_abi.rs`). Previously these imported from `loa` and could not link.
- The VM provides **15** host functions: `host_time_now`, `host_random_bytes`, `host_log`, `host_storage_read`,
  `host_storage_write`, `host_storage_delete`, `host_network_connect`, `host_network_listen`,
  `host_network_broadcast`, `host_credit_balance`, `host_credit_transfer`, `host_credit_reserve`,
  `host_credit_release`, `host_credit_consume`, `host_credit_available`.
- Declaring a `sex fun` the VM does not provide (unknown name, wrong arity, a float where the host expects an
  integer) is a **compile error**.
- String literals, `string` parameters and typed string locals passed to `host_*` functions lower to `(ptr, len)`.
  Modules that import pointer-taking host functions export `memory`.

```dol
sex fun host_log(level: i64, msg: string) -> i64

sex fun hello() -> i64 {
    return host_log(2, "hello from DOL")
}
```

`univrs/vudo` CI compiles a program like this to WASM and runs it in the VM.

### Generated Code

**DOL:**
```dol
sex var COUNTER: i64 = 0

sex fun increment() -> i64 {
    COUNTER = COUNTER + 1
    return COUNTER
}
```

**Rust output** (actual `dol-codegen` 0.8.2 output):
```rust
use std::cell::RefCell;

thread_local! {
    static COUNTER: RefCell<i64> = RefCell::new(0);
}

pub fn increment() -> i64 {
    COUNTER.with(|__v| *__v.borrow_mut() = (COUNTER.with(|__v| __v.borrow().clone()) + 1));
    return COUNTER.with(|__v| __v.borrow().clone());
}
```

**TypeScript output** (actual `dol-codegen --target typescript` 0.8.2 output; function bodies are not generated):
```typescript
export let COUNTER: I64 = 0 /* TODO: sex var expression */;

export function increment(): I64 {
    // TODO: implement
}
```

---

## Vocabulary Summary

| Term | Meaning | Rust Equivalent |
|------|---------|-----------------|
| `sex` | Side Effect eXecution | `unsafe` |
| `sex fun` | Function with side effects | `fn` with mutation |
| `sex var` | Mutable global variable | `static mut` |
| `sex { }` | Effectful block | `unsafe { }` |
| `sex extern` | FFI declaration (Planned — not implemented) | `extern "C"` |
| `.sex.dol` | File with sex code | — |
| `sex/` | Directory of sex files | — |

---

## Philosophy

> "In pure functional programming, sex is forbidden.
> In DOL, sex is acknowledged, contained, and tracked.
> Because sometimes, to create something new,
> boundaries must be crossed."

The sex system ensures:
1. **Explicit** — Side effects are visible in types and files
2. **Contained** — Sex code is isolated from pure code
3. **Tracked** — Compiler knows where effects can occur
4. **Documented** — Developers know what's dangerous

---

## Open Questions

The syntax sketched in this section is Planned — not implemented; none of it parses in DOL 0.8.2.

1. **Effect polymorphism?** — Can functions be generic over sex?
   ```text
   fun map<F: Fun | Sex>(f: F, list: List<A>) -> List<B>
   ```

2. **Sex regions?** — Different kinds of effects?
   ```text
   sex[IO] fun read_file() -> String
   sex[State] fun increment() -> i64
   sex[IO, State] fun log_and_count() -> Void
   ```

3. **Sex isolation?** — Can sex code run in sandbox?
   ```text
   sandbox sex {
       // Effects are captured, not executed
   }
   ```

---

*"To evolve, sometimes you need a little sex."* 🍄
