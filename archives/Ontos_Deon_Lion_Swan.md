# Univrs: Ontos → Deon → Lion & Swan

### Ecosystem strategy, grounded in the repositories

Nov 14, 2026 · @Sepahsalar · supersedes *"Univrs Ecosystem Strategy — Ontos, Mycelium, Myth"* (`complete_plan.md`)

Aligned with: [`univrs/network` › `docs/SPIRIT-HOSTING-PLAN.md`](https://github.com/univrs/network/blob/docs/spirit-hosting-plan/docs/SPIRIT-HOSTING-PLAN.md) (Proposed, 2026-11-08)

---

## 0. What changed from the previous version

The first version was written from outside. It had landing-page blurbs and the Lion & Swan text, and it named four gaps:

1. DOL's primitives.
2. The mycelium economy.
3. imagine.univrs.io.
4. What "WC/DK" means.

All four are answered in the repos under `~/repos/*`. This version swaps the proposals for what the code and docs actually say, and cites the file each time. Where code and documents disagree, it says so. Three findings change the strategy:

1. **Univrs is already partly written in DOL.** `metalearn.org/ontology/index.dol` declares `system univrs.ecosystem @ 0.1.0`. Step 1 is therefore "finish and promote" rather than "start", and it is incomplete in a measurable way.
2. **There is no single mycelium economy. There are three, and they contradict each other.** The running code (`univrs-enr`) has transferable, non-decaying credits with a fiat bridge. The older ontology (`univrs-network/ontology/economics.dol`) has decaying, non-transferable credits that can never be exchanged for fiat. The narrative (nexus, imagine) promises creator payouts, and nothing implements them. Reconciling the three is the Deon layer's first job.
3. **The thin thread is blocked at the Ontos layer before it reaches economy or myth.** No node can run a Spirit. `vudo publish` and `vudo summon` are simulated. The DOL compiler, `dol-abi` and the VM disagree on the host ABI. The Spirit Hosting Plan (H0 → H1 → H2 → S → M) is the critical path for every recommendation below.

---

## 1. The shape in brief

Univrs is one experiment run at three depths:

- **Ontos — what can exist.** DOL, the VUDO VM, Spirits.
- **Deon — what ought to be possible.** The mycelial economy (ENR): who can give, take, accumulate, and be cut off.
- **Myth — how conduct is judged.** The Lion and the Swan, including the community's judgment of Univrs itself.

The economy and the myth are not additions to the Ontos → Deon thesis. They are the two-thirds of it that software alone cannot supply.

Three recommendations follow, now stated against what exists:

1. **Make the self-description true and canonical.** `metalearn.org/ontology/` already models Univrs in DOL. Complete it, move it to `univrs-dol`, and make it describe what runs rather than what is hoped for.
2. **Reconcile the economy into one ontology of rules, each marked as encoded or emergent.** "Encoded" must mean enforced by host code (VM host functions, ENR bridge), not just written in DOL. The DOL→WASM backend ignores `rule`/`system` declarations.
3. **Make "The Narrative: The Lion & The Swan" the first full production.** The learn.univrs.io capstone already scaffolds it. It should ship on Spirit hosting (H1/H2) and pay its makers through ENR credits, so that one project exercises all three layers.

---

## 2. Layer 1 — Ontos: what Univrs is made of

### 2.1 The kinds of things, corrected against the repos (seven + DOLOS)

| Kind | In Univrs | Where it lives | State today |
| --- | --- | --- | --- |
| Language | **DOL — Design Ontology Language** v0.8.1 (crate `dol`, lib `metadol`) | `univrs-dol` | Real. Parser, checker, codegen and a WASM backend (beta, 161 tests). |
| Toolchain | DOL binaries: `dol-parse`, `dol-check`, `dol-test`, `dol-codegen` (rust/typescript/jsonschema), `dol-build`, `dol-migrate`, `dol-mcp`, `vudo`. Native LLVM (beta), MLIR behind a feature flag, WIT codegen | `univrs-dol/Cargo.toml`, `COMPILER-TARGETS.md` | Real, mostly beta |
| | LLVM Translation MCP (Julia→Zig/Rust via LLVM IR) | `llvm-translation-mcp` | Real, but **not connected to DOL**. It is a sibling meta-tool. |
| | Skills framework (cross-repo Claude Code skills: build, test-all, dol-release, ecosystem-health…) | `univrs-skills` | Real. Developer tooling, not a language feature. |
| Runtime | **VUDO VM** ("Virtual Universal Distributed Operations"): wasmtime 27, fuel metering, 15 `host_*` syscalls, capability grants | `univrs-vudo/vudo` (`vudo_vm`, `spirit_runtime`, `vudo_cli`, `vudo_repl`) | VM library real (367 tests per the Spirit Hosting Plan). CLI partly simulated. Host backends in-memory only. |
| Operating system | **DOLOS — the DOL Operating System** (L6; formerly "VUDO OS"). It hosts, places, moves and retires Spirits across nodes: lifecycle (Seed→…→Decompose), scheduler, migration, Loa services, Spells, Medium (MCP). It is named for Dolos, the Greek trickster whose forged Truth had no feet; its rule is never to report success without doing the work. | Planned in `mycelial-node` (`SpiritHost`, Spirit Hosting Plan H1/S/M) on top of `univrs-vudo` | **Design only.** No lifecycle, scheduler or migration code exists. *VUDO* remains the platform brand; *VUDO VM* is L5. |
| Package | **Spirit**: WASM module + manifest + Ed25519 signature | `spirit_runtime/src/manifest.rs`, `univrs-vudo/spirits/` | Signing and local registry real. Publish and summon simulated. No network registry. |
| Agent | Creators/Developers/Researchers (vudo landing page); peers/nodes (network); roles Leaf/Nexus/PoteauMitan (ENR); AI agents (tarot: Lumen, Morrow, Orpheus, Vesper) | various | **No code defines "Saint", and the documents treat it as a currency, not a role.** `univrs-docs/direct-saints.md` (Jan 2026) defines **Saints as closed-loop ecosystem credits**. They are earned by contribution (corporate cloud donations first) and paid to artists and developers for Spirits. They are **not pegged 1:1 to USD and not redeemable for USD**, "by design", to stay outside the GENIUS Act. `nexus/nexus-rebels-strategy.md` still says "SAINT tokens … 1-to-1 USFed". |
| Substrate | **Mycelial network**: libp2p 0.54 (gossipsub, Kademlia, mDNS) + ENR bridge; 4 live nodes (GCP, Hetzner, AWS, Azure) behind nexus.univrs.io | `univrs-network`, `univrs-enr` | Real P2P plus credits/gradients/election/septal gossip. Nodes cannot run Spirits. |
| Theory | **Nexus Paradigm**: Assembly Theory as computational infrastructure; artificial ontogenesis; "Gentropy"; Spirits as "the Unit of Executable Ontology" | `metalearn.org/docs/nexus.md`, `metalearn.org/src/app/paradigm` | Written, with falsification criteria. |

Supporting crates the first version did not list: `univrs-identity` (Ed25519, `SignedClaim`, encrypted key storage, "no central authority issues or revokes identities") and `univrs-state` (versioned KV, SQLite and memory). `univrs-orchestration` is a 12-crate container orchestrator with youki, Chitchat and MCP. Its `scheduler_interface` scoring types are reused by the Spirit Scheduler.

The VUDO vocabulary already maps the roles mythically (`vudo.univrs.io/VUDO-LANDING-VISION.md:157-168`):

| Technical term | VUDO name |
| --- | --- |
| module | Spirit |
| function | Spell |
| session | Séance |
| service | Loa |
| network | Mycelium |
| hub | Mitan |
| token | Gris-Gris |
| admin | Mambo |

**Decision needed:** the strategy uses "Saints" for the *people* who create and distribute. `direct-saints.md` uses "Saints" for the *credits* they earn. Pick one meaning. Recommendation: follow `direct-saints.md`, so that Saint = the closed-loop credit unit, and make the ENR `Credits` type *be* Saints. Name the creator role separately (e.g. in VUDO vocabulary). Retire "1-to-1 USFed" from `nexus-rebels-strategy.md`, which contradicts both `direct-saints.md` and `economics.dol`.

### 2.2 DOL's actual primitives

From `univrs-dol/src/lexer.rs:1270-1376` and `src/ast.rs`:

- **Declarations:** `gen` (was `gene`), `trait`, `rule` (was `constraint`), `system`, `evo` (was `evolves`), `docs` (was `exegesis`), `fun`, `const`, `sex var`. The old forms are deprecated in 0.8 and become errors in 0.9.
- **Predicates:** `has`, `is`, `derives from`, `requires`, `uses`, `emits`, `matches`, **`never`**, `adds`, `deprecates`, `removes`, `because`.
- **Logic:** `forall`, `exists`, `each`, `all`, `no`, `implies`, `not`, plus `law` for algebraic properties.
- **Tests:** `test`, `given`, `when`, `then`, `always`.
- **Other:** `spirit`, `module`, `use`, `pub`, `state`, `migrate`, `extends`, `type`, `this`, and a full expression language.
- **Every declaration must carry a `docs` block.** Exegesis is mandatory.

A representative example (`univrs-dol/examples/genes/graph.dol`):

```dol
gen Graph<N, E> {
  has nodes: Vec<N>
  has edges: Vec<Tuple<u64, u64, E>>
  rule no_self_loops {
    forall edge in this.edges.
      edge.0 != edge.1
  }
  law undirected_symmetry {
    forall (i, j, e) in this.edges.
      (j, i, e) in this.edges
  }
}
```

What this means for the thesis:

- **"Record becoming, not only being" is already a language primitive.** `evo name @ new > parent { adds … deprecates … removes … because "…" }` stores version, parent version and rationale as "an accumulative history" (`ast.rs:733-781`). The missing piece is runtime. Spirits have no lineage in code. Fork attribution (`registry.dol`: "each fork transfers attribution_credits", content-addressed by `wasm_hash`) exists only in spec. Note also that `migrate {}` blocks are parsed and then discarded (`parser.rs:1139`).
- **The Deon layer has no deontic grammar.** There are no `must`/`may`/`forbidden`/`obligation` keywords. `never` expresses impossibility, which is the encoded case. Nothing in DOL can express "possible, visible, and judged", which is the emergent case. This is the first concrete *thinness test failure*. Recommendation: before adding keywords, prototype the emergent case as a convention, for example a `rule` paired with an `emits violation_observed` event that the host logs instead of blocking. Promote it to syntax only if it recurs.
- **Encoded rules are not executed.** The WASM backend ignores `trait`/`rule`/`system` declarations (`COMPILER-TARGETS.md`). A DOL `rule` today is documentation plus a `dol-check` target, not runtime enforcement. Enforcement has to live in host code until codegen catches up.

### 2.3 Univrs in DOL: what exists, what is missing

`metalearn.org/ontology/index.dol`:

```dol
system univrs.ecosystem @ 0.1.0 {
  requires core.primitives >= 0.1.0     requires economics.credit >= 0.1.0
  requires core.identity >= 0.1.0       requires economics.reputation >= 0.1.0
  requires network.peer >= 0.1.0        requires assembly.assembly_index >= 0.1.0
  requires orchestration.node >= 0.1.0  requires assembly.evolution_chain >= 0.1.0   ← file does not exist
  requires orchestration.workload >= 0.1.0  requires assembly.selection >= 0.1.0
  all entities is identifiable
  all operations is authenticated
  all state_changes is logged
  all specifications is evolvable
}
```

Gaps, each of which is a task:

1. `assembly.evolution_chain` is required but missing. This is the "record becoming" module itself.
2. There is no `vudo.*` or `spirits.*` dependency, although specs exist in `univrs-vudo/ontology/prospective/{vudo-vm,spirits}/`.
3. No Saint/agent role, no myth module, no ENR modules. The ENR DOL lives separately in `univrs-enr/dol/{core,nexus,pricing,revival,septal}.dol`.
4. `all operations is authenticated` is false today. Credit and gradient gossip carry `signature: vec![] // TODO` (`enr_bridge/credits.rs`, `gradient.rs`).

There are 419 `.dol` files across the repos. Ontology fragments are scattered across metalearn.org, univrs-network, univrs-enr, univrs-orchestration, univrs-vudo and cryptosaint.io. **The self-description test is therefore partly a consolidation test:** one canonical `univrs.ecosystem` under `univrs-dol/ontology/univrs/`, importing the others by version, with each `requires` resolving.

### 2.4 Runtime ground truth (from the Spirit Hosting Plan, §1)

| Real | Simulated or missing |
| --- | --- |
| DOL→WASM compiler (beta) | No `mycelial-node` dependency on wasmtime or `vudo_vm`: **nodes cannot run Spirits** |
| VUDO sandbox, fuel, 15 host functions, capabilities | **Host ABI mismatch:** the compiler imports module `loa`; `dol-abi` declares `vudo_*` (22); the VM provides `host_*` (15). No name matches across all three. |
| Ed25519 signing; local registry `~/.vudo/registry/` | `vudo build` writes a placeholder; `vudo run` only checks magic bytes; `publish` sleeps 1 s and prints a URL; `summon` writes `"Summoned Spirit placeholder"`; `imaginarium.vudo.univrs.io` does not resolve |
| libp2p mesh; ENR gradient plumbing | Gradients are hand-entered from the dashboard; nodes don't measure themselves |
| Browser `/editor` on vudo.univrs.io: Monaco + `dol-wasm`; real WASM for `fun` declarations | Manifest has no resource needs; no Spirit lifecycle (Seed→…→Decompose); no state snapshot; no Spirit distribution topic; `vudo-p2p` (iroh) fails to compile |

Signature verification is off by default (`require_signatures = false`, `registry/local.rs:960`). `publish` warns on unsigned packages and proceeds.

---

## 3. Layer 2 — Deon: the mycelial economy (ENR)

ENR = **Entropy-Nexus-Revival** (`univrs-enr/README.md` §1.1). One doc expands it as "Economic Network Resources" (`nexus/decentralized-infrastructure-brief.md:44`); fix that.

### 3.1 Three specs that disagree

| | (A) `univrs-enr` code, ~8.1k LOC, 114 tests | (B) `univrs-network/ontology/economics.dol`, marked "PROSPECTIVE" | (C) Narrative: nexus, imagine, cryptosaint |
| --- | --- | --- | --- |
| Unit | `Credits { amount: u64 }`, "conserved across transfers" | credits that "decay linearly over 30 days" | **Saints**: closed-loop credits, not USD-pegged (`univrs-docs/direct-saints.md`); vs. "SAINT tokens… 1-to-1 USFed" (`nexus-rebels-strategy.md`) |
| Transfer | Free transfers, 2% entropy tax | `no_direct_transfer`; credits earned by attestation | "Spirits earn credits each time they are summoned" (imagine index) |
| Fiat | `src/fiat/` StripeBridge: credit→fiat *spend* via Stripe Issuing, rate-limited by policy | "NOT… exchanged for fiat" | Saints "CANNOT" be redeemed for USD or used outside the ecosystem (`direct-saints.md`); interest-free mutual credit, BRICS Pay alignment (cryptosaint) |
| Hoarding | Nothing prevents it | `decay_is_mandatory`: `credit_value(age) = amount·(1 − age/30d)` | "hoarding earns nothing" (the previous strategy's rule 3) |

These cannot all be true. **Choosing among them is the Deon decision,** and it should be made in DOL with an `evo` record whose `because` states why. Recommendation: keep (A)'s conserved, running credits as the base and add (B)'s anti-hoarding as demurrage on idle balances, which is cheaper than banning transfers. Treat the fiat bridge as an explicit `septal` boundary: possible, logged, judged. **Check it against `direct-saints.md` first.** A credit→fiat spend card lets Saints buy goods outside the ecosystem, which that document rules out to keep the credits outside the GENIUS Act. This is a regulatory question, not only a design one. Drop "1-to-1 USFed".

### 3.2 The founder questions, answered from the repos

| Question (previous version) | Answer found | Source |
| --- | --- | --- |
| Unit of account | **Credits** (u64), not pegged to energy, compute or fiat. Each new node self-grants `INITIAL_NODE_CREDITS = 1000`. Proposed earn rates: 10/GB relayed, 1/GB-hour stored, 5/hour online, 20/positive attestation. | `univrs-enr/src/core/types.rs`; `enr_bridge/credits.rs`; `economics.dol` |
| What counts as contribution, who measures | Reputation `R(T) = 0.7·R(T−1) + 0.3·C(T)` (implemented). Nexus election weights uptime 0.3 / bandwidth 0.3 / reputation 0.2 / connectivity 0.2 (implemented). Contribution score weights (planned): uptime 20, relay 25, storage 25, vouches 20, disputes 10. **No measurement: nodes don't self-report; gradients are hand-entered.** | `mycelial-core/src/reputation.rs`; `univrs-enr/src/nexus/election.rs`; `PHASE6_ECONOMICS.md`; `SPIRIT-HOSTING-PLAN.md` §1 |
| How creators are rewarded (in Saints) | Designed in `direct-saints.md` ("Artists/Developers receive Saints for Spirits"; V1 database ledger planned May–Dec 2026). **Not in code.** "Creator writes Spirit → user summons, pays → creator receives credits → entropy tax funds revival." No split percentages. VUDO Phase 3, "Creators Get Paid", gate not met. The manifest has `[pricing] base_cost, per_fuel_cost`, which no code uses yet. | `nexus/nexus-rebels-strategy.md:111-126`; `nexus/vudo-nexus-alignment.md`; `spirits/thermodynamic/manifest.toml` |
| Who pays for compute and storage | Users, per job: `price = base + entropy·FACTOR` + 2% tax, reserve → consume → release. Hosted Spirits: "reserve before run, consume per fuel" (H1). The VM credit backend is in-memory only. The real 4 cloud nodes are funded by "grants and volunteer contributions" initially; the funder is not stated. | `univrs-enr/README.md` §4.3; `SPIRIT-HOSTING-PLAN.md` H1; `nexus/digital-commons-onepager.md:133` |
| Sybil resistance | **None in code.** Ed25519/DID identity exists. Signatures are empty `TODO`s ("In MVP, we trust broadcasts"). Every new identity mints 1000 credits. "Anti-sybil measures" is an open task. | `enr_bridge/credits.rs:136,178`; `PHASE6_ECONOMICS.md:83` |

### 3.3 The mycelium rules, classified

| # | Rule | Status in code | Recommended mode |
| --- | --- | --- | --- |
| 1 | No central treasury | Half-true. No treasury, but a collective **Revival Pool** fed by a 2% entropy tax and split 40% maintenance / 25% new-node subsidy / 20% low-balance support / 15% reserve (`univrs-enr/src/revival/pool.rs`). **The deployed network bridge debits the tax and credits it nowhere; it is burned** (`enr_bridge/credits.rs:95-118`). Only the optional `openraft` scaffold routes it to the pool. | **Encoded:** tax must reach the pool (ENR Invariant 1, conservation, is violated today) |
| 2 | Value moves toward need | Only the subsidy and low-balance pool splits. ENR's own README rejects charity framing: "Markets, Not Charity… Fungi are active traders." | **Emergent:** gradients price scarcity; the pool is the floor |
| 3 | Hoarding earns nothing | Not in (A). Demurrage in (B), unimplemented | **Encoded as demurrage** on idle balances (decision §3.1) |
| 4 | No one can be cut off | **Contradicted by design:** septal gates isolate failing nodes (`FAILURE_THRESHOLD = 5`, `ISOLATION_THRESHOLD = 0.7`), and ENR Invariant 5 says `isolated(node) implies no_credit_flow(node)` | **Reframe:** isolation must be *temporary, visible and appealable*. Encode the "healing" path, not "never isolated". |
| 5 | Provenance cannot be erased | Not in code. `evo` in DOL; `wasm_hash` and attribution in `registry.dol` spec | **Encoded:** content-addressed Spirits (H2) + `assembly.evolution_chain` |
| 6 | Messages are authenticated | Spec says so (`all operations is authenticated`). Code has empty signatures. | **Encoded:** sign and verify credit/gradient messages before any payout flow |

ENR's written invariants (`univrs-enr/README.md` §3.2, partial checker in `src/core/invariants.rs`) are the right encoded core: conservation, non-negative entropy, revival completeness, nexus consistency, septal safety. Rule 1 shows they are not enforced end to end on the deployed path.

**The White Swan test case,** "the pleasure of having more than others", now has a concrete answer to choose. Under (A) it is possible and invisible. Under (B) it is impossible. The recommendation (demurrage plus public balances via the dashboard) makes it **possible, costly and visible**, which is the emergent mode the thesis needs.

### 3.4 Remaining economic decisions (genuinely open)

- Revenue split between Spirit creator, hosting node and Revival Pool on each summon.
- Whether the fiat bridge stays, and where its septal boundary sits.
- The sybil mechanism: vouch-weighted initial credits (instead of a flat 1000), or attestation-only minting as in (B).
- Who funds the four live nodes until the credit system can.

---

## 4. Layer 3 — Myth: the Lion and the Swan

### 4.1 Where the myth actually lives

| Artifact | Location | Content |
| --- | --- | --- |
| Founding text | `univrs-docs/archives/Lion_and_swan.md` (502 lines; published via book.univrs.io › philosophy-and-essays › lion_and_swan) | "Forging a New Myth of Resistance" (Winged Lion as Destructive State; Biblia as Swan; Gnostic prison; Prometheus vs. Lucifer), **duplicated at lines 1–170 and 171–360**; then "Nexus Tools", "The Moral Inversion as Narrative Technology", "The Self-Interrogating Myth", "The Detached Perspective: A Historian in the Post-Abundance Future", "Bringing This to Aesthetic Form: The VUDO VM 'Spirits' Architecture", "The Risk to Name" |
| Companion texts | `univrs-docs/archives/{Biblia,Mythic_Rebellion,Manifest}.md` | Swan/Biblia lineage, rebellion, manifesto |
| Taught form | `learn.univrs.io/content/reference/mythology.mdx` | Black Lion "Obsidian black… Guardian of Harmony", White Swan pearl; four scene types (Confrontation, Interrogation, Transformation, Revelation); TheBook: "Those who read TheBook become its authors." |
| Buildable form | `learn.univrs.io/content/tutorials/capstone/001–007` + `content/checkpoints/capstone-001…007` | **"Capstone: Lion & Swan"**: ontology → setup → symbols → image-gen → narrative → gallery → credits (`capstone-006-credits/src/credits.dol`) → tests → publish |
| imagine.univrs.io | `imagine.univrs.io/src/pages/` | **No Lion & Swan content.** Routes: `/` "Protect Your Spirit", `/manifesto` (Sovereignty, Creation, Bondieu, Entropy, Ontology), `/architecture` (7-layer honest status), `/seam` (the DOL→WASM gap), `/letter` (Integral Collective alliance), `/grid-commons`. Community = one D1 table, `subscribers`. |
| Sigil | `univrs.io/about.html` | "The Sun Lion & The Mycelium": Shir-o-Khorshid, "strength in service of illumination" |

So the myth exists as text, as a reference page and as a seven-step tutorial. **It does not yet exist as a Spirit or on the Imaginarium.** The capstone is the nearest artifact to "Spirits v0".

**WC/DK = WorldCenterer Dynamic Knowledge.** It is the animation-design principles for knowledge architecture: "a knowledge system [is] a place you move through, not a set of screens you look at" (`~/sepah/wcdk.md`, 2026-10-22, outside `repos`). It is applied in imagine `/seam` and `metalearn.org/public/elements-3d.html`. WC/DK is the presentation grammar for the myth: Lion & Swan worlds should be places you move through.

### 4.2 Two tellings, one pair of symbols

| | Founding telling | Inversion, thousands of years on |
| --- | --- | --- |
| Lion | The Winged Lion: a destructive State whose protection is a cage | The Black Lions: descendants of Univrs, keepers of a harmony that works |
| Swan | Biblia as a Swan: living truth, transformation, rebellion | The White Swans: revivalists of TheBook, restoring war, greed and dominion |
| What it warns against | Control presented as protection | Regression presented as liberation, and harmony hardening into stagnation |

Each symbol changes sides, so no generation inherits moral authority. Note the sigil collision: Univrs's own emblem is a lion (Shir-o-Khorshid). That is an asset. The project carries the Lion's risk on its face, and the Interrogation should say so.

### 4.3 The Book is the hinge, now concretely

The Venetian lion's book is open in peace and closed in war. For Univrs the book is DOL and the ontologies written in it, so "open" has testable meaning:

- **Readable:** mandatory `docs` blocks already enforce exegesis.
- **Revisable:** `evo` records already make every change carry a `because`.
- **Forkable:** not yet. There is no network registry, no fork attribution in code, and no way for a rival ontology to run (H2, step 6 below).
- **Closed-book risk, present today:** public claims that outrun the code. Examples are imagine L5 "ENR Host Functions: done" (none exist) and "Spirits earn credits each time they are summoned" (no summon exists). A myth about an open book cannot sit on a site with unfounded claims. Fix these in V (§6).

### 4.4 From story to Spirits

The five templates (in `Lion_and_swan.md`):

- **The Interrogation**
- **The Revivalist Probe**
- **The Keeper's Doubt**
- **The Swan's Recognition**
- **The Crossover**

`mythology.mdx` adds four scene types, which act as the templates' building blocks:

- Confrontation
- Interrogation
- Transformation
- Revelation

The Spirit primitives specified in the founding text:

- **Motion:** Lion "deliberate, grounded, protective"; Swan "quick, darting, ambitious".
- **Sound signatures.**
- **Interactive states.**
- **Moral-ambiguity markers.**

The mapping to real VUDO features:

| Myth element | VUDO/DOL mechanism |
| --- | --- |
| Symbol (Lion, Swan) | `gen` with `has` motion/sound/state; `evo` for the side-change across tellings |
| Moral-ambiguity marker | the emergent-rule convention (§2.2): an observed, not blocked, violation |
| Template | a `system` composing symbols, scenes and a test (`given/when/then`) that states the experiment |
| Playing a template | instantiating the Spirit in a sandbox; results emitted as events |
| Judgment | an `evo` on the community's own ontology, `because` = the verdict |

### 4.5 Four cautions (unchanged in substance, now with evidence)

- **Ranked humanity.** The founding text's Gnostic sorting (unaware / capable / enlightened) contradicts "No root node" (`univrs.io/roadmap.html`). Keep awakening as something any node can do.
- **Two endings.** The founding text ends in transcendence ("Integrating Concepts of Transhumanism as a Means of Escaping the State's Control"). The inversion ends in harmony with nature. The canon should choose one, or stage the contradiction on purpose.
- **Paralysis.** Lead with the founding telling; introduce the inversion as a practice (the Interrogation), not a preface.
- **Public reading.** The founding text is explicitly "Rebellion Against Destructive State Power", and cryptosaint aligns with BRICS Pay. Public material must stay clearly mythic and aimed at *extraction and unaccountable control*, not at any particular government.

---

## 5. The complete shape

```
   ┌──────────────── ONTOS: what can exist ─────────────────┐
   │  DOL (gen/trait/rule/system/evo/docs)                  │
   │  VUDO VM (sandbox, fuel, host_*), Spirits (signed)     │
   └───────────────┬────────────────────────────────────────┘
                   │ sets what can be expressed
   ┌───────────────▼──────────── DEON: what ought to be possible ┐
   │  ENR credits, entropy tax, Revival Pool, septal gates,      │
   │  reputation, gradients — each rule ENCODED or EMERGENT      │
   └───────────────┬─────────────────────────────────────────────┘
                   │ sets what there is to judge
   ┌───────────────▼──────────────── MYTH: how conduct is judged ┐
   │  Lion & Swan; five templates; the Interrogation             │
   └───────────────┬─────────────────────────────────────────────┘
                   │ verdict written back as  evo … because "…"
                   └──────────────────────────► ONTOS
```

Software can show which norms are possible and stable. It cannot say which are right. The Interrogation is where that verdict is made, by people, in public. DOL's `evo … because` is where the verdict is written down so it can be tested again.

---

## 6. Strategy: one thin thread, in order

Build one thread through all three layers before widening any of them. The first three steps are the Spirit Hosting Plan. Nothing in the economy or the myth can run until a node can host a Spirit. Each step has exit oracles, including **negative oracles** (states that must never occur).

| Step | Layer | What | Exit oracles |
| --- | --- | --- | --- |
| **0. Toolchain truth** (= Hosting H0) | Ontos | Canonical host ABI = VM linker (module `vudo`, `host_*`) (D2). `dol-abi` and the compiler align. `vudo build` calls `metadol::compile_source`. `vudo run` uses a real `Sandbox`. `publish`/`summon` fail honestly. **Public claims corrected** on imagine `/architecture` and the index. | A DOL Spirit calling `host_log` runs in the VM and logs. ✗ never: placeholder WASM; `publish`/`summon` reporting success without doing the work; a site claim without a citing test. |
| **1. Univrs in DOL** | Ontos | Move `metalearn.org/ontology/` into `univrs-dol/ontology/univrs/` as canonical. Add `assembly.evolution_chain`, `vudo.*`, `spirits.*`, `enr.*`, the agent roles and `enr.saints` (Saint = closed-loop credit, per `direct-saints.md`), `myth.*`. Publish the primitives list (§2.2) next to it. | `dol-check` resolves every `requires`. A newcomer can learn what Univrs is from that tree alone. ✗ never: a `requires` on a missing module; a declaration without `docs`. |
| **2. Hosting** (= H1, H2) | Ontos | `mycelial-node` feature `spirit-host` embeds `vudo_vm` (D1). Real storage/credit/network backends. Manifest `resources`. Spirit lifecycle. Distribution over libp2p by content hash (D3). Kademlia name→hash. Real `publish`/`summon`. | Publish on node A, summon and run on node C. ✗ never: an unsigned or tampered package loaded; hash mismatch accepted; a Spirit crashing the node; storage written without the capability. |
| **3. The economy as one ontology** | Deon | Reconcile (A)/(B)/(C) via an `evo` with `because`. Mark every rule encoded/emergent (§3.3). Route the entropy tax to the Revival Pool. Sign and verify credit/gradient messages. Replace the flat 1000-credit grant with a sybil-resistant scheme. Wire `[pricing]` through: **summon → reserve → consume per fuel → creator + host + pool credited**. | One summon on the live network pays its creator. ✗ never: `sum(credits) ≠ genesis + minted − burned` (tax burned silently counts as a violation); an unsigned credit message applied; credits paid outside the network. |
| **4. Spirits v0: Lion & Swan** | Myth | Promote the learn capstone into published Spirits: Lion, Swan (with `evo` side-change), the five templates as `system`s, moral-ambiguity markers via the emergent-rule convention. Presentation follows WC/DK. Add a Lion & Swan room to imagine.univrs.io. | Someone outside the core summons both symbols and runs The Interrogation without help. ✗ never: a template that ranks participants (caution 1). |
| **5. The first production** | all | "The Narrative: The Lion & The Swan", made in VUDO by its creators and paid in Saints through step 3's flow. | Released; its makers were paid through the network, not around it. |
| **6. The first Interrogation, on Univrs itself** | Myth → Ontos | Run the ritual on the ecosystem (e.g. "Is the septal gate a cage?" "Is the fiat bridge a closed book?"). Publish the verdict. | At least one rule in `univrs.ecosystem` changed by an `evo` whose `because` cites the Interrogation. |
| **7. Open the playground** (= DOLOS Scheduler S, Migration M as needed) | all | Imaginarium builders fork the ontology and run their own worlds on the mesh. | **A world that disagrees with Univrs's own rules runs on Univrs.** ✗ never: a rival ontology rejected for disagreeing rather than for violating an encoded invariant. |

Step 7 is the real proof of the thesis. A playground that can only host its founder's ontology is a product. One that hosts a rival ontology is an experimental medium.

**Visibility (Hosting phase V) runs alongside every step.** The nexus.univrs.io dashboard gets a Spirits panel. imagine `/architecture` and vudo milestones update in the same change set as the code, citing the test that proves it.

### What to hold back until the thread exists

- **New surfaces.** There are already eight: univrs.io, imagine, learn, vudo, book, tarot, shine, nexus, plus metalearn.org. imagine `/architecture` and `/seam` already explain the stack honestly. Add the three layers to that existing page instead of building a ninth site.
- New themes beyond the Lion and the Swan. Tarot and shine stay as sibling Imaginarium expressions; they are not myth canon.
- Nexuspolis (`nexus/nexus-service-architecture.md`, `univrs-network/docs/NEXUSPOLIS-PLAN.md`) and further theory that no running world depends on.
- The Integral Collective alliance (`/letter`, "Integral's five subsystems become Spirits") until a node can host one Spirit.

---

## 7. Risks

The largest risk is still that the three layers stay three projects. The repos show it concretely: 419 DOL files in six repos, three economies, and a myth that lives in a tutorial but on no site.

- **The economy stays a metaphor.** Credits move on the live mesh, but the tax burns and messages are unsigned, so nothing pays a creator. Until step 3's oracle passes, Deon is aspiration.
- **The language carries hidden assumptions.** Found so far: there is no way to express "permitted but judged", and declared rules are not executed in WASM. Step 7 is the only honest test.
- **The myth outruns the product.** It already has. Public pages claim host functions and summon payouts that do not exist. Step 0 corrects this before the narrative launches.
- **Emergence is mistaken for justification.** A norm that stabilises in a world is a fact about that world. Exploitation can be stable too, so the Interrogation has to stay a human judgment.
- **Unverified numbers.** The univrs-dol README claims 1914 tests, but its own breakdown sums to 631. The univrs-network ROADMAP says 40 tests. `dol-reflect` had 5 failing tests (2026-02-07 report). Re-run `/test-all` and publish real counts before quoting any of them.

---

## 8. Questions that are still open (only the founder can answer)

The previous list is now mostly resolved:

- WC/DK, answered (§4.1)
- DOL primitives, answered (§2.2)
- Unit of account, answered (§3.2)

What remains:

- [ ] **Saint:** confirm `direct-saints.md` (Saint = closed-loop credit) as canon, and name the creator role separately?
- [ ] **Which economy:** conserved and transferable (A), decaying and attestation-only (B), or the recommended hybrid with demurrage? Is the StripeBridge kept, given `direct-saints.md`'s closed-loop requirement?
- [ ] **Revenue split** per summon: creator / host / Revival Pool.
- [ ] **Septal isolation:** how does an isolated node appeal or heal? This is the "no one can be cut off" question in practice.
- [ ] **Is the canon forkable?** Can a builder publish a telling in which the Swans are right? Step 7 assumes yes.
- [ ] **Who may publish a Spirit, and what happens to one that causes harm?** The spec has `Yanked: Security issue, cannot summon` and reviews (`registry.dol`); the code has no moderation or key revocation.
- [ ] **Which ending does the canon hold:** transcendence of the world, or harmony within it?
- [ ] **Who funds** the four live nodes until credits can?

---

## 9. Sources

| Claim area | Primary files |
| --- | --- |
| DOL language | `univrs-dol/{Cargo.toml, README.md, CHANGELOG.md, COMPILER-TARGETS.md}`, `src/lexer.rs:1270-1376`, `src/ast.rs`, `src/parser.rs`, `stdlib/*.md`, `examples/**` |
| Ecosystem ontology | `metalearn.org/ontology/**/*.dol`, `univrs-enr/dol/*.dol`, `univrs-network/ontology/*.dol`, `univrs-vudo/ontology/prospective/**`, `univrs-orchestration/ontology/**` |
| VUDO / Spirits | `univrs-vudo/{README.md, docs/, vudo/, spirits/}`, `vudo.univrs.io/{VUDO-LANDING-VISION.md, LOCAL-FIRST.md, LeWorldModel.md, src/}` |
| Hosting plan | `univrs-network/docs/SPIRIT-HOSTING-PLAN.md` (branch `docs/spirit-hosting-plan`) |
| Economy | `univrs-docs/direct-saints.md`, `univrs-enr/{README.md, src/core, src/revival/pool.rs, src/nexus, src/fiat}`, `univrs-network/{crates/mycelial-network/src/enr_bridge/, docs/PHASE6_ECONOMICS.md, docs/PROGRESS-2025-12-31.md}`, `nexus/*.md`, `cryptosaint.io/content/` |
| Identity / state / orchestration | `univrs-identity/src`, `univrs-state/src`, `univrs-orchestration/orchestrator` |
| Myth | `univrs-docs/archives/{Lion_and_swan,Biblia,Mythic_Rebellion,Manifest}.md`, `learn.univrs.io/content/{reference/mythology.mdx, tutorials/capstone/, checkpoints/}` |
| Surfaces | `imagine.univrs.io/src/pages/`, `univrs.io/*.html`, `metalearn.org/{docs/nexus.md, src/app/}`, `learn.univrs.io/`, `shine.univrs.io/`, `tarot.univrs.io/`, `univrs-network/nginx/nexus.conf` |
| WC/DK | `~/sepah/wcdk.md` (outside `repos`) |

Test counts above are taken from repo docs and annotation greps, not from fresh runs, except the 367 VM tests verified in the Spirit Hosting Plan (2026-11-08).
