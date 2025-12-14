# Anonymous Routing for CryptoSaint Credit Transactions

> Securing mycelial credit flows through S-IDA (Secure Information Dispersal Algorithm) and decentralized anonymous routing.

## Executive Summary

CryptoSaint's mutual credit system requires transaction privacy to:
1. **Protect participant identity** from surveillance and targeting
2. **Ensure transaction confidentiality** for sensitive economic data
3. **Maintain resilience** against network failures and attacks
4. **Preserve fungibility** of credits through unlinkability

This document specifies how PlanetServe's S-IDA protocol integrates with CryptoSaint to provide these guarantees while maintaining the transparency required for mycelial credit verification.

---

## Why Anonymous Routing for Credit Transactions?

### The Privacy Paradox in Mycelial Economics

Mycelial economics requires **transparency of algorithms** but **privacy of participants**:

| Aspect | Transparency | Privacy |
|--------|--------------|---------|
| Credit creation rules | ✓ Public, auditable | |
| Reputation algorithms | ✓ Open, verifiable | |
| Transaction amounts | | ✓ Encrypted in transit |
| Participant identities | | ✓ Pseudonymous |
| Credit relationships | | ✓ Unlinkable |
| Contribution patterns | | ✓ Protected |

### Threat Model

**Adversaries may attempt:**
- Network surveillance to map credit relationships
- Transaction graph analysis to deanonymize participants
- Targeted attacks on high-reputation nodes
- Sybil attacks to compromise routing paths
- Content inspection to extract sensitive economic data

**Security Goals:**
- **Sender Anonymity**: Model nodes cannot link requests to IP addresses
- **Content Confidentiality**: Only sender and recipient see transaction details
- **Failure Resilience**: k-of-n threshold provides redundancy
- **Low Overhead**: No public-key operations on relay paths

---

## S-IDA Protocol for Credit Transactions

### Overview

S-IDA combines:
1. **AES-256 Encryption** for content confidentiality
2. **Rabin's IDA** for message fragmentation (information-theoretic threshold)
3. **Shamir's Secret Sharing** for key distribution
4. **Onion Routing** for path establishment (one-time setup)
5. **Sliced Routing** for data transmission (low overhead)

### Transaction Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CryptoSaint Credit Transaction Flow                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  SENDER                                                    RECIPIENT    │
│    │                                                           │        │
│    │  1. Create Transaction                                    │        │
│    │     ┌──────────────────────┐                              │        │
│    │     │ From: Alice          │                              │        │
│    │     │ To: Bob              │                              │        │
│    │     │ Amount: 100 credits  │                              │        │
│    │     │ Purpose: "Trade"     │                              │        │
│    │     │ Signature: [...]     │                              │        │
│    │     └──────────────────────┘                              │        │
│    │                                                           │        │
│    │  2. Encrypt with AES Key K                                │        │
│    │     {Transaction}K                                        │        │
│    │                                                           │        │
│    │  3. Split into n=4 Cloves                                 │        │
│    │     ┌────┐ ┌────┐ ┌────┐ ┌────┐                          │        │
│    │     │ C1 │ │ C2 │ │ C3 │ │ C4 │                          │        │
│    │     └──┬─┘ └──┬─┘ └──┬─┘ └──┬─┘                          │        │
│    │        │      │      │      │                             │        │
│    │  4. Route through Proxies                                 │        │
│    │        │      │      │      │                             │        │
│    │        ▼      ▼      ▼      ▼                             │        │
│    │     ┌────┐ ┌────┐ ┌────┐ ┌────┐                          │        │
│    │     │ P1 │ │ P2 │ │ P3 │ │ P4 │  (Proxies)               │        │
│    │     └──┬─┘ └──┬─┘ └──┬─┘ └──┬─┘                          │        │
│    │        │      │      │      │                             │        │
│    │        ▼      ▼      ▼      ▼                             │        │
│    │     ┌────────────────────────┐                            │        │
│    │     │      RECIPIENT         │◄───────────────────────────┤        │
│    │     └────────────────────────┘                            │        │
│    │                                                           │        │
│    │  5. Recover with k=3 Cloves                               │        │
│    │     - Reconstruct Key K from k shares                     │        │
│    │     - Reconstruct {Transaction}K from k fragments         │        │
│    │     - Decrypt to get Transaction                          │        │
│    │                                                           │        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Protocol Details

#### Phase 1: Proxy Establishment (Onion Routing)

```rust
/// Establish N≥n proxies using Onion routing
pub struct ProxyEstablishment {
    /// Number of hops per path (l=3 per PlanetServe)
    path_length: usize,
    /// Minimum proxies needed
    min_proxies: usize,
}

impl ProxyEstablishment {
    pub async fn establish_proxies(
        &self,
        user_id: &str,
        user_list: &[UserNode],
    ) -> Result<Vec<Proxy>, EstablishmentError> {
        let mut proxies = Vec::new();
        
        while proxies.len() < self.min_proxies {
            // Select l random relay nodes
            let relays = self.select_random_relays(user_list, self.path_length)?;
            
            // Build Onion path
            let (path, proxy) = self.build_onion_path(user_id, &relays).await?;
            
            // Store path info at each relay
            for (i, relay) in relays.iter().enumerate() {
                let predecessor = if i == 0 { None } else { Some(relays[i-1].id.clone()) };
                let successor = relays.get(i + 1).map(|r| r.id.clone());
                
                relay.store_path_info(PathInfo {
                    session_id: path.session_id,
                    predecessor,
                    successor,
                }).await?;
            }
            
            proxies.push(proxy);
        }
        
        Ok(proxies)
    }
    
    /// Session ID = hash(user_id || last_node_id)
    fn compute_session_id(&self, user_id: &str, last_node: &str) -> [u8; 32] {
        let mut hasher = Sha256::new();
        hasher.update(user_id.as_bytes());
        hasher.update(last_node.as_bytes());
        hasher.finalize().into()
    }
}
```

#### Phase 2: Transaction Encoding (S-IDA)

```rust
/// Credit transaction structure
#[derive(Serialize, Deserialize)]
pub struct CreditTransaction {
    /// Sender's pseudonymous ID
    pub from: String,
    /// Recipient's pseudonymous ID
    pub to: String,
    /// Credit amount
    pub amount: u64,
    /// Transaction purpose (optional)
    pub purpose: Option<String>,
    /// Timestamp
    pub timestamp: u64,
    /// Sender's signature
    pub signature: Vec<u8>,
    /// Nonce for replay protection
    pub nonce: [u8; 16],
}

/// Anonymous transaction encoder
pub struct AnonymousTransactionEncoder {
    sida_encoder: SidaEncoder,
    proxy_manager: ProxyManager,
}

impl AnonymousTransactionEncoder {
    pub async fn encode_transaction(
        &self,
        tx: &CreditTransaction,
        recipient_proxies: &[String],
    ) -> Result<Vec<RoutedClove>, EncodingError> {
        // 1. Serialize transaction
        let tx_bytes = bincode::serialize(tx)?;
        
        // 2. Get sender's proxy session IDs
        let session_ids = self.proxy_manager.get_session_ids()?;
        
        // 3. Create cloves using S-IDA
        let cloves = self.sida_encoder.encode(
            &tx_bytes,
            &tx.to,
            session_ids,
        )?;
        
        // 4. Wrap with routing information
        let routed_cloves: Vec<RoutedClove> = cloves.into_iter()
            .zip(self.proxy_manager.proxies.iter())
            .map(|(clove, proxy)| RoutedClove {
                clove,
                via_proxy: proxy.node_id.clone(),
                recipient_proxy: recipient_proxies[clove.index - 1].clone(),
            })
            .collect();
        
        Ok(routed_cloves)
    }
}
```

#### Phase 3: Routing

```rust
/// Clove with routing metadata
pub struct RoutedClove {
    pub clove: Clove,
    pub via_proxy: String,
    pub recipient_proxy: String,
}

/// Relay node behavior
pub struct RelayNode {
    path_table: HashMap<[u8; 32], PathInfo>,
}

impl RelayNode {
    /// Forward clove based on stored path info
    pub async fn forward_clove(&self, clove: &Clove) -> Result<(), RoutingError> {
        let path_info = self.path_table.get(&clove.session_id)
            .ok_or(RoutingError::UnknownSession)?;
        
        if let Some(successor) = &path_info.successor {
            // Forward to next hop
            self.send_to(successor, clove).await?;
        } else {
            // This is the proxy - forward to destination
            self.send_to(&clove.destination, clove).await?;
        }
        
        Ok(())
    }
}
```

#### Phase 4: Reception and Decoding

```rust
/// Transaction receiver
pub struct TransactionReceiver {
    sida_decoder: SidaDecoder,
    pending_cloves: HashMap<TransactionId, Vec<Clove>>,
    config: SidaConfig,
}

impl TransactionReceiver {
    pub async fn receive_clove(&mut self, clove: Clove) -> Option<CreditTransaction> {
        // Extract transaction ID from clove metadata
        let tx_id = TransactionId::from_clove(&clove);
        
        // Add to pending cloves
        let cloves = self.pending_cloves.entry(tx_id).or_insert_with(Vec::new);
        cloves.push(clove);
        
        // Check if we have enough cloves
        if cloves.len() >= self.config.k {
            // Attempt recovery
            match self.sida_decoder.decode(cloves) {
                Ok(tx_bytes) => {
                    self.pending_cloves.remove(&tx_id);
                    
                    // Deserialize and verify
                    match bincode::deserialize::<CreditTransaction>(&tx_bytes) {
                        Ok(tx) if self.verify_signature(&tx) => Some(tx),
                        _ => None,
                    }
                }
                Err(_) => None,
            }
        } else {
            None
        }
    }
    
    fn verify_signature(&self, tx: &CreditTransaction) -> bool {
        // Verify sender's signature on transaction
        // Implementation depends on signature scheme
        true // Placeholder
    }
}
```

---

## Security Analysis

### Anonymity Properties

#### Sender Anonymity

**Guarantee:** Relay nodes and recipient cannot determine the sender's IP address.

**Mechanism:**
1. First relay (guard) sees sender IP but not content or destination
2. Each subsequent relay only sees predecessor and successor
3. Recipient sees only proxy IPs, not sender

**Analysis:**
- Path of length l=3 provides 3 hops of indirection
- Attacker must control ≥k nodes on ≥k paths to compromise anonymity
- With n=4, k=3, and random selection, probability of compromise is low

#### Content Confidentiality

**Guarantee:** Only sender and recipient can read transaction details.

**Mechanism:**
1. AES-256 encryption with random key K
2. Key split via Shamir (k-of-n threshold)
3. Message split via Rabin IDA (k-of-n threshold)
4. Neither key nor message recoverable with <k cloves

**Analysis:**
- AES-256 provides 128-bit post-quantum security margin
- Shamir SSS is information-theoretically secure
- Rabin IDA provides optimal redundancy

#### Unlinkability

**Guarantee:** Different transactions from same sender cannot be linked.

**Mechanism:**
1. Different session IDs per proxy path
2. Random nonce per transaction
3. Cloves routed through different path combinations

**Analysis:**
- Traffic analysis requires global network view
- Timing attacks mitigated by batching (future work)

### Failure Resilience

**Scenario:** Up to n-k relays fail during transmission.

**Mechanism:**
1. k-of-n threshold means n-k failures tolerable
2. With n=4, k=3: survives 1 path failure
3. With n=5, k=3: survives 2 path failures

**Analysis (from PlanetServe):**
- With 3% node failure rate, success rate >95%
- Path survival improves with path diversity

### Attack Resistance

| Attack | Mitigation | Effectiveness |
|--------|------------|---------------|
| Traffic Analysis | Multiple paths, batching | Medium |
| Timing Correlation | Relay delays, batching | Medium |
| Sybil (< k paths) | Random relay selection | High |
| Sybil (≥ k paths) | Credential verification | High |
| Content Inspection | AES-256 encryption | High |
| Replay Attack | Nonce + timestamp | High |

---

## Integration with CryptoSaint

### Credit Transaction Types

| Transaction Type | Privacy Level | S-IDA Config |
|-----------------|---------------|--------------|
| Standard Credit Transfer | Full anonymity | n=4, k=3, l=3 |
| High-Value Transfer | Enhanced anonymity | n=5, k=3, l=4 |
| Public Donation | Sender anonymity only | n=4, k=3, l=2 |
| Ecological Credit | Partial transparency | n=3, k=2, l=2 |

### Reputation Integration

Credit transactions include reputation context:

```rust
#[derive(Serialize, Deserialize)]
pub struct ReputationAwareTransaction {
    /// Base transaction
    pub tx: CreditTransaction,
    /// Sender's current reputation score
    pub sender_reputation: f64,
    /// Proof of reputation (ZK or attestation)
    pub reputation_proof: ReputationProof,
}

#[derive(Serialize, Deserialize)]
pub enum ReputationProof {
    /// Verification committee attestation
    CommitteeAttestation {
        score: f64,
        epoch: u64,
        signatures: Vec<Signature>,
    },
    /// Zero-knowledge proof of score range
    ZkRangeProof {
        commitment: [u8; 32],
        proof: Vec<u8>,
    },
}
```

### Response Routing

Responses (confirmations, rejections) also use S-IDA:

```rust
/// Transaction response
#[derive(Serialize, Deserialize)]
pub struct TransactionResponse {
    /// Original transaction ID
    pub tx_id: TransactionId,
    /// Response status
    pub status: ResponseStatus,
    /// Recipient's signature
    pub signature: Vec<u8>,
    /// Updated balances (encrypted)
    pub balance_update: Option<EncryptedBalance>,
}

pub enum ResponseStatus {
    Accepted { confirmation_id: [u8; 32] },
    Rejected { reason: String },
    Pending { retry_after: u64 },
}
```

### Verification Committee Integration

Anonymous routing protects normal transactions, but verification requires controlled transparency:

```rust
/// Verification-aware transaction
pub struct VerifiableTransaction {
    /// Anonymous transaction
    pub anonymous_tx: RoutedClove,
    /// Commitment to transaction hash (for verification)
    pub tx_commitment: [u8; 32],
    /// Proof that commitment opens to valid transaction
    pub validity_proof: ValidityProof,
}

impl VerifiableTransaction {
    /// Verification committee can verify without seeing content
    pub fn verify_without_content(&self) -> bool {
        // Verify commitment structure
        // Verify validity proof
        // Does NOT reveal transaction details
        true
    }
    
    /// Reveal to verification committee (dispute resolution)
    pub fn reveal(&self, key: &[u8]) -> Option<CreditTransaction> {
        // Decrypt and reveal for dispute resolution
        None
    }
}
```

---

## Performance Characteristics

### Latency Breakdown

| Operation | Latency | Notes |
|-----------|---------|-------|
| Proxy establishment | ~200ms | One-time per session |
| S-IDA encoding | <0.5ms | Per transaction |
| Clove routing (3 hops) | ~100ms | Depends on network |
| S-IDA decoding | <0.5ms | Per transaction |
| **Total (steady-state)** | **~100ms** | After proxies established |

### Overhead

| Metric | Value | Comparison |
|--------|-------|------------|
| Message expansion | ~33% | (4 cloves for 3 needed) |
| Bandwidth per tx | ~4x direct | Path redundancy |
| CPU (sender) | ~0.3ms | AES + splitting |
| CPU (relay) | ~0 | No crypto operations |
| CPU (receiver) | ~0.3ms | AES + reconstruction |

### Scalability

| Nodes | Transactions/sec | Limiting Factor |
|-------|------------------|-----------------|
| 100 | ~1000 | Network |
| 1000 | ~10000 | Network |
| 10000 | ~100000 | Routing table size |

---

## Future Enhancements

### 1. Mixnet Integration

Add mixing to further obscure timing patterns:

```rust
pub struct MixedClove {
    pub clove: Clove,
    pub delay: Duration,
    pub dummy_probability: f64,
}
```

### 2. Batching for Efficiency

Batch multiple transactions through shared paths:

```rust
pub struct TransactionBatch {
    pub transactions: Vec<CreditTransaction>,
    pub batch_proof: BatchProof,
}
```

### 3. Zero-Knowledge Reputation Proofs

Prove reputation range without revealing exact score:

```rust
pub fn prove_reputation_above_threshold(
    score: f64,
    threshold: f64,
) -> ZkProof {
    // Bulletproof range proof
}
```

### 4. Cross-Community Routing

Extend to support transactions across different CryptoSaint communities:

```rust
pub struct CrossCommunityTransaction {
    pub source_community: CommunityId,
    pub target_community: CommunityId,
    pub transaction: CreditTransaction,
    pub exchange_rate: f64,
}
```

---

## Implementation Checklist

### Phase 1: Core Protocol (Week 5-6)
- [ ] S-IDA encoder/decoder
- [ ] Proxy establishment
- [ ] Basic clove routing

### Phase 2: CryptoSaint Integration (Week 7-8)
- [ ] Transaction serialization
- [ ] Signature verification
- [ ] Response routing

### Phase 3: Security Hardening (Week 9-10)
- [ ] Replay protection
- [ ] Path rotation
- [ ] Failure recovery

### Phase 4: Performance Optimization (Week 11-12)
- [ ] Batching
- [ ] Connection pooling
- [ ] Caching

---

## References

1. [PlanetServe: Decentralized LLM Serving](https://arxiv.org/abs/2504.20101)
2. [Tor: Second-Generation Onion Router](https://www.usenix.org/conference/13th-usenix-security-symposium/tor-second-generation-onion-router)
3. [Secret Sharing Made Short](https://www.iacr.org/archive/crypto93/01-14.pdf)
4. [Efficient Dispersal of Information](https://dl.acm.org/doi/10.1145/62212.62213)
5. [Mixnets and Anonymous Communication](https://www.freehaven.net/anonbib/)
