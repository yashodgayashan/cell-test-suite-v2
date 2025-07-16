#!/bin/bash

echo "Building Cell-Based Architecture Components..."

# Build Cell A
echo "Building Cell A components..."
cd cell-a/gateway
docker build -t yashodperera/cell-a-gateway:latest .
docker push yashodperera/cell-a-gateway:latest
cd ../user-service
docker build -t yashodperera/cell-a-user-service:latest .
docker push yashodperera/cell-a-user-service:latest
cd ../product-service
docker build -t yashodperera/cell-a-product-service:latest .
docker push yashodperera/cell-a-product-service:latest
cd ../..

# Build Cell B
echo "Building Cell B components..."
cd cell-b/gateway
docker build -t yashodperera/cell-b-gateway:latest .
docker push yashodperera/cell-b-gateway:latest
cd ../order-service
docker build -t yashodperera/cell-b-order-service:latest .
docker push yashodperera/cell-b-order-service:latest
cd ../payment-service
docker build -t yashodperera/cell-b-payment-service:latest .
docker push yashodperera/cell-b-payment-service:latest
cd ../..

echo "All cell components built successfully!"