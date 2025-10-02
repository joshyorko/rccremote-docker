#!/bin/bash

# Cloudflare Tunnel deployment script for RCC Remote
# Usage: ./deploy-cloudflare.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
COMPOSE_FILE="${PROJECT_ROOT}/examples/docker-compose.cloudflare.yml"
DEFAULT_SERVER_NAME="rccremote.joshyorko.com"

check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker first."
    fi
    
    if ! command -v docker compose &> /dev/null; then
        error "Docker Compose not found. Please install Docker Compose first."
    fi
    
    log "Prerequisites check passed ✓"
}

check_tunnel_token() {
    if [ -z "$CF_TUNNEL_TOKEN" ]; then
        error "CF_TUNNEL_TOKEN not set. Please set your Cloudflare Tunnel token:
        
        export CF_TUNNEL_TOKEN='your-token-here'
        
        Or create a .env file with:
        CF_TUNNEL_TOKEN=your-token-here
        
        Get your token from: https://one.dash.cloudflare.com/"
    fi
    
    log "Tunnel token found ✓"
}

setup_environment() {
    log "Setting up environment..."
    
    export SERVER_NAME="${SERVER_NAME:-$DEFAULT_SERVER_NAME}"
    
    log "Configuration:"
    info "  Server Name: $SERVER_NAME"
    info "  Compose File: $COMPOSE_FILE"
}

build_images() {
    log "Building Docker images..."
    docker compose -f "$COMPOSE_FILE" build
    log "Image build completed ✓"
}

deploy_services() {
    log "Deploying services with Docker Compose..."
    docker compose -f "$COMPOSE_FILE" up -d
    log "Services deployed ✓"
}

wait_for_health() {
    log "Waiting for services to be healthy (timeout: 120s)..."
    
    local timeout=120
    local elapsed=0
    local interval=5
    
    while [ $elapsed -lt $timeout ]; do
        if docker compose -f "$COMPOSE_FILE" ps | grep -q "healthy"; then
            log "Services are healthy ✓"
            return 0
        fi
        
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    warn "Services did not become healthy within ${timeout}s"
    return 1
}

verify_deployment() {
    log "Verifying deployment..."
    
    # Check if containers are running
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        error "Containers are not running"
    fi
    
    log "Deployment verification passed ✓"
}

show_info() {
    echo ""
    log "Deployment completed successfully!"
    echo ""
    echo "=== Deployment Information ==="
    echo "Server Name: $SERVER_NAME"
    echo "Public URL: https://$SERVER_NAME"
    echo ""
    echo "=== Running Containers ==="
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
    echo "=== Client Configuration ==="
    echo "No custom SSL configuration needed! Just set:"
    echo ""
    echo "  export RCC_REMOTE_ORIGIN=https://$SERVER_NAME"
    echo "  export ROBOCORP_HOME=/opt/robocorp"
    echo ""
    echo "  # Create directory if needed"
    echo "  sudo mkdir -p /opt/robocorp"
    echo "  sudo chown -R \$USER:\$USER /opt/robocorp"
    echo ""
    echo "  # Enable shared holotree"
    echo "  rcc holotree shared --enable"
    echo ""
    echo "  # Test connection"
    echo "  rcc holotree vars"
    echo ""
    echo "=== Useful Commands ==="
    echo "View logs:"
    echo "  docker compose -f $COMPOSE_FILE logs -f"
    echo ""
    echo "Stop services:"
    echo "  docker compose -f $COMPOSE_FILE down"
    echo ""
    echo "View Cloudflare Tunnel status:"
    echo "  https://one.dash.cloudflare.com/"
    echo ""
}

main() {
    local start_time=$(date +%s)
    
    log "Starting RCC Remote Cloudflare Tunnel deployment"
    log "Server Name: ${SERVER_NAME:-$DEFAULT_SERVER_NAME}"
    
    check_prerequisites
    check_tunnel_token
    setup_environment
    build_images
    deploy_services
    wait_for_health
    verify_deployment
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    show_info
    
    log "Deployment completed in ${minutes} minutes and ${seconds} seconds"
}

main "$@"
