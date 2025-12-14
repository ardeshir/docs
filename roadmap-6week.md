# 6-Week Implementation Roadmap

> Sprint-by-sprint development plan for integrating PlanetServe capabilities into Univrs.io infrastructure.

## Overview

This roadmap covers the implementation of four core PlanetServe components into the Univrs.io ecosystem:

1. **Reputation Scoring System** (Weeks 1-2)
2. **Hash-Radix Tree for Workload Distribution** (Weeks 3-4)
3. **S-IDA Anonymous Communication** (Weeks 5-6)
4. **Verification Committee** (Future Phase)

### Success Criteria

- [ ] Reputation scores influence scheduler decisions
- [ ] Workloads route to nodes with relevant cached state
- [ ] Credit transactions are anonymized through S-IDA
- [ ] Delta synchronization reduces network overhead by 10x
- [ ] Unit test coverage >80% for new components

---

## Week 1: Reputation Core Implementation

### Goals
- Implement core reputation data structures
- Create scoring algorithms with asymmetric punishment
- Add persistence layer integration

### Tasks

| Task | Priority | Estimate | Assignee |
|------|----------|----------|----------|
| Define `ReputationConfig` struct with default parameters | P0 | 2h | - |
| Implement `NodeReputation` with sliding window | P0 | 4h | - |
| Create `update()` method with punishment logic | P0 | 3h | - |
| Add `is_trusted()` and `should_mark_untrusted()` methods | P1 | 1h | - |
| Write comprehensive unit tests | P0 | 4h | - |
| Document reputation formulas and parameters | P1 | 2h | - |

### Implementation Details

```rust
// reputation/mod.rs
pub mod config;
pub mod scoring;
pub mod store;

// reputation/config.rs
pub struct ReputationConfig {
    pub alpha: f64,           // 0.4 - history weight
    pub beta: f64,            // 0.6 - current performance weight
    pub window_size: usize,   // 5 epochs
    pub gamma: f64,           // 0.2 - punishment threshold
    pub trust_threshold: f64, // 0.4 - minimum for trusted status
}
```

### Deliverables
- [ ] `crates/reputation/src/config.rs`
- [ ] `crates/reputation/src/scoring.rs`
- [ ] `crates/reputation/src/lib.rs`
- [ ] `crates/reputation/tests/scoring_tests.rs`

### Testing Checkpoints
- [ ] Normal update increases reputation for good performance
- [ ] Single bad score decreases reputation proportionally
- [ ] Multiple bad scores in window trigger punishment multiplier
- [ ] Reputation converges to correct value over time

---

## Week 2: Reputation Store Integration

### Goals
- Integrate reputation with existing StateStore
- Add API endpoints for reputation queries
- Create reputation-aware scheduler interface

### Tasks

| Task | Priority | Estimate | Assignee |
|------|----------|----------|----------|
| Define `ReputationStore` trait | P0 | 2h | - |
| Implement trait for existing StateStore backend | P0 | 6h | - |
| Add serialization/deserialization for reputation data | P1 | 2h | - |
| Create `get_trusted_nodes()` query method | P0 | 2h | - |
| Add `mark_untrusted()` with reason logging | P1 | 2h | - |
| Integrate with scheduler weight calculations | P0 | 4h | - |
| Write integration tests | P0 | 4h | - |

### API Design

```rust
#[async_trait]
pub trait ReputationStore: Send + Sync {
    async fn get_reputation(&self, node_id: &str) -> Result<NodeReputation, StoreError>;
    async fn update_reputation(&self, node_id: &str, credit_score: f64) -> Result<f64, StoreError>;
    async fn get_trusted_nodes(&self) -> Result<Vec<String>, StoreError>;
    async fn mark_untrusted(&self, node_id: &str, reason: &str) -> Result<(), StoreError>;
    async fn get_nodes_by_reputation(&self, min_score: f64) -> Result<Vec<(String, f64)>, StoreError>;
}
```

### Deliverables
- [ ] `crates/reputation/src/store.rs`
- [ ] `crates/orchestrator_core/src/scheduler/reputation.rs`
- [ ] Updated `StateStore` implementation
- [ ] Integration test suite

### Testing Checkpoints
- [ ] Reputation persists across restarts
- [ ] Trusted nodes query returns correct set
- [ ] Scheduler weights correlate with reputation scores
- [ ] Untrusted marking removes from scheduling pool

---

## Week 3: Hash-Radix Tree Core

### Goals
- Implement HR-tree data structure
- Create chunking and hashing algorithms
- Add basic search and insert operations

### Tasks

| Task | Priority | Estimate | Assignee |
|------|----------|----------|----------|
| Define `ChunkConfig` with sentry integration | P0 | 2h | - |
| Implement `HRTreeNode` structure | P0 | 3h | - |
| Create `HRTree` with insert/search operations | P0 | 6h | - |
| Implement `hash_chunk()` with 8-bit fingerprints | P0 | 2h | - |
| Add `chunk_content()` with configurable lengths | P1 | 3h | - |
| Implement `get_best_node()` with LB factor | P0 | 3h | - |
| Write unit tests for tree operations | P0 | 4h | - |

### Implementation Details

```rust
// hr_tree/mod.rs
pub mod config;
pub mod node;
pub mod tree;
pub mod search;

// hr_tree/node.rs
pub struct HRTreeNode {
    pub hash: u8,
    pub children: HashMap<u8, Box<HRTreeNode>>,
    pub model_nodes: Vec<NodeMetadata>,
}

// hr_tree/tree.rs
pub struct HRTree {
    root: HRTreeNode,
    chunk_lengths: Vec<usize>,
    config: ChunkConfig,
}
```

### Deliverables
- [ ] `crates/hr_tree/src/config.rs`
- [ ] `crates/hr_tree/src/node.rs`
- [ ] `crates/hr_tree/src/tree.rs`
- [ ] `crates/hr_tree/src/search.rs`
- [ ] `crates/hr_tree/tests/tree_tests.rs`

### Testing Checkpoints
- [ ] Insert creates correct tree structure
- [ ] Search finds matching prefixes
- [ ] False positive rate is 1/256^d
- [ ] Load balancing selects lowest LB factor

---

## Week 4: HR-Tree Synchronization

### Goals
- Implement delta update generation and application
- Add network synchronization protocol
- Integrate with cluster manager

### Tasks

| Task | Priority | Estimate | Assignee |
|------|----------|----------|----------|
| Implement `generate_delta()` for changed entries | P0 | 4h | - |
| Create `apply_delta()` for incoming updates | P0 | 3h | - |
| Define `HRTreeDelta` serialization format | P1 | 2h | - |
| Add timestamp tracking for entries | P0 | 2h | - |
| Implement broadcast protocol (5-second interval) | P0 | 4h | - |
| Create conflict resolution for concurrent updates | P1 | 3h | - |
| Benchmark memory and network overhead | P1 | 2h | - |
| Write synchronization tests | P0 | 4h | - |

### Synchronization Protocol

```rust
// hr_tree/sync.rs
pub struct HRTreeDelta {
    pub additions: Vec<DeltaEntry>,
    pub removals: Vec<DeltaEntry>,
    pub timestamp: u64,
    pub source_node: String,
}

pub struct SyncManager {
    tree: Arc<RwLock<HRTree>>,
    last_sync: AtomicU64,
    peers: Vec<PeerConnection>,
}

impl SyncManager {
    pub async fn sync_loop(&self) {
        loop {
            tokio::time::sleep(Duration::from_secs(5)).await;
            
            let delta = self.tree.read().await.generate_delta(
                self.last_sync.load(Ordering::Relaxed)
            );
            
            if !delta.is_empty() {
                self.broadcast_delta(&delta).await;
            }
        }
    }
}
```

### Deliverables
- [ ] `crates/hr_tree/src/sync.rs`
- [ ] `crates/hr_tree/src/delta.rs`
- [ ] Integration with cluster manager
- [ ] Benchmark results document

### Testing Checkpoints
- [ ] Delta contains only changed entries
- [ ] Applied deltas correctly update tree
- [ ] Network overhead is 10x less than full broadcast
- [ ] Concurrent updates resolve correctly

---

## Week 5: S-IDA Core Implementation

### Goals
- Implement Rabin's IDA for message splitting
- Implement Shamir's Secret Sharing for key distribution
- Create encoder/decoder pair

### Tasks

| Task | Priority | Estimate | Assignee |
|------|----------|----------|----------|
| Implement GF(2^8) arithmetic (add, mul, inv) | P0 | 3h | - |
| Create `rabin_split()` with Vandermonde matrix | P0 | 5h | - |
| Create `rabin_recover()` with Lagrange interpolation | P0 | 5h | - |
| Implement `shamir_split()` for key shares | P0 | 4h | - |
| Implement `shamir_recover()` for key reconstruction | P0 | 4h | - |
| Create `SidaEncoder` combining both | P0 | 3h | - |
| Create `SidaDecoder` with threshold check | P0 | 3h | - |
| Write comprehensive cryptographic tests | P0 | 4h | - |

### Implementation Details

```rust
// sida/mod.rs
pub mod gf256;      // Galois field arithmetic
pub mod rabin;      // Information Dispersal Algorithm
pub mod shamir;     // Secret Sharing
pub mod encoder;    // Combined encoder
pub mod decoder;    // Combined decoder

// sida/gf256.rs
pub fn gf_add(a: u8, b: u8) -> u8 { a ^ b }
pub fn gf_mul(a: u8, b: u8) -> u8 { /* AES polynomial */ }
pub fn gf_inv(a: u8) -> u8 { /* Extended Euclidean */ }
```

### Deliverables
- [ ] `crates/sida/src/gf256.rs`
- [ ] `crates/sida/src/rabin.rs`
- [ ] `crates/sida/src/shamir.rs`
- [ ] `crates/sida/src/encoder.rs`
- [ ] `crates/sida/src/decoder.rs`
- [ ] `crates/sida/tests/crypto_tests.rs`

### Testing Checkpoints
- [ ] GF(2^8) operations satisfy field axioms
- [ ] Rabin split/recover roundtrips correctly
- [ ] Shamir split/recover roundtrips correctly
- [ ] k-of-n threshold enforced (k-1 cloves fail)
- [ ] Different clove combinations all succeed

---

## Week 6: S-IDA Integration & Anonymous Routing

### Goals
- Create proxy establishment protocol
- Integrate S-IDA with credit transaction layer
- Implement path session management

### Tasks

| Task | Priority | Estimate | Assignee |
|------|----------|----------|----------|
| Define `Clove` message format | P0 | 2h | - |
| Implement `ProxyManager` for path establishment | P0 | 5h | - |
| Create session ID generation (hash of user + last node) | P0 | 2h | - |
| Implement clove routing through relay nodes | P0 | 4h | - |
| Integrate with CryptoSaint credit transactions | P0 | 5h | - |
| Add path failure detection and recovery | P1 | 3h | - |
| Create end-to-end integration tests | P0 | 4h | - |
| Document anonymous routing protocol | P1 | 2h | - |

### Protocol Integration

```rust
// sida/routing.rs
pub struct ProxyManager {
    proxies: Vec<Proxy>,
    paths: HashMap<SessionId, PathInfo>,
    config: SidaConfig,
}

pub struct Proxy {
    pub node_id: String,
    pub public_key: PublicKey,
    pub session_id: [u8; 32],
}

pub struct PathInfo {
    pub session_id: [u8; 32],
    pub predecessor: Option<String>,
    pub successor: Option<String>,
    pub established_at: u64,
}

// Integration with CryptoSaint
pub struct AnonymousCreditTransaction {
    encoder: SidaEncoder,
    proxy_manager: ProxyManager,
}

impl AnonymousCreditTransaction {
    pub async fn send_credit(
        &self,
        from: &str,
        to: &str,
        amount: u64,
        signature: &[u8],
    ) -> Result<TransactionId, TransactionError> {
        // 1. Serialize transaction
        let tx_bytes = serialize_transaction(from, to, amount, signature)?;
        
        // 2. Get proxy session IDs
        let session_ids = self.proxy_manager.get_session_ids()?;
        
        // 3. Create cloves
        let cloves = self.encoder.encode(&tx_bytes, to, session_ids)?;
        
        // 4. Route cloves through proxies
        for (clove, proxy) in cloves.iter().zip(self.proxy_manager.proxies.iter()) {
            self.route_through_proxy(clove, proxy).await?;
        }
        
        Ok(TransactionId::from_bytes(&tx_bytes))
    }
}
```

### Deliverables
- [ ] `crates/sida/src/routing.rs`
- [ ] `crates/sida/src/proxy.rs`
- [ ] `crates/cryptosaint/src/anonymous_tx.rs`
- [ ] Integration test suite
- [ ] Protocol documentation

### Testing Checkpoints
- [ ] Proxy paths establish correctly
- [ ] Credit transactions route through anonymous overlay
- [ ] Relay nodes cannot link sender to transaction
- [ ] Path failures trigger re-routing
- [ ] k-of-n cloves successfully reconstruct transaction

---

## Post-Roadmap: Verification Committee

### Future Phase Tasks

| Task | Priority | Estimate |
|------|----------|----------|
| Tendermint consensus integration | P0 | 2 weeks |
| Challenge prompt generation system | P0 | 1 week |
| Perplexity scoring implementation | P0 | 1 week |
| Two-phase voting protocol | P0 | 1 week |
| Leader election via VRF | P1 | 3 days |
| Committee rotation mechanism | P2 | 1 week |

---

## Risk Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| GF(2^8) implementation bugs | Medium | High | Use established crypto library, extensive testing |
| HR-tree memory overhead | Low | Medium | Benchmark early, tune hash bits |
| Sync protocol network saturation | Medium | High | Implement rate limiting, delta compression |
| Path establishment failures | Medium | Medium | Multiple retry paths, fallback routing |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Underestimated complexity | Medium | Medium | Buffer time built into each week |
| Integration issues | High | Low | Continuous integration, interface contracts |
| Dependencies between weeks | Medium | Medium | Clear deliverables, weekly sync points |

---

## Resource Requirements

### Development Environment
- Rust 1.75+
- tokio async runtime
- aes-gcm for encryption
- serde for serialization

### Testing Infrastructure
- Unit test framework (cargo test)
- Integration test cluster (3+ nodes)
- Network simulation for latency testing

### Dependencies to Add

```toml
# Cargo.toml additions
[dependencies]
aes-gcm = "0.10"
rand = "0.8"
thiserror = "1.0"
async-trait = "0.1"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }

[dev-dependencies]
proptest = "1.0"  # Property-based testing for crypto
criterion = "0.5"  # Benchmarking
```

---

## Success Metrics

### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Reputation update latency | <1ms | Per-operation timing |
| HR-tree search latency | <0.1ms | Benchmark suite |
| Delta sync network overhead | <10% of full broadcast | Traffic measurement |
| S-IDA encode latency | <0.5ms | Per-message timing |
| S-IDA decode latency | <0.5ms | Per-message timing |
| Path establishment | <200ms | End-to-end timing |

### Quality Targets

| Metric | Target |
|--------|--------|
| Unit test coverage | >80% |
| Integration test coverage | >70% |
| Documentation coverage | 100% public APIs |
| Benchmark regression | <5% between builds |

---

## Weekly Sync Format

### Status Report Template
```markdown
## Week N Status

### Completed
- [ ] Task 1
- [ ] Task 2

### In Progress
- Task 3 (70% complete)

### Blocked
- Blocker description

### Next Week Focus
- Priority items for Week N+1

### Metrics
- Tests passing: X/Y
- Coverage: Z%
```

---

## References

- [PlanetServe Paper](https://arxiv.org/abs/2504.20101)
- [Rabin's IDA](https://dl.acm.org/doi/10.1145/62212.62213)
- [Shamir's Secret Sharing](https://dl.acm.org/doi/10.1145/359168.359176)
- [Tendermint Consensus](https://arxiv.org/abs/1807.04938)
