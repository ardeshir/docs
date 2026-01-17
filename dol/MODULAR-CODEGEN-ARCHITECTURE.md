# DOL Modular Codegen Architecture

> **Document Version:** 1.0.0  
> **Status:** RFC (Request for Comments)  
> **Last Updated:** December 2025  
> **Problem:** 538 errors when combining 10 DOL files into single lib.rs

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
├── pratt.dol                       ├── token.rs
├── types.dol                       ├── lexer.rs
├── codegen.dol                     ├── parser.rs
├── hir.dol                         ├── pratt.rs
├── main.dol                        ├── types.rs
└── bootstrap.dol                   ├── codegen.rs
                                    ├── hir.rs
                                    ├── main.rs
                                    ├── bootstrap.rs
                                    └── prelude.rs
```

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

```dol
// crate_codegen.dol (new file)

module dol.crate_codegen @ 0.4.0

use dol.ast.DolFile
use dol.codegen.RustCodegen

/// Generate a complete Rust crate from multiple DOL files
pub gen CrateCodegen {
    has files: List<DolFile>
    has output_dir: String
    has crate_name: String = "dol_generated"
    has crate_version: String = "0.1.0"
    
    /// Main entry point
    pub fun generate() -> Result<(), String> {
        // 1. Analyze module dependencies
        let modules = this.analyze_modules()
        
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

```dol
gen ModuleInfo {
    has name: String           // "ast"
    has full_path: String      // "dol.ast"
    has version: Option<String>
    has imports: List<ImportInfo>
    has exports: List<String>  // Public items
    has dependencies: List<String>  // Other modules this depends on
}

gen ImportInfo {
    has source_module: String  // "dol.token"
    has items: ImportItems     // All, or specific names
    has is_external: Bool      // From @external/pkg
}

impl CrateCodegen {
    fun analyze_modules() -> List<ModuleInfo> {
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
    
    fun module_name(file: DolFile) -> String {
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

```dol
impl CrateCodegen {
    fun gen_module_file(file: DolFile) -> Result<(), String> {
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
    
    fun gen_resolved_imports(file: DolFile) -> String {
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
    
    fun resolve_import(use_decl: UseDecl) -> String {
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
    
    fun format_use(path: String, items: UseItems) -> String {
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

```dol
impl CrateCodegen {
    fun gen_lib_rs(modules: List<ModuleInfo>) -> Result<(), String> {
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
    
    fun topological_sort(modules: List<ModuleInfo>) -> List<ModuleInfo> {
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

```dol
impl CrateCodegen {
    fun gen_prelude_rs(modules: List<ModuleInfo>) -> Result<(), String> {
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

```dol
impl CrateCodegen {
    fun gen_cargo_toml() -> Result<(), String> {
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

```dol
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
fun check_duplicates(modules: List<ModuleInfo>) -> List<Warning> {
    let defined = Map::new()  // name → defining module
    let warnings = []
    
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

### New Command: `dol build-crate`

```bash
# Generate Rust crate from DOL files
dol build-crate dol/*.dol -o stage2/

# With options
dol build-crate dol/*.dol \
    --output stage2/ \
    --crate-name dol_compiler \
    --crate-version 0.4.0

# Verify output compiles
cd stage2 && cargo check
```

### Updated Workflow

```bash
# Stage 1: Bootstrap compiler (Rust) generates Stage 2
cargo run --bin dol -- build-crate dol/*.dol -o stage2/

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

1. Create `crate_codegen.dol` with module analysis
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

| Metric | Target |
|--------|--------|
| Compilation errors | 0 |
| Generated modules | 10 (one per .dol file) |
| Stage 2 = Stage 3 | Identical output |
| CI integration | `dol build-crate` in CI |

---

## Appendix: File-by-File Module Mapping

| DOL File | Rust Module | Primary Exports |
|----------|-------------|-----------------|
| ast.dol | ast.rs | Expr, Stmt, Decl, DolFile |
| token.dol | token.rs | Token, TokenKind, Span |
| lexer.dol | lexer.rs | Lexer, lex() |
| parser.dol | parser.rs | Parser, parse() |
| pratt.dol | pratt.rs | PrattParser, Precedence |
| types.dol | types.rs | Type, TypeExpr, TypeEnv |
| codegen.dol | codegen.rs | RustCodegen, codegen() |
| hir.dol | hir.rs | HirExpr, HirModule |
| bootstrap.dol | bootstrap.rs | Bootstrap utilities |
| main.dol | main.rs | main(), CLI handling |

---

*"From single file chaos to modular clarity."*
