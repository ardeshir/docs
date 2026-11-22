# DOL Bootstrap Process

> **Status (verified against DOL v0.8.2, 2026-11-20): Self-hosting is NOT working.**
> This page originally announced "Full Self-Hosting Achieved" for v0.2.3 "Stage2".
> That claim does not hold. See the DOL ground-truth audit
> (`docs/DOL-STATUS-2026-11.md` in the [dol repository](https://github.com/univrs/dol)).

---

## Overview

Self-hosting means the DOL compiler can compile its own source code.
It is a long-term goal of the project, not a shipped feature.

What exists at v0.8.2:
- The bootstrap sources: `dol/*.dol` — 10 files, ≈9.9k lines of DOL describing the
  compiler (AST, tokens, lexer, parser, type checker, codegen). All of them parse.
- `dol-build-crate`, which generates a Rust crate from those files.

What does not work:
- ❌ The Rust crate generated from `dol/*.dol` fails to compile with **850 errors**.
- ❌ The v0.2.2 "2,544 lines, 0 errors" result is not reproducible (the same check now gives 19 errors).
- ❌ `stage1/` contains only a `Cargo.toml`; `stage2/` does not exist.
- ❌ No stage has compiled the compiler from DOL sources.

---

## Bootstrap Stages (design)

```
Stage 0: Rust Bootstrap Compiler        — exists (src/)
         └─ Hand-written Rust implementation

Stage 1: DOL Source Files               — exists (dol/*.dol, all parse)
         └─ dol/ast.dol, dol/token.dol, dol/lexer.dol, dol/parser.dol,
            dol/typechecker.dol, dol/codegen.dol, ...

Stage 2: Generated Rust                 — Planned — not implemented
         └─ Stage 0 compiles Stage 1 → Rust (currently 850 compile errors)

Stage 3: Full Self-Hosting              — Planned — not implemented
         └─ Stage 2 compiles Stage 1 → identical output
```

---

## Codegen Fixes Made During the v0.2.x Bootstrap Attempt

These codegen issues were fixed while attempting the bootstrap (they did not make the generated crate compile):

1. **Recursive types** - `Box<T>` for self-referential types
2. **String matching** - `.as_str()` for pattern matching
3. **Derive macros** - No `Eq` for types containing f64
4. **Tuple variants** - Wrapper structs for complex variants
5. **Keyword escaping** - `r#type` for reserved words
6. **Macro invocation** - `println!()` not `println()`

---

## Verification

```bash
# Generate a Rust crate from the bootstrap sources (requires --features cli)
cargo run --features cli --bin dol-build-crate -- dol/*.dol -o /tmp/stage2

# Try to build it (the 2026-11 audit measured 850 compile errors at v0.8.2)
cd /tmp/stage2 && cargo build
```

---

## Related

The VUDO VM is developed separately in univrs/vudo; see
[PHASE2_COMPLETE.md](../vudo/PHASE2_COMPLETE.md). As of DOL 0.8.2, DOL-compiled
Spirits link and run in the VUDO VM (the Spirit Hosting H0 milestone) — that
path uses the Rust compiler in `src/`, not a self-hosted compiler.

---

## Links

- [DOL repository](https://github.com/univrs/dol)
- [Crates.io](https://crates.io/crates/dol)
- [VUDO Landing](https://vudo.univrs.io)

---

*"Systems designed to evolve and adapt to change."*

— The VUDO Team
