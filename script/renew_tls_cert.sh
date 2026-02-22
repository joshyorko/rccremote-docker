#!/usr/bin/env bash
set -euo pipefail

# Renews/creates a Let's Encrypt certificate through Cloudflare DNS-01
# and reloads the Kamal proxy with updated PEM values.
#
# Usage:
#   script/renew_tls_cert.sh [domain ...]
#
# Required:
#   CLOUDFLARE_CREDENTIALS_FILE -> path to certbot cloudflare ini file
#   LETSENCRYPT_EMAIL           -> ACME account email
#
# Optional:
#   DNS_PROPAGATION_SECONDS     -> default 30
#   RELOAD_PROXY                -> 1 (default) to run `bin/kamal proxy reboot`

if [ "$#" -gt 0 ]; then
  DOMAINS=("$@")
else
  DOMAINS=("admin.joshyorko.com" "rccremote.joshyorko.com")
fi

PRIMARY_DOMAIN="${DOMAINS[0]}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-joshua.yorko@gmail.com}"
CLOUDFLARE_CREDENTIALS_FILE="${CLOUDFLARE_CREDENTIALS_FILE:-$HOME/.secrets/certbot/cloudflare.ini}"
DNS_PROPAGATION_SECONDS="${DNS_PROPAGATION_SECONDS:-30}"
RELOAD_PROXY="${RELOAD_PROXY:-1}"
CERTBOT_CONFIG_DIR="${CERTBOT_CONFIG_DIR:-$HOME/.config/letsencrypt}"
CERTBOT_WORK_DIR="${CERTBOT_WORK_DIR:-$HOME/.local/share/letsencrypt/work}"
CERTBOT_LOGS_DIR="${CERTBOT_LOGS_DIR:-$HOME/.local/share/letsencrypt/logs}"
CERT_LIVE_DIR="${CERTBOT_CONFIG_DIR}/live/${PRIMARY_DOMAIN}"

if ! command -v certbot >/dev/null 2>&1; then
  echo "certbot is not installed. Install certbot + dns-cloudflare plugin first." >&2
  exit 1
fi

if [ ! -f "$CLOUDFLARE_CREDENTIALS_FILE" ]; then
  echo "Missing Cloudflare credentials file: $CLOUDFLARE_CREDENTIALS_FILE" >&2
  exit 1
fi

chmod 600 "$CLOUDFLARE_CREDENTIALS_FILE"
certbot_args=()
for domain in "${DOMAINS[@]}"; do
  certbot_args+=(-d "$domain")
done

certbot certonly \
  --non-interactive \
  --agree-tos \
  --keep-until-expiring \
  --cert-name "$PRIMARY_DOMAIN" \
  --expand \
  --config-dir "$CERTBOT_CONFIG_DIR" \
  --work-dir "$CERTBOT_WORK_DIR" \
  --logs-dir "$CERTBOT_LOGS_DIR" \
  --email "$LETSENCRYPT_EMAIL" \
  --dns-cloudflare \
  --dns-cloudflare-credentials "$CLOUDFLARE_CREDENTIALS_FILE" \
  --dns-cloudflare-propagation-seconds "$DNS_PROPAGATION_SECONDS" \
  "${certbot_args[@]}"

if [ ! -f "$CERT_LIVE_DIR/fullchain.pem" ] || [ ! -f "$CERT_LIVE_DIR/privkey.pem" ]; then
  echo "Expected certificate files are missing in $CERT_LIVE_DIR" >&2
  exit 1
fi

if ! grep -q '^KAMAL_SSL_CERTIFICATE_PEM=' .kamal/secrets; then
  cat >&2 <<EOF
Missing KAMAL SSL secret lines in .kamal/secrets.
Add these exact lines:
KAMAL_SSL_CERTIFICATE_PEM=\$(cat $CERT_LIVE_DIR/fullchain.pem)
KAMAL_SSL_PRIVATE_KEY_PEM=\$(cat $CERT_LIVE_DIR/privkey.pem)
EOF
  exit 1
fi

if [ "$RELOAD_PROXY" = "1" ]; then
  bin/kamal proxy reboot
  echo "Kamal proxy reloaded with updated TLS material for ${DOMAINS[*]}"
else
  echo "Certificate ready for ${DOMAINS[*]}. Run: bin/kamal proxy reboot"
fi
