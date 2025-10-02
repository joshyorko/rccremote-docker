#!/bin/bash

# Integration test for Docker Compose deployment
# Tests basic deployment, health checks, and RCC connectivity

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

log "Starting Docker Compose deployment test..."

# Clean up function
cleanup() {
    log "Cleaning up..."
    cd ../../examples
    docker-compose -f docker-compose.development.yml down -v 2>/dev/null || true
}

trap cleanup EXIT

# Navigate to examples directory
cd "$(dirname "$0")/../../examples"

# Deploy
log "Deploying Docker Compose development environment..."
export SERVER_NAME=rccremote.local
docker-compose -f docker-compose.development.yml up -d

# Wait for services to be healthy
log "Waiting for services to be healthy (max 180s)..."
timeout=180
elapsed=0
interval=5

while [ $elapsed -lt $timeout ]; do
    if docker ps --filter "name=rccremote" --filter "health=healthy" | grep -q rccremote; then
        if docker ps --filter "name=nginx" --filter "health=healthy" | grep -q nginx; then
            log "Services are healthy ✓"
            break
        fi
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
done

if [ $elapsed -ge $timeout ]; then
    error "Services did not become healthy within ${timeout}s"
fi

# Test health endpoints
log "Testing health endpoints..."
for endpoint in /health/live /health/ready; do
    if curl -skf https://localhost:8443${endpoint} > /dev/null 2>&1; then
        log "  $endpoint: OK ✓"
    else
        error "  $endpoint: FAILED"
    fi
done

log "Docker Compose deployment test PASSED ✓"
