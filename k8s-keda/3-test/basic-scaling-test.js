import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');

// Test configuration
export let options = {
  stages: [
    // Ramp-up: 0 to 10 VUs over 2 minutes
    { duration: '2m', target: 10 },
    // Steady state: 10 VUs for 3 minutes
    { duration: '3m', target: 10 },
    // Peak load: 10 to 50 VUs over 2 minutes
    { duration: '2m', target: 50 },
    // High load: 50 VUs for 3 minutes
    { duration: '3m', target: 50 },
    // Ramp-down: 50 to 0 VUs over 2 minutes
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    http_req_failed: ['rate<0.1'],     // Error rate must be below 10%
    errors: ['rate<0.1'],              // Custom error rate below 10%
  },
};

const BASE_URL = 'http://localhost:8080';

// Test endpoints for both cells
const endpoints = [
  // Cell A endpoints
  { host: 'cell-a-gateway.local', path: '/health', name: 'Cell A Health' },
  { host: 'cell-a-gateway.local', path: '/users', name: 'Cell A Users' },
  { host: 'cell-a-gateway.local', path: '/products', name: 'Cell A Products' },
  
  // Cell B endpoints  
  { host: 'cell-b-gateway.local', path: '/health', name: 'Cell B Health' },
  { host: 'cell-b-gateway.local', path: '/orders', name: 'Cell B Orders' },
  { host: 'cell-b-gateway.local', path: '/payments', name: 'Cell B Payments' },
];

export default function () {
  // Randomly select an endpoint to test
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  const params = {
    headers: {
      'Host': endpoint.host,
      'Content-Type': 'application/json',
    },
  };

  console.log(`Testing ${endpoint.name}: ${endpoint.host}${endpoint.path}`);
  
  const response = http.get(`${BASE_URL}${endpoint.path}`, params);
  
  const result = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
    'response body is not empty': (r) => r.body && r.body.length > 0,
    'response is valid JSON': (r) => {
      try {
        JSON.parse(r.body);
        return true;
      } catch (e) {
        return false;
      }
    },
  });

  if (!result) {
    errorRate.add(1);
    console.error(`Request failed for ${endpoint.name}: ${response.status} - ${response.body}`);
  } else {
    errorRate.add(0);
  }

  // Add some think time between requests
  sleep(Math.random() * 2 + 1); // Random sleep between 1-3 seconds
} 