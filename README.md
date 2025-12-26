# Univrs.io — Sovereign Infrastructure for the Mycelial Economy

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/rust-1.75+-orange.svg)](https://www.rust-lang.org/)

> *Building decentralized infrastructure where contribution creates credit, reputation influences resource allocation, and communities self-govern through transparent mathematical algorithms.*

## 🌐 Vision

Univrs.io is building a comprehensive ecosystem of sovereign infrastructure platforms that embody **mycelial economics** — a regenerative economic model inspired by fungal networks where resources flow organically based on contribution and mutual benefit rather than extraction.

The project aims to replace centralized cloud oligopolies and debt-based financial systems with decentralized alternatives that promote:
- 🌍 **Ecological regeneration**
- 🔐 **Data sovereignty**  
- ⚖️ **Equitable resource distribution**

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Univrs.io Ecosystem                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │ RustOrchestration│ │   CryptoSaint   │  │ MyceliaNetwork  │      │
│  │   Container      │ │   Regenerative  │  │   P2P Social    │      │
│  │   Orchestration  │ │   Credit System │  │   Coordination  │      │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘      │
│           │                    │                    │               │
│           └────────────────────┼────────────────────┘               │
│                                │                                    │
│  ┌─────────────────────────────▼─────────────────────────────────┐  │
│  │                     PlanetServe Layer                          │ │
│  │   Decentralized LLM Serving | Anonymous Routing | Verification │
│  └───────────────────────────────────────────────────────────────┘  │
│                                │                                    │
│  ┌─────────────────────────────▼─────────────────────────────────┐  │
│  │                       dynamic-math                            │  │
│  │          Client-side WASM for Transparent Algorithms          │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 🧬 Core Platforms

### 1. RustOrchestration
AI-native container orchestration built in Rust with mycelial scheduling principles.

**Key Features:**
- Persistent state management with credit tracking
- Trait-based abstractions for pluggable components
- Kubernetes-style reconciliation loops
- MutualCreditScheduler for reputation-based resource allocation

**Status:** Core architecture implemented, mycelial economics integration in progress.

→ [View RustOrchestration Documentation](https://github.com/univrs/univrs-orchestration)

### 2. CryptoSaint
Regenerative credit system implementing mycelial economics for community-governed finance.

**Key Features:**
- Community-governed mutual credit networks
- Tokenized ecological credit systems  
- Reputation-based lending in decentralized networks
- Context-aware credit assessment engine

**Status:** Theoretical framework complete, technical implementation roadmap defined.

→ [View CryptoSaint Documentation](https://cryptosaint.io)

### 3. MyceliaNetwork
Peer-to-peer social coordination platform enabling bioregional economic integration.

**Key Features:**
- Decentralized identity and reputation
- Resource sharing protocols
- Collective governance mechanisms
- Cross-community coordination

→ [View MyceliaNetwork Documentation](https://github.com/univrs/univrs-network)

### 4. PlanetServe Integration (NEW)
Decentralized infrastructure for scalable, privacy-preserving distributed computing, based on [PlanetServe research](https://arxiv.org/abs/2504.20101).

**Key Features:**
- **Anonymous Communication** via S-IDA (Secure Information Dispersal Algorithm)
- **Reputation-Based Verification** using perplexity scoring
- **Hash-Radix Trees** for decentralized workload distribution
- **BFT Consensus** for verification committee governance

→ [View PlanetServe Integration Specifications](archives/planetserve-integration.md)

## 🔬 Research Foundation

### Mycelial Economics Principles

| Principle | Traditional Economics | Mycelial Economics |
|-----------|----------------------|-------------------|
| Organization | Hierarchical | Distributed networks |
| Resource Flow | Competitive extraction | Collaborative regeneration |
| Decision Making | Top-down | Emergent coordination |
| Value Creation | Individual accumulation | Collective benefit |
| Success Metrics | GDP, profit | Ecosystem health, life capacity |

### Validated by Real-World Systems

- **Sardex (Italy)**: 4,000+ businesses, €50M+ annual transactions via mutual credit
- **WIR Bank (Switzerland)**: 90+ years, 45,000 members, 1.5B CHF annual turnover
- **Mondragon Cooperative**: 70,000+ worker-owners, billions in annual revenue

## 📊 Technical Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Systems Programming | **Rust** | Memory safety, performance, async/await |
| Blockchain | **Substrate** | Credit creation, reputation, ecological accounting |
| P2P Networking | **libp2p** | Peer discovery, message routing |
| Algorithms | **WebAssembly** | Cross-platform transparent computation |
| Consensus | **Raft/BFT** | Distributed state consistency |
| Verification | **Tendermint** | Committee-based governance |


## 📅 Roadmap

### Phase 1: Foundation (Current)
- [x] Core trait architecture
- [x] Persistent state management
- [x] Error handling framework
- [ ] Credit tracking in StateStore
- [x] Design Ontology Language 2.0 (v0.2.2 "Bootstrap" released Dec 26, 2024 - Self-hosting achieved!) 

### Phase 2: PlanetServe Integration (Q1 2025)
- [ ] Reputation scoring system
- [ ] Hash-Radix tree for workload distribution
- [ ] S-IDA anonymous communication
- [ ] BFT verification committee

### Phase 3: Mycelial Economics (Q2 2025)
- [ ] MutualCreditScheduler
- [ ] Ecological impact valuation
- [ ] Cross-platform WASM algorithms
- [ ] Community governance tools 
- [ ] VUDO OS and DOL Runtime 

→ [View Univrs Roadmap](archives/Univrs_Roadmap.md)

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [PlanetServe Integration](archives/planetserve-integration.md) | Technical specifications for decentralized infrastructure |
| [Anonymous Routing for CryptoSaint](https://cryptosaint.io) | Securing credit transactions with S-IDA |
| [Mycelial Economics Technologies](archives/Mycelial_Economics_Orch.md) | Complete technology ecosystem overview |
| [API Reference](archives/Univrs_DevTools.md) | Developer API documentation |

## 🤝 Contributing

We welcome contributions from developers, economists, ecologists, and anyone passionate about regenerative systems.

### Ways to Contribute
1. **Code**: Submit PRs for features, bug fixes, or optimizations
2. **Documentation**: Improve guides, tutorials, or API docs
3. **Research**: Share relevant papers, case studies, or data
4. **Community**: Participate in discussions, help others

### Development Workflow
```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes and test
cargo test
cargo clippy

# Submit a pull request
git push origin feature/your-feature-name
```

## 📞 Contact

- **Website**: [https://univrs.io](https://univrs.io)
- **Email**: ardeshir.org@gmail.com
- **Documentation**: [book.univrs.io](https://book.univrs.io/docs) you're here :P

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

*"In mycelial networks, each node both gives and receives. The health of the whole emerges from the cooperation of the parts."*

**Building the future of sovereign infrastructure, one contribution at a time.**

</div>
