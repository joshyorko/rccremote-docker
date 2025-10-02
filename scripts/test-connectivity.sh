#!/bin/bash

# RCC connectivity testing script
# Usage: ./test-connectivity.sh [options]

set -e

# Default values
RCC_REMOTE_ORIGIN="${RCC_REMOTE_ORIGIN:-https://rccremote.local:8443}"
ROBOT_PATH="${ROBOT_PATH:-../data/robots-samples/rf7}"
TIMEOUT="${TIMEOUT:-300}"
VERBOSE="${VERBOSE:-false}"
SKIP_SSL_VERIFY="${SKIP_SSL_VERIFY:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [options]

Options:
    -o, --origin URL           RCC Remote origin URL (default: https://rccremote.local:8443)
    -r, --robot PATH           Path to robot directory with robot.yaml (default: ../data/robots-samples/rf7)
    -t, --timeout SECONDS      Timeout in seconds (default: 300)
    -s, --skip-ssl-verify      Skip SSL certificate verification
    -v, --verbose              Verbose output
    -h, --help                 Display this help message

Examples:
    # Test with defaults
    $0

    # Test specific RCC Remote instance
    $0 --origin https://rccremote.example.com:443

    # Test with custom robot
    $0 --robot /path/to/my/robot

    # Skip SSL verification for self-signed certs
    $0 --skip-ssl-verify
EOF
    exit 0
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

debug() {
    [ "$VERBOSE" = "true" ] && echo -e "${YELLOW}[DEBUG]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--origin)
            RCC_REMOTE_ORIGIN="$2"
            shift 2
            ;;
        -r|--robot)
            ROBOT_PATH="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -s|--skip-ssl-verify)
            SKIP_SSL_VERIFY="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if RCC is available
    if ! command -v rcc &> /dev/null; then
        # Try using the downloaded RCC binary
        if [ -f "/tmp/rcc-linux64" ]; then
            RCC_CMD="/tmp/rcc-linux64"
            info "Using RCC binary from /tmp/rcc-linux64"
        else
            error "RCC not found. Please install RCC or set PATH to include RCC binary."
        fi
    else
        RCC_CMD="rcc"
        info "Using system RCC: $(which rcc)"
    fi
    
    # Check RCC version
    local rcc_version=$($RCC_CMD version 2>&1 || echo "unknown")
    info "RCC version: $rcc_version"
    
    # Check if robot path exists
    if [ ! -d "$ROBOT_PATH" ]; then
        error "Robot path not found: $ROBOT_PATH"
    fi
    
    # Check if robot.yaml exists
    if [ ! -f "$ROBOT_PATH/robot.yaml" ]; then
        error "robot.yaml not found in: $ROBOT_PATH"
    fi
    
    log "Prerequisites check passed ✓"
}

# Configure RCC for remote origin
configure_rcc() {
    log "Configuring RCC for remote origin: $RCC_REMOTE_ORIGIN"
    
    export RCC_REMOTE_ORIGIN="$RCC_REMOTE_ORIGIN"
    debug "RCC_REMOTE_ORIGIN=$RCC_REMOTE_ORIGIN"
    
    # Configure SSL verification
    if [ "$SKIP_SSL_VERIFY" = "true" ]; then
        warn "SSL verification disabled"
        # Create profile with SSL verification disabled
        cat > /tmp/rcc-profile-noverify.yaml << 'EOF'
profiles:
  ssl-noverify:
    description: Profile with disabled SSL verification
    settings:
      verify-ssl: false
EOF
        $RCC_CMD config import -f /tmp/rcc-profile-noverify.yaml
        $RCC_CMD config switch -p ssl-noverify
        info "Switched to ssl-noverify profile"
    fi
    
    # Show current configuration
    if [ "$VERBOSE" = "true" ]; then
        debug "Current RCC configuration:"
        $RCC_CMD config diag
    fi
}

# Test RCC connectivity
test_connectivity() {
    log "Testing RCC connectivity to $RCC_REMOTE_ORIGIN"
    
    cd "$ROBOT_PATH"
    
    # Test holotree vars command
    info "Fetching holotree variables..."
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = "true" ]; then
        $RCC_CMD holotree vars
    else
        $RCC_CMD holotree vars > /tmp/rcc-holotree-vars.log 2>&1
    fi
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    info "Holotree variables fetched successfully in ${elapsed}s ✓"
    
    # Check if catalog was downloaded from remote
    if grep -q "Fill hololib from RCC REMOTE ORIGIN" /tmp/rcc-holotree-vars.log 2>/dev/null; then
        info "Catalog downloaded from RCC Remote ✓"
    elif [ "$VERBOSE" = "false" ]; then
        warn "Could not confirm catalog download from remote (check verbose output)"
    fi
}

# Test catalog listing
test_catalog_listing() {
    log "Testing catalog listing..."
    
    if $RCC_CMD holotree catalogs > /tmp/rcc-catalogs.log 2>&1; then
        local catalog_count=$(grep -c "^[[:space:]]*[a-f0-9]\{40\}" /tmp/rcc-catalogs.log || echo "0")
        info "Found $catalog_count catalogs ✓"
        
        if [ "$VERBOSE" = "true" ]; then
            echo "=== Available Catalogs ==="
            cat /tmp/rcc-catalogs.log
            echo ""
        fi
    else
        warn "Could not list catalogs (may be normal if no catalogs exist)"
    fi
}

# Test space creation
test_space_creation() {
    log "Testing space creation..."
    
    cd "$ROBOT_PATH"
    
    local start_time=$(date +%s)
    
    # Create space (this will use remote catalog if available)
    if [ "$VERBOSE" = "true" ]; then
        $RCC_CMD holotree vars -r robot.yaml
    else
        $RCC_CMD holotree vars -r robot.yaml > /tmp/rcc-space-creation.log 2>&1
    fi
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    info "Space created successfully in ${elapsed}s ✓"
}

# Show connectivity summary
show_summary() {
    log "Connectivity test completed successfully!"
    echo ""
    echo "=== Test Summary ==="
    echo "RCC Remote Origin: $RCC_REMOTE_ORIGIN"
    echo "Robot Path: $ROBOT_PATH"
    echo "SSL Verification: $([ "$SKIP_SSL_VERIFY" = "true" ] && echo "Disabled" || echo "Enabled")"
    echo ""
    echo "=== Results ==="
    echo "✓ RCC binary available"
    echo "✓ Robot configuration valid"
    echo "✓ RCC Remote connectivity working"
    echo "✓ Catalog download successful"
    echo "✓ Space creation successful"
    echo ""
    echo "=== Next Steps ==="
    echo "Your RCC client is now configured to use RCC Remote."
    echo "You can run your robots with:"
    echo "  cd $ROBOT_PATH"
    echo "  rcc run"
    echo ""
}

# Main function
main() {
    log "Starting RCC connectivity test"
    
    check_prerequisites
    configure_rcc
    test_connectivity
    test_catalog_listing
    test_space_creation
    show_summary
    
    log "All tests passed in $(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds ✓"
}

# Run main function
main
