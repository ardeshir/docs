# VUDO Developer Guide

> Complete guide for developing, signing, and deploying Spirit packages on the VUDO platform.

---

## Quick Links

| Guide | Description |
|-------|-------------|
| [Platform Overview](#platform-overview) | Architecture and core concepts |
| [Spirit Runtime](#spirit-runtime) | Package management system |
| [Manifest Format](#manifest-format) | Package metadata specification |
| [Cryptographic Signing](#cryptographic-signing) | Ed25519 signatures |
| [Local Registry](#local-registry) | Installing and managing Spirits |

---

## Platform Overview

VUDO is a secure WebAssembly execution platform with two main crates:

### vudo_vm
The sandboxed WASM runtime providing:
- Memory isolation
- Fuel-based CPU metering
- Capability enforcement
- Host function linking

### spirit_runtime
Package management providing:
- Manifest parsing (TOML/JSON)
- Ed25519 signing
- Local registry storage
- Semantic versioning

```
┌─────────────────────────────────────────────────────────┐
│                    VUDO Platform                         │
├──────────────────────┬──────────────────────────────────┤
│      vudo_vm         │        spirit_runtime            │
│  ┌────────────────┐  │  ┌────────────────────────────┐  │
│  │ Sandbox        │  │  │ Manifest + Signature       │  │
│  │ Linker         │  │  │ Registry + Versioning      │  │
│  │ Capabilities   │  │  │ Dependencies + Pricing     │  │
│  │ Fuel Metering  │  │  │                            │  │
│  └────────────────┘  │  └────────────────────────────┘  │
└──────────────────────┴──────────────────────────────────┘
```

---

## Spirit Runtime

### Installation

```toml
[dependencies]
spirit_runtime = { path = "path/to/spirit_runtime" }
```

### Quick Start

```rust
use spirit_runtime::{
    Manifest, ManifestBuilder, Capability, SemVer,
    KeyPair, LocalRegistry, Registry,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Generate keypair
    let keypair = KeyPair::generate();

    // 2. Create manifest
    let mut manifest = ManifestBuilder::new(
        "my-spirit",
        SemVer::new(1, 0, 0),
        keypair.verifying_key().to_hex(),
    )
    .description("My first Spirit")
    .capability(Capability::SensorTime)
    .build();

    // 3. Sign manifest
    let signature = manifest.sign(&keypair.signing_key().0)?;
    manifest.signature = Some(signature);

    // 4. Install to registry
    let mut registry = LocalRegistry::new();
    registry.init().await?;
    registry.install("./my-spirit/").await?;

    Ok(())
}
```

---

## Manifest Format

### TOML Example

```toml
name = "example-spirit"
author = "ed25519-public-key-64-hex-chars"
description = "Example Spirit package"
license = "MIT"

[version]
major = 1
minor = 0
patch = 0

capabilities = [
    "sensor_time",
    "actuator_log",
    "storage_read",
]

[dependencies]
utils = { version = "^1.0" }
local-lib = { path = "../local-lib" }

[pricing]
base_cost = 100
per_fuel_cost = 1

signature = "ed25519-signature-128-hex-chars"
```

### Available Capabilities

| Category | Capability | Description |
|----------|------------|-------------|
| **Network** | `network_listen` | Accept connections |
| | `network_connect` | Outgoing connections |
| | `network_broadcast` | Multicast |
| **Storage** | `storage_read` | Read storage |
| | `storage_write` | Write storage |
| | `storage_delete` | Delete from storage |
| **Compute** | `spawn_sandbox` | Child sandboxes |
| | `cross_sandbox_call` | Cross-sandbox calls |
| **Sensor** | `sensor_time` | Current time |
| | `sensor_random` | Random numbers |
| | `sensor_environment` | Environment vars |
| **Actuator** | `actuator_log` | Log output |
| | `actuator_notify` | Notifications |
| | `actuator_credit` | Billing |

### Version Constraints

```toml
[dependencies]
dep1 = { version = "^1.0" }      # >=1.0.0, <2.0.0
dep2 = { version = "~1.2" }      # >=1.2.0, <1.3.0
dep3 = { version = ">=1.0" }     # Minimum version
dep4 = { version = "*" }         # Any version
```

---

## Cryptographic Signing

### Key Generation

```rust
use spirit_runtime::signature::{KeyPair, SigningKey};

// Generate new keypair
let keypair = KeyPair::generate();
let public_key = keypair.verifying_key().to_hex();
let private_key = keypair.signing_key().to_hex();

// Save private key securely
std::fs::write("signing_key.secret", &private_key)?;
```

### Signing Manifests

```rust
use spirit_runtime::Manifest;

let mut manifest = Manifest::from_file("manifest.toml")?;

// Sign with private key
let signature = manifest.sign(&signing_key)?;
manifest.signature = Some(signature);

// Save signed manifest
manifest.to_file("manifest.toml")?;
```

### Verification

```rust
let manifest = Manifest::from_file("manifest.toml")?;

// Validate structure
manifest.validate()?;

// Verify signature
manifest.verify()?;
```

### Security Notes

- Private keys are 32 bytes (64 hex characters)
- Signatures are 64 bytes (128 hex characters)
- Public keys are 32 bytes (64 hex characters)
- Never commit private keys to version control

---

## Local Registry

### Directory Structure

```
~/.vudo/registry/
├── index.json           # Registry metadata
├── spirits/             # Installed packages
│   ├── my-spirit/
│   │   ├── 1.0.0/
│   │   │   ├── manifest.json
│   │   │   └── spirit.wasm
│   │   └── latest -> 1.0.0/
│   └── ...
└── cache/               # Downloaded packages
```

### Basic Operations

```rust
use spirit_runtime::registry::{LocalRegistry, Registry};

let mut registry = LocalRegistry::new();
registry.init().await?;

// Install
registry.install("./my-spirit/").await?;

// Get latest
let spirit = registry.get("my-spirit").await?;

// Get specific version
let spirit = registry.get_version("my-spirit", "1.0.0").await?;

// Get WASM bytes
let wasm = registry.get_wasm("my-spirit", None).await?;

// Uninstall
registry.uninstall("my-spirit").await?;
```

### Searching

```rust
use spirit_runtime::registry::SpiritQuery;

let query = SpiritQuery::new()
    .with_name("network")
    .with_capability("network_connect");

let results = registry.search(&query).await?;
```

---

## Spirit Package Structure

A Spirit package directory contains:

```
my-spirit/
├── manifest.toml        # Package metadata (required)
├── spirit.wasm          # Compiled WASM (required)
└── assets/              # Optional static assets
```

---

## Complete Workflow

### 1. Create Project

```bash
mkdir my-spirit && cd my-spirit
```

### 2. Generate Keys

```rust
let keypair = KeyPair::generate();
println!("Public key: {}", keypair.verifying_key().to_hex());
// Save private key securely
```

### 3. Write Manifest

```toml
# manifest.toml
name = "my-spirit"
author = "your-64-char-hex-public-key"

[version]
major = 1
minor = 0
patch = 0

capabilities = ["sensor_time", "actuator_log"]
```

### 4. Compile WASM

Build your WASM module and save as `spirit.wasm`.

### 5. Sign Package

```rust
let mut manifest = Manifest::from_file("manifest.toml")?;
let signature = manifest.sign(&signing_key)?;
manifest.signature = Some(signature);
manifest.to_file("manifest.toml")?;
```

### 6. Install Locally

```rust
let mut registry = LocalRegistry::new();
registry.init().await?;
registry.install("./my-spirit/").await?;
```

### 7. Verify

```rust
let spirit = registry.get("my-spirit").await?;
spirit.manifest.verify()?;
println!("Spirit installed and verified!");
```

---

## Error Reference

| Error | Cause | Fix |
|-------|-------|-----|
| `InvalidName` | Empty or invalid characters | Use alphanumeric, dash, underscore |
| `InvalidAuthor` | Wrong key length | Use 64-char hex public key |
| `SignatureError` | Missing or invalid signature | Sign manifest properly |
| `NotFound` | Spirit not in registry | Install first |
| `MissingWasm` | No spirit.wasm file | Add WASM file to package |

---

## Related Documentation

- [Full Documentation (univrs-vudo/docs)](https://github.com/univrs/univrs-vudo/tree/main/docs)
- [Phase 2 Complete](./PHASE2_COMPLETE.md)
- [CLI Reference](./CLI.md)
- [DOL Language](./DOLRAC.md)

---

*"Imagine. Summon. Create."*

*Le reseau est Bondieu.*
