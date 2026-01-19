#!/bin/bash

# Contract test for Health API endpoints
# Tests compliance with specs/001-streamlining-rcc-remote/contracts/health-api.yaml

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[CONTRACT TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

TARGET="${TARGET:-https://localhost:8443}"
FAILED_TESTS=0

log "Testing Health API Contract against $TARGET"

# Test /health/live endpoint
test_liveness_endpoint() {
    log "Testing /health/live endpoint..."
    
    local response=$(curl -sk -w "\n%{http_code}" "${TARGET}/health/live" 2>/dev/null)
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)
    
    # Must return 200 or 500
    if [[ "$status" != "200" && "$status" != "500" ]]; then
        error "Expected status 200 or 500, got: $status"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Response must be valid JSON
    if ! echo "$body" | jq empty 2>/dev/null; then
        error "Response is not valid JSON: $body"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Must have required fields: status, timestamp
    if ! echo "$body" | jq -e '.status' >/dev/null 2>&1; then
        error "Missing required field: status"
        ((FAILED_TESTS++))
        return 1
    fi
    
    if ! echo "$body" | jq -e '.timestamp' >/dev/null 2>&1; then
        error "Missing required field: timestamp"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Status must be one of: healthy, unhealthy, starting
    local status_value=$(echo "$body" | jq -r '.status')
    if [[ "$status_value" != "healthy" && "$status_value" != "unhealthy" && "$status_value" != "starting" ]]; then
        error "Invalid status value: $status_value (expected: healthy, unhealthy, or starting)"
        ((FAILED_TESTS++))
        return 1
    fi
    
    log "  ✓ /health/live contract validated"
    return 0
}

# Test /health/ready endpoint
test_readiness_endpoint() {
    log "Testing /health/ready endpoint..."
    
    local response=$(curl -sk -w "\n%{http_code}" "${TARGET}/health/ready" 2>/dev/null)
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)
    
    # Must return 200 or 503
    if [[ "$status" != "200" && "$status" != "503" ]]; then
        error "Expected status 200 or 503, got: $status"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Response must be valid JSON
    if ! echo "$body" | jq empty 2>/dev/null; then
        error "Response is not valid JSON: $body"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Must have required fields
    if ! echo "$body" | jq -e '.status' >/dev/null 2>&1; then
        error "Missing required field: status"
        ((FAILED_TESTS++))
        return 1
    fi
    
    if ! echo "$body" | jq -e '.timestamp' >/dev/null 2>&1; then
        error "Missing required field: timestamp"
        ((FAILED_TESTS++))
        return 1
    fi
    
    log "  ✓ /health/ready contract validated"
    return 0
}

# Test /health/startup endpoint
test_startup_endpoint() {
    log "Testing /health/startup endpoint..."
    
    local response=$(curl -sk -w "\n%{http_code}" "${TARGET}/health/startup" 2>/dev/null)
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)
    
    # Must return 200 or 503
    if [[ "$status" != "200" && "$status" != "503" ]]; then
        error "Expected status 200 or 503, got: $status"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Response must be valid JSON
    if ! echo "$body" | jq empty 2>/dev/null; then
        error "Response is not valid JSON: $body"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Must have required fields
    if ! echo "$body" | jq -e '.status' >/dev/null 2>&1; then
        error "Missing required field: status"
        ((FAILED_TESTS++))
        return 1
    fi
    
    if ! echo "$body" | jq -e '.timestamp' >/dev/null 2>&1; then
        error "Missing required field: timestamp"
        ((FAILED_TESTS++))
        return 1
    fi
    
    log "  ✓ /health/startup contract validated"
    return 0
}

# Test /metrics endpoint
test_metrics_endpoint() {
    log "Testing /metrics endpoint..."
    
    local response=$(curl -sk -w "\n%{http_code}" "${TARGET}/metrics" 2>/dev/null)
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)
    
    # Must return 200
    if [[ "$status" != "200" ]]; then
        warn "Expected status 200, got: $status (metrics endpoint may not be implemented)"
        return 0
    fi
    
    # Response should be plain text
    if echo "$body" | grep -q "^# HELP"; then
        log "  ✓ /metrics endpoint returns Prometheus format"
    else
        warn "  ! /metrics endpoint does not return Prometheus format"
    fi
    
    return 0
}

# Run all tests
main() {
    log "Starting Health API contract tests..."
    echo ""
    
    test_liveness_endpoint || true
    test_readiness_endpoint || true
    test_startup_endpoint || true
    test_metrics_endpoint || true
    
    echo ""
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log "All Health API contract tests PASSED ✓"
        exit 0
    else
        error "$FAILED_TESTS contract test(s) FAILED"
        exit 1
    fi
}

main
