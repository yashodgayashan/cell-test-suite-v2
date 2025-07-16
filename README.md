# Cell-Based Architecture Test Suite

A comprehensive test suite for cell-based architecture research, featuring two autonomous cells with gateways and services that demonstrate distributed system patterns.

## 🏗️ Architecture Overview

```
cell-architecture-test/
├── cell-a/                     # Cell A (E-commerce Cell)
│   ├── gateway/               # Gateway for Cell A
│   ├── user-service/          # User management service
│   └── product-service/       # Product catalog service
├── cell-b/                     # Cell B (Order Processing Cell)
│   ├── gateway/               # Gateway for Cell B
│   ├── order-service/         # Order processing service
│   └── payment-service/       # Payment processing service
├── shared/                     # Shared types and utilities
├── k8s/                       # Kubernetes manifests
│   ├── cell-a/               # Cell A K8s resources
│   └── cell-b/               # Cell B K8s resources
├── test/                      # Integration tests
└── scripts/                   # Build and deployment scripts
```

### Cell A (E-commerce Cell)
- **Gateway** (Port 8010): Routes requests to local services and Cell B
- **User Service** (Port 8011): Manages user accounts and profiles
- **Product Service** (Port 8012): Manages product catalog and inventory

### Cell B (Order Processing Cell)
- **Gateway** (Port 8020): Routes requests to local services and Cell A
- **Order Service** (Port 8021): Handles order processing and validation
- **Payment Service** (Port 8022): Processes payments and refunds

## 🚀 Quick Start

### Prerequisites
- Go 1.21+
- Docker and Docker Compose
- Kubernetes cluster (for K8s deployment)
- Make (optional, for convenience commands)

### Build and Deploy

```bash
# Build all components
make build

# Or build individual cells
make cell-a
make cell-b

# Deploy locally with Docker Compose
make deploy-local

# Or deploy to Kubernetes
make deploy-k8s

# Test inter-cell communication
make test-communication

# Monitor cell health
make monitor
```

### Development Workflow

```bash
# Build and test Cell A only
make cell-a
docker-compose up cell-a-gateway cell-a-user-service cell-a-product-service

# Build and test Cell B only
make cell-b
docker-compose up cell-b-gateway cell-b-order-service cell-b-payment-service

# Run integration tests
make test

# Clean up
make clean
```

## 🔧 Configuration

All services use environment variables for configuration:

### Cell A Configuration
```env
# Cell A Gateway
CELL_ID=cell-a
PORT=8010
USER_SERVICE_URL=http://cell-a-user-service:8011
PRODUCT_SERVICE_URL=http://cell-a-product-service:8012
CELL_B_GATEWAY_URL=http://cell-b-gateway:8020

# Cell A User Service
CELL_ID=cell-a
PORT=8011

# Cell A Product Service
CELL_ID=cell-a
PORT=8012
```

### Cell B Configuration
```env
# Cell B Gateway
CELL_ID=cell-b
PORT=8020
ORDER_SERVICE_URL=http://cell-b-order-service:8021
PAYMENT_SERVICE_URL=http://cell-b-payment-service:8022
CELL_A_GATEWAY_URL=http://cell-a-gateway:8010

# Cell B Order Service
CELL_ID=cell-b
PORT=8021
CELL_A_GATEWAY_URL=http://cell-a-gateway:8010
PAYMENT_SERVICE_URL=http://cell-b-payment-service:8022

# Cell B Payment Service
CELL_ID=cell-b
PORT=8022
ORDER_SERVICE_URL=http://cell-b-order-service:8021
```

## 🔄 Data Flow Examples

### E2E Order Flow
1. **Create User** → Cell A Gateway → User Service
2. **Create Product** → Cell A Gateway → Product Service  
3. **Create Order** → Cell B Gateway → Order Service → (validates with Cell A)
4. **Process Payment** → Cell B Gateway → Payment Service → (updates Order Service)

### Cross-Cell Access
- **Access Users from Cell B** → Cell B Gateway → Cell A Gateway → User Service
- **Access Products from Cell B** → Cell B Gateway → Cell A Gateway → Product Service
- **Access Orders from Cell A** → Cell A Gateway → Cell B Gateway → Order Service

## 📊 Monitoring and Testing

### Health Checks
All services provide health endpoints:
- `/health` - Service health status
- `/readiness` - Service readiness status

### Integration Tests
```bash
# Run all tests
go test -v ./test/...

# Run specific test categories
go test -v ./test/ -run TestCellA
go test -v ./test/ -run TestCellB
go test -v ./test/ -run TestCrossCellCommunication
```

### Monitoring
```bash
# Monitor all services
make monitor

# Check Kubernetes status
make status-k8s

# View logs
make logs-local    # Docker Compose logs
make logs-k8s      # Kubernetes logs
```

## 🔗 API Endpoints

### Cell A Gateway (Port 8010)
- `GET /health` - Health check
- `POST /users` - Create user
- `GET /users` - Get all users
- `GET /users/{id}` - Get user by ID
- `PUT /users/{id}` - Update user
- `DELETE /users/{id}` - Delete user
- `POST /products` - Create product
- `GET /products` - Get all products
- `GET /products/{id}` - Get product by ID
- `PUT /products/{id}` - Update product
- `DELETE /products/{id}` - Delete product
- `PUT /products/{id}/stock` - Update product stock
- Routes to Cell B: `/orders/*`, `/payments/*`

### Cell B Gateway (Port 8020)
- `GET /health` - Health check
- `POST /orders` - Create order
- `GET /orders` - Get all orders
- `GET /orders/{id}` - Get order by ID
- `PUT /orders/{id}/status` - Update order status
- `DELETE /orders/{id}` - Delete order
- `POST /payments` - Create payment
- `GET /payments` - Get all payments
- `GET /payments/{id}` - Get payment by ID
- `GET /payments/order/{order_id}` - Get payments by order
- `POST /payments/{id}/refund` - Refund payment
- Routes to Cell A: `/users/*`, `/products/*`

## 🚀 Deployment Options

### Local Development
```bash
make deploy-local
```

### Kubernetes
```bash
make deploy-k8s
make port-forward  # Access services locally
```

### Individual Cell Deployment
```bash
# Deploy only Cell A
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/cell-a/

# Deploy only Cell B
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/cell-b/
```

## 📈 Research Applications

This architecture demonstrates:
- **Cell Autonomy**: Each cell can operate independently
- **Service Mesh Patterns**: Inter-cell communication through gateways
- **Fault Isolation**: Cell failures don't cascade
- **Scalability**: Cells can be scaled independently
- **Load Distribution**: Traffic distributed across cells
- **Data Locality**: Services co-located with related data

## 🛠️ Development

### Adding New Services
1. Create service directory under appropriate cell
2. Follow existing patterns for configuration
3. Add Kubernetes manifests
4. Update docker-compose.yaml
5. Add integration tests

### Adding New Cells
1. Create new cell directory (e.g., `cell-c/`)
2. Add gateway and services
3. Update routing in existing gateways
4. Add Kubernetes manifests
5. Update build scripts

## 📝 License

This is a research project - use and modify as needed for your research purposes.