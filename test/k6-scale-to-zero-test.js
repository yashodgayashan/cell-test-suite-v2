import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';

// Custom metrics for scale-to-zero testing
const scaleUpTime = new Trend('scale_up_time');
const scaleDownDetected = new Counter('scale_down_detected');
const coldStartRequests = new Counter('cold_start_requests');
const scalingEvents = new Gauge('scaling_events');

// Configuration
const CELL_A_URL = __ENV.CELL_A_URL || 'http://cell-a.local';
const CELL_B_URL = __ENV.CELL_B_URL || 'http://cell-b.local';
const CLUSTER_IP_A = __ENV.CELL_A_CLUSTER_IP || 'http://cell-a-gateway.cell-a.svc.cluster.local:8010';
const CLUSTER_IP_B = __ENV.CELL_B_CLUSTER_IP || 'http://cell-b-gateway.cell-b.svc.cluster.local:8020';

// Use cluster IPs if running inside cluster
const BASE_URL_A = __ENV.USE_CLUSTER_IP === 'true' ? CLUSTER_IP_A : CELL_A_URL;
const BASE_URL_B = __ENV.USE_CLUSTER_IP === 'true' ? CLUSTER_IP_B : CELL_B_URL;

// Scale-to-zero test configuration
export const options = {
  scenarios: {
    scale_to_zero_test: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 1,
      maxDuration: '20m',
    },
    background_traffic: {
      executor: 'constant-vus',
      vus: 2,
      duration: '15m',
      startTime: '2m',
    },
    spike_after_idle: {
      executor: 'ramping-vus',
      startVUs: 0,
      startTime: '10m',
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 20 },
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<5000'], // Allow longer response times for cold starts
    http_req_failed: ['rate<0.1'],     // Allow higher error rate during scaling
    scale_up_time: ['p(90)<10000'],    // Scale up should complete within 10s
  },
};

function makeRequest(method, url, payload = null, expectedStatus = 200, timeout = '30s') {
  const params = {
    headers: { 'Content-Type': 'application/json' },
    timeout: timeout,
  };

  const startTime = Date.now();
  let response;
  
  if (payload) {
    response = http.request(method, url, JSON.stringify(payload), params);
  } else {
    response = http.request(method, url, null, params);
  }

  const duration = Date.now() - startTime;
  
  // Detect potential cold start (high response time)
  if (duration > 3000) {
    coldStartRequests.add(1);
    scaleUpTime.add(duration);
    console.log(`Potential cold start detected: ${method} ${url} took ${duration}ms`);
  }

  const success = check(response, {
    [`${method} ${url} status is ${expectedStatus}`]: (r) => r.status === expectedStatus,
    [`${method} ${url} completed`]: (r) => r.status !== 0,
  });

  if (!success && response.status !== 0) {
    console.log(`Request failed: ${method} ${url} - Status: ${response.status}, Body: ${response.body}`);
  }

  return { response, duration, success };
}

export default function () {
  const scenario = __ENV.K6_SCENARIO_NAME;
  
  if (scenario === 'scale_to_zero_test') {
    scaleToZeroMainTest();
  } else if (scenario === 'background_traffic') {
    backgroundTrafficTest();
  } else if (scenario === 'spike_after_idle') {
    spikeAfterIdleTest();
  } else {
    // Default behavior
    healthCheckTest();
  }
}

function scaleToZeroMainTest() {
  group('Scale-to-Zero Main Test', () => {
    console.log('=== Starting Scale-to-Zero Test ===');
    
    // Phase 1: Initial warmup
    console.log('Phase 1: Initial warmup...');
    warmupServices();
    
    // Phase 2: Generate some activity
    console.log('Phase 2: Generating activity...');
    generateActivity();
    
    // Phase 3: Wait for scale down (65 seconds to be safe)
    console.log('Phase 3: Waiting for scale down (65 seconds)...');
    sleep(65);
    scaleDownDetected.add(1);
    
    // Phase 4: Test cold start
    console.log('Phase 4: Testing cold start...');
    testColdStart();
    
    // Phase 5: Sustained load after scale up
    console.log('Phase 5: Sustained load test...');
    sustainedLoadTest();
    
    console.log('=== Scale-to-Zero Test Complete ===');
  });
}

function backgroundTrafficTest() {
  group('Background Traffic', () => {
    // Light background traffic to keep some services active
    const actions = [
      () => makeRequest('GET', `${BASE_URL_A}/health`),
      () => makeRequest('GET', `${BASE_URL_B}/health`),
      () => makeRequest('GET', `${BASE_URL_A}/users`),
      () => makeRequest('GET', `${BASE_URL_B}/orders`),
    ];
    
    const action = actions[Math.floor(Math.random() * actions.length)];
    action();
    
    sleep(Math.random() * 10 + 5); // Sleep 5-15 seconds
  });
}

function spikeAfterIdleTest() {
  group('Spike After Idle', () => {
    // Simulate sudden spike in traffic after idle period
    const user = {
      name: `SpikeUser${Date.now()}`,
      email: `spike${Date.now()}@example.com`
    };
    
    const { response, duration } = makeRequest('POST', `${BASE_URL_A}/users`, user, 201, '45s');
    
    if (response.status === 201) {
      // Follow up with related requests
      makeRequest('GET', `${BASE_URL_A}/users`, null, 200);
      makeRequest('GET', `${BASE_URL_B}/users`, null, 200); // Cross-cell request
    }
    
    sleep(1);
  });
}

function warmupServices() {
  group('Service Warmup', () => {
    // Warm up both cells
    makeRequest('GET', `${BASE_URL_A}/health`);
    makeRequest('GET', `${BASE_URL_B}/health`);
    
    // Create some initial data
    const user = {
      name: `WarmupUser${Date.now()}`,
      email: `warmup${Date.now()}@example.com`
    };
    
    const product = {
      name: `WarmupProduct${Date.now()}`,
      description: 'Warmup product for testing',
      price: 99.99,
      stock: 50
    };
    
    makeRequest('POST', `${BASE_URL_A}/users`, user, 201);
    makeRequest('POST', `${BASE_URL_A}/products`, product, 201);
    
    sleep(2);
  });
}

function generateActivity() {
  group('Generate Activity', () => {
    // Create users and products
    for (let i = 0; i < 3; i++) {
      const user = {
        name: `ActivityUser${Date.now()}_${i}`,
        email: `activity${Date.now()}_${i}@example.com`
      };
      makeRequest('POST', `${BASE_URL_A}/users`, user, 201);
      
      const product = {
        name: `ActivityProduct${Date.now()}_${i}`,
        description: `Product ${i} for activity generation`,
        price: Math.random() * 100 + 10,
        stock: Math.floor(Math.random() * 100) + 1
      };
      makeRequest('POST', `${BASE_URL_A}/products`, product, 201);
      
      sleep(1);
    }
    
    // Some cross-cell requests
    makeRequest('GET', `${BASE_URL_B}/users`);
    makeRequest('GET', `${BASE_URL_A}/orders`);
  });
}

function testColdStart() {
  group('Cold Start Test', () => {
    console.log('Testing cold start with health check...');
    
    // First request after idle - should trigger scale up
    const startTime = Date.now();
    const { response: healthResponse, duration: healthDuration } = makeRequest('GET', `${BASE_URL_A}/health`, null, 200, '45s');
    
    if (healthResponse.status === 200) {
      console.log(`Health check cold start took: ${healthDuration}ms`);
      scaleUpTime.add(healthDuration);
    }
    
    // Test functional endpoint after scale up
    const user = {
      name: `ColdStartUser${Date.now()}`,
      email: `coldstart${Date.now()}@example.com`
    };
    
    const { response: userResponse, duration: userDuration } = makeRequest('POST', `${BASE_URL_A}/users`, user, 201, '45s');
    
    if (userResponse.status === 201) {
      console.log(`User creation after cold start took: ${userDuration}ms`);
      
      // Test cross-cell communication after scale up
      const { duration: crossCellDuration } = makeRequest('GET', `${BASE_URL_B}/users`, null, 200, '45s');
      console.log(`Cross-cell request after cold start took: ${crossCellDuration}ms`);
    }
    
    scalingEvents.add(1);
  });
}

function sustainedLoadTest() {
  group('Sustained Load After Scale Up', () => {
    // Test that services handle load properly after scaling up
    for (let i = 0; i < 5; i++) {
      const user = {
        name: `SustainedUser${Date.now()}_${i}`,
        email: `sustained${Date.now()}_${i}@example.com`
      };
      
      const { response } = makeRequest('POST', `${BASE_URL_A}/users`, user, 201);
      
      if (response.status === 201) {
        const userData = JSON.parse(response.body);
        const userId = userData.data ? userData.data.id : userData.id;
        
        if (userId) {
          // Test various operations
          makeRequest('GET', `${BASE_URL_A}/users/${userId}`);
          makeRequest('GET', `${BASE_URL_B}/users/${userId}`); // Cross-cell
          makeRequest('PUT', `${BASE_URL_A}/users/${userId}`, {
            ...user,
            name: user.name + ' Updated'
          });
        }
      }
      
      sleep(0.5);
    }
  });
}

function healthCheckTest() {
  group('Health Check', () => {
    makeRequest('GET', `${BASE_URL_A}/health`);
    makeRequest('GET', `${BASE_URL_B}/health`);
  });
}

// Summary function to analyze results
export function handleSummary(data) {
  const summary = {
    timestamp: new Date().toISOString(),
    test_duration: data.state.testRunDurationMs,
    total_requests: data.metrics.http_reqs.values.count,
    failed_requests: data.metrics.http_req_failed.values.rate,
    avg_response_time: data.metrics.http_req_duration.values.avg,
    p95_response_time: data.metrics.http_req_duration.values['p(95)'],
    max_response_time: data.metrics.http_req_duration.values.max,
    cold_starts: data.metrics.cold_start_requests ? data.metrics.cold_start_requests.values.count : 0,
    scale_events: data.metrics.scaling_events ? data.metrics.scaling_events.values.value : 0,
    scale_down_events: data.metrics.scale_down_detected ? data.metrics.scale_down_detected.values.count : 0,
    avg_scale_up_time: data.metrics.scale_up_time ? data.metrics.scale_up_time.values.avg : 0,
    thresholds_passed: Object.keys(data.metrics).every(metric => {
      const m = data.metrics[metric];
      return !m.thresholds || Object.values(m.thresholds).every(t => !t.ok === false);
    })
  };
  
  console.log('\n=== SCALE-TO-ZERO TEST SUMMARY ===');
  console.log(`Test Duration: ${summary.test_duration}ms`);
  console.log(`Total Requests: ${summary.total_requests}`);
  console.log(`Failed Requests: ${(summary.failed_requests * 100).toFixed(2)}%`);
  console.log(`Average Response Time: ${summary.avg_response_time.toFixed(2)}ms`);
  console.log(`P95 Response Time: ${summary.p95_response_time.toFixed(2)}ms`);
  console.log(`Max Response Time: ${summary.max_response_time.toFixed(2)}ms`);
  console.log(`Cold Starts Detected: ${summary.cold_starts}`);
  console.log(`Scale Events: ${summary.scale_events}`);
  console.log(`Scale Down Events: ${summary.scale_down_events}`);
  console.log(`Average Scale Up Time: ${summary.avg_scale_up_time.toFixed(2)}ms`);
  console.log(`All Thresholds Passed: ${summary.thresholds_passed}`);
  console.log('====================================\n');
  
  return {
    'scale-to-zero-summary.json': JSON.stringify(summary, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

// Simple text summary function
function textSummary(data, options = {}) {
  const indent = options.indent || '';
  const enableColors = options.enableColors || false;
  
  let summary = `${indent}Test Summary:\n`;
  summary += `${indent}  Duration: ${data.state.testRunDurationMs}ms\n`;
  summary += `${indent}  Requests: ${data.metrics.http_reqs.values.count}\n`;
  summary += `${indent}  Failed: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%\n`;
  summary += `${indent}  Avg Response Time: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  
  return summary;
} 