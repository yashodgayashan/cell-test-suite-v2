#!/bin/bash

echo "Deploying Cell A components only..."

# Create Cell A namespace
kubectl apply -f k8s/namespaces.yaml

# Deploy Cell A components
echo "Deploying Cell A components to cell-a namespace..."
kubectl apply -f k8s/cell-a/gateway.yaml
kubectl apply -f k8s/cell-a/user-service.yaml
kubectl apply -f k8s/cell-a/product-service.yaml

echo "Waiting for Cell A deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cell-a-gateway -n cell-a
kubectl wait --for=condition=available --timeout=300s deployment/cell-a-user-service -n cell-a
kubectl wait --for=condition=available --timeout=300s deployment/cell-a-product-service -n cell-a

echo "Cell A deployment completed!"
kubectl get pods,services -n cell-a
