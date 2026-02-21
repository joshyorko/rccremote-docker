#!/bin/bash

# Create Cloudflare Tunnel programmatically using cloudflared CLI
# Usage: ./create-cloudflare-tunnel.sh [OPTIONS]
#
# Options:
#   --tunnel-name NAME     Name for the tunnel (default: rccremote)
#   --hostname HOSTNAME    Public hostname (e.g., rccremote.example.com)
#   --service URL          Service URL (default: http://rccremote:4653)
#   --auto-deploy          Automatically deploy after creation
#   --help                 Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# Default values
TUNNEL_NAME="rccremote"
HOSTNAME=""
SERVICE_URL="http://rccremote:4653"
AUTO_DEPLOY=false

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

show_help() {
    cat << EOF
${CYAN}Cloudflare Tunnel Creator for RCC Remote${NC}

This script creates a Cloudflare Tunnel programmatically using the cloudflared CLI.

${YELLOW}Usage:${NC}
    $0 [OPTIONS]

${YELLOW}Options:${NC}
    --tunnel-name NAME     Name for the tunnel (default: rccremote)
    --hostname HOSTNAME    Public hostname (e.g., rccremote.example.com) [REQUIRED]
    --service URL          Service URL (default: http://rccremote:4653)
    --auto-deploy          Automatically deploy after creation
    --help                 Show this help message

${YELLOW}Examples:${NC}
    # Create tunnel with custom hostname
    $0 --hostname rccremote.example.com

    # Create and auto-deploy
    $0 --hostname rccremote.example.com --auto-deploy

    # Custom tunnel name and hostname
    $0 --tunnel-name my-rccremote --hostname rcc.example.com

${YELLOW}Prerequisites:${NC}
    1. cloudflared CLI installed (https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/)
    2. Cloudflare account with a domain
    3. Cloudflare Zero Trust access (free tier works)

${YELLOW}Installation (if cloudflared not installed):${NC}
    # Homebrew (recommended for most systems)
    brew install cloudflare/cloudflare/cloudflared

    # Universal Blue / Fedora Silverblue / Bluefin (immutable distros)
    brew install cloudflared

    # Arch Linux / Manjaro
    yay -S cloudflared-bin

    # Traditional Linux (Debian/Ubuntu)
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb

    # Fedora (traditional)
    sudo dnf install cloudflared

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tunnel-name)
                TUNNEL_NAME="$2"
                shift 2
                ;;
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --service)
                SERVICE_URL="$2"
                shift 2
                ;;
            --auto-deploy)
                AUTO_DEPLOY=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1\nUse --help for usage information."
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$HOSTNAME" ]; then
        error "Hostname is required. Use --hostname to specify it.\nExample: --hostname rccremote.example.com"
    fi
}

check_cloudflared() {
    log "Checking for cloudflared CLI..."
    
    if ! command -v cloudflared &> /dev/null; then
        error "cloudflared CLI not found. Please install it first:

Homebrew (macOS/Linux):
    brew install cloudflare/cloudflare/cloudflared

Universal Blue / Fedora Silverblue / Immutable distros:
    brew install cloudflared

Arch Linux / Manjaro:
    yay -S cloudflared-bin

Traditional Linux (Debian/Ubuntu):
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb

Fedora (traditional):
    sudo dnf install cloudflared

Or visit: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/"
    fi
    
    log "cloudflared found: $(cloudflared --version)"
}

authenticate_cloudflare() {
    log "Authenticating with Cloudflare..."
    info "A browser window will open for authentication."
    info "Please login to your Cloudflare account."
    echo ""
    
    if ! cloudflared tunnel login; then
        error "Authentication failed. Please try again."
    fi
    
    success "Authentication successful!"
}

check_existing_tunnel() {
    log "Checking for existing tunnel: $TUNNEL_NAME"
    
    if cloudflared tunnel list 2>/dev/null | grep -q "$TUNNEL_NAME"; then
        warn "Tunnel '$TUNNEL_NAME' already exists!"
        echo ""
        read -p "Do you want to use the existing tunnel? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Using existing tunnel: $TUNNEL_NAME"
            return 0
        else
            read -p "Enter a new tunnel name: " TUNNEL_NAME
            check_existing_tunnel
        fi
    fi
}

create_tunnel() {
    log "Creating Cloudflare Tunnel: $TUNNEL_NAME"
    
    if cloudflared tunnel create "$TUNNEL_NAME"; then
        success "Tunnel created successfully!"
    else
        error "Failed to create tunnel"
    fi
}

configure_dns() {
    log "Configuring DNS routing..."
    info "Hostname: $HOSTNAME"
    
    if cloudflared tunnel route dns "$TUNNEL_NAME" "$HOSTNAME"; then
        success "DNS configured successfully!"
    else
        warn "DNS configuration failed. You may need to configure it manually in the Cloudflare dashboard."
    fi
}

get_tunnel_info() {
    log "Retrieving tunnel information..."
    
    # Get tunnel UUID
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    
    if [ -z "$TUNNEL_ID" ]; then
        error "Could not find tunnel ID for $TUNNEL_NAME"
    fi
    
    info "Tunnel ID: $TUNNEL_ID"
}

create_config() {
    log "Creating tunnel configuration..."
    
    # Create config directory if it doesn't exist
    mkdir -p "$HOME/.cloudflared"
    
    # Create config file
    cat > "$HOME/.cloudflared/config.yml" << EOF
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $HOSTNAME
    service: $SERVICE_URL
  - service: http_status:404
EOF
    
    success "Configuration created at $HOME/.cloudflared/config.yml"
}

get_tunnel_token() {
    log "Generating tunnel token..."
    
    TUNNEL_TOKEN=$(cloudflared tunnel token "$TUNNEL_NAME" 2>/dev/null)
    
    if [ -z "$TUNNEL_TOKEN" ]; then
        error "Failed to generate tunnel token"
    fi
    
    success "Tunnel token generated!"
}

save_to_env() {
    log "Saving configuration to .env file..."
    
    ENV_FILE="$PROJECT_ROOT/.env"
    
    # Create or update .env file
    if [ -f "$ENV_FILE" ]; then
        # Backup existing .env
        cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%s)"
        warn "Backed up existing .env file"
    fi
    
    # Update or add CF_TUNNEL_TOKEN
    if grep -q "^CF_TUNNEL_TOKEN=" "$ENV_FILE" 2>/dev/null; then
        sed -i.bak "s|^CF_TUNNEL_TOKEN=.*|CF_TUNNEL_TOKEN=$TUNNEL_TOKEN|" "$ENV_FILE"
    else
        echo "" >> "$ENV_FILE"
        echo "# Cloudflare Tunnel Configuration" >> "$ENV_FILE"
        echo "CF_TUNNEL_TOKEN=$TUNNEL_TOKEN" >> "$ENV_FILE"
    fi
    
    # Update or add SERVER_NAME
    if grep -q "^SERVER_NAME=" "$ENV_FILE" 2>/dev/null; then
        sed -i.bak "s|^SERVER_NAME=.*|SERVER_NAME=$HOSTNAME|" "$ENV_FILE"
    else
        echo "SERVER_NAME=$HOSTNAME" >> "$ENV_FILE"
    fi
    
    success "Configuration saved to $ENV_FILE"
}

show_summary() {
    echo ""
    echo "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo "${CYAN}║          Cloudflare Tunnel Created Successfully!          ║${NC}"
    echo "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "${YELLOW}Tunnel Information:${NC}"
    echo "  Name:     $TUNNEL_NAME"
    echo "  ID:       $TUNNEL_ID"
    echo "  Hostname: $HOSTNAME"
    echo "  Service:  $SERVICE_URL"
    echo ""
    echo "${YELLOW}Configuration Files:${NC}"
    echo "  Config:      $HOME/.cloudflared/config.yml"
    echo "  Credentials: $HOME/.cloudflared/$TUNNEL_ID.json"
    echo "  .env file:   $PROJECT_ROOT/.env"
    echo ""
    echo "${YELLOW}Environment Variables:${NC}"
    echo "  CF_TUNNEL_TOKEN=$TUNNEL_TOKEN"
    echo "  SERVER_NAME=$HOSTNAME"
    echo ""
    echo "${YELLOW}Next Steps:${NC}"
    echo "  1. Deploy using Docker Compose:"
    echo "     ${BLUE}cd $PROJECT_ROOT${NC}"
    echo "     ${BLUE}make cf-up${NC}"
    echo ""
    echo "  2. Or deploy using the script:"
    echo "     ${BLUE}./scripts/deploy-cloudflare.sh${NC}"
    echo ""
    echo "  3. Configure RCC clients:"
    echo "     ${BLUE}export RCC_REMOTE_ORIGIN=https://$HOSTNAME${NC}"
    echo "     ${BLUE}rcc holotree catalogs${NC}"
    echo ""
    echo "${YELLOW}Useful Commands:${NC}"
    echo "  View tunnel status:"
    echo "     ${BLUE}cloudflared tunnel list${NC}"
    echo ""
    echo "  View tunnel info:"
    echo "     ${BLUE}cloudflared tunnel info $TUNNEL_NAME${NC}"
    echo ""
    echo "  Test locally (before Docker):"
    echo "     ${BLUE}cloudflared tunnel run $TUNNEL_NAME${NC}"
    echo ""
    echo "  Delete tunnel:"
    echo "     ${BLUE}cloudflared tunnel delete $TUNNEL_NAME${NC}"
    echo ""
    echo "${YELLOW}Cloudflare Dashboard:${NC}"
    echo "  https://one.dash.cloudflare.com/"
    echo ""
}

deploy_services() {
    log "Deploying services with Docker Compose..."
    
    export CF_TUNNEL_TOKEN="$TUNNEL_TOKEN"
    export SERVER_NAME="$HOSTNAME"
    
    cd "$PROJECT_ROOT"
    
    if command -v make &> /dev/null; then
        make cf-up
    else
        docker compose -f docker-compose/docker-compose.cloudflare.yml up -d
    fi
    
    success "Services deployed!"
}

main() {
    echo "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo "${CYAN}║     Cloudflare Tunnel Creator for RCC Remote              ║${NC}"
    echo "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    parse_args "$@"
    
    log "Starting Cloudflare Tunnel creation"
    info "Tunnel Name: $TUNNEL_NAME"
    info "Hostname: $HOSTNAME"
    info "Service: $SERVICE_URL"
    echo ""
    
    check_cloudflared
    authenticate_cloudflare
    check_existing_tunnel
    create_tunnel
    configure_dns
    get_tunnel_info
    create_config
    get_tunnel_token
    save_to_env
    show_summary
    
    if [ "$AUTO_DEPLOY" = true ]; then
        echo ""
        log "Auto-deploy enabled. Starting deployment..."
        deploy_services
    else
        echo ""
        read -p "Do you want to deploy now? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            deploy_services
        else
            info "Skipping deployment. Run 'make cf-up' when ready."
        fi
    fi
    
    success "Done!"
}

main "$@"
