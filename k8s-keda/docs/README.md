# KEDA HTTP Scaling for Cell-Based Architecture

This directory contains Kubernetes manifests for deploying the cell-based architecture test suite with KEDA HTTP scaling. The original deployments have been converted to scale from 0 based on HTTP traffic.

## Architecture Overview

### KEDA HTTP Add-on Integration
- All services start with 0 replicas
- KEDA HTTP Add-on intercepts traffic and scales services on-demand
- Services scale down to 0 when idle
- Cross-cell communication is maintained through proper routing

### Scaling Behavior
- **Min Replicas**: 0 (scale to zero when idle)
- **Max Replicas**: 5 per service
- **Target Pending Requests**: 10 per replica
- **Scale Down Period**: 30 seconds of no traffic

## Prerequisites

1. **KEDA Installation**:
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
```

2. **KEDA HTTP Add-on Installation**:
```bash
helm install keda-http-add-on kedacore/keda-add-ons-http \
  --namespace keda \
  --create-namespace
```

3. **Verify Installation**:
```bash
kubectl get pods -n keda
kubectl get svc -n keda keda-add-ons-http-interceptor-proxy
```

## Deployment

### Option 1: Deploy All Cells
```bash
# Create namespaces
kubectl apply -f namespaces.yaml

# Deploy Cell A with KEDA scaling
kubectl apply -f cell-a/

# Deploy Cell B with KEDA scaling  
kubectl apply -f cell-b/

# Apply ingress configuration
kubectl apply -f ingress.yaml
```

### Option 2: Deploy Individual Cells
```bash
# Deploy only Cell A
kubectl apply -f namespaces.yaml
kubectl apply -f cell-a/

# Deploy only Cell B  
kubectl apply -f namespaces.yaml
kubectl apply -f cell-b/
```

## Testing HTTP Scaling

### Quick Testing
#### 1. Port Forward KEDA HTTP Interceptor
```bash
kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080
```

#### 2. Basic Functionality Tests
```bash
# Run comprehensive test suite
./test-scaling.sh basic

# Interactive testing mode
./test-scaling.sh interactive

# Working features demo
./demo-working-features.sh
```

#### 3. Manual Testing
```bash
# Test Cell A Services (will scale from 0)
curl -H "Host: cell-a-gateway.local" http://localhost:8080/users
curl -H "Host: cell-a-gateway.local" http://localhost:8080/products

# Test Cell B Services (will scale from 0)
curl -H "Host: cell-b-gateway.local" http://localhost:8080/orders
curl -H "Host: cell-b-gateway.local" http://localhost:8080/payments

# Watch scaling in action
kubectl get pods -n cell-a -n cell-b -w
```

### Load Testing with K6
#### Quick K6 Setup
```bash
# Install k6 and run basic connectivity test
./quick-k6-setup.sh

# Or install k6 manually:
# Ubuntu: sudo apt-get install k6
# macOS: brew install k6
```

#### Load Test Suite
```bash
# Individual load tests
./run-load-tests.sh basic      # Basic scaling test (12 min)
./run-load-tests.sh spike      # Spike test (7 min)
./run-load-tests.sh services   # Service scaling test (9 min)
./run-load-tests.sh cross-cell # Cross-cell test (6 min)

# Complete test suite (~35 minutes)
./run-load-tests.sh all

# Real-time pod monitoring during tests
./run-load-tests.sh monitor
```

#### Load Test Features
- **Gateway Scale-to-Zero**: Validates 0→N scaling under load
- **Service Scaling**: Tests internal service scaling patterns
- **Spike Testing**: Sudden traffic burst handling
- **Cross-Cell Analysis**: Communication pattern validation
- **Performance Metrics**: Response times, error rates, throughput
- **Pod Monitoring**: Real-time scaling event tracking

#### Understanding Load Test Results
```bash
# View generated results
ls results-*.json              # K6 performance results
ls pod-scaling-*.log           # Pod scaling monitoring logs
cat cross-cell-summary.json    # Cross-cell communication analysis

# Monitor HTTPScaledObjects during/after tests
kubectl get httpscaledobjects -A
kubectl describe httpscaledobject cell-a-gateway -n cell-a
```

## Monitoring

### View HTTPScaledObjects
```bash
kubectl get httpscaledobjects -A
kubectl describe httpscaledobject cell-a-gateway -n cell-a
```

### Monitor Scaling Events
```bash
kubectl get events -n cell-a --sort-by='.lastTimestamp'
kubectl get events -n cell-b --sort-by='.lastTimestamp'
```

### View KEDA Logs
```bash
kubectl logs -n keda deployment/keda-operator
kubectl logs -n keda deployment/keda-add-on-http-operator
```

## Key Differences from Original Deployment

1. **Replicas**: Changed from 1 to 0 in all Deployments
2. **HTTPScaledObject**: Added for each service to enable HTTP-based scaling
3. **Host-based Routing**: Services are accessed via specific hostnames through the KEDA interceptor
4. **Scaling Configuration**: Configured for automatic scale-to-zero with HTTP traffic-based scaling

## Troubleshooting

### Services Not Scaling Up
- Check HTTPScaledObject status: `kubectl describe httpscaledobject <name> -n <namespace>`
- Verify KEDA HTTP interceptor is running: `kubectl get pods -n keda`
- Check if Host header matches HTTPScaledObject spec

### Cross-Cell Communication Issues
- Ensure both cells are deployed
- Verify service URLs in ConfigMaps point to correct cluster DNS names
- Check network policies allow cross-namespace communication

### Traffic Not Reaching Services
- Verify ingress configuration
- Check KEDA HTTP interceptor proxy service
- Ensure Host headers are correctly set in requests 