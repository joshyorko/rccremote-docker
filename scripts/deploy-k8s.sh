#!/bin/bash

# Deploy RCC Remote to Kubernetes
# Usage: ./deploy-k8s.sh [options]

set -e

# Default values
NAMESPACE="${NAMESPACE:-rccremote}"
ENVIRONMENT="${ENVIRONMENT:-production}"
REPLICAS="${REPLICAS:-3}"
TIMEOUT="${TIMEOUT:-300}"
SKIP_VALIDATION="${SKIP_VALIDATION:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [options]

Options:
    -n, --namespace NAME        Kubernetes namespace (default: rccremote)
    -e, --environment ENV       Environment: dev, staging, production (default: production)
    -r, --replicas NUM          Number of replicas (default: 3)
    -t, --timeout SECONDS       Deployment timeout in seconds (default: 300)
    -s, --skip-validation       Skip pre-deployment validation
    -h, --help                  Display this help message

Examples:
    # Deploy with defaults
    $0

    # Deploy to custom namespace with 5 replicas
    $0 --namespace automation --replicas 5

    # Deploy development environment
    $0 --environment dev --replicas 1
EOF
    exit 0
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--replicas)
            REPLICAS="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -s|--skip-validation)
            SKIP_VALIDATION="true"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

# Validate prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl first."
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    fi
    
    # Check if k8s directory exists
    if [ ! -d "../k8s" ] && [ ! -d "k8s" ]; then
        error "Kubernetes manifests directory not found. Run from project root or scripts directory."
    fi
    
    log "Prerequisites check passed ✓"
}

# Validate manifests
validate_manifests() {
    if [ "$SKIP_VALIDATION" = "true" ]; then
        warn "Skipping manifest validation"
        return 0
    fi
    
    log "Validating Kubernetes manifests..."
    
    local K8S_DIR="../k8s"
    [ -d "k8s" ] && K8S_DIR="k8s"
    
    for manifest in "$K8S_DIR"/*.yaml; do
        if ! kubectl apply --dry-run=client -f "$manifest" &> /dev/null; then
            error "Invalid manifest: $manifest"
        fi
    done
    
    log "Manifest validation passed ✓"
}

# Create or update namespace
setup_namespace() {
    log "Setting up namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        kubectl label namespace "$NAMESPACE" environment="$ENVIRONMENT"
        log "Namespace $NAMESPACE created"
    fi
}

# Deploy manifests
deploy_manifests() {
    log "Deploying RCC Remote to namespace: $NAMESPACE"
    
    local K8S_DIR="../k8s"
    [ -d "k8s" ] && K8S_DIR="k8s"
    
    # Apply in order: namespace, configmap, secrets, PVs, deployment, service, ingress
    local ordered_manifests=(
        "$K8S_DIR/namespace.yaml"
        "$K8S_DIR/configmap.yaml"
        "$K8S_DIR/secret.yaml"
        "$K8S_DIR/persistent-volume.yaml"
        "$K8S_DIR/deployment.yaml"
        "$K8S_DIR/service.yaml"
        "$K8S_DIR/health-check.yaml"
        "$K8S_DIR/ingress.yaml"
    )
    
    for manifest in "${ordered_manifests[@]}"; do
        if [ -f "$manifest" ]; then
            log "Applying $(basename $manifest)..."
            kubectl apply -f "$manifest" -n "$NAMESPACE"
        else
            warn "Manifest not found: $manifest"
        fi
    done
    
    # Scale deployment to desired replicas
    log "Scaling deployment to $REPLICAS replicas..."
    kubectl scale deployment rccremote --replicas="$REPLICAS" -n "$NAMESPACE"
}

# Wait for deployment
wait_for_deployment() {
    log "Waiting for deployment to be ready (timeout: ${TIMEOUT}s)..."
    
    if kubectl wait --for=condition=available \
        --timeout="${TIMEOUT}s" \
        deployment/rccremote \
        -n "$NAMESPACE" 2>&1; then
        log "Deployment is ready ✓"
    else
        error "Deployment failed to become ready within ${TIMEOUT} seconds"
    fi
}

# Verify health
verify_health() {
    log "Verifying service health..."
    
    # Get one pod to test
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app=rccremote -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$pod" ]; then
        error "No pods found"
    fi
    
    # Test health endpoints
    log "Testing health endpoints on pod: $pod"
    
    for endpoint in /health/live /health/ready /health/startup; do
        if kubectl exec -n "$NAMESPACE" "$pod" -c rccremote -- \
            curl -sf "http://localhost:4653${endpoint}" > /dev/null; then
            log "  $endpoint: OK ✓"
        else
            warn "  $endpoint: FAILED"
        fi
    done
}

# Display deployment info
show_deployment_info() {
    log "Deployment completed successfully!"
    echo ""
    echo "=== Deployment Information ==="
    echo "Namespace: $NAMESPACE"
    echo "Environment: $ENVIRONMENT"
    echo "Replicas: $REPLICAS"
    echo ""
    echo "=== Pods ==="
    kubectl get pods -n "$NAMESPACE" -l app=rccremote
    echo ""
    echo "=== Services ==="
    kubectl get svc -n "$NAMESPACE"
    echo ""
    echo "=== Access Information ==="
    echo "Service DNS: rccremote.$NAMESPACE.svc.cluster.local"
    echo ""
    echo "To test locally:"
    echo "  kubectl port-forward -n $NAMESPACE svc/rccremote 8443:443"
    echo "  curl -k https://localhost:8443/health/live"
    echo ""
    echo "To view logs:"
    echo "  kubectl logs -n $NAMESPACE -l app=rccremote -c rccremote --tail=50"
    echo ""
}

# Main deployment flow
main() {
    log "Starting RCC Remote Kubernetes deployment"
    log "Environment: $ENVIRONMENT | Namespace: $NAMESPACE | Replicas: $REPLICAS"
    
    check_prerequisites
    validate_manifests
    setup_namespace
    deploy_manifests
    wait_for_deployment
    verify_health
    show_deployment_info
    
    log "Deployment completed in $(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds"
}

# Run main function
main
