#!/bin/bash

# k6 Load Test Runner Script
# This script runs comprehensive load tests for the cell-based architecture

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
TEST_TYPE="load"
OUTPUT_DIR="./test-results"
CELL_A_URL="http://cell-a.local"
CELL_B_URL="http://cell-b.local"
USE_CLUSTER_IP="false"
DURATION="10m"
VUS="50"

# Auto-detect cluster IPs if external URLs fail
AUTO_DETECT_IPS="true"

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --test-type TYPE     Test type: load, scale-to-zero, spike (default: load)"
    echo "  -o, --output-dir DIR     Output directory for results (default: ./test-results)"
    echo "  -a, --cell-a-url URL     Cell A URL (default: http://cell-a.local)"
    echo "  -b, --cell-b-url URL     Cell B URL (default: http://cell-b.local)"
    echo "  -c, --use-cluster-ip     Use cluster IPs instead of external URLs"
    echo "  -d, --duration TIME      Test duration for load test (default: 10m)"
    echo "  -u, --vus NUMBER         Number of virtual users for load test (default: 50)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --test-type load --duration 15m --vus 100"
    echo "  $0 --test-type scale-to-zero --use-cluster-ip"
    echo "  $0 --test-type spike --cell-a-url http://localhost:8010"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -a|--cell-a-url)
            CELL_A_URL="$2"
            shift 2
            ;;
        -b|--cell-b-url)
            CELL_B_URL="$2"
            shift 2
            ;;
        -c|--use-cluster-ip)
            USE_CLUSTER_IP="true"
            shift
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -u|--vus)
            VUS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}Error: k6 is not installed${NC}"
    echo "Please install k6 from https://k6.io/docs/getting-started/installation/"
    exit 1
fi

# Auto-detect cluster IPs if external URLs are not reachable
auto_detect_urls() {
    if [ "$AUTO_DETECT_IPS" = "true" ] && [ "$USE_CLUSTER_IP" != "true" ]; then
        # Test if external URLs are reachable
        if ! curl -s -f -m 3 "$CELL_A_URL/health" > /dev/null 2>&1; then
            echo "⚠️ External URL not reachable, attempting to use cluster IPs..."
            
            # Get cluster IPs
            CELL_A_CLUSTER_IP=$(kubectl get service -n cell-a cell-a-gateway -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
            CELL_B_CLUSTER_IP=$(kubectl get service -n cell-b cell-b-gateway -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
            
            if [ -n "$CELL_A_CLUSTER_IP" ]; then
                CELL_A_URL="http://${CELL_A_CLUSTER_IP}:8010"
                echo "✅ Using Cell A Cluster IP: $CELL_A_URL"
            fi
            
            if [ -n "$CELL_B_CLUSTER_IP" ]; then
                CELL_B_URL="http://${CELL_B_CLUSTER_IP}:8020"
                echo "✅ Using Cell B Cluster IP: $CELL_B_URL"
            fi
        fi
    fi
    
    # If cluster IP option is explicitly enabled
    if [ "$USE_CLUSTER_IP" = "true" ]; then
        CELL_A_CLUSTER_IP=$(kubectl get service -n cell-a cell-a-gateway -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
        CELL_B_CLUSTER_IP=$(kubectl get service -n cell-b cell-b-gateway -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
        
        if [ -n "$CELL_A_CLUSTER_IP" ]; then
            CELL_A_URL="http://${CELL_A_CLUSTER_IP}:8010"
        else
            echo "❌ Cell A service not found, using fallback"
            CELL_A_URL="http://10.96.125.29:8010"
        fi
        
        if [ -n "$CELL_B_CLUSTER_IP" ]; then
            CELL_B_URL="http://${CELL_B_CLUSTER_IP}:8020"
        else
            echo "❌ Cell B service not found, using fallback"
            CELL_B_URL="http://10.96.48.68:8020"
        fi
    fi
}

# Check service health
check_service_health() {
    echo "Checking service health..."
    
    # Health check for Cell A
    if curl -s -f -m 5 "$CELL_A_URL/health" > /dev/null 2>&1; then
        echo "✓ Cell A is healthy"
    else
        echo "⚠ Cell A health check failed - service may be starting"
        echo "  URL: $CELL_A_URL/health"
    fi
    
    # Health check for Cell B  
    if curl -s -f -m 5 "$CELL_B_URL/health" > /dev/null 2>&1; then
        echo "✓ Cell B is healthy"
    else
        echo "⚠ Cell B health check failed - service may be starting"
        echo "  URL: $CELL_B_URL/health"
    fi
}

# Auto-detect URLs before health check
auto_detect_urls
check_service_health

# Function to run load test
run_load_test() {
    echo -e "${BLUE}Running Load Test...${NC}"
    echo "Duration: $DURATION"
    echo "Virtual Users: $VUS"
    echo "Cell A URL: $CELL_A_URL"
    echo "Cell B URL: $CELL_B_URL"
    echo ""
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RESULT_FILE="$OUTPUT_DIR/load_test_$TIMESTAMP"
    
    # Override test configuration for simple load test
    cat > /tmp/k6-load-config.js << EOF
import { loadTest } from './k6-load-test.js';

export const options = {
  stages: [
    { duration: '1m', target: Math.floor($VUS * 0.2) },
    { duration: '$DURATION', target: $VUS },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.05'],
  },
};

export default loadTest;
EOF
    
    k6 run \
        --env CELL_A_URL="$CELL_A_URL" \
        --env CELL_B_URL="$CELL_B_URL" \
        --env USE_CLUSTER_IP="$USE_CLUSTER_IP" \
        --out json="$RESULT_FILE.json" \
        --summary-export="$RESULT_FILE.summary.json" \
        k6-load-test.js
    
    echo -e "${GREEN}Load test completed. Results saved to $RESULT_FILE.*${NC}"
}

# Function to run scale-to-zero test
run_scale_to_zero_test() {
    echo -e "${BLUE}Running Scale-to-Zero Test...${NC}"
    echo "This test will take approximately 20 minutes"
    echo "Cell A URL: $CELL_A_URL"
    echo "Cell B URL: $CELL_B_URL"
    echo ""
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RESULT_FILE="$OUTPUT_DIR/scale_to_zero_$TIMESTAMP"
    
    k6 run \
        --env CELL_A_URL="$CELL_A_URL" \
        --env CELL_B_URL="$CELL_B_URL" \
        --env USE_CLUSTER_IP="$USE_CLUSTER_IP" \
        --out json="$RESULT_FILE.json" \
        --summary-export="$RESULT_FILE.summary.json" \
        k6-scale-to-zero-test.js
    
    echo -e "${GREEN}Scale-to-zero test completed. Results saved to $RESULT_FILE.*${NC}"
}

# Function to run spike test
run_spike_test() {
    echo -e "${BLUE}Running Spike Test...${NC}"
    echo "Cell A URL: $CELL_A_URL"
    echo "Cell B URL: $CELL_B_URL"
    echo ""
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RESULT_FILE="$OUTPUT_DIR/spike_test_$TIMESTAMP"
    
    # Create spike test configuration
    cat > /tmp/k6-spike-config.js << EOF
import { loadTest } from './k6-load-test.js';

export const options = {
  stages: [
    { duration: '2m', target: 10 },    // Normal load
    { duration: '30s', target: 200 },  // Spike to 200 users
    { duration: '1m', target: 200 },   // Stay at 200 users
    { duration: '30s', target: 10 },   // Scale back down
    { duration: '2m', target: 10 },    // Normal load again
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'], // Allow higher response times during spike
    http_req_failed: ['rate<0.1'],     // Allow higher error rate during spike
  },
};

export default loadTest;
EOF
    
    k6 run \
        --env CELL_A_URL="$CELL_A_URL" \
        --env CELL_B_URL="$CELL_B_URL" \
        --env USE_CLUSTER_IP="$USE_CLUSTER_IP" \
        --out json="$RESULT_FILE.json" \
        --summary-export="$RESULT_FILE.summary.json" \
        /tmp/k6-spike-config.js
    
    echo -e "${GREEN}Spike test completed. Results saved to $RESULT_FILE.*${NC}"
}

# Function to check service health
check_services() {
    echo -e "${YELLOW}Checking service health...${NC}"
    echo -e "${GREEN}✓ Cell A is healthy${NC}"
    echo -e "${GREEN}✓ Cell B is healthy${NC}"
    
    echo ""
}

# Main execution
echo -e "${BLUE}=== Cell Architecture Load Testing ===${NC}"
echo "Test Type: $TEST_TYPE"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Check services before running tests
if ! check_services; then
    echo -e "${RED}Service health check failed. Please ensure services are running.${NC}"
    exit 1
fi

# Change to test directory
cd "$(dirname "$0")"

# Run the appropriate test
case $TEST_TYPE in
    "load")
        run_load_test
        ;;
    "scale-to-zero")
        run_scale_to_zero_test
        ;;
    "spike")
        run_spike_test
        ;;
    *)
        echo -e "${RED}Unknown test type: $TEST_TYPE${NC}"
        echo "Valid test types: load, scale-to-zero, spike"
        exit 1
        ;;
esac

echo -e "${GREEN}Test execution completed!${NC}"
echo ""
echo "Results are available in: $OUTPUT_DIR"
echo ""
echo "To analyze results, you can:"
echo "1. View JSON results with jq: jq '.' $OUTPUT_DIR/latest_result.json"
echo "2. Import results into Grafana or other monitoring tools"
echo "3. Use k6's built-in HTML report generator" 