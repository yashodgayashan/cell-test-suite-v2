#!/bin/bash

echo "=== Setting Up Port Forwards for Load Testing ==="

# Function to kill existing port forwards
cleanup_port_forwards() {
    echo "Cleaning up existing port forwards..."
    pkill -f "kubectl port-forward.*cell-a-gateway.*8010"
    pkill -f "kubectl port-forward.*cell-b-gateway.*8020"
    sleep 2
}

# Function to check if services exist
check_services() {
    echo "Checking if services exist..."
    
    CELL_A_SERVICE=$(kubectl get service -n cell-a cell-a-gateway 2>/dev/null)
    CELL_B_SERVICE=$(kubectl get service -n cell-b cell-b-gateway 2>/dev/null)
    
    if [ -z "$CELL_A_SERVICE" ]; then
        echo "❌ Cell A gateway service not found"
        echo "Please deploy the cell services first:"
        echo "kubectl apply -f ../k8s-knative/"
        exit 1
    fi
    
    if [ -z "$CELL_B_SERVICE" ]; then
        echo "❌ Cell B gateway service not found"
        echo "Please deploy the cell services first:"
        echo "kubectl apply -f ../k8s-knative/"
        exit 1
    fi
    
    echo "✅ Services found"
}

# Function to setup port forwards
setup_port_forwards() {
    echo "Setting up port forwards..."
    
    # Port forward Cell A gateway
    echo "Starting port forward for Cell A (8010 -> 8010)..."
    kubectl port-forward -n cell-a service/cell-a-gateway 8010:8010 &
    CELL_A_PID=$!
    
    # Port forward Cell B gateway  
    echo "Starting port forward for Cell B (8020 -> 8020)..."
    kubectl port-forward -n cell-b service/cell-b-gateway 8020:8020 &
    CELL_B_PID=$!
    
    # Wait a moment for port forwards to establish
    sleep 3
    
    # Verify port forwards are working
    echo "Verifying port forwards..."
    
    if netstat -tln | grep -q ":8010.*LISTEN"; then
        echo "✅ Cell A port forward active on :8010"
    else
        echo "❌ Cell A port forward failed"
        cleanup_port_forwards
        exit 1
    fi
    
    if netstat -tln | grep -q ":8020.*LISTEN"; then
        echo "✅ Cell B port forward active on :8020"
    else
        echo "❌ Cell B port forward failed"  
        cleanup_port_forwards
        exit 1
    fi
    
    echo "📝 Port forward PIDs: Cell A=$CELL_A_PID, Cell B=$CELL_B_PID"
    echo "💡 To stop port forwards: kill $CELL_A_PID $CELL_B_PID"
}

# Function to test connectivity
test_connectivity() {
    echo "Testing connectivity..."
    
    # Test Cell A
    if curl -s -f -m 5 http://localhost:8010/health > /dev/null; then
        echo "✅ Cell A health check successful"
    else
        echo "⚠️  Cell A health check failed (service may be starting)"
    fi
    
    # Test Cell B
    if curl -s -f -m 5 http://localhost:8020/health > /dev/null; then
        echo "✅ Cell B health check successful"
    else
        echo "⚠️  Cell B health check failed (service may be starting)"
    fi
}

# Main execution
main() {
    # Parse command line arguments
    case "${1:-setup}" in
        "setup")
            cleanup_port_forwards
            check_services
            setup_port_forwards
            test_connectivity
            echo ""
            echo "=== Port Forwards Ready ==="
            echo "Cell A: http://localhost:8010"
            echo "Cell B: http://localhost:8020"
            echo ""
            echo "To run load test with port forwards:"
            echo "CELL_A_URL=http://localhost:8010 CELL_B_URL=http://localhost:8020 k6 run k6-load-test-direct.js"
            echo ""
            echo "To stop port forwards:"
            echo "./setup-port-forwards.sh cleanup"
            ;;
        "cleanup")
            cleanup_port_forwards
            echo "✅ Port forwards cleaned up"
            ;;
        "test")
            test_connectivity
            ;;
        *)
            echo "Usage: $0 [setup|cleanup|test]"
            echo "  setup   - Setup port forwards (default)"
            echo "  cleanup - Stop all port forwards"
            echo "  test    - Test connectivity"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 