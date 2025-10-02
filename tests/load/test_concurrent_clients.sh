#!/bin/bash

# Load test for 100+ concurrent RCC clients
# Tests system performance and scalability under load

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[LOAD TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

TARGET="${TARGET:-https://localhost:8443}"
CLIENT_COUNT="${CLIENT_COUNT:-100}"
DURATION="${DURATION:-60}"
CONCURRENT_REQUESTS="${CONCURRENT_REQUESTS:-10}"

log "Load testing $TARGET with $CLIENT_COUNT clients over ${DURATION}s"

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v curl &> /dev/null; then
        error "curl not found. Please install curl."
    fi
    
    if ! command -v ab &> /dev/null && ! command -v hey &> /dev/null; then
        warn "Neither 'ab' nor 'hey' found. Installing basic load testing..."
        # We'll use parallel curl as fallback
    fi
    
    log "Prerequisites check passed ✓"
}

# Simple health check load test using parallel curl
load_test_health_endpoints() {
    log "Load testing health endpoints with $CLIENT_COUNT requests..."
    
    local start_time=$(date +%s)
    local success_count=0
    local fail_count=0
    local total_time=0
    
    # Function to test single endpoint
    test_endpoint() {
        local endpoint=$1
        local req_start=$(date +%s%N)
        
        local status=$(curl -sk -o /dev/null -w "%{http_code}" "${TARGET}${endpoint}" 2>/dev/null)
        
        local req_end=$(date +%s%N)
        local req_time=$(( (req_end - req_start) / 1000000 ))  # Convert to ms
        
        if [[ "$status" == "200" ]]; then
            echo "success:$req_time"
        else
            echo "fail:$req_time"
        fi
    }
    
    export -f test_endpoint
    export TARGET
    
    # Test /health/live endpoint
    log "  Testing /health/live with $CLIENT_COUNT requests..."
    
    local results_file=$(mktemp)
    
    # Run requests in parallel batches
    for ((i=0; i<CLIENT_COUNT; i++)); do
        test_endpoint "/health/live" >> "$results_file" &
        
        # Limit concurrent requests
        if (( (i+1) % CONCURRENT_REQUESTS == 0 )); then
            wait
        fi
    done
    wait
    
    # Analyze results
    success_count=$(grep -c "^success:" "$results_file" || echo 0)
    fail_count=$(grep -c "^fail:" "$results_file" || echo 0)
    
    # Calculate response times
    local total_time=0
    local min_time=999999
    local max_time=0
    
    while IFS=: read -r status time; do
        total_time=$((total_time + time))
        if [[ $time -lt $min_time ]]; then
            min_time=$time
        fi
        if [[ $time -gt $max_time ]]; then
            max_time=$time
        fi
    done < "$results_file"
    
    local avg_time=$((total_time / CLIENT_COUNT))
    
    rm -f "$results_file"
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    log ""
    log "=== Load Test Results ==="
    log "Total requests:    $CLIENT_COUNT"
    log "Successful:        $success_count ($(( success_count * 100 / CLIENT_COUNT ))%)"
    log "Failed:            $fail_count ($(( fail_count * 100 / CLIENT_COUNT ))%)"
    log "Duration:          ${elapsed}s"
    log "Requests/sec:      $(( CLIENT_COUNT / elapsed ))"
    log ""
    log "Response times (ms):"
    log "  Min:             ${min_time}ms"
    log "  Avg:             ${avg_time}ms"
    log "  Max:             ${max_time}ms"
    log ""
    
    # Validate against requirements
    if [[ $success_count -lt $(( CLIENT_COUNT * 95 / 100 )) ]]; then
        error "Success rate below 95%: $(( success_count * 100 / CLIENT_COUNT ))%"
    fi
    
    if [[ $avg_time -gt 5000 ]]; then
        error "Average response time exceeds 5s: ${avg_time}ms"
    fi
    
    log "✓ Load test passed: $(( success_count * 100 / CLIENT_COUNT ))% success rate, ${avg_time}ms avg response time"
}

# Sustained load test
sustained_load_test() {
    log "Running sustained load test for ${DURATION}s..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION))
    local request_count=0
    local success_count=0
    
    while [[ $(date +%s) -lt $end_time ]]; do
        for ((i=0; i<CONCURRENT_REQUESTS; i++)); do
            {
                local status=$(curl -sk -o /dev/null -w "%{http_code}" "${TARGET}/health/live" 2>/dev/null)
                if [[ "$status" == "200" ]]; then
                    ((success_count++))
                fi
                ((request_count++))
            } &
        done
        wait
        sleep 0.1
    done
    
    local actual_duration=$(($(date +%s) - start_time))
    local rps=$((request_count / actual_duration))
    local success_rate=$((success_count * 100 / request_count))
    
    log ""
    log "=== Sustained Load Test Results ==="
    log "Duration:          ${actual_duration}s"
    log "Total requests:    $request_count"
    log "Successful:        $success_count ($success_rate%)"
    log "Requests/sec:      $rps"
    log ""
    
    if [[ $success_rate -lt 95 ]]; then
        error "Success rate below 95%: $success_rate%"
    fi
    
    log "✓ Sustained load test passed: $success_rate% success rate over ${actual_duration}s"
}

# Concurrent clients simulation
concurrent_clients_test() {
    log "Simulating $CLIENT_COUNT concurrent clients..."
    
    # This would typically use a more sophisticated load testing tool
    # For now, we'll do a simplified version
    
    warn "Full concurrent client simulation requires dedicated load testing tools"
    warn "Consider using: hey, k6, or locust for production load testing"
    
    log "Running simplified concurrent test..."
    
    local pids=()
    local results_dir=$(mktemp -d)
    
    # Spawn concurrent client processes
    for ((i=0; i<CLIENT_COUNT; i++)); do
        {
            local result=$(curl -sk -o /dev/null -w "%{http_code}:%{time_total}" "${TARGET}/health/ready" 2>/dev/null)
            echo "$result" > "$results_dir/client_$i.result"
        } &
        pids+=($!)
        
        # Stagger starts slightly
        if (( i % 10 == 0 )); then
            sleep 0.1
        fi
    done
    
    # Wait for all clients
    log "  Waiting for $CLIENT_COUNT concurrent requests to complete..."
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    # Analyze results
    local success=0
    local total=0
    for result_file in "$results_dir"/*.result; do
        if [ -f "$result_file" ]; then
            local code=$(cut -d: -f1 < "$result_file")
            if [[ "$code" == "200" ]]; then
                ((success++))
            fi
            ((total++))
        fi
    done
    
    rm -rf "$results_dir"
    
    local success_rate=$((success * 100 / total))
    
    log ""
    log "=== Concurrent Clients Test Results ==="
    log "Concurrent clients: $total"
    log "Successful:         $success ($success_rate%)"
    log ""
    
    if [[ $success_rate -lt 95 ]]; then
        error "Success rate below 95%: $success_rate%"
    fi
    
    log "✓ Concurrent clients test passed: $success_rate% success rate"
}

# Main test flow
main() {
    log "Starting load test for RCC Remote..."
    log "Target: $TARGET"
    log "Clients: $CLIENT_COUNT"
    log "Duration: ${DURATION}s"
    echo ""
    
    check_prerequisites
    load_test_health_endpoints
    sustained_load_test
    concurrent_clients_test
    
    echo ""
    log "====================================="
    log "Load test COMPLETED successfully ✓"
    log "System handled $CLIENT_COUNT+ concurrent clients"
    log "====================================="
}

main
