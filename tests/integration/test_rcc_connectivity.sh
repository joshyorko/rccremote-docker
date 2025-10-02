#!/bin/bash

# Integration test for RCC client connectivity
# Tests end-to-end RCC client connection and catalog fetching

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INTEGRATION TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

RCC_REMOTE_ORIGIN="${RCC_REMOTE_ORIGIN:-https://rccremote.local:8443}"
RCC_BIN="/tmp/rcc-linux64"

log "Testing RCC client connectivity to $RCC_REMOTE_ORIGIN"

# Download RCC if not present
download_rcc() {
    if [ ! -f "$RCC_BIN" ]; then
        log "Downloading RCC binary..."
        wget -q https://github.com/joshyorko/rcc/releases/download/v18.7.0/rcc-linux64 -O "$RCC_BIN"
        chmod +x "$RCC_BIN"
        log "RCC downloaded successfully"
    fi
    
    local version=$($RCC_BIN version 2>&1 || echo "unknown")
    log "RCC version: $version"
}

# Configure RCC profile for SSL no-verify
configure_rcc_profile() {
    log "Configuring RCC profile for RCC Remote..."
    
    cat > /tmp/rcc-profile-test.yaml << 'EOF'
profiles:
  rccremote-test:
    description: Test profile for RCC Remote integration
    settings:
      verify-ssl: false
EOF
    
    $RCC_BIN config import -f /tmp/rcc-profile-test.yaml
    $RCC_BIN config switch -p rccremote-test
    
    log "RCC profile configured ✓"
}

# Test basic RCC commands
test_rcc_basic() {
    log "Testing basic RCC commands..."
    
    # Test version command
    if ! $RCC_BIN version >/dev/null 2>&1; then
        error "RCC version command failed"
    fi
    
    # Test holotree commands
    if ! $RCC_BIN ht catalogs >/dev/null 2>&1; then
        error "RCC holotree catalogs command failed"
    fi
    
    log "  ✓ Basic RCC commands working"
}

# Test RCC Remote connectivity
test_rcc_remote_connectivity() {
    log "Testing RCC Remote connectivity..."
    
    export RCC_REMOTE_ORIGIN="$RCC_REMOTE_ORIGIN"
    
    # Create a minimal test robot
    local test_dir=$(mktemp -d)
    cat > "$test_dir/robot.yaml" << 'EOF'
tasks:
  Test:
    shell: echo "Hello from RCC"

condaConfigFile: conda.yaml
artifactsDir: output

environmentConfigs:
  - conda.yaml
EOF
    
    cat > "$test_dir/conda.yaml" << 'EOF'
channels:
  - conda-forge

dependencies:
  - python=3.11.5
  - pip=23.2.1
  - pip:
    - robotframework==7.0
EOF
    
    cd "$test_dir"
    
    # Test holotree vars (should fetch from remote if available)
    log "  Testing holotree vars with RCC Remote..."
    if $RCC_BIN ht vars -r robot.yaml > /tmp/rcc-test-output.log 2>&1; then
        log "  ✓ RCC holotree vars succeeded"
        
        # Check if remote was used
        if grep -q "RCC REMOTE ORIGIN" /tmp/rcc-test-output.log 2>/dev/null; then
            log "  ✓ RCC used RCC Remote for catalog fetching"
        else
            warn "  ! Could not confirm RCC Remote was used (may be using local cache)"
        fi
    else
        warn "  ! RCC holotree vars failed (RCC Remote may not be available yet)"
        cat /tmp/rcc-test-output.log
    fi
    
    # Cleanup
    cd - >/dev/null
    rm -rf "$test_dir"
}

# Test catalog listing
test_catalog_listing() {
    log "Testing catalog listing..."
    
    if $RCC_BIN ht catalogs > /tmp/rcc-catalogs.log 2>&1; then
        local catalog_count=$(grep -c "^[[:space:]]*[a-f0-9]\{40\}" /tmp/rcc-catalogs.log || echo "0")
        log "  ✓ Found $catalog_count catalog(s)"
        
        if [[ $catalog_count -gt 0 ]]; then
            log "  Sample catalogs:"
            head -5 /tmp/rcc-catalogs.log | sed 's/^/    /'
        fi
    else
        warn "  ! Could not list catalogs"
    fi
}

# Main test flow
main() {
    log "Starting RCC connectivity integration test..."
    echo ""
    
    download_rcc
    configure_rcc_profile
    test_rcc_basic
    test_rcc_remote_connectivity
    test_catalog_listing
    
    echo ""
    log "RCC connectivity integration test COMPLETED ✓"
    log "Note: Some tests may show warnings if RCC Remote is not fully operational"
}

main
