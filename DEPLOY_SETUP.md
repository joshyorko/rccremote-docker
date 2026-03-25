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
- `.kamal/hooks/docker-setup` adds the SSH user to `docker` and creates data directories under `~/rccremote-data`.

## 2) One-time Server Bootstrap

```bash
bin/kamal server bootstrap
```

If Docker group permissions do not apply immediately:

```bash
ssh kdlocpanda@10.10.10.106 "newgrp docker"
```

## 3) Prepare Local Deploy Secrets

Create `.env.kamal.local` in this repo with:

```bash
cat > .env.kamal.local <<'EOF'
S3_ACCESS_KEY_ID=REPLACE_ME
S3_SECRET_ACCESS_KEY=REPLACE_ME
ADMIN_CLOUDFLARED_TOKEN=REPLACE_ME
RCCREMOTE_CLOUDFLARED_TOKEN=REPLACE_ME
EOF
```

`.kamal/secrets` reads these values at deploy time. Never commit raw secrets.

## 4) Cloudflare Tunnel Notes

Each deployment uses its own `cloudflared` accessory:

- `config/deploy.yml` -> `admin.joshyorko.com`
- `config/deploy.rccremote.yml` -> `rccremote.joshyorko.com`

Create the tunnel tokens in Cloudflare and place them in `.env.kamal.local` as:

- `ADMIN_CLOUDFLARED_TOKEN`
- `RCCREMOTE_CLOUDFLARED_TOKEN`

## 5) DNS Notes

Cloudflare Tunnel should front both hostnames:

- `admin.joshyorko.com`
- `rccremote.joshyorko.com`

Kamal proxy listens only on `127.0.0.1` and `cloudflared` is the public edge.

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

Both deployments use:

- host-path storage under `~/rccremote-data`
- S3-compatible Active Storage at `10.10.40.56:9000`
- Litestream replication for all production SQLite databases

## 7) RCC Client Configuration

On client machines:

```bash
export RCC_REMOTE_ORIGIN=https://rccremote.joshyorko.com
rcc holotree catalogs
```

## 8) Notes

The previous certbot-based TLS flow is obsolete for this branch. Public TLS is handled by Cloudflare Tunnel rather than locally managed LetsEncrypt certificates.
