import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

export let errorRate = new Rate('errors');
export let serviceResponseTime = new Trend('service_response_time');

// Service-focused load test
export let options = {
  stages: [
    // Gradual ramp-up to test service scaling
    { duration: '1m', target: 5 },
    { duration: '2m', target: 15 },
    { duration: '2m', target: 30 },
    { duration: '3m', target: 30 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.1'],
    service_response_time: ['p(90)<2000'],
    errors: ['rate<0.1'],
  },
};

const BASE_URL = 'http://localhost:8080';

// Service endpoints that should trigger internal service scaling
const serviceEndpoints = [
  // Cell A services
  { host: 'cell-a-gateway.local', path: '/users', name: 'User Service', method: 'GET' },
  { host: 'cell-a-gateway.local', path: '/products', name: 'Product Service', method: 'GET' },
  
  // Cell B services
  { host: 'cell-b-gateway.local', path: '/orders', name: 'Order Service', method: 'GET' },
  { host: 'cell-b-gateway.local', path: '/payments', name: 'Payment Service', method: 'GET' },
  
  // Create operations to generate more load
  { host: 'cell-a-gateway.local', path: '/users', name: 'Create User', method: 'POST', body: {
    name: `TestUser${Math.floor(Math.random() * 1000)}`,
    email: `user${Math.floor(Math.random() * 1000)}@test.com`
  }},
  { host: 'cell-a-gateway.local', path: '/products', name: 'Create Product', method: 'POST', body: {
    name: `Product${Math.floor(Math.random() * 1000)}`,
    price: Math.floor(Math.random() * 100) + 10,
    category: 'electronics'
  }},
];

export default function () {
  const endpoint = serviceEndpoints[Math.floor(Math.random() * serviceEndpoints.length)];
  
  const params = {
    headers: {
      'Host': endpoint.host,
      'Content-Type': 'application/json',
    },
  };

  let response;
  const startTime = Date.now();

  if (endpoint.method === 'POST' && endpoint.body) {
    response = http.post(`${BASE_URL}${endpoint.path}`, JSON.stringify(endpoint.body), params);
  } else {
    response = http.get(`${BASE_URL}${endpoint.path}`, params);
  }

  const responseTime = Date.now() - startTime;
  serviceResponseTime.add(responseTime);

  const result = check(response, {
    'status is success': (r) => r.status >= 200 && r.status < 300,
    'response time acceptable': (r) => r.timings.duration < 3000,
    'service responds with data': (r) => {
      if (r.status >= 200 && r.status < 300) {
        try {
          const body = JSON.parse(r.body);
          return body !== null && typeof body === 'object';
        } catch (e) {
          return false;
        }
      }
      return false;
    },
  });

  if (!result) {
    errorRate.add(1);
    console.error(`Service test failed for ${endpoint.name}: ${response.status} - ${response.body?.substring(0, 100)}`);
  } else {
    errorRate.add(0);
    console.log(`✅ ${endpoint.name}: ${response.status} (${responseTime}ms)`);
  }

  // Variable sleep based on operation type
  if (endpoint.method === 'POST') {
    sleep(Math.random() * 1 + 0.5); // 0.5-1.5s for create operations
  } else {
    sleep(Math.random() * 0.5 + 0.2); // 0.2-0.7s for read operations
  }
} 