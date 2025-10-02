#!/bin/bash

# Health check script for RCC Remote
# Usage: ./health-check.sh [options]

set -e

# Default values
TARGET="${TARGET:-localhost:8443}"
TIMEOUT="${TIMEOUT:-30}"
INTERVAL="${INTERVAL:-5}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [options]

Options:
    -t, --target HOST:PORT     Target host and port (default: localhost:8443)
    --timeout SECONDS          Maximum wait time in seconds (default: 30)
    --interval SECONDS         Check interval in seconds (default: 5)
    -v, --verbose              Verbose output
    -h, --help                 Display this help message

Health Endpoints:
    /health/live               Liveness check - is the service running?
    /health/ready              Readiness check - can the service accept requests?
    /health/startup            Startup check - has initialization completed?

Examples:
    # Check all health endpoints on default target
    $0

    # Check specific target with custom timeout
    $0 --target rccremote.local:443 --timeout 60

    # Verbose output with custom interval
    $0 --verbose --interval 10
EOF
    exit 0
}

log() {
    [ "$VERBOSE" = "true" ] && echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
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
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v curl &> /dev/null; then
        error "curl not found. Please install curl first."
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Check single endpoint
check_endpoint() {
    local endpoint=$1
    local target=$2
    local url="https://${target}${endpoint}"
    
    log "Checking endpoint: $url"
    
    local response_code=$(curl -sk -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    local response_time=$(curl -sk -o /dev/null -w "%{time_total}" "$url" 2>/dev/null || echo "999")
    
    if [ "$response_code" = "200" ]; then
        info "✓ $endpoint: OK (${response_time}s)"
        return 0
    else
        warn "✗ $endpoint: FAILED (HTTP $response_code)"
        return 1
    fi
}

# Wait for endpoint to be healthy
wait_for_endpoint() {
    local endpoint=$1
    local target=$2
    local elapsed=0
    
    log "Waiting for $endpoint to be healthy (timeout: ${TIMEOUT}s)..."
    
    while [ $elapsed -lt $TIMEOUT ]; do
        if check_endpoint "$endpoint" "$target" > /dev/null 2>&1; then
            return 0
        fi
        
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
        
        [ "$VERBOSE" = "true" ] || echo -n "."
    done
    
    [ "$VERBOSE" = "false" ] && echo ""
    return 1
}

# Check all health endpoints
check_all_endpoints() {
    local target=$1
    local all_healthy=true
    
    info "Checking health endpoints on $target"
    echo ""
    
    # Check liveness
    if ! check_endpoint "/health/live" "$target"; then
        all_healthy=false
    fi
    
    # Check readiness
    if ! check_endpoint "/health/ready" "$target"; then
        all_healthy=false
    fi
    
    # Check startup
    if ! check_endpoint "/health/startup" "$target"; then
        all_healthy=false
    fi
    
    echo ""
    
    if [ "$all_healthy" = "true" ]; then
        info "All health checks passed ✓"
        return 0
    else
        error "Some health checks failed"
        return 1
    fi
}

# Get detailed health information
get_health_details() {
    local target=$1
    
    info "Fetching detailed health information..."
    echo ""
    
    for endpoint in /health/live /health/ready /health/startup; do
        local url="https://${target}${endpoint}"
        echo "=== $endpoint ==="
        curl -sk "$url" 2>/dev/null | jq '.' 2>/dev/null || curl -sk "$url" 2>/dev/null || echo "No response"
        echo ""
    done
}

# Monitor health continuously
monitor_health() {
    local target=$1
    
    info "Starting continuous health monitoring (Ctrl+C to stop)..."
    echo ""
    
    while true; do
        local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
        echo "[$timestamp]"
        check_all_endpoints "$target"
        echo ""
        sleep $INTERVAL
    done
}

# Main function
main() {
    check_prerequisites
    
    # If timeout is specified, wait for service to be healthy
    if [ "$TIMEOUT" -gt 0 ]; then
        local start_time=$(date +%s)
        
        # Wait for liveness endpoint
        if ! wait_for_endpoint "/health/live" "$TARGET"; then
            error "Service did not become healthy within ${TIMEOUT} seconds"
            exit 1
        fi
        
        # Wait for readiness endpoint
        if ! wait_for_endpoint "/health/ready" "$TARGET"; then
            error "Service did not become ready within ${TIMEOUT} seconds"
            exit 1
        fi
        
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        
        info "Service is healthy and ready after ${elapsed} seconds ✓"
    fi
    
    # Perform comprehensive health check
    if ! check_all_endpoints "$TARGET"; then
        exit 1
    fi
    
    # Show detailed info if verbose
    if [ "$VERBOSE" = "true" ]; then
        get_health_details "$TARGET"
    fi
    
    exit 0
}

# Run main function
main
