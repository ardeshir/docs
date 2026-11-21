# DOL Modular Codegen Architecture

> **Document Version:** 1.0.0  
> **Status:** RFC (Request for Comments)  
> **Last Updated:** December 2025  
> **Problem:** 538 errors when combining 10 DOL files into single lib.rs (at time of writing)

> **Status note (DOL 0.8.2, November 2026):** the modular crate generator was implemented **in Rust** — `src/codegen/crate_gen.rs` and the `dol-build-crate` binary — not as the `crate_codegen.dol` sketched below. Running it on the 10 bootstrap files (`dol/*.dol`) still produces a crate that **fails with 850 compile errors**. `stage1/` contains only a `Cargo.toml`, `stage2/` does not exist, and `dol-build-crate` is not run in CI. **Self-hosting is not achieved**; the Stage 2 → Stage 3 verification in this RFC is planned — not implemented. The DOL snippets containing `impl` blocks are design pseudocode: `impl` does not parse in DOL 0.8.2.

---

## Executive Summary

The current DOL codegen outputs all DOL files into a single `lib.rs`, causing namespace conflicts, duplicate definitions, and import collisions. This document specifies a **modular codegen** architecture that generates a proper Rust crate structure with one module per DOL file.

### Current State (Broken)

```
dol/*.dol (10 files) → codegen → stage2/src/lib.rs (single file)
                                         ↓
                                  538 compilation errors
                                  - Duplicate: is_primitive, ModuleDecl
                                  - Missing: UseDecl, HasField
                                  - Conflicts: HashMap imported 5x
```

### Target State (Working)

```
dol/*.dol (10 files) → modular codegen → stage2/
                                         ├── Cargo.toml
                                         └── src/
                                             ├── lib.rs (mod declarations)
                                             ├── ast.rs
                                             ├── token.rs
                                             ├── lexer.rs
                                             ├── parser.rs
                                             ├── codegen.rs
                                             ├── types.rs
                                             ├── hir.rs
                                             ├── main.rs
                                             └── prelude.rs (re-exports)
```

---

## Problem Analysis

### Error Categories (538 total)

| Category | Count | Root Cause |
|----------|-------|------------|
| Type mismatches | 133 | DOL types → Rust types mapping inconsistent |
| Duplicate definitions | ~20 | Multiple files define same types/functions |
| Missing types | ~15 | Types referenced but not generated |
| Reimported symbols | ~5 | Same `use` statement in multiple files |
| Visibility errors | ~50 | Private items accessed across modules |
| Other | ~315 | Cascading from above |

### Why Single-File Fails

```rust
// Current: Everything in lib.rs

// From ast.dol
pub struct ModuleDecl { ... }
pub fn is_primitive(name: &str) -> bool { ... }

// From types.dol (CONFLICT!)
pub struct ModuleDecl { ... }  // Duplicate!
pub fn is_primitive(name: &str) -> bool { ... }  // Duplicate!

// From parser.dol
use std::collections::HashMap;

// From codegen.dol (CONFLICT!)
use std::collections::HashMap;  // Reimport!
```

### Why Modular Works

```rust
// lib.rs
pub mod ast;
pub mod types;
pub mod parser;
pub mod codegen;

// ast.rs
pub struct ModuleDecl { ... }  // ast::ModuleDecl

// types.rs  
pub struct ModuleDecl { ... }  // types::ModuleDecl (different type!)

// If they're meant to be the same type:
// types.rs
pub use crate::ast::ModuleDecl;  // Re-export, no duplication
```

---

## Architecture Design

### Module Resolution Strategy

Each DOL `module` declaration maps to a Rust module:

```dol
// dol/ast.dol
module dol.ast @ 0.4.0
```

```rust
// src/ast.rs (generated)
//! Module: dol.ast
//! Version: 0.4.0
```

### File Structure Generation

```
Input:                          Output:
dol/                            stage2/
├── ast.dol                     ├── Cargo.toml
├── token.dol                   └── src/
├── lexer.dol                       ├── lib.rs
├── parser.dol                      ├── ast.rs
├── types.dol                       ├── token.rs
├── typechecker.dol                 ├── lexer.rs
├── codegen.dol                     ├── parser.rs
├── mod.dol                         ├── types.rs
├── main.dol                        ├── typechecker.rs
└── bootstrap.dol                   ├── codegen.rs
                                    ├── main.rs
                                    ├── bootstrap.rs
                                    └── prelude.rs
```

(The bootstrap sources at v0.8.2 are these 10 files; the `pratt.dol` and `hir.dol` named in the original draft were never created.)

### Import Resolution

DOL imports need to resolve to Rust `use` statements:

```dol
// In parser.dol
use dol.ast.*
use dol.token.{Token, TokenKind}
```

```rust
// In parser.rs (generated)
use crate::ast::*;
use crate::token::{Token, TokenKind};
```

#### Import Mapping Rules

| DOL Import | Rust Output |
|------------|-------------|
| `use dol.ast.*` | `use crate::ast::*;` |
| `use dol.ast.{Expr, Stmt}` | `use crate::ast::{Expr, Stmt};` |
| `use std.collections.HashMap` | `use std::collections::HashMap;` |
| `use @external/pkg.Type` | `use external_pkg::Type;` |

---

## Implementation Specification

### New Codegen Entry Point

Design sketch (never written in DOL; the real implementation is `src/codegen/crate_gen.rs`):

```dol
// crate_codegen.dol (design sketch)

module dol.crate_codegen @ 0.4.0

use dol.ast.DolFile
use dol.codegen.RustCodegen

/// Generate a complete Rust crate from multiple DOL files
pub gen CrateCodegen {
    has files: Vec<DolFile>
    has output_dir: string
    has crate_name: string = "dol_generated"
    has crate_version: string = "0.1.0"
    
    /// Main entry point
    pub fun generate() -> Result<(), string> {
        // 1. Analyze module dependencies
        val modules = this.analyze_modules()
        
        // 2. Generate each module file
        for file in this.files {
            this.gen_module_file(file)?
        }
        
        // 3. Generate lib.rs
        this.gen_lib_rs(modules)?
        
        // 4. Generate prelude.rs
        this.gen_prelude_rs(modules)?
        
        // 5. Generate Cargo.toml
        this.gen_cargo_toml()?
        
        return Ok(())
    }
}
```

### Module Analysis

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
gen ModuleInfo {
    has name: string           // "ast"
    has full_path: string      // "dol.ast"
    has version: Option<string>
    has imports: Vec<ImportInfo>
    has exports: Vec<string>  // Public items
    has dependencies: Vec<string>  // Other modules this depends on
}

gen ImportInfo {
    has source_module: string  // "dol.token"
    has items: ImportItems     // All, or specific names
    has is_external: bool      // From @external/pkg
}

impl CrateCodegen {
    fun analyze_modules() -> Vec<ModuleInfo> {
        let modules = []
        
        for file in this.files {
            let info = ModuleInfo {
                name: this.module_name(file),
                full_path: file.module.path.join("."),
                version: file.module.version,
                imports: this.extract_imports(file),
                exports: this.extract_exports(file),
                dependencies: []
            }
            
            // Resolve dependencies from imports
            for imp in info.imports {
                if this.is_internal_module(imp.source_module) {
                    info.dependencies.push(imp.source_module)
                }
            }
            
            modules.push(info)
        }
        
        return modules
    }
    
    fun module_name(file: DolFile) -> string {
        // Extract last component of module path
        // "dol.ast" → "ast"
        match file.module {
            Some(m) { return m.path.last() }
            None { 
                // Fallback to filename
                return file.filename.replace(".dol", "")
            }
        }
    }
}
```

### Module File Generation

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
impl CrateCodegen {
    fun gen_module_file(file: DolFile) -> Result<(), string> {
        let module_name = this.module_name(file)
        let output_path = this.output_dir + "/src/" + module_name + ".rs"
        
        let codegen = RustCodegen {}
        
        // Generate module header
        let content = "//! Module: " + file.module.path.join(".") + "\n"
        content = content + "//! Generated from DOL source\n\n"
        
        // Generate imports (resolved to crate:: paths)
        content = content + this.gen_resolved_imports(file) + "\n"
        
        // Generate module contents
        content = content + codegen.gen_file_body(file)
        
        // Write file
        write_file(output_path, content)?
        
        return Ok(())
    }
    
    fun gen_resolved_imports(file: DolFile) -> string {
        let output = ""
        let seen_imports = Set::new()  // Deduplicate
        
        for use_decl in file.uses {
            let rust_import = this.resolve_import(use_decl)
            
            if !seen_imports.contains(rust_import) {
                output = output + rust_import + "\n"
                seen_imports.insert(rust_import)
            }
        }
        
        return output
    }
    
    fun resolve_import(use_decl: UseDecl) -> string {
        let path = use_decl.path.join("::")
        
        // Check if internal module
        if path.starts_with("dol.") {
            // dol.ast → crate::ast
            let internal_path = path.replace("dol.", "crate::")
            return this.format_use(internal_path, use_decl.items)
        }
        
        // Check if std
        if path.starts_with("std.") {
            let std_path = path.replace(".", "::")
            return this.format_use(std_path, use_decl.items)
        }
        
        // External package
        let external_path = path.replace(".", "::")
        return this.format_use(external_path, use_decl.items)
    }
    
    fun format_use(path: string, items: UseItems) -> string {
        match items {
            UseItems.All { 
                return "use " + path + "::*;" 
            }
            UseItems.Single { 
                return "use " + path + ";" 
            }
            UseItems.Named(names) {
                return "use " + path + "::{" + names.join(", ") + "};"
            }
        }
    }
}
```

### lib.rs Generation

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
impl CrateCodegen {
    fun gen_lib_rs(modules: Vec<ModuleInfo>) -> Result<(), string> {
        let content = "//! DOL Generated Crate\n"
        content = content + "//! Generated from DOL source files\n\n"
        
        // Sort modules by dependency order
        let sorted = this.topological_sort(modules)
        
        // Module declarations
        for module in sorted {
            if module.name == "main" {
                // main.rs is separate, not a module
                continue
            }
            content = content + "pub mod " + module.name + ";\n"
        }
        
        content = content + "\n"
        content = content + "pub mod prelude;\n"
        
        let output_path = this.output_dir + "/src/lib.rs"
        write_file(output_path, content)?
        
        return Ok(())
    }
    
    fun topological_sort(modules: Vec<ModuleInfo>) -> Vec<ModuleInfo> {
        // Sort modules so dependencies come before dependents
        // This ensures Rust compiles in correct order
        
        let sorted = []
        let visited = Set::new()
        
        fun visit(module: ModuleInfo) {
            if visited.contains(module.name) {
                return
            }
            visited.insert(module.name)
            
            for dep in module.dependencies {
                let dep_module = modules.find(|m| m.name == dep)
                if dep_module != None {
                    visit(dep_module.unwrap())
                }
            }
            
            sorted.push(module)
        }
        
        for module in modules {
            visit(module)
        }
        
        return sorted
    }
}
```

### prelude.rs Generation

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
impl CrateCodegen {
    fun gen_prelude_rs(modules: Vec<ModuleInfo>) -> Result<(), string> {
        let content = "//! Prelude - commonly used types re-exported\n\n"
        
        // Re-export public types from each module
        for module in modules {
            if module.name == "main" {
                continue
            }
            
            // Option 1: Re-export everything public
            content = content + "pub use crate::" + module.name + "::*;\n"
            
            // Option 2: Re-export only specific items (more controlled)
            // for export in module.exports {
            //     content = content + "pub use crate::" + module.name + "::" + export + ";\n"
            // }
        }
        
        let output_path = this.output_dir + "/src/prelude.rs"
        write_file(output_path, content)?
        
        return Ok(())
    }
}
```

### Cargo.toml Generation

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
impl CrateCodegen {
    fun gen_cargo_toml() -> Result<(), string> {
        let content = "[package]\n"
        content = content + "name = \"" + this.crate_name + "\"\n"
        content = content + "version = \"" + this.crate_version + "\"\n"
        content = content + "edition = \"2021\"\n"
        content = content + "\n"
        content = content + "[dependencies]\n"
        
        // Add standard dependencies
        // (Could be configurable based on what DOL code uses)
        
        let output_path = this.output_dir + "/Cargo.toml"
        write_file(output_path, content)?
        
        return Ok(())
    }
}
```

---

## Handling Duplicate Definitions

### Strategy 1: Canonical Location

Define each type in exactly one module, re-export elsewhere:

> **Planned — not implemented:** this syntax does not parse in DOL 0.8.2.

```text
// In types.dol - canonical definition
pub gen ModuleDecl { ... }

// In ast.dol - re-export if needed
pub use dol.types.ModuleDecl
```

Generated Rust:
```rust
// types.rs
pub struct ModuleDecl { ... }

// ast.rs
pub use crate::types::ModuleDecl;
```

### Strategy 2: Module-Qualified Names

If types are intentionally different, they get different qualified names:

```rust
// ast.rs
pub struct ModuleDecl { ... }  // ast::ModuleDecl

// types.rs
pub struct ModuleDecl { ... }  // types::ModuleDecl

// Usage in other modules must be explicit:
use crate::ast::ModuleDecl as AstModuleDecl;
use crate::types::ModuleDecl as TypesModuleDecl;
```

### Strategy 3: Detect and Warn

Codegen detects duplicate definitions and warns:

```dol
fun check_duplicates(modules: Vec<ModuleInfo>) -> Vec<Warning> {
    var defined = Map::new()  // name → defining module
    var warnings = []
    
    for module in modules {
        for export in module.exports {
            if defined.contains(export) {
                warnings.push(Warning {
                    message: "Duplicate definition: " + export,
                    locations: [defined.get(export), module.name]
                })
            } else {
                defined.insert(export, module.name)
            }
        }
    }
    
    return warnings
}
```

---

## CLI Integration

### Command: `dol-build-crate`

Shipped as a separate binary (there is no `dol` binary). Install with `cargo install dol --features cli`.

```bash
# Generate Rust crate from DOL files
dol-build-crate dol/*.dol -o stage2/

# With options
dol-build-crate dol/*.dol \
    --output stage2/ \
    --name dol_compiler \
    --crate-version 0.4.0

# Verify output compiles (at v0.8.2 this fails: 850 errors for dol/*.dol)
cd stage2 && cargo check
```

### Updated Workflow

> **Planned — not implemented:** only the first step runs today. The generated Stage 2 crate does not compile, so Stage 2 → Stage 3 has never been executed.

```bash
# Stage 1: Bootstrap compiler (Rust) generates Stage 2
cargo run --features cli --bin dol-build-crate -- dol/*.dol -o stage2/

# Verify Stage 2 compiles
cd stage2 && cargo build

# Stage 2: Generated compiler generates Stage 3
cd stage2 && cargo run -- build-crate ../dol/*.dol -o ../stage3/

# Verify Stage 3 matches Stage 2
diff -r stage2/src stage3/src  # Should be identical
```

---

## Migration Path

### Phase 1: Implement CrateCodegen (1-2 weeks)

1. Create `crate_codegen.dol` with module analysis (done instead in Rust: `src/codegen/crate_gen.rs`)
2. Generate multi-file output structure
3. Implement import resolution
4. Generate lib.rs and Cargo.toml

### Phase 2: Fix DOL Sources (1 week)

1. Run duplicate detection
2. Move duplicate definitions to canonical locations
3. Add re-exports where needed
4. Verify imports are explicit

### Phase 3: Verification (1 week)

1. Generate stage2 with new codegen
2. Fix remaining compilation errors
3. Achieve 0 errors
4. Verify stage2 can generate stage3

---

## Success Criteria

| Metric | Target | Status (0.8.2) |
|--------|--------|----------------|
| Compilation errors | 0 | Not met — 850 errors |
| Generated modules | 10 (one per .dol file) | — |
| Stage 2 = Stage 3 | Identical output | Not met — Stage 2 does not build |
| CI integration | `dol-build-crate` in CI | Not met — not in CI |

---

## Appendix: File-by-File Module Mapping

| DOL File | Rust Module | Primary Exports |
|----------|-------------|-----------------|
| ast.dol | ast.rs | Expr, Stmt, Decl, DolFile |
| token.dol | token.rs | Token, TokenKind, Span |
| lexer.dol | lexer.rs | Lexer, lex() |
| parser.dol | parser.rs | Parser, parse(), Precedence |
| types.dol | types.rs | Type, TypeExpr, TypeEnv |
| typechecker.dol | typechecker.rs | TypeChecker, typecheck() |
| codegen.dol | codegen.rs | RustCodegen, codegen() |
| mod.dol | (module root) | Re-exports of the other modules |
| bootstrap.dol | bootstrap.rs | Bootstrap utilities |
| main.dol | main.rs | main(), CLI handling |

---

*"From single file chaos to modular clarity."*
