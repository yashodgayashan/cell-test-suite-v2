#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== KEDA HTTP Scaling Deployment for Cell-Based Architecture ===${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command_exists kubectl; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command_exists helm; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}Prerequisites check passed!${NC}"

# Function to install KEDA
install_keda() {
    echo -e "${YELLOW}Installing KEDA...${NC}"
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    
    if helm list -n keda | grep -q "keda"; then
        echo -e "${YELLOW}KEDA already installed, upgrading...${NC}"
        helm upgrade keda kedacore/keda --namespace keda
    else
        helm install keda kedacore/keda --namespace keda --create-namespace
    fi
    
    echo -e "${GREEN}KEDA installed successfully!${NC}"
}

# Function to install KEDA HTTP Add-on
install_keda_http() {
    echo -e "${YELLOW}Installing KEDA HTTP Add-on...${NC}"
    
    if helm list -n keda | grep -q "keda-http-add-on"; then
        echo -e "${YELLOW}KEDA HTTP Add-on already installed, upgrading...${NC}"
        helm upgrade keda-http-add-on kedacore/keda-add-ons-http --namespace keda
    else
        helm install keda-http-add-on kedacore/keda-add-ons-http --namespace keda --create-namespace
    fi
    
    echo -e "${GREEN}KEDA HTTP Add-on installed successfully!${NC}"
}

# Function to deploy cell architecture
deploy_cells() {
    echo -e "${YELLOW}Deploying Cell-Based Architecture with KEDA HTTP Scaling...${NC}"
    
    # Create namespaces
    echo -e "${BLUE}Creating namespaces...${NC}"
    kubectl apply -f namespaces.yaml
    
    # Create service accounts
    echo -e "${BLUE}Creating service accounts...${NC}"
    kubectl apply -f serviceaccounts.yaml
    
    # Deploy Cell A
    echo -e "${BLUE}Deploying Cell A...${NC}"
    kubectl apply -f cells/cell-a/
    
    # Deploy Cell B  
    echo -e "${BLUE}Deploying Cell B...${NC}"
    kubectl apply -f cells/cell-b/
    
    # Deploy ingress
    echo -e "${BLUE}Deploying ingress configuration...${NC}"
    kubectl apply -f ingress.yaml
    
    echo -e "${GREEN}Cell architecture deployed successfully!${NC}"
}

# Function to wait for deployments
wait_for_keda() {
    echo -e "${YELLOW}Waiting for KEDA components to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=keda-operator -n keda --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=operator,app.kubernetes.io/part-of=keda-add-ons-http -n keda --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=interceptor,app.kubernetes.io/part-of=keda-add-ons-http -n keda --timeout=300s
    echo -e "${GREEN}KEDA components are ready!${NC}"
}

# Function to show status
show_status() {
    echo -e "${BLUE}=== Deployment Status ===${NC}"
    
    echo -e "${YELLOW}KEDA Pods:${NC}"
    kubectl get pods -n keda
    
    echo -e "\n${YELLOW}HTTPScaledObjects:${NC}"
    kubectl get httpscaledobjects -A
    
    echo -e "\n${YELLOW}Cell A Pods:${NC}"
    kubectl get pods -n cell-a
    
    echo -e "\n${YELLOW}Cell B Pods:${NC}"
    kubectl get pods -n cell-b
    
    echo -e "\n${YELLOW}Services:${NC}"
    kubectl get svc -n keda | grep interceptor
}

# Function to provide testing instructions
show_testing_info() {
    echo -e "\n${BLUE}=== Testing Instructions ===${NC}"
    echo -e "${YELLOW}1. Port forward KEDA HTTP interceptor:${NC}"
    echo "   kubectl port-forward -n keda svc/keda-add-ons-http-interceptor-proxy 8080:8080"
    
    echo -e "\n${YELLOW}2. Test Cell A Gateway:${NC}"
    echo "   curl -H \"Host: cell-a-gateway.local\" http://localhost:8080/health"
    echo "   curl -H \"Host: cell-a-gateway.local\" http://localhost:8080/users"
    
    echo -e "\n${YELLOW}3. Test Cell B Gateway:${NC}"
    echo "   curl -H \"Host: cell-b-gateway.local\" http://localhost:8080/health"
    echo "   curl -H \"Host: cell-b-gateway.local\" http://localhost:8080/orders"
    
    echo -e "\n${YELLOW}4. Watch scaling in action:${NC}"
    echo "   kubectl get pods -n cell-a -w"
    echo "   kubectl get pods -n cell-b -w"
    
    echo -e "\n${YELLOW}5. Monitor HTTPScaledObjects:${NC}"
    echo "   kubectl get httpscaledobjects -A"
    echo "   kubectl describe httpscaledobject cell-a-gateway -n cell-a"
}

# Main execution
case "${1:-}" in
    "install-keda")
        install_keda
        ;;
    "install-http")
        install_keda_http
        ;;
    "deploy")
        deploy_cells
        ;;
    "status")
        show_status
        ;;
    "test-info")
        show_testing_info
        ;;
    "all"|"")
        install_keda
        install_keda_http
        wait_for_keda
        deploy_cells
        show_status
        show_testing_info
        ;;
    *)
        echo "Usage: $0 [install-keda|install-http|deploy|status|test-info|all]"
        echo ""
        echo "Commands:"
        echo "  install-keda    Install KEDA core"
        echo "  install-http    Install KEDA HTTP Add-on"
        echo "  deploy          Deploy cell architecture"
        echo "  status          Show deployment status"
        echo "  test-info       Show testing instructions"
        echo "  all             Run complete installation (default)"
        exit 1
        ;;
esac

echo -e "\n${GREEN}=== Script completed successfully! ===${NC}" 