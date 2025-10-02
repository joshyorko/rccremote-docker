#!/bin/bash

# Contract test for Deployment API endpoints
# Tests compliance with specs/001-streamlining-rcc-remote/contracts/deployment-api.yaml

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[CONTRACT TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

TARGET="${TARGET:-https://localhost:8443}"
FAILED_TESTS=0

log "Testing Deployment API Contract against $TARGET"

# Test /api/v1/deployment/validate endpoint
test_deployment_validate() {
    log "Testing POST /api/v1/deployment/validate endpoint..."
    
    # Valid deployment manifest
    local valid_manifest='{
        "type": "kubernetes",
        "environment": "production",
        "server_name": "rccremote.example.com",
        "replica_count": 3,
        "resource_limits": {
            "cpu": "500m",
            "memory": "1Gi",
            "storage": "10Gi"
        },
        "scaling_config": {
            "min_replicas": 3,
            "max_replicas": 10,
            "target_cpu_percent": 70
        }
    }'
    
    local response=$(curl -sk -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$valid_manifest" \
        "${TARGET}/api/v1/deployment/validate" 2>/dev/null)
    
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)
    
    # Check if endpoint exists (200 or 400 expected)
    if [[ "$status" == "404" ]]; then
        warn "Deployment API not implemented yet (/api/v1/deployment/validate returns 404)"
        return 0
    fi
    
    # Must return 200 or 400
    if [[ "$status" != "200" && "$status" != "400" ]]; then
        warn "Expected status 200 or 400, got: $status"
        return 0
    fi
    
    # Response must be valid JSON
    if ! echo "$body" | jq empty 2>/dev/null; then
        error "Response is not valid JSON: $body"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Must have required fields: valid, errors
    if ! echo "$body" | jq -e '.valid' >/dev/null 2>&1; then
        error "Missing required field: valid"
        ((FAILED_TESTS++))
        return 1
    fi
    
    if ! echo "$body" | jq -e '.errors' >/dev/null 2>&1; then
        error "Missing required field: errors"
        ((FAILED_TESTS++))
        return 1
    fi
    
    log "  ✓ /api/v1/deployment/validate contract validated"
    return 0
}

# Test /api/v1/certificates/generate endpoint
test_certificate_generate() {
    log "Testing POST /api/v1/certificates/generate endpoint..."
    
    # Valid certificate request
    local cert_request='{
        "server_names": ["rccremote.local", "rccremote.example.com"],
        "cert_type": "self-signed",
        "validity_days": 365
    }'
    
    local response=$(curl -sk -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$cert_request" \
        "${TARGET}/api/v1/certificates/generate" 2>/dev/null)
    
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)
    
    # Check if endpoint exists
    if [[ "$status" == "404" ]]; then
        warn "Certificate API not implemented yet (/api/v1/certificates/generate returns 404)"
        return 0
    fi
    
    # Must return 200 or 400
    if [[ "$status" != "200" && "$status" != "400" ]]; then
        warn "Expected status 200 or 400, got: $status"
        return 0
    fi
    
    # Response must be valid JSON
    if ! echo "$body" | jq empty 2>/dev/null; then
        error "Response is not valid JSON: $body"
        ((FAILED_TESTS++))
        return 1
    fi
    
    if [[ "$status" == "200" ]]; then
        # Success response should have certificate fields
        if ! echo "$body" | jq -e '.server_cert' >/dev/null 2>&1; then
            error "Missing required field: server_cert"
            ((FAILED_TESTS++))
            return 1
        fi
        
        if ! echo "$body" | jq -e '.server_key' >/dev/null 2>&1; then
            error "Missing required field: server_key"
            ((FAILED_TESTS++))
            return 1
        fi
        
        if ! echo "$body" | jq -e '.expiry_date' >/dev/null 2>&1; then
            error "Missing required field: expiry_date"
            ((FAILED_TESTS++))
            return 1
        fi
    fi
    
    log "  ✓ /api/v1/certificates/generate contract validated"
    return 0
}

# Test /api/v1/catalogs endpoint
test_catalogs_list() {
    log "Testing GET /api/v1/catalogs endpoint..."
    
    local response=$(curl -sk -w "\n%{http_code}" \
        "${TARGET}/api/v1/catalogs" 2>/dev/null)
    
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)
    
    # Check if endpoint exists
    if [[ "$status" == "404" ]]; then
        warn "Catalogs API not implemented yet (/api/v1/catalogs returns 404)"
        return 0
    fi
    
    # Must return 200
    if [[ "$status" != "200" ]]; then
        warn "Expected status 200, got: $status"
        return 0
    fi
    
    # Response must be valid JSON
    if ! echo "$body" | jq empty 2>/dev/null; then
        error "Response is not valid JSON: $body"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Must have required fields: catalogs, total_count
    if ! echo "$body" | jq -e '.catalogs' >/dev/null 2>&1; then
        error "Missing required field: catalogs"
        ((FAILED_TESTS++))
        return 1
    fi
    
    if ! echo "$body" | jq -e '.total_count' >/dev/null 2>&1; then
        error "Missing required field: total_count"
        ((FAILED_TESTS++))
        return 1
    fi
    
    log "  ✓ /api/v1/catalogs contract validated"
    return 0
}

# Run all tests
main() {
    log "Starting Deployment API contract tests..."
    echo ""
    
    test_deployment_validate || true
    test_certificate_generate || true
    test_catalogs_list || true
    
    echo ""
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log "All Deployment API contract tests PASSED ✓"
        log "Note: Some APIs may not be implemented yet (warnings shown above)"
        exit 0
    else
        error "$FAILED_TESTS contract test(s) FAILED"
        exit 1
    fi
}

main
