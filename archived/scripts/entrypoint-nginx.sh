#!/bin/sh

CERT_DIR=/etc/nginx/certs

# Check if the certificate and key already exist
if [ ! -f "$CERT_DIR/server.crt" ] || [ ! -f "$CERT_DIR/server.key" ]; then
    OPENSSL_TPL=/openssl.cnf.template
    OPENSSL_CONF=$(mktemp)
    envsubst '$SERVER_NAME' <${OPENSSL_TPL} >${OPENSSL_CONF}
    echo "Generated openssl config file $OPENSSL_CONF with server name $SERVER_NAME"
    echo "Generating self-signed certificate for $SERVER_NAME..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_DIR/server.key" \
        -out "$CERT_DIR/server.crt" \
        -config "$OPENSSL_CONF" \
        -subj "/C=US/ST=State/L=City/O=YourOrg/OU=YourUnit/CN=$SERVER_NAME"
else
    echo "Server certificate and key already exist."
fi

# Substitute environment variables in nginx.conf
#envsubst '$NGINX_PORT' </etc/nginx/nginx.conf.template >/etc/nginx/nginx.conf

# Start nginx
#nginx -g 'daemon off;'
