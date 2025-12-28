# Kubernetes Sidecar Monitoring and Debugging Guide

## 1. Enhanced Kubectl Debugging Commands

### Pod-level Debugging
```bash
# Get detailed pod information
kubectl describe pod -l app=qsm-julia-sidecar

# Check pod logs from both containers
kubectl logs -l app=qsm-julia-sidecar -c qsm --tail=100 -f
kubectl logs -l app=qsm-julia-sidecar -c julia-service --tail=100 -f

# View logs from both containers simultaneously
kubectl logs -l app=qsm-julia-sidecar --all-containers=true -f

# Get previous container logs (if containers restarted)
kubectl logs -l app=qsm-julia-sidecar -c qsm --previous
kubectl logs -l app=qsm-julia-sidecar -c julia-service --previous

# Execute into specific container for debugging
kubectl exec -it <pod-name> -c qsm -- /bin/bash
kubectl exec -it <pod-name> -c julia-service -- /bin/bash

# Test connectivity between containers
kubectl exec -it <pod-name> -c qsm -- curl http://localhost:8000/health
kubectl exec -it <pod-name> -c qsm -- netstat -tuln
```

### Network Debugging
```bash
# Check network policies
kubectl get networkpolicies

# Check service endpoints
kubectl get endpoints qsm-julia-svc

# Describe the service
kubectl describe service qsm-julia-svc

# Port forward for external debugging
kubectl port-forward deployment/qsm-julia-sidecar 8000:8000
kubectl port-forward deployment/qsm-julia-sidecar 8080:80
```

## 2. Enhanced Manifest with Better Observability

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-qsm-julia
  namespace: default
  annotations:
    azure.workload.identity/client-id: "f6f41384-8515-4dfe-ba7e-28c6bb5a190f"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qsm-julia-sidecar
  namespace: default
spec:
  replicas: 4
  selector:
    matchLabels:
      app: qsm-julia-sidecar
  template:
    metadata:
      labels:
        app: qsm-julia-sidecar
        azure.workload.identity/use: "true"
      annotations:
        # Enable Prometheus scraping
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: sa-qsm-julia
      containers:
      - name: qsm
        image: cdsoptmzprod.azurecr.io/cdsqsmimg:__QSMIMG__
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          name: http-qsm
        - containerPort: 9090
          name: metrics-qsm
        env:
        - name: QSM_ENVIRONMENT
          value: "prod"
        - name: JULIA_SERVICE_URL
          value: "http://localhost:8000"
        - name: LOG_LEVEL
          value: "DEBUG"
        resources:
          requests:
            memory: "2.5Gi"
            cpu: "1.5"
          limits:
            memory: "4Gi"
            cpu: "2.5"
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        
      - name: julia-service
        image: cdsoptmzprod.azurecr.io/julia-service:__JULIA__
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000
          name: http-julia
        - containerPort: 9091
          name: metrics-julia
        env:
        - name: CLUSTER
          value: "prod"
        - name: LOG_LEVEL
          value: "DEBUG"
        resources:
          requests:
            memory: "16Gi"
            cpu: "4"
          limits:
            memory: "20Gi"
            cpu: "5"
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5
          
      # Optional: Add logging sidecar for centralized logs
      - name: fluent-bit
        image: fluent/fluent-bit:latest
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log
      volumes:
      - name: shared-logs
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: qsm-julia-svc
  namespace: default
  labels:
    app: qsm-julia-sidecar
spec:
  type: LoadBalancer
  ports:
  - name: http-qsm
    port: 80
    targetPort: http-qsm
  - name: http-julia
    port: 8000
    targetPort: http-julia
  - name: metrics-qsm
    port: 9090
    targetPort: metrics-qsm
  - name: metrics-julia
    port: 9091
    targetPort: metrics-julia
  selector:
    app: qsm-julia-sidecar
```

## 3. Application-Level Monitoring Code

### QSM Service Monitoring (Example in Python/Go)
```python
import time
import logging
import requests
from prometheus_client import Counter, Histogram, start_http_server

# Metrics
REQUEST_COUNT = Counter('qsm_requests_total', 'Total QSM requests', ['status'])
REQUEST_DURATION = Histogram('qsm_request_duration_seconds', 'QSM request duration')
JULIA_REQUEST_COUNT = Counter('julia_requests_total', 'Total requests to Julia', ['status'])
JULIA_REQUEST_DURATION = Histogram('julia_request_duration_seconds', 'Julia request duration')

class QSMService:
    def __init__(self):
        self.julia_url = "http://localhost:8000"
        self.logger = logging.getLogger(__name__)
        
    @REQUEST_DURATION.time()
    def process_request(self, request_data):
        try:
            self.logger.info(f"Processing request: {request_data.get('id', 'unknown')}")
            
            # Send to Julia service with monitoring
            with JULIA_REQUEST_DURATION.time():
                response = self.send_to_julia(request_data)
            
            REQUEST_COUNT.labels(status='success').inc()
            return response
            
        except Exception as e:
            self.logger.error(f"Error processing request: {str(e)}")
            REQUEST_COUNT.labels(status='error').inc()
            raise
    
    def send_to_julia(self, data):
        try:
            self.logger.debug(f"Sending to Julia: {data}")
            response = requests.post(f"{self.julia_url}/optimize", json=data, timeout=300)
            
            if response.status_code == 200:
                JULIA_REQUEST_COUNT.labels(status='success').inc()
                self.logger.info(f"Julia response received: {response.status_code}")
                return response.json()
            else:
                JULIA_REQUEST_COUNT.labels(status='error').inc()
                self.logger.error(f"Julia service error: {response.status_code} - {response.text}")
                response.raise_for_status()
                
        except requests.exceptions.Timeout:
            JULIA_REQUEST_COUNT.labels(status='timeout').inc()
            self.logger.error("Julia service timeout")
            raise
        except requests.exceptions.ConnectionError:
            JULIA_REQUEST_COUNT.labels(status='connection_error').inc()
            self.logger.error("Julia service connection error")
            raise

# Start metrics server
start_http_server(9090)
```

## 4. Distributed Tracing Setup

### Using Jaeger for Request Tracing
```yaml
# Add to your deployment
- name: JAEGER_AGENT_HOST
  value: "jaeger-agent.default.svc.cluster.local"
- name: JAEGER_SERVICE_NAME
  value: "qsm-julia-sidecar"
```

## 5. Advanced Debugging Techniques

### Network Analysis
```bash
# Install network tools in debugging pod
kubectl run debug --image=nicolaka/netshoot -it --rm

# From debug pod, test connectivity
nslookup qsm-julia-svc
curl -v http://qsm-julia-svc:80/health
curl -v http://qsm-julia-svc:8000/health

# Check DNS resolution within the pod
kubectl exec -it <pod-name> -c qsm -- nslookup localhost
kubectl exec -it <pod-name> -c qsm -- netstat -tlnp
```

### Performance Analysis
```bash
# Resource usage per container
kubectl top pod -l app=qsm-julia-sidecar --containers

# Get detailed resource metrics
kubectl describe pod <pod-name> | grep -A 10 "Containers:"

# Check for OOM kills or restarts
kubectl get events --sort-by='.lastTimestamp' | grep <pod-name>
```

## 6. Monitoring Dashboards

### Prometheus Queries
```promql
# Request rate
rate(qsm_requests_total[5m])

# Error rate
rate(qsm_requests_total{status="error"}[5m]) / rate(qsm_requests_total[5m])

# Request duration
histogram_quantile(0.95, rate(qsm_request_duration_seconds_bucket[5m]))

# Julia service availability
up{job="julia-service"}

# Container restarts
increase(kube_pod_container_status_restarts_total[1h])
```

## 7. Specific Debugging for Complex Optimization Requests

### Your JSON Payload Analysis
Based on your nutritional optimization request, here are targeted debugging strategies:

```bash
# Monitor payload size and processing time
kubectl logs -l app=qsm-julia-sidecar -c qsm | grep -E "(payload_size|processing_time|ingredients_count|nutrients_count)"

# Check for JSON parsing errors
kubectl logs -l app=qsm-julia-sidecar -c julia-service | grep -i "json\|parse\|invalid"

# Monitor memory usage during large requests
kubectl top pod -l app=qsm-julia-sidecar --containers

# Check for optimization timeouts (your Julia optimization might be complex)
kubectl logs -l app=qsm-julia-sidecar -c qsm | grep -i "timeout\|502\|504"
```

### Enhanced Request Monitoring Code
```python
import json
import sys
from datetime import datetime

class OptimizationRequestMonitor:
    def log_request_summary(self, request_data):
        """Log key metrics about the optimization request"""
        summary = {
            "timestamp": datetime.utcnow().isoformat(),
            "request_type": "optimization",
            "locations_count": len(request_data.get("Locations", [])),
            "total_ingredients": 0,
            "total_nutrients": 0,
            "payload_size_bytes": len(json.dumps(request_data))
        }
        
        for location in request_data.get("Locations", []):
            ingredients = location.get("Ingredients", [])
            summary["total_ingredients"] += len(ingredients)
            
            for ingredient in ingredients:
                summary["total_nutrients"] += len(ingredient.get("NutrientLevels", []))
        
        self.logger.info(f"REQUEST_SUMMARY: {json.dumps(summary)}")
        
        # Alert on unusually large requests
        if summary["payload_size_bytes"] > 10 * 1024 * 1024:  # > 10MB
            self.logger.warning(f"LARGE_PAYLOAD: {summary['payload_size_bytes']} bytes")
        
        if summary["total_ingredients"] > 1000:
            self.logger.warning(f"HIGH_COMPLEXITY: {summary['total_ingredients']} ingredients")

    def validate_request_structure(self, request_data):
        """Validate the request structure before sending to Julia"""
        errors = []
        
        if not isinstance(request_data.get("Locations"), list):
            errors.append("Locations must be an array")
            
        for i, location in enumerate(request_data.get("Locations", [])):
            if not isinstance(location.get("Ingredients"), list):
                errors.append(f"Location[{i}].Ingredients must be an array")
                continue
                
            for j, ingredient in enumerate(location.get("Ingredients", [])):
                if not ingredient.get("IngredientId"):
                    errors.append(f"Location[{i}].Ingredients[{j}].IngredientId is required")
                
                if ingredient.get("Cost") is None:
                    errors.append(f"Location[{i}].Ingredients[{j}].Cost is required")
                
                nutrients = ingredient.get("NutrientLevels", [])
                for k, nutrient in enumerate(nutrients):
                    if not nutrient.get("NutrientId"):
                        errors.append(f"Location[{i}].Ingredients[{j}].NutrientLevels[{k}].NutrientId missing")
        
        if errors:
            self.logger.error(f"REQUEST_VALIDATION_ERRORS: {json.dumps(errors)}")
            return False
        return True
```

### Memory and Timeout Configuration Updates
```yaml
# Updated container configs for large optimization requests
containers:
- name: qsm
  resources:
    requests:
      memory: "4Gi"      # Increased for large JSON processing
      cpu: "2"
    limits:
      memory: "8Gi"      # Increased limits
      cpu: "4"
  env:
  - name: HTTP_TIMEOUT
    value: "600"         # 10 minute timeout for complex optimizations
  - name: MAX_REQUEST_SIZE
    value: "50MB"        # Allow larger payloads

- name: julia-service
  resources:
    requests:
      memory: "20Gi"     # Increased for optimization algorithms
      cpu: "6"
    limits:
      memory: "32Gi"     # More memory for complex problems
      cpu: "8"
  env:
  - name: JULIA_OPTIMIZATION_TIMEOUT
    value: "540"         # 9 minute timeout (less than QSM timeout)
  - name: JULIA_GC_ENABLE
    value: "true"        # Enable garbage collection for memory management
```

### Specific Request Testing
```bash
# Create a test payload file
cat > test_optimization.json << 'EOF'
{
  "Locations": [
    {
      "Ingredients": [
        {
          "IngredientId": "test-id",
          "Available": true,
          "Global": true,
          "Cost": 6610.0,
          "NutrientLevels": [
            {"NutrientId": "nutrient-1", "Level": 30.0},
            {"NutrientId": "nutrient-2", "Level": 0.22}
          ]
        }
      ]
    }
  ]
}
EOF

# Test with simplified payload first
kubectl exec -it <pod-name> -c qsm -- curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: test-001" \
  --data-binary @test_optimization.json \
  http://localhost:8000/optimize

# Monitor the test request
kubectl logs -f -l app=qsm-julia-sidecar -c julia-service | grep "test-001"
```

### Performance Analysis Queries
```bash
# Find slow optimization requests
kubectl logs -l app=qsm-julia-sidecar -c julia-service --since=1h | \
  grep "optimization_complete" | \
  awk '{print $NF}' | \
  sort -n | \
  tail -10

# Check memory usage patterns
kubectl logs -l app=qsm-julia-sidecar -c julia-service | \
  grep -E "memory_usage|gc_run|out_of_memory"

# Find failed optimizations
kubectl logs -l app=qsm-julia-sidecar -c julia-service | \
  grep -E "optimization_failed|error|exception" | \
  tail -20
```

## 8. Common Issues with Your Request Type

### 1. JSON Size and Memory Issues
- **Symptom**: OOMKilled containers or 413 Request Entity Too Large
- **Solution**: Increase memory limits, implement request streaming, or batch processing

### 2. Optimization Complexity Timeouts  
- **Symptom**: 504 Gateway Timeout, incomplete responses
- **Solution**: Implement progress callbacks, increase timeouts, or problem decomposition

### 3. Numerical Precision Issues
- **Symptom**: Inconsistent results, optimization failures
- **Solution**: Validate nutrient levels, check for NaN/Inf values, implement bounds checking

### 4. Ingredient/Nutrient ID Validation
- **Symptom**: Optimization errors, constraint violations
- **Solution**: Pre-validate all IDs exist in your database, implement ID caching

### Debugging Commands for Your Specific Case
```bash
# Check for ingredient/nutrient processing errors
kubectl logs -l app=qsm-julia-sidecar -c julia-service | grep -E "IngredientId|NutrientId|constraint"

# Monitor optimization progress
kubectl logs -f -l app=qsm-julia-sidecar -c julia-service | grep -E "optimization|iteration|solution"

# Check for memory pressure during optimization
kubectl describe pod -l app=qsm-julia-sidecar | grep -A 5 -B 5 "memory"
```
