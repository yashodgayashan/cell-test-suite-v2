#!/bin/bash

echo "Testing Network Policies and Cell Isolation..."

# Function to test direct service access (should fail)
test_direct_access() {
    local service_name=$1
    local namespace=$2
    local port=$3
    
    echo "Testing direct access to $service_name in $namespace namespace..."
    
    # Try to access service directly from outside the cluster
    # This should fail due to network policies
    timeout 10 kubectl run test-pod --image=curlimages/curl:latest --rm -i --restart=Never -- \
        curl -s http://$service_name.$namespace.svc.cluster.local:$port/health || echo "✅ Direct access blocked (expected)"
}

# Function to test gateway access (should work)
test_gateway_access() {
    local gateway_name=$1
    local namespace=$2
    
    echo "Testing gateway access to $gateway_name in $namespace namespace..."
    
    # Determine port based on namespace
    local port
    if [[ "$namespace" == "cell-a" ]]; then
        port=8010
    elif [[ "$namespace" == "cell-b" ]]; then
        port=8020
    else
        echo "❌ Unknown namespace: $namespace"
        return 1
    fi
    
    # Port forward to access gateway
    kubectl port-forward svc/$gateway_name $port:$port -n $namespace &
    PF_PID=$!
    
    sleep 5
    
    # Test gateway access
    response=$(curl -s http://localhost:$port/health)
    if [[ $response == *"healthy"* ]]; then
        echo "✅ Gateway access successful"
    else
        echo "❌ Gateway access failed"
    fi
    
    kill $PF_PID 2>/dev/null || true
}

# Function to test cross-cell communication through gateways
test_cross_cell_communication() {
    echo "Testing cross-cell communication through gateways..."
    
    # Create a test pod in cell-a to test communication
    kubectl run test-pod-a --image=curlimages/curl:latest -n cell-a --rm -i --restart=Never -- \
        curl -s http://cell-b-gateway.cell-b.svc.cluster.local:8020/health || echo "Cross-cell communication test completed"
}

# Function to test network policy effectiveness
test_network_policy_effectiveness() {
    echo "=== Testing Network Policy Effectiveness ==="
    
    # Test that gateways can be accessed
    echo "--- Testing Gateway Access (should work) ---"
    test_gateway_access "cell-a-gateway" "cell-a"
    test_gateway_access "cell-b-gateway" "cell-b"
    
    # Test cross-cell communication
    echo "--- Testing Cross-Cell Communication ---"
    test_cross_cell_communication


    # Test that services cannot be accessed directly
    echo "--- Testing Direct Service Access (should be blocked) ---"
    test_direct_access "cell-a-user-service" "cell-a" "8011"
    test_direct_access "cell-a-product-service" "cell-a" "8012"
    test_direct_access "cell-b-order-service" "cell-b" "8021"
    test_direct_access "cell-b-payment-service" "cell-b" "8022"
}

# Function to validate network policies are applied
validate_network_policies() {
    echo "=== Validating Network Policies ==="
    
    echo "Network policies in cell-a:"
    kubectl get networkpolicies -n cell-a -o wide
    
    echo "Network policies in cell-b:"
    kubectl get networkpolicies -n cell-b -o wide
    
    echo "Describing network policies..."
    kubectl describe networkpolicies -n cell-a
    kubectl describe networkpolicies -n cell-b
}

# Function to test service-to-service communication within cell
test_intra_cell_communication() {
    echo "=== Testing Intra-Cell Communication ==="
    
    # Test that gateway can reach services within the same cell
    kubectl run gateway-test-a --image=curlimages/curl:latest -n cell-a --rm -i --restart=Never -- \
        curl -s http://cell-a-user-service.cell-a.svc.cluster.local:8011/health || echo "Intra-cell communication test completed"
        
    kubectl run gateway-test-b --image=curlimages/curl:latest -n cell-b --rm -i --restart=Never -- \
        curl -s http://cell-b-order-service.cell-b.svc.cluster.local:8021/health || echo "Intra-cell communication test completed"
}

# Run all tests
echo "Starting comprehensive network policy tests..."
echo "=============================================="

validate_network_policies
test_network_policy_effectiveness
test_intra_cell_communication

echo "=============================================="
echo "Network policy testing completed!"