PHONY: build test deploy clean help cell-a cell-b

help: ## Show this help message
	@echo "Cell-Based Architecture Test Suite"
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $1, $2}' $(MAKEFILE_LIST)

build: ## Build all cell components
	@echo "Building all cell components..."
	@chmod +x scripts/build-all.sh
	@./scripts/build-all.sh

cell-a: ## Build Cell A components only
	@echo "Building Cell A components..."
	@cd cell-a/gateway && docker build -t cell-a-gateway:latest .
	@cd cell-a/user-service && docker build -t cell-a-user-service:latest .
	@cd cell-a/product-service && docker build -t cell-a-product-service:latest .

cell-b: ## Build Cell B components only
	@echo "Building Cell B components..."
	@cd cell-b/gateway && docker build -t cell-b-gateway:latest .
	@cd cell-b/order-service && docker build -t cell-b-order-service:latest .
	@cd cell-b/payment-service && docker build -t cell-b-payment-service:latest .

test: ## Run integration tests
	@echo "Running integration tests..."
	@go test -v ./test/...

deploy-local: ## Deploy using Docker Compose
	@echo "Deploying locally with Docker Compose..."
	@docker-compose up -d

deploy-k8s: ## Deploy to Kubernetes
	@echo "Deploying to Kubernetes..."
	@chmod +x scripts/deploy-k8s.sh
	@./scripts/deploy-k8s.sh

test-communication: ## Test inter-cell communication
	@echo "Testing cell communication..."
	@chmod +x scripts/test-cell-communication.sh
	@./scripts/test-cell-communication.sh

monitor: ## Monitor cell health
	@echo "Starting cell monitoring..."
	@chmod +x scripts/monitor-cells.sh
	@./scripts/monitor-cells.sh

clean: ## Clean up all resources
	@echo "Cleaning up..."
	@chmod +x scripts/cleanup-cells.sh
	@./scripts/cleanup-cells.sh

logs-local: ## Show Docker Compose logs
	@docker-compose logs -f

logs-k8s: ## Show Kubernetes logs
	@kubectl logs -f -l cell=cell-a -n cell-architecture --max-log-requests=10
	@kubectl logs -f -l cell=cell-b -n cell-architecture --max-log-requests=10

status-k8s: ## Show Kubernetes status
	@echo "=== Cell A Status ==="
	@kubectl get pods,services -l cell=cell-a -n cell-architecture
	@echo "=== Cell B Status ==="
	@kubectl get pods,services -l cell=cell-b -n cell-architecture

port-forward: ## Set up port forwarding for Kubernetes
	@kubectl port-forward svc/cell-a-gateway 8010:8010 -n cell-architecture &
	@kubectl port-forward svc/cell-b-gateway 8020:8020 -n cell-architecture &
	@kubectl port-forward svc/cell-a-user-service 8011:8011 -n cell-architecture &
	@kubectl port-forward svc/cell-a-product-service 8012:8012 -n cell-architecture &
	@kubectl port-forward svc/cell-b-order-service 8021:8021 -n cell-architecture &
	@kubectl port-forward svc/cell-b-payment-service 8022:8022 -n cell-architecture &