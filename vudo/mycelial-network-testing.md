# Mycelial Network Integration Testing

This document describes the integration testing infrastructure for the Mycelial Network P2P layer and its integration with the ENR (Entropy-Nexus-Revival) economic primitives.

## Overview

The Mycelial Network is the P2P gossip layer that connects VUDO nodes. It integrates with the ENR economic module to enable:

- **Gradient Broadcasting**: Propagate resource availability across the network
- **Credit Synchronization**: Transfer credits between nodes with 2% entropy tax
- **Nexus Election**: Distributed leader election for hub nodes
- **Septal Gates**: Circuit breakers for isolating unhealthy nodes

## Test Summary

| Test Suite | Tests | Status |
|------------|-------|--------|
| `gate_gradient.rs` | 2 | All passing |
| `gate_credits.rs` | 4 | All passing |
| `gate_election.rs` | 3 | All passing |
| **Total** | **9** | **All passing** |

## Test Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Container                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Isolated Bridge Network                 │    │
│  │                                                      │    │
│  │   ┌─────────┐   ┌─────────┐   ┌─────────┐          │    │
│  │   │  Node0  │───│  Node1  │   │  Node2  │          │    │
│  │   │  (hub)  │───│         │   │         │          │    │
│  │   └─────────┘   └─────────┘   └─────────┘          │    │
│  │        │             │             │                │    │
│  │        └─────────────┴─────────────┘                │    │
│  │              Star Bootstrap Topology                 │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Test Categories

### Phase 0 Gate Tests

These tests validate the ENR bridge integration meets Phase 0 requirements.

#### Gradient Tests (`gate_gradient.rs`)

| Test | Description | Assertion |
|------|-------------|-----------|
| `test_gradient_propagates_to_all_nodes` | 3-node cluster gradient propagation | Gradient reaches all nodes within 15s |
| `test_gradient_propagates_5_nodes` | 5-node cluster propagation | Gradient reaches all 5 nodes |

#### Credit Tests (`gate_credits.rs`)

| Test | Description | Assertion |
|------|-------------|-----------|
| `test_credit_transfer_with_tax` | Transfer 100 credits | Sender: 898, Receiver: 1100 (2% tax) |
| `test_self_transfer_rejected` | Self-transfer attempt | Returns error |
| `test_insufficient_balance_rejected` | Over-balance transfer | Returns error |
| `test_multiple_transfers` | Sequential transfers | Cumulative tax applied correctly |

#### Election Tests (`gate_election.rs`)

| Test | Description | Assertion |
|------|-------------|-----------|
| `test_election_announcement_propagates` | 5-node election announcement | All nodes see election in progress |
| `test_election_completes_with_winner` | 3-node election completion | Winner elected (may timeout in MVP) |
| `test_ineligible_node_cannot_win` | Low-uptime node stays Leaf | Ineligible nodes don't become candidates |

## Running Tests

### Quick Start

```bash
# Run all integration tests
cd univrs-network
cargo test --test gate_gradient --test gate_credits --test gate_election -- --ignored
```

### Docker (Recommended)

Docker provides network isolation, eliminating interference from host network interfaces.

```bash
# Navigate to univrs-network
cd univrs-network

# Build and run all integration tests
docker compose -f docker-compose.test.yml up --build

# Run in detached mode
docker compose -f docker-compose.test.yml up --build -d

# View logs
docker compose -f docker-compose.test.yml logs -f

# Run specific test
docker compose -f docker-compose.test.yml run --rm integration-tests \
  cargo test --package mycelial-network --release --test gate_credits -- --ignored --nocapture

# Clean up volumes
docker compose -f docker-compose.test.yml down -v
```

### Local Execution

Tests are marked `#[ignore]` and require careful network configuration on WSL2 or hosts with Docker bridge interfaces.

```bash
# Run all gate tests
cargo test --test gate_gradient -- --ignored

# With debug logging
RUST_LOG=mycelial_network=debug cargo test --test gate_credits -- --ignored --nocapture

# Single-threaded (avoids port conflicts)
cargo test -- --ignored --test-threads=1
```

## TestCluster Helper

The `TestCluster` helper spawns multiple network nodes for integration testing:

```rust
use helpers::TestCluster;

// Spawn a 3-node cluster
let cluster = TestCluster::spawn(3).await?;

// Wait for mesh formation (min 1 peer for star topology)
cluster.wait_for_mesh(1, 10).await?;

// Access individual nodes
let bridge = &cluster.node(0).enr_bridge;

// Transfer credits between nodes
bridge.transfer_credits(node1_id, Credits::new(100)).await?;

// Cleanup
cluster.shutdown().await;
```

### Features

- **Automatic port allocation**: Process-unique ports (20000-60000 range)
- **Direct bootstrap**: No mDNS, uses explicit peer addresses
- **Star topology**: Node 0 is hub, others connect to it
- **Address filtering**: Filters Docker/WSL bridge addresses
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
| `/vudo/enr/gradient/1.0.0` | Resource gradient broadcasts |
| `/vudo/enr/credits/1.0.0` | Credit transfer messages |
| `/vudo/enr/election/1.0.0` | Nexus election protocol |
| `/vudo/enr/septal/1.0.0` | Septal gate (circuit breaker) messages |

## Network Address Filtering

The network service filters non-routable addresses to avoid connection issues:

| Address Type | Example | Action |
|--------------|---------|--------|
| Localhost | 127.0.0.1 | Allowed |
| Docker bridge | 172.17.x.x | Filtered |
| WSL adapter | 172.28.x.x, 172.29.x.x | Filtered |
| Link-local | 10.255.255.254 | Filtered |

## Troubleshooting

### Mesh Formation Timeout

- **Symptom**: Tests fail with "Mesh formation timeout"
- **Causes**: Port conflicts, Docker/WSL network interfaces
- **Solution**: Run in Docker with `network_mode: bridge`

### Tests hang during mesh formation

- **Cause**: Stale peers from Docker/WSL2 virtual interfaces
- **Solution**: Run in Docker or check port availability

### Port conflicts

- **Cause**: Previous test run didn't clean up
- **Solution**: Tests use `PORT_COUNTER` for unique ports; run single-threaded

### Election Tests Timing Out

- **Symptom**: `test_election_completes_with_winner` times out after 30s
- **Note**: This is expected behavior for MVP

## CI/CD Integration

For GitHub Actions:

```yaml
integration-tests:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Run integration tests
      run: |
        docker compose -f docker-compose.test.yml up --build --abort-on-container-exit
      working-directory: ./univrs-network
```

## Related Documentation

- [ENR Economic Primitives](https://github.com/univrs/univrs-enr)
- [Mycelial Network](https://github.com/univrs/network)
- [Developer Guide](./developer-guide.md)
- [Phase 2 Complete](./PHASE2_COMPLETE.md)
