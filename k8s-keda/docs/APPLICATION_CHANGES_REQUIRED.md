# Application Code Changes Required for KEDA HTTP Scaling

## 🔍 Current Issue

The KEDA HTTP scaling setup is working for **direct external requests** to gateways, but **internal service-to-service communication** requires application code changes to work properly.

### What's Working ✅
- External requests to gateways via KEDA HTTP interceptor
- Gateway scaling (Cell A and Cell B gateways scale up correctly)
- Service configuration and environment variables

### What Needs Application Changes ❌
- Internal service calls from gateways to services (user-service, product-service, etc.)
- Cross-cell communication through gateways

## 🏗️ Technical Explanation

### Current Application Behavior
```go
// Current code (simplified)
userServiceURL := os.Getenv("USER_SERVICE_URL") 
// Now: "http://keda-add-on-http-interceptor-proxy.keda.svc.cluster.local:8080"

resp, err := http.Get(userServiceURL + "/users")
// This call fails because no Host header is set
```

### Required Application Behavior
```go
// Required code changes
userServiceURL := os.Getenv("USER_SERVICE_URL")
userServiceHost := os.Getenv("USER_SERVICE_HOST") // "cell-a-user-service.local"

client := &http.Client{}
req, _ := http.NewRequest("GET", userServiceURL + "/users", nil)
req.Host = userServiceHost // This is the critical addition
resp, err := client.Do(req)
```

## 🔧 Required Application Code Changes

### 1. Gateway Applications Need Updates

#### Cell A Gateway (`cell-a/gateway/`)
```go
// Add Host header support for internal calls
func callUserService(endpoint string) {
    userServiceURL := os.Getenv("USER_SERVICE_URL")
    userServiceHost := os.Getenv("USER_SERVICE_HOST")
    
    req, _ := http.NewRequest("GET", userServiceURL + endpoint, nil)
    req.Host = userServiceHost
    
    client := &http.Client{}
    resp, err := client.Do(req)
    // Handle response...
}

func callProductService(endpoint string) {
    productServiceURL := os.Getenv("PRODUCT_SERVICE_URL")
    productServiceHost := os.Getenv("PRODUCT_SERVICE_HOST")
    
    req, _ := http.NewRequest("GET", productServiceURL + endpoint, nil)
    req.Host = productServiceHost
    
    client := &http.Client{}
    resp, err := client.Do(req)
    // Handle response...
}
```

#### Cell B Gateway (`cell-b/gateway/`)
```go
func callOrderService(endpoint string) {
    orderServiceURL := os.Getenv("ORDER_SERVICE_URL")
    orderServiceHost := os.Getenv("ORDER_SERVICE_HOST")
    
    req, _ := http.NewRequest("POST", orderServiceURL + endpoint, body)
    req.Host = orderServiceHost
    
    client := &http.Client{}
    resp, err := client.Do(req)
    // Handle response...
}

func callPaymentService(endpoint string) {
    paymentServiceURL := os.Getenv("PAYMENT_SERVICE_URL")
    paymentServiceHost := os.Getenv("PAYMENT_SERVICE_HOST")
    
    req, _ := http.NewRequest("POST", paymentServiceURL + endpoint, body)
    req.Host = paymentServiceHost
    
    client := &http.Client{}
    resp, err := client.Do(req)
    // Handle response...
}
```

### 2. Service Applications Need Updates

#### Order Service (`cell-b/order-service/`)
```go
func callCellAGateway(endpoint string) {
    cellAGatewayURL := os.Getenv("CELL_A_GATEWAY_URL")
    cellAGatewayHost := os.Getenv("CELL_A_GATEWAY_HOST")
    
    req, _ := http.NewRequest("GET", cellAGatewayURL + endpoint, nil)
    req.Host = cellAGatewayHost
    
    client := &http.Client{}
    resp, err := client.Do(req)
    // Handle response...
}

func callPaymentService(endpoint string) {
    paymentServiceURL := os.Getenv("PAYMENT_SERVICE_URL")
    paymentServiceHost := os.Getenv("PAYMENT_SERVICE_HOST")
    
    req, _ := http.NewRequest("POST", paymentServiceURL + endpoint, body)
    req.Host = paymentServiceHost
    
    client := &http.Client{}
    resp, err := client.Do(req)
    // Handle response...
}
```

## 🛠️ Implementation Steps

### Step 1: Update Application Code
1. Modify all HTTP client calls to include Host headers
2. Use the `*_HOST` environment variables provided in ConfigMaps
3. Rebuild and push new container images

### Step 2: Update Container Images
```bash
# Build new images with the updated code
docker build -t yashodperera/cell-a-gateway:keda-v1 ./cell-a/gateway/
docker build -t yashodperera/cell-a-user-service:keda-v1 ./cell-a/user-service/
docker build -t yashodperera/cell-a-product-service:keda-v1 ./cell-a/product-service/

docker build -t yashodperera/cell-b-gateway:keda-v1 ./cell-b/gateway/
docker build -t yashodperera/cell-b-order-service:keda-v1 ./cell-b/order-service/
docker build -t yashodperera/cell-b-payment-service:keda-v1 ./cell-b/payment-service/

# Push to registry
docker push yashodperera/cell-a-gateway:keda-v1
# ... push all images
```

### Step 3: Update Kubernetes Manifests
```yaml
# Update image tags in deployment files
containers:
- name: gateway
  image: yashodperera/cell-a-gateway:keda-v1  # Updated tag
```

## 🚀 Alternative Approach: Hybrid Scaling

If modifying application code is not feasible immediately, you can use a **hybrid approach**:

### Option 1: Keep Internal Services Always Running
```yaml
# For internal services, use minimum 1 replica instead of 0
spec:
  replicas:
    min: 1  # Always keep at least 1 running
    max: 5
```

### Option 2: Use Different Scaling for Internal Services
- External entry points (gateways): Use KEDA HTTP scaling
- Internal services: Use regular HPA or keep always running
- Trade-off: Less cost savings but no application changes required

### Option 3: Service Mesh Integration
- Use a service mesh like Istio with KEDA
- Service mesh can handle Host header routing transparently
- More complex setup but no application code changes

## 📋 Environment Variables Reference

### Current Configuration in ConfigMaps:

#### Cell A Gateway
```env
USER_SERVICE_URL=http://keda-add-on-http-interceptor-proxy.keda.svc.cluster.local:8080
USER_SERVICE_HOST=cell-a-user-service.local
PRODUCT_SERVICE_URL=http://keda-add-on-http-interceptor-proxy.keda.svc.cluster.local:8080
PRODUCT_SERVICE_HOST=cell-a-product-service.local
CELL_B_GATEWAY_URL=http://keda-add-on-http-interceptor-proxy.keda.svc.cluster.local:8080
CELL_B_GATEWAY_HOST=cell-b-gateway.local
```

#### Cell B Gateway
```env
ORDER_SERVICE_URL=http://keda-add-on-http-interceptor-proxy.keda.svc.cluster.local:8080
ORDER_SERVICE_HOST=cell-b-order-service.local
PAYMENT_SERVICE_URL=http://keda-add-on-http-interceptor-proxy.keda.svc.cluster.local:8080
PAYMENT_SERVICE_HOST=cell-b-payment-service.local
CELL_A_GATEWAY_URL=http://keda-add-on-http-interceptor-proxy.keda.svc.cluster.local:8080
CELL_A_GATEWAY_HOST=cell-a-gateway.local
```

## 📈 Benefits After Implementation

Once application code is updated:
- ✅ Full scale-to-zero functionality for all services
- ✅ Automatic scaling based on actual traffic
- ✅ Cost optimization with serverless-style scaling
- ✅ Maintained cell autonomy and cross-cell communication
- ✅ Rich observability through KEDA metrics

## 🎯 Next Steps

1. **Immediate**: Use hybrid approach for demo purposes
2. **Short-term**: Update application code with Host header support
3. **Long-term**: Consider service mesh integration for advanced scenarios 