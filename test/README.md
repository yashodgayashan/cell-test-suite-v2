# k6 Load Testing Suite for Cell-Based Architecture

A comprehensive load testing suite using k6 to test the cell-based architecture with focus on scale-to-zero functionality powered by eBPF.

## 🚀 Quick Start

### Prerequisites

1. **k6 Installation**:
   ```bash
   # Linux
   sudo gpg -k
   sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
   echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
   sudo apt-get update
   sudo apt-get install k6
   
   # macOS
   brew install k6
   
   # Windows
   choco install k6
   ```

2. **Python (for analysis)**:
   ```bash
   pip install matplotlib  # Optional, for charts
   ```

3. **Running Services**: Ensure your cell-based architecture is deployed and accessible.

### Quick Test Run

```bash
# Basic load test
./run-load-test.sh --test-type load --duration 5m --vus 20

# Scale-to-zero test (takes ~20 minutes)
./run-load-test.sh --test-type scale-to-zero --use-cluster-ip

# Spike test
./run-load-test.sh --test-type spike --vus 100
```

## 📊 Test Types

### 1. Load Test (`k6-load-test.js`)

**Purpose**: General performance testing with realistic user scenarios.

**Features**:
- Multi-stage load progression (10 → 50 → 100 → 200 users)
- Realistic user flows (30% user management, 30% product management, 30% e2e orders, 10% health checks)
- Cross-cell communication testing
- Comprehensive metrics collection

**Usage**:
```bash
./run-load-test.sh --test-type load --duration 10m --vus 50
```

**Scenarios Tested**:
- User creation, retrieval, updates
- Product management and inventory
- End-to-end order processing with payments
- Cross-cell data access
- Health check monitoring

### 2. Scale-to-Zero Test (`k6-scale-to-zero-test.js`)

**Purpose**: Specifically tests eBPF-powered scale-to-zero functionality.

**Features**:
- Multi-scenario execution (main test, background traffic, spike after idle)
- Cold start detection and measurement
- Scale-up time tracking
- Custom metrics for scaling events

**Usage**:
```bash
./run-load-test.sh --test-type scale-to-zero
```

**Test Phases**:
1. **Warmup**: Initial service activation
2. **Activity Generation**: Create load to keep services active
3. **Idle Period**: 65-second wait for scale-down
4. **Cold Start Test**: Measure scale-up performance
5. **Sustained Load**: Verify post-scale-up functionality

**Custom Metrics**:
- `scale_up_time`: Time taken for services to respond after scale-up
- `cold_start_requests`: Number of requests that triggered cold starts
- `scaling_events`: Count of scaling events detected

### 3. Spike Test

**Purpose**: Tests system behavior under sudden load spikes.

**Features**:
- Rapid scaling from 10 to 200 users
- Sustained spike testing
- Graceful scale-down verification

**Load Pattern**:
```
Users: 10 ────▲ 200 ──── 200 ────▼ 10 ──── 0
Time:  2m   30s   1m   30s   2m   30s
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CELL_A_URL` | `http://cell-a.local` | Cell A gateway URL |
| `CELL_B_URL` | `http://cell-b.local` | Cell B gateway URL |
| `USE_CLUSTER_IP` | `false` | Use cluster IPs instead of external URLs |
| `CELL_A_CLUSTER_IP` | `http://cell-a-gateway.cell-a.svc.cluster.local:8010` | Cell A cluster IP |
| `CELL_B_CLUSTER_IP` | `http://cell-b-gateway.cell-b.svc.cluster.local:8020` | Cell B cluster IP |

### Running from Kubernetes

When running tests from within the cluster:

```bash
./run-load-test.sh --use-cluster-ip --test-type load
```

### Custom URLs

For local development or custom deployments:

```bash
./run-load-test.sh \
  --cell-a-url http://localhost:8010 \
  --cell-b-url http://localhost:8020 \
  --test-type load
```

## 📈 Results Analysis

### Automatic Analysis

Each test run generates:
- **JSON results**: Raw k6 metrics
- **Summary JSON**: Processed metrics summary
- **Text report**: Human-readable analysis
- **Charts PDF**: Visual performance analysis (if matplotlib available)

### Manual Analysis

Use the Python analysis tool:

```bash
# Analyze results
python3 analyze-results.py test-results/load_test_20231201_143022.json

# Custom output directory
python3 analyze-results.py results.json --output-dir ./my-analysis

# Skip chart generation
python3 analyze-results.py results.json --no-charts
```

### Sample Analysis Output

```
============================================================
k6 LOAD TEST ANALYSIS REPORT
============================================================
Generated: 2023-12-01 14:35:22

📊 BASIC METRICS
--------------------
Total Requests: 12,847
Request Rate: 21.41 req/s
Error Rate: 0.23%

⏱️  RESPONSE TIMES (ms)
-------------------------
Average: 234.56
Minimum: 45.23
Maximum: 1,847.92
50th percentile: 198.45
90th percentile: 456.78
95th percentile: 623.45
99th percentile: 1,234.56

🔄 SCALE-TO-ZERO METRICS
--------------------------
Cold Starts Detected: 3
Average Scale-up Time: 2,345.67 ms
Maximum Scale-up Time: 4,567.89 ms
90th percentile Scale-up: 3,456.78 ms

🎯 PERFORMANCE ASSESSMENT
----------------------------
✅ Error Rate: EXCELLENT (< 1%)
✅ Response Time: GOOD (P95 < 2s)
```

## 🎯 Performance Thresholds

### Load Test Thresholds
- **P95 Response Time**: < 2000ms
- **Error Rate**: < 5%
- **Custom Error Rate**: < 10%

### Scale-to-Zero Test Thresholds
- **P95 Response Time**: < 5000ms (allows for cold starts)
- **Error Rate**: < 10% (allows for scaling transitions)
- **P90 Scale-up Time**: < 10000ms

## 🔍 Monitoring During Tests

### Real-time Monitoring

Monitor your eBPF application logs:
```bash
kubectl logs -f deployment/my-ebpf-app -n default
```

Watch for scale events:
```bash
kubectl get pods -w -n cell-a
kubectl get pods -w -n cell-b
```

### Metrics to Watch

1. **Service Response Times**
2. **Pod Scaling Events**
3. **eBPF Log Output**
4. **Network Traffic Patterns**
5. **Resource Utilization**

## 🚨 Troubleshooting

### Common Issues

1. **Services Not Responding**:
   ```bash
   # Check service health
   curl http://cell-a.local/health
   curl http://cell-b.local/health
   
   # Check cluster IPs
   kubectl get services -A
   ```

2. **High Error Rates**:
   - Verify service scaling configurations
   - Check resource limits
   - Monitor eBPF application logs

3. **Slow Scale-up Times**:
   - Review eBPF scale-down timeout settings
   - Check container image pull times
   - Verify resource availability

### Debug Mode

Run tests with verbose output:
```bash
k6 run --verbose k6-load-test.js
```

### Scale-to-Zero Debug

Monitor eBPF logs during scale-to-zero test:
```bash
# Terminal 1: Run test
./run-load-test.sh --test-type scale-to-zero

# Terminal 2: Monitor eBPF
kubectl logs -f deployment/my-ebpf-app -n default
```

## 📋 Test Scenarios Detail

### User Management Flow (30% of traffic)
1. Create user via Cell A
2. Retrieve user by ID
3. Update user information
4. List all users
5. Cross-cell user access via Cell B

### Product Management Flow (30% of traffic)
1. Create product via Cell A
2. Retrieve product by ID
3. Update product stock
4. List all products
5. Cross-cell product access via Cell B

### End-to-End Order Flow (30% of traffic)
1. Create user in Cell A
2. Create product in Cell A
3. Create order in Cell B (validates user/product)
4. Process payment in Cell B
5. Update order status
6. Cross-cell order verification
7. Payment status checks

### Health Check Flow (10% of traffic)
1. Cell A health endpoint
2. Cell B health endpoint
3. Readiness checks

## 🎨 Customization

### Adding Custom Test Scenarios

1. Create new test function in `k6-load-test.js`:
```javascript
function customScenario() {
  group('Custom Scenario', () => {
    // Your test logic here
    makeRequest('GET', `${CELL_A_URL}/custom-endpoint`);
  });
}
```

2. Add to scenario distribution:
```javascript
export default function () {
  const scenario = Math.random();
  if (scenario < 0.25) {
    customScenario();  // 25% of traffic
  }
  // ... other scenarios
}
```

### Custom Metrics

Add custom metrics for specific use cases:
```javascript
import { Counter, Trend } from 'k6/metrics';

const customMetric = new Counter('custom_events');
const customDuration = new Trend('custom_duration');

// Use in test
customMetric.add(1);
customDuration.add(responseTime);
```

## 📚 Additional Resources

- [k6 Documentation](https://k6.io/docs/)
- [k6 JavaScript API](https://k6.io/docs/javascript-api/)
- [Performance Testing Best Practices](https://k6.io/docs/testing-guides/)
- [eBPF Scale-to-Zero Architecture](../README.md)

## 🤝 Contributing

1. Add new test scenarios in the appropriate test files
2. Update thresholds based on performance requirements
3. Enhance analysis scripts for better insights
4. Add documentation for new features

## 📄 License

This testing suite is part of the cell-based architecture research project. 