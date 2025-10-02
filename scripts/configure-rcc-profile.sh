#!/bin/bash

# Configure RCC profile with CA certificate for rccremote
# Usage: ./configure-rcc-profile.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${CERT_DIR:-$SCRIPT_DIR/../certs}"
CONFIG_DIR="${CONFIG_DIR:-$SCRIPT_DIR/../config}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

check_prerequisites() {
    if ! command -v rcc &> /dev/null; then
        error "rcc not found. Please install RCC first."
    fi
}

configure_ssl_profile() {
    log "Configuring RCC SSL profile..."
    
    if [ -f "$CERT_DIR/rootCA.pem" ]; then
        log "Root CA certificate found. Creating ssl-cabundle profile..."
        
        # Create temporary profile file
        local profile_file=$(mktemp)
        
        # Read the root CA content
        local root_ca_content=$(cat "$CERT_DIR/rootCA.pem")
        
        # Create the profile with ca-bundle
        cat > "$profile_file" << EOF
name: ssl-cabundle
description: SSL certificate verification with rootCA

settings: 
  certificates:
    verify-ssl: true
    ssl-no-revoke: false

  meta:
    name: ssl-cabundle
    description: SSL certificate verification with rootCA
    source: manual
    version: 2024.10

ca-bundle: |
EOF
        
        # Append the certificate content with proper indentation
        echo "$root_ca_content" | sed 's/^/  /' >> "$profile_file"
        
        # Import and switch to the profile
        rcc config import -f "$profile_file"
        rcc config switch -p ssl-cabundle
        
        rm -f "$profile_file"
        
        log "SSL profile configured successfully ✓"
        log "RCC will now use the custom CA certificate"
        
    else
        warn "Root CA certificate not found at $CERT_DIR/rootCA.pem"
        log "Creating ssl-noverify profile instead..."
        
        # Create temporary profile file
        local profile_file=$(mktemp)
        
        cat > "$profile_file" << 'EOF'
name: ssl-noverify
description: disabled SSL verification

settings: 
  certificates:
    verify-ssl: false
    ssl-no-revoke: false

  meta:
    name: ssl-noverify
    description: disabled SSL verification
    source: manual
    version: 2024.10
EOF
        
        rcc config import -f "$profile_file"
        rcc config switch -p ssl-noverify
        
        rm -f "$profile_file"
        
        warn "SSL verification disabled ✓"
        log "This is NOT recommended for production use"
    fi
}

show_current_config() {
    log "Current RCC configuration:"
    echo ""
    rcc config settings
}

main() {
    log "RCC Profile Configuration"
    log "=========================="
    
    check_prerequisites
    configure_ssl_profile
    
    echo ""
    log "Testing configuration..."
    show_current_config
    
    echo ""
    log "Configuration complete!"
    log "You can now use: export RCC_REMOTE_ORIGIN=https://rccremote.local:8443"
    log "And test with: rcc holotree vars"
}

main "$@"
