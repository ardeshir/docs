# DOL: Design Ontology Language

**Syntax: v0.8 "Clarity" · Latest toolchain release: 0.8.2 (2026-11-20)**

> **Status.** This page is a language guide, not a formal specification: no formal spec exists for the current language (`docs/grammar.ebnf` in the DOL repo is frozen at v0.0.1). The de facto reference is the lexer and parser of the `dol` crate (0.8.2) plus its CHANGELOG. "DOL 2.0" is a historical label for the language generation with expressions and functions; it is not a version number.

> "Simplicity is prerequisite for reliability." — Edsger W. Dijkstra

---

## Introduction

DOL (Design Ontology Language) is a declarative specification language that serves as the source of truth for the Univrs platform. In the DOL-first paradigm, design contracts are written before tests, and tests are written before code. Nothing changes without first being declared in the ontology.

> **Note:** As of v0.8.0 "Clarity", DOL uses modernized Rust-aligned syntax. Old syntax (`gene`, `constraint`, `exegesis`, `evolves`, PascalCase types) is deprecated but still supported with warnings; it is planned to become an error in v0.9. See [v0.8.0 Release Notes](releases/v0.8.0.md) for migration details.

DOL inverts the traditional software development flow:

```
Traditional:  Code → Tests → Documentation
DOL-First:    Design Ontology → Tests → Code
```

The ontology is not documentation of what was built. It is the declaration of what must exist.

---

## Rationale

### Why Ontology-First?

Software systems accumulate complexity. Requirements scatter across tickets, wikis, comments, and tribal knowledge. Tests verify implementation details rather than intent. Documentation drifts from reality.

DOL solves this by establishing a single authoritative layer:

- **AI agents** parse DOL to understand what should exist
- **CI/CD pipelines** validate changes against DOL before acceptance
- **Developers** read DOL as natural language intent
- **Self-healing systems** reference DOL to restore desired state (*Planned — not implemented*)

When the ontology is the source of truth, the system knows what it should be.

### Why Plain Language?

DOL uses constrained natural language rather than symbolic notation. This serves multiple purposes:

1. **Human readability** — Engineers read intent without translation
2. **AI comprehension** — Language models parse DOL natively
3. **Reduced ceremony** — No keyword proliferation, no syntactic noise
4. **Universal accessibility** — Domain experts contribute without programming knowledge

### Why Accumulative?

DOL repositories are append-only, like git history or biological evolution. Every mutation is preserved. Every adaptation is traceable. The full phylogeny is available to any node.

This accumulative model means:

- No design decision is lost
- Evolution is always auditable  
- Any node holds the complete system history
- Rollback means traversing lineage, not restoring snapshots

---

## Core Concepts

### Gen (Gene)

The atomic unit of DOL. A gen declares fundamental truths that cannot be decomposed further.

```dol
gen container.exists {
  container has identity
  container has state
  container has boundaries
}

docs {
  A container is the fundamental unit of workload isolation in Univrs.
  Every container possesses three essential properties: a cryptographic
  identity that uniquely identifies it across the network, a finite state
  that describes its current condition, and boundaries that enforce
  resource isolation and security constraints.
}
```

Gens are named with dot notation: `domain.property`. They contain only declarative statements using simple predicates: `has`, `is`, `derives from`, `requires`.

### Trait

Composable behaviors built from gens. Traits declare what a component does.

```dol
trait container.lifecycle {
  uses container.exists
  uses identity.cryptographic
  uses state.finite

  container is created
  container is started
  container is stopped
  container is destroyed

  each transition emits event
  each transition is authenticated
}

docs {
  The container lifecycle defines the state machine governing container
  existence. Containers move through discrete states via authenticated
  transitions. Every state change produces an event for observability
  and audit. The lifecycle depends on cryptographic identity for
  authentication and finite state for transition validity.
}
```

Traits compose gens with `uses` and declare behaviors with `is` statements.

### Rule (Constraint)

Invariants that must always hold. Rules define the laws of the system.

```dol
rule container.integrity {
  container.state matches declared state
  container.identity never changes
  container.boundaries is enforced
}

docs {
  Container integrity ensures the runtime matches the declared ontology.
  Once a container receives its cryptographic identity, that identity is
  immutable for the container's lifetime. State drift—where actual state
  diverges from declared state—triggers remediation. Boundary enforcement
  prevents resource escape and maintains isolation guarantees.
}
```

### Evo (Evolution)

The lineage record. Evolution blocks declare how the ontology changes over time.

```dol
evo container.lifecycle @ 0.0.2 > 0.0.1 {
  adds container is paused
  adds container is resumed

  because "workload migration requires state preservation"
}

docs {
  Version 0.0.2 extends the lifecycle to support pause and resume
  operations. This enables live migration of containers between nodes
  without losing runtime state. The original four-state model (created,
  started, stopped, destroyed) remains valid; pause and resume are
  additions, not replacements.
}
```

Evolution uses the `>` operator to denote lineage: `@ 0.0.2 > 0.0.1` reads as "version 0.0.2 descends from 0.0.1."

### System

Top-level composition declaring a complete subsystem.

```dol
system univrs.orchestrator @ 0.1.0 {
  requires container.lifecycle >= 0.0.2
  requires node.discovery >= 0.0.1
  requires cluster.consistency >= 0.0.1

  nodes requires gossip discovery
  containers is scheduled
  transitions requires consensus validation

  all operations is authenticated
  all transitions is replicated
}

docs {
  The Univrs orchestrator is the primary system composition. It combines
  container lifecycle management, peer-to-peer node discovery, and
  distributed consensus into a unified platform. The orchestrator ensures
  that containers are scheduled across available nodes, state changes are
  agreed upon by the cluster, and all operations carry cryptographic proof
  of authorization.
}
```

---

## Syntax Reference

### File Structure

A DOL file contains one or more declarations (gen, trait, rule, system, evo, fun, ...), each followed by a docs section. The template below is schematic, not parseable DOL:

```text
<declaration-type> <name> {
  <statements>
}

docs {
  <plain english description>
}
```

### Statement Types

| Statement | Usage | Example |
|-----------|-------|---------|
| `has` | Property possession | `container has identity` |
| `is` | State or behavior | `container is created` |
| `derives from` | Origin relationship | `identity derives from ed25519 keypair` |
| `requires` | Dependency | `identity requires no authority` |
| `uses` | Composition | `uses container.exists` |
| `emits` | Event production | `transition emits event` |
| `matches` | Equivalence constraint | `state matches declared state` |
| `never` | Negative constraint | `identity never changes` |

### Evolution Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `>` | Descends from | `@ 0.0.2 > 0.0.1` |
| `adds` | New capability | `adds container is paused` |
| `deprecates` | Soft removal | `deprecates container is destroyed` |
| `removes` | Hard removal (rare) | `removes legacy.behavior` |
| `because` | Rationale | `because "migration requires state"` |

### Naming Conventions

- Gens: `domain.property` — `container.exists`, `identity.cryptographic`
- Traits: `domain.behavior` — `container.lifecycle`, `node.discovery`
- Rules: `domain.invariant` — `container.integrity`, `cluster.consistency`
- Systems: `product.component` — `univrs.orchestrator`, `univrs.scheduler`

---

## Test Files

Tests live in paired `.dol.test` files. They verify that implementations satisfy the ontology. `.dol.test` is a separate line-oriented format read by `dol-test`, not by the DOL parser: a `test <subject> {` header, then one quoted `test "<name>" { ... }` block per case with `given:`, `when:` and `then:` sections (and an optional `always` line).

```text
// container.lifecycle.dol.test

test container.lifecycle {

    test "container can be created" {
        given:
            container does not exist
        when:
            create container with identity
        then:
            container has identity
            container is created
    }

    test "unsigned transitions are rejected" {
        given:
            container exists
        when:
            transition is requested without a valid signature
        then:
            transition is rejected
    }

    test "container state matches declared state" {
        given:
            container is running
        then:
            container state matches declared state
        always
    }
}
```

`dol-test` turns each case into a Rust `#[test]` function that records the given/when/then lines as comments with placeholder `assert!(true, "TODO: ...")` assertions (or an `unimplemented!()` stub with `--stubs`); you write the real assertions. The `always` line marks an invariant test. Running invariant tests continuously as runtime assertions is *Planned — not implemented*.

---

## Repository Structure

A suggested layout:

```
dol/
├── gens/
│   ├── container.exists.dol
│   ├── identity.cryptographic.dol
│   ├── state.finite.dol
│   └── node.exists.dol
├── traits/
│   ├── container.lifecycle.dol
│   ├── container.lifecycle.dol.test
│   ├── node.discovery.dol
│   └── node.discovery.dol.test
├── rules/
│   ├── container.integrity.dol
│   ├── container.integrity.dol.test
│   └── cluster.consistency.dol
└── systems/
    ├── univrs.orchestrator.dol
    └── univrs.orchestrator.dol.test
```

*Planned — not implemented:* every node in the Univrs network holds the complete DOL repository. Like git, the full history travels with the source. Like mycelial networks, every node contains the complete genetic code of the system.

---

## The Docs Section

Every DOL file concludes with a `docs` block (formerly `exegesis`). This is plain English prose that:

1. **Explains intent** — Why does this ontology element exist?
2. **Provides context** — How does it relate to the larger system?
3. **Guides implementation** — What should engineers understand?
4. **Enables AI comprehension** — Context for autonomous agents

The docs block is not optional commentary. It is part of the specification. A DOL file without docs is incomplete.

```dol
gen identity.cryptographic {
  identity derives from ed25519 keypair
  identity is self_sovereign
  identity requires no authority
}

docs {
  Cryptographic identity is the foundation of trust in Univrs. Every
  entity—container, node, user, agent—possesses an Ed25519 keypair that
  serves as its identity. This identity is self-sovereign: no central
  authority issues or validates it. The entity generates its own keypair
  and proves ownership through cryptographic signatures.

  This design eliminates certificate authorities, identity providers, and
  other centralized trust anchors. Trust emerges from cryptographic proof,
  not institutional endorsement. The choice of Ed25519 provides fast
  signature generation and verification with strong security properties.
}
```

---

## Toolchain

The tools ship as binaries of the `dol` crate and need the `cli` feature:

```bash
cargo install dol --features cli
```

This installs `dol-parse`, `dol-check`, `dol-test`, `dol-codegen`, `dol-migrate`, `dol-mcp`, `dol-build` and `dol-build-crate`. There is no single `dol` binary.

> **Known limitation (0.8.2):** `dol-parse` and `dol-check` only parse the **first** declaration in each file; anything after it is silently ignored. The library function `metadol::parse_file_all` parses whole files. The validator does not enforce types yet.

### DOL Parser (`dol-parse`)

Reads `.dol` files into an Abstract Syntax Tree for tooling consumption.

```bash
dol-parse genes/container.exists.dol --format json
dol-parse traits/ --validate
```

### Test Generator (`dol-test`)

Transforms `.dol.test` files into executable Rust tests.

```bash
dol-test traits/container.lifecycle.dol.test --output src/tests/
```

### Validator (`dol-check`)

CI gate ensuring code changes have corresponding DOL coverage.

```bash
dol-check dol/ --require-exegesis --coverage-source src/
```

### Drift Detector (`dol-drift`)

*Planned — not implemented.* A runtime daemon comparing actual system state against DOL constraints. No `dol-drift` binary exists.

---

## Development Workflow

### 1. Write DOL First

Before any code change, update or create the relevant DOL specification.

```dol
// New feature: container pause capability

evo container.lifecycle @ 0.0.2 > 0.0.1 {
  adds container is paused
  adds container is resumed

  because "live migration requires state preservation"
}

docs {
  This evolution adds pause and resume capabilities to support live
  migration between nodes without losing container state.
}
```

### 2. Write Tests

Create or update the corresponding `.dol.test` file.

```text
test container.lifecycle {
    test "container can be paused" {
        given:
            container is running
        when:
            pause container
        then:
            container is paused
            container memory is preserved
    }
}
```

### 3. Generate Test Scaffolding

```bash
dol-test traits/container.lifecycle.dol.test --output src/tests/
```

### 4. Implement Code

Write the Rust implementation to satisfy the generated tests.

### 5. Validate

```bash
dol-check dol/ --require-exegesis --coverage-source src/
cargo test
```

### 6. Deploy

Gate the change on DOL validation in your CI (for example `dol-check dol/ --ci --strict`). Platform-side enforcement is *Planned — not implemented*.

---

## Philosophy

DOL embodies several core principles:

**Specification as Source** — The ontology is not derived from code. Code is derived from ontology.

**Accumulative Evolution** — Nothing is deleted. History is preserved. Every change is traceable.

**Plain Language** — Human-readable, AI-parseable, universally accessible.

**Contracts Before Code** — No implementation without declaration.

**Self-Description** — The `docs` block ensures every element explains itself.

**Distributed Truth** — Every node holds the complete ontology. No central authority. (Design goal.)

---

## Next Steps

The latest release is **0.8.2** (2026-11-20), "Spirit Hosting H0": DOL-compiled Spirits now link and run in the VUDO VM. Bodiless `sex fun host_*` declarations import from WASM module `vudo` with the VM linker's exact signatures (15 host functions); an unknown or mis-typed host function is a compile error, and `string` arguments lower to `(ptr, len)`:

```dol
sex fun host_log(level: i64, msg: string) -> i64

sex fun hello() -> i64 {
    return host_log(2, "hello from DOL")
}
```

The univrs/vudo VM and CLI (`dol = "0.8.2"`) are currently the only production consumer of the DOL compiler. See the [Changelog](CHANGELOG.md).

Future work (*Planned — not implemented*):

- **v0.9** — Deprecated syntax becomes an error
- **Spirit Package Manager** — Mycelium registry for DOL packages
- **LSP Server** — IDE integration (only a completion-provider library exists today)
- **Self-hosting** — the DOL-in-DOL bootstrap sources parse, but the generated crate does not compile
- **v1.0** — exit criteria have not been defined

---

## Complete Example

```dol
// genes/container.exists.dol
// DOL v0.8 syntax

gen container.exists {
  container has identity
  container has state
  container has boundaries
  container has resources
  container has image
}

docs {
  The container gen defines the essential properties of a container in
  the Univrs platform. A container is an isolated execution environment
  that encapsulates a workload.

  Identity: Every container has a unique cryptographic identity derived
  from an Ed25519 keypair. This identity is immutable for the container's
  lifetime and serves as the basis for all authentication.

  State: Containers exist in discrete states (created, running, paused,
  stopped, archived). State transitions are atomic and authenticated.

  Boundaries: Resource isolation is enforced through Linux namespaces and
  cgroups. A container cannot escape its boundaries.

  Resources: CPU, memory, network, and storage allocations are declared
  and enforced. Resource limits are constraints, not suggestions.

  Image: The container's filesystem derives from an OCI-compliant image.
  The image is immutable; runtime changes use copy-on-write layers.
}
```

---

*DOL is part of the Univrs platform. For more information, visit [univrs.io](https://univrs.io).*
