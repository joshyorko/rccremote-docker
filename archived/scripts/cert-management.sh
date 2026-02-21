#!/bin/bash

# Enhanced certificate management script for RCC Remote
# Usage: ./cert-management.sh [command] [options]

set -e

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
CERT_DIR="${CERT_DIR:-$SCRIPT_DIR/../certs}"
SERVER_NAME="${SERVER_NAME:-rccremote.local}"
VALIDITY_DAYS="${VALIDITY_DAYS:-365}"
KEY_SIZE="${KEY_SIZE:-2048}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-pem}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    generate-selfsigned        Generate self-signed certificate
    generate-ca-signed         Generate CA-signed certificate
    validate                   Validate existing certificates
    renew                      Renew expiring certificates
    info                       Show certificate information
    export                     Export certificates for clients
    clean                      Remove all certificates

Options:
    -d, --cert-dir DIR         Certificate directory (default: ../certs)
    -s, --server-name NAME     Server name/CN (default: rccremote.local)
    -v, --validity DAYS        Certificate validity in days (default: 365)
    -k, --key-size BITS        RSA key size (default: 2048)
    -f, --format FORMAT        Output format: pem, der (default: pem)
    -h, --help                 Display this help message

Examples:
    # Generate self-signed certificate
    $0 generate-selfsigned --server-name rccremote.example.com

    # Generate CA-signed certificate
    $0 generate-ca-signed --validity 730

    # Validate existing certificates
    $0 validate

    # Show certificate info
    $0 info

    # Export CA for clients
    $0 export
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

# Parse global options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--cert-dir)
                CERT_DIR="$2"
                shift 2
                ;;
            -s|--server-name)
                SERVER_NAME="$2"
                shift 2
                ;;
            -v|--validity)
                VALIDITY_DAYS="$2"
                shift 2
                ;;
            -k|--key-size)
                KEY_SIZE="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                break
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    if ! command -v openssl &> /dev/null; then
        error "openssl not found. Please install OpenSSL first."
    fi
    
    mkdir -p "$CERT_DIR"
}

# Generate self-signed certificate
generate_selfsigned() {
    log "Generating self-signed certificate for $SERVER_NAME"
    
    check_prerequisites
    
    # Create OpenSSL configuration
    local config=$(mktemp)
    cat > "$config" << EOF
[req]
default_bits = $KEY_SIZE
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = US
ST = State
L = City
O = RCCRemote
OU = DevOps
CN = $SERVER_NAME

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = $SERVER_NAME
DNS.2 = *.$SERVER_NAME
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF
    
    # Generate private key
    log "Generating private key..."
    openssl genrsa -out "$CERT_DIR/server.key" $KEY_SIZE 2>/dev/null
    chmod 600 "$CERT_DIR/server.key"
    
    # Generate self-signed certificate
    log "Generating self-signed certificate..."
    openssl req -new -x509 \
        -key "$CERT_DIR/server.key" \
        -out "$CERT_DIR/server.crt" \
        -days $VALIDITY_DAYS \
        -config "$config"
    
    # Copy as root CA for clients
    cp "$CERT_DIR/server.crt" "$CERT_DIR/rootCA.pem"
    
    rm -f "$config"
    
    log "Self-signed certificate generated successfully ✓"
    show_cert_info "$CERT_DIR/server.crt"
}

# Generate CA-signed certificate
generate_ca_signed() {
    log "Generating CA-signed certificate for $SERVER_NAME"
    
    check_prerequisites
    
    # Create OpenSSL configuration
    local config=$(mktemp)
    cat > "$config" << EOF
[req]
default_bits = $KEY_SIZE
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = US
ST = State
L = City
O = RCCRemote
OU = DevOps
CN = $SERVER_NAME

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = $SERVER_NAME
DNS.2 = *.$SERVER_NAME
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF
    
    # Generate Root CA if it doesn't exist
    if [ ! -f "$CERT_DIR/rootCA.key" ]; then
        log "Generating Root CA..."
        openssl genrsa -out "$CERT_DIR/rootCA.key" 4096 2>/dev/null
        chmod 600 "$CERT_DIR/rootCA.key"
        
        openssl req -x509 -new -nodes \
            -key "$CERT_DIR/rootCA.key" \
            -sha256 \
            -days $((VALIDITY_DAYS * 2)) \
            -out "$CERT_DIR/rootCA.crt" \
            -subj "/C=US/ST=State/L=City/O=RCCRemote/OU=CA/CN=RCCRemote Root CA"
        
        # Create PEM bundle
        cp "$CERT_DIR/rootCA.crt" "$CERT_DIR/rootCA.pem"
        
        log "Root CA generated ✓"
    else
        log "Using existing Root CA"
    fi
    
    # Generate server private key
    log "Generating server private key..."
    openssl genrsa -out "$CERT_DIR/server.key" $KEY_SIZE 2>/dev/null
    chmod 600 "$CERT_DIR/server.key"
    
    # Generate CSR
    log "Generating certificate signing request..."
    openssl req -new \
        -key "$CERT_DIR/server.key" \
        -out "$CERT_DIR/server.csr" \
        -config "$config"
    
    # Sign with Root CA
    log "Signing certificate with Root CA..."
    openssl x509 -req \
        -in "$CERT_DIR/server.csr" \
        -CA "$CERT_DIR/rootCA.crt" \
        -CAkey "$CERT_DIR/rootCA.key" \
        -CAcreateserial \
        -out "$CERT_DIR/server.crt" \
        -days $VALIDITY_DAYS \
        -extensions v3_req \
        -extfile "$config"
    
    rm -f "$config" "$CERT_DIR/server.csr"
    
    log "CA-signed certificate generated successfully ✓"
    show_cert_info "$CERT_DIR/server.crt"
}

# Validate certificates
validate_certs() {
    log "Validating certificates in $CERT_DIR"
    
    local valid=true
    
    # Check if required files exist
    if [ ! -f "$CERT_DIR/server.crt" ]; then
        error "server.crt not found"
        valid=false
    fi
    
    if [ ! -f "$CERT_DIR/server.key" ]; then
        error "server.key not found"
        valid=false
    fi
    
    if [ "$valid" = "false" ]; then
        return 1
    fi
    
    # Validate certificate format
    if ! openssl x509 -in "$CERT_DIR/server.crt" -noout 2>/dev/null; then
        error "Invalid certificate format"
        valid=false
    fi
    
    # Validate key format
    if ! openssl rsa -in "$CERT_DIR/server.key" -check -noout 2>/dev/null; then
        error "Invalid private key format"
        valid=false
    fi
    
    # Check if certificate and key match
    local cert_modulus=$(openssl x509 -noout -modulus -in "$CERT_DIR/server.crt" 2>/dev/null | openssl md5)
    local key_modulus=$(openssl rsa -noout -modulus -in "$CERT_DIR/server.key" 2>/dev/null | openssl md5)
    
    if [ "$cert_modulus" != "$key_modulus" ]; then
        error "Certificate and key do not match"
        valid=false
    fi
    
    # Check expiration
    local expiry=$(openssl x509 -in "$CERT_DIR/server.crt" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    
    if [ $days_left -lt 0 ]; then
        error "Certificate has expired"
        valid=false
    elif [ $days_left -lt 30 ]; then
        warn "Certificate expires in $days_left days"
    else
        log "Certificate is valid for $days_left more days ✓"
    fi
    
    if [ "$valid" = "true" ]; then
        log "All certificate validations passed ✓"
        return 0
    else
        return 1
    fi
}

# Show certificate information
show_cert_info() {
    local cert_file="${1:-$CERT_DIR/server.crt}"
    
    if [ ! -f "$cert_file" ]; then
        error "Certificate not found: $cert_file"
    fi
    
    echo ""
    echo "=== Certificate Information ==="
    openssl x509 -in "$cert_file" -noout -subject -issuer -dates
    echo ""
    echo "=== Subject Alternative Names ==="
    openssl x509 -in "$cert_file" -noout -ext subjectAltName
    echo ""
}

# Renew certificates
renew_certs() {
    log "Renewing certificates..."
    
    # Backup old certificates
    if [ -f "$CERT_DIR/server.crt" ]; then
        local backup_dir="$CERT_DIR/backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        cp "$CERT_DIR"/*.{crt,key,pem} "$backup_dir/" 2>/dev/null || true
        log "Old certificates backed up to $backup_dir"
    fi
    
    # Check if we have a CA
    if [ -f "$CERT_DIR/rootCA.key" ] && [ -f "$CERT_DIR/rootCA.crt" ]; then
        generate_ca_signed
    else
        generate_selfsigned
    fi
}

# Export certificates for clients
export_certs() {
    log "Exporting certificates for clients..."
    
    local export_dir="$CERT_DIR/client-export"
    mkdir -p "$export_dir"
    
    # Copy CA certificate
    if [ -f "$CERT_DIR/rootCA.pem" ]; then
        cp "$CERT_DIR/rootCA.pem" "$export_dir/"
        log "Exported rootCA.pem to $export_dir/"
    fi
    
    if [ -f "$CERT_DIR/rootCA.crt" ]; then
        cp "$CERT_DIR/rootCA.crt" "$export_dir/"
        log "Exported rootCA.crt to $export_dir/"
    fi
    
    # Create README
    cat > "$export_dir/README.md" << EOF
# RCC Remote Client Certificates

## Files

- \`rootCA.pem\` - Root CA certificate in PEM format (for RCC profile configuration)
- \`rootCA.crt\` - Root CA certificate in CRT format (for system trust stores)

## Usage with RCC

1. Copy \`rootCA.pem\` to your RCC client machine
2. Configure RCC profile:

\`\`\`yaml
profiles:
  rccremote:
    description: RCC Remote with SSL verification
    settings:
      verify-ssl: true
      ca-bundle: |
$(cat "$CERT_DIR/rootCA.pem" | sed 's/^/        /')
\`\`\`

3. Import and activate profile:

\`\`\`bash
rcc config import -f rcc-profile.yaml
rcc config switch -p rccremote
\`\`\`

## System Trust Store Installation

### Linux
\`\`\`bash
sudo cp rootCA.crt /usr/local/share/ca-certificates/rccremote-ca.crt
sudo update-ca-certificates
\`\`\`

### macOS
\`\`\`bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.crt
\`\`\`

### Windows
\`\`\`powershell
certutil -addstore -f "ROOT" rootCA.crt
\`\`\`
EOF
    
    log "Client certificates exported to $export_dir/ ✓"
    log "See $export_dir/README.md for usage instructions"
}

# Clean certificates
clean_certs() {
    log "Cleaning certificates in $CERT_DIR"
    
    read -p "This will remove all certificates. Are you sure? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$CERT_DIR"/*.{crt,key,pem,csr,srl}
        log "All certificates removed ✓"
    else
        log "Operation cancelled"
    fi
}

# Main function
main() {
    if [ $# -lt 1 ]; then
        usage
    fi
    
    local command=$1
    shift
    
    parse_options "$@"
    
    case $command in
        generate-selfsigned)
            generate_selfsigned
            ;;
        generate-ca-signed)
            generate_ca_signed
            ;;
        validate)
            validate_certs
            ;;
        renew)
            renew_certs
            ;;
        info)
            show_cert_info
            ;;
        export)
            export_certs
            ;;
        clean)
            clean_certs
            ;;
        *)
            error "Unknown command: $command. Use --help for usage information."
            ;;
    esac
}

# Run main function
main "$@"
