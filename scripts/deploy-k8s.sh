#!/bin/bash

echo "Deploying Cell-Based Architecture with Separate Namespaces..."

# Create namespaces
kubectl apply -f k8s/namespaces.yaml

# Deploy Cell A components
echo "Deploying Cell A components to cell-a namespace..."
kubectl apply -f k8s/cell-a/gateway.yaml
kubectl apply -f k8s/cell-a/user-service.yaml
kubectl apply -f k8s/cell-a/product-service.yaml

# Deploy Cell B components
echo "Deploying Cell B components to cell-b namespace..."
kubectl apply -f k8s/cell-b/gateway.yaml
kubectl apply -f k8s/cell-b/order-service.yaml
kubectl apply -f k8s/cell-b/payment-service.yaml

# echo "Applying network policies for cell isolation..."
# kubectl apply -f k8s/network-policies.yaml

# Deploy ingress
echo "Deploying ingress for both cells..."
kubectl apply -f k8s/ingress.yaml

echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cell-a-gateway -n cell-a
kubectl wait --for=condition=available --timeout=300s deployment/cell-a-user-service -n cell-a
kubectl wait --for=condition=available --timeout=300s deployment/cell-a-product-service -n cell-a
kubectl wait --for=condition=available --timeout=300s deployment/cell-b-gateway -n cell-b
kubectl wait --for=condition=available --timeout=300s deployment/cell-b-order-service -n cell-b
kubectl wait --for=condition=available --timeout=300s deployment/cell-b-payment-service -n cell-b

echo "All deployments are ready!"

# Show status
echo "=== Cell A Status ==="
kubectl get pods,services -n cell-a
echo
echo "=== Cell B Status ==="
kubectl get pods,services -n cell-b

# echo
# echo "=== Network Policies ==="
# kubectl get networkpolicies -n cell-a
# kubectl get networkpolicies -n cell-b