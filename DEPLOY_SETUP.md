# Deploy Setup (Fresh DevPod -> Homelab)

This repo now deploys two services with Kamal:

- `admin.joshyorko.com` -> Rails admin/control-plane app
- `rccremote.joshyorko.com` -> dedicated `rccremote` daemon

Both services run on the same host and share robot/catalog/holotree storage.

Server target:

- Host: `10.10.10.106`
- User: `kdlocpanda`

## 0) Local Host Prep (before creating/recreating DevPod)

Make sure your SSH key can reach the homelab server:

```bash
ssh kdlocpanda@10.10.10.106 "echo host-ssh-ok"
```

Recommended SSH config on your local machine:

```sshconfig
Host homelab-rcc
  HostName 10.10.10.106
  User kdlocpanda
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

## 1) DevPod Bootstrap (every new DevPod)

```bash
ssh -o StrictHostKeyChecking=accept-new kdlocpanda@10.10.10.106 "echo ssh-ok"
```

If needed:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Hook behavior in this repo:

- `.kamal/hooks/pre-connect` verifies SSH connectivity to target hosts.
- `.kamal/hooks/docker-setup` adds the SSH user to `docker`, installs certbot tooling, and creates data directories under `~/rccremote-data`.

## 2) One-time Server Bootstrap

```bash
bin/kamal server bootstrap
```

If Docker group permissions do not apply immediately:

```bash
ssh kdlocpanda@10.10.10.106 "newgrp docker"
```

## 3) Add Cloudflare API Token (on server, not in repo)

```bash
ssh kdlocpanda@10.10.10.106 "mkdir -p ~/.secrets/certbot && chmod 700 ~/.secrets/certbot"
ssh kdlocpanda@10.10.10.106 "cat > ~/.secrets/certbot/cloudflare.ini <<'EOF'
dns_cloudflare_api_token = REPLACE_WITH_CLOUDFLARE_DNS_TOKEN
EOF"
ssh kdlocpanda@10.10.10.106 "chmod 600 ~/.secrets/certbot/cloudflare.ini"
```

Never commit real tokens.

## 4) Issue/Renew LetsEncrypt Cert (DNS-01, SAN)

Run on server:

```bash
ssh kdlocpanda@10.10.10.106 "certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
  --config-dir ~/.config/letsencrypt \
  --work-dir ~/.local/share/letsencrypt/work \
  --logs-dir ~/.local/share/letsencrypt/logs \
  --agree-tos -m joshua.yorko@gmail.com -n \
  --cert-name admin.joshyorko.com \
  --expand \
  -d admin.joshyorko.com \
  -d rccremote.joshyorko.com"
```

The shared Kamal TLS secrets in `.kamal/secrets` read from:

- `/home/kdlocpanda/.config/letsencrypt/live/admin.joshyorko.com/fullchain.pem`
- `/home/kdlocpanda/.config/letsencrypt/live/admin.joshyorko.com/privkey.pem`

## 5) DNS Notes

Cloudflare records should resolve to your homelab endpoint:

- `admin.joshyorko.com`
- `rccremote.joshyorko.com`

For private homelab access, use split DNS on LAN as needed.

## 6) Deploy (Admin + RCC Remote)

Deploy Rails admin app:

```bash
bin/kamal setup -c config/deploy.yml
bin/kamal deploy -c config/deploy.yml
```

Deploy `rccremote` daemon app:

```bash
bin/kamal setup -c config/deploy.rccremote.yml
bin/kamal deploy -c config/deploy.rccremote.yml
```

## 7) RCC Client Configuration

On client machines:

```bash
export RCC_REMOTE_ORIGIN=https://rccremote.joshyorko.com
rcc holotree catalogs
```

## 8) TLS Renewal Helper

From this repo (or on server):

```bash
script/renew_tls_cert.sh
```

Default behavior renews cert SANs for both domains (`admin` + `rccremote`).
