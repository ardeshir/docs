# Building Modern Compiler Infrastructure for a Domain-Specific Language

DOL can achieve both rapid prototyping and production performance by implementing **two parallel compilation paths from a shared AST**: a JavaScript transpiler for immediate demos, and a Rust-to-WASM pipeline for native-speed production. The most effective architecture uses a Cargo workspace with separate codegen crates, adopting patterns from TypeScript's emitter design for JS output and Binaryen for WASM generation. This staged approach lets you ship working demos within weeks while building production-grade infrastructure over months.

The key insight from researching languages like Grain, Elm, and PureScript is that **LLVM is overkill for DSL compilers**—Binaryen provides faster compilation and full WASM GC support with far less complexity. For the JS path, generating ESTree-compliant JSON from Rust and using the **astring** library for final code emission (4-10x faster than alternatives) gives you debuggable output with minimal implementation effort.

---

## Path 1: JavaScript transpilation patterns that work

TypeScript's emitter architecture provides the clearest model for building a JS transpiler in Rust. The compiler uses a "dumb" tree-based syntax emitter that walks the AST and prints JavaScript without containing business logic—all semantic decisions happen in earlier phases. This separation makes the emitter testable and maintainable as the language evolves.

**CoffeeScript's fragment-based approach** offers a simpler alternative suitable for a DSL. Each AST node implements a `compileNode()` method returning code fragments with source location data. These fragments concatenate into final JavaScript with source map mappings automatically generated. This approach requires less infrastructure than generating a full JavaScript AST.

For DOL specifically, I recommend a hybrid approach:

```rust
// Rust side: Generate ESTree-compatible JSON AST
#[derive(Serialize)]
struct JSExpr {
    #[serde(rename = "type")]
    node_type: String,
    loc: SourceLocation,
    // ... node-specific fields
}
```

Then use **astring** on the JavaScript side for code printing—it benchmarks at ~465 operations/second compared to ~104 for escodegen and ~61 for Babel's generator. Source maps integrate via the **magic-string** library, which Vite and Rollup use for their speed and simplicity.

### Host function bindings for Spirits

Elm's port system provides the cleanest model for DOL's host function bindings. Rather than direct FFI, ports create an asynchronous message-passing interface between the compiled code and the JavaScript host:

```javascript
// Generated runtime header (injected into every output)
const __dol = {
  vudo_print: (value) => console.log("[Spirit]", value),
  emit_effect: (handler) => ({ __effect: true, handler }),
  state: new Map(),
  
  // P2P integration points
  send_message: (target, payload) => { /* host implementation */ },
  subscribe: (channel) => { /* returns observable */ }
};
```

PureScript's approach of representing effects as thunks—`Effect a` compiles to `() => a`—works well for lazy evaluation and composition. For DOL's autonomous Spirits, consider representing behaviors as effect descriptions that the runtime interprets, rather than immediately executing side effects.

### Runtime library design

Elm bundles its entire runtime into every output file (thousands of lines for even simple programs), which simplifies deployment but bloats bundle sizes. PureScript takes the opposite approach with a minimal core distributed as packages. For DOL's multi-environment targets (browser, Node, Tauri), **a modular runtime with environment-specific adapters** makes more sense:

```
@dol/runtime-core    - Effect system, state management (shared)
@dol/runtime-browser - DOM bindings, Web APIs
@dol/runtime-node    - File system, native modules
@dol/runtime-tauri   - IPC with Rust backend
```

The core runtime should be under 5KB minified, with environment adapters tree-shaken by bundlers.

---

## Path 2: WASM compilation via Binaryen rather than LLVM

Grain, AssemblyScript, and Motoko all skip LLVM entirely, using **Binaryen** for WASM code generation. This choice delivers faster compile times, simpler compiler architecture, and full support for emerging WASM features like GC that LLVM doesn't yet handle.

Binaryen provides a lightweight IR almost identical to WASM's structure, making the mental model straightforward. The tradeoff is roughly **2% slower output compared to V8's optimizer and 14% slower than LLVM-optimized code**—acceptable for most DSL use cases, especially since you can always run `wasm-opt` as a post-processing step to recover much of that performance.

For DOL, the recommended architecture:

```
DOL Source → Parser (Rust) → AST → Type Checker 
                                        ↓
                              ┌─────────┴─────────┐
                              ↓                   ↓
                        JS Codegen           WASM Codegen
                        (ESTree JSON)        (Binaryen IR)
                              ↓                   ↓
                        astring → .js        wasm-opt → .wasm
                        + .map               + JS glue
```

### Cranelift vs LLVM vs Binaryen decision matrix

| Factor | Cranelift | LLVM | Binaryen |
|--------|-----------|------|----------|
| **Compile speed** | ~10x faster than LLVM | Slowest | Fastest |
| **Output quality** | ~2% slower than V8 | Best optimization | Good with wasm-opt |
| **Code complexity** | 200K LoC, pure Rust | 20M LoC, C++ | Moderate, C++ |
| **WASM GC** | Limited | No support | Full support |
| **Best for** | Debug builds, JIT | Release builds | GC languages, DSLs |

**Recommendation: Start with Binaryen.** If DOL's Spirits need garbage collection (likely for complex ontological structures), Binaryen is the only choice with full WASM GC support. Add Cranelift later only if you need faster debug builds or want a pure-Rust toolchain.

### wasm-bindgen patterns for Spirit host bindings

```rust
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::{JsFuture, spawn_local};

#[wasm_bindgen]
pub struct Spirit {
    id: String,
    state: JsValue,
}

#[wasm_bindgen]
impl Spirit {
    #[wasm_bindgen(constructor)]
    pub fn new(manifest: &str) -> Result<Spirit, JsValue> {
        // Parse manifest, initialize state
    }
    
    pub async fn process_event(&mut self, event: JsValue) -> Result<JsValue, JsValue> {
        // Async effect handling using wasm-bindgen-futures
        let response = JsFuture::from(self.emit_effect(event)).await?;
        Ok(response)
    }
}

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = ["globalThis", "DOL"])]
    fn emit_effect(effect: JsValue) -> js_sys::Promise;
    
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}
```

Use `--target web` for browser builds (ES modules, no bundler required) and `--target nodejs` for Node.js compatibility. For Tauri, the WASM module loads identically to browser but can call into Rust-side IPC.

---

## Crate organization for staged implementation

The key architectural decision is **separating the AST definition from both code generators**, enabling you to build the JS backend first while designing an IR that will work for WASM later.

```
dol/
├── Cargo.toml                    # Workspace root
├── crates/
│   ├── dol-syntax/               # Lexer, parser, AST (exists)
│   │   └── src/
│   │       ├── ast.rs            # Shared AST types with spans
│   │       ├── lexer.rs
│   │       └── parser.rs
│   ├── dol-semantic/             # Type checking, validation
│   │   └── src/
│   │       ├── types.rs          # Type system
│   │       └── checker.rs        # Semantic analysis
│   ├── dol-ir/                   # Optional mid-level IR
│   │   └── src/
│   │       └── mir.rs            # Backend-agnostic IR
│   ├── dol-codegen-js/           # JavaScript emitter
│   │   └── src/
│   │       ├── emitter.rs        # AST → ESTree JSON
│   │       └── sourcemap.rs      # Source map generation
│   ├── dol-codegen-wasm/         # WASM emitter (Phase 2)
│   │   └── src/
│   │       └── binaryen.rs       # AST → Binaryen IR
│   ├── dol-cli/                  # Command-line compiler
│   └── dol-binding-node/         # napi-rs bindings for Node
├── packages/                     # npm packages
│   ├── @dol/core/                # Main npm package
│   ├── @dol/runtime/             # Runtime library
│   └── @dol/language-server/     # LSP implementation
└── runtime/
    └── js/                       # Runtime source
```

The **CodeGenerator trait** defines the interface both backends implement:

```rust
pub trait CodeGenerator {
    type Output;
    type Error;
    
    fn generate(&self, program: &Program) -> Result<Self::Output, Self::Error>;
}

// JS backend (Phase 1)
impl CodeGenerator for JsCodegen {
    type Output = JsOutput; // Contains .js + .map
    type Error = CodegenError;
    
    fn generate(&self, program: &Program) -> Result<JsOutput, CodegenError> {
        // Walk AST, emit ESTree JSON, run astring
    }
}

// WASM backend (Phase 2)
impl CodeGenerator for WasmCodegen {
    type Output = Vec<u8>; // WASM binary
    type Error = CodegenError;
    
    fn generate(&self, program: &Program) -> Result<Vec<u8>, CodegenError> {
        // Walk AST, emit Binaryen IR, optimize, serialize
    }
}
```

---

## SDK packaging following the SWC pattern

SWC provides the clearest model for distributing a Rust-based compiler to the npm ecosystem. The key insight is using **optional dependencies to auto-select platform-specific native binaries**, with WASM as the universal fallback:

```json
// @dol/core/package.json
{
  "name": "@dol/core",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "optionalDependencies": {
    "@dol/core-linux-x64-gnu": "1.0.0",
    "@dol/core-darwin-arm64": "1.0.0",
    "@dol/core-win32-x64-msvc": "1.0.0"
  }
}
```

At runtime, `@dol/core` attempts to load the native binary first, falling back to `@dol/wasm` if unavailable. This gives developers native speed on their development machines while maintaining universal compatibility.

Use **napi-rs** for the Rust-to-Node.js bindings—it handles the complexity of native module compilation and provides AsyncTask patterns for non-blocking operations essential for a compiler that may need to process multiple files.

### CI/CD release pipeline

Adopt Rust's release train model with **6-week cycles** and three channels:

1. **Nightly**: Built from main branch, includes experimental syntax behind feature flags
2. **Beta**: Promoted from nightly, stabilization period for finding bugs  
3. **Stable**: Production releases, features graduate from beta

GitHub Actions matrix strategy for cross-platform builds:

```yaml
strategy:
  matrix:
    include:
      - os: ubuntu-latest
        target: x86_64-unknown-linux-gnu
      - os: macos-latest
        target: aarch64-apple-darwin
      - os: macos-latest
        target: x86_64-apple-darwin
      - os: windows-latest
        target: x86_64-pc-windows-msvc

steps:
  - uses: actions/checkout@v4
  - uses: dtolnay/rust-toolchain@stable
    with:
      targets: ${{ matrix.target }}
  - run: cargo build --release --target ${{ matrix.target }}
  - uses: actions/upload-artifact@v4
```

---

## Handling evolving syntax with an edition system

Since DOL's spec is still evolving, implement **Rust's edition system from the start**. Each source file declares its edition, and the parser applies edition-specific grammar rules while compiling to the same internal IR:

```toml
# spirit.dol.toml or in file header
[package]
edition = "2025"
```

Key principles from Rust's design:

- **Opt-in per-file**: Each file specifies its edition, enabling gradual migration
- **Cross-edition interop**: Spirits compiled with different editions can interact
- **"Skin deep" changes only**: Editions affect parsing, not runtime semantics
- **Automated migration**: `dol fix --edition 2026` rewrites code automatically

For unstable features before the first stable release, use feature flags:

```rust
// In DOL source
#![feature(async_spirits)]
#![feature(typed_effects)]
```

These require the nightly channel and get stabilized into editions over time.

---

## Developer experience through excellent error messages

Elm's error messages set the standard—they read like a helpful colleague explaining what went wrong and how to fix it. The key elements:

1. **Precise source spans** pointing exactly to the problem
2. **Plain English explanations** avoiding jargon
3. **Actionable suggestions** with example fixes
4. **Links to documentation** for complex issues

Use **miette** or **ariadne** for error formatting in Rust:

```rust
use miette::{Diagnostic, SourceSpan};

#[derive(Debug, Diagnostic, thiserror::Error)]
#[error("Type mismatch in Spirit declaration")]
#[diagnostic(
    code(dol::type_error::mismatch),
    help("The `behavior` block expects `Effect Unit`, but this expression has type `{found}`"),
    url(docsrs)
)]
pub struct TypeMismatch {
    #[source_code]
    src: String,
    
    #[label("expected type `{expected}` here")]
    expected_span: SourceSpan,
    
    #[label("but found type `{found}`")]
    found_span: SourceSpan,
    
    expected: String,
    found: String,
}
```

Track source spans through all compilation phases—this information is essential for error messages, source maps, and IDE integration.

---

## Testing the transpiler for correctness

TypeScript's **baseline testing system** provides the gold standard. Test files contain only DOL source; the compiler output is saved to baseline files and committed to version control:

```
tests/
├── cases/
│   ├── basic_spirit.dol          # Input
│   └── type_error.dol
└── baselines/
    └── reference/
        ├── basic_spirit.js       # Expected JS output
        ├── basic_spirit.js.map   # Expected source map
        └── type_error.errors     # Expected error output
```

Tests pass if output matches baselines; `dol test --update-baselines` accepts new output. This catches regressions while making intentional changes easy to review in git diffs.

Complement golden tests with **property-based testing** using the proptest crate:

```rust
proptest! {
    #[test]
    fn compile_roundtrip_preserves_semantics(input in valid_dol_program()) {
        let js_result = compile_to_js(&input)?;
        let wasm_result = compile_to_wasm(&input)?;
        
        // Both should produce same observable behavior
        assert_eq!(
            execute_js(&js_result),
            execute_wasm(&wasm_result)
        );
    }
    
    #[test]
    fn sourcemap_positions_are_valid(input in valid_dol_program()) {
        let result = compile_to_js(&input)?;
        for mapping in result.sourcemap.mappings() {
            prop_assert!(mapping.original_line <= input.lines().count());
        }
    }
}
```

---

## Exposing the compiler via MCP for AI integration

The Model Context Protocol enables AI tools to interact with DOL's compiler directly. Essential MCP tools for a language:

```typescript
const tools = [
  {
    name: "dol_check",
    description: "Type-check DOL source and return diagnostics",
    inputSchema: {
      type: "object",
      properties: {
        code: { type: "string" },
        edition: { type: "string", default: "2025" }
      }
    }
  },
  {
    name: "dol_compile",
    description: "Compile DOL source to JavaScript or WASM",
    inputSchema: {
      properties: {
        code: { type: "string" },
        target: { enum: ["js", "wasm"] },
        emit_sourcemap: { type: "boolean" }
      }
    }
  },
  {
    name: "dol_explain_error",
    description: "Get detailed explanation of an error code",
    inputSchema: {
      properties: { error_code: { type: "string" } }
    }
  }
];
```

Use streaming for long-running compilations and return structured JSON diagnostics that AI tools can parse and act upon.

---

## Conclusion

Building DOL's compiler infrastructure requires **prioritizing the JS transpilation path for rapid iteration** while designing the architecture to accommodate WASM from day one. The critical decisions are:

1. **Use Binaryen over LLVM** for WASM—simpler, faster compilation, full GC support
2. **Adopt the SWC packaging pattern** with platform-specific optional dependencies
3. **Implement editions immediately** to allow syntax evolution without breaking existing code
4. **Design the CodeGenerator trait** before implementing either backend to ensure clean separation
5. **Invest in error messages early**—they're the primary interface most developers will experience

The staged implementation should follow this sequence: parser refinement → JS codegen → runtime library → testing infrastructure → LSP server → WASM codegen → MCP integration. Each phase delivers usable functionality while building toward the complete vision of Spirits running at native speed across browser, Node, and Tauri environments.