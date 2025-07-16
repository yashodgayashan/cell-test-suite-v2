#!/bin/bash

echo "Deploying Cell B components only..."

# Create Cell B namespace
kubectl apply -f k8s/namespaces.yaml

# Deploy Cell B components
echo "Deploying Cell B components to cell-b namespace..."
kubectl apply -f k8s/cell-b/gateway.yaml
kubectl apply -f k8s/cell-b/order-service.yaml
kubectl apply -f k8s/cell-b/payment-service.yaml

echo "Waiting for Cell B deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cell-b-gateway -n cell-b
kubectl wait --for=condition=available --timeout=300s deployment/cell-b-order-service -n cell-b
kubectl wait --for=condition=available --timeout=300s deployment/cell-b-payment-service -n cell-b

echo "Cell B deployment completed!"
kubectl get pods,services -n cell-b