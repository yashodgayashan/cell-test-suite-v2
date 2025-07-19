import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter, Trend } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');
export let requestCount = new Counter('requests_total');
export let responseTime = new Trend('response_time');

// Test configuration
export let options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up to 10 users over 2 minutes
    { duration: '5m', target: 10 },   // Stay at 10 users for 5 minutes
    { duration: '2m', target: 50 },   // Ramp up to 50 users over 2 minutes
    { duration: '5m', target: 50 },   // Stay at 50 users for 5 minutes
    { duration: '2m', target: 100 },  // Ramp up to 100 users over 2 minutes
    { duration: '5m', target: 100 },  // Stay at 100 users for 5 minutes
    { duration: '2m', target: 0 },    // Ramp down to 0 users over 2 minutes
  ],
  thresholds: {
    errors: ['rate<0.1'],           // Error rate should be less than 10%
    http_req_duration: ['p(95)<2000'], // 95% of requests should complete within 2 seconds
    http_req_failed: ['rate<0.05'],    // Less than 5% of requests should fail
  },
};

// Service endpoints - using cluster IPs
const CELL_A_GATEWAY = 'http://10.96.125.29:8010';
const CELL_B_GATEWAY = 'http://10.96.48.68:8020';

// Or using port-forward approach
const CELL_A_URL = __ENV.CELL_A_URL || CELL_A_GATEWAY;
const CELL_B_URL = __ENV.CELL_B_URL || CELL_B_GATEWAY;

console.log(`Cell A URL: ${CELL_A_URL}`);
console.log(`Cell B URL: ${CELL_B_URL}`);

export default function () {
  let success = true;
  
  // Test Cell A - User Service
  try {
    let userPayload = JSON.stringify({
      name: `testuser_${Math.random().toString(36).substring(7)}`,
      email: `test_${Math.random().toString(36).substring(7)}@example.com`
    });

    let userResponse = http.post(`${CELL_A_URL}/users`, userPayload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: '30s'
    });

    let userCheckResult = check(userResponse, {
      'POST /users status is 201': (r) => r.status === 201,
      'POST /users response time < 5000ms': (r) => r.timings.duration < 5000,
    });

    if (!userCheckResult) {
      console.log(`Error: POST ${CELL_A_URL}/users - Status: ${userResponse.status}, Body: ${userResponse.body}`);
      success = false;
    }

    responseTime.add(userResponse.timings.duration);
    requestCount.add(1);
  } catch (error) {
    console.log(`Request Failed: ${error}`);
    success = false;
  }

  // Test Cell A - Product Service
  try {
    let productPayload = JSON.stringify({
      name: `product_${Math.random().toString(36).substring(7)}`,
      price: Math.floor(Math.random() * 1000) + 10,
      category: 'test'
    });

    let productResponse = http.post(`${CELL_A_URL}/products`, productPayload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: '30s'
    });

    let productCheckResult = check(productResponse, {
      'POST /products status is 201': (r) => r.status === 201,
      'POST /products response time < 5000ms': (r) => r.timings.duration < 5000,
    });

    if (!productCheckResult) {
      console.log(`Error: POST ${CELL_A_URL}/products - Status: ${productResponse.status}, Body: ${productResponse.body}`);
      success = false;
    }

    responseTime.add(productResponse.timings.duration);
    requestCount.add(1);
  } catch (error) {
    console.log(`Request Failed: ${error}`);
    success = false;
  }

  // Health checks
  try {
    let healthResponseA = http.get(`${CELL_A_URL}/health`, { timeout: '10s' });
    let healthResponseB = http.get(`${CELL_B_URL}/health`, { timeout: '10s' });

    check(healthResponseA, {
      'GET /health (Cell A) status is 200': (r) => r.status === 200,
      'GET /health (Cell A) response time < 5000ms': (r) => r.timings.duration < 5000,
    });

    check(healthResponseB, {
      'GET /health (Cell B) status is 200': (r) => r.status === 200,
      'GET /health (Cell B) response time < 5000ms': (r) => r.timings.duration < 5000,
    });

    // Readiness checks
    let readinessResponseA = http.get(`${CELL_A_URL}/readiness`, { timeout: '10s' });
    let readinessResponseB = http.get(`${CELL_B_URL}/readiness`, { timeout: '10s' });

    check(readinessResponseA, {
      'GET /readiness (Cell A) status is 200': (r) => r.status === 200,
      'GET /readiness (Cell A) response time < 5000ms': (r) => r.timings.duration < 5000,
    });

    check(readinessResponseB, {
      'GET /readiness (Cell B) status is 200': (r) => r.status === 200,
      'GET /readiness (Cell B) response time < 5000ms': (r) => r.timings.duration < 5000,
    });

    requestCount.add(4); // 4 health/readiness checks
  } catch (error) {
    console.log(`Health check failed: ${error}`);
    success = false;
  }

  errorRate.add(!success);
  
  // Random sleep between 1-3 seconds
  sleep(Math.random() * 2 + 1);
} 