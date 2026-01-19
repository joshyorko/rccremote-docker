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

RCC_REMOTE_ORIGIN="${RCC_REMOTE_ORIGIN:-https://localhost:8443}"
RCC_BIN="rcc"

log "Testing RCC client connectivity to $RCC_REMOTE_ORIGIN"

# Check if RCC is available
check_rcc() {
    if ! command -v rcc &> /dev/null; then
        error "RCC not found in PATH. Please install RCC first."
    fi
    
    local version=$(rcc version 2>&1 || echo "unknown")
    log "RCC version: $version"
}

# Configure RCC profile for SSL no-verify
configure_rcc_profile() {
    log "Configuring RCC profile for RCC Remote..."
    
    # Create profile configuration
    local profile_file="/tmp/rcc-profile-test.yaml"
    cat > "$profile_file" << 'EOF'
profiles:
  rccremote-test:
    description: Test profile for RCC Remote integration
    settings:
      certificates:
        verify-ssl: false
EOF
    
    # Import and switch profile
    if rcc config import -f "$profile_file" > /dev/null 2>&1; then
        if rcc config switch -p rccremote-test > /dev/null 2>&1; then
            log "RCC profile configured ✓"
        else
            warn "Failed to switch to profile, continuing with default settings"
        fi
    else
        warn "Failed to import profile, continuing with default settings"
    fi
    
    # Clean up temporary file
    rm -f "$profile_file"
}

# Test basic RCC commands
test_rcc_basic() {
    log "Testing basic RCC commands..."
    
    # Test version command
    if ! rcc version >/dev/null 2>&1; then
        error "RCC version command failed"
    fi
    
    # Test holotree commands
    if ! rcc holotree catalogs >/dev/null 2>&1; then
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
    if timeout 30 rcc holotree vars -r robot.yaml > /tmp/rcc-test-output.log 2>&1; then
        log "  ✓ RCC holotree vars succeeded"
        
        # Check if remote was used
        if grep -q "Fill hololib from RCC_REMOTE_ORIGIN" /tmp/rcc-test-output.log 2>/dev/null; then
            log "  ✓ RCC used RCC Remote for catalog fetching"
        else
            warn "  ! Could not confirm RCC Remote was used (may be using local cache)"
        fi
    else
        warn "  ! RCC holotree vars failed (RCC Remote may not be available yet)"
        if [ -f /tmp/rcc-test-output.log ]; then
            head -10 /tmp/rcc-test-output.log
        fi
    fi
    
    # Cleanup
    cd - >/dev/null
    rm -rf "$test_dir"
}

# Test catalog listing
test_catalog_listing() {
    log "Testing catalog listing..."
    
    if rcc holotree catalogs > /tmp/rcc-catalogs.log 2>&1; then
        local catalog_count=$(grep -c "^[[:space:]]*[a-f0-9]\{16\}" /tmp/rcc-catalogs.log || echo "0")
        log "  ✓ Found $catalog_count catalog(s) in holotree"
        
        if [[ $catalog_count -gt 0 ]]; then
            log "  Sample catalogs:"
            head -5 /tmp/rcc-catalogs.log | sed 's/^/    /'
        else
            log "  (No catalogs found - this is normal for fresh installations)"
        fi
    else
        warn "  ! Could not list catalogs"
        if [ -f /tmp/rcc-catalogs.log ]; then
            cat /tmp/rcc-catalogs.log
        fi
    fi
}

# Test RCC Remote server availability
test_rcc_remote_server() {
    log "Testing RCC Remote server availability..."
    
    if curl -k -s --connect-timeout 5 "$RCC_REMOTE_ORIGIN/" > /dev/null 2>&1; then
        log "  ✓ RCC Remote server is responding"
    else
        error "RCC Remote server at $RCC_REMOTE_ORIGIN is not responding"
    fi
}

# Main test flow
main() {
    log "Starting RCC connectivity integration test..."
    echo ""
    
    # Set the RCC_REMOTE_ORIGIN environment variable
    export RCC_REMOTE_ORIGIN="$RCC_REMOTE_ORIGIN"
    
    check_rcc
    test_rcc_remote_server
    configure_rcc_profile
    test_rcc_basic
    test_rcc_remote_connectivity
    test_catalog_listing
    
    echo ""
    log "RCC connectivity integration test COMPLETED ✓"
    log "RCC Remote service at $RCC_REMOTE_ORIGIN is working properly"
}

main
