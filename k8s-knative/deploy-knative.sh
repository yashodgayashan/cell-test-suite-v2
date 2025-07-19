#!/bin/bash

echo "Deploying Knative resources..."

# Create namespaces first
echo "Creating namespaces..."
kubectl apply -f namespaces.yaml

# Wait for namespaces to be ready
kubectl wait --for=condition=Active namespace/cell-a --timeout=60s
kubectl wait --for=condition=Active namespace/cell-b --timeout=60s

# Deploy cell-a services
echo "Deploying cell-a services..."
kubectl apply -f cell-a/gateway.yaml
kubectl apply -f cell-a/user-service.yaml
kubectl apply -f cell-a/product-service.yaml

# Deploy cell-b services
echo "Deploying cell-b services..."
kubectl apply -f cell-b/gateway.yaml
kubectl apply -f cell-b/order-service.yaml
kubectl apply -f cell-b/payment-service.yaml

# Wait for Knative services to be ready
echo "Waiting for Knative services to be ready..."
kubectl wait --for=condition=Ready kservice/cell-a-gateway -n cell-a --timeout=300s
kubectl wait --for=condition=Ready kservice/cell-a-user-service -n cell-a --timeout=300s
kubectl wait --for=condition=Ready kservice/cell-a-product-service -n cell-a --timeout=300s
kubectl wait --for=condition=Ready kservice/cell-b-gateway -n cell-b --timeout=300s
kubectl wait --for=condition=Ready kservice/cell-b-order-service -n cell-b --timeout=300s
kubectl wait --for=condition=Ready kservice/cell-b-payment-service -n cell-b --timeout=300s

# Deploy ingress (choose one based on your setup)
echo "Deploying ingress..."
# For standard Kubernetes ingress:
kubectl apply -f ingress.yaml

# For Knative-specific ingress (uncomment if using Kourier):
# kubectl apply -f knative-ingress.yaml

echo "Deployment complete!"
echo ""
echo "Service URLs:"
echo "Cell-A Gateway: http://cell-a-gateway.cell-a.svc.cluster.local"
echo "Cell-B Gateway: http://cell-b-gateway.cell-b.svc.cluster.local"
echo ""
echo "External URLs (if ingress is configured):"
echo "Cell-A: http://cell-a.local"
echo "Cell-B: http://cell-b.local" 