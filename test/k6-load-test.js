import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const requestCounter = new Counter('requests_total');

// Configuration
const CELL_A_BASE_URL = __ENV.CELL_A_URL || 'http://cell-a.local';
const CELL_B_BASE_URL = __ENV.CELL_B_URL || 'http://cell-b.local';
const CLUSTER_IP_A = __ENV.CELL_A_CLUSTER_IP || 'http://cell-a-gateway.cell-a.svc.cluster.local:8010';
const CLUSTER_IP_B = __ENV.CELL_B_CLUSTER_IP || 'http://cell-b-gateway.cell-b.svc.cluster.local:8020';

// Use cluster IPs if running inside cluster, otherwise use external URLs
const CELL_A_URL = __ENV.USE_CLUSTER_IP === 'true' ? CLUSTER_IP_A : CELL_A_BASE_URL;
const CELL_B_URL = __ENV.USE_CLUSTER_IP === 'true' ? CLUSTER_IP_B : CELL_B_BASE_URL;

// Load test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 200 },  // Spike test
    { duration: '1m', target: 200 },  // Stay at spike
    { duration: '3m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests under 2s
    http_req_failed: ['rate<0.05'],    // Error rate under 5%
    errors: ['rate<0.1'],              // Custom error rate under 10%
  },
};

// Test data generators
function generateUser() {
  const userNum = Math.floor(Math.random() * 10000);
  return {
    name: `User${userNum}`,
    email: `user${userNum}@example.com`
  };
}

function generateProduct() {
  const productNum = Math.floor(Math.random() * 1000);
  return {
    name: `Product${productNum}`,
    description: `Description for product ${productNum}`,
    price: Math.floor(Math.random() * 1000) + 10,
    stock: Math.floor(Math.random() * 100) + 1
  };
}

function generateOrder(userId, productId) {
  return {
    user_id: userId,
    product_id: productId,
    quantity: Math.floor(Math.random() * 5) + 1,
    total: Math.floor(Math.random() * 500) + 50
  };
}

function generatePayment(orderId, amount) {
  return {
    order_id: orderId,
    amount: amount,
    method: ['credit_card', 'debit_card', 'paypal'][Math.floor(Math.random() * 3)]
  };
}

// Helper function to make requests with error handling
function makeRequest(method, url, payload = null, expectedStatus = 200) {
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '30s',
  };

  let response;
  if (payload) {
    response = http.request(method, url, JSON.stringify(payload), params);
  } else {
    response = http.request(method, url, null, params);
  }

  requestCounter.add(1);
  responseTime.add(response.timings.duration);

  const success = check(response, {
    [`${method} ${url} status is ${expectedStatus}`]: (r) => r.status === expectedStatus,
    [`${method} ${url} response time < 5000ms`]: (r) => r.timings.duration < 5000,
  });

  if (!success) {
    errorRate.add(1);
    console.log(`Error: ${method} ${url} - Status: ${response.status}, Body: ${response.body}`);
  }

  return response;
}

// Test scenarios
export default function () {
  const scenario = Math.random();
  
  if (scenario < 0.3) {
    // 30% - User management flow
    userManagementFlow();
  } else if (scenario < 0.6) {
    // 30% - Product management flow
    productManagementFlow();
  } else if (scenario < 0.9) {
    // 30% - End-to-end order flow
    endToEndOrderFlow();
  } else {
    // 10% - Health checks and monitoring
    healthCheckFlow();
  }
  
  sleep(Math.random() * 3 + 1); // Random sleep 1-4 seconds
}

function userManagementFlow() {
  group('User Management Flow', () => {
    // Create user via Cell A
    const newUser = generateUser();
    let response = makeRequest('POST', `${CELL_A_URL}/users`, newUser, 201);
    
    if (response.status === 201) {
      const userData = JSON.parse(response.body);
      const userId = userData.data ? userData.data.id : userData.id;
      
      if (userId) {
        // Get user by ID
        makeRequest('GET', `${CELL_A_URL}/users/${userId}`, null, 200);
        
        // Update user
        const updatedUser = {
          ...newUser,
          name: newUser.name + ' Updated'
        };
        makeRequest('PUT', `${CELL_A_URL}/users/${userId}`, updatedUser, 200);
        
        // Get all users
        makeRequest('GET', `${CELL_A_URL}/users`, null, 200);
        
        // Access user from Cell B (cross-cell communication)
        makeRequest('GET', `${CELL_B_URL}/users/${userId}`, null, 200);
      }
    }
  });
}

function productManagementFlow() {
  group('Product Management Flow', () => {
    // Create product via Cell A
    const newProduct = generateProduct();
    let response = makeRequest('POST', `${CELL_A_URL}/products`, newProduct, 201);
    
    if (response.status === 201) {
      const productData = JSON.parse(response.body);
      const productId = productData.data ? productData.data.id : productData.id;
      
      if (productId) {
        // Get product by ID
        makeRequest('GET', `${CELL_A_URL}/products/${productId}`, null, 200);
        
        // Update product stock
        const stockUpdate = { stock: Math.floor(Math.random() * 50) + 10 };
        makeRequest('PUT', `${CELL_A_URL}/products/${productId}/stock`, stockUpdate, 200);
        
        // Get all products
        makeRequest('GET', `${CELL_A_URL}/products`, null, 200);
        
        // Access product from Cell B (cross-cell communication)
        makeRequest('GET', `${CELL_B_URL}/products/${productId}`, null, 200);
      }
    }
  });
}

function endToEndOrderFlow() {
  group('End-to-End Order Flow', () => {
    // Step 1: Create user
    const newUser = generateUser();
    let userResponse = makeRequest('POST', `${CELL_A_URL}/users`, newUser, 201);
    
    if (userResponse.status !== 201) return;
    
    const userData = JSON.parse(userResponse.body);
    const userId = userData.data ? userData.data.id : userData.id;
    
    if (!userId) return;
    
    // Step 2: Create product
    const newProduct = generateProduct();
    let productResponse = makeRequest('POST', `${CELL_A_URL}/products`, newProduct, 201);
    
    if (productResponse.status !== 201) return;
    
    const productData = JSON.parse(productResponse.body);
    const productId = productData.data ? productData.data.id : productData.id;
    
    if (!productId) return;
    
    // Step 3: Create order via Cell B
    const newOrder = generateOrder(userId, productId);
    let orderResponse = makeRequest('POST', `${CELL_B_URL}/orders`, newOrder, 201);
    
    if (orderResponse.status === 201) {
      const orderData = JSON.parse(orderResponse.body);
      const orderId = orderData.data ? orderData.data.id : orderData.id;
      
      if (orderId) {
        // Step 4: Process payment
        const newPayment = generatePayment(orderId, newOrder.total);
        let paymentResponse = makeRequest('POST', `${CELL_B_URL}/payments`, newPayment, 201);
        
        if (paymentResponse.status === 201) {
          const paymentData = JSON.parse(paymentResponse.body);
          const paymentId = paymentData.data ? paymentData.data.id : paymentData.id;
          
          // Step 5: Update order status
          makeRequest('PUT', `${CELL_B_URL}/orders/${orderId}/status`, 
                     { status: 'completed' }, 200);
          
          // Step 6: Verify order from Cell A (cross-cell access)
          makeRequest('GET', `${CELL_A_URL}/orders/${orderId}`, null, 200);
          
          // Step 7: Check payment status
          if (paymentId) {
            makeRequest('GET', `${CELL_B_URL}/payments/${paymentId}`, null, 200);
            makeRequest('GET', `${CELL_B_URL}/payments/order/${orderId}`, null, 200);
          }
        }
      }
    }
  });
}

function healthCheckFlow() {
  group('Health Check Flow', () => {
    // Check health of both cells
    makeRequest('GET', `${CELL_A_URL}/health`, null, 200);
    makeRequest('GET', `${CELL_B_URL}/health`, null, 200);
    
    // Check readiness
    makeRequest('GET', `${CELL_A_URL}/readiness`, null, 200);
    makeRequest('GET', `${CELL_B_URL}/readiness`, null, 200);
  });
}

// Scenario for stress testing scale-to-zero functionality
export function scaleToZeroTest() {
  group('Scale-to-Zero Test', () => {
    console.log('Starting scale-to-zero test...');
    
    // Make initial requests
    makeRequest('GET', `${CELL_A_URL}/health`, null, 200);
    makeRequest('GET', `${CELL_B_URL}/health`, null, 200);
    
    // Wait for potential scale down (60 seconds based on annotation)
    console.log('Waiting for potential scale down...');
    sleep(70);
    
    // Make requests after idle period (should trigger scale up)
    console.log('Making requests after idle period...');
    makeRequest('GET', `${CELL_A_URL}/health`, null, 200);
    makeRequest('GET', `${CELL_B_URL}/health`, null, 200);
    
    // Test actual functionality after scale up
    const user = generateUser();
    makeRequest('POST', `${CELL_A_URL}/users`, user, 201);
  });
} 