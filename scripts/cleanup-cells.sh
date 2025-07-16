#!/bin/bash

echo "Cleaning up Cell-Based Architecture..."

# Stop and remove Docker containers
docker-compose down

# Remove Docker images
docker rmi cell-a-gateway:latest cell-a-user-service:latest cell-a-product-service:latest 2>/dev/null || true
docker rmi cell-b-gateway:latest cell-b-order-service:latest cell-b-payment-service:latest 2>/dev/null || true

# Clean up Kubernetes resources
kubectl delete namespace cell-a
kubectl delete namespace cell-b

echo "Cleanup completed!"