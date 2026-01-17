# DOL REPL Tutorial

The DOL REPL (Read-Eval-Print Loop) provides an interactive environment for exploring and testing DOL code. This tutorial covers everything from basic usage to advanced features.

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

- Rust 1.70+ installed
- The `dol` crate with the `wasm` feature enabled

### Installation

Add DOL to your project's `Cargo.toml`:

```toml
[dependencies]
dol = { version = "0.8", features = ["wasm"] }
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

```dol
>>> 42
=> 42

>>> -17
=> -17

>>> 0
=> 0
```

### Floating-Point Literals

```dol
>>> 3.14159
=> 3.14159

>>> -273.15
=> -273.15

>>> 1.0
=> 1
```

### Arithmetic Operations

DOL supports standard arithmetic operations with proper precedence:

```dol
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

```dol
>>> 1.5 + 2.5
=> 4

>>> 3.14159 * 2.0
=> 6.28318

>>> 10.0 / 3.0
=> 3.333333333333333
```

---

## Defining Functions

The REPL maintains state across evaluations, allowing you to define and use functions.

### Simple Functions

Use the `pub fun` keyword to define functions:

```dol
>>> pub fun square(x: i64) -> i64 { x * x }
Defined function 'square'

>>> square(7)
=> 49

>>> square(12)
=> 144
```

### Functions with Multiple Parameters

```dol
>>> pub fun add(a: i64, b: i64) -> i64 { a + b }
Defined function 'add'

>>> add(10, 20)
=> 30

>>> pub fun multiply(x: i64, y: i64) -> i64 { x * y }
Defined function 'multiply'

>>> multiply(6, 7)
=> 42
```

### Float Functions

```dol
>>> pub fun area(radius: f64) -> f64 { 3.14159 * radius * radius }
Defined function 'area'

>>> area(10.0)
=> 314.159

>>> pub fun circumference(radius: f64) -> f64 { 2.0 * 3.14159 * radius }
Defined function 'circumference'

>>> circumference(5.0)
=> 31.4159
```

### Functions Using Other Functions

```dol
>>> pub fun cube(x: i64) -> i64 { x * square(x) }
Defined function 'cube'

>>> cube(3)
=> 27

>>> cube(4)
=> 64
```

---

## Working with Genes

Genes are DOL's primary data structure, similar to structs in other languages.

### Defining Genes

```dol
>>> gen Point { has x: i64   has y: i64 }
Defined gene 'Point'
```

### Using Genes in Functions

```dol
>>> pub fun getX() -> i64 {
...     let p = Point { x: 42, y: 100 }
...     p.x
... }
Defined function 'getX'

>>> getX()
=> 42
```

### Complex Gene Examples

```dol
>>> gen Vector2D { has dx: f64   has dy: f64 }
Defined gene 'Vector2D'

>>> pub fun magnitude() -> f64 {
...     let v = Vector2D { dx: 3.0, dy: 4.0 }
...     // Would be sqrt(dx*dx + dy*dy), simplified here
...     v.dx + v.dy
... }
Defined function 'magnitude'

>>> magnitude()
=> 7
```

### Nested Gene Access

```dol
>>> gen Rectangle {
...     has width: i64
...     has height: i64
... }
Defined gene 'Rectangle'

>>> pub fun calculateArea() -> i64 {
...     let rect = Rectangle { width: 10, height: 5 }
...     rect.width * rect.height
... }
Defined function 'calculateArea'

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
| `bool` | Boolean value | `true`, `false` |

### Type Inference Rules

1. **Integer literals** without decimal points are typed as `i64`
2. **Float literals** with decimal points are typed as `f64`
3. **Arithmetic operations** preserve the type of their operands
4. **Mixed operations** follow standard promotion rules

### Examples

```dol
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

The REPL returns different result types:

```rust
pub enum EvalResult {
    /// An expression that was evaluated
    Expression {
        value: String,
        expr_type: String,
    },

    /// A definition (function, gene, trait, etc.)
    Defined {
        name: String,
        kind: String,
    },

    /// An import statement
    Imported {
        module: String,
    },

    /// Empty input or comment-only
    Empty,
}
```

### Handling Results

```rust
match repl.eval(input) {
    Ok(EvalResult::Expression { value, expr_type }) => {
        println!("=> {} : {}", value, expr_type);
    }
    Ok(EvalResult::Defined { name, kind }) => {
        println!("Defined {} '{}'", kind, name);
    }
    Ok(EvalResult::Imported { module }) => {
        println!("Imported module '{}'", module);
    }
    Ok(EvalResult::Empty) => {
        // No output needed
    }
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

### Future Improvements

Planned enhancements:

- [ ] Top-level `let` bindings
- [ ] Interactive debugging
- [ ] Command history
- [ ] Tab completion
- [ ] Multi-line editing
- [ ] REPL commands (`:help`, `:clear`, `:type`)

---

## Complete Example Session

Here's a complete REPL session demonstrating various features:

```dol
>>> // Basic arithmetic
>>> 10 + 20
=> 30

>>> 3.14159 * 2.0
=> 6.28318

>>> // Define a gene
>>> gen Circle { has radius: f64 }
Defined gene 'Circle'

>>> // Define helper functions
>>> pub fun square_f(x: f64) -> f64 { x * x }
Defined function 'square_f'

>>> pub fun pi() -> f64 { 3.14159 }
Defined function 'pi'

>>> // Calculate circle area
>>> pub fun circleArea(r: f64) -> f64 {
...     pi() * square_f(r)
... }
Defined function 'circleArea'

>>> circleArea(5.0)
=> 78.53975

>>> // Use gene in a function
>>> pub fun getCircleArea() -> f64 {
...     let c = Circle { radius: 10.0 }
...     circleArea(c.radius)
... }
Defined function 'getCircleArea'

>>> getCircleArea()
=> 314.159

>>> // Integer operations
>>> pub fun factorial(n: i64) -> i64 {
...     // Simplified - just multiply for demo
...     n * (n - 1) * (n - 2)
... }
Defined function 'factorial'

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

    /// Evaluate DOL code
    pub fn eval(&mut self, input: &str) -> Result<EvalResult, EvalError>;

    /// Get all defined functions
    pub fn functions(&self) -> Vec<&str>;

    /// Get all defined genes
    pub fn genes(&self) -> Vec<&str>;

    /// Clear all definitions
    pub fn clear(&mut self);
}
```

### Error Handling

```rust
#[derive(Debug)]
pub enum EvalError {
    /// Parse error with location
    ParseError(String),

    /// Compilation error
    CompileError(String),

    /// Runtime execution error
    RuntimeError(String),

    /// Type inference error
    TypeError(String),
}
```

---

## See Also

- [DOL Language Reference](/dol/Language.md)
- [DOL CLI Reference](/dol/CLI.md)
- [DOL-to-WASM Compilation](/dol/DOL-to-WASM.md)
- [v0.8.0 Release Notes](/releases/v0.8.0.md) - "Clarity" syntax

---

*Tutorial last updated: January 2026*
*DOL Version: 0.8.x*
