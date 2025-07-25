import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

export let errorRate = new Rate('errors');

// Spike test configuration - tests sudden traffic bursts
export let options = {
  stages: [
    // Normal load
    { duration: '2m', target: 5 },
    // Sudden spike
    { duration: '30s', target: 100 },
    // Sustained high load
    { duration: '2m', target: 100 },
    // Another spike
    { duration: '30s', target: 200 },
    // Sustained very high load
    { duration: '1m', target: 200 },
    // Quick ramp down
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'], // Allow higher response times during spikes
    http_req_failed: ['rate<0.15'],     // Allow slightly higher error rate during spikes
    errors: ['rate<0.15'],
  },
};

const BASE_URL = 'http://localhost:8080';

// Focus on gateway endpoints for spike testing
const gatewayEndpoints = [
  { host: 'cell-a-gateway.local', path: '/health', name: 'Cell A Gateway' },
  { host: 'cell-b-gateway.local', path: '/health', name: 'Cell B Gateway' },
];

export default function () {
  const endpoint = gatewayEndpoints[Math.floor(Math.random() * gatewayEndpoints.length)];
  
  const params = {
    headers: {
      'Host': endpoint.host,
      'Content-Type': 'application/json',
    },
  };

  const response = http.get(`${BASE_URL}${endpoint.path}`, params);
  
  const result = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 5000ms': (r) => r.timings.duration < 5000,
    'gateway is healthy': (r) => {
      if (r.status === 200) {
        try {
          const body = JSON.parse(r.body);
          return body.status === 'healthy';
        } catch (e) {
          return false;
        }
      }
      return false;
    },
  });

  if (!result) {
    errorRate.add(1);
    console.error(`Spike test failed for ${endpoint.name}: ${response.status}`);
  } else {
    errorRate.add(0);
  }

  // Minimal sleep during spike tests
  sleep(0.1);
} 