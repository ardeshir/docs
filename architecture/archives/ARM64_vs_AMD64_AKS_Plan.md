# Azure AKS ARM64 Migration Analysis & Implementation Plan

Based on the [official Microsoft documentation](https://learn.microsoft.com/en-us/azure/aks/use-arm64-vms)
A comprehensive analysis for our QSM-Julia optimization workload:

## ✅ Latest News: ARM64 is GA and Well-Supported

Azure ARM64 support in AKS is generally available and provides better price-performance for many workloads, with up to 50% better price-performance than comparable x86-based VMs for scale-out workloads.

## 📋 Prerequisites Check

### Required Components
- ✅ Existing AKS cluster 
- ✅ ARM64 VM SKUs: Dpsv5, Dplsv5, or Epsv5 series available
- ❓ Container images that support ARM64 architecture (needs verification)

### Current Limitations
- ARM64 VMs aren't supported for Windows node pools (Linux only) 
- Existing node pools can't be updated to use ARM64 VMs (must create new)
- ARM64 node pools aren't supported on Defender-enabled clusters with Kubernetes version 1.29.0 or lower

## 🔧 Implementation Steps

### Phase 1: Pre-Migration Validation

#### 1.1 Check Our Container Images for ARM64 Support
```bash
# Check if our current images support ARM64
docker manifest inspect cdsoptmzprod.azurecr.io/cdsqsmimg:__QSMIMG__
docker manifest inspect cdsoptmzprod.azurecr.io/julia-service:__JULIA__

# Look for "arm64" or "aarch64" in the architectures
docker buildx imagetools inspect cdsoptmzprod.azurecr.io/cdsqsmimg:__QSMIMG__ --format "{{json .Manifest}}" | jq '.manifests[].platform'
```

#### 1.2 Test Julia Performance on ARM64
```bash
# Create a test ARM64 container locally (if you have M1 Mac)
docker run --platform linux/arm64 julia:1.9 julia -e 'using LinearAlgebra; @time rand(1000,1000) * rand(1000,1000)'

# Compare with AMD64 performance
docker run --platform linux/amd64 julia:1.9 julia -e 'using LinearAlgebra; @time rand(1000,1000) * rand(1000,1000)'
```

#### 1.3 Verify Available ARM64 SKUs in Our Region
```bash
# Check available ARM64 SKUs
az vm list-sizes --location eastus --output table | grep -E "(Dpsv5|Dplsv5|Epsv5)"

# Check pricing comparison
az vm list-prices --location eastus --size Standard_D4pds_v5  # ARM64
az vm list-prices --location eastus --size Standard_D4s_v5    # AMD64 equivalent
```

### Phase 2: Multi-Architecture Image Preparation

#### 2.1 Update Dockerfiles for Multi-Arch
```dockerfile
# Dockerfile.julia-service - Updated for multi-arch
FROM --platform=$BUILDPLATFORM julia:1.9 as builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install packages that work on both architectures
RUN julia -e 'using Pkg; Pkg.add(["HTTP", "JSON", "JuMP"])'

# For optimization solvers, check ARM64 compatibility
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        echo "Installing ARM64-optimized packages"; \
        julia -e 'using Pkg; Pkg.add("Ipopt")'; \
    else \
        echo "Installing AMD64-optimized packages"; \
        julia -e 'using Pkg; Pkg.add(["Ipopt", "Gurobi"])'; \
    fi

FROM julia:1.9
COPY --from=builder /root/.julia /root/.julia
COPY src/ /app/src/
WORKDIR /app
EXPOSE 8000
CMD ["julia", "src/Service.jl"]
```

#### 2.2 Build Multi-Architecture Images
```bash
# Create buildx builder for multi-arch
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# Build and push multi-arch Julia service
docker buildx build --platform linux/amd64,linux/arm64 \
  -t cdsoptmzprod.azurecr.io/julia-service:multiarch \
  --push \
  -f Dockerfile.julia-service .

# Build and push multi-arch QSM service
docker buildx build --platform linux/amd64,linux/arm64 \
  -t cdsoptmzprod.azurecr.io/cdsqsmimg:multiarch \
  --push \
  -f Dockerfile.qsm .
```

### Phase 3: ARM64 Node Pool Creation

#### 3.1 Add ARM64 Node Pool to Existing Cluster
```bash
# Set variables
RESOURCE_GROUP_NAME="your-resource-group"
CLUSTER_NAME="your-aks-cluster"
ARM_NODE_POOL_NAME="arm64pool"

# Add ARM64 node pool with taints to prevent system pods
az aks nodepool add \
  --resource-group $RESOURCE_GROUP_NAME \
  --cluster-name $CLUSTER_NAME \
  --name $ARM_NODE_POOL_NAME \
  --node-count 2 \
  --node-vm-size Standard_D4pds_v5 \
  --node-taints "kubernetes.io/arch=arm64:NoSchedule" \
  --tags "environment=test,architecture=arm64"
```

#### 3.2 Verify ARM64 Node Pool
```bash
# Verify the node pool was created
az aks nodepool show \
  --resource-group $RESOURCE_GROUP_NAME \
  --cluster-name $CLUSTER_NAME \
  --name $ARM_NODE_POOL_NAME \
  --query vmSize

# Check nodes are ready
kubectl get nodes -l kubernetes.io/arch=arm64
kubectl describe node <arm64-node-name>
```

### Phase 4: Deploy Test Workload to ARM64

#### 4.1 Create ARM64-Specific Deployment
```yaml
# arm64-test-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qsm-julia-arm64-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: qsm-julia-arm64-test
  template:
    metadata:
      labels:
        app: qsm-julia-arm64-test
    spec:
      # Force scheduling to ARM64 nodes
      nodeSelector:
        kubernetes.io/arch: arm64
      tolerations:
      - key: "kubernetes.io/arch"
        operator: "Equal"
        value: "arm64"
        effect: "NoSchedule"
      containers:
      - name: qsm
        image: cdsoptmzprod.azurecr.io/cdsqsmimg:multiarch
        ports:
        - containerPort: 80
        env:
        - name: QSM_ENVIRONMENT
          value: "arm64-test"
        - name: ARCHITECTURE
          value: "arm64"
        resources:
          requests:
            memory: "2.5Gi"
            cpu: "1.5"
          limits:
            memory: "4Gi"
            cpu: "2.5"
            
      - name: julia-service
        image: cdsoptmzprod.azurecr.io/julia-service:multiarch
        ports:
        - containerPort: 8000
        env:
        - name: CLUSTER
          value: "arm64-test"
        - name: ARCHITECTURE
          value: "arm64"
        resources:
          requests:
            memory: "16Gi"
            cpu: "4"
          limits:
            memory: "20Gi"
            cpu: "5"
---
apiVersion: v1
kind: Service
metadata:
  name: qsm-julia-arm64-svc
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  - port: 8000
    targetPort: 8000
  selector:
    app: qsm-julia-arm64-test
```

#### 4.2 Deploy and Test
```bash
# Deploy to ARM64 nodes
kubectl apply -f arm64-test-deployment.yaml

# Verify pods are running on ARM64 nodes
kubectl get pods -o wide | grep arm64-test

# Test the ARM64 deployment
kubectl port-forward svc/qsm-julia-arm64-svc 8080:80 &
kubectl port-forward svc/qsm-julia-arm64-svc 8000:8000 &

# Send your optimization request to ARM64 version
curl -X POST http://localhost:8000/optimize \
  -H "Content-Type: application/json" \
  -d @your-optimization-request.json
```

### Phase 5: Performance Comparison

#### 5.1 Benchmarking Script
```bash
#!/bin/bash
# performance-comparison.sh

echo "=== ARM64 vs AMD64 Performance Comparison ==="

# Test identical optimization requests on both architectures
AMD64_POD=$(kubectl get pods -l app=qsm-julia-sidecar -o name | head -1)
ARM64_POD=$(kubectl get pods -l app=qsm-julia-arm64-test -o name | head -1)

echo "Testing AMD64 (current production)..."
kubectl exec $AMD64_POD -c julia-service -- julia -e '
using LinearAlgebra, BenchmarkTools
@btime rand(1000,1000) * rand(1000,1000)
'

echo "Testing ARM64 (new architecture)..."  
kubectl exec $ARM64_POD -c julia-service -- julia -e '
using LinearAlgebra, BenchmarkTools
@btime rand(1000,1000) * rand(1000,1000)
'

# Test your actual optimization workload
echo "Testing real optimization on both architectures..."
# Add your specific optimization benchmark here
```

### Phase 6: Production Migration Strategy

#### 6.1 Blue-Green Deployment Approach
```bash
# Gradually shift traffic to ARM64
# Start with 10% of requests to ARM64

# Update your main deployment to include both architectures
kubectl patch deployment qsm-julia-sidecar -p '{
  "spec": {
    "template": {
      "spec": {
        "affinity": {
          "nodeAffinity": {
            "preferredDuringSchedulingIgnoredDuringExecution": [
              {
                "weight": 90,
                "preference": {
                  "matchExpressions": [
                    {"key": "kubernetes.io/arch", "operator": "In", "values": ["amd64"]}
                  ]
                }
              },
              {
                "weight": 10,
                "preference": {
                  "matchExpressions": [
                    {"key": "kubernetes.io/arch", "operator": "In", "values": ["arm64"]}
                  ]
                }
              }
            ]
          }
        }
      }
    }
  }
}'
```

## 📊 Cost Analysis

### Expected Savings
Based on Microsoft's claims:
- Up to 50% better price-performance for scale-out workloads
- Lower power consumption → potential cost savings

### VM Size Recommendations
```bash
# Current (AMD64) vs Recommended ARM64 equivalents:
# Standard_D4s_v5 (4 vCPU, 16GB) → Standard_D4pds_v5 (4 vCPU, 16GB)
# Standard_D8s_v5 (8 vCPU, 32GB) → Standard_D8pds_v5 (8 vCPU, 32GB)

# Check current pricing
az vm list-prices --location eastus --size Standard_D4s_v5    # AMD64
az vm list-prices --location eastus --size Standard_D4pds_v5  # ARM64
```

## ⚠️  Risk Mitigation

### 1. Julia Ecosystem Compatibility
- Test all your Julia packages on ARM64 first
- Some optimization solvers may have different performance characteristics
- Linear algebra libraries (BLAS/LAPACK) behavior might differ

### 2. Rollback Plan
```bash
# Quick rollback: drain ARM64 nodes and shift traffic back
kubectl drain <arm64-node> --ignore-daemonsets --delete-emptydir-data
kubectl cordon <arm64-node>

# Update deployment to avoid ARM64
kubectl patch deployment qsm-julia-sidecar -p '{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "kubernetes.io/arch": "amd64"
        }
      }
    }
  }
}'
```

### 3. Monitoring and Alerting
```bash
# Add ARM64-specific monitoring
kubectl label nodes -l kubernetes.io/arch=arm64 monitoring=arm64

# Monitor performance differences
# Use Prometheus queries to compare:
# - Request processing time: arm64 vs amd64
# - Memory usage patterns
# - Error rates
```

## 🎯 My Recommendation

### Start with Hybrid Approach (Recommended)
1. ✅ **Keep production AMD64** for stability
2. ✅ **Add ARM64 node pool** for testing and development
3. ✅ **Build multi-arch images** to support both
4. ✅ **Gradually test** optimization workloads on ARM64
5. ✅ **Migrate when confident** in performance and stability

### Timeline Suggestion
- **Week 1-2**: Build multi-arch images and test locally
- **Week 3**: Add ARM64 node pool and deploy test workloads
- **Week 4-6**: Performance testing and optimization comparison
- **Week 7-8**: Gradual traffic shift if results are positive
- **Week 9-10**: Full migration (if warranted)

## 🚨 Decision Checkpoint

**Before proceeding, answer these questions:**
1. Do our Julia optimization packages work identically on ARM64?
2. Are we seeing 20%+ cost savings that justify the migration effort?
3. Is our TaskFailedException actually related to architecture?
4. Does our team have bandwidth for this migration alongside fixing current issues?

