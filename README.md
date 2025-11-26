# Univrs Infrastructure

> **Building the future of Rust-native orchestration and sovereign computing infrastructure**

Welcome to the Univrs.io documentation — your comprehensive guide to Univrs infrastructure, Rust orchestration, and the technologies powering decentralized compute sovereignty.

## What is Univrs?

Univrs.io is building the next generation of infrastructure tools focused on:

- **🦀 Rust-Native Orchestration** — High-performance container orchestration built entirely in Rust, leveraging traits and async patterns for maximum efficiency
- **🖥️ Univrs Infrastructure** — illumos-based operating systems, Oxide hardware, and sovereign compute platforms
- **🌐 Protocol Innovation** — Universal Tool Calling Protocol (UTCP) vs Model Context Protocol (MCP) analysis and implementation
- **☁️ Cloud-Agnostic DevOps** — Azure, AWS, Kubernetes, and multi-cloud deployment strategies

## Quick Navigation

| Section | Description |
|---------|-------------|
| [**Univrs.io Vision**](vision-and-strategy/univrs_argument.md) | Our thesis, roadmap, and go-to-market strategy |
| [**Rust Orchestration**](rust-orchestration/README.md) | Core orchestration primitives, interfaces, and implementation |
| [**Univrs Infrastructure**](https://book.univrs.io/os/) | illumos, Oxide, and sovereign hardware |
| [**Oxide Computer**](oxide/README.md) | Deep dive into Oxide hardware and philosophy |
| [**Azure & Cloud DevOps**](azure-and-cloud-devops/azure-functions/README.md) | Cloud deployment guides and DevOps patterns |
| [**Global Economics**](global-economics-and-geopolitics/monetary-systems/README.md) | Analysis of monetary systems and economic models |

## Getting Started

### For Developers
Start with the [Rust Orchestration](rust-orchestration/README.md) section to understand the core architecture, including:
- Cargo workspace setup
- Shared type definitions
- Container runtime interfaces
- Scheduler implementations

### For Infrastructure Engineers
Explore the [Univrs Infrastructure](oxide/README.md) section covering:
- illumos DTrace and MDB debugging
- Oxide rack deployment with Talos Linux
- Virtualization with virtio

### For Strategists
Review our [Vision & Strategy](vision-and-strategy/univrs_argument.md) documents:
- Univrs.io core thesis
- UTCP vs MCP protocol comparison
- Market positioning

## Technology Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    Univrs.io Platform                       │
├─────────────────────────────────────────────────────────────┤
│  Applications   │  MCP Server  │  Cloud APIs  │  CLI Tools  │
├─────────────────────────────────────────────────────────────┤
│            Rust Orchestrator Core (orchestrator_core)       │
├─────────────────────────────────────────────────────────────┤
│  Container     │  Cluster      │  Scheduler   │   Shared    │
│  Runtime       │  Manager      │  Interface   │   Types     │
│  Interface     │  Interface    │              │             │
├─────────────────────────────────────────────────────────────┤
│        Youki Runtime   │   memberlist-rs   │   TiKV/etcd    │
├─────────────────────────────────────────────────────────────┤
│         illumos  /  Oxide Hardware  /  Linux (Talos)        │
└─────────────────────────────────────────────────────────────┘
```

## Connect

- **Discord**: [Join Univrs.io Community](https://discord.gg/pXwH6rQcsS)
- **Documentation**: You're here! 📖

---

*Univrs.io — Orchestrating Freedom*
