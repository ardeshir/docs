# Developer Tooling Ecosystem

## Univrs.io SDK, CLI, and API Architecture

**Version**: 0.1.0-draft  
**Date**: December 17, 2025  
**Status**: Design Document

---

Building UI/UX for the Mycelial Dashboard, with a coherent developer tooling strategy. 
This document defines the layered approach:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DEVELOPER TOOLING LAYERS                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Layer 4: DASHBOARD (React Web UI)                                     │
│            └── Visual management, monitoring, debugging                 │
│                                                                         │
│   Layer 3: META-APPS & OVERLAYS                                         │
│            └── Templates, generators, IDE plugins                       │
│                                                                         │
│   Layer 2: CLI TOOLS                                                    │
│            ├── ui     (end-user interface)                              │
│            └── uictl  (operator control)                                │
│                                                                         │
│   Layer 1: SDK LIBRARIES                                                │
│            ├── univrs-sdk-rust   (native)                               │
│            ├── univrs-sdk-ts     (TypeScript/Node)                      │
│            ├── univrs-sdk-python (Python)                               │
│            └── univrs-sdk-go     (Go)                                   │
│                                                                         │
│   Layer 0: PROTOCOL & API                                               │
│            ├── MCP (Model Context Protocol) - AI-native                 │
│            ├── REST/HTTP - Traditional integration                      │
│            ├── gRPC - High-performance (future)                         │
│            └── WebSocket - Real-time events                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part I: Protocol Layer (Layer 0)

### 1.1 API Protocols

| Protocol | Use Case | Status |
|----------|----------|--------|
| **MCP** | AI agent integration | ✅ Implemented |
| **REST/HTTP** | Traditional clients, web apps | 📋 Design |
| **WebSocket** | Real-time events, dashboard | 📋 Design |
| **gRPC** | High-performance inter-service | 🔮 Future |

### 1.2 REST API Design

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         REST API ENDPOINTS                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  WORKLOADS                                                              │
│  ─────────────────────────────────────────────────────────────────────  │
│  GET    /api/v1/workloads              List all workloads               │
│  POST   /api/v1/workloads              Create workload                  │
│  GET    /api/v1/workloads/:id          Get workload details             │
│  PUT    /api/v1/workloads/:id          Update workload                  │
│  DELETE /api/v1/workloads/:id          Delete workload                  │
│  POST   /api/v1/workloads/:id/scale    Scale replicas                   │
│  GET    /api/v1/workloads/:id/logs     Stream logs                      │
│  GET    /api/v1/workloads/:id/events   Get events                       │
│                                                                         │
│  NODES                                                                  │
│  ─────────────────────────────────────────────────────────────────────  │
│  GET    /api/v1/nodes                  List all nodes                   │
│  GET    /api/v1/nodes/:id              Get node details                 │
│  POST   /api/v1/nodes/:id/cordon       Mark node unschedulable          │
│  POST   /api/v1/nodes/:id/drain        Evacuate workloads               │
│  PUT    /api/v1/nodes/:id/labels       Update labels                    │
│                                                                         │
│  CLUSTER                                                                │
│  ─────────────────────────────────────────────────────────────────────  │
│  GET    /api/v1/cluster/status         Overall cluster status           │
│  GET    /api/v1/cluster/events         Cluster event stream             │
│  GET    /api/v1/cluster/metrics        Aggregated metrics               │
│                                                                         │
│  MYCELIAL (Credits & Reputation)                                        │
│  ─────────────────────────────────────────────────────────────────────  │
│  GET    /api/v1/credits/balance        Your credit balance              │
│  GET    /api/v1/credits/history        Transaction history              │
│  POST   /api/v1/credits/transfer       Transfer credits                 │
│  GET    /api/v1/reputation/:id         Get reputation score             │
│                                                                         │
│  IDENTITY & POLICY                                                      │
│  ─────────────────────────────────────────────────────────────────────  │
│  GET    /api/v1/identity               Your identity info               │
│  GET    /api/v1/policy                 Your current policy              │
│  PUT    /api/v1/policy                 Update policy                    │
│                                                                         │
│  OBSERVABILITY                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│  GET    /health                        Health check                     │
│  GET    /ready                         Readiness probe                  │
│  GET    /live                          Liveness probe                   │
│  GET    /metrics                       Prometheus metrics               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 WebSocket Events

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       WEBSOCKET EVENT STREAM                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Connection: ws://localhost:9090/api/v1/events                          │
│                                                                         │
│  SUBSCRIPTION                                                           │
│  ─────────────────────────────────────────────────────────────────────  │
│  → { "subscribe": ["workloads", "nodes", "cluster"] }                   │
│  ← { "subscribed": ["workloads", "nodes", "cluster"] }                  │
│                                                                         │
│  EVENT TYPES                                                            │
│  ─────────────────────────────────────────────────────────────────────  │
│  Workload Events:                                                       │
│  ← { "type": "workload.created", "data": { ... } }                      │
│  ← { "type": "workload.scaled", "data": { ... } }                       │
│  ← { "type": "workload.deleted", "data": { ... } }                      │
│  ← { "type": "workload.instance.started", "data": { ... } }             │
│  ← { "type": "workload.instance.failed", "data": { ... } }              │
│                                                                         │
│  Node Events:                                                           │
│  ← { "type": "node.joined", "data": { ... } }                           │
│  ← { "type": "node.left", "data": { ... } }                             │
│  ← { "type": "node.health_changed", "data": { ... } }                   │
│                                                                         │
│  Cluster Events:                                                        │
│  ← { "type": "cluster.leader_elected", "data": { ... } }                │
│  ← { "type": "cluster.partition_detected", "data": { ... } }            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.4 Authentication Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      AUTHENTICATION FLOW                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  USER'S DEVICE                          ORCHESTRATOR                    │
│  ─────────────────                      ────────────                    │
│                                                                         │
│  1. User has Ed25519 keypair                                            │
│     (generated by `ui init`)                                            │
│                                                                         │
│  2. Request includes signed challenge                                   │
│     ┌─────────────────────────────────────────────────────────────┐     │
│     │ POST /api/v1/workloads                                      │     │
│     │ Authorization: Univrs <public_key>:<signature>:<timestamp>  │     │
│     │                                                             │     │
│     │ signature = sign(private_key, sha256(method + path +        │     │
│     │                                       timestamp + body))    │     │
│     └─────────────────────────────────────────────────────────────┘     │
│                                                                         │
│  3. Server verifies:                                                    │
│     - Signature matches public key                                      │
│     - Timestamp within acceptable window (±5 minutes)                   │
│     - Public key is authorized (per policy)                             │
│                                                                         │
│  NO TOKENS, NO SESSIONS, NO CENTRAL AUTH SERVER                         │
│  Identity is cryptographic, verification is local                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part II: SDK Libraries (Layer 1)

### 2.1 SDK Design Principles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       SDK DESIGN PRINCIPLES                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. IDENTITY-FIRST                                                      │
│     SDK manages keypairs, signing, identity lifecycle                   │
│     User never handles raw crypto operations                            │
│                                                                         │
│  2. POLICY-AWARE                                                        │
│     SDK enforces user's policy locally before API calls                 │
│     Fail fast if action would violate policy                            │
│                                                                         │
│  3. OFFLINE-CAPABLE                                                     │
│     SDK caches state, can operate read-only offline                     │
│     Queue writes for sync when connected                                │
│                                                                         │
│  4. TYPE-SAFE                                                           │
│     Strong typing in all languages                                      │
│     Generated from shared schema (OpenAPI or similar)                   │
│                                                                         │
│  5. ASYNC-NATIVE                                                        │
│     All network operations are async                                    │
│     Event streams via callbacks or async iterators                      │
│                                                                         │
│  6. MINIMAL DEPENDENCIES                                                │
│     Core SDK has few dependencies                                       │
│     Optional features for specific use cases                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Rust SDK (Native)

```rust
// univrs-sdk-rust

use univrs_sdk::{Client, Identity, Workload, WorkloadSpec};

#[tokio::main]
async fn main() -> Result<()> {
    // Load identity from default config path
    let identity = Identity::load_default()?;
    
    // Create client (auto-discovers local or network nodes)
    let client = Client::builder()
        .identity(identity)
        .discover()  // Auto-discover via mDNS or configured bootstrap
        .await?
        .build()?;
    
    // Deploy a workload
    let workload = client.workloads().create(WorkloadSpec {
        name: "my-app".into(),
        image: "myregistry/myapp:v1".into(),
        replicas: 3,
        resources: Resources {
            cpu: "100m".parse()?,
            memory: "128Mi".parse()?,
        },
        ..Default::default()
    }).await?;
    
    println!("Created workload: {}", workload.id);
    
    // Stream events
    let mut events = client.events().subscribe(["workloads"]).await?;
    while let Some(event) = events.next().await {
        println!("Event: {:?}", event);
    }
    
    Ok(())
}
```

**Crate structure:**
```
univrs-sdk-rust/
├── Cargo.toml
├── src/
│   ├── lib.rs
│   ├── client.rs         # Client builder, connection management
│   ├── identity.rs       # Keypair management, signing
│   ├── policy.rs         # Local policy enforcement
│   ├── workloads.rs      # Workload operations
│   ├── nodes.rs          # Node operations
│   ├── credits.rs        # Credit operations
│   ├── events.rs         # Event streaming
│   └── error.rs          # Error types
└── examples/
    ├── deploy.rs
    ├── scale.rs
    └── events.rs
```

### 2.3 TypeScript SDK

```typescript
// univrs-sdk-ts

import { Client, Identity, WorkloadSpec } from '@univrs/sdk';

async function main() {
  // Load identity
  const identity = await Identity.loadDefault();
  
  // Create client
  const client = await Client.create({
    identity,
    discover: true,
  });
  
  // Deploy workload
  const workload = await client.workloads.create({
    name: 'my-app',
    image: 'myregistry/myapp:v1',
    replicas: 3,
    resources: {
      cpu: '100m',
      memory: '128Mi',
    },
  });
  
  console.log(`Created workload: ${workload.id}`);
  
  // Subscribe to events
  const events = client.events.subscribe(['workloads']);
  for await (const event of events) {
    console.log('Event:', event);
  }
}
```

**Package structure:**
```
univrs-sdk-ts/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts
│   ├── client.ts
│   ├── identity.ts
│   ├── policy.ts
│   ├── workloads.ts
│   ├── nodes.ts
│   ├── credits.ts
│   ├── events.ts
│   └── types.ts          # Generated from OpenAPI
└── examples/
    ├── deploy.ts
    └── events.ts
```

### 2.4 Python SDK

```python
# univrs-sdk-python

from univrs import Client, Identity, WorkloadSpec
import asyncio

async def main():
    # Load identity
    identity = Identity.load_default()
    
    # Create client
    client = await Client.create(
        identity=identity,
        discover=True
    )
    
    # Deploy workload
    workload = await client.workloads.create(WorkloadSpec(
        name="my-app",
        image="myregistry/myapp:v1",
        replicas=3,
        resources={"cpu": "100m", "memory": "128Mi"}
    ))
    
    print(f"Created workload: {workload.id}")
    
    # Subscribe to events
    async for event in client.events.subscribe(["workloads"]):
        print(f"Event: {event}")

asyncio.run(main())
```

---

## Part III: CLI Tools (Layer 2)

### 3.1 Tool Separation Philosophy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CLI TOOL SEPARATION                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ui (univrs interface)                                                  │
│  ═══════════════════════════════════════════════════════════════════    │
│  WHO:    End users, developers, anyone deploying workloads              │
│  WHAT:   Day-to-day operations                                          │
│  SCOPE:  Their own workloads, their own identity                        │
│                                                                         │
│  Commands:                                                              │
│  - ui init              Create identity                                 │
│  - ui deploy            Deploy workload                                 │
│  - ui status            View workloads                                  │
│  - ui logs              Stream logs                                     │
│  - ui scale             Scale replicas                                  │
│  - ui credits balance   Check credits                                   │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  uictl (univrs control)                                                 │
│  ═══════════════════════════════════════════════════════════════════    │
│  WHO:    Node operators, cluster admins, SREs                           │
│  WHAT:   Node management, cluster operations, debugging                 │
│  SCOPE:  Nodes they operate, cluster-wide visibility                    │
│                                                                         │
│  Commands:                                                              │
│  - uictl node init      Initialize this machine as a node               │
│  - uictl node register  Register with network                           │
│  - uictl node drain     Evacuate workloads                              │
│  - uictl cluster status Cluster overview                                │
│  - uictl debug gossip   Debug gossip protocol                           │
│  - uictl debug state    Inspect state store                             │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  WHY SEPARATE?                                                          │
│  - Clear mental model: users vs operators                               │
│  - Different security contexts                                          │
│  - Different installation paths                                         │
│  - Avoids accidental cluster operations                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 ui Command Reference

```
ui - univrs interface (universal interface)
    The user-facing CLI for deploying and managing workloads.

USAGE:
    ui <COMMAND> [OPTIONS]

COMMANDS:
    Identity Management
    ───────────────────────────────────────────────────────────────────
    init                 Create a new identity (keypair)
    identity show        Display your public identity
    identity export      Export identity for backup (encrypted)
    identity import      Import identity from backup
    
    Policy Management
    ───────────────────────────────────────────────────────────────────
    policy show          Display current policy
    policy edit          Edit policy in $EDITOR
    policy trust         Add operator to trust list
    policy deny          Add operator to deny list
    
    Workload Operations
    ───────────────────────────────────────────────────────────────────
    deploy <spec>        Deploy a workload from file or stdin
    status [name]        Show workload status (all or specific)
    logs <name>          Stream workload logs
    scale <name> <n>     Scale workload to n replicas
    delete <name>        Delete a workload
    describe <name>      Detailed workload information
    
    Credit Operations
    ───────────────────────────────────────────────────────────────────
    credits balance      Show your credit balance
    credits history      Show transaction history
    credits send         Transfer credits to another user
    
    Network
    ───────────────────────────────────────────────────────────────────
    network status       Show network connectivity
    network peers        List connected peers
    
    Meta
    ───────────────────────────────────────────────────────────────────
    version              Show version information
    config               Show configuration paths
    completion           Generate shell completions

GLOBAL OPTIONS:
    -o, --output <format>    Output format: human (default), json, yaml
    -v, --verbose            Increase verbosity (-vv for debug)
    -q, --quiet              Suppress non-error output
    --config <path>          Use alternate config file
    --identity <path>        Use alternate identity file

EXAMPLES:
    # First-time setup
    ui init
    
    # Deploy from file
    ui deploy ./my-app.yaml
    
    # Deploy inline
    echo '{"name":"nginx","image":"nginx:latest","replicas":2}' | ui deploy -
    
    # Watch status
    ui status --watch
    
    # Scale up
    ui scale my-app 5
    
    # Check credits
    ui credits balance
```

### 3.3 uictl Command Reference

```
uictl - univrs control
    The operator CLI for managing nodes and cluster operations.

USAGE:
    uictl <COMMAND> [OPTIONS]

COMMANDS:
    Node Operations
    ───────────────────────────────────────────────────────────────────
    node init            Initialize this machine as a univrs node
    node register        Register node with the network
    node status          Show this node's status
    node config          Show/edit node configuration
    node withdraw        Gracefully remove node from network
    
    node cordon          Mark node as unschedulable
    node uncordon        Mark node as schedulable
    node drain           Evacuate all workloads from node
    node label           Add/remove node labels
    
    Cluster Operations
    ───────────────────────────────────────────────────────────────────
    cluster status       Show cluster overview
    cluster nodes        List all nodes in cluster
    cluster workloads    List all workloads in cluster
    cluster events       Stream cluster events
    cluster metrics      Show cluster metrics summary
    
    Debug Operations
    ───────────────────────────────────────────────────────────────────
    debug gossip         Show gossip protocol state
    debug state          Inspect state store contents
    debug reconcile      Trigger manual reconciliation
    debug network        Network diagnostics
    debug logs           Advanced log filtering
    
    Operator Identity
    ───────────────────────────────────────────────────────────────────
    operator init        Create operator identity
    operator show        Show operator identity
    operator reputation  Show your reputation score

GLOBAL OPTIONS:
    -o, --output <format>    Output format: human (default), json, yaml
    -v, --verbose            Increase verbosity
    --node <address>         Connect to specific node
    --context <name>         Use named context (for multi-cluster)

EXAMPLES:
    # Initialize a new node
    uictl node init --resources "cpu=4,memory=8Gi,disk=100Gi"
    
    # Register with network
    uictl node register --bootstrap dns/bootstrap.univrs.io/udp/9000
    
    # Drain for maintenance
    uictl node drain --timeout 5m
    
    # Debug gossip membership
    uictl debug gossip --verbose
    
    # Watch cluster events
    uictl cluster events --follow
```

---

## Part IV: Meta-Apps & Overlays (Layer 3)

### 4.1 Developer Force Multipliers

```
┌────────────────────────────────────────────────────────────────────────┐
│                    META-APP & OVERLAY ECOSYSTEM                        │
├─────────────────────────────────────────────────────────               ┤
│                                                                        │
│  TEMPLATE GENERATORS                                                   │
│  ═══════════════════════════════════════════════════════════════════   │
│                                                                        │
│  ui create <template>                                                  │
│  ├── ui create web        → React/Vue/Svelte web app                   │
│  ├── ui create api        → REST API service                           │
│  ├── ui create worker     → Background job processor                   │
│  ├── ui create ml         → ML model serving                           │
│  └── ui create custom     → Interactive builder                        │
│                                                                        │
│  Each template includes:                                               │
│  - Dockerfile optimized for univrs                                     │
│  - univrs.yaml workload spec                                           │
│  - .github/workflows for CI (optional)                                 │
│  - README with deployment instructions                                 │
│                                                                        │
│  ───────────────────────────────────────────────────────────────────── │
│                                                                        │
│  IDE EXTENSIONS                                                        │
│  ══════════════════════════════════════════════════════                │
│                                                                        │
│  VS Code Extension: univrs-vscode                                      │
│  ├── Syntax highlighting for univrs.yaml                               │
│  ├── IntelliSense for workload specs                                   │
│  ├── Deploy/scale/logs from editor                                   
   ├── Status bar showing workload health                                │
│  └── Integrated terminal with ui CLI                                   │
│                                                                        │
│  JetBrains Plugin: univrs-intellij                                     │
│  └── Same features for IntelliJ/GoLand/PyCharm                         │
│                                                                        │
│  ─────────────────────────────────────────────────────────────────     │
│                                                                        │
│  CI/CD INTEGRATIONS                                                    │
│  ═════════════════════════════════════════════════════                 │
│                                                                        │
│  GitHub Actions: univrs/deploy-action                                  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ - uses: univrs/deploy-action@v1                                 │   │
│  │   with:                                                         │   │
│  │     workload: ./univrs.yaml                                     │   │
│  │     identity: ${{ secrets.UNIVRS_IDENTITY }}                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  GitLab CI: un-gitlab                                              │
│  CircleCI: univrs-circleci-orb                                         │
│                                                                          │
│  ───────────────────────────────────────────────────────────────────── │
    DEVELOPMENT PROXY                                                    │
│  ═══════════════════════════════════════════════════════════════════   │
│                                                                        │
│  ui dev                                                                │
│  └── Local development proxy that:                                     │
│      - Runs your app locally                                           │
│      - Routes traffic from univrs network to local                     │
│      - Live reload on file changes                                     │
│      - Mimics production environment                                   │
│                                                                        │
│  ───────────────────────────────────────────────────────               │
│                                                                        │
│  OBSERVABILITY OVERLAY                                                 │
│  ═══════════════════════════════════════════════════════════════════   │
│   bserve                                                               │
│  └── TUI (terminal UI) for:                                            │
│      - Real-time log aggregation                                       │
│      - Metrics visualization (sparklines)                              │
│      - Workload topology view                                          │
│      - Interactive debugging                                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Template System

```yaml
# ~/.config/univrs/templates/web/univrs.yaml.tmpl
name: {{ .name }}
image: {{ .registry }}/{{ .name }}:{{ .tag | default "latest" }}
replicas: {{ .replicas | default 2 }}

resources:
  cpu: {{ .cpu | default "100m" }}
  m{ .memory | default "128Mi" }}

env:
  - name: NODE_ENV
    value: production
{{- range .env }}
  - name: {{ .name }}
    value: {{ .value }}
{{- end }}

health:
  http:
    path: /health
    port: {{ .port | default 3000 }}

routing:
  - match:
      prefix: /
    port: {{ .port | default 3000 }}
```

```bash
# Create from template
ui create web --name my-app --port 8080

# Interactive mode
ui create
# ? Select template: web
# ? Application name: my-app
# ? Port: 8080
# ? Initial replicas: 3
# Created ./my-app/
#   - Dockerfile
#   - univrs.yaml
#   - README.md
```

### 4.3 Development Proxy (ui dev)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ui dev - DEVELOPMENT PROXY                         │
├─────────────────────────────────                ────────────────────────┤
│                                                                         │
│   LOCAL MACHINE                         UNIVRS NETWORK                  │
│   ─────────────────                     ──────────────                  │
│                                                                         │
│   ┌──────────────     ─┐               ┌─────────────────┐              │
│   │   Your App      │                  │   Other Apps    │              │
│   │   (localhost)   │◄────────────────►│   (deployed)    │              │
│   └────────┬────────┘    Proxy Tunnel  └─────────────────┘              │
│            │                                   │                        │
│            ▼                                   │                        │
│   ┌─────────────────┐                          │                        │
│   │   ui dev proxy  │◄─────────────────────────┘                        │
│   │   (port 4000)   │   Traffic from network                            │
│   └──────────â   routed to local app                                │
│                                                                         │
│   FEATURES:                                                             │
│   - Hot reload on file changes                                          │
│   - Automatic HTTPS termination                                         │
│   - Request logging                                                     │
│   - Environment variable injection                                      │
│   - Mock external services                                              │
│                                                                         │
│   USAGE:                                                                │
│   $ ui dev --port 3000                                                  │
│   ✓ Proxy started at https://my-app.dev.univrs.local                    │
│   ✓ Forwarding to localhost:3000                                        │
│   ✓ Wating for file changes...                                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.4 Observability TUI (ui observe)

```
┌─────────────────────────────────────────────────────────────────┐
│  ui observe - Univrs Workload Monitor                  [q]uit [h]elp    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  WORKLOAD                             │  NODES                         │
│  ─────────────────────────────────────┼────────────────────────────────│
│  ● my-app          3/3  ██████ 45%    │  ● node-1   healthy  cpu: 23%  │
│  ● api-gateway     2/2  ████   32%    │  ● node-2   healthy  cpu: 45%  │
│  ● background-job  1/1  ██     18%       ● node-3   healthy  cpu: 12%  │
│  ○ ml-model        0/1  ░░░░░░ err    │                                 │
│                                       │                                 │
├───────────────────────────────────────┴─────────────────────────────────┤
│  LOGS [my-app] [f]ilt─────────────────────────────────────────────────────────────────────────┤
│  12:34:56 INFO  Request received: GET /api/users                        │
│  12:34:56 INFO  Response sent: 200 OK (23ms)                            │
│  12:34:57 INFO  Request received: POST /api/orders                      │
│  12:34:57 DEBUG Database query executed (5ms)                           │
│  12:34:57 INFO  Response sent: 201 Created (45ms)                       │
│  12:34:58 WARN  Rate limit approaching for user_123                     │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
├────────────────────────────────────────────────────────┤
│  EVENTS                                                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  12:34:50  workload.scaled       my-app 2→3 replicas                    │
│  12:33:22  node.joined           node-3 joined cluster                  │
│  12:30:00  workload.deployed     api-gateway v1.2.3                     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part V: Dashboard Integration (Layer 4)

### 5.1 How SDK/CLI/API Feed the Dashboard

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DASHBOARD DATA FLOW                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                      MYCELIAL DASHBOARD (React)                         │
│                              │                                          │
│         ┌────────────────────┼────────────────────┐                     │
│         │                    │                    │                     │
│         ▼                    ▼                    ▼                     │
â           ─────┐     ┌─────────────┐     ┌─────────────┐                │
│  │ REST API    │     │  WebSocket  │     │   MCP       │                │
│  │ (queries)   │     │  (events)   │     │ (AI chat)   │                │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                │
│         │                                       │                       │
│         └───────────────────┴───────────────────┘                       │
│                             │                                           │
│                             ▼                                           │
│                   ┌─────────────────┐                                   │
│                   │   ORCHESTRATOR  │                                   │
│                   │   (Rust backend)│                                   │
│                   └─────────────────┘                                   │
│                                                                         │
│  DASHBOARD VIEWS (from existing mycelial-dashboard + new):              │
│  ─────────────────────────────────────────────────────────────          │
│                                                                         │
│  Existing (mycelial-dashboard):                                         │
│  ├── Network Graph (P2P peers)                                          │
│  ├── Reputation Board                                                   │
│  └── Credit Network                                                     │
│                                                                         │
│  New (orchestrator views):                                              │
│  ├── Workload List                                                      │
│  ├── Node Status                                                        │
│  ├── Deployment Wizard                                                  │
│  ├── Log Viewer                                                         │
   ├── Metrics Dashboard                                                  │
│  └── AI Console (MCP chat interface)                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Before Building Dashboard these foundation pieces complete:

| Layer | Component | Status | Blocks Dashboard |
|-------|-----------|--------|------------------|
| 0 | MCP Server | ✅ Done | No |
| 0 | REST API | 📋 Design | Yes - queries |
| 0 | WebSocket | 📋 Design | Yes - real-time |
| 1 | SDK (Rust) | 📋 Design | No |
| 1 | SDK (TypeScript) | 📋 Design | Yes - dashboard uses |
| 2 | ui CLI | 📋 Design | No |
| 2 | uictl CLI | 📋 Design | No |

**Recommendation**: Implement REST API + WebSocket + TypeScript SDK befviews.

---

## Part VI: Implementation Roadmap

### 6.1 Phase 1: API & SDK Foundation

```bash
# Task 1: REST API endpoints
npx claude-flow@alpha hive-mind spawn "Add REST API to orchestrator_core with axum: workloads CRUD, nodes list, cluster status" \
  --namespace rust-orch-rest \
  --agents architect,coder,coder,tester \
  --claude

# Task 2: WebSocket event stream
npx claude-flow@alpha hive-mind spawn "Add WebSocket event streaming to orchestrator: subscribe to workload/node/cluster events" \
  --namespace rust-orch-websocket \
  --agents architect,coder,tester \
  --claude

# Task 3: TypeScript SDK
npx claude-flow@alpha hive-mind spawn "Create univrs-sdk-ts TypeScript SDK with REST client, WebSocket events, identity management" \
  --namespace sdk-typescript \
  --agents architect,coder,coder,tester \
  --claude
```

### 6.2 Phase 2: CLI Tools

```bash
# Task 4: ui CLI (depends on user_config, currently in progress)
npx claude-flow@alpha hive-mind spawn "Create ui CLI with clap: init, deploy, status, logs, scale commands" \
  --namespace rust-orch-cli \
  --agents architect,coder,tester \
  --claude

# Task 5: uictl CLI
npx claude-flow@alpha hive-mind spawn "Create uictl CLI: node init/register/drain, cluster status, debug commands" \
  --namespace rust-orch-uictl \
  --agents architect,coder,tester \
  --claude
```

### 6.3 Phase 3: Meta-Apps & Dashboard

```bash
# Task 6: Template system
# Task 7: Dashboard orchestrator views
# Task 8: IDE extensions
```

---

## Summary: Developer Experience Priority

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DEVELOPER EXPERIENCE PRIORITY                        │
├─────────────────────────────────────────────────────────────────---     │
│  IMMEDIATE (This Week)                                                  │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. ✅ Container Guide (this document)                                  │
│  2. ⏳ user_config crate (in progress via claude-flow)                  │
│  3. 📋 REST API endpoints                                               │
│                                                                         │
│  SHORT TERM (Next 2 Weeks)                                              │
│  ─────────────────────────────────────────────────────────────────────  │
│  4. WebSocket event streaming                                           │
│  5. ui CLI (basic commands)                                             │
│  6. TypeScript SDK                                                      │
│                                                                         │
│  MEDIUM TERM (Month)                                                    │
│  ─────────────────────────────────────────────────────────────          │
│  7. uictl CLI                                                           │
│  8. Dashboard orchestrator views                                        │
│  9. Template system                                                     │
│                                                                         │
│  LONGER TERM                                                            │
│  ─────────────────────────────────────────────────────────              │
│  10. IDE extensions                                                     │
│  11. CI/CD integrations                                                 │
│  12. Development proxy (ui dev)                                         │
│  13. Observability TUI (ui observe)                                     │
│           ──────────────────────────────────────────────────────────────┘
```

---

*Developer Tooling Ecosystem v0.1.0-draft*
*Univrs.io - Building the developer experience layer by layer*
