#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Quick K6 Setup for KEDA Load Testing${NC}"
echo "========================================="

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "ubuntu"
        elif command -v yum >/dev/null 2>&1; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Install k6
install_k6() {
    local os=$(detect_os)
    
    echo -e "${YELLOW}Installing k6 for $os...${NC}"
    
    case $os in
        "ubuntu")
            sudo gpg -k
            sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
            echo 'deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main' | sudo tee /etc/apt/sources.list.d/k6.list
            sudo apt-get update
            sudo apt-get install -y k6
            ;;
        "macos")
            if command -v brew >/dev/null 2>&1; then
                brew install k6
            else
                echo -e "${RED}Homebrew not found. Please install Homebrew first:${NC}"
                echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                exit 1
            fi
            ;;
        "redhat")
            sudo dnf install https://dl.k6.io/rpm/repo.rpm -y
            sudo dnf install k6 -y
            ;;
        *)
            echo -e "${RED}Unsupported OS. Please install k6 manually:${NC}"
            echo "https://k6.io/docs/get-started/installation/"
            exit 1
            ;;
    esac
}

# Check if k6 is already installed
if command -v k6 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ k6 is already installed: $(k6 version)${NC}"
else
    echo -e "${YELLOW}k6 not found. Installing...${NC}"
    install_k6
fi

# Verify installation
if k6 version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ k6 installation successful!${NC}"
    k6 version
else
    echo -e "${RED}❌ k6 installation failed${NC}"
    exit 1
fi

echo -e "\n${BLUE}🔧 Setup Check${NC}"

# Check KEDA deployment
echo -e "${YELLOW}Checking KEDA deployment...${NC}"
if kubectl get pods -n keda | grep -q "interceptor.*Running"; then
    echo -e "${GREEN}✅ KEDA HTTP interceptor is running${NC}"
else
    echo -e "${RED}❌ KEDA HTTP interceptor not found${NC}"
    echo "Please deploy KEDA first:"
    echo "  ./deploy.sh all"
    exit 1
fi

# Check port forwarding
echo -e "${YELLOW}Checking KEDA HTTP interceptor access...${NC}"
if curl -s --max-time 5 http://localhost:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ KEDA HTTP interceptor accessible on port 8080${NC}"
else
    echo -e "${YELLOW}⚠️  KEDA HTTP interceptor not accessible on port 8080${NC}"
    echo "Starting port forwarding in background..."
    kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080 >/dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    
    # Wait for port forward to establish
    echo -e "${BLUE}Waiting for port forward to establish...${NC}"
    sleep 5
    
    if curl -s --max-time 5 http://localhost:8080/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Port forwarding established${NC}"
        echo "Port forward PID: $PORT_FORWARD_PID (will continue in background)"
    else
        echo -e "${RED}❌ Failed to establish port forwarding${NC}"
        kill $PORT_FORWARD_PID 2>/dev/null || true
        echo "Please start port forwarding manually:"
        echo "  kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080"
        exit 1
    fi
fi

# Check cell deployment
echo -e "${YELLOW}Checking cell deployment...${NC}"
cell_a_pods=$(kubectl get pods -n cell-a --no-headers 2>/dev/null | wc -l)
cell_b_pods=$(kubectl get pods -n cell-b --no-headers 2>/dev/null | wc -l)

if [ "$cell_a_pods" -gt 0 ] && [ "$cell_b_pods" -gt 0 ]; then
    echo -e "${GREEN}✅ Cell deployments found (Cell A: $cell_a_pods pods, Cell B: $cell_b_pods pods)${NC}"
else
    echo -e "${YELLOW}⚠️  Cell deployments not found${NC}"
    echo "Please deploy the cells first:"
    echo "  ./deploy.sh deploy"
fi

echo -e "\n${BLUE}🧪 Quick Test${NC}"

# Create a simple test script
cat > /tmp/quick-test.js << 'EOF'
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '30s', target: 5 },
    { duration: '1m', target: 5 },
    { duration: '30s', target: 0 },
  ],
};

const BASE_URL = 'http://localhost:8080';

export default function () {
  const response = http.get(`${BASE_URL}/health`, {
    headers: { 'Host': 'cell-a-gateway.local' }
  });
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });
}
EOF

echo -e "${YELLOW}Running quick connectivity test (2 minutes)...${NC}"
if k6 run /tmp/quick-test.js; then
    echo -e "${GREEN}✅ Quick test successful!${NC}"
else
    echo -e "${RED}❌ Quick test failed${NC}"
    echo "Please check:"
    echo "  1. KEDA deployment status"
    echo "  2. Port forwarding"
    echo "  3. Cell deployment"
fi

# Cleanup
rm -f /tmp/quick-test.js

echo -e "\n${GREEN}🎉 Setup Complete!${NC}"
echo -e "\n${BLUE}Available Load Tests:${NC}"
echo "  ./run-load-tests.sh basic      # Basic scaling test (12 min)"
echo "  ./run-load-tests.sh spike      # Spike test (7 min)"
echo "  ./run-load-tests.sh services   # Service scaling test (9 min)"
echo "  ./run-load-tests.sh cross-cell # Cross-cell test (6 min)"
echo "  ./run-load-tests.sh all        # Full suite (~35 min)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Run a basic test: ./run-load-tests.sh basic"
echo "2. Monitor scaling: kubectl get pods -n cell-a -n cell-b -w"
echo "3. View test documentation: cat k6-load-tests/README.md"

echo -e "\n${PURPLE}💡 Pro Tips:${NC}"
echo "- Run tests in a separate terminal to monitor pod scaling"
echo "- Use ./run-load-tests.sh monitor for real-time pod monitoring"
echo "- Check results in generated JSON files and log files" 