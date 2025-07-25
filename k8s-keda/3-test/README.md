# K6 Load Testing Suite for KEDA HTTP Scaling

This directory contains comprehensive k6 load tests designed to demonstrate and validate KEDA HTTP scaling behavior in the cell-based architecture.

## 🎯 Test Objectives

### 1. Validate KEDA HTTP Scaling
- Demonstrate gateway scale-from-zero functionality
- Test service scaling under various load patterns
- Verify scaling thresholds and timing
- Monitor resource utilization during scaling events

### 2. Performance Benchmarking
- Measure response times during scaling events
- Identify performance bottlenecks
- Test system behavior under different load patterns
- Validate scaling configuration effectiveness

### 3. Cross-Cell Communication Analysis
- Test communication patterns between cells
- Identify Host header requirements for full scale-to-zero
- Compare same-cell vs cross-cell performance

## 📋 Test Suite Overview

| Test | Duration | Purpose | Load Pattern |
|------|----------|---------|--------------|
| `basic-scaling-test.js` | 12 min | Overall system scaling | Gradual ramp: 0→10→50 VUs |
| `spike-test.js` | 7 min | Sudden traffic bursts | Spikes: 5→100→200 VUs |
| `service-load-test.js` | 9 min | Internal service scaling | Service-focused: 0→30 VUs |
| `cross-cell-test.js` | 6 min | Cross-cell communication | Mixed cell patterns |

## 🚀 Quick Start

### Prerequisites
1. **k6 Installation**:
   ```bash
   # Ubuntu/Debian
   sudo gpg -k && sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
   echo 'deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main' | sudo tee /etc/apt/sources.list.d/k6.list
   sudo apt-get update && sudo apt-get install k6
   
   # macOS
   brew install k6
   ```

2. **KEDA Deployment**:
   ```bash
   ./deploy.sh all
   ```

3. **Port Forwarding**:
   ```bash
   kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080
   ```

### Running Tests

```bash
# Single tests
./run-load-tests.sh basic      # Basic scaling test
./run-load-tests.sh spike      # Spike test
./run-load-tests.sh services   # Service scaling test
./run-load-tests.sh cross-cell # Cross-cell test

# Complete test suite (~35 minutes)
./run-load-tests.sh all

# Utilities
./run-load-tests.sh monitor    # Real-time pod monitoring
./run-load-tests.sh clean      # Clean up test artifacts
```

## 📊 Test Details

### Basic Scaling Test (`basic-scaling-test.js`)
**Duration**: 12 minutes  
**Load Pattern**:
- 0→10 VUs over 2 minutes (ramp-up)
- 10 VUs for 3 minutes (steady state)
- 10→50 VUs over 2 minutes (scale-up)
- 50 VUs for 3 minutes (high load)
- 50→0 VUs over 2 minutes (scale-down)

**Tests**:
- Gateway health endpoints
- Service endpoints (users, products, orders, payments)
- Response times and error rates
- Scaling behavior validation

**Thresholds**:
- 95% of requests < 2000ms
- Error rate < 10%

### Spike Test (`spike-test.js`)
**Duration**: 7 minutes  
**Load Pattern**:
- 5 VUs for 2 minutes (baseline)
- Spike to 100 VUs for 30 seconds
- 100 VUs for 2 minutes (sustained)
- Spike to 200 VUs for 30 seconds
- 200 VUs for 1 minute (peak)
- Scale down to 0 in 1 minute

**Tests**:
- Gateway responsiveness to traffic spikes
- Scaling speed and effectiveness
- System stability during rapid changes

**Thresholds**:
- 95% of requests < 5000ms (higher tolerance for spikes)
- Error rate < 15%

### Service Load Test (`service-load-test.js`)
**Duration**: 9 minutes  
**Load Pattern**:
- Gradual ramp: 0→5→15→30 VUs
- Mix of GET and POST operations
- Focus on internal service scaling

**Tests**:
- User service scaling
- Product service scaling
- Order service scaling
- Payment service scaling
- Create operations (POST requests)

**Thresholds**:
- 95% of requests < 3000ms
- Service response time 90% < 2000ms
- Error rate < 10%

### Cross-Cell Test (`cross-cell-test.js`)
**Duration**: 6 minutes  
**Load Pattern**:
- 0→3→8 VUs over 5 minutes
- Focus on cross-cell communication patterns

**Tests**:
- Cell A → Cell B communication
- Cell B → Cell A communication
- Same-cell communication (for comparison)
- Host header requirement analysis

**Thresholds**:
- 95% of requests < 4000ms
- Error rate < 30% (higher tolerance for cross-cell issues)

## 📈 Monitoring and Analysis

### Real-Time Monitoring
```bash
# Monitor pod scaling during tests
kubectl get pods -n cell-a -n cell-b -w

# Monitor HTTPScaledObjects
kubectl get httpscaledobjects -A -w

# View KEDA events
kubectl get events -n cell-a -n cell-b --sort-by='.lastTimestamp'
```

### Test Results
- **JSON Results**: `results-{test-name}-{timestamp}.json`
- **Pod Monitoring**: `pod-scaling-{test-name}-{timestamp}.log`
- **Cross-Cell Analysis**: `cross-cell-summary.json`

### Key Metrics to Monitor
1. **Scaling Metrics**:
   - Pod count changes over time
   - Scaling event frequency
   - Time to scale from 0→1
   - Time to scale down to 0

2. **Performance Metrics**:
   - Response time percentiles (p90, p95, p99)
   - Error rates by endpoint
   - Throughput (requests/second)

3. **KEDA Metrics**:
   - HTTPScaledObject status
   - Queue length (pending requests)
   - Scaling decisions and triggers

## 🎯 Expected Results

### Gateway Scaling
- **Scale-up**: Should scale from 0→1 within 10-30 seconds of first request
- **Scale-down**: Should scale to 0 after 30-60 seconds of no traffic
- **Performance**: Initial requests may have higher latency (cold start)

### Internal Service Scaling
- **Current Configuration**: All services scale to zero (0 min replicas)
- **Expected Behavior**: May fail when internal services are at 0 replicas
- **Scale-up**: Services should scale 0→1→2→3 based on load (if reachable)
- **Reliability Issue**: Internal service calls may fail with scale-to-zero

### 🔧 **If Tests Fail**
If internal service communication fails, apply the hybrid scaling fix:
```bash
cd ../1-setup && ./apply-hybrid-fix.sh
```
Then re-run tests: `./test-scaling.sh basic`

### Cross-Cell Communication
- **Current State**: Expected failures due to Host header requirements
- **Same-Cell**: Should work reliably (100% success rate)
- **Future**: Will improve with application code changes

## 🔧 Customizing Tests

### Modifying Load Patterns
Edit the `options.stages` array in test files:
```javascript
export let options = {
  stages: [
    { duration: '2m', target: 10 },  // Customize duration and target VUs
    { duration: '5m', target: 50 },
    { duration: '2m', target: 0 },
  ],
};
```

### Adding New Endpoints
Add to the `endpoints` array:
```javascript
const endpoints = [
  { host: 'cell-a-gateway.local', path: '/new-endpoint', name: 'New Test' },
  // ... existing endpoints
];
```

### Custom Thresholds
Modify the `thresholds` object:
```javascript
thresholds: {
  http_req_duration: ['p(95)<1000'],  // 95% under 1 second
  http_req_failed: ['rate<0.05'],     // 5% error rate
  errors: ['rate<0.05'],
},
```

## 🚨 Troubleshooting

### Common Issues

1. **k6 Not Found**:
   ```bash
   # Verify installation
   k6 version
   # If not found, reinstall following prerequisites
   ```

2. **Connection Refused**:
   ```bash
   # Check port forwarding
   kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080
   # Test connection
   curl -H "Host: cell-a-gateway.local" http://localhost:8080/health
   ```

3. **High Error Rates**:
   - Check KEDA deployment status
   - Verify service accounts exist
   - Check pod resource limits
   - Monitor scaling events

4. **Slow Scaling**:
   - Review HTTPScaledObject configurations
   - Check KEDA operator logs
   - Verify interceptor performance

### Debug Commands
```bash
# Check KEDA status
kubectl get pods -n keda
kubectl logs -n keda deployment/keda-operator

# Check HTTPScaledObjects
kubectl describe httpscaledobject -A

# Monitor scaling events
kubectl get events -A --sort-by='.lastTimestamp' | grep -i scale
```

## 📚 Further Reading

- [k6 Documentation](https://k6.io/docs/)
- [KEDA HTTP Add-on](https://keda.sh/docs/2.8/scalers/http/)
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Load Testing Best Practices](https://k6.io/docs/testing-guides/)

This load testing suite provides comprehensive validation of your KEDA HTTP scaling implementation and helps identify optimization opportunities. 