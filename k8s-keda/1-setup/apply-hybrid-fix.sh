#!/bin/bash

set -e

echo "=== Applying Hybrid Scaling Fix ==="
echo "This will:"
echo "- Keep gateways with KEDA HTTP scaling (scale to zero)"
echo "- Keep internal services always running (min 1 replica)"
echo "- Restore direct service-to-service communication"

echo ""
read -p "Apply hybrid fix? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Cancelled."
    exit 0
fi

echo "Applying hybrid configuration..."

# Update ConfigMaps for hybrid approach
kubectl patch configmap cell-a-gateway-config -n cell-a --patch='
data:
  USER_SERVICE_URL: "http://cell-a-user-service.cell-a.svc.cluster.local:8011"
  PRODUCT_SERVICE_URL: "http://cell-a-product-service.cell-a.svc.cluster.local:8012"
'

kubectl patch configmap cell-b-gateway-config -n cell-b --patch='
data:
  ORDER_SERVICE_URL: "http://cell-b-order-service.cell-b.svc.cluster.local:8021"  
  PAYMENT_SERVICE_URL: "http://cell-b-payment-service.cell-b.svc.cluster.local:8022"
'

kubectl patch configmap cell-b-order-service-config -n cell-b --patch='
data:
  PAYMENT_SERVICE_URL: "http://cell-b-payment-service.cell-b.svc.cluster.local:8022"
'

# Update HTTPScaledObjects to have min 1 replica for internal services
kubectl patch httpscaledobject cell-a-user-service -n cell-a --type='merge' --patch='
spec:
  replicas:
    min: 1
    max: 3
'

kubectl patch httpscaledobject cell-a-product-service -n cell-a --type='merge' --patch='
spec:
  replicas:
    min: 1
    max: 3
'

kubectl patch httpscaledobject cell-b-order-service -n cell-b --type='merge' --patch='
spec:
  replicas:
    min: 1
    max: 3
'

kubectl patch httpscaledobject cell-b-payment-service -n cell-b --type='merge' --patch='
spec:
  replicas:
    min: 1
    max: 3
'

# Restart deployments to pick up new config
kubectl rollout restart deployment/cell-a-gateway -n cell-a
kubectl rollout restart deployment/cell-b-gateway -n cell-b

echo ""
echo "✅ Hybrid scaling fix applied!"
echo ""
echo "Configuration:"
echo "- Gateways: KEDA HTTP scaling (scale to zero when no external traffic)"
echo "- Internal services: Always running (min 1 replica) with KEDA scaling up"
echo "- Direct service-to-service communication restored"
echo ""
echo "Wait for deployments to restart, then test with:"
echo "./test-scaling.sh basic" 