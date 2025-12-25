# Meta-Programming Architecture

This document describes the architecture of DOL's meta-programming system introduced in v0.2.0.

## Overview

DOL's meta-programming provides:
- **Quote/Eval**: First-class AST manipulation
- **Quasi-Quote/Unquote**: Template-based code generation
- **Reflect**: Runtime type introspection
- **Idiom Brackets**: Applicative functor syntax sugar
- **Macros**: Compile-time code transformation

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    DOL Source                          │
│              'expr, !eval, ?Type, #macro               │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│                   Lexer (logos)                        │
│         Quote, Bang, Question, Hash tokens             │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│               Pratt Parser                             │
│    Quote(135), Bang(130), Question(135) precedence     │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│                      AST                               │
│  Expr::Quote, Expr::Eval, Expr::Reflect,              │
│  Expr::QuasiQuote, Expr::Unquote, Expr::IdiomBracket  │
└───────────────────────┬─────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   Macro     │ │   Idiom     │ │    Type     │
│  Expander   │ │  Desugar    │ │   Checker   │
│ src/macros/ │ │ transform/  │ │ Quoted<T>   │
└──────┬──────┘ └──────┬──────┘ └──────┬──────┘
       │               │               │
       └───────────────┼───────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   Evaluator                            │
│              src/eval/interpreter.rs                   │
│         Quote→AST, Eval→value, Reflect→TypeInfo       │
└─────────────────────────────────────────────────────────┘
```

## Components

### 1. Lexer Extensions

New tokens added to `src/lexer.rs`:

```rust
pub enum Token {
    // ... existing tokens ...

    // Meta-programming tokens
    Quote,           // '
    Bang,            // ! (also used for Eval)
    Question,        // ?
    Hash,            // #
    IdiomOpen,       // [|
    IdiomClose,      // |]
    Backtick,        // ` (quasi-quote)
    Tilde,           // ~ (unquote)
}
```

### 2. AST Nodes

Extended `Expr` enum in `src/ast.rs`:

```rust
pub enum Expr {
    // ... existing variants ...

    /// Quote: 'expr - captures AST as data
    Quote(Box<Expr>),

    /// Eval: !expr - evaluates quoted expression
    Eval(Box<Expr>),

    /// Quasi-quote: `template - AST template
    QuasiQuote(Box<Expr>),

    /// Unquote: ~expr - splice into quasi-quote
    Unquote(Box<Expr>),

    /// Reflect: ?Type - get type information
    Reflect(Box<TypeExpr>),

    /// Idiom bracket: [| f x y |]
    IdiomBracket {
        func: Box<Expr>,
        args: Vec<Expr>,
    },
}
```

### 3. Pratt Parser

Binding powers in `src/pratt.rs`:

| Operator | Binding Power | Position |
|----------|--------------|----------|
| Quote `'` | 135 | Prefix |
| Eval `!` | 130 | Prefix |
| Reflect `?` | 135 | Prefix |

### 4. Type System

The type checker handles meta-programming types:

```rust
// Quote produces Quoted<T>
Expr::Quote(inner) => {
    let inner_type = self.infer(inner)?;
    Ok(Type::Generic {
        name: "Quoted".to_string(),
        args: vec![inner_type],
    })
}

// Eval unwraps Quoted<T> to T
Expr::Eval(inner) => {
    let inner_type = self.infer(inner)?;
    match inner_type {
        Type::Generic { name, args } if name == "Quoted" => {
            Ok(args.into_iter().next().unwrap())
        }
        _ => Err(TypeError::ExpectedQuoted(inner_type)),
    }
}

// Reflect produces TypeInfo
Expr::Reflect(_) => {
    Ok(Type::Generic {
        name: "TypeInfo".to_string(),
        args: vec![],
    })
}
```

### 5. Macro System

Located in `src/macros/`:

```
src/macros/
├── mod.rs          # MacroError, MacroInput, MacroOutput, MacroContext
├── builtin.rs      # 18 built-in macro implementations
└── expand.rs       # MacroExpander pass
```

#### Macro Trait

```rust
pub trait Macro: Send + Sync {
    fn name(&self) -> &str;
    fn expand(&self, input: MacroInput, ctx: &MacroContext) -> Result<MacroOutput, MacroError>;
    fn is_attribute(&self) -> bool { false }
}
```

#### Built-in Macros

| Macro | Type | Description |
|-------|------|-------------|
| `derive` | Attribute | Generate trait implementations |
| `stringify` | Expression | Convert to string literal |
| `concat` | Expression | Concatenate strings |
| `env` | Expression | Read env var at compile-time |
| `cfg` | Attribute | Conditional compilation |
| `assert` | Statement | Runtime assertion |
| `dbg` | Expression | Debug print |
| `format` | Expression | String formatting |
| ... | ... | ... |

### 6. Reflection System

Located in `src/reflect.rs`:

```rust
pub struct TypeInfo {
    pub name: String,
    pub kind: TypeKind,
    pub fields: Vec<FieldInfo>,
    pub methods: Vec<MethodInfo>,
    pub supertype: Option<String>,
    pub is_public: bool,
}

pub struct FieldInfo {
    pub name: String,
    pub type_name: String,
    pub is_public: bool,
    pub is_mutable: bool,
}

pub struct MethodInfo {
    pub name: String,
    pub params: Vec<(String, String)>,
    pub return_type: String,
    pub is_static: bool,
}

pub struct TypeRegistry {
    types: HashMap<String, TypeInfo>,
}
```

### 7. Idiom Bracket Desugaring

Located in `src/transform/desugar_idiom.rs`:

```rust
impl Pass for IdiomDesugar {
    fn run(&mut self, decl: Declaration) -> PassResult<Declaration> {
        // Transform [| f x y |] to ((f <$> x) <*> y)
    }
}
```

Desugaring rules:
- `[| f |]` → `f`
- `[| f a |]` → `f <$> a`
- `[| f a b |]` → `(f <$> a) <*> b`
- `[| f a b c |]` → `((f <$> a) <*> b) <*> c`

### 8. Evaluator

The interpreter in `src/eval/interpreter.rs` handles:

```rust
Expr::Quote(inner) => Ok(Value::Quoted(inner.clone())),

Expr::Eval(inner) => {
    let value = self.eval_in_env(inner, env)?;
    match value {
        Value::Quoted(expr) => self.eval_in_env(&expr, env),
        _ => Err(EvalError::type_error("Quoted", value.type_name())),
    }
}

Expr::Reflect(type_expr) => self.eval_reflect(type_expr),

Expr::IdiomBracket { func, args } => {
    // Desugar and evaluate
}
```

## Data Flow

1. **Source** → Lexer tokenizes meta-operators
2. **Tokens** → Pratt parser builds AST with meta-nodes
3. **AST** → Macro expander processes `#macro(...)` invocations
4. **AST** → Idiom desugar transforms `[| ... |]` to `<$>/<*>` chains
5. **AST** → Type checker infers `Quoted<T>` and `TypeInfo` types
6. **Typed AST** → Evaluator handles Quote/Eval/Reflect at runtime

## Key Design Decisions

### Why Quote/Eval Instead of Hygenic Macros?

Quote/Eval provides a simpler mental model for AST manipulation while still enabling powerful metaprogramming. It mirrors Lisp's quote/eval but with static typing.

### Why Idiom Brackets?

Idiom brackets (from Haskell's idiom brackets extension) provide clean syntax for applicative functor composition without nested parentheses.

### Type Safety

- `Quoted<T>` preserves the type of the quoted expression
- Eval can only be applied to `Quoted<T>`, returning `T`
- TypeInfo is a concrete type, not dependent typing

## Testing

| Component | Test File | Test Count |
|-----------|-----------|------------|
| Quote/Eval | `tests/quote_tests.rs` | 34 |
| Reflect | `tests/reflect_tests.rs` | 17 |
| Idiom Brackets | `tests/idiom_tests.rs` | 27 |
| Macros | `src/macros/builtin.rs` | 25+ |

Total: 590 tests passing

## Future Work

- **Q3**: Code generation for meta-operators (LLVM/WASM)
- **Q4**: Self-hosting - DOL compiler written in DOL
- **Future**: Hygenic macro system, staged computation
