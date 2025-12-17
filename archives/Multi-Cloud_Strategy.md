# Univrs.io: Dogfooding & Multi-Cloud Strategy

## Executive Summary

The most pragmatic path to production is **multi-cloud free tier** deployment, progressively evolving into a true mycelial network. This approach:

- Proves cloud-agnostic architecture from day one
- Zero infrastructure cost for MVP/POC
- Real geographic distribution for testing gossip protocols
- Natural evolution path as the network grows

---

## Architecture Convergence

You have two complementary systems that should converge:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         UNIVRS.IO UNIFIED PLATFORM                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────┐          ┌─────────────────────┐               │
│  │  MYCELIAL DASHBOARD │          │  RUST ORCHESTRATOR  │               │
│  │  (mycelial-dashboard)│         │  (RustOrchestration) │               │
│  ├─────────────────────┤          ├─────────────────────┤               │
│  │ • P2P Discovery     │◄────────►│ • Container Runtime │               │
│  │ • Gossipsub Mesh    │  Gossip  │ • Workload Scheduling│              │
│  │ • Reputation System │  Events  │ • State Management  │               │
│  │ • Credit Relations  │          │ • MCP AI Interface  │               │
│  │ • React Dashboard   │          │ • Reconciliation    │               │
│  └─────────┬───────────┘          └──────────┬──────────┘               │
│            │                                  │                          │
│            └──────────────┬───────────────────┘                          │
│                           │                                              │
│                           ▼                                              │
│            ┌─────────────────────────────┐                              │
│            │     UNIFIED CONTROL PLANE    │                              │
│            │  ┌─────────────────────────┐│                              │
│            │  │ • Single React Dashboard ││                              │
│            │  │ • MCP for AI Control     ││                              │
│            │  │ • Chitchat Cluster Mgmt  ││                              │
│            │  │ • Mycelial Credit System ││                              │
│            │  └─────────────────────────┘│                              │
│            └─────────────────────────────┘                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## UI Strategy: Unified Dashboard

### Option A: Extend Mycelial Dashboard (Recommended)

The mycelial-dashboard already has:
- React + TypeScript frontend
- WebSocket real-time updates
- P2P network visualization
- Rust backend with WASM bridge

**Extend it to include orchestrator views:**

```
mycelial-dashboard/
├── dashboard/src/
│   ├── views/
│   │   ├── network/          # Existing P2P views
│   │   │   ├── PeerGraph.tsx
│   │   │   ├── GossipLog.tsx
│   │   │   └── ReputationBoard.tsx
│   │   │
│   │   ├── orchestrator/     # NEW: Orchestrator views
│   │   │   ├── WorkloadList.tsx
│   │   │   ├── NodeStatus.tsx
│   │   │   ├── SchedulerView.tsx
│   │   │   └── MCPConsole.tsx    # AI interaction terminal
│   │   │
│   │   └── mycelial/         # NEW: Unified economic views
│   │       ├── CreditNetwork.tsx
│   │       ├── ResourceFlow.tsx
│   │       └── ContributionGraph.tsx
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        REACT DASHBOARD                           │
├─────────────────────────────────────────────────────────────────┤
│                              │                                   │
│         WebSocket #1         │         WebSocket #2              │
│     (P2P Network Events)     │    (Orchestrator Events)          │
│              │               │              │                    │
└──────────────┼───────────────┼──────────────┼────────────────────┘
               │               │              │
               ▼               │              ▼
┌──────────────────────┐       │    ┌──────────────────────┐
│  mycelial-node       │       │    │  orchestrator        │
│  (libp2p + gossip)   │◄──────┼───►│  (MCP server)        │
└──────────────────────┘       │    └──────────────────────┘
               │               │              │
               └───────────────┼──────────────┘
                               │
                    Chitchat Gossip Protocol
                    (Shared cluster membership)
```

---

## Multi-Cloud Free Tier Strategy

### Why Free Tier First?

| Approach | Cost | Access | Cloud-Agnostic Proof |
|----------|------|--------|---------------------|
| OpenNebula/Oxide | $$$$ | Limited | ❌ Single vendor |
| AWS/GCP/Azure only | $$ | Easy | ❌ Single vendor |
| **Multi-cloud Free Tier** | **$0** | **Easy** | **✅ Proven** |
| Community nodes | $0 | Organic | ✅ True mycelial |

### Free Tier Resources

| Provider | Instance Type | vCPU | RAM | Notes |
|----------|---------------|------|-----|-------|
| **AWS** | t2.micro / t3.micro | 1 | 1GB | 750 hrs/mo for 12 months |
| **GCP** | e2-micro | 0.25 | 1GB | Always free |
| **Azure** | B1s | 1 | 1GB | 750 hrs/mo for 12 months |
| **Oracle** | A1.Flex (ARM) | 4 | 24GB | Always free, best value! |
| **Hetzner** | - | - | - | Not free but €3/mo VPS |

### Recommended Initial Topology

```
                    ┌─────────────────────┐
                    │   BOOTSTRAP NODE    │
                    │   Oracle A1.Flex    │
                    │   (ARM, 4 vCPU)     │
                    │   us-ashburn-1      │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  AWS t3.micro   │ │  GCP e2-micro   │ │  Azure B1s      │
│  us-east-1      │ │  us-central1    │ │  eastus         │
│  Worker Node    │ │  Worker Node    │ │  Worker Node    │
└─────────────────┘ └─────────────────┘ └─────────────────┘
           │                   │                   │
           └───────────────────┼───────────────────┘
                               │
                        Chitchat Gossip
                        (Cross-cloud mesh)
```

---

## Dogfooding Phases

### Phase 1: Local Development (Current)
```bash
# Single node, all components local
cargo run --bin orchestrator
cargo run --bin mcp-orchestrator
cd mycelial-dashboard && pnpm dev
```

### Phase 2: Local Multi-Node (Docker Compose)
```yaml
# docker-compose.yml
services:
  bootstrap:
    build: .
    ports: ["9000:9000"]
    command: ["--bootstrap", "--port", "9000"]
  
  worker-1:
    build: .
    command: ["--connect", "/dns/bootstrap/udp/9000/quic-v1"]
  
  worker-2:
    build: .
    command: ["--connect", "/dns/bootstrap/udp/9000/quic-v1"]
  
  dashboard:
    build: ./mycelial-dashboard/dashboard
    ports: ["3000:3000"]
```

**Dogfood Test**: Deploy the orchestrator itself as a workload:
```bash
# Use orchestrator to deploy orchestrator
curl -X POST http://localhost:8080/api/workloads \
  -d '{"name": "orchestrator-canary", "image": "univrs/orchestrator:dev", "replicas": 1}'
```

### Phase 3: Multi-Cloud Free Tier

**IaC Approach**: Use Pulumi or OpenTofu (Terraform fork) for cloud-agnostic provisioning.

```
infrastructure/
├── Pulumi.yaml
├── index.ts                    # Or main.tf for OpenTofu
├── providers/
│   ├── aws.ts
│   ├── gcp.ts
│   ├── azure.ts
│   └── oracle.ts
└── modules/
    ├── bootstrap-node/
    ├── worker-node/
    └── networking/
```

**Pulumi Example**:
```typescript
// infrastructure/index.ts
import * as aws from "@pulumi/aws";
import * as gcp from "@pulumi/gcp";
import * as azure from "@pulumi/azure-native";

// Bootstrap on Oracle (best free tier)
const bootstrap = new oracle.core.Instance("bootstrap", {
    shape: "VM.Standard.A1.Flex",
    shapeConfig: { ocpus: 4, memoryInGbs: 24 },
    // ...
});

// Workers across clouds
const awsWorker = new aws.ec2.Instance("worker-aws", {
    instanceType: "t3.micro",
    // ...
});

const gcpWorker = new gcp.compute.Instance("worker-gcp", {
    machineType: "e2-micro",
    // ...
});

// Export endpoints for chitchat seed nodes
export const seedNodes = [
    pulumi.interpolate`/ip4/${bootstrap.publicIp}/udp/9000/quic-v1`,
    pulumi.interpolate`/ip4/${awsWorker.publicIp}/udp/9000/quic-v1`,
    pulumi.interpolate`/ip4/${gcpWorker.publicIp}/udp/9000/quic-v1`,
];
```

### Phase 4: Self-Deploying Orchestrator

**True dogfooding** - the orchestrator deploys its own updates:

```
┌─────────────────────────────────────────────────────────────────┐
│                    SELF-DEPLOYMENT PIPELINE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. GitHub Push                                                  │
│       │                                                          │
│       ▼                                                          │
│  2. GitHub Actions builds container image                        │
│       │                                                          │
│       ▼                                                          │
│  3. Push to registry (ghcr.io/univrs/orchestrator:sha-xxx)      │
│       │                                                          │
│       ▼                                                          │
│  4. MCP tool call to running orchestrator:                      │
│     "workload_update orchestrator-prod image=sha-xxx"           │
│       │                                                          │
│       ▼                                                          │
│  5. Orchestrator performs rolling update ON ITSELF              │
│       │                                                          │
│       ▼                                                          │
│  6. Gossip propagates new version across mycelial network       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Phase 5: Community Mycelial Network

As the network proves itself:
1. Contributors run nodes and earn reputation
2. Credit relationships form between node operators  
3. Resource sharing emerges organically
4. OpenNebula/Oxide nodes join when cost-effective

---

## Integration Points

### Chitchat ↔ libp2p Bridge

Both systems use gossip, but different protocols. Bridge them:

```rust
// cluster_manager/src/libp2p_bridge.rs

pub struct LibP2PChitchatBridge {
    chitchat: ChitchatClusterManager,
    libp2p_events: mpsc::Receiver<NetworkEvent>,
}

impl LibP2PChitchatBridge {
    /// Sync libp2p peer discovery with chitchat membership
    pub async fn run(&mut self) {
        loop {
            tokio::select! {
                // libp2p discovers new peer
                Some(NetworkEvent::PeerDiscovered(peer_id)) = self.libp2p_events.recv() => {
                    // Register in chitchat for orchestrator visibility
                    self.chitchat.register_peer(peer_id).await;
                }
                // Chitchat membership change
                Some(event) = self.chitchat.events().recv() => {
                    // Could trigger libp2p connection attempts
                    handle_membership_change(event).await;
                }
            }
        }
    }
}
```

### Mycelial Credits ↔ Scheduler

The credit system should influence scheduling:

```rust
// scheduler/src/mycelial.rs

pub struct MycelialScheduler {
    credit_network: Arc<CreditNetwork>,
    reputation_store: Arc<ReputationStore>,
}

impl Scheduler for MycelialScheduler {
    async fn schedule(&self, workload: &Workload, nodes: &[Node]) -> Result<Placement> {
        // Factor in node reputation
        let scored_nodes: Vec<_> = nodes.iter()
            .map(|n| {
                let reputation = self.reputation_store.get(&n.id).unwrap_or_default();
                let credit_balance = self.credit_network.balance(&n.operator);
                (n, reputation.score * 0.7 + credit_balance.normalized() * 0.3)
            })
            .collect();
        
        // Prefer high-reputation, positive-credit nodes
        let best = scored_nodes.into_iter()
            .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
            .map(|(n, _)| n);
        
        // ...
    }
}
```

---

## Recommended Tech Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **IaC** | Pulumi (TypeScript) or OpenTofu | Cloud-agnostic, free tier friendly |
| **Container Registry** | ghcr.io | Free for public repos |
| **CI/CD** | GitHub Actions | Free for public repos |
| **Secrets** | SOPS + age | Git-friendly, no cloud dependency |
| **Monitoring** | Prometheus + Grafana Cloud | Free tier available |
| **DNS** | Cloudflare | Free tier, global anycast |
| **Gossip** | Chitchat + libp2p | Already integrated |

---

## Migration Path: Free Tier → Production

```
┌─────────────────────────────────────────────────────────────────┐
│                      GROWTH TRAJECTORY                           │
├──────────┬──────────────────────────────────────────────────────┤
│  Stage   │  Infrastructure                                       │
├──────────┼──────────────────────────────────────────────────────┤
│  MVP     │  Multi-cloud free tier (4-5 nodes)                   │
│          │  $0/month                                             │
├──────────┼──────────────────────────────────────────────────────┤
│  Early   │  Free tier + Hetzner/OVH VPS (10-20 nodes)          │
│  Adopters│  ~$30-50/month                                       │
├──────────┼──────────────────────────────────────────────────────┤
│  Growth  │  Community nodes join (reputation incentive)         │
│          │  Mostly $0 (operators contribute for credits)        │
├──────────┼──────────────────────────────────────────────────────┤
│  Scale   │  Hybrid: community + reserved cloud capacity         │
│          │  Strategic OpenNebula/Oxide for specific workloads   │
├──────────┼──────────────────────────────────────────────────────┤
│  Mature  │  True mycelial: decentralized node operation         │
│          │  Self-sustaining through credit economics            │
└──────────┴──────────────────────────────────────────────────────┘
```

---

## Immediate Next Steps

1. **Complete MCP Server** (Sprint 3.1 in progress)
2. **Add orchestrator views to mycelial-dashboard**
3. **Create IaC module** for multi-cloud free tier
4. **Bridge chitchat ↔ libp2p** for unified membership
5. **Deploy first multi-cloud testnet**

---

## Quick Commands for Phase 2 (Local Multi-Node)

```bash
# Build container image
docker build -t univrs/orchestrator:dev .

# Start local cluster
docker-compose up -d

# Deploy orchestrator as its own workload (dogfood!)
docker exec orchestrator-bootstrap \
  curl -X POST localhost:8080/api/workloads \
  -H "Content-Type: application/json" \
  -d '{"name":"orchestrator-canary","image":"univrs/orchestrator:dev","replicas":2}'

# Watch the orchestrator orchestrate itself
docker logs -f orchestrator-bootstrap
```

---

*Strategy document for Univrs.io / RustOrchestration*
*Designed for progressive decentralization via Mycelial Economics*
