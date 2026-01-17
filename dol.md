# DOL: Design Ontology Language

**Version 0.8.0 — Clarity**

> "Simplicity is prerequisite for reliability." — Edsger W. Dijkstra

---

## Introduction

DOL (Design Ontology Language) is a declarative specification language that serves as the source of truth for the Univrs platform. In the DOL-first paradigm, design contracts are written before tests, and tests are written before code. Nothing changes without first being declared in the ontology.

> **Note:** As of v0.8.0 "Clarity", DOL uses modernized Rust-aligned syntax. Old syntax (`gene`, `constraint`, `exegesis`) is deprecated but still supported with warnings. See [v0.8.0 Release Notes](releases/v0.8.0.md) for migration details.

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
- **Self-healing systems** reference DOL to restore desired state

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
  container state matches declared state
  container identity never changes
  container boundaries are enforced
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

  nodes discover peers via gossip
  containers schedule across nodes
  consensus validates state transitions

  all operations are authenticated
  all state is replicated
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

Every DOL file contains one primary declaration (gen, trait, rule, or system) followed by a docs section.

```dol
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

Tests live in paired `.dol.test` files. They verify that implementations satisfy the ontology.

```dol
// container.lifecycle.dol.test

test container.creation {
  given no container
  when container is created
  then container has identity
  then container state is created
}

test container.authentication {
  given container exists
  when transition is requested
  when request lacks valid signature
  then transition is rejected
}

test container.state.integrity {
  given container state is running
  then container state matches declared state
  always
}
```

### Test Structure

```dol
test <name> {
  given <precondition>
  when <action>
  then <postcondition>
  [always]  // for invariant tests
}
```

Tests are generated into executable code by the DOL toolchain. The `always` keyword marks tests that run continuously as runtime assertions.

---

## Repository Structure

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

Every node in the Univrs network holds the complete DOL repository. Like git, the full history travels with the source. Like mycelial networks, every node contains the complete genetic code of the system.

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
  identity is self-sovereign
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
dol-check --against src/ --require-exegesis
```

### Drift Detector (`dol-drift`)

Runtime daemon comparing actual system state against DOL constraints.

```bash
dol-drift --watch --remediate
```

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

```dol
test container.pause {
  given container state is running
  when container is paused
  then container state is paused
  then container memory is preserved
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
dol-check --require-coverage 100
cargo test
```

### 6. Deploy

The platform accepts the change only after DOL validation passes.

---

## Philosophy

DOL embodies several core principles:

**Specification as Source** — The ontology is not derived from code. Code is derived from ontology.

**Accumulative Evolution** — Nothing is deleted. History is preserved. Every change is traceable.

**Plain Language** — Human-readable, AI-parseable, universally accessible.

**Contracts Before Code** — No implementation without declaration.

**Self-Description** — The exegesis ensures every element explains itself.

**Distributed Truth** — Every node holds the complete ontology. No central authority.

---

## Next Steps

DOL v0.8.0 "Clarity" represents a major milestone. Future work includes:

- **v0.9.0** — Strict mode (deprecated syntax becomes errors)
- **v1.0.0** — Stable API, old syntax removed
- **Spirit Package Manager** — Mycelium registry for DOL packages
- **LSP Server** — IDE integration with syntax highlighting

---

## Complete Example

```dol
// genes/container.exists.dol
// DOL v0.8.0

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
