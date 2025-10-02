#!/bin/bash

# Integration test for Kubernetes deployment using k3d
# Tests deployment, scaling, health checks

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

CLUSTER_NAME="rccremote-test-$$"

log "Starting Kubernetes deployment test with k3d..."

# Clean up function
cleanup() {
    log "Cleaning up k3d cluster..."
    k3d cluster delete $CLUSTER_NAME 2>/dev/null || true
}

trap cleanup EXIT

# Check prerequisites
if ! command -v k3d &> /dev/null; then
    error "k3d not found. Please install k3d first."
fi

if ! command -v kubectl &> /dev/null; then
    error "kubectl not found. Please install kubectl first."
fi

# Create k3d cluster
log "Creating k3d cluster..."
k3d cluster create $CLUSTER_NAME --port "8443:443@loadbalancer" --wait

# Wait for cluster to be ready
log "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Deploy RCC Remote
log "Deploying RCC Remote to cluster..."
cd "$(dirname "$0")/../../"

# Apply manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/persistent-volume.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Wait for deployment
log "Waiting for deployment to be ready (max 300s)..."
if ! kubectl wait --for=condition=available deployment/rccremote \
    -n rccremote --timeout=300s; then
    log "Deployment logs:"
    kubectl logs -n rccremote -l app=rccremote --tail=50
    error "Deployment failed to become ready"
fi

# Check pod status
log "Checking pod status..."
kubectl get pods -n rccremote

# Check service
log "Checking service..."
kubectl get svc -n rccremote

# Scale test
log "Testing horizontal scaling..."
kubectl scale deployment rccremote --replicas=2 -n rccremote
kubectl wait --for=condition=available deployment/rccremote \
    -n rccremote --timeout=120s

pod_count=$(kubectl get pods -n rccremote -l app=rccremote --no-headers | wc -l)
if [ "$pod_count" -ne 2 ]; then
    error "Expected 2 pods, found $pod_count"
fi

log "Scaling test passed ✓"

log "Kubernetes deployment test PASSED ✓"
