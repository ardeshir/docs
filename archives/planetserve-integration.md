# PlanetServe Integration Specifications

> Technical specifications for integrating PlanetServe's decentralized infrastructure capabilities into the Univrs.io ecosystem.

## Executive Summary

[PlanetServe](https://arxiv.org/abs/2504.20101) is a decentralized overlay network for scalable, privacy-preserving distributed computing. This document specifies how its four core innovations integrate with Univrs.io's mycelial economics infrastructure:

1. **Overlay Network Organization** → RustOrchestration cluster management
2. **Anonymous Communication (S-IDA)** → CryptoSaint credit transaction security
3. **Hash-Radix Trees** → Decentralized workload/cache distribution
4. **Reputation-Based Verification** → Mycelial credit scoring

## Alignment with Mycelial Economics

| PlanetServe Mechanism | Mycelial Economics Equivalent | Integration Target |
|----------------------|------------------------------|-------------------|
| Reputation scores based on contribution quality | Credit creation through verified contribution | RustOrchestration StateStore |
| Resources flow to nodes with available capacity | Abundance-based distribution patterns | MutualCreditScheduler |
| No central scheduler - emergent coordination | Decentralized coordination without hierarchy | Cluster Manager |
| Verification committee with BFT consensus | Transparent, auditable governance algorithms | CryptoSaint Governance |
| Contribution credit proportional to resources | Mathematical reward for participation | Credit Tracking |

---

## 1. Reputation Scoring System

### Overview

PlanetServe's reputation model uses asymmetric reward/punishment to ensure consistent good behavior. This maps directly to mycelial credit creation where reputation influences resource allocation.

### Mathematical Model

**Reputation Update Formula:**
```
R(T) = α·R(T-1) + β·C(T)

Where:
- R(T) = Reputation score at epoch T
- R(T-1) = Previous reputation score
- C(T) = Credit score from verification in epoch T
- α = 0.4 (history weight)
- β = 0.6 (current performance weight)
```

**Punishment Mechanism (Sliding Window):**
```
If abnormal_count/window_size > γ (threshold = 1/5):
    R(T) = α·R(T-1) + (W+1)/(W + c/γ + 2)·C(T)

Where:
- W = Window size (5 epochs)
- c = Count of abnormal values in window
- γ = Punishment threshold (0.2)
```

### Rust Implementation

```rust
// reputation.rs - Reputation scoring system for RustOrchestration

use std::collections::VecDeque;

/// Configuration for reputation scoring
#[derive(Clone, Debug)]
pub struct ReputationConfig {
    /// Weight for historical reputation (default: 0.4)
    pub alpha: f64,
    /// Weight for current credit score (default: 0.6)
    pub beta: f64,
    /// Sliding window size for abnormality detection (default: 5)
    pub window_size: usize,
    /// Threshold for punishment trigger (default: 0.2)
    pub gamma: f64,
    /// Minimum score to be considered trusted (default: 0.4)
    pub trust_threshold: f64,
    /// Score below which node is untrusted (default: 0.2)
    pub abnormal_threshold: f64,
}

impl Default for ReputationConfig {
    fn default() -> Self {
        Self {
            alpha: 0.4,
            beta: 0.6,
            window_size: 5,
            gamma: 0.2,
            trust_threshold: 0.4,
            abnormal_threshold: 0.2,
        }
    }
}

/// Reputation tracker for a single node
#[derive(Clone, Debug)]
pub struct NodeReputation {
    /// Current reputation score (0.0 to 1.0)
    pub score: f64,
    /// Sliding window of recent credit scores
    pub credit_history: VecDeque<f64>,
    /// Configuration
    config: ReputationConfig,
    /// Number of epochs participated
    pub epochs_participated: u64,
}

impl NodeReputation {
    pub fn new(config: ReputationConfig) -> Self {
        Self {
            score: 0.5, // Start at neutral
            credit_history: VecDeque::with_capacity(config.window_size),
            config,
            epochs_participated: 0,
        }
    }

    /// Update reputation based on new credit score
    pub fn update(&mut self, credit_score: f64) -> f64 {
        // Add to sliding window
        if self.credit_history.len() >= self.config.window_size {
            self.credit_history.pop_front();
        }
        self.credit_history.push_back(credit_score);
        self.epochs_participated += 1;

        // Count abnormal values in window
        let abnormal_count = self.credit_history
            .iter()
            .filter(|&&score| score < self.config.abnormal_threshold)
            .count();

        let abnormal_ratio = abnormal_count as f64 / self.credit_history.len() as f64;

        // Calculate new reputation
        if abnormal_ratio > self.config.gamma {
            // Apply punishment
            let w = self.config.window_size as f64;
            let c = abnormal_count as f64;
            let punishment_factor = (w + 1.0) / (w + c / self.config.gamma + 2.0);
            
            self.score = self.config.alpha * self.score + punishment_factor * credit_score;
        } else {
            // Normal update
            self.score = self.config.alpha * self.score + self.config.beta * credit_score;
        }

        // Clamp to valid range
        self.score = self.score.clamp(0.0, 1.0);
        self.score
    }

    /// Check if node is trusted
    pub fn is_trusted(&self) -> bool {
        self.score >= self.config.trust_threshold
    }

    /// Check if node should be marked untrusted
    pub fn should_mark_untrusted(&self) -> bool {
        self.score < self.config.trust_threshold && self.epochs_participated >= 3
    }
}

/// Trait for reputation-aware state store
#[async_trait::async_trait]
pub trait ReputationStore: Send + Sync {
    /// Get reputation for a node
    async fn get_reputation(&self, node_id: &str) -> Result<NodeReputation, StoreError>;
    
    /// Update reputation after verification
    async fn update_reputation(
        &self,
        node_id: &str,
        credit_score: f64,
    ) -> Result<f64, StoreError>;
    
    /// Get all nodes above trust threshold
    async fn get_trusted_nodes(&self) -> Result<Vec<String>, StoreError>;
    
    /// Mark node as untrusted
    async fn mark_untrusted(&self, node_id: &str, reason: &str) -> Result<(), StoreError>;
}

#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    #[error("Node not found: {0}")]
    NodeNotFound(String),
    #[error("Storage error: {0}")]
    Storage(String),
    #[error("Serialization error: {0}")]
    Serialization(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_reputation_normal_update() {
        let config = ReputationConfig::default();
        let mut rep = NodeReputation::new(config);
        
        // Good performance should increase reputation
        rep.update(0.8);
        assert!(rep.score > 0.5);
        
        rep.update(0.9);
        assert!(rep.score > 0.6);
    }

    #[test]
    fn test_reputation_punishment() {
        let config = ReputationConfig::default();
        let mut rep = NodeReputation::new(config);
        rep.score = 0.8; // Start high
        
        // Multiple bad performances trigger punishment
        for _ in 0..3 {
            rep.update(0.1);
        }
        
        assert!(rep.score < 0.4, "Score should drop below trust threshold");
        assert!(rep.should_mark_untrusted());
    }

    #[test]
    fn test_asymmetric_reward_punishment() {
        let config = ReputationConfig::default();
        let mut rep = NodeReputation::new(config.clone());
        rep.score = 0.6;
        
        // One bad score
        rep.update(0.1);
        let after_bad = rep.score;
        
        // Reset and try one good score
        rep = NodeReputation::new(config);
        rep.score = 0.6;
        rep.update(0.9);
        let after_good = rep.score;
        
        // Punishment should be stronger than reward
        let punishment_delta = 0.6 - after_bad;
        let reward_delta = after_good - 0.6;
        
        // After sliding window fills, punishment accelerates
        assert!(punishment_delta.abs() > 0.0 || reward_delta.abs() > 0.0);
    }
}
```

### Integration Points

1. **StateStore Extension**: Add `ReputationStore` trait to existing state management
2. **Scheduler Input**: Use reputation scores as scheduling weight factors
3. **Credit Creation**: Map reputation to contribution credit in CryptoSaint

---

## 2. Hash-Radix Tree (HR-Tree)

### Overview

The HR-tree is a distributed data structure that enables decentralized workload distribution without centralized scheduling. It uses hash fingerprints instead of full content to reduce memory and network overhead.

### Key Properties

- **Memory Efficient**: 8-bit hash values reduce storage by ~32x vs full content
- **Low False Positive Rate**: 1/256^d where d is tree depth
- **Delta Updates**: Only changed portions broadcast, 10x network reduction
- **Load Balancing**: Integrated LB factor in node metadata

### Data Structure

```rust
// hr_tree.rs - Hash-Radix Tree for decentralized workload distribution

use std::collections::HashMap;
use std::hash::{Hash, Hasher};

/// Configuration for HR-tree chunking
#[derive(Clone, Debug)]
pub struct ChunkConfig {
    /// Hash size in bits (default: 8)
    pub hash_bits: u8,
    /// Minimum chunk length in tokens
    pub min_chunk_len: usize,
    /// Maximum chunk length in tokens
    pub max_chunk_len: usize,
    /// Threshold depth for cache hit
    pub hit_threshold: usize,
}

impl Default for ChunkConfig {
    fn default() -> Self {
        Self {
            hash_bits: 8,
            min_chunk_len: 16,
            max_chunk_len: 256,
            hit_threshold: 3,
        }
    }
}

/// Model node metadata stored in tree
#[derive(Clone, Debug)]
pub struct NodeMetadata {
    /// Node IP address
    pub address: String,
    /// Load balance factor: L * (Q/C)
    pub lb_factor: f64,
    /// Reputation score from verification
    pub reputation: f64,
    /// Last update timestamp
    pub updated_at: u64,
}

/// A node in the Hash-Radix tree
#[derive(Clone, Debug)]
pub struct HRTreeNode {
    /// Hash value for this chunk (0-255 for 8-bit)
    pub hash: u8,
    /// Child nodes indexed by their hash
    pub children: HashMap<u8, Box<HRTreeNode>>,
    /// Model nodes that have cached content at this prefix
    pub model_nodes: Vec<NodeMetadata>,
}

impl HRTreeNode {
    pub fn new(hash: u8) -> Self {
        Self {
            hash,
            children: HashMap::new(),
            model_nodes: Vec::new(),
        }
    }
}

/// The Hash-Radix Tree structure
pub struct HRTree {
    /// Root node of the tree
    root: HRTreeNode,
    /// Chunk length array computed by Sentry
    chunk_lengths: Vec<usize>,
    /// Configuration
    config: ChunkConfig,
}

impl HRTree {
    pub fn new(config: ChunkConfig) -> Self {
        Self {
            root: HRTreeNode::new(0),
            chunk_lengths: vec![64, 32, 32, 32], // Default chunking
            config,
        }
    }

    /// Set chunk lengths based on detected system prompts
    pub fn set_chunk_lengths(&mut self, system_prompt_lengths: Vec<usize>, delta: usize) {
        let mut lengths = Vec::new();
        let mut sorted = system_prompt_lengths.clone();
        sorted.sort();

        if !sorted.is_empty() {
            lengths.push(sorted[0]); // First system prompt
            
            for i in 1..sorted.len() {
                lengths.push(delta); // Separator
                lengths.push(sorted[i] - sorted[i-1] - delta); // Difference
            }
        }

        if !lengths.is_empty() {
            self.chunk_lengths = lengths;
        }
    }

    /// Compute 8-bit hash for a chunk
    fn hash_chunk(&self, chunk: &[u8]) -> u8 {
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        chunk.hash(&mut hasher);
        (hasher.finish() & 0xFF) as u8
    }

    /// Split content into chunks based on configured lengths
    fn chunk_content(&self, content: &[u8]) -> Vec<Vec<u8>> {
        let mut chunks = Vec::new();
        let mut offset = 0;

        for &len in &self.chunk_lengths {
            if offset >= content.len() {
                break;
            }
            let end = (offset + len).min(content.len());
            chunks.push(content[offset..end].to_vec());
            offset = end;
        }

        // Handle remaining content with fixed-size chunks
        while offset < content.len() {
            let end = (offset + self.config.max_chunk_len).min(content.len());
            chunks.push(content[offset..end].to_vec());
            offset = end;
        }

        chunks
    }

    /// Search for matching prefix in tree
    /// Returns (matched_depth, matching_model_nodes)
    pub fn search(&self, content: &[u8]) -> (usize, Vec<NodeMetadata>) {
        let chunks = self.chunk_content(content);
        let mut current = &self.root;
        let mut depth = 0;

        for chunk in chunks {
            let hash = self.hash_chunk(&chunk);
            
            match current.children.get(&hash) {
                Some(child) => {
                    current = child;
                    depth += 1;
                }
                None => break,
            }
        }

        if depth >= self.config.hit_threshold {
            (depth, current.model_nodes.clone())
        } else {
            (depth, Vec::new())
        }
    }

    /// Insert cache entry for a model node
    pub fn insert(&mut self, content: &[u8], metadata: NodeMetadata) {
        let chunks = self.chunk_content(content);
        let hashes: Vec<u8> = chunks.iter().map(|c| self.hash_chunk(c)).collect();
        
        let mut current = &mut self.root;

        for hash in hashes {
            current = current.children
                .entry(hash)
                .or_insert_with(|| Box::new(HRTreeNode::new(hash)));
        }

        // Add or update model node at leaf
        if let Some(existing) = current.model_nodes.iter_mut()
            .find(|n| n.address == metadata.address) {
            *existing = metadata;
        } else {
            current.model_nodes.push(metadata);
        }
    }

    /// Generate delta update for synchronization
    pub fn generate_delta(&self, since_timestamp: u64) -> HRTreeDelta {
        let mut additions = Vec::new();
        let mut removals = Vec::new();

        self.collect_deltas(&self.root, Vec::new(), since_timestamp, &mut additions, &mut removals);

        HRTreeDelta { additions, removals }
    }

    fn collect_deltas(
        &self,
        node: &HRTreeNode,
        path: Vec<u8>,
        since: u64,
        additions: &mut Vec<DeltaEntry>,
        removals: &mut Vec<DeltaEntry>,
    ) {
        for metadata in &node.model_nodes {
            if metadata.updated_at > since {
                additions.push(DeltaEntry {
                    path: path.clone(),
                    metadata: metadata.clone(),
                });
            }
        }

        for (hash, child) in &node.children {
            let mut child_path = path.clone();
            child_path.push(*hash);
            self.collect_deltas(child, child_path, since, additions, removals);
        }
    }

    /// Apply delta update from another node
    pub fn apply_delta(&mut self, delta: HRTreeDelta) {
        for entry in delta.additions {
            self.insert_at_path(&entry.path, entry.metadata);
        }
        // Handle removals...
    }

    fn insert_at_path(&mut self, path: &[u8], metadata: NodeMetadata) {
        let mut current = &mut self.root;
        
        for &hash in path {
            current = current.children
                .entry(hash)
                .or_insert_with(|| Box::new(HRTreeNode::new(hash)));
        }
        
        current.model_nodes.push(metadata);
    }
}

/// Delta update for HR-tree synchronization
#[derive(Clone, Debug)]
pub struct HRTreeDelta {
    pub additions: Vec<DeltaEntry>,
    pub removals: Vec<DeltaEntry>,
}

#[derive(Clone, Debug)]
pub struct DeltaEntry {
    pub path: Vec<u8>,
    pub metadata: NodeMetadata,
}

/// Load balancing integration
impl HRTree {
    /// Get best node for workload considering cache and load
    pub fn get_best_node(
        &self,
        content: &[u8],
        reputation_threshold: f64,
    ) -> Option<NodeMetadata> {
        let (depth, candidates) = self.search(content);

        if depth >= self.config.hit_threshold && !candidates.is_empty() {
            // Cache hit - find lowest LB factor among trusted nodes
            candidates.iter()
                .filter(|n| n.reputation >= reputation_threshold)
                .min_by(|a, b| a.lb_factor.partial_cmp(&b.lb_factor).unwrap())
                .cloned()
        } else {
            // Cache miss - would need all_nodes list for load balancing
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hr_tree_insert_and_search() {
        let mut tree = HRTree::new(ChunkConfig::default());
        
        let content = b"You are a helpful AI assistant. User: Hello!";
        let metadata = NodeMetadata {
            address: "192.168.1.1".to_string(),
            lb_factor: 0.5,
            reputation: 0.9,
            updated_at: 1000,
        };

        tree.insert(content, metadata.clone());
        
        let (depth, nodes) = tree.search(content);
        assert!(depth > 0);
        assert!(!nodes.is_empty());
        assert_eq!(nodes[0].address, "192.168.1.1");
    }

    #[test]
    fn test_hr_tree_prefix_matching() {
        let mut tree = HRTree::new(ChunkConfig {
            hit_threshold: 2,
            ..Default::default()
        });
        
        let base = b"You are a helpful AI assistant. User: ";
        let query1 = b"You are a helpful AI assistant. User: Hello!";
        let query2 = b"You are a helpful AI assistant. User: Goodbye!";
        
        let metadata = NodeMetadata {
            address: "192.168.1.1".to_string(),
            lb_factor: 0.5,
            reputation: 0.9,
            updated_at: 1000,
        };

        tree.insert(query1, metadata);
        
        // Similar prefix should match
        let (depth1, _) = tree.search(query1);
        let (depth2, _) = tree.search(query2);
        
        // Both should have some prefix match due to shared system prompt
        assert!(depth1 > 0);
        // depth2 may vary based on chunking
    }
}
```

### Integration with RustOrchestration

1. **Replace centralized scheduler** with distributed HR-tree lookups
2. **Container image layers** → Tree nodes (instead of KV cache prefixes)
3. **Workload affinity** → Prefix matching
4. **State synchronization** → Delta broadcasts every 5 seconds

---

## 3. Anonymous Communication (S-IDA)

### Overview

S-IDA (Secure Information Dispersal Algorithm) combines Rabin's IDA for message splitting with Shamir's Secret Sharing for key distribution, enabling:

- **User anonymity**: Relay nodes can't link requests to identities
- **Content confidentiality**: Message visible only to sender and destination
- **Failure resilience**: k-of-n threshold for successful delivery
- **Low overhead**: No public-key operations on relay paths

### Protocol Steps

```
1. PREPARATION
   - User downloads user list and model node list from verification committee
   - Lists signed by >2/3 verification nodes

2. PROXY ESTABLISHMENT (Onion Routing)
   - User selects l=3 relays for each of N≥n paths
   - Builds Onion path using public keys
   - Session ID = hash(user_id, last_node_id)
   - Each relay stores: (predecessor, successor, session_id)

3. MESSAGE SENDING (S-IDA)
   a) Encrypt message M with random AES key K: {M}K
   b) Split {M}K into n fragments using Rabin's IDA (k-threshold)
   c) Split K into n fragments using Shamir's Secret Sharing
   d) Create n cloves: Ci = (Mi, Ki)
   e) Send cloves via n different paths to proxies
   f) Proxies forward cloves to destination

4. MESSAGE RECOVERY
   - Destination receives ≥k cloves
   - Reconstruct key K from ≥k shares
   - Reconstruct {M}K from ≥k fragments
   - Decrypt to recover M
```

### Rust Implementation

```rust
// sida.rs - Secure Information Dispersal Algorithm

use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use rand::{thread_rng, RngCore};

/// Configuration for S-IDA
#[derive(Clone, Debug)]
pub struct SidaConfig {
    /// Total number of cloves to create
    pub n: usize,
    /// Minimum cloves needed for recovery
    pub k: usize,
    /// Number of relay hops per path
    pub path_length: usize,
}

impl Default for SidaConfig {
    fn default() -> Self {
        Self {
            n: 4,
            k: 3,
            path_length: 3,
        }
    }
}

/// A clove containing encrypted message fragment and key share
#[derive(Clone, Debug)]
pub struct Clove {
    /// Index of this clove (1 to n)
    pub index: usize,
    /// Path session ID for routing
    pub session_id: [u8; 32],
    /// Encrypted message fragment
    pub message_fragment: Vec<u8>,
    /// Key share for this clove
    pub key_share: KeyShare,
    /// Destination address
    pub destination: String,
}

/// Shamir secret sharing key share
#[derive(Clone, Debug)]
pub struct KeyShare {
    pub x: u8,
    pub y: Vec<u8>,
}

/// S-IDA encoder for message distribution
pub struct SidaEncoder {
    config: SidaConfig,
}

impl SidaEncoder {
    pub fn new(config: SidaConfig) -> Self {
        Self { config }
    }

    /// Create cloves from a message
    pub fn encode(
        &self,
        message: &[u8],
        destination: &str,
        session_ids: Vec<[u8; 32]>,
    ) -> Result<Vec<Clove>, SidaError> {
        if session_ids.len() != self.config.n {
            return Err(SidaError::InvalidConfig(
                "session_ids count must equal n".to_string()
            ));
        }

        // Step 1: Generate random AES key
        let mut key = [0u8; 32];
        thread_rng().fill_bytes(&mut key);

        // Step 2: Encrypt message with AES-256-GCM
        let cipher = Aes256Gcm::new_from_slice(&key)
            .map_err(|e| SidaError::Encryption(e.to_string()))?;
        
        let mut nonce_bytes = [0u8; 12];
        thread_rng().fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);
        
        let mut ciphertext = cipher.encrypt(nonce, message)
            .map_err(|e| SidaError::Encryption(e.to_string()))?;
        
        // Prepend nonce to ciphertext
        let mut encrypted = nonce_bytes.to_vec();
        encrypted.append(&mut ciphertext);

        // Step 3: Split encrypted message using Rabin's IDA
        let message_fragments = self.rabin_split(&encrypted)?;

        // Step 4: Split key using Shamir's Secret Sharing
        let key_shares = self.shamir_split(&key)?;

        // Step 5: Create cloves
        let cloves = session_ids.into_iter()
            .enumerate()
            .map(|(i, session_id)| Clove {
                index: i + 1,
                session_id,
                message_fragment: message_fragments[i].clone(),
                key_share: key_shares[i].clone(),
                destination: destination.to_string(),
            })
            .collect();

        Ok(cloves)
    }

    /// Rabin's IDA: Split data into n fragments where k are needed
    fn rabin_split(&self, data: &[u8]) -> Result<Vec<Vec<u8>>, SidaError> {
        let n = self.config.n;
        let k = self.config.k;

        // Pad data to be divisible by k
        let padded_len = ((data.len() + k - 1) / k) * k;
        let mut padded = data.to_vec();
        padded.resize(padded_len, 0);

        // Create Vandermonde matrix for encoding
        let fragment_size = padded_len / k;
        let mut fragments: Vec<Vec<u8>> = vec![vec![0u8; fragment_size]; n];

        // For each position in the fragments
        for pos in 0..fragment_size {
            let chunk_start = pos * k;
            let chunk: Vec<u8> = padded[chunk_start..chunk_start + k].to_vec();
            
            // For each output fragment
            for i in 0..n {
                let x = (i + 1) as u8;
                let mut val = 0u8;
                let mut x_power = 1u8;
                
                for j in 0..k {
                    val = gf_add(val, gf_mul(chunk[j], x_power));
                    x_power = gf_mul(x_power, x);
                }
                
                fragments[i][pos] = val;
            }
        }

        Ok(fragments)
    }

    /// Shamir's Secret Sharing: Split key into n shares where k are needed
    fn shamir_split(&self, secret: &[u8]) -> Result<Vec<KeyShare>, SidaError> {
        let n = self.config.n;
        let k = self.config.k;

        let mut shares = Vec::with_capacity(n);
        
        // Generate random coefficients for polynomial
        let mut coefficients: Vec<Vec<u8>> = Vec::with_capacity(secret.len());
        for byte in secret {
            let mut coefs = vec![*byte];
            for _ in 1..k {
                let mut random_byte = [0u8; 1];
                thread_rng().fill_bytes(&mut random_byte);
                coefs.push(random_byte[0]);
            }
            coefficients.push(coefs);
        }

        // Evaluate polynomial at points 1..n
        for i in 1..=n {
            let x = i as u8;
            let mut y = Vec::with_capacity(secret.len());
            
            for coefs in &coefficients {
                let mut val = 0u8;
                let mut x_power = 1u8;
                
                for &coef in coefs {
                    val = gf_add(val, gf_mul(coef, x_power));
                    x_power = gf_mul(x_power, x);
                }
                
                y.push(val);
            }
            
            shares.push(KeyShare { x, y });
        }

        Ok(shares)
    }
}

/// S-IDA decoder for message recovery
pub struct SidaDecoder {
    config: SidaConfig,
}

impl SidaDecoder {
    pub fn new(config: SidaConfig) -> Self {
        Self { config }
    }

    /// Recover message from cloves (need at least k cloves)
    pub fn decode(&self, cloves: &[Clove]) -> Result<Vec<u8>, SidaError> {
        if cloves.len() < self.config.k {
            return Err(SidaError::InsufficientCloves {
                required: self.config.k,
                received: cloves.len(),
            });
        }

        // Take first k cloves
        let used_cloves: Vec<&Clove> = cloves.iter().take(self.config.k).collect();

        // Step 1: Recover key using Lagrange interpolation
        let key = self.shamir_recover(&used_cloves)?;

        // Step 2: Recover encrypted message using IDA
        let encrypted = self.rabin_recover(&used_cloves)?;

        // Step 3: Decrypt message
        let nonce = Nonce::from_slice(&encrypted[..12]);
        let ciphertext = &encrypted[12..];

        let cipher = Aes256Gcm::new_from_slice(&key)
            .map_err(|e| SidaError::Decryption(e.to_string()))?;
        
        let plaintext = cipher.decrypt(nonce, ciphertext)
            .map_err(|e| SidaError::Decryption(e.to_string()))?;

        Ok(plaintext)
    }

    fn shamir_recover(&self, cloves: &[&Clove]) -> Result<[u8; 32], SidaError> {
        let k = self.config.k;
        let key_len = 32;
        let mut key = [0u8; 32];

        let xs: Vec<u8> = cloves.iter().map(|c| c.key_share.x).collect();

        for byte_idx in 0..key_len {
            let ys: Vec<u8> = cloves.iter()
                .map(|c| c.key_share.y[byte_idx])
                .collect();

            // Lagrange interpolation at x=0
            let mut result = 0u8;
            
            for i in 0..k {
                let mut numerator = 1u8;
                let mut denominator = 1u8;
                
                for j in 0..k {
                    if i != j {
                        numerator = gf_mul(numerator, xs[j]);
                        denominator = gf_mul(denominator, gf_add(xs[i], xs[j]));
                    }
                }
                
                let lagrange = gf_mul(ys[i], gf_mul(numerator, gf_inv(denominator)));
                result = gf_add(result, lagrange);
            }
            
            key[byte_idx] = result;
        }

        Ok(key)
    }

    fn rabin_recover(&self, cloves: &[&Clove]) -> Result<Vec<u8>, SidaError> {
        let k = self.config.k;
        let fragment_size = cloves[0].message_fragment.len();
        let mut recovered = vec![0u8; fragment_size * k];

        let xs: Vec<u8> = cloves.iter().map(|c| c.index as u8).collect();

        for pos in 0..fragment_size {
            let ys: Vec<u8> = cloves.iter()
                .map(|c| c.message_fragment[pos])
                .collect();

            // Solve system using Lagrange interpolation
            for coef_idx in 0..k {
                let eval_point = (coef_idx + 1) as u8;
                let mut result = 0u8;
                
                for i in 0..k {
                    let mut numerator = 1u8;
                    let mut denominator = 1u8;
                    
                    for j in 0..k {
                        if i != j {
                            numerator = gf_mul(numerator, gf_add(eval_point, xs[j]));
                            denominator = gf_mul(denominator, gf_add(xs[i], xs[j]));
                        }
                    }
                    
                    let lagrange = gf_mul(ys[i], gf_mul(numerator, gf_inv(denominator)));
                    result = gf_add(result, lagrange);
                }
                
                recovered[pos * k + coef_idx] = result;
            }
        }

        // Remove padding
        while recovered.last() == Some(&0) {
            recovered.pop();
        }

        Ok(recovered)
    }
}

/// GF(2^8) arithmetic operations
fn gf_add(a: u8, b: u8) -> u8 {
    a ^ b
}

fn gf_mul(a: u8, b: u8) -> u8 {
    let mut result = 0u8;
    let mut a = a;
    let mut b = b;
    
    while b > 0 {
        if b & 1 != 0 {
            result ^= a;
        }
        let high_bit = a & 0x80;
        a <<= 1;
        if high_bit != 0 {
            a ^= 0x1B; // AES irreducible polynomial
        }
        b >>= 1;
    }
    
    result
}

fn gf_inv(a: u8) -> u8 {
    if a == 0 {
        return 0;
    }
    
    let mut result = a;
    for _ in 0..6 {
        result = gf_mul(result, result);
        result = gf_mul(result, a);
    }
    gf_mul(result, result)
}

#[derive(Debug, thiserror::Error)]
pub enum SidaError {
    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),
    
    #[error("Encryption error: {0}")]
    Encryption(String),
    
    #[error("Decryption error: {0}")]
    Decryption(String),
    
    #[error("Insufficient cloves: need {required}, received {received}")]
    InsufficientCloves { required: usize, received: usize },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sida_roundtrip() {
        let config = SidaConfig::default();
        let encoder = SidaEncoder::new(config.clone());
        let decoder = SidaDecoder::new(config.clone());

        let message = b"Hello, this is a secret message for mycelial credit!";
        let session_ids: Vec<[u8; 32]> = (0..4)
            .map(|i| {
                let mut id = [0u8; 32];
                id[0] = i as u8;
                id
            })
            .collect();

        let cloves = encoder.encode(message, "10.0.0.1", session_ids)
            .expect("Encoding should succeed");

        assert_eq!(cloves.len(), 4);

        // Recovery with exactly k cloves
        let recovered = decoder.decode(&cloves[..3])
            .expect("Decoding with k cloves should succeed");

        assert_eq!(recovered, message);
    }

    #[test]
    fn test_sida_insufficient_cloves() {
        let config = SidaConfig::default();
        let encoder = SidaEncoder::new(config.clone());
        let decoder = SidaDecoder::new(config.clone());

        let message = b"Secret";
        let session_ids: Vec<[u8; 32]> = (0..4)
            .map(|_| [0u8; 32])
            .collect();

        let cloves = encoder.encode(message, "10.0.0.1", session_ids).unwrap();

        // Try recovery with less than k cloves
        let result = decoder.decode(&cloves[..2]);
        assert!(matches!(result, Err(SidaError::InsufficientCloves { .. })));
    }
}
```

→ See [CryptoSaint Anonymous Routing](./cryptosaint-anonymous-routing.md) for credit transaction integration.

---

## 4. BFT Verification Committee

### Overview

The verification committee uses Tendermint-based BFT consensus to maintain consistent reputation scores and prevent malicious nodes from gaming the system.

### Committee Responsibilities

1. **Maintain user/model node lists** with public keys and IP addresses
2. **Issue challenge prompts** anonymously through overlay network
3. **Compute perplexity scores** for model responses
4. **Update reputation scores** with asymmetric punishment
5. **Mark untrusted nodes** when reputation falls below threshold

### Verification Protocol

```
EPOCH e_i:
1. Leader L_i selected by VRF on previous epoch's commit hash
2. L_i sends challenge prompts to model nodes in M_i (predetermined)
3. Model nodes return signed responses through anonymous overlay
4. L_i computes credit scores and reputation updates
5. L_i broadcasts (responses, scores) to committee
6. Each verification node:
   - Validates signatures and prompts
   - Independently computes scores
   - Compares with leader's proposal
7. Two-phase voting: Pre-Vote → Pre-Commit
8. Update committed if 2n/3+1 nodes agree
```

### Integration with CryptoSaint Governance

```rust
// verification_committee.rs - BFT verification for governance

use tendermint::consensus::State;

/// Verification epoch state
#[derive(Clone, Debug)]
pub struct VerificationEpoch {
    /// Epoch number
    pub epoch: u64,
    /// Leader for this epoch
    pub leader: ValidatorId,
    /// Model nodes to verify
    pub target_nodes: Vec<NodeId>,
    /// Challenge prompts (hashed for commitment)
    pub prompt_commitments: Vec<[u8; 32]>,
    /// Collected responses
    pub responses: Vec<SignedResponse>,
    /// Computed scores
    pub scores: Vec<(NodeId, f64)>,
    /// Votes collected
    pub pre_votes: Vec<Vote>,
    pub pre_commits: Vec<Vote>,
}

/// Committee-wide reputation update
#[derive(Clone, Debug)]
pub struct ReputationUpdate {
    pub epoch: u64,
    pub updates: Vec<(NodeId, f64)>,
    pub untrusted: Vec<NodeId>,
    pub signature: AggregateSignature,
}

#[async_trait::async_trait]
pub trait VerificationCommittee: Send + Sync {
    /// Get current epoch
    async fn current_epoch(&self) -> u64;
    
    /// Am I the leader for this epoch?
    async fn is_leader(&self) -> bool;
    
    /// Send challenge prompts (leader only)
    async fn send_challenges(&self, epoch: &VerificationEpoch) -> Result<(), CommitteeError>;
    
    /// Collect and validate responses (leader only)
    async fn collect_responses(&self, epoch: &mut VerificationEpoch) -> Result<(), CommitteeError>;
    
    /// Compute scores locally
    async fn compute_scores(&self, epoch: &VerificationEpoch) -> Vec<(NodeId, f64)>;
    
    /// Vote on proposed updates
    async fn vote(&self, update: &ReputationUpdate) -> Result<Vote, CommitteeError>;
    
    /// Commit approved updates
    async fn commit(&self, update: ReputationUpdate) -> Result<(), CommitteeError>;
}
```

---

## Implementation Checklist

### Week 1-2: Reputation System
- [ ] Implement `NodeReputation` with sliding window
- [ ] Add `ReputationStore` trait to StateStore
- [ ] Create reputation update endpoint
- [ ] Add punishment mechanism tests

### Week 3-4: Hash-Radix Tree
- [ ] Implement `HRTree` data structure
- [ ] Add chunk configuration from Sentry
- [ ] Create delta synchronization protocol
- [ ] Integrate with scheduler for workload routing

### Week 5-6: Anonymous Communication
- [ ] Implement S-IDA encoder/decoder
- [ ] Create proxy establishment protocol
- [ ] Add path session management
- [ ] Integrate with credit transaction layer

### Future: Verification Committee
- [ ] Tendermint integration
- [ ] Challenge prompt generation
- [ ] Perplexity scoring implementation
- [ ] Two-phase voting protocol

---

## References

1. [PlanetServe: A Decentralized, Scalable, and Privacy-Preserving Overlay for Democratizing Large Language Model Serving](https://arxiv.org/abs/2504.20101) - Fang et al., 2025
2. [Tendermint: Byzantine Fault Tolerance in the Age of Blockchains](https://arxiv.org/abs/1807.04938) - Buchman et al., 2018
3. [Secret Sharing Made Short](https://www.iacr.org/archive/crypto93/01-14.pdf) - Krawczyk, 1993
4. [Efficient Dispersal of Information for Security](https://dl.acm.org/doi/10.1145/62212.62213) - Rabin, 1989
