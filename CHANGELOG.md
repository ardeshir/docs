# DOL Changelog

All notable changes to the Design Ontology Language will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2024-12-25 - "Meta-Programming"

### Added
- **Quote/Eval**: `'expr` captures AST as `Quoted<T>`, `!quoted` evaluates back to `T`
- **Quasi-Quote/Unquote**: `` `template `` with `~splice` for AST templates
- **Reflect**: `?Type` returns `TypeInfo` at runtime for type introspection
- **Idiom Brackets**: `[| f x y |]` applicative functor syntax sugar
- **18 Built-in Macros**:
  - `#derive(Trait, ...)` - Generate trait implementations
  - `#stringify(expr)` - Convert expression to string
  - `#concat(a, b, ...)` - Concatenate string literals
  - `#env("VAR")` - Read environment variable at compile-time
  - `#cfg(condition)` - Conditional compilation
  - `#assert(cond)` - Runtime assertion
  - `#assert_eq(a, b)` - Assert equality
  - `#assert_ne(a, b)` - Assert inequality
  - `#format(fmt, ...)` - String formatting
  - `#dbg(expr)` - Debug print (returns value)
  - `#todo(msg)` - Mark unimplemented
  - `#unreachable()` - Mark unreachable code
  - `#compile_error(msg)` - Trigger compile-time error
  - `#vec(a, b, c)` - Create vector literal
  - `#file()` - Current file name
  - `#line()` - Current line number
  - `#column()` - Current column number
  - `#module_path()` - Current module path
- `TypeInfo`, `FieldInfo`, `MethodInfo` for reflection system
- `TypeRegistry` for type lookup
- Macro expansion pass in compiler pipeline
- Idiom bracket desugaring transform
- Pratt parser extended with meta-operators (Quote: 135, Eval: 130, Reflect: 135)

### Changed
- Test count: 590 passing (reorganized test structure)
- Expression evaluator now handles Quote/Eval/Reflect operators
- Type checker infers `Quoted<T>` for quoted expressions

### Fixed
- Ontology files updated for DOL syntax compliance
- Reserved keyword collisions (exists, state) resolved in example files

## [0.1.0] - 2024-12-22 - "Genesis"

### Added
- Initial DOL 2.0 compiler implementation
- **Lexer**: `logos`-based tokenizer with span tracking
- **Parser**: Recursive descent with Pratt precedence for expressions
- **Type Checker**: Bidirectional type inference
- **Code Generation**: Rust, TypeScript, JSON Schema backends
- **SEX System** (Side Effect eXecution):
  - `sex fun` for effectful functions
  - `sex var` for mutable globals
  - `sex { }` blocks for localized effects
  - File-level effect isolation (`.sex.dol`, `sex/`)
  - Effect tracking and purity linting
- **Core Language Features**:
  - Genes (structs with constraints)
  - Traits (interfaces with laws)
  - Systems (composed declarations)
  - Constraints (invariant rules)
  - Evolutions (schema migrations)
- **Expression System**:
  - Pipe operator (`|>`)
  - Compose operator (`>>`)
  - Lambda expressions
  - Pattern matching with guards
  - Control flow (if/else, match, for, while, loop)
- **Biology Module Examples**:
  - Ecosystem modeling
  - Hyphal network patterns
  - Mycelium transport
  - Evolution traits
- 631 tests passing
- CLI tools: `dol-parse`, `dol-check`

### Technical Details
- Rust implementation (100%)
- Zero clippy warnings policy
- Comprehensive test coverage
- EBNF grammar specification
