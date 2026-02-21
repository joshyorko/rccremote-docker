#!/bin/bash

# End-to-end deployment validation test
# Validates complete deployment workflow from start to finish

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[VALIDATION]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

DEPLOYMENT_TYPE="${DEPLOYMENT_TYPE:-docker}"  # docker or k8s
VALIDATION_FAILED=0

log "Starting end-to-end deployment validation..."
log "Deployment type: $DEPLOYMENT_TYPE"

# Validate prerequisites
validate_prerequisites() {
    log "Validating prerequisites..."
    
    if [[ "$DEPLOYMENT_TYPE" == "docker" ]]; then
        if ! command -v docker &> /dev/null; then
            error "Docker not found"
        fi
        
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
            error "Docker Compose not found"
        fi
    elif [[ "$DEPLOYMENT_TYPE" == "k8s" ]]; then
        if ! command -v kubectl &> /dev/null; then
            error "kubectl not found"
        fi
        
        if ! kubectl cluster-info &> /dev/null; then
            error "Cannot connect to Kubernetes cluster"
        fi
    fi
    
    log "  ✓ Prerequisites validated"
}

# Validate infrastructure files
validate_infrastructure() {
    log "Validating infrastructure files..."
    
    local repo_root="/home/runner/work/rccremote-docker/rccremote-docker"
    
    # Check Kubernetes manifests
    if [[ ! -f "$repo_root/k8s/namespace.yaml" ]]; then
        error "Missing k8s/namespace.yaml"
    fi
    
    if [[ ! -f "$repo_root/k8s/deployment.yaml" ]]; then
        error "Missing k8s/deployment.yaml"
    fi
    
    if [[ ! -f "$repo_root/k8s/service.yaml" ]]; then
        error "Missing k8s/service.yaml"
    fi
    
    # Check Docker Compose files
    if [[ ! -f "$repo_root/docker-compose/docker-compose.development.yml" ]]; then
        error "Missing docker-compose.development.yml"
    fi
    
    if [[ ! -f "$repo_root/docker-compose/docker-compose.production.yml" ]]; then
        error "Missing docker-compose.production.yml"
    fi
    
    # Check deployment scripts
    if [[ ! -x "$repo_root/scripts/deploy-docker.sh" ]]; then
        error "Missing or not executable: scripts/deploy-docker.sh"
    fi
    
    if [[ ! -x "$repo_root/scripts/deploy-k8s.sh" ]]; then
        error "Missing or not executable: scripts/deploy-k8s.sh"
    fi
    
    log "  ✓ Infrastructure files validated"
}

# Validate documentation
validate_documentation() {
    log "Validating documentation..."
    
    local repo_root="/home/runner/work/rccremote-docker/rccremote-docker"
    local docs=(
        "docs/deployment-guide.md"
        "docs/kubernetes-setup.md"
        "docs/arc-integration.md"
        "docs/troubleshooting.md"
    )
    
    for doc in "${docs[@]}"; do
        if [[ ! -f "$repo_root/$doc" ]]; then
            error "Missing documentation: $doc"
        fi
        
        # Check that doc is not empty
        if [[ ! -s "$repo_root/$doc" ]]; then
            error "Empty documentation file: $doc"
        fi
    done
    
    log "  ✓ Documentation validated"
}

# Validate deployment scripts
validate_deployment_scripts() {
    log "Validating deployment scripts..."
    
    local repo_root="/home/runner/work/rccremote-docker/rccremote-docker"
    local scripts=(
        "scripts/deploy-docker.sh"
        "scripts/deploy-k8s.sh"
        "scripts/health-check.sh"
        "scripts/test-connectivity.sh"
        "scripts/cert-management.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ ! -x "$repo_root/$script" ]]; then
            error "Script not executable: $script"
        fi
        
        # Check for usage function
        if ! grep -q "usage()" "$repo_root/$script"; then
            warn "Script missing usage() function: $script"
        fi
    done
    
    log "  ✓ Deployment scripts validated"
}

# Validate security configurations
validate_security() {
    log "Validating security configurations..."
    
    local repo_root="/home/runner/work/rccremote-docker/rccremote-docker"
    
    # Check Kubernetes deployment for security contexts
    if ! grep -q "runAsNonRoot: true" "$repo_root/k8s/deployment.yaml"; then
        error "Kubernetes deployment missing runAsNonRoot security context"
    fi
    
    if ! grep -q "runAsUser: 1000" "$repo_root/k8s/deployment.yaml"; then
        error "Kubernetes deployment missing runAsUser specification"
    fi
    
    # Check for capability drops
    if ! grep -q "CAP_DROP" "$repo_root/k8s/deployment.yaml" && ! grep -q "drop:" "$repo_root/k8s/deployment.yaml"; then
        warn "Kubernetes deployment may be missing capability restrictions"
    fi
    
    log "  ✓ Security configurations validated"
}

# Validate test infrastructure
validate_tests() {
    log "Validating test infrastructure..."
    
    local repo_root="/home/runner/work/rccremote-docker/rccremote-docker"
    local tests=(
        "tests/contract/test_health_api.sh"
        "tests/contract/test_deployment_api.sh"
        "tests/integration/test_docker_deployment.sh"
        "tests/integration/test_k8s_deployment.sh"
        "tests/integration/test_rcc_connectivity.sh"
        "tests/load/test_concurrent_clients.sh"
    )
    
    for test in "${tests[@]}"; do
        if [[ ! -x "$repo_root/$test" ]]; then
            error "Test not executable: $test"
        fi
    done
    
    log "  ✓ Test infrastructure validated"
}

# Validate Kubernetes manifests syntax
validate_k8s_manifests() {
    if [[ "$DEPLOYMENT_TYPE" != "k8s" ]]; then
        return 0
    fi
    
    log "Validating Kubernetes manifests syntax..."
    
    local repo_root="/home/runner/work/rccremote-docker/rccremote-docker"
    local manifests=(
        "k8s/namespace.yaml"
        "k8s/configmap.yaml"
        "k8s/secret.yaml"
        "k8s/persistent-volume.yaml"
        "k8s/deployment.yaml"
        "k8s/service.yaml"
        "k8s/ingress.yaml"
    )
    
    for manifest in "${manifests[@]}"; do
        if ! kubectl apply --dry-run=client -f "$repo_root/$manifest" &>/dev/null; then
            error "Invalid Kubernetes manifest: $manifest"
        fi
    done
    
    log "  ✓ Kubernetes manifests syntax validated"
}

# Validate Docker Compose syntax
validate_docker_compose() {
    if [[ "$DEPLOYMENT_TYPE" != "docker" ]]; then
        return 0
    fi
    
    log "Validating Docker Compose syntax..."
    
    local repo_root="/home/runner/work/rccremote-docker/rccremote-docker"
    local compose_files=(
        "docker-compose/docker-compose.development.yml"
        "docker-compose/docker-compose.production.yml"
    )
    
    for compose_file in "${compose_files[@]}"; do
        if docker compose -f "$repo_root/$compose_file" config &>/dev/null || docker-compose -f "$repo_root/$compose_file" config &>/dev/null; then
            log "    ✓ Valid: $compose_file"
        else
            error "Invalid Docker Compose file: $compose_file"
        fi
    done
    
    log "  ✓ Docker Compose syntax validated"
}

# Summary
print_summary() {
    echo ""
    log "====================================="
    log "End-to-End Validation COMPLETED"
    log "====================================="
    log ""
    log "Validated:"
    log "  ✓ Prerequisites"
    log "  ✓ Infrastructure files"
    log "  ✓ Documentation"
    log "  ✓ Deployment scripts"
    log "  ✓ Security configurations"
    log "  ✓ Test infrastructure"
    
    if [[ "$DEPLOYMENT_TYPE" == "k8s" ]]; then
        log "  ✓ Kubernetes manifests"
    else
        log "  ✓ Docker Compose files"
    fi
    
    echo ""
    log "Deployment is ready for: $DEPLOYMENT_TYPE"
    echo ""
}

# Main validation flow
main() {
    validate_prerequisites
    validate_infrastructure
    validate_documentation
    validate_deployment_scripts
    validate_security
    validate_tests
    
    if [[ "$DEPLOYMENT_TYPE" == "k8s" ]]; then
        validate_k8s_manifests
    else
        validate_docker_compose
    fi
    
    print_summary
}

main
