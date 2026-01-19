#!/bin/bash

# Deploy RCC Remote using Docker Compose
# Usage: ./deploy-docker.sh [options]

set -e

# Default values
ENVIRONMENT="${ENVIRONMENT:-development}"
COMPOSE_FILE=""
SERVER_NAME="${SERVER_NAME:-rccremote.local}"
TIMEOUT="${TIMEOUT:-300}"
SKIP_BUILD="${SKIP_BUILD:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [options]

Options:
    -e, --environment ENV       Environment: development, production (default: development)
    -f, --file FILE            Custom docker-compose file path
    -s, --server-name NAME     Server name for certificates (default: rccremote.local)
    -t, --timeout SECONDS      Deployment timeout in seconds (default: 300)
    -b, --skip-build           Skip building images, use existing
    -h, --help                 Display this help message

Examples:
    # Deploy development environment
    $0

    # Deploy production with custom server name
    $0 --environment production --server-name rccremote.example.com

    # Use custom compose file
    $0 --file /path/to/docker-compose.yml
EOF
    exit 0
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -f|--file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        -s|--server-name)
            SERVER_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -b|--skip-build)
            SKIP_BUILD="true"
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

# Determine compose file
if [ -z "$COMPOSE_FILE" ]; then
    if [ "$ENVIRONMENT" = "production" ]; then
        COMPOSE_FILE="../docker-compose/docker-compose.production.yml"
    else
        COMPOSE_FILE="../docker-compose/docker-compose.development.yml"
    fi
fi

# Check if running from scripts directory
if [ ! -f "$COMPOSE_FILE" ] && [ -f "docker-compose/docker-compose.$ENVIRONMENT.yml" ]; then
    COMPOSE_FILE="docker-compose/docker-compose.$ENVIRONMENT.yml"
fi

# Validate prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker first."
    fi
    
    # Check docker-compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose not found. Please install Docker Compose first."
    fi
    
    # Check compose file
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Compose file not found: $COMPOSE_FILE"
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker first."
    fi
    
    log "Prerequisites check passed ✓"
}

# Setup environment
setup_environment() {
    log "Setting up environment variables..."
    
    export SERVER_NAME="$SERVER_NAME"
    
    # Create .env file if it doesn't exist
    if [ ! -f "../.env" ] && [ ! -f ".env" ]; then
        local env_file="../.env"
        [ -d "examples" ] && env_file=".env"
        
        cat > "$env_file" << EOF
SERVER_NAME=$SERVER_NAME
ROBOCORP_HOME=/opt/robocorp
RCC_REMOTE_ORIGIN=https://$SERVER_NAME:443
EOF
        log "Created .env file with SERVER_NAME=$SERVER_NAME"
    fi
    
    log "Environment setup completed ✓"
}

# Build images
build_images() {
    if [ "$SKIP_BUILD" = "true" ]; then
        log "Skipping image build (--skip-build flag set)"
        return 0
    fi
    
    log "Building Docker images..."
    
    if docker compose version &> /dev/null; then
        docker compose -f "$COMPOSE_FILE" build
    else
        docker-compose -f "$COMPOSE_FILE" build
    fi
    
    log "Image build completed ✓"
}

# Deploy containers
deploy_containers() {
    log "Deploying containers with Docker Compose..."
    
    if docker compose version &> /dev/null; then
        docker compose -f "$COMPOSE_FILE" up -d
    else
        docker-compose -f "$COMPOSE_FILE" up -d
    fi
    
    log "Containers deployed ✓"
}

# Wait for services
wait_for_services() {
    log "Waiting for services to be healthy (timeout: ${TIMEOUT}s)..."
    
    local elapsed=0
    local interval=5
    
    while [ $elapsed -lt $TIMEOUT ]; do
        # Check rccremote health
        if docker ps --filter "name=rccremote" --filter "health=healthy" | grep -q rccremote; then
            log "RCC Remote service is healthy ✓"
            
            # Check nginx health
            if docker ps --filter "name=nginx" --filter "health=healthy" | grep -q nginx; then
                log "Nginx service is healthy ✓"
                return 0
            fi
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo ""
    error "Services did not become healthy within ${TIMEOUT} seconds"
}

# Verify basic connectivity
verify_health() {
    log "Verifying basic service connectivity..."
    
    local base_url="https://localhost:8443"
    [ "$ENVIRONMENT" = "production" ] && base_url="https://localhost:443"
    
    if curl -skf "${base_url}/" --connect-timeout 5 > /dev/null 2>&1; then
        log "  HTTPS endpoint: OK ✓"
    else
        warn "  HTTPS endpoint: FAILED (may need more time to initialize)"
    fi
}

# Show deployment info
show_deployment_info() {
    log "Deployment completed successfully!"
    echo ""
    echo "=== Deployment Information ==="
    echo "Environment: $ENVIRONMENT"
    echo "Compose File: $COMPOSE_FILE"
    echo "Server Name: $SERVER_NAME"
    echo ""
    echo "=== Running Containers ==="
    docker ps --filter "name=rccremote"
    echo ""
    echo "=== Access Information ==="
    if [ "$ENVIRONMENT" = "production" ]; then
        echo "HTTPS endpoint: https://$SERVER_NAME:443"
    else
        echo "HTTPS endpoint: https://$SERVER_NAME:8443"
    fi
    echo ""
    echo "=== Useful Commands ==="
    echo "View logs:"
    echo "  docker logs rccremote-dev -f    # Development"
    echo "  docker logs rccremote-prod -f   # Production"
    echo ""
    echo "Stop services:"
    if docker compose version &> /dev/null; then
        echo "  docker compose -f $COMPOSE_FILE down"
    else
        echo "  docker-compose -f $COMPOSE_FILE down"
    fi
    echo ""
    echo "Test RCC connectivity:"
    echo "  export RCC_REMOTE_ORIGIN=https://$SERVER_NAME:8443"
    echo "  rcc holotree vars"
    echo ""
}

# Main deployment flow
main() {
    log "Starting RCC Remote Docker deployment"
    log "Environment: $ENVIRONMENT | Server Name: $SERVER_NAME"
    
    check_prerequisites
    setup_environment
    build_images
    deploy_containers
    wait_for_services
    verify_health
    show_deployment_info
    
    log "Deployment completed in $(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds"
}

# Run main function
main
