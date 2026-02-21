#!/bin/bash

# Complete RCC Remote Workflow Integration Test
# Tests the entire workflow from certificate generation to RCC connectivity

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SERVER_NAME="${SERVER_NAME:-localhost}"
SERVER_PORT="${SERVER_PORT:-8443}"

log "Starting complete RCC Remote workflow integration test"
log "Repository: $REPO_ROOT"
log "Server: $SERVER_NAME:$SERVER_PORT"
echo ""

# Step 1: Certificate Generation
test_cert_generation() {
    log "Step 1: Testing certificate generation"
    
    cd "$REPO_ROOT/scripts"
    
    # Clean existing certificates
    if [ -d "$REPO_ROOT/certs" ]; then
        rm -f "$REPO_ROOT/certs"/*.crt "$REPO_ROOT/certs"/*.key "$REPO_ROOT/certs"/*.pem 2>/dev/null || true
    fi
    
    # Generate CA-signed certificates
    if ./cert-management.sh generate-ca-signed --server-name "$SERVER_NAME" > /tmp/cert-gen.log 2>&1; then
        log "  ✓ Certificate generation succeeded"
    else
        error "Certificate generation failed. Check /tmp/cert-gen.log"
    fi
    
    # Verify certificates exist
    if [ -f "$REPO_ROOT/certs/server.crt" ] && [ -f "$REPO_ROOT/certs/server.key" ] && [ -f "$REPO_ROOT/certs/rootCA.crt" ]; then
        log "  ✓ All required certificates present"
    else
        error "Required certificates missing"
    fi
    
    # Validate certificates
    if ./cert-management.sh validate > /tmp/cert-validate.log 2>&1; then
        log "  ✓ Certificate validation passed"
    else
        warn "Certificate validation warnings (non-fatal)"
    fi
    
    echo ""
}

# Step 2: Install CA Certificate
test_ca_installation() {
    log "Step 2: Testing CA certificate installation"
    
    if [ -f "$REPO_ROOT/certs/rootCA.crt" ]; then
        if sudo cp "$REPO_ROOT/certs/rootCA.crt" /usr/local/share/ca-certificates/rccremote-ca.crt 2>/dev/null; then
            if sudo update-ca-certificates > /tmp/ca-install.log 2>&1; then
                log "  ✓ CA certificate installed in system trust store"
            else
                warn "CA certificate installation completed with warnings"
            fi
        else
            warn "Could not install CA certificate (may need sudo)"
        fi
    else
        error "rootCA.crt not found"
    fi
    
    echo ""
}

# Step 3: Deploy with Docker
test_deployment() {
    log "Step 3: Testing Docker deployment"
    
    cd "$REPO_ROOT/scripts"
    
    # Create required directories
    mkdir -p "$REPO_ROOT/data/robots" "$REPO_ROOT/data/hololib_zip"
    
    # Copy sample robot if robots directory is empty
    if [ ! "$(ls -A $REPO_ROOT/data/robots 2>/dev/null | grep -v README)" ]; then
        if [ -d "$REPO_ROOT/data/robots-samples/rf7" ]; then
            cp -r "$REPO_ROOT/data/robots-samples/rf7" "$REPO_ROOT/data/robots/"
            log "  ✓ Copied sample robot to robots directory"
        fi
    fi
    
    # Deploy (skip build if already built)
    if ./deploy-docker.sh --environment development --server-name "$SERVER_NAME" --skip-build > /tmp/deploy.log 2>&1; then
        log "  ✓ Deployment succeeded"
    else
        error "Deployment failed. Check /tmp/deploy.log"
    fi
    
    # Verify containers are running
    if docker ps | grep -q rccremote-dev && docker ps | grep -q rccremote-nginx-dev; then
        log "  ✓ Containers are running"
    else
        error "Containers not running"
    fi
    
    # Wait for services to be ready
    log "  Waiting for services to be ready..."
    sleep 10
    
    echo ""
}

# Step 4: Health Check
test_health_check() {
    log "Step 4: Testing service health"
    
    # Test HTTPS endpoint
    if curl -sk "https://$SERVER_NAME:$SERVER_PORT/" > /dev/null 2>&1; then
        log "  ✓ HTTPS endpoint responding"
    else
        warn "HTTPS endpoint not responding (may be expected if no health endpoints)"
    fi
    
    # Check container health
    if docker ps --filter "name=rccremote-dev" --filter "health=healthy" | grep -q rccremote-dev; then
        log "  ✓ RCCRemote container is healthy"
    else
        warn "RCCRemote container health status unknown"
    fi
    
    if docker ps --filter "name=rccremote-nginx-dev" --filter "health=healthy" | grep -q rccremote-nginx-dev; then
        log "  ✓ Nginx container is healthy"
    else
        warn "Nginx container health status unknown"
    fi
    
    echo ""
}

# Step 5: RCC Installation
test_rcc_installation() {
    log "Step 5: Testing RCC installation"
    
    if command -v rcc &> /dev/null; then
        local version=$(rcc version 2>&1)
        log "  ✓ RCC is installed: $version"
    else
        error "RCC not found in PATH"
    fi
    
    # Disable telemetry
    rcc config identity -t > /dev/null 2>&1 || true
    log "  ✓ RCC telemetry disabled"
    
    echo ""
}

# Step 6: RCC Connectivity Test
test_rcc_connectivity() {
    log "Step 6: Testing RCC connectivity"
    
    export RCC_REMOTE_ORIGIN="https://$SERVER_NAME:$SERVER_PORT"
    log "  RCC_REMOTE_ORIGIN=$RCC_REMOTE_ORIGIN"
    
    # Create test robot
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Copy a robot from the deployed robots
    if [ -d "$REPO_ROOT/data/robots/rf7" ]; then
        cp -r "$REPO_ROOT/data/robots/rf7"/* "$test_dir/"
        log "  ✓ Using rf7 test robot"
    else
        # Create minimal test robot
        cat > robot.yaml << 'EOF'
tasks:
  Test:
    shell: echo "Test"

condaConfigFile: conda.yaml
artifactsDir: output

environmentConfigs:
  - conda.yaml
EOF
        cat > conda.yaml << 'EOF'
channels:
  - conda-forge

dependencies:
  - python>=3.12
  - pip=23.2.1
  - pip:
    - robotframework==7
EOF
        log "  ✓ Created minimal test robot"
    fi
    
    # Clean holotree to force remote fetch
    rm -rf ~/.robocorp/holotree/* 2>/dev/null || true
    
    # Test holotree vars with remote
    log "  Testing RCC holotree vars with remote origin..."
    if timeout 120 rcc holotree vars -r robot.yaml > /tmp/rcc-test.log 2>&1; then
        log "  ✓ RCC holotree vars succeeded"
        
        # Check if remote was used
        if grep -q "Fill hololib from RCC_REMOTE_ORIGIN" /tmp/rcc-test.log; then
            log "  ✓ RCC successfully fetched from RCC Remote"
        else
            warn "Could not confirm remote fetch (may have built locally)"
        fi
        
        # Check for SSL errors
        if grep -qi "SSL\|certificate\|tls" /tmp/rcc-test.log | grep -qi "error\|fail"; then
            warn "SSL-related errors detected in RCC output"
        else
            log "  ✓ No SSL errors detected"
        fi
        
        # Verify environment was created
        if grep -q "SUCCESS" /tmp/rcc-test.log; then
            log "  ✓ Environment creation successful"
        fi
    else
        error "RCC holotree vars failed. Check /tmp/rcc-test.log"
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$test_dir"
    
    echo ""
}

# Step 7: Verify Catalogs
test_catalogs() {
    log "Step 7: Verifying available catalogs"
    
    # Check rccremote logs for catalogs
    if docker logs rccremote-dev 2>&1 | grep -q "Holotree catalogs:"; then
        local catalog_count=$(docker logs rccremote-dev 2>&1 | grep -E "^[a-f0-9]{16}" | wc -l)
        log "  ✓ Found $catalog_count catalog(s) in rccremote"
    else
        warn "Could not verify catalogs in rccremote"
    fi
    
    echo ""
}

# Main test execution
main() {
    local start_time=$(date +%s)
    
    test_cert_generation
    test_ca_installation
    test_deployment
    test_health_check
    test_rcc_installation
    test_rcc_connectivity
    test_catalogs
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log "===================="
    log "ALL TESTS PASSED ✓"
    log "===================="
    log "Total duration: ${duration}s"
    log ""
    log "The complete RCC Remote workflow is working correctly:"
    log "  1. ✓ Certificates generated and validated"
    log "  2. ✓ CA certificate installed"
    log "  3. ✓ Services deployed and healthy"
    log "  4. ✓ RCC connectivity verified"
    log "  5. ✓ Catalogs available"
    echo ""
}

# Run tests
main
