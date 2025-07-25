#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}🚀 KEDA HTTP Scaling Load Tests${NC}"
echo "=================================="

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    if ! command -v k6 >/dev/null 2>&1; then
        echo -e "${RED}❌ k6 is not installed${NC}"
        echo "Install k6:"
        echo "  # Ubuntu/Debian:"
        echo "  sudo gpg -k && sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69"
        echo "  echo 'deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main' | sudo tee /etc/apt/sources.list.d/k6.list"
        echo "  sudo apt-get update && sudo apt-get install k6"
        echo ""
        echo "  # macOS:"
        echo "  brew install k6"
        echo ""
        echo "  # Or download from: https://k6.io/docs/get-started/installation/"
        exit 1
    fi
    
    if ! kubectl get pods -n keda | grep -q "interceptor.*Running"; then
        echo -e "${RED}❌ KEDA HTTP interceptor is not running${NC}"
        echo "Please ensure KEDA is deployed and run:"
        echo "  ./deploy.sh all"
        exit 1
    fi
    
    if ! curl -s --max-time 5 http://localhost:8080/health >/dev/null 2>&1; then
        echo -e "${RED}❌ KEDA HTTP interceptor is not accessible on localhost:8080${NC}"
        echo "Please start port forwarding:"
        echo "  kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed!${NC}"
}

# Function to monitor pods during test
monitor_pods() {
    local duration=$1
    local test_name=$2
    
    echo -e "${PURPLE}📊 Monitoring pod scaling for ${duration}...${NC}"
    
    # Create monitoring script
    cat > /tmp/monitor_pods.sh << 'EOF'
#!/bin/bash
while true; do
    echo "=== $(date) ==="
    echo "Cell A Pods:"
    kubectl get pods -n cell-a --no-headers | wc -l | xargs echo "  Count:"
    kubectl get pods -n cell-a -o wide --no-headers | awk '{print "  " $1 " - " $3}' 2>/dev/null || echo "  No pods"
    echo "Cell B Pods:"
    kubectl get pods -n cell-b --no-headers | wc -l | xargs echo "  Count:"
    kubectl get pods -n cell-b -o wide --no-headers | awk '{print "  " $1 " - " $3}' 2>/dev/null || echo "  No pods"
    echo "HTTPScaledObjects Status:"
    kubectl get httpscaledobjects -A --no-headers | awk '{print "  " $2 " (" $1 ") - Min:" $6 " Max:" $7 " Active:" $9}'
    echo ""
    sleep 10
done
EOF
    
    chmod +x /tmp/monitor_pods.sh
    /tmp/monitor_pods.sh > "pod-scaling-${test_name}-$(date +%Y%m%d-%H%M%S).log" &
    MONITOR_PID=$!
    
    # Let it run for the test duration then kill it
    sleep $duration
    kill $MONITOR_PID 2>/dev/null || true
    wait $MONITOR_PID 2>/dev/null || true
    
    echo -e "${GREEN}📊 Pod monitoring saved to pod-scaling-${test_name}-*.log${NC}"
}

# Function to run a specific test
run_test() {
    local test_file=$1
    local test_name=$2
    local monitor_duration=$3
    
    echo -e "\n${BLUE}🧪 Running ${test_name}${NC}"
    echo "Test file: $test_file"
    echo "Expected duration: ~${monitor_duration}s"
    
    echo -e "${YELLOW}Initial pod status:${NC}"
    kubectl get pods -n cell-a -n cell-b
    
    echo -e "\n${YELLOW}Starting load test...${NC}"
    
    # Start monitoring in background
    monitor_pods $monitor_duration $test_name &
    MONITOR_PID=$!
    
    # Run the k6 test
    k6 run $test_file \
        --out json=results-${test_name}-$(date +%Y%m%d-%H%M%S).json \
        --summary-trend-stats="avg,min,med,max,p(90),p(95),p(99),count" \
        --summary-time-unit=ms
    
    # Stop monitoring
    kill $MONITOR_PID 2>/dev/null || true
    wait $MONITOR_PID 2>/dev/null || true
    
    echo -e "\n${YELLOW}Final pod status:${NC}"
    kubectl get pods -n cell-a -n cell-b
    
    echo -e "${GREEN}✅ ${test_name} completed!${NC}"
}

# Function to show post-test analysis
show_analysis() {
    echo -e "\n${BLUE}📈 Post-Test Analysis${NC}"
    echo "====================="
    
    echo -e "\n${YELLOW}HTTPScaledObjects Status:${NC}"
    kubectl get httpscaledobjects -A
    
    echo -e "\n${YELLOW}Recent Scaling Events:${NC}"
    kubectl get events -n cell-a --sort-by='.lastTimestamp' | grep -E "(Scaled|ScaledObject)" | tail -5 || echo "No recent scaling events in cell-a"
    kubectl get events -n cell-b --sort-by='.lastTimestamp' | grep -E "(Scaled|ScaledObject)" | tail -5 || echo "No recent scaling events in cell-b"
    
    echo -e "\n${YELLOW}Current Resource Usage:${NC}"
    kubectl top pods -n cell-a 2>/dev/null || echo "Metrics not available for cell-a"
    kubectl top pods -n cell-b 2>/dev/null || echo "Metrics not available for cell-b"
    
    echo -e "\n${PURPLE}📋 Test Results Summary:${NC}"
    if ls results-*.json >/dev/null 2>&1; then
        echo "Test result files:"
        ls -la results-*.json
        echo ""
        echo "Pod monitoring logs:"
        ls -la pod-scaling-*.log 2>/dev/null || echo "No monitoring logs found"
    else
        echo "No result files found"
    fi
}

# Main execution
case "${1:-}" in
    "basic")
        check_prerequisites
        run_test "basic-scaling-test.js" "basic-scaling" 720
        show_analysis
        ;;
        
    "spike")
        check_prerequisites  
        run_test "spike-test.js" "spike-test" 420
        show_analysis
        ;;
        
    "services")
        check_prerequisites
        run_test "service-load-test.js" "service-load" 540
        show_analysis
        ;;
        
    "cross-cell")
        check_prerequisites
        run_test "cross-cell-test.js" "cross-cell" 360
        show_analysis
        echo -e "\n${YELLOW}📋 Cross-Cell Test Note:${NC}"
        echo "Cross-cell communication may show failures - this is expected without Host header support."
        echo "See APPLICATION_CHANGES_REQUIRED.md for implementation details."
        if [ -f "cross-cell-summary.json" ]; then
            echo -e "\n${PURPLE}Cross-Cell Summary:${NC}"
            cat cross-cell-summary.json
        fi
        ;;
        
    "all")
        check_prerequisites
        echo -e "${BLUE}🎯 Running comprehensive load test suite${NC}"
        echo "This will take approximately 30-40 minutes"
        echo ""
        read -p "Continue with full test suite? (y/N): " confirm
        if [[ $confirm != [yY] ]]; then
            echo "Cancelled."
            exit 0
        fi
        
        run_test "basic-scaling-test.js" "basic-scaling" 720
        echo -e "\n${PURPLE}⏳ Waiting 2 minutes for system to stabilize...${NC}"
        sleep 120
        
        run_test "service-load-test.js" "service-load" 540  
        echo -e "\n${PURPLE}⏳ Waiting 2 minutes for system to stabilize...${NC}"
        sleep 120
        
        run_test "spike-test.js" "spike-test" 420
        echo -e "\n${PURPLE}⏳ Waiting 2 minutes for system to stabilize...${NC}" 
        sleep 120
        
        run_test "cross-cell-test.js" "cross-cell" 360
        
        show_analysis
        echo -e "\n${GREEN}🎉 Comprehensive load testing completed!${NC}"
        ;;
        
    "monitor")
        echo -e "${PURPLE}📊 Pod monitoring mode${NC}"
        echo "Monitoring pod scaling in real-time. Press Ctrl+C to stop."
        kubectl get pods -n cell-a -n cell-b -w
        ;;
        
    "clean")
        echo -e "${YELLOW}🧹 Cleaning up test artifacts...${NC}"
        rm -f results-*.json pod-scaling-*.log cross-cell-summary.json /tmp/monitor_pods.sh
        echo -e "${GREEN}✅ Cleanup completed!${NC}"
        ;;
        
    *)
        echo "Usage: $0 [basic|spike|services|cross-cell|all|monitor|clean]"
        echo ""
        echo "Load Tests:"
        echo "  basic      - Basic scaling test (12 minutes)"
        echo "  spike      - Spike load test (7 minutes)" 
        echo "  services   - Service scaling test (9 minutes)"
        echo "  cross-cell - Cross-cell communication test (6 minutes)"
        echo "  all        - Run all tests sequentially (~35 minutes)"
        echo ""
        echo "Utilities:"
        echo "  monitor    - Real-time pod monitoring"
        echo "  clean      - Clean up test result files"
        echo ""
        echo "Prerequisites:"
        echo "  1. Install k6: https://k6.io/docs/get-started/installation/"
        echo "  2. Deploy KEDA: ./deploy.sh all"
        echo "  3. Port forward: kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080"
        exit 1
        ;;
esac

echo -e "\n${GREEN}=== Load testing completed! ===${NC}" 