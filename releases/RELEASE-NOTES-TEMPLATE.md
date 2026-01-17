# Release Notes Template

**Use this template for all DOL releases starting v0.9.0.**

This template encodes commitments from critique exegesis:
- Commitment #17: Be explicit about what "compatible" means
- Commitment #18: Name trade-offs explicitly (e.g., "Rust-aligned" not just "clearer")
- Commitment #22: Critique BEFORE deployment, not after

---

## Template

```markdown
# DOL vX.Y.Z Release Notes

**Release Date:** [Date]
**Codename:** [Name]

---

## Overview

[1-2 sentence summary of the release]

---

## Design Philosophy

<!-- REQUIRED: Name the trade-offs explicitly. Don't hide design choices behind neutral language. -->

### Trade-offs in This Release

| Choice | Trade-off | Who Benefits | Who Pays |
|--------|-----------|--------------|----------|
| [e.g., Rust-aligned syntax] | [e.g., Familiarity for Rust users vs. DOL's unique identity] | [e.g., Developers coming from Rust] | [e.g., Developers who preferred original syntax] |
| [Choice 2] | [Trade-off] | [Beneficiary] | [Cost-bearer] |

**Example for v0.8.0:**

| Choice | Trade-off | Who Benefits | Who Pays |
|--------|-----------|--------------|----------|
| Rust-aligned type names (`i32` not `Int32`) | Reduced learning curve for Rust developers vs. language independence | Rust developers, WASM ecosystem | Developers from Python/JS who found `Int32` more readable |
| Shorter keywords (`gen` not `gene`) | Typing efficiency vs. semantic richness | Heavy users writing lots of code | New users who found `gene` self-explanatory |

---

## Breaking Changes

<!-- List any breaking changes with migration paths -->

[None / List of changes]

---

## Deprecations

<!-- REQUIRED: Be explicit about timelines and what "compatible" means -->

### Deprecation Policy

**"Compatible" means:** A migration path exists with a deadline. It does NOT mean permanent support.

| Deprecated | Replacement | Warning Since | Error Since | Removed In |
|------------|-------------|---------------|-------------|------------|
| [old syntax] | [new syntax] | [version] | [version] | [version] |

### Current Deprecations

| Item | Status | Deadline | Migration Tool |
|------|--------|----------|----------------|
| [e.g., `gene` keyword] | Warning | v0.9.0 (errors) | `dol-migrate 0.8-to-0.9` |
| [e.g., `String` type] | Warning | v0.9.0 (errors) | `dol-migrate 0.8-to-0.9` |

### What "Backward Compatible" Actually Means

When we say a release is "backward compatible," we mean:

1. **Your code will compile** - Old syntax produces warnings, not errors
2. **Migration tools exist** - Automated conversion is available
3. **There is a deadline** - Old syntax will eventually be removed
4. **You should migrate now** - Don't wait for the deadline

We do NOT mean:
- ❌ Old syntax will be supported forever
- ❌ You can ignore deprecation warnings indefinitely
- ❌ Future releases won't break unmigrated code

---

## Language Changes

### [Change Category]

[Description of changes]

**Why this change:**
<!-- REQUIRED: Explain the reasoning, not just the what -->

[Explanation that names the trade-off]

---

## New Features

### [Feature Name]

[Description]

---

## Migration Guide

### Prerequisites

- DOL version [X.Y.Z] or later
- [Other requirements]

### Automatic Migration

```bash
# Preview changes
dol-migrate [old]-to-[new] --diff src/

# Apply migration
dol-migrate [old]-to-[new] src/

# Verify
dol-check src/
```

### Manual Migration Steps

1. [Step 1]
2. [Step 2]
3. [Step 3]

### Migration Deadline

| Milestone | Date/Version | What Happens |
|-----------|--------------|--------------|
| Deprecation | vX.Y.0 | Warnings emitted |
| Strict mode errors | vX.Y+1.0 | `--strict` flag fails |
| Default errors | vX.Y+2.0 | All builds fail |
| Removal | vX.Y+3.0 | Old syntax no longer parsed |

**If you haven't migrated by [version], your code will not compile.**

---

## Honest Assessment

<!-- REQUIRED: Include a self-assessment section -->

### What We Got Right

- [Thing that worked well]

### What We're Uncertain About

- [Thing we're not sure was the right choice]

### What We'd Do Differently

- [Hindsight observation]

### User Impact

- **Users who will benefit:** [description]
- **Users who may struggle:** [description]
- **Users who should wait:** [description]

---

## Installation

```bash
# From crates.io
cargo install metadol --version X.Y.Z

# With CLI tools
cargo install metadol --version X.Y.Z --features cli
```

---

## Links

- [GitHub Release](https://github.com/univrs/dol/releases/tag/vX.Y.Z)
- [Migration Guide](https://learn.univrs.io/dol/migration/X.Y)
- [Changelog](../CHANGELOG.md)
```

---

## Pre-Release Critique Process

**Critique BEFORE deployment, not after.**

The release process is:

1. **Write release notes** using this template
2. **Run `/critique DOL vX.Y.Z`** on the draft release notes
3. **Run `/respond`** to add exegesis to the critique
4. **Review the critique** - sit with the discomfort
5. **Decide whether to ship** - the critique may reveal issues worth fixing first
6. **If shipping**: publish release notes, then publish critique + exegesis together
7. **If not shipping**: fix issues, return to step 1

### Why Critique Before?

From the-clarity-doctrine exegesis:

> "Post-deployment critique is accountability theater. By the time users read the critique, they've already upgraded. The discomfort arrives too late to change anything."

Pre-deployment critique creates a decision point. You might discover:
- Trade-offs you hadn't fully considered
- User groups who will be harmed
- Deprecation timelines that are too aggressive
- Features that need more testing

**The critique is not punishment. It's a final review gate.**

---

## Checklist Before Publishing

### Content Checklist
- [ ] Trade-offs section names who benefits AND who pays
- [ ] Deprecation timeline has specific version numbers
- [ ] "Compatible" is explained (migration path, not permanent)
- [ ] Migration deadline is explicit
- [ ] Honest assessment included
- [ ] Design choices use specific language (e.g., "Rust-aligned" not "clearer")

### Critique Gate Checklist
- [ ] `/critique DOL vX.Y.Z` has been run on these release notes
- [ ] `/respond` exegesis has been written
- [ ] Builder has read critique and sat with discomfort
- [ ] Decision to ship is conscious, not rushed
- [ ] Critique + exegesis ready to publish alongside release

---

## Anti-Patterns to Avoid

### ❌ Vague Compatibility Claims

> "This release is fully backward compatible."

### ✅ Explicit Compatibility Claims

> "This release is backward compatible: old syntax produces warnings but compiles. Migration deadline: v0.9.0 will emit errors in strict mode. v1.0.0 will remove old syntax entirely."

---

### ❌ Neutral Language Hiding Trade-offs

> "Syntax has been modernized for clarity."

### ✅ Explicit Trade-off Language

> "Syntax has been Rust-aligned (`i32` instead of `Int32`). This benefits developers familiar with Rust but loses the language-agnostic naming that made DOL accessible to Python/JS developers."

---

### ❌ Missing Deadlines

> "Old syntax is deprecated."

### ✅ Explicit Deadlines

> "Old syntax is deprecated. Timeline: warnings in v0.8.0, errors in v0.9.0 strict mode, removal in v1.0.0."

---

## Why This Template Exists

From critique exegesis (the-clarity-doctrine):

> "Compatible" without a deadline is a lie by omission. Users assume permanence. Builders assume migration. The gap creates technical debt and broken trust.

> Saying "clearer" when you mean "Rust-aligned" hides the trade-off. Some users found `Int32` clearer than `i32`. Clarity is subjective. Rust-alignment is a specific design choice with specific beneficiaries.

This template forces explicit answers to questions users deserve:
1. What trade-offs were made?
2. Who benefits from these choices?
3. When will old code stop working?
4. What do I need to do, and by when?

---

*"Release notes are a contract. Vague contracts breed disputes."*
