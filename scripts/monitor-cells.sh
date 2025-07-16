#!/bin/bash

echo "Monitoring Cell-Based Architecture with Separate Namespaces..."

# Function to check service health
check_service() {
    local service_name=$1
    local url=$2
    
    echo "Checking $service_name..."
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" $url/health 2>/dev/null)
    http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')
    
    if [ "$http_code" -eq 200 ]; then
        echo "✅ $service_name is healthy"
        echo "   Response: $(echo $body | jq -c '.' 2>/dev/null || echo $body)"
    else
        echo "❌ $service_name is unhealthy (HTTP $http_code)"
    fi
    echo
}

# Function to check Kubernetes status
check_k8s_status() {
    echo "=== Kubernetes Status ==="
    echo "--- Cell A Namespace ---"
    kubectl get pods -n cell-a 2>/dev/null || echo "Cell A namespace not found"
    echo
    echo "--- Cell B Namespace ---"
    kubectl get pods -n cell-b 2>/dev/null || echo "Cell B namespace not found"
    echo
}

# Monitor loop
while true; do
    echo "=== Cell Architecture Health Check - $(date) ==="
    
    # Check Kubernetes status if available
    if command -v kubectl &> /dev/null; then
        check_k8s_status
    fi
    
    # Check Cell A services
    echo "--- Cell A Services ---"
    check_service "Cell A Gateway" "http://localhost:8010"
    check_service "Cell A User Service" "http://localhost:8011"
    check_service "Cell A Product Service" "http://localhost:8012"
    
    # Check Cell B services
    echo "--- Cell B Services ---"
    check_service "Cell B Gateway" "http://localhost:8020"
    check_service "Cell B Order Service" "http://localhost:8021"
    check_service "Cell B Payment Service" "http://localhost:8022"
    
    echo "=== End Health Check ==="
    echo
    
    sleep 30
done
