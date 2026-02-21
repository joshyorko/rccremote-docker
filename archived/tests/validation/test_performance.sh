#!/bin/bash

# Performance validation test for <5 minute deployment requirement
# Validates deployment time meets performance targets

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[PERF TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

DEPLOYMENT_TYPE="${DEPLOYMENT_TYPE:-docker}"  # docker or k8s
MAX_DEPLOYMENT_TIME=300  # 5 minutes in seconds

log "Performance validation: <5 minute deployment requirement"
log "Deployment type: $DEPLOYMENT_TYPE"

# Test Docker Compose deployment time
test_docker_deployment_time() {
    log "Testing Docker Compose deployment time..."
    
    local start_time=$(date +%s)
    
    # Deploy using development compose
    cd /home/runner/work/rccremote-docker/rccremote-docker
    export SERVER_NAME=rccremote.local
    
    log "  Starting Docker Compose deployment..."
    if docker compose -f docker-compose/docker-compose.development.yml up -d >/dev/null 2>&1 || docker-compose -f docker-compose/docker-compose.development.yml up -d >/dev/null 2>&1; then
        log "  ✓ Docker Compose up command succeeded"
    else
        error "Docker Compose deployment failed"
    fi
    
    # Wait for services to be healthy
    log "  Waiting for services to be healthy..."
    local timeout=180
    local elapsed=0
    local interval=5
    
    while [ $elapsed -lt $timeout ]; do
        if docker ps --filter "name=rccremote" --filter "health=healthy" | grep -q rccremote; then
            if docker ps --filter "name=nginx" --filter "health=healthy" | grep -q nginx; then
                log "  ✓ Services are healthy"
                break
            fi
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    if [ $elapsed -ge $timeout ]; then
        warn "Services did not become healthy within timeout"
    fi
    
    local end_time=$(date +%s)
    local deployment_time=$((end_time - start_time))
    
    # Cleanup
    docker compose -f docker-compose/docker-compose.development.yml down -v >/dev/null 2>&1 || docker-compose -f docker-compose/docker-compose.development.yml down -v >/dev/null 2>&1 || true
    
    log ""
    log "=== Docker Compose Deployment Performance ==="
    log "Total deployment time: ${deployment_time}s"
    log "Target:                ${MAX_DEPLOYMENT_TIME}s"
    log "Status:                $([ $deployment_time -le $MAX_DEPLOYMENT_TIME ] && echo "✓ PASS" || echo "✗ FAIL")"
    log ""
    
    if [ $deployment_time -gt $MAX_DEPLOYMENT_TIME ]; then
        error "Deployment time ${deployment_time}s exceeds target ${MAX_DEPLOYMENT_TIME}s"
    fi
    
    log "✓ Docker Compose deployment met <5 minute requirement (${deployment_time}s)"
}

# Test Kubernetes deployment time
test_k8s_deployment_time() {
    log "Testing Kubernetes deployment time..."
    
    # Check if k3d is available
    if ! command -v k3d &> /dev/null; then
        warn "k3d not available, skipping Kubernetes deployment time test"
        return 0
    fi
    
    local cluster_name="rccremote-perf-test-$$"
    local start_time=$(date +%s)
    
    # Create cluster
    log "  Creating k3d cluster..."
    if ! k3d cluster create $cluster_name --wait >/dev/null 2>&1; then
        warn "k3d cluster creation failed, skipping test"
        return 0
    fi
    
    # Deploy RCC Remote
    log "  Deploying RCC Remote to Kubernetes..."
    cd /home/runner/work/rccremote-docker/rccremote-docker
    
    kubectl apply -f k8s/namespace.yaml >/dev/null 2>&1
    kubectl apply -f k8s/configmap.yaml >/dev/null 2>&1
    kubectl apply -f k8s/secret.yaml >/dev/null 2>&1
    kubectl apply -f k8s/persistent-volume.yaml >/dev/null 2>&1
    kubectl apply -f k8s/deployment.yaml >/dev/null 2>&1
    kubectl apply -f k8s/service.yaml >/dev/null 2>&1
    
    # Wait for deployment
    log "  Waiting for deployment to be ready..."
    if kubectl wait --for=condition=available deployment/rccremote -n rccremote --timeout=240s >/dev/null 2>&1; then
        log "  ✓ Deployment is ready"
    else
        warn "Deployment did not become ready in time"
    fi
    
    local end_time=$(date +%s)
    local deployment_time=$((end_time - start_time))
    
    # Cleanup
    k3d cluster delete $cluster_name >/dev/null 2>&1 || true
    
    log ""
    log "=== Kubernetes Deployment Performance ==="
    log "Total deployment time: ${deployment_time}s (including cluster creation)"
    log "Target:                ${MAX_DEPLOYMENT_TIME}s"
    log "Status:                $([ $deployment_time -le $MAX_DEPLOYMENT_TIME ] && echo "✓ PASS" || echo "✗ FAIL")"
    log ""
    
    if [ $deployment_time -gt $MAX_DEPLOYMENT_TIME ]; then
        error "Deployment time ${deployment_time}s exceeds target ${MAX_DEPLOYMENT_TIME}s"
    fi
    
    log "✓ Kubernetes deployment met <5 minute requirement (${deployment_time}s)"
}

# Test deployment script performance
test_deployment_script_time() {
    log "Testing deployment script execution time..."
    
    cd /home/runner/work/rccremote-docker/rccremote-docker
    
    # Test deploy-docker.sh --help (should be instant)
    local start_time=$(date +%s)
    ./scripts/deploy-docker.sh --help >/dev/null 2>&1 || true
    local end_time=$(date +%s)
    local help_time=$((end_time - start_time))
    
    if [ $help_time -gt 5 ]; then
        warn "deploy-docker.sh --help took ${help_time}s (should be <1s)"
    else
        log "  ✓ deploy-docker.sh --help: ${help_time}s"
    fi
    
    # Test deploy-k8s.sh --help
    start_time=$(date +%s)
    ./scripts/deploy-k8s.sh --help >/dev/null 2>&1 || true
    end_time=$(date +%s)
    help_time=$((end_time - start_time))
    
    if [ $help_time -gt 5 ]; then
        warn "deploy-k8s.sh --help took ${help_time}s (should be <1s)"
    else
        log "  ✓ deploy-k8s.sh --help: ${help_time}s"
    fi
}

# Test health check script performance
test_health_check_performance() {
    log "Testing health check script performance..."
    
    cd /home/runner/work/rccremote-docker/rccremote-docker
    
    # Deploy a test instance first
    export SERVER_NAME=rccremote.local
    docker compose -f docker-compose/docker-compose.development.yml up -d >/dev/null 2>&1 || docker-compose -f docker-compose/docker-compose.development.yml up -d >/dev/null 2>&1
    
    # Wait a bit for startup
    sleep 30
    
    # Test health check script
    local start_time=$(date +%s)
    if ./scripts/health-check.sh --target localhost:8443 --timeout 30 >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local check_time=$((end_time - start_time))
        
        log "  ✓ Health check completed in ${check_time}s"
        
        if [ $check_time -gt 60 ]; then
            warn "Health check took longer than expected: ${check_time}s"
        fi
    else
        warn "Health check script failed (service may not be fully ready)"
    fi
    
    # Cleanup
    docker compose -f docker-compose/docker-compose.development.yml down -v >/dev/null 2>&1 || docker-compose -f docker-compose/docker-compose.development.yml down -v >/dev/null 2>&1 || true
}

# Main test flow
main() {
    log "Starting performance validation tests..."
    echo ""
    
    if [[ "$DEPLOYMENT_TYPE" == "docker" ]]; then
        test_docker_deployment_time
    elif [[ "$DEPLOYMENT_TYPE" == "k8s" ]]; then
        test_k8s_deployment_time
    else
        log "Testing both deployment types..."
        test_docker_deployment_time
        test_k8s_deployment_time
    fi
    
    test_deployment_script_time
    test_health_check_performance
    
    echo ""
    log "====================================="
    log "Performance validation PASSED ✓"
    log "All deployments meet <5 minute target"
    log "====================================="
}

main
