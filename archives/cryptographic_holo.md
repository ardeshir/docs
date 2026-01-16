# Cryptographic lens-filtered pub/sub for semantic inference sharing

**Inner Product Functional Encryption enables cryptographically-enforced “lens” access to 4096-dimensional embeddings, but WASM runtime constraints require a hybrid architecture splitting light cryptographic operations (encryption, key handling) in WASM agents from compute-intensive operations on native backends.** This specification details a production-viable system where agents publish encrypted semantic signatures and subscribers can compute only the inner products their lens keys permit—without ever accessing raw vectors. The recommended stack combines the CKKS homomorphic scheme for vector arithmetic with Decentralized Multi-Client Functional Encryption (DMCFE) for lens semantics, running on wasmCloud with NATS messaging.

-----

## The fundamental constraint: no FHE computation in WASM today

The single most important finding from this research is that **no production Rust library currently supports fully homomorphic encryption computation within WASM environments**. TFHE-rs v1.0.0 (February 2025) offers client-side WASM APIs for encryption and decryption only—actual homomorphic operations require native x86/GPU backends. This architectural constraint shapes every design decision.

The practical implication is clear: VUDO VM agents must delegate compute-intensive cryptographic operations to native capability providers or external services. WASM modules handle key management, encryption, decryption, and protocol orchestration while a native “Crypto Provider” handles the expensive inner product computations. This split actually improves security—the cryptographic heavy lifting happens in auditable, isolated components rather than within arbitrary agent code.

**Ciphertext sizes for 4096-dimensional vectors** under different schemes illustrate the data plane challenge:

|Scheme              |Ciphertext Size|Expansion Factor|Suitable for Vectors|
|--------------------|---------------|----------------|--------------------|
|CKKS (N=8192)       |**~262 KB**    |~5,000:1        |✓ Excellent         |
|BFV (N=8192)        |~300 KB        |~5,000-10,000:1 |✓ Good              |
|TFHE                |~130 MB        |~8,200:1 per bit|✗ Impractical       |
|IPFE (pairing-based)|~160 KB        |~40:1           |✓ Best for lens     |

-----

## Why Inner Product Functional Encryption matches the lens concept perfectly

The “lens-as-cryptographic-key” requirement maps directly to **Inner Product Functional Encryption (IPFE)**. In IPFE, a publisher encrypts vector **x** under a master public key; an authority derives secret keys **sk_y** for each subscriber’s lens vector **y**; and decryption reveals *only* the inner product ⟨x, y⟩—nothing more about x.

This is cryptographically enforced access control, not filtering. An agent with lens key for vector y literally *cannot* learn x beyond what ⟨x, y⟩ reveals. For semantic embeddings, this means agents can compute similarity projections (dot products) against encrypted vectors without accessing the underlying semantic representation.

The **Decentralized Multi-Client Functional Encryption (DMCFE)** variant eliminates the trusted key authority bottleneck. Each agent runs independent setup, publishes their own encrypted contributions, and functional keys are derived through distributed protocols. The Cosmian `dmcfe` Rust crate implements exactly this scheme on the BLS12-381 curve—a critical discovery for implementation feasibility.

**Performance estimates for 4096-dimensional IPFE** (extrapolated from CiFEr benchmarks):

- Key generation: ~28ms
- Encryption: ~57ms
- Decryption (inner product): ~43ms
- Ciphertext size: ~160 KB (4096 group elements)

The critical caveat: releasing **n linearly independent keys** for an n-dimensional space breaks security. With 4096 dimensions, the system must carefully manage key issuance—either limiting the number of distinct lens keys, using hierarchical lens structures, or accepting that some collusion sets can recover plaintexts.

-----

## Recommended cryptographic architecture

The optimal design combines CKKS for efficient vector arithmetic with IPFE for lens-based access control, deployed in a hybrid WASM/native architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                    WASM Agent (VUDO VM)                         │
│  ┌─────────────────┐    ┌─────────────────────────────────────┐ │
│  │  Lens Key Store │    │     Protocol Orchestration          │ │
│  │  (sk_y, pk)     │    │  - Serialize/deserialize ciphertexts│ │
│  └────────┬────────┘    │  - Message routing decisions        │ │
│           │             │  - Local similarity cache           │ │
│           ▼             └─────────────────────────────────────┘ │
│  ┌─────────────────┐                                            │
│  │ Light Crypto    │←── Encrypt vectors (IPFE.Enc)              │
│  │ (Pure Rust→WASM)│←── Decrypt inner products (IPFE.Dec)       │
│  └────────┬────────┘    (cosmian_dmcfe compiled to WASM)        │
└───────────┼─────────────────────────────────────────────────────┘
            │ Host Function Call / Capability Provider
            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Native Crypto Provider (wasmCloud)                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  CKKS Vector Operations (when needed for batch processing)  ││
│  │  - Homomorphic dot products: 15-50ms per 4096-dim           ││
│  │  - Matrix projections: 2-10 seconds for 4096×4096           ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  IPFE Key Authority (or DMCFE distributed protocol)         ││
│  │  - Generate functional keys for new lenses                  ││
│  │  - Key rotation and revocation                              ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

The **Cosmian `dmcfe` crate** is the primary implementation target for IPFE operations. It provides:

- IPFE for single-input inner products
- MCFE for multi-client scenarios
- DMCFE for decentralized key generation
- KP-ABE for attribute-based policies
- Built on `cosmian_bls12_381`, a pairing-friendly curve implementation

For scenarios requiring more complex vector operations (batch projections, approximate nearest neighbor), CKKS via a native provider fills the gap. The fhe.rs crate offers pure-Rust BFV that *may* compile to WASM (untested but architecturally possible given pure-Rust implementation).

-----

## Pub/sub message flow with lens-filtered decryption

The system operates through NATS JetStream with the following message lifecycle:

**1. Publisher encrypts semantic signature:**

```rust
// In WASM agent
let semantic_vector: [f32; 4096] = embedding_model.encode(content);
let ciphertext = ipfe.encrypt(&master_pk, &semantic_vector, label);
let bloom_hint = compute_lens_bloom(&semantic_vector); // For routing

nats.publish("vectors.nlp.embeddings.tier1", Message {
    ciphertext: ciphertext.serialize(),
    lens_bloom: bloom_hint,
    timestamp: now(),
});
```

**2. Broker routes based on Bloom filter pre-matching:**

```
Topic structure: vectors/{domain}/{semantic_class}/{security_tier}

Routing rule: Forward if (msg.lens_bloom AND subscription.lens_bloom) ≠ 0
```

This pre-filtering reduces cryptographic operations—agents only attempt decryption on messages their lens *might* access. The Bloom filter leaks some information (that certain lens/vector pairs are compatible) but dramatically improves performance.

**3. Subscriber decrypts inner product:**

```rust
// In WASM agent
let ciphertext = Ciphertext::deserialize(&msg.ciphertext);
let inner_product = ipfe.decrypt(&my_lens_key, &ciphertext);
// inner_product = ⟨semantic_vector, my_lens_vector⟩

if inner_product > similarity_threshold {
    // This vector is semantically relevant to my lens
    cache.update(msg.source, inner_product);
}
```

The agent learns *only* the similarity score between the published vector and their lens—not the vector itself, not other agents’ similarity scores, and not which dimensions contributed to the score.

-----

## Rust/WASM library recommendations with tradeoffs

|Library          |Use Case                     |WASM Status                             |Recommendation                        |
|-----------------|-----------------------------|----------------------------------------|--------------------------------------|
|**cosmian_dmcfe**|IPFE/DMCFE for lens semantics|Likely compilable (pure Rust, BLS12-381)|**Primary choice** for lens operations|
|**tfhe-rs v1.4** |Integer FHE when needed      |Client-side only                        |Use for auxiliary encrypted integers  |
|**fhe.rs**       |BFV vector operations        |Untested, potential                     |Evaluate for WASM BFV path            |
|**OpenFHE-rs**   |CKKS/BGV                     |✗ C++ FFI                               |Native provider only                  |

The **cosmian_dmcfe** crate deserves special attention. It implements:

- The exact DMCFE scheme from Chotard et al. for decentralized key generation
- Inner product computation on encrypted vectors using BLS12-381 pairings
- Label-based encryption preventing ciphertext reuse
- Partial decryption key aggregation for threshold scenarios

To compile for WASM, the BLS12-381 implementation must avoid platform-specific SIMD. The `cosmian_bls12_381` crate may require auditing for WASM compatibility—specifically checking for `#[cfg(target_arch)]` blocks and ensuring `getrandom` uses the “js” feature.

-----

## Key management for dynamic agent enrollment

The DMCFE model distributes trust across the system:

**Initial setup (once per deployment):**

1. Each agent generates DSum secret key `dsk_i`
1. Agents publish DSum public keys to key curator (can be NATS KV)
1. Master public key aggregated from all public keys

**New agent enrollment:**

1. New agent generates `(dsk_new, dpk_new)`
1. Publishes `dpk_new` to curator
1. Existing agents update their secret keys `sk_i` incorporating `dpk_new`
1. Key curator aggregates updated master public key

**Lens key derivation:**

1. Agent specifies lens vector `y = [y_1, ..., y_4096]`
1. For DMCFE: each existing agent generates partial decryption key using their `sk_i`
1. Partial keys aggregated (DSum guarantees all must participate)
1. Final functional key `sk_y` issued to requesting agent

**Revocation:**

- Binary-tree key structure (REEDS pattern) enables O(log n) revocation 
- Revoked agent’s `dpk_revoked` removed from aggregation
- All agents update secret keys
- Old ciphertexts remain decryptable by authorized agents; new ciphertexts exclude revoked agent

This eliminates the single-point-of-trust that traditional IPFE requires, at the cost of coordination overhead during enrollment/revocation.

-----

## Performance estimates for production deployment

**Per-message latency (4096-dim vector):**

|Operation            |Location|Time      |Notes              |
|---------------------|--------|----------|-------------------|
|IPFE Encryption      |WASM    |~60ms     |Publisher side     |
|Bloom filter matching|Broker  |<1ms      |Pre-filtering      |
|IPFE Decryption      |WASM    |~45ms     |Subscriber side    |
|NATS delivery        |Network |~2-10ms   |Depends on topology|
|**Total end-to-end** |        |**~120ms**|Per subscriber     |

**Memory footprint:**

|Component        |Size     |Location           |
|-----------------|---------|-------------------|
|Ciphertext (IPFE)|~160 KB  |Message payload    |
|Lens key         |~320 KB  |Agent local storage|
|Master public key|~4 MB    |Shared (NATS KV)   |
|Bloom hint       |256 bytes|Message metadata   |

**WASM constraints and mitigations:**

- **2GB linear memory limit**: Single 4096-dim ciphertext (~160KB) fits easily; can process thousands before hitting limits
- **No threading**: Key generation slower (~10x vs native); mitigate with capability provider delegation
- **No SIMD (some runtimes)**: ~2-3x performance penalty for field arithmetic; acceptable for async workloads

**Throughput at scale:**

- Single WASM agent: ~8 encryptions/second or ~20 decryptions/second
- With native crypto provider: ~1000 IPFE operations/second (bottleneck shifts to network)
- NATS cluster: 64MB max payload handles ciphertexts easily; 100K+ messages/second achievable

-----

## Lessons from prior art: the Tiptoe architecture pattern

The most relevant production system is **Tiptoe** (SOSP 2023), which achieves private semantic search over 360M documents. Its key insight applies directly here:

**Cluster-then-fetch reduces cryptographic scope.** Tiptoe stores semantic cluster centroids (~50MB) on clients. Clients identify relevant clusters locally, then use homomorphic encryption only within those clusters. For lens-filtered pub/sub, this translates to:

1. Publish coarse “lens compatibility hints” (Bloom filters, centroid IDs) in cleartext
1. Subscribers pre-filter locally using these hints
1. Only perform expensive IPFE decryption on likely-relevant messages

This hybrid approach—cleartext routing metadata with encrypted payloads—achieves the privacy/performance tradeoff that pure cryptographic approaches cannot. The Bloom filter leaks “agent X’s lens is compatible with message Y” but not the similarity score or vector contents.

**TEEs as an acceleration path:** Intel TDX and SGX impose <20% overhead for LLM inference. For operations exceeding WASM performance budgets (batch projections, key ceremonies), TEE-based capability providers offer a pragmatic middle ground between pure cryptography and plaintext computation.

-----

## Implementation roadmap for VUDO VM integration

**Phase 1: Core cryptographic primitives (Weeks 1-4)**

- Fork `cosmian_dmcfe` and audit for WASM compatibility
- Implement `wasm32-unknown-unknown` target support
- Benchmark IPFE encrypt/decrypt in Wasmtime
- Define capability provider interface for native crypto fallback

**Phase 2: Pub/sub integration (Weeks 5-8)**

- Implement NATS message schema with ciphertext + Bloom hint
- Build wasmCloud actor template for lens-filtered subscriptions
- Implement key curator as NATS KV-backed service
- Test multi-agent enrollment flow

**Phase 3: Performance optimization (Weeks 9-12)**

- Profile WASM hot paths; identify native provider delegation points
- Implement ciphertext compression (TFHE-rs achieves 1900× reduction)
- Add batch processing for high-throughput scenarios
- Benchmark end-to-end latency under load

**Phase 4: Security hardening (Weeks 13-16)**

- External audit of IPFE parameter selection
- Implement key rotation protocol
- Add differential privacy noise injection (per Wally approach)
- Document collusion bounds and threat model

-----

## Conclusion: a viable path with known limitations

This system is implementable today with the following constraints accepted:

**What works:**

- IPFE provides exact “lens = cryptographic key” semantics for inner product access
- DMCFE eliminates trusted key authority via distributed protocols
- Cosmian’s Rust implementation offers a realistic WASM compilation target
- wasmCloud + NATS provides production-grade pub/sub with 64MB payloads
- ~120ms end-to-end latency acceptable for async inference sharing

**What requires compromise:**

- Heavy cryptographic operations must run on native providers, not pure WASM
- 4096 dimensions limits practical distinct lens keys to prevent collusion attacks
- Bloom filter routing leaks lens compatibility (but not similarity scores)
- No side-channel mitigations in current libraries (TFHE-rs planning for future releases)

**What remains speculative:**

- `cosmian_dmcfe` WASM compilation success (needs engineering validation)
- fhe.rs WASM path for BFV vector operations (untested)
- Long-term performance as vector dimensions scale beyond 4096

The fundamental contribution of this architecture is demonstrating that cryptographically-enforced semantic access control is achievable with current tooling—not theoretically possible, but practically buildable. The lens-filtered pub/sub pattern enables a new class of multi-agent systems where semantic similarity can be computed across trust boundaries without revealing the underlying representations.