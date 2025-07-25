# 🚀 Getting Started - Complete Flow

This guide provides a comprehensive step-by-step flow for deploying and testing the KEDA HTTP scaling implementation.

## 📋 Prerequisites

Before starting, ensure you have:
- ✅ **Kubernetes cluster** running (Kind, Minikube, or cloud cluster)
- ✅ **kubectl** configured and connected to your cluster
- ✅ **helm** installed for KEDA deployment
- ✅ **Terminal access** with bash support

### Verify Prerequisites
```bash
# Check kubectl connection
kubectl cluster-info

# Check helm installation  
helm version

# Verify cluster nodes
kubectl get nodes
```

## 🎯 Complete Recommended Flow

### Phase 1: Understanding the System

#### Step 1: Review System Status
```bash
# Read the current configuration
cat CURRENT_STATUS.md

# Understand the workflow structure
ls -la  # See 1-setup/, 2-deploy/, 3-test/
```

**What to expect:**
- All services configured for scale-to-zero (0 min replicas)
- Hybrid fix available but not applied
- Complete testing suite ready

### Phase 2: Deployment

#### Step 2: Deploy KEDA and Cell Architecture
```bash
cd 2-deploy
./deploy.sh all
```

**What this does:**
- Installs KEDA core
- Installs KEDA HTTP add-on
- Deploys Cell A (e-commerce services)
- Deploys Cell B (order processing services)
- Creates HTTPScaledObjects for all services

**Expected output:**
```
✅ KEDA installed successfully
✅ KEDA HTTP add-on installed
✅ Cell A deployed
✅ Cell B deployed
✅ Ingress configured
```

#### Step 3: Verify Deployment
```bash
# Check KEDA pods
kubectl get pods -n keda

# Check cell deployments (should show 0/0 ready - this is correct!)
kubectl get deployments -n cell-a -n cell-b

# Check HTTPScaledObjects
kubectl get httpscaledobjects -A
```

### Phase 3: Network Setup

#### Step 4: Set Up Port Forwarding
```bash
# In a separate terminal window - keep this running
kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080
```

**Important:** Keep this terminal open throughout testing!

#### Step 5: Verify Connectivity
```bash
# Quick connectivity test
curl -H "Host: cell-a-gateway.local" http://localhost:8080/health
# Should return: {"status": "healthy", "cell": "cell-a"}
```

### Phase 4: Testing and Validation

#### Step 6: Run Basic Functionality Tests
```bash
cd ../3-test
./test-scaling.sh basic
```

**Expected scenarios:**
1. **✅ Gateway Scaling Works**: Gateways scale from 0→1 on first request
2. **⚠️ Internal Services May Fail**: Internal service calls might fail

#### Step 7A: If Tests Pass ✅
```bash
echo "🎉 All tests passed! Your scale-to-zero setup is working perfectly!"
# Proceed to load testing (Step 8)
```

#### Step 7B: If Internal Service Tests Fail ⚠️
```bash
echo "Internal service communication failed - applying hybrid fix..."
cd ../1-setup
./apply-hybrid-fix.sh

# Re-test after applying fix
cd ../3-test
./test-scaling.sh basic
```

**What the hybrid fix does:**
- Keeps gateways at scale-to-zero (cost optimization)
- Sets internal services to min 1 replica (reliability)
- Updates ConfigMaps for direct service communication

### Phase 5: Load Testing (Optional)

#### Step 8: Set Up K6 Load Testing
```bash
cd ../1-setup
./quick-k6-setup.sh
```

#### Step 9: Run Load Tests
```bash
cd ../3-test

# Start with basic test (12 minutes)
./run-load-tests.sh basic

# If basic test passes, run full suite
./run-load-tests.sh all
```

**Load test scenarios:**
- **Basic**: Gradual ramp-up testing overall system
- **Spike**: Sudden traffic bursts
- **Services**: Internal service scaling focus
- **Cross-cell**: Inter-cell communication patterns

### Phase 6: Monitoring and Analysis

#### Step 10: Real-time Monitoring
```bash
# In another terminal - watch scaling in action
kubectl get pods -n cell-a -n cell-b -w

# Check HTTPScaledObject status
kubectl get httpscaledobjects -A

# View scaling events
kubectl get events -n cell-a -n cell-b --sort-by='.lastTimestamp'
```

#### Step 11: Review Results
```bash
# Check load test results (if ran)
ls results-*.json

# View scaling logs
ls pod-scaling-*.log

# HTTPScaledObject details
kubectl describe httpscaledobject cell-a-gateway -n cell-a
```

## 🎯 Success Criteria

Your system is working correctly if:
- ✅ **Gateway Scaling**: Gateways scale from 0→N based on HTTP traffic
- ✅ **Service Communication**: All endpoints respond correctly
- ✅ **Load Handling**: System scales appropriately under load
- ✅ **Scale Down**: Services scale back to minimum when idle

## 🔧 Troubleshooting Common Issues

### Issue 1: KEDA Pods Not Running
```bash
# Check KEDA installation
kubectl get pods -n keda
kubectl logs -n keda deployment/keda-operator
```

### Issue 2: Port Forwarding Connection Refused
```bash
# Restart port forwarding
kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080

# Test connectivity
curl -H "Host: cell-a-gateway.local" http://localhost:8080/health
```

### Issue 3: Internal Service Communication Fails
```bash
# Apply hybrid fix
cd 1-setup
./apply-hybrid-fix.sh

# Verify fix applied
kubectl get httpscaledobjects -A
# Should show min: 1 for internal services
```

### Issue 4: Services Not Scaling
```bash
# Check HTTPScaledObject status
kubectl describe httpscaledobject <name> -n <namespace>

# Check KEDA HTTP interceptor logs
kubectl logs -n keda deployment/keda-add-on-http-interceptor
```

## 🚀 Next Steps After Success

1. **Production Deployment**: Use hybrid configuration for reliability
2. **Monitoring Setup**: Implement metrics collection
3. **Application Updates**: Consider adding Host headers for full cross-cell optimization
4. **Scaling Tuning**: Adjust targetValue and scaledownPeriod based on your traffic patterns

## 📚 Additional Resources

- **Detailed Guides**: Each directory (1-setup/, 2-deploy/, 3-test/) has comprehensive READMEs
- **Configuration Reference**: `docs/README.md`
- **Success Summary**: `docs/FINAL_SUCCESS_SUMMARY.md`
- **Architecture Details**: `docs/CONVERSION_SUMMARY.md`

## 🎉 Congratulations!

You now have a fully functional KEDA HTTP scaling system with:
- ✅ **Scale-to-zero capability** for cost optimization
- ✅ **Automatic scaling** based on HTTP traffic
- ✅ **Professional testing suite** for validation
- ✅ **Production-ready configuration** options
- ✅ **Comprehensive monitoring** tools

Your cell-based architecture is now modern, cost-effective, and auto-scaling! 🌟 