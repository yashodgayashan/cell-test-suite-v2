#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}🚀 KEDA HTTP Scaling - Quick Start${NC}"
echo "=================================="

echo -e "\n${YELLOW}📁 Workflow-Based Structure:${NC}"
echo "  1️⃣  1-setup/   - Tools installation & configuration (hybrid fix available)"
echo "  2️⃣  2-deploy/  - K8s manifests & deployment"  
echo "  3️⃣  3-test/    - Testing & validation"
echo "  📚 docs/      - Comprehensive documentation"
echo "  📋 CURRENT_STATUS.md - System status & configuration state"

echo -e "\n${YELLOW}🎯 Quick Actions:${NC}"

# Function to run script in appropriate workflow directory
run_script() {
    local script_path=$1
    shift
    if [[ "$script_path" == *"/"* ]]; then
        # Path includes directory
        local dir=$(dirname "$script_path")
        local script=$(basename "$script_path")
        cd "$dir" && ./"$script" "$@"
    else
        # Find script in workflow directories
        for dir in 1-setup 2-deploy 3-test; do
            if [[ -f "$dir/$script_path" ]]; then
                cd "$dir" && ./"$script_path" "$@"
                return
            fi
        done
        echo "Script $script_path not found in workflow directories"
        return 1
    fi
}

case "${1:-}" in
    "deploy")
        echo -e "${GREEN}Deploying KEDA + cells...${NC}"
        run_script 2-deploy/deploy.sh all
        ;;
    "test")
        echo -e "${GREEN}Running basic functionality tests...${NC}"
        run_script 3-test/test-scaling.sh basic
        ;;
    "demo")
        echo -e "${GREEN}Running working features demo...${NC}"
        run_script 3-test/demo-working-features.sh
        ;;
    "k6-setup")
        echo -e "${GREEN}Setting up K6 load testing...${NC}"
        run_script 1-setup/quick-k6-setup.sh
        ;;
    "load-test")
        shift
        test_type=${1:-basic}
        echo -e "${GREEN}Running K6 load test: $test_type${NC}"
        run_script 3-test/run-load-tests.sh "$test_type"
        ;;
    "status")
        echo -e "${GREEN}Checking deployment status...${NC}"
        run_script 2-deploy/deploy.sh status
        ;;
    "tools")
        echo -e "${GREEN}Showing all available tools...${NC}"
        ./show-all-tools.sh
        ;;
    "docs")
        echo -e "${GREEN}Available documentation:${NC}"
        echo "  GETTING_STARTED.md                # Complete step-by-step flow"
        echo "  CURRENT_STATUS.md                 # Current system status"
        echo "  docs/README.md                    # Main setup guide"
        echo "  docs/FINAL_SUCCESS_SUMMARY.md    # Complete success summary"
        echo "  1-setup/README.md                 # Setup workflow"
        echo "  2-deploy/README.md                # Deployment workflow"
        echo "  3-test/README.md                  # Testing workflow"
        ;;
    "monitor")
        echo -e "${GREEN}Monitoring pod scaling...${NC}"
        kubectl get pods -n cell-a -n cell-b -w
        ;;
    "port-forward")
        echo -e "${GREEN}Starting port forwarding...${NC}"
        kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080
        ;;
    *)
        echo -e "\n${YELLOW}Usage: $0 [command]${NC}"
        echo ""
        echo -e "${GREEN}🚀 Deployment:${NC}"
        echo "  deploy              # Deploy complete KEDA + cells"
        echo "  status              # Check deployment status"
        echo ""
        echo -e "${GREEN}🧪 Testing:${NC}"
        echo "  test                # Run basic functionality tests"
        echo "  demo                # Run working features demo"
        echo "  k6-setup            # Setup K6 load testing"
        echo "  load-test [type]    # Run K6 load test (basic/spike/services/cross-cell/all)"
        echo ""
        echo -e "${GREEN}📊 Monitoring:${NC}"
        echo "  monitor             # Watch pod scaling"
        echo "  port-forward        # Start KEDA interceptor port forwarding"
        echo ""
        echo -e "${GREEN}🛠️  Utilities:${NC}"
        echo "  tools               # Show all available tools"
        echo "  docs                # List documentation"
        echo ""
        echo -e "${PURPLE}💡 Examples:${NC}"
        echo "  $0 deploy           # Complete deployment"
        echo "  $0 test             # Basic functionality test"
        echo "  $0 load-test basic  # Basic load test"
        echo "  $0 load-test all    # Complete load test suite"
        echo ""
        echo -e "${BLUE}📖 For complete step-by-step guide, see: GETTING_STARTED.md${NC}"
        ;;
esac 