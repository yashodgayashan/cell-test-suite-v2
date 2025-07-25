import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter } from 'k6/metrics';

export let errorRate = new Rate('errors');
export let crossCellAttempts = new Counter('cross_cell_attempts');
export let crossCellErrors = new Counter('cross_cell_errors');

// Cross-cell communication test
export let options = {
  stages: [
    { duration: '1m', target: 3 },
    { duration: '2m', target: 8 },
    { duration: '2m', target: 8 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<4000'], // Allow more time for cross-cell calls
    http_req_failed: ['rate<0.3'],     // Higher tolerance for cross-cell issues
    errors: ['rate<0.3'],
  },
};

const BASE_URL = 'http://localhost:8080';

// Cross-cell endpoints - testing one cell accessing another cell's resources
const crossCellEndpoints = [
  // Cell B trying to access Cell A resources (users, products)
  { host: 'cell-b-gateway.local', path: '/users', name: 'Cell B → Cell A Users', crossCell: true },
  { host: 'cell-b-gateway.local', path: '/products', name: 'Cell B → Cell A Products', crossCell: true },
  
  // Cell A trying to access Cell B resources (orders, payments)  
  { host: 'cell-a-gateway.local', path: '/orders', name: 'Cell A → Cell B Orders', crossCell: true },
  { host: 'cell-a-gateway.local', path: '/payments', name: 'Cell A → Cell B Payments', crossCell: true },
  
  // Same-cell calls for comparison
  { host: 'cell-a-gateway.local', path: '/users', name: 'Cell A → Cell A Users', crossCell: false },
  { host: 'cell-a-gateway.local', path: '/products', name: 'Cell A → Cell A Products', crossCell: false },
  { host: 'cell-b-gateway.local', path: '/orders', name: 'Cell B → Cell B Orders', crossCell: false },
  { host: 'cell-b-gateway.local', path: '/payments', name: 'Cell B → Cell B Payments', crossCell: false },
];

export default function () {
  const endpoint = crossCellEndpoints[Math.floor(Math.random() * crossCellEndpoints.length)];
  
  const params = {
    headers: {
      'Host': endpoint.host,
      'Content-Type': 'application/json',
    },
  };

  if (endpoint.crossCell) {
    crossCellAttempts.add(1);
  }

  console.log(`Testing ${endpoint.name}`);
  
  const response = http.get(`${BASE_URL}${endpoint.path}`, params);
  
  const result = check(response, {
    'status is success or expected failure': (r) => {
      // For cross-cell calls, we might expect some failures due to Host header requirements
      if (endpoint.crossCell) {
        return r.status === 200 || r.status === 503; // 503 = Service Unavailable is expected
      }
      return r.status === 200;
    },
    'response time reasonable': (r) => r.timings.duration < 4000,
    'response has content': (r) => r.body && r.body.length > 0,
  });

  // Special handling for cross-cell communication analysis
  if (endpoint.crossCell) {
    if (response.status === 200) {
      console.log(`✅ Cross-cell SUCCESS: ${endpoint.name}`);
    } else if (response.status === 503) {
      console.log(`⚠️  Cross-cell expected failure: ${endpoint.name} (Host header needed)`);
      crossCellErrors.add(1);
    } else {
      console.error(`❌ Cross-cell unexpected error: ${endpoint.name} - ${response.status}`);
      crossCellErrors.add(1);
      errorRate.add(1);
    }
  } else {
    // Same-cell calls should always work
    if (!result || response.status !== 200) {
      errorRate.add(1);
      console.error(`❌ Same-cell failure: ${endpoint.name} - ${response.status}`);
    } else {
      console.log(`✅ Same-cell SUCCESS: ${endpoint.name}`);
    }
  }

  if (!result && !endpoint.crossCell) {
    errorRate.add(1);
  }

  // Longer sleep for cross-cell tests to allow for scaling
  sleep(Math.random() * 2 + 1);
}

export function handleSummary(data) {
  const crossCellAttemptCount = data.metrics.cross_cell_attempts ? data.metrics.cross_cell_attempts.values.count : 0;
  const crossCellErrorCount = data.metrics.cross_cell_errors ? data.metrics.cross_cell_errors.values.count : 0;
  const crossCellSuccessRate = crossCellAttemptCount > 0 ? 
    ((crossCellAttemptCount - crossCellErrorCount) / crossCellAttemptCount * 100).toFixed(2) : 0;

  return {
    'cross-cell-summary.json': JSON.stringify({
      cross_cell_attempts: crossCellAttemptCount,
      cross_cell_errors: crossCellErrorCount,
      cross_cell_success_rate: `${crossCellSuccessRate}%`,
      note: "Low cross-cell success rate is expected without Host header support in application code",
      recommendation: "See APPLICATION_CHANGES_REQUIRED.md for Host header implementation"
    }, null, 2),
  };
} 