# Mycelial Network Integration Testing

This document describes the integration testing infrastructure for the Mycelial Network P2P layer and its integration with the ENR (Entropy-Nexus-Revival) economic primitives.

## Overview

The Mycelial Network is the P2P gossip layer that connects VUDO nodes. It integrates with the ENR economic module to enable:

- **Gradient Broadcasting**: Propagate resource availability across the network
- **Credit Synchronization**: Transfer credits between nodes with 2% entropy tax
- **Nexus Election**: Distributed leader election for hub nodes
- **Septal Gates**: Circuit breakers for isolating unhealthy nodes

## Test Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Container                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Isolated Bridge Network                 │    │
│  │                                                      │    │
│  │   ┌─────────┐   ┌─────────┐   ┌─────────┐          │    │
│  │   │  Node1  │───│  Node2  │───│  Node3  │          │    │
│  │   │ :20000  │   │ :20002  │   │ :20004  │          │    │
│  │   └─────────┘   └─────────┘   └─────────┘          │    │
│  │        │             │             │                │    │
│  │        └─────────────┴─────────────┘                │    │
│  │                Gossipsub Mesh                        │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Test Categories

### Phase 0 Gate Tests

These tests validate the ENR bridge integration meets Phase 0 requirements.

#### Gradient Tests (`gate_gradient.rs`)

| Test | Description | Assertion |
|------|-------------|-----------|
| `test_gradient_propagation_3_nodes` | 3-node cluster | Gradient reaches all nodes within 15s |
| `test_gradient_aggregation` | Aggregate multiple gradients | Network gradient reflects all sources |
| `test_gradient_freshness` | Prune stale gradients | Old gradients removed after 30s |

#### Credit Tests (`gate_credits.rs`)

| Test | Description | Assertion |
|------|-------------|-----------|
| `test_credit_transfer_with_tax` | Transfer 100 credits | Sender: 898, Receiver: 1100 (2% tax) |
| `test_multi_hop_transfer` | A→B→C transfers | Correct final balances |
| `test_concurrent_transfers` | Parallel transfers | No race conditions |
| `test_credit_exhaustion` | Over-balance transfer | Returns error |

#### Election Tests (`gate_election.rs`)

| Test | Description | Assertion |
|------|-------------|-----------|
| `test_nexus_election` | 3-node election | Winner elected within timeout |
| `test_election_convergence` | 5-node election | All nodes agree on winner |

## Running Tests

### Docker (Recommended)

Docker provides network isolation, eliminating interference from host network interfaces.

```bash
# Navigate to univrs-network
cd univrs-network

# Build the test image
docker compose -f docker-compose.test.yml build

# Run all integration tests
docker compose -f docker-compose.test.yml run --rm integration-tests

# Run specific test
docker compose -f docker-compose.test.yml run --rm integration-tests \
  cargo test --package mycelial-network --release --test gate_credits -- --ignored --nocapture

# Clean up volumes
docker compose -f docker-compose.test.yml down -v
```

### Local Execution

Tests are marked `#[ignore]` and may fail on WSL2 or hosts with Docker bridge interfaces.

```bash
# Run all gate tests (may fail due to network interference)
cargo test --package mycelial-network --test gate_gradient -- --ignored

# With debug logging
RUST_LOG=mycelial_network=debug cargo test --test gate_credits -- --ignored --nocapture
```

## TestCluster Helper

The `TestCluster` helper spawns multiple network nodes for integration testing:

```rust
use helpers::TestCluster;

// Spawn a 3-node cluster
let cluster = TestCluster::spawn(3).await?;

// Wait for mesh formation (each node sees at least 2 peers)
cluster.wait_for_mesh(2, 10).await?;

// Access individual nodes
let bridge = &cluster.node(0).enr_bridge;
let balance = bridge.local_balance().await;

// Transfer credits between nodes
bridge.transfer_credits(node2_id, Credits::new(100)).await?;

// Cleanup
cluster.shutdown().await;
```

### Features

- **Automatic port allocation**: Process-unique ports prevent conflicts
- **Direct bootstrap**: No mDNS, uses explicit peer addresses
- **Mesh waiting**: Configurable timeout for mesh formation
- **Full access**: `NetworkHandle` and `EnrBridge` exposed for each node

## Docker Configuration

### Dockerfile.integration

```dockerfile
FROM rust:latest

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config libssl-dev protobuf-compiler

# Copy all univrs-* workspace crates
COPY univrs-enr /workspace/univrs-enr
COPY univrs-identity /workspace/univrs-identity
COPY univrs-state /workspace/univrs-state
COPY univrs-network /workspace/univrs-network

WORKDIR /workspace/univrs-network
RUN cargo build --package mycelial-network --tests --release

CMD ["cargo", "test", "--package", "mycelial-network", "--release", \
     "--", "--ignored", "--nocapture", "--test-threads=1"]
```

### docker-compose.test.yml

```yaml
services:
  integration-tests:
    build:
      context: ..
      dockerfile: univrs-network/Dockerfile.integration
    network_mode: bridge
    environment:
      - RUST_LOG=info
      - RUST_BACKTRACE=1
    volumes:
      - cargo-registry:/usr/local/cargo/registry
      - cargo-git:/usr/local/cargo/git

volumes:
  cargo-registry:
  cargo-git:
```

## Credit Transfer Math

The ENR economic model applies a 2% entropy tax on all transfers:

```
Initial state:
  - Node A: 1000 credits
  - Node B: 1000 credits

Transfer 100 credits from A to B:
  - Tax: 100 × 0.02 = 2 credits (goes to revival pool)
  - Net transfer: 100 credits

Final state:
  - Node A: 1000 - 100 - 2 = 898 credits
  - Node B: 1000 + 100 = 1100 credits
```

## Gossipsub Topics

The ENR bridge uses dedicated gossipsub topics:

| Topic | Purpose |
|-------|---------|
| `enr/gradient/1.0` | Resource gradient broadcasts |
| `enr/credits/1.0` | Credit transfer messages |
| `enr/election/1.0` | Nexus election protocol |
| `enr/septal/1.0` | Septal gate (circuit breaker) messages |

## Troubleshooting

### Tests hang during mesh formation

- **Cause**: Stale peers from Docker/WSL2 virtual interfaces
- **Solution**: Run in Docker with `network_mode: bridge`

### Port conflicts

- **Cause**: Previous test run didn't clean up
- **Solution**: Use unique base ports per test via `PORT_COUNTER`

### mDNS discovery issues

- **Cause**: mDNS discovers peers outside test cluster
- **Solution**: Tests use direct bootstrap, mDNS disabled

## Related Documentation

- [ENR Economic Primitives](https://github.com/univrs/univrs-enr)
- [Mycelial Network](https://github.com/univrs/network)
- [VUDO Platform](./developer-guide.md)
