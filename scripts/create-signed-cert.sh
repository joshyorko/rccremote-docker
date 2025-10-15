#!/bin/bash
set -euo pipefail

# This script is only for demonstration purposes of how to create the server certificate.
# The script determines its own location so it can be run from the repository root or
# the scripts folder.

# Determine script and repository root directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CERT_DIR="$ROOT_DIR/certs"
OPENSSL_TPL="$SCRIPT_DIR/openssl.cnf.template"

# if SERVER_NAME is not set in environment, read from .env
if [ -z "${SERVER_NAME:-}" ]; then
    if [ -f "$ROOT_DIR/.env" ]; then
        # shellcheck disable=SC1090
        source "$ROOT_DIR/.env"
        export SERVER_NAME
        echo "SERVER_NAME is set to $SERVER_NAME in .env file."
    else
        echo "SERVER_NAME is not set in environment or .env file."
        exit 1
    fi
else
    echo "SERVER_NAME is set to $SERVER_NAME in environment variable."
fi

mkdir -p $CERT_DIR

# create temporary openssl config file and use envsubst to replace the SERVER_NAME
OPENSSL_CONF="$(mktemp)"
envsubst '$SERVER_NAME' <"${OPENSSL_TPL}" >"${OPENSSL_CONF}"

if grep -q $SERVER_NAME $OPENSSL_CONF; then
    echo "Openssl configuration created successfully with server name $SERVER_NAME ($OPENSSL_CONF)."
else
    echo "Server name $SERVER_NAME not found in the openssl config file ($OPENSSL_CONF). Exiting..."
    exit 1
fi

# remove all crt/key/pem/csr files in the CERT_DIR after prompting the user
echo "Ready to generate the certificates now. This will empty the cert dir $CERT_DIR."
read -p "=> Are you sure? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$CERT_DIR"/*.{crt,key,pem,csr} || true
fi

echo ""

# 1. create a root CA certificate & key
echo "1. Creating a root CA certificate & key..."
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
    -keyout "$CERT_DIR/rootCA.key" \
    -out "$CERT_DIR/rootCA.crt" \
    -subj "/C=US/ST=State/L=City/O=YourOrg/OU=YourUnit/CN=RootCA"

# 2. Create a certificate bundle from the root certificate
echo "2. Creating a certificate bundle from the root certificate..."
openssl x509 -in "$CERT_DIR/rootCA.crt" -out "$CERT_DIR/rootCA.pem" -outform PEM

# 3. Generate the Server’s Private Key and Certificate Signing Request (CSR)
echo "3. Generating the Server’s Private Key and Certificate Signing Request (CSR)..."
openssl req -new -nodes -newkey rsa:2048 \
    -keyout "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.csr" \
    -config "$OPENSSL_CONF" \
    -subj "/C=US/ST=State/L=City/O=YourOrg/OU=YourUnit/CN=$SERVER_NAME"

# 4. Sign the Server Certificate with the Root Certificate
echo "4. Signing the Server Certificate with the Root Certificate..."
openssl x509 -req -days 3650 -in "$CERT_DIR/server.csr" \
    -CA "$CERT_DIR/rootCA.crt" -CAkey "$CERT_DIR/rootCA.key" -CAcreateserial \
    -out "$CERT_DIR/server.crt" -extensions v3_req -extfile "$OPENSSL_CONF"

echo "==== Server certificate created successfully ===="
echo "Root CA certificate: $CERT_DIR/rootCA.crt"
echo "Root CA certificate bundle: $CERT_DIR/rootCA.pem"
echo "Server certificate: $CERT_DIR/server.crt"
echo "Server private key: $CERT_DIR/server.key"
echo "Server certificate details:"
openssl x509 -in $CERT_DIR/server.crt -text -noout
