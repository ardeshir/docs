# Integration: BRICS Pay Bridge ↔ Univrs.io Architecture

## BRICS Pay bridge to [Univrs.io](http://Univrs.io) decentralized cloud platform and CryptoSaint regenerative economics.

## System Overview: The Three-Layer Stack

```
┌────────────────────────────────────────────────────────────────┐
│                    UNIVRS.IO ECOSYSTEM                          │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 3: Application Layer                                     │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ User-Facing Services                                      │ │
│  │ • Decentralized App Hosting                              │ │
│  │ • Developer Tools & CI/CD                                │ │
│  │ • Community Governance Portal                            │ │
│  │ • Regenerative Project Marketplace                       │ │
│  └──────────────────────────────────────────────────────────┘ │
│                            ↕                                    │
│  Layer 2: Economic Layer (CryptoSaint)                         │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Contribution Credit System                                │ │
│  │ • Reputation Scoring                                     │ │
│  │ • Ecological Impact Valuation ←─────┐                   │ │
│  │ • Mutual Credit Ledger              │                   │ │
│  │ • DAO Governance (Quadratic Voting)  │                  │ │
│  │                                      │                   │ │
│  │ BRICS Pay Bridge ←──────────────────┤                   │ │
│  │ • Credit Valuation Protocol         │                   │ │
│  │ • Atomic Swaps (EB-HTLC)           │                   │ │
│  │ • Liquidity Pools                   │                   │ │
│  │ • ZK Privacy Layer                  │                   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                            ↕                                    │
│  Layer 1: Infrastructure Layer                                  │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Decentralized Cloud Infrastructure                        │ │
│  │ • Substrate Blockchain Runtime                           │ │
│  │ • IPFS Distributed Storage                               │ │
│  │ • Kubernetes Orchestration                               │ │
│  │ • Edge Computing Nodes                                   │ │
│  │ • TEE (Trusted Execution Environments)                   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

## Layer 1: Infrastructure Integration

### Substrate-Based Univrs Chain

```rust
// runtime/src/lib.rs
#![cfg_attr(not(feature = "std"), no_std)]

use sp_runtime::{
    create_runtime_str, generic, impl_opaque_keys,
    traits::{BlakeTwo256, Block as BlockT, IdentifyAccount, Verify},
    MultiSignature,
};

/// Univrs.io Runtime - Integrating all pallets
pub struct Runtime;

impl frame_system::Config for Runtime {
    type BaseCallFilter = frame_support::traits::Everything;
    type BlockWeights = RuntimeBlockWeights;
    type BlockLength = RuntimeBlockLength;
    type DbWeight = RocksDbWeight;
    type RuntimeOrigin = RuntimeOrigin;
    type RuntimeCall = RuntimeCall;
    type Index = Index;
    type BlockNumber = BlockNumber;
    type Hash = Hash;
    type Hashing = BlakeTwo256;
    type AccountId = AccountId;
    type Lookup = AccountIdLookup<AccountId, ()>;
    type Header = generic::Header<BlockNumber, BlakeTwo256>;
    type RuntimeEvent = RuntimeEvent;
    type BlockHashCount = BlockHashCount;
    type Version = Version;
    type PalletInfo = PalletInfo;
    type AccountData = pallet_balances::AccountData<Balance>;
    type OnNewAccount = ();
    type OnKilledAccount = ();
    type SystemWeightInfo = ();
    type SS58Prefix = SS58Prefix;
    type OnSetCode = ();
    type MaxConsumers = frame_support::traits::ConstU32<16>;
}

// Construct runtime with all pallets
construct_runtime!(
    pub enum Runtime where
        Block = Block,
        NodeBlock = opaque::Block,
        UncheckedExtrinsic = UncheckedExtrinsic
    {
        // Core System Pallets
        System: frame_system,
        Timestamp: pallet_timestamp,
        Balances: pallet_balances,
        TransactionPayment: pallet_transaction_payment,
        
        // Governance Pallets
        Democracy: pallet_democracy,
        Council: pallet_collective::<Instance1>,
        TechnicalCommittee: pallet_collective::<Instance2>,
        Treasury: pallet_treasury,
        
        // Custom Univrs Pallets
        CreditNetwork: pallet_credit_network,              // Contribution credits
        EcologicalOracle: pallet_ecological_oracle,        // Impact valuation
        ReputationSystem: pallet_reputation,               // Reputation scoring
        
        // BRICS Bridge Pallets
        AtomicSwap: pallet_atomic_swap,                    // Cross-chain swaps
        BricsBridge: pallet_brics_bridge,                  // Bridge orchestration
        LiquidityPool: pallet_liquidity_pool,              // LP management
        OracleAggregator: pallet_oracle_aggregator,        // Price feeds
        
        // Infrastructure Pallets
        CloudResources: pallet_cloud_resources,            // Resource allocation
        ComputeMarket: pallet_compute_market,              // Compute marketplace
        StorageMarket: pallet_storage_market,              // Storage marketplace
        
        // Privacy Pallets
        ZKVerifier: pallet_zk_verifier,                    // ZK proof verification
    }
);
```

### Kubernetes Cluster Architecture

```yaml
# k8s/univrs-platform-stack.yaml
---
# Namespace for entire Univrs platform
apiVersion: v1
kind: Namespace
metadata:
  name: univrs-platform
  labels:
    environment: production
    platform: univrs

---
# Substrate Node StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: univrs-validator
  namespace: univrs-platform
spec:
  serviceName: univrs-validator
  replicas: 7  # Byzantine fault tolerance (3f+1, f=2)
  selector:
    matchLabels:
      app: univrs-validator
  template:
    metadata:
      labels:
        app: univrs-validator
        layer: infrastructure
    spec:
      securityContext:
        fsGroup: 1000
      containers:
      - name: substrate-node
        image: univrs/substrate-node:v1.0.0
        ports:
        - containerPort: 9944  # WebSocket RPC
          name: ws-rpc
        - containerPort: 9933  # HTTP RPC
          name: http-rpc
        - containerPort: 30333  # P2P
          name: p2p
        - containerPort: 9615  # Prometheus metrics
          name: metrics
        command:
        - /usr/local/bin/univrs-node
        args:
        - --base-path=/data
        - --chain=mainnet
        - --validator
        - --name=$(POD_NAME)
        - --rpc-cors=all
        - --unsafe-ws-external
        - --unsafe-rpc-external
        - --rpc-methods=Unsafe
        - --prometheus-external
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: RUST_LOG
          value: "info,runtime=debug"
        resources:
          requests:
            memory: "8Gi"
            cpu: "4000m"
          limits:
            memory: "16Gi"
            cpu: "8000m"
        volumeMounts:
        - name: chain-data
          mountPath: /data
        - name: node-keys
          mountPath: /keys
          readOnly: true
      
      # Sidecar: Telemetry collector
      - name: telemetry
        image: univrs/telemetry-collector:latest
        ports:
        - containerPort: 8080
        env:
        - name: SUBSTRATE_RPC=ws://localhost:9944
        
  volumeClaimTemplates:
  - metadata:
      name: chain-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 500Gi

---
# IPFS Cluster for Distributed Storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ipfs-cluster
  namespace: univrs-platform
spec:
  serviceName: ipfs-cluster
  replicas: 5
  selector:
    matchLabels:
      app: ipfs-cluster
  template:
    metadata:
      labels:
        app: ipfs-cluster
        layer: infrastructure
    spec:
      containers:
      - name: ipfs-node
        image: ipfs/go-ipfs:v0.23.0
        ports:
        - containerPort: 4001  # P2P
        - containerPort: 5001  # API
        - containerPort: 8080  # Gateway
        volumeMounts:
        - name: ipfs-data
          mountPath: /data/ipfs
        resources:
          requests:
            memory: "4Gi"
            cpu: "2000m"
          limits:
            memory: "8Gi"
            cpu: "4000m"
      
      - name: ipfs-cluster-service
        image: ipfs/ipfs-cluster:latest
        ports:
        - containerPort: 9094  # HTTP API
        - containerPort: 9095  # P2P
        - containerPort: 9096  # Cluster API
        env:
        - name: CLUSTER_PEERNAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: CLUSTER_SECRET
          valueFrom:
            secretKeyRef:
              name: ipfs-cluster-secret
              key: secret
        volumeMounts:
        - name: cluster-data
          mountPath: /data/ipfs-cluster
          
  volumeClaimTemplates:
  - metadata:
      name: ipfs-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Ti
  - metadata:
      name: cluster-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi

---
# BRICS Bridge Deployment (from previous design)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: brics-bridge
  namespace: univrs-platform
spec:
  replicas: 3
  selector:
    matchLabels:
      app: brics-bridge
      layer: economic
  template:
    metadata:
      labels:
        app: brics-bridge
        layer: economic
    spec:
      containers:
      - name: bridge-node
        image: univrs/brics-bridge:latest
        ports:
        - containerPort: 8545  # JSON-RPC
        - containerPort: 9615  # Metrics
        env:
        - name: SUBSTRATE_RPC
          value: "ws://univrs-validator-0.univrs-validator:9944"
        - name: BRICS_ENDPOINTS
          valueFrom:
            configMapKeyRef:
              name: brics-config
              key: endpoints
        resources:
          requests:
            memory: "4Gi"
            cpu: "2000m"
          limits:
            memory: "8Gi"
            cpu: "4000m"
      
      # Oracle aggregator sidecar
      - name: oracle-aggregator
        image: univrs/oracle-aggregator:latest
        ports:
        - containerPort: 8080
        env:
        - name: ECOLOGICAL_ORACLE_URL
          value: "http://ecological-oracle-service:8080"
        - name: PRICE_ORACLE_URLS
          value: "https://api.coingecko.com,https://api.binance.com"
      
      # Settlement monitor sidecar
      - name: settlement-monitor
        image: univrs/settlement-monitor:latest
        env:
        - name: ALERT_WEBHOOK
          valueFrom:
            secretKeyRef:
              name: monitoring-secrets
              key: webhook-url

---
# Ecological Oracle Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecological-oracle
  namespace: univrs-platform
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ecological-oracle
      layer: economic
  template:
    metadata:
      labels:
        app: ecological-oracle
        layer: economic
    spec:
      containers:
      # Remote sensing processor
      - name: remote-sensing
        image: univrs/remote-sensing-processor:latest
        env:
        - name: PLANET_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: planet-api
        - name: SENTINEL_HUB_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: sentinel-client
        resources:
          requests:
            memory: "8Gi"
            cpu: "4000m"
          limits:
            memory: "16Gi"
            cpu: "8000m"
            nvidia.com/gpu: 1
      
      # ML inference engine
      - name: ml-inference
        image: univrs/ml-inference:latest
        volumeMounts:
        - name: models
          mountPath: /models
        resources:
          requests:
            nvidia.com/gpu: 1
      
      # IoT data aggregator
      - name: iot-aggregator
        image: univrs/iot-aggregator:latest
        env:
        - name: INFLUXDB_URL
          value: "http://influxdb:8086"
        - name: MQTT_BROKER
          value: "mqtt://mqtt-broker:1883"
      
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: ml-models-pvc

---
# Cloud Resource Manager Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloud-resource-manager
  namespace: univrs-platform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloud-resource-manager
      layer: application
  template:
    metadata:
      labels:
        app: cloud-resource-manager
        layer: application
    spec:
      containers:
      - name: resource-manager
        image: univrs/cloud-resource-manager:latest
        ports:
        - containerPort: 8080
        env:
        - name: SUBSTRATE_RPC
          value: "ws://univrs-validator:9944"
        - name: K8S_API_SERVER
          value: "https://kubernetes.default.svc"
        - name: IPFS_API
          value: "http://ipfs-cluster:5001"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
      
      # Compute marketplace backend
      - name: compute-marketplace
        image: univrs/compute-marketplace:latest
        ports:
        - containerPort: 8081
        env:
        - name: REPUTATION_SERVICE
          value: "http://reputation-service:8080"

---
# Developer Portal & Governance UI
apiVersion: apps/v1
kind: Deployment
metadata:
  name: developer-portal
  namespace: univrs-platform
spec:
  replicas: 3
  selector:
    matchLabels:
      app: developer-portal
      layer: application
  template:
    metadata:
      labels:
        app: developer-portal
        layer: application
    spec:
      containers:
      - name: web-frontend
        image: univrs/developer-portal-ui:latest
        ports:
        - containerPort: 3000
        env:
        - name: SUBSTRATE_WS_URL
          value: "wss://rpc.univrs.io"
        - name: IPFS_GATEWAY
          value: "https://gateway.univrs.io"
      
      - name: api-backend
        image: univrs/developer-portal-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: connection-string

---
# Ingress Controller
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: univrs-platform-ingress
  namespace: univrs-platform
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - univrs.io
    - "*.univrs.io"
    secretName: univrs-tls
  rules:
  - host: app.univrs.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: developer-portal
            port:
              number: 3000
  - host: rpc.univrs.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: univrs-validator
            port:
              number: 9944
  - host: gateway.univrs.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ipfs-cluster
            port:
              number: 8080
  - host: bridge.univrs.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: brics-bridge
            port:
              number: 8545
```

## Layer 2: Economic System Integration

### Cloud Resource Tokenization

```rust
// pallets/cloud-resources/src/lib.rs

/// Tokenize cloud resources as NFTs with contribution credits
#[derive(Clone, Encode, Decode, PartialEq, RuntimeDebug, TypeInfo)]
pub struct CloudResourceNFT {
    pub resource_id: ResourceId,
    pub resource_type: ResourceType,
    pub specifications: ResourceSpecs,
    
    // Contribution tracking
    pub provided_by: AccountId,
    pub ecological_footprint: EcologicalFootprint,
    pub contribution_credits_earned: Balance,
    
    // Utilization
    pub allocated_to: Option<AccountId>,
    pub utilization_history: Vec<UtilizationRecord>,
    
    // Bridge capability
    pub bridge_eligible: bool,
    pub bridge_value_usd: Option<Balance>,
}

#[derive(Clone, Encode, Decode, PartialEq, RuntimeDebug, TypeInfo)]
pub enum ResourceType {
    Compute {
        cpu_cores: u32,
        memory_gb: u64,
        gpu_count: u32,
    },
    Storage {
        capacity_tb: u64,
        iops: u32,
        redundancy_level: u8,
    },
    Network {
        bandwidth_gbps: u32,
        location: GeoLocation,
    },
    Validator {
        stake_amount: Balance,
        uptime_percentage: u8,
    },
}

#[derive(Clone, Encode, Decode, PartialEq, RuntimeDebug, TypeInfo)]
pub struct EcologicalFootprint {
    // Power consumption
    pub power_usage_watts: u64,
    pub renewable_energy_percent: u8,
    
    // Carbon
    pub carbon_emissions_kg_per_year: u64,
    pub carbon_offsets: Vec<CarbonOffset>,
    
    // Hardware lifecycle
    pub hardware_age_months: u32,
    pub recycling_plan: Option<RecyclingPlan>,
}

impl<T: Config> Pallet<T> {
    /// Mint cloud resource as NFT, award contribution credits
    pub fn register_cloud_resource(
        provider: T::AccountId,
        resource_type: ResourceType,
        specs: ResourceSpecs,
        ecological_data: EcologicalFootprint,
    ) -> Result<ResourceId, Error<T>> {
        // Calculate contribution credits based on:
        // 1. Resource capacity
        // 2. Renewable energy usage
        // 3. Hardware efficiency
        // 4. Geographic distribution (edge nodes get bonus)
        
        let base_credits = Self::calculate_base_credits(&resource_type, &specs)?;
        let eco_multiplier = Self::calculate_eco_multiplier(&ecological_data)?;
        let geo_multiplier = Self::calculate_geo_multiplier(&specs.location)?;
        
        let total_credits = base_credits
            .saturating_mul(eco_multiplier)
            .saturating_mul(geo_multiplier);
        
        // Mint NFT
        let resource_id = Self::next_resource_id();
        let nft = CloudResourceNFT {
            resource_id,
            resource_type,
            specifications: specs,
            provided_by: provider.clone(),
            ecological_footprint: ecological_data,
            contribution_credits_earned: total_credits,
            allocated_to: None,
            utilization_history: vec![],
            bridge_eligible: true,
            bridge_value_usd: Self::estimate_market_value(&resource_type, &specs),
        };
        
        CloudResources::<T>::insert(resource_id, nft);
        
        // Award contribution credits
        CreditNetwork::<T>::mint_contribution_credits(
            provider.clone(),
            total_credits,
            ContributionType::InfrastructureProvision,
        )?;
        
        // Update reputation
        ReputationSystem::<T>::increase_reputation(
            provider,
            total_credits / 100,
            ReputationSource::CloudResourceProvider,
        )?;
        
        Ok(resource_id)
    }
    
    /// Use contribution credits earned from providing resources to bridge to BRICS
    pub fn bridge_resource_value(
        provider: T::AccountId,
        resource_id: ResourceId,
        target_currency: BricsCurrency,
        amount_usd: Balance,
    ) -> Result<BridgeTransactionId, Error<T>> {
        let resource = Self::cloud_resources(resource_id)
            .ok_or(Error::<T>::ResourceNotFound)?;
        
        ensure!(resource.provided_by == provider, Error::<T>::NotResourceOwner);
        ensure!(resource.bridge_eligible, Error::<T>::NotBridgeEligible);
        
        // Check sufficient contribution credits
        let credit_balance = CreditNetwork::<T>::credit_balance(&provider)?;
        let required_credits = Self::calculate_required_credits(
            amount_usd,
            &resource.ecological_footprint,
        )?;
        
        ensure!(credit_balance >= required_credits, Error::<T>::InsufficientCredits);
        
        // Initiate bridge transaction
        let bridge_tx = BricsBridge::<T>::initiate_bridge(
            provider,
            required_credits,
            target_currency,
            amount_usd,
            BridgeSource::CloudResourceValue(resource_id),
        )?;
        
        Ok(bridge_tx)
    }
}
```

### Unified Credit System

```rust
// pallets/credit-network/src/lib.rs

/// Unified credit system integrating multiple value streams
#[derive(Clone, Encode, Decode, PartialEq, RuntimeDebug, TypeInfo)]
pub struct UnifiedCreditAccount {
    pub account_id: AccountId,
    
    // Credit sources
    pub infrastructure_credits: Balance,      // From providing cloud resources
    pub ecological_credits: Balance,          // From regenerative actions
    pub development_credits: Balance,         // From open source contributions
    pub governance_credits: Balance,          // From DAO participation
    pub bridge_credits: Balance,              // From facilitating cross-chain
    
    // Aggregated
    pub total_credits: Balance,
    pub weighted_reputation: u64,
    
    // Bridge eligibility
    pub bridge_capacity: Balance,
    pub active_bridges: Vec<BridgeTransactionId>,
    
    // Historical
    pub lifetime_credits_earned: Balance,
    pub lifetime_credits_spent: Balance,
}

impl<T: Config> Pallet<T> {
    /// Calculate comprehensive bridge capacity
    pub fn calculate_bridge_capacity(
        account: &T::AccountId,
    ) -> Result<Balance, Error<T>> {
        let unified_account = Self::credit_accounts(account)
            .ok_or(Error::<T>::AccountNotFound)?;
        
        // Multi-factor capacity calculation
        let mut capacity = 0u128;
        
        // Factor 1: Direct credit balance (60% weight)
        capacity += (unified_account.total_credits as u128) * 60 / 100;
        
        // Factor 2: Reputation score (20% weight)
        let reputation = ReputationSystem::<T>::reputation_score(account)?;
        let reputation_capacity = (reputation as u128) 
            * Self::reputation_to_credits_ratio();
        capacity += reputation_capacity * 20 / 100;
        
        // Factor 3: Ecological impact (15% weight)
        let eco_impact = EcologicalOracle::<T>::get_account_impact(account)?;
        let eco_capacity = Self::ecological_metrics_to_credits(&eco_impact)?;
        capacity += eco_capacity * 15 / 100;
        
        // Factor 4: Network effect (5% weight)
        let network_factor = Self::calculate_network_effect(account)?;
        capacity += (unified_account.total_credits as u128) * network_factor * 5 / 100;
        
        Ok(capacity as Balance)
    }
    
    /// Spend credits for various purposes
    pub fn spend_credits(
        account: T::AccountId,
        amount: Balance,
        purpose: CreditSpendPurpose,
    ) -> DispatchResult {
        let mut unified_account = Self::credit_accounts(&account)
            .ok_or(Error::<T>::AccountNotFound)?;
        
        ensure!(
            unified_account.total_credits >= amount,
            Error::<T>::InsufficientCredits
        );
        
        match purpose {
            CreditSpendPurpose::BridgeToFiat { currency, recipient } => {
                // Deduct credits
                unified_account.total_credits -= amount;
                
                // Initiate bridge
                let bridge_tx = BricsBridge::<T>::initiate_bridge(
                    account.clone(),
                    amount,
                    currency,
                    Self::credits_to_fiat(amount, currency)?,
                    BridgeSource::CreditBalance,
                )?;
                
                unified_account.active_bridges.push(bridge_tx);
            }
            
            CreditSpendPurpose::CloudResources { resource_type, duration } => {
                // Allocate cloud resources
                CloudResources::<T>::allocate_resources(
                    account.clone(),
                    resource_type,
                    duration,
                    amount,
                )?;
                
                unified_account.total_credits -= amount;
            }
            
            CreditSpendPurpose::GovernanceProposal { proposal_id } => {
                // Submit governance proposal
                Democracy::<T>::submit_proposal_with_credits(
                    account.clone(),
                    proposal_id,
                    amount,
                )?;
                
                unified_account.governance_credits -= amount;
            }
        }
        
        unified_account.lifetime_credits_spent += amount;
        CreditAccounts::<T>::insert(account, unified_account);
        
        Ok(())
    }
}
```

## Layer 3: Application Layer Integration

### Developer Portal with Bridge Access

```typescript
// apps/developer-portal/src/services/BridgeService.ts

import { ApiPromise, WsProvider } from '@polkadot/api';
import { web3FromAddress } from '@polkadot/extension-dapp';

export class UnivrsB ridgeService {
  private api: ApiPromise;
  
  constructor(private wsUrl: string = 'wss://rpc.univrs.io') {}
  
  async init() {
    const provider = new WsProvider(this.wsUrl);
    this.api = await ApiPromise.create({ provider });
  }
  
  /**
   * Get user's unified credit account
   */
  async getCreditAccount(address: string): Promise<UnifiedCreditAccount> {
    const account = await this.api.query.creditNetwork.creditAccounts(address);
    return account.toJSON() as UnifiedCreditAccount;
  }
  
  /**
   * Calculate bridge capacity including all contributions
   */
  async calculateBridgeCapacity(address: string): Promise<BridgeCapacity> {
    // Get credit balance
    const credits = await this.api.query.creditNetwork.creditAccounts(address);
    
    // Get reputation score
    const reputation = await this.api.query.reputationSystem.reputationScores(address);
    
    // Get ecological impact
    const ecoImpact = await this.api.query.ecologicalOracle.accountImpact(address);
    
    // Get cloud resources provided
    const resources = await this.api.query.cloudResources.providerResources(address);
    
    // Calculate composite capacity
    const capacity = await this.api.rpc.creditNetwork.calculateBridgeCapacity(address);
    
    return {
      totalCredits: credits.total_credits.toNumber(),
      reputation: reputation.score.toNumber(),
      ecologicalImpact: ecoImpact.toJSON(),
      cloudResources: resources.toJSON(),
      bridgeCapacity: capacity.toNumber(),
      availableCurrencies: ['RUB', 'CNY', 'INR', 'BRL', 'ZAR'],
    };
  }
  
  /**
   * Initiate bridge transaction with ZK privacy
   */
  async bridgeToFiat(params: {
    address: string;
    amount: number;
    targetCurrency: BricsCurrency;
    recipient: string;
    usePrivacy: boolean;
  }): Promise<BridgeTransaction> {
    const { address, amount, targetCurrency, recipient, usePrivacy } = params;
    
    // Get signer
    const injector = await web3FromAddress(address);
    
    if (usePrivacy) {
      // Generate ZK proof
      const proof = await this.generatePrivacyProof(address, amount);
      
      // Submit private bridge transaction
      const tx = this.api.tx.bricsBridge.initiateprivateBridge(
        proof,
        targetCurrency,
        recipient
      );
      
      const hash = await tx.signAndSend(address, { signer: injector.signer });
      return { txHash: hash.toString(), private: true };
    } else {
      // Submit public bridge transaction
      const tx = this.api.tx.bricsBridge.initiatePublicBridge(
        amount,
        targetCurrency,
        recipient
      );
      
      const hash = await tx.signAndSend(address, { signer: injector.signer });
      return { txHash: hash.toString(), private: false };
    }
  }
  
  /**
   * Register cloud resource and earn credits
   */
  async registerCloudResource(params: {
    address: string;
    resourceType: ResourceType;
    specifications: ResourceSpecs;
    ecologicalData: EcologicalFootprint;
  }): Promise<{ resourceId: string; creditsEarned: number }> {
    const { address, resourceType, specifications, ecologicalData } = params;
    
    const injector = await web3FromAddress(address);
    const tx = this.api.tx.cloudResources.registerCloudResource(
      resourceType,
      specifications,
      ecologicalData
    );
    
    const result = await new Promise((resolve, reject) => {
      tx.signAndSend(address, { signer: injector.signer }, ({ status, events }) => {
        if (status.isInBlock) {
          // Find ResourceRegistered event
          const registered = events.find(e => 
            this.api.events.cloudResources.ResourceRegistered.is(e.event)
          );
          
          if (registered) {
            const [resourceId, credits] = registered.event.data;
            resolve({
              resourceId: resourceId.toString(),
              creditsEarned: credits.toNumber(),
            });
          }
        }
      });
    });
    
    return result as { resourceId: string; creditsEarned: number };
  }
  
  /**
   * Monitor bridge transaction status
   */
  async monitorBridgeTransaction(txHash: string): Promise<Observable<BridgeStatus>> {
    return new Observable(observer => {
      this.api.query.system.events((events) => {
        events.forEach((record) => {
          const { event } = record;
          
          if (this.api.events.bricsBridge.BridgeInitiated.is(event)) {
            observer.next({ status: 'initiated', data: event.data.toJSON() });
          }
          
          if (this.api.events.bricsBridge.BridgeCompleted.is(event)) {
            observer.next({ status: 'completed', data: event.data.toJSON() });
            observer.complete();
          }
          
          if (this.api.events.bricsBridge.BridgeFailed.is(event)) {
            observer.error({ status: 'failed', data: event.data.toJSON() });
          }
        });
      });
    });
  }
  
  private async generatePrivacyProof(
    address: string,
    amount: number
  ): Promise<ZKProof> {
    // Call ZK proof generation service
    const response = await fetch('https://zk.univrs.io/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ address, amount }),
    });
    
    return response.json();
  }
}
```

### React Dashboard Component

```typescript
// apps/developer-portal/src/components/BridgeDashboard.tsx

import React, { useState, useEffect } from 'react';
import { UnivrsB ridgeService } from '../services/BridgeService';

export const BridgeDashboard: React.FC = () => {
  const [account, setAccount] = useState<string>('');
  const [capacity, setCapacity] = useState<BridgeCapacity | null>(null);
  const [loading, setLoading] = useState(false);
  
  const bridgeService = new UnivrsB ridgeService();
  
  useEffect(() => {
    bridgeService.init();
  }, []);
  
  const loadCapacity = async () => {
    if (!account) return;
    setLoading(true);
    try {
      const cap = await bridgeService.calculateBridgeCapacity(account);
      setCapacity(cap);
    } catch (error) {
      console.error('Failed to load capacity:', error);
    }
    setLoading(false);
  };
  
  const handleBridge = async (currency: BricsCurrency, amount: number) => {
    try {
      const tx = await bridgeService.bridgeToFiat({
        address: account,
        amount,
        targetCurrency: currency,
        recipient: '', // Get from form
        usePrivacy: true, // Get from checkbox
      });
      
      // Monitor transaction
      bridgeService.monitorBridgeTransaction(tx.txHash).subscribe({
        next: (status) => console.log('Bridge status:', status),
        complete: () => alert('Bridge completed!'),
        error: (err) => alert(`Bridge failed: ${err}`),
      });
    } catch (error) {
      console.error('Bridge failed:', error);
    }
  };
  
  return (
    <div className="bridge-dashboard">
      <h1>BRICS Pay Bridge</h1>
      
      <section className="capacity-overview">
        <h2>Your Bridge Capacity</h2>
        {capacity && (
          <div>
            <div className="stat">
              <label>Total Credits:</label>
              <value>{capacity.totalCredits.toLocaleString()}</value>
            </div>
            
            <div className="stat">
              <label>Reputation Score:</label>
              <value>{capacity.reputation}/1000</value>
            </div>
            
            <div className="stat">
              <label>Ecological Impact:</label>
              <value>
                {capacity.ecologicalImpact.carbon_sequestered_tonnes}t CO₂
              </value>
            </div>
            
            <div className="stat highlight">
              <label>Bridge Capacity:</label>
              <value>${capacity.bridgeCapacity.toLocaleString()}</value>
            </div>
          </div>
        )}
      </section>
      
      <section className="bridge-actions">
        <h2>Bridge to BRICS Currency</h2>
        <BridgeForm onSubmit={handleBridge} capacity={capacity} />
      </section>
      
      <section className="contribution-sources">
        <h2>Earn More Credits</h2>
        <div className="grid">
          <Card title="Provide Cloud Resources">
            Register your compute, storage, or network resources
            to earn contribution credits
            <button onClick={() => /* navigate */ {}}>
              Register Resource
            </button>
          </Card>
          
          <Card title="Ecological Projects">
            Participate in regenerative projects and earn
            credits backed by verified impact
            <button onClick={() => /* navigate */ {}}>
              Browse Projects
            </button>
          </Card>
          
          <Card title="Open Source Contributions">
            Contribute to Univrs codebase and ecosystem tools
            <button onClick={() => /* navigate */ {}}>
              View Repos
            </button>
          </Card>
          
          <Card title="Provide Liquidity">
            Become a bridge LP and earn fees while supporting
            the regenerative economy
            <button onClick={() => /* navigate */ {}}>
              Add Liquidity
            </button>
          </Card>
        </div>
      </section>
    </div>
  );
};
```

## Complete Transaction Flow Example

### Scenario: Developer Provides Infrastructure → Bridges to Pay Indian Team

```
┌─────────────────────────────────────────────────────────────────┐
│ Transaction: Alice (USA) → Bob's Team (India)                    │
├─────────────────────────────────────────────────────────────────┤

Step 1: Alice registers cloud resource on Univrs.io
  ├─ Resource: 32-core server, 128GB RAM, 2TB NVMe
  ├─ Location: Chicago edge node
  ├─ Ecological: 80% renewable energy
  └─ Result: Earns 50,000 contribution credits + 500 reputation

Step 2: Alice's credits accrue from usage
  ├─ Her server used by 3 projects for 6 months
  ├─ Generates additional 30,000 credits
  └─ Total balance: 80,000 credits

Step 3: Alice wants to pay Bob's team in India
  ├─ Bob's project: Regenerative agriculture tech
  ├─ Invoice: 5,000 INR ($60 USD equivalent)
  └─ Alice initiates bridge

Step 4: Bridge capacity calculation
  ├─ Credit balance: 80,000 → $800 equivalent
  ├─ Reputation: 1,200 → 1.2x multiplier
  ├─ Ecological bonus: 80% renewable → 1.15x multiplier
  ├─ Final capacity: $1,104
  └─ Required: $60 ✓ (sufficient)

Step 5: Oracle pricing
  ├─ Ecological Oracle: Alice's server carbon-negative
  ├─ Adds 5% premium to exchange rate
  ├─ Base rate: 1 credit = 0.01 USD
  ├─ Adjusted: 1 credit = 0.0105 USD
  └─ Required credits: ~5,714 credits

Step 6: ZK proof generation (privacy enabled)
  ├─ Prove: capacity >= 5,714 credits (without revealing exact)
  ├─ Prove: reputation >= 500 (threshold)
  ├─ Prove: ecological impact positive
  └─ Generate nullifier (prevent double-spend)

Step 7: Atomic swap setup
  ├─ Lock 5,714 credits on Univrs chain
  ├─ Ecological collateral: Server NFT metadata
  ├─ Generate secret for HTLC
  ├─ Hash lock: blake2(secret)
  └─ Time lock: 24 hours

Step 8: BRICS Pay settlement
  ├─ Bridge operator has INR liquidity
  ├─ Receives hash lock and swap parameters
  ├─ Initiates INR transfer to Bob via UPI
  └─ Bob receives 5,000 INR in wallet

Step 9: Secret reveal and completion
  ├─ Bridge operator reveals secret
  ├─ Alice's credits burned on Univrs chain
  ├─ Collateral returned to Alice
  ├─ Reputation: Alice +50, Bridge operator +20
  └─ Transaction recorded in both ledgers

Step 10: Impact tracking
  ├─ Alice's carbon-negative server value recorded
  ├─ Bob's regenerative ag project linked
  ├─ Ecological impact: Net positive
  └─ Both parties earn ecological credits

Final State:
  Alice: 74,286 credits remaining, can continue bridging
  Bob: 5,000 INR received, builds sustainable ag tech
  Ecosystem: Carbon-negative transaction, regenerative impact
  
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Strategy

### Phase 1: Testnet Launch (Months 1-3)

```bash
# Deploy Univrs testnet
kubectl apply -f k8s/testnet/

# Initialize with test validators
./scripts/init-testnet-validators.sh --count=7

# Deploy bridge testnet
kubectl apply -f k8s/testnet/brics-bridge/

# Connect to BRICS Pay testnet (if available)
./scripts/connect-brics-testnet.sh
```

### Phase 2: Mainnet Beta (Months 4-9)

- Limited validator set (21 nodes)
- Single BRICS currency (INR or BRL)
- Manual oracle updates
- Transaction limits

### Phase 3: Full Production (Months 10-18)

- Open validator set with staking
- All BRICS currencies
- Automated oracle network
- Full decentralization
