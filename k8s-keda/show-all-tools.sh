#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}🛠️  KEDA HTTP Scaling - Workflow-Based Tools${NC}"
echo "================================================"

echo -e "\n${YELLOW}1️⃣  Setup & Installation (1-setup/)${NC}"
echo "  cd 1-setup && ./quick-k6-setup.sh     # Install k6 & run connectivity test"
echo "  cd 1-setup && ./apply-hybrid-fix.sh   # Apply hybrid scaling configuration"

echo -e "\n${YELLOW}2️⃣  Deploy & Configuration (2-deploy/)${NC}"
echo "  cd 2-deploy && ./deploy.sh all        # Complete KEDA & cell deployment"
echo "  cd 2-deploy && ./deploy.sh install-keda # Install KEDA core only"
echo "  cd 2-deploy && ./deploy.sh install-http # Install KEDA HTTP add-on only"
echo "  cd 2-deploy && ./deploy.sh deploy     # Deploy cells only"
echo "  cd 2-deploy && ./deploy.sh status     # Show deployment status"

echo -e "\n${YELLOW}3️⃣  Testing & Validation (3-test/)${NC}"
echo "  cd 3-test && ./test-scaling.sh basic  # Comprehensive functionality test"
echo "  cd 3-test && ./test-scaling.sh interactive # Interactive testing menu"
echo "  cd 3-test && ./test-scaling.sh status # HTTPScaledObject status"
echo "  cd 3-test && ./demo-working-features.sh # Working features demonstration"

echo -e "\n${YELLOW}🚀 K6 Load Testing (3-test/)${NC}"
echo "  cd 3-test && ./run-load-tests.sh basic    # Basic scaling test (12 min)"
echo "  cd 3-test && ./run-load-tests.sh spike    # Spike traffic test (7 min)"
echo "  cd 3-test && ./run-load-tests.sh services # Service scaling test (9 min)"
echo "  cd 3-test && ./run-load-tests.sh cross-cell # Cross-cell test (6 min)"
echo "  cd 3-test && ./run-load-tests.sh all      # Complete test suite (~35 min)"
echo "  cd 3-test && ./run-load-tests.sh monitor  # Real-time pod monitoring"
echo "  cd 3-test && ./run-load-tests.sh clean    # Clean up test artifacts"

echo -e "\n${YELLOW}📊 Monitoring & Analysis${NC}"
echo "  kubectl get httpscaledobjects -A   # View all HTTPScaledObjects"
echo "  kubectl get pods -n cell-a -n cell-b -w  # Watch pod scaling"
echo "  kubectl get events -n cell-a --sort-by='.lastTimestamp'  # Recent events"
echo "  kubectl describe httpscaledobject <name> -n <namespace>  # Detailed status"

echo -e "\n${YELLOW}🔗 Port Forwarding${NC}"
echo "  kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080"

echo -e "\n${YELLOW}📋 Quick Test Commands${NC}"
echo "  curl -H \"Host: cell-a-gateway.local\" http://localhost:8080/health"
echo "  curl -H \"Host: cell-a-gateway.local\" http://localhost:8080/users"
echo "  curl -H \"Host: cell-b-gateway.local\" http://localhost:8080/orders"

echo -e "\n${YELLOW}📚 Documentation${NC}"
echo "  docs/README.md                     # Detailed setup guide"
echo "  docs/FINAL_SUCCESS_SUMMARY.md     # Complete success summary"
echo "  docs/APPLICATION_CHANGES_REQUIRED.md # Future enhancement guide"
echo "  1-setup/README.md                  # Setup workflow guide"
echo "  2-deploy/README.md                 # Deployment workflow guide"
echo "  3-test/README.md                   # Testing workflow guide"

echo -e "\n${YELLOW}📁 Workflow Directory Structure${NC}"
echo "  k8s-keda/"
echo "  ├── 1️⃣  1-setup/    - Tools installation & configuration"
echo "  ├── 2️⃣  2-deploy/   - K8s manifests & deployment"
echo "  ├── 3️⃣  3-test/     - Testing & validation"
echo "  └── 📚 docs/       - Comprehensive documentation"

echo -e "\n${GREEN}🎯 Recommended Workflow:${NC}"
echo "1. Setup: cd 1-setup && ./quick-k6-setup.sh"
echo "2. Deploy: cd 2-deploy && ./deploy.sh all"
echo "3. Test: cd 3-test && ./test-scaling.sh basic"
echo "4. Load Test: cd 3-test && ./run-load-tests.sh basic"
echo "5. Monitor: kubectl get pods -n cell-a -n cell-b -w"

echo -e "\n${YELLOW}🚀 Quick Start (Root Directory)${NC}"
echo "  ./quick-start.sh deploy            # Deploy everything"
echo "  ./quick-start.sh test              # Run basic tests" 
echo "  ./quick-start.sh k6-setup          # Setup K6 load testing"
echo "  ./quick-start.sh load-test basic   # Run load tests"
echo "  ./quick-start.sh tools             # Show this overview"

echo -e "\n${PURPLE}💡 Pro Tips:${NC}"
echo "• Use ./quick-start.sh for one-command operations"
echo "• Each workflow directory (1-setup, 2-deploy, 3-test) has its own README"
echo "• Load test results are saved as JSON files and logs in 3-test/"
echo "• All services start with 0 replicas and scale based on HTTP traffic"

echo -e "\n${GREEN}Your cell-test-suite-v2 is now a workflow-optimized, auto-scaling system! 🎉${NC}" 