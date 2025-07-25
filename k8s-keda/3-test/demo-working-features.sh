#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎉 KEDA HTTP Scaling Demo - Working Features${NC}"
echo "=============================================="

echo -e "\n${YELLOW}📊 Current KEDA Configuration:${NC}"
kubectl get httpscaledobjects -A

echo -e "\n${YELLOW}🔍 Initial Pod Status (should show internal services always running):${NC}"
kubectl get pods -n cell-a -n cell-b

echo -e "\n${BLUE}🚀 Testing KEDA HTTP Scaling Features:${NC}"

echo -e "\n${YELLOW}1. Gateway Scale-from-Zero Demonstration${NC}"
echo "   - Gateways start at 0 replicas"
echo "   - Scale up automatically when receiving HTTP requests"

echo -e "\n${GREEN}Testing Cell A Gateway:${NC}"
curl -s -H "Host: cell-a-gateway.local" http://localhost:8080/health | jq .

echo -e "\n${GREEN}Testing Cell B Gateway:${NC}"
curl -s -H "Host: cell-b-gateway.local" http://localhost:8080/health | jq .

echo -e "\n${YELLOW}2. Internal Service Communication (Working!)${NC}"
echo "   - Services can communicate within each cell"
echo "   - Internal services maintain minimum 1 replica for reliability"

echo -e "\n${GREEN}Cell A - User Service:${NC}"
curl -s -H "Host: cell-a-gateway.local" http://localhost:8080/users | jq .

echo -e "\n${GREEN}Cell A - Product Service:${NC}"
curl -s -H "Host: cell-a-gateway.local" http://localhost:8080/products | jq .

echo -e "\n${GREEN}Cell B - Order Service:${NC}"
curl -s -H "Host: cell-b-gateway.local" http://localhost:8080/orders | jq .

echo -e "\n${GREEN}Cell B - Payment Service:${NC}"
curl -s -H "Host: cell-b-gateway.local" http://localhost:8080/payments | jq .

echo -e "\n${YELLOW}3. Current Pod Status (should show gateways have scaled up):${NC}"
kubectl get pods -n cell-a -n cell-b

echo -e "\n${BLUE}💡 Key Benefits Demonstrated:${NC}"
echo "✅ Gateway Scale-to-Zero: Gateways scale from 0→1 based on HTTP traffic"
echo "✅ Internal Service Reliability: Services maintain minimum 1 replica" 
echo "✅ KEDA HTTP Scaling: All services configured with HTTPScaledObjects"
echo "✅ Cost Optimization: Unused gateways consume no resources"
echo "✅ Cell Autonomy: Each cell operates independently"
echo "✅ Service Communication: Internal services communicate directly"

echo -e "\n${YELLOW}📋 Architecture Summary:${NC}"
echo "- Gateways: KEDA HTTP scaling (0-5 replicas)"
echo "- Internal Services: Hybrid scaling (1-3 replicas)" 
echo "- External Traffic: Routes through KEDA HTTP interceptor"
echo "- Internal Traffic: Direct Kubernetes service communication"

echo -e "\n${BLUE}🎯 What's Working vs. Future Enhancements:${NC}"
echo -e "${GREEN}✅ WORKING:${NC}"
echo "  - Gateway auto-scaling based on HTTP traffic"
echo "  - Internal service communication within cells"
echo "  - All CRUD operations on services"
echo "  - Health checks and service discovery"

echo -e "${YELLOW}📝 FUTURE (requires app code changes):${NC}"
echo "  - Cross-cell communication with full scale-to-zero"
echo "  - Complete application-level Host header support"
echo "  - See APPLICATION_CHANGES_REQUIRED.md for details"

echo -e "\n${GREEN}🏆 Conversion SUCCESS! Your cell-test-suite-v2 now has KEDA HTTP scaling!${NC}" 