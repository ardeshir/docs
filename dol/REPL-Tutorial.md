# DOL REPL Tutorial

The DOL REPL (Read-Eval-Print Loop) provides an interactive environment for exploring and testing DOL code. This tutorial covers everything from basic usage to advanced features.

> **Status (verified against DOL v0.8.2, 2026-11-20):** The REPL is a **library API**
> (`metadol::repl::SpiritRepl`). There is no working REPL command-line program at 0.8.2: the
> interactive REPL lives in the `vudo` binary of the `dol` crate, which does not compile. Every
> session below was re-run through `SpiritRepl::eval` with the `wasm` feature; the `>>>` lines are
> inputs passed to `eval`, and the lines after them are the returned value or message.
> Evaluation compiles to WASM, so the WASM backend's gaps apply (see *Limitations*).

## Table of Contents

1. [Getting Started](#getting-started)
2. [Basic Expressions](#basic-expressions)
3. [Defining Functions](#defining-functions)
4. [Working with Genes](#working-with-genes)
5. [Type System](#type-system)
6. [Advanced Usage](#advanced-usage)
7. [Under the Hood](#under-the-hood)

---

## Getting Started

### Prerequisites

Before using the DOL REPL, ensure you have:

- Rust 1.84+ installed (the crate's minimum supported Rust version)
- The `dol` crate (library name `metadol`) with the `wasm` feature enabled

### Installation

Add DOL to your project's `Cargo.toml`:

```toml
[dependencies]
metadol = { package = "dol", version = "0.8.2", features = ["wasm"] }
```

### Creating a REPL Instance

```rust
use metadol::repl::{SpiritRepl, EvalResult};

fn main() {
    let mut repl = SpiritRepl::new();

    // Evaluate DOL code
    match repl.eval("42") {
        Ok(EvalResult::Expression { value, .. }) => {
            println!("Result: {}", value);
        }
        Ok(result) => println!("{:?}", result),
        Err(e) => eprintln!("Error: {}", e),
    }
}
```

---

## Basic Expressions

The REPL can evaluate expressions and return their computed values.

### Integer Literals

```text
>>> 42
=> 42

>>> -17
=> -17

>>> 0
=> 0
```

### Floating-Point Literals

Note: negative float literals such as `-273.15` fail to compile at 0.8.2 (`WebAssembly translation error`); write `0.0 - 273.15` instead.

```text
>>> 3.14159
=> 3.14159

>>> 1.0
=> 1
```

### Arithmetic Operations

DOL supports standard arithmetic operations with proper precedence:

```text
>>> 10 + 20
=> 30

>>> 100 - 37
=> 63

>>> 6 * 7
=> 42

>>> 100 / 4
=> 25

>>> 10 + 20 * 2
=> 50  // Multiplication has higher precedence

>>> (10 + 20) * 2
=> 60  // Parentheses override precedence
```

### Float Arithmetic

```text
>>> 1.5 + 2.5
=> 4

>>> 3.14159 * 2.0
=> 6.28318

>>> 10.0 / 3.0
=> 3.3333333333333335
```

---

## Defining Functions

The REPL maintains state across evaluations, allowing you to define and use functions.

### Simple Functions

Use the `pub fun` keyword to define functions:

```text
>>> pub fun square(x: i64) -> i64 { x * x }
Defined function square

>>> square(7)
=> 49

>>> square(12)
=> 144
```

### Functions with Multiple Parameters

```text
>>> pub fun add(a: i64, b: i64) -> i64 { a + b }
Defined function add

>>> add(10, 20)
=> 30

>>> pub fun multiply(x: i64, y: i64) -> i64 { x * y }
Defined function multiply

>>> multiply(6, 7)
=> 42
```

### Float Functions

```text
>>> pub fun area(radius: f64) -> f64 { 3.14159 * radius * radius }
Defined function area

>>> area(10.0)
=> 314.159

>>> pub fun circumference(radius: f64) -> f64 { 2.0 * 3.14159 * radius }
Defined function circumference

>>> circumference(5.0)
=> 31.4159
```

### Functions Using Other Functions

```text
>>> pub fun cube(x: i64) -> i64 { x * square(x) }
Defined function cube

>>> cube(3)
=> 27

>>> cube(4)
=> 64
```

---

## Working with Genes

Genes are DOL's primary data structure, similar to structs in other languages.

### Defining Genes

```text
>>> gen Point { has x: i64   has y: i64 }
Defined gene Point
```

### Using Genes in Functions

```text
>>> pub fun getX() -> i64 {
...     val p = Point { x: 42, y: 100 }
...     p.x
... }
Defined function getX

>>> getX()
=> 42
```

### Genes with Float Fields

> **Known issue (0.8.2):** a gene with `f64` fields (for example `gen Vector2D { has dx: f64   has dy: f64 }`)
> can be defined, but evaluating a function that builds one fails with
> `WASM error: Runtime: Failed to load WASM: WebAssembly translation error`. Use integer fields for now.

### Nested Gene Access

```text
>>> gen Rectangle {
...     has width: i64
...     has height: i64
... }
Defined gene Rectangle

>>> pub fun calculateArea() -> i64 {
...     val rect = Rectangle { width: 10, height: 5 }
...     rect.width * rect.height
... }
Defined function calculateArea

>>> calculateArea()
=> 50
```

---

## Type System

The REPL performs automatic type inference for expressions.

### Supported Types

| Type | Description | Example |
|------|-------------|---------|
| `i64` | 64-bit signed integer | `42`, `-17` |
| `f64` | 64-bit floating point | `3.14`, `-273.15` |
| `bool` | Boolean value | `true`, `false` (at 0.8.2 `true` prints as `1`; comparisons such as `1 < 2` fail to compile) |

### Type Inference Rules

1. **Integer literals** without decimal points are typed as `i64`
2. **Float literals** with decimal points are typed as `f64`
3. **Arithmetic operations** preserve the type of their operands
4. **Mixed operations** follow standard promotion rules

### Examples

```text
>>> 42          // Inferred as i64
=> 42

>>> 3.14        // Inferred as f64
=> 3.14

>>> 10 + 20     // i64 + i64 = i64
=> 30

>>> 1.5 + 2.5   // f64 + f64 = f64
=> 4
```

---

## Advanced Usage

### Session Persistence

All definitions persist within a REPL session:

```rust
let mut repl = SpiritRepl::new();

// Define a function
repl.eval("pub fun double(x: i64) -> i64 { x * 2 }").unwrap();

// Use it multiple times
repl.eval("double(5)");   // => 10
repl.eval("double(100)"); // => 200

// Define another function that uses the first
repl.eval("pub fun quadruple(x: i64) -> i64 { double(double(x)) }").unwrap();
repl.eval("quadruple(3)"); // => 12
```

### EvalResult Types

The REPL returns different result types (abridged from `src/repl/evaluator.rs`):

```rust
pub enum EvalResult {
    /// Empty input (no-op)
    Empty,
    /// A declaration was defined
    Defined { name: String, kind: String, message: String },
    /// An expression was evaluated
    Expression { input: String, value: String },
    /// Output of REPL commands
    Help(String),
    Quit,
    Message(String),
    TypeInfo(String),
    RustCode(String),
    WasmInfo { size_bytes: usize, functions: usize, has_memory: bool },
    SpiritLoaded { name: String, declarations: usize },
}
```

### Handling Results

```rust
match repl.eval(input) {
    Ok(EvalResult::Expression { value, .. }) => {
        println!("=> {}", value);
    }
    Ok(EvalResult::Defined { message, .. }) => {
        println!("{}", message);
    }
    Ok(EvalResult::Empty) => {
        // No output needed
    }
    Ok(other) => println!("{:?}", other),
    Err(e) => {
        eprintln!("Error: {}", e);
    }
}
```

---

## Under the Hood

### How the REPL Works

The DOL REPL compiles and executes code through a sophisticated pipeline:

```
Input → Parse → Type Inference → WASM Compilation → Execution → Result
```

#### 1. Parsing

The input is parsed using DOL's recursive descent parser, producing an AST.

#### 2. Type Inference

For expressions, the REPL infers the return type:
- Scans for float literals (`.` in numbers)
- Checks for boolean keywords (`true`, `false`)
- Defaults to `i64` for integer expressions

#### 3. WASM Compilation

Expressions are wrapped in a function for compilation:

```dol
// Input: 42

// Generated code:
pub fun dolReplEval() -> i64 {
    42
}
```

#### 4. Execution

The compiled WASM is executed via wasmtime:
- The module is instantiated
- The wrapper function is called
- Results are extracted and formatted

### Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Input     │────▶│   Parser    │────▶│     AST     │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌─────────────┐     ┌──────▼──────┐
                    │   Result    │◀────│   WASM      │
                    └─────────────┘     │  Compiler   │
                           ▲            └──────┬──────┘
                           │                   │
                    ┌──────┴──────┐     ┌──────▼──────┐
                    │  Formatter  │◀────│  wasmtime   │
                    └─────────────┘     └─────────────┘
```

### Limitations

Current REPL limitations:

1. **No interactive debugging** - Errors are reported but cannot be stepped through
2. **Expression-only evaluation** - Statements require function wrapping
3. **WASM feature required** - Expression evaluation needs `--features wasm`
4. **No top-level bindings** - Variables must be defined within functions
5. **WASM backend gaps (0.8.2)** - negative float literals, functions whose body is only a float literal (e.g. `pub fun pi() -> f64 { 3.14159 }`), genes with `f64` fields and comparison expressions fail with `WebAssembly translation error`
6. **One bad definition poisons the session** - all definitions are recompiled on every evaluation, so after a definition that fails to compile, later evaluations fail too; use `:clear` to reset
7. **Comment-only input is not ignored** - `>>> // comment` is evaluated as an expression and fails
8. **No type enforcement** - DOL 0.8.2 does not reject ill-typed function bodies before compilation

### Future Improvements

Planned enhancements:

- [ ] Top-level `let` bindings
- [ ] Interactive debugging
- [ ] Tab completion
- [ ] Multi-line editing
- [ ] A working REPL command-line program (the `vudo` binary does not compile at 0.8.2)

Already in the library: REPL commands passed to `eval` — `:help`, `:clear`, `:list`, `:type <name>`, `:emit`, `:wasm`, `:shake`, `:history`, `:load <file>`, `:load-spirit <path>`, `:spirits`, `:reload`.

---

## Complete Example Session

Here's a complete REPL session demonstrating various features (verified with DOL 0.8.2):

```text
>>> 10 + 20
=> 30

>>> 3.14159 * 2.0
=> 6.28318

>>> gen Rect { has width: i64   has height: i64 }
Defined gene Rect

>>> pub fun square_f(x: f64) -> f64 { x * x }
Defined function square_f

>>> pub fun circleArea(r: f64) -> f64 {
...     3.14159 * square_f(r)
... }
Defined function circleArea

>>> circleArea(5.0)
=> 78.53975

>>> pub fun rectArea() -> i64 {
...     val r = Rect { width: 10, height: 5 }
...     r.width * r.height
... }
Defined function rectArea

>>> rectArea()
=> 50

>>> pub fun factorial(n: i64) -> i64 {
...     n * (n - 1) * (n - 2)
... }
Defined function factorial

>>> factorial(5)
=> 60
```

---

## API Reference

### SpiritRepl

```rust
impl SpiritRepl {
    /// Create a new REPL instance
    pub fn new() -> Self;

    /// Create a REPL with a custom session configuration
    pub fn with_config(config: SessionConfig) -> Self;

    /// Evaluate DOL code or a `:command`
    pub fn eval(&mut self, input: &str) -> Result<EvalResult, ReplError>;

    /// Declarations accumulated in this session
    pub fn declarations(&self) -> &[Declaration];

    /// Input history
    pub fn history(&self) -> &[String];

    /// Session configuration
    pub fn config(&self) -> &SessionConfig;
}
```

To clear all definitions, evaluate the `:clear` command.

### Error Handling

```rust
#[derive(Debug, Clone)]
pub enum ReplError {
    Parse(String),
    Command(String),
    NotFound(String),
    Codegen(String),
    Wasm(String),
    Io(String),
    Feature(String),
}
```

---

## See Also

- [DOL Language Reference](/dol.md)
- [DOL CLI Reference](/dol/CLI.md)
- [DOL-to-WASM Compilation](/dol/DOL-to-WASM.md)
- [v0.8.0 Release Notes](/releases/v0.8.0.md) - "Clarity" syntax

---

*Tutorial last updated: November 2026 (sessions re-verified against DOL 0.8.2)*
*DOL Version: 0.8.2*
