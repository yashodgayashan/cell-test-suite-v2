# 2️⃣ Deploy & Configuration

This directory contains all Kubernetes manifests and deployment scripts for the KEDA HTTP scaling cell architecture.

## 🚀 Deployment Script

### `deploy.sh`
**Main deployment orchestrator** - Handles complete KEDA and cell deployment
```bash
./deploy.sh all          # Complete deployment (KEDA + cells)
./deploy.sh install-keda # Install KEDA core only
./deploy.sh install-http # Install KEDA HTTP add-on only  
./deploy.sh deploy       # Deploy cells only
./deploy.sh status       # Show deployment status
./deploy.sh test-info    # Show testing instructions
```

## ⚙️ Kubernetes Manifests

### Core Infrastructure
- **`namespaces.yaml`** - Creates `cell-a` and `cell-b` namespaces
- **`serviceaccounts.yaml`** - Service accounts for both cells
- **`ingress.yaml`** - KEDA HTTP interceptor routing configuration

### Cell Configurations
- **`cells/cell-a/`** - Cell A (E-commerce services)
  - `gateway.yaml` - Gateway with HTTPScaledObject (scale-to-zero)
  - `user-service.yaml` - User service with KEDA scaling
  - `product-service.yaml` - Product service with KEDA scaling

- **`cells/cell-b/`** - Cell B (Order processing services)  
  - `gateway.yaml` - Gateway with HTTPScaledObject (scale-to-zero)
  - `order-service.yaml` - Order service with KEDA scaling
  - `payment-service.yaml` - Payment service with KEDA scaling

### Alternative Configurations
- **`hybrid-scaling.yaml`** - Alternative hybrid scaling configuration

## 🎯 Deployment Workflow

### Step 1: Install KEDA
```bash
./deploy.sh install-keda  # Installs KEDA core
./deploy.sh install-http  # Installs KEDA HTTP add-on
```

### Step 2: Deploy Cell Architecture
```bash
./deploy.sh deploy        # Deploys all cells and configurations
```

### Step 3: Verify Deployment
```bash
./deploy.sh status        # Check deployment status
kubectl get pods -n cell-a -n cell-b
kubectl get httpscaledobjects -A
```

### Quick Complete Deployment
```bash
./deploy.sh all           # Does everything in one command
```

## 🔧 Key Features

### KEDA HTTP Scaling Configuration
- **Scale-to-Zero**: All services start with 0 replicas
- **HTTP-based Scaling**: Services scale based on HTTP traffic
- **Request Rate Targeting**: 10 requests per replica target
- **Scale Down Period**: 30-60 seconds of idle time before scaling down

### Architecture Benefits
- **Cost Optimization**: Services scale to zero when idle
- **Automatic Scaling**: No manual intervention required
- **Traffic-based**: Scales based on actual load
- **Cross-cell Communication**: Maintains service connectivity

## 📊 Scaling Behavior

| Service Type | Min Replicas | Max Replicas | Scale Down Period |
|-------------|--------------|--------------|-------------------|
| Gateways | 0 | 5 | 30 seconds |
| Internal Services | 0 | 3 | 60 seconds |

**Note**: All services currently scale to zero. For production reliability, apply the hybrid fix:
```bash
cd ../1-setup && ./apply-hybrid-fix.sh
```
This sets internal services to min 1 replica while keeping gateways at scale-to-zero.

## 🔗 Required Port Forwarding

For testing and access:
```bash
kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080
```

## ➡️ Next Steps

After successful deployment, proceed to:
**3-test/** - Test scaling functionality and performance 