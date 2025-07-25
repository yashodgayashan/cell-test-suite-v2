#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== KEDA HTTP Scaling Test Suite ===${NC}"

# Configuration
INTERCEPTOR_URL="http://localhost:8080"
CELL_A_HOST="cell-a-gateway.local"
CELL_B_HOST="cell-b-gateway.local"

# Function to check if port-forward is active
check_port_forward() {
    if ! curl -s --max-time 5 "$INTERCEPTOR_URL/health" >/dev/null 2>&1; then
        echo -e "${RED}Error: Cannot reach KEDA interceptor at $INTERCEPTOR_URL${NC}"
        echo -e "${YELLOW}Please run: kubectl port-forward -n keda svc/keda-add-ons-http-interceptor-proxy 8080:8080${NC}"
        exit 1
    fi
}

# Function to watch pods in background
watch_pods() {
    local namespace=$1
    echo -e "${BLUE}Watching pods in namespace: $namespace${NC}"
    kubectl get pods -n "$namespace" -w &
    WATCH_PID=$!
}

# Function to stop watching
stop_watch() {
    if [ ! -z "${WATCH_PID:-}" ]; then
        kill $WATCH_PID 2>/dev/null || true
    fi
}

# Function to test endpoint
test_endpoint() {
    local host=$1
    local path=$2
    local description=$3
    
    echo -e "\n${YELLOW}Testing: $description${NC}"
    echo -e "${BLUE}Request: curl -H \"Host: $host\" $INTERCEPTOR_URL$path${NC}"
    
    response=$(curl -s -H "Host: $host" "$INTERCEPTOR_URL$path" || echo "ERROR")
    if [ "$response" = "ERROR" ]; then
        echo -e "${RED}❌ Request failed${NC}"
    else
        echo -e "${GREEN}✅ Response: $response${NC}"
    fi
    
    # Give time for scaling
    sleep 2
}

# Function to show current pod status
show_pod_status() {
    echo -e "\n${BLUE}=== Current Pod Status ===${NC}"
    echo -e "${YELLOW}Cell A Pods:${NC}"
    kubectl get pods -n cell-a --no-headers 2>/dev/null | wc -l | xargs echo "Pod count:"
    kubectl get pods -n cell-a
    
    echo -e "\n${YELLOW}Cell B Pods:${NC}"
    kubectl get pods -n cell-b --no-headers 2>/dev/null | wc -l | xargs echo "Pod count:"
    kubectl get pods -n cell-b
}

# Function to load test
load_test() {
    local host=$1
    local path=$2
    local requests=$3
    
    echo -e "\n${YELLOW}Running load test: $requests requests to $host$path${NC}"
    
    for i in $(seq 1 "$requests"); do
        curl -s -H "Host: $host" "$INTERCEPTOR_URL$path" >/dev/null &
        if [ $((i % 5)) -eq 0 ]; then
            echo -e "${BLUE}Sent $i requests...${NC}"
            sleep 1
        fi
    done
    
    wait
    echo -e "${GREEN}Load test completed!${NC}"
}

# Trap to cleanup
trap stop_watch EXIT

# Main test execution
case "${1:-}" in
    "basic")
        echo -e "${YELLOW}Running basic scaling tests...${NC}"
        check_port_forward
        
        show_pod_status
        
        # Test Cell A services
        test_endpoint "$CELL_A_HOST" "/health" "Cell A Gateway Health"
        test_endpoint "$CELL_A_HOST" "/users" "Cell A User Service"
        test_endpoint "$CELL_A_HOST" "/products" "Cell A Product Service"
        
        show_pod_status
        
        # Test Cell B services  
        test_endpoint "$CELL_B_HOST" "/health" "Cell B Gateway Health"
        test_endpoint "$CELL_B_HOST" "/orders" "Cell B Order Service"
        test_endpoint "$CELL_B_HOST" "/payments" "Cell B Payment Service"
        
        show_pod_status
        
        # Test cross-cell communication
        test_endpoint "$CELL_B_HOST" "/users" "Cross-cell: Cell B accessing Cell A users"
        test_endpoint "$CELL_A_HOST" "/orders" "Cross-cell: Cell A accessing Cell B orders"
        
        show_pod_status
        ;;
        
    "load")
        echo -e "${YELLOW}Running load tests to trigger scaling...${NC}"
        check_port_forward
        
        # Start watching Cell A pods
        watch_pods "cell-a"
        
        echo -e "\n${BLUE}Initial state - all pods should be at 0${NC}"
        show_pod_status
        
        # Generate load on Cell A
        load_test "$CELL_A_HOST" "/users" 20
        
        echo -e "\n${BLUE}After load test - checking scaled pods${NC}"
        sleep 5
        show_pod_status
        
        echo -e "\n${YELLOW}Waiting for scale down (this takes about 60 seconds)...${NC}"
        sleep 60
        
        echo -e "\n${BLUE}After scale down period${NC}"
        show_pod_status
        ;;
        
    "watch")
        namespace=${2:-"cell-a"}
        echo -e "${YELLOW}Watching pods in namespace: $namespace${NC}"
        echo -e "${BLUE}Press Ctrl+C to stop watching${NC}"
        kubectl get pods -n "$namespace" -w
        ;;
        
    "status")
        echo -e "${YELLOW}Checking HTTPScaledObjects status...${NC}"
        kubectl get httpscaledobjects -A
        
        echo -e "\n${YELLOW}Detailed status for Cell A Gateway:${NC}"
        kubectl describe httpscaledobject cell-a-gateway -n cell-a
        ;;
        
    "interactive")
        echo -e "${YELLOW}Interactive testing mode${NC}"
        check_port_forward
        
        while true; do
            echo -e "\n${BLUE}=== Interactive KEDA HTTP Scaling Test ===${NC}"
            echo "1. Test Cell A Gateway"
            echo "2. Test Cell B Gateway"  
            echo "3. Test Cell A User Service"
            echo "4. Test Cell B Order Service"
            echo "5. Run load test on Cell A"
            echo "6. Show pod status"
            echo "7. Show HTTPScaledObject status"
            echo "8. Exit"
            
            read -p "Choose option (1-8): " choice
            
            case $choice in
                1) test_endpoint "$CELL_A_HOST" "/health" "Cell A Gateway" ;;
                2) test_endpoint "$CELL_B_HOST" "/health" "Cell B Gateway" ;;
                3) test_endpoint "$CELL_A_HOST" "/users" "Cell A User Service" ;;
                4) test_endpoint "$CELL_B_HOST" "/orders" "Cell B Order Service" ;;
                5) load_test "$CELL_A_HOST" "/users" 10 ;;
                6) show_pod_status ;;
                7) kubectl get httpscaledobjects -A ;;
                8) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
                *) echo -e "${RED}Invalid option${NC}" ;;
            esac
        done
        ;;
        
    *)
        echo "Usage: $0 [basic|load|watch|status|interactive]"
        echo ""
        echo "Commands:"
        echo "  basic       Run basic scaling tests"
        echo "  load        Run load tests to trigger scaling"
        echo "  watch       Watch pods in namespace (default: cell-a)"
        echo "  status      Show HTTPScaledObject status"
        echo "  interactive Interactive testing mode"
        echo ""
        echo "Prerequisites:"
        echo "  kubectl port-forward -n keda svc/keda-add-on-http-interceptor-proxy 8080:8080"
        exit 1
        ;;
esac

echo -e "\n${GREEN}=== Test completed! ===${NC}" 