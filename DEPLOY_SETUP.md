# Deploy Setup (Fresh DevPod -> Homelab)

This project is designed so DevPods can be ephemeral. Keep long-lived secrets and cert state on the homelab server.

Server target:

- Host: `10.10.10.106`
- User: `kdlocpanda`
- Domain: `admin.joshyorko.com`

## 0) Local Host Prep (before creating/recreating DevPod)

Make sure your SSH key can reach the homelab server from your local machine:

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

Then verify:

```bash
ssh homelab-rcc "echo host-ssh-config-ok"
```

## 1) DevPod Bootstrap (every new DevPod)

Make sure your SSH key is available in the DevPod and can reach the server:

```bash
ssh -o StrictHostKeyChecking=accept-new kdlocpanda@10.10.10.106 "echo ssh-ok"
```

If that fails, load your key in the DevPod:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

If your DevPod does not include your host key automatically, copy/mount your SSH private key into the DevPod before deploying.

Hook behavior in this repo:

- `.kamal/hooks/pre-connect` verifies SSH connectivity to all target hosts before commands run.
- `.kamal/hooks/docker-setup` installs `certbot` + Cloudflare DNS plugin during `kamal server bootstrap`.

## 2) One-time Server Bootstrap

Use Kamal to install/provision Docker on the target server.
This also runs `.kamal/hooks/docker-setup` in this repo, which:

- Adds the SSH user (`kdlocpanda`) to the `docker` group so it can access the Docker socket without `sudo`.
- Installs `certbot` + Cloudflare DNS plugin for TLS certificate management.

```bash
bin/kamal server bootstrap
```

> **Note:** The docker group change requires the SSH session to be refreshed.
> If you see `permission denied` errors on the Docker socket after bootstrap,
> log out and back in on the server, or run `newgrp docker` in the active session.

Optional cloud-init excerpt (if reprovisioning server):

```yaml
users:
  - name: kdlocpanda
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY
```

## 3) Add Cloudflare API Token (on server, not in repo)

Run these commands on the server (or via SSH command wrapper):

```bash
ssh kdlocpanda@10.10.10.106 "mkdir -p ~/.secrets/certbot && chmod 700 ~/.secrets/certbot"
ssh kdlocpanda@10.10.10.106 "cat > ~/.secrets/certbot/cloudflare.ini <<'EOF'
dns_cloudflare_api_token = isXnJJBtkPVaGY3CLRL5Ciu-tsZGKHxcnJPnyLJG
EOF"
ssh kdlocpanda@10.10.10.106 "chmod 600 ~/.secrets/certbot/cloudflare.ini"
```

Never commit real tokens.

## 4) Issue or Renew Let's Encrypt Cert (DNS-01)

```bash
ssh kdlocpanda@10.10.10.106 "certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
  --config-dir ~/.config/letsencrypt \
  --work-dir ~/.local/share/letsencrypt/work \
  --logs-dir ~/.local/share/letsencrypt/logs \
  --agree-tos -m joshua.yorko@gmail.com -n \
  -d admin.joshyorko.com"
```

The Kamal secrets in this repo already read certs from:

- `/home/kdlocpanda/.config/letsencrypt/live/admin.joshyorko.com/fullchain.pem`
- `/home/kdlocpanda/.config/letsencrypt/live/admin.joshyorko.com/privkey.pem`

## 5) Deploy from DevPod

```bash
bin/kamal server bootstrap
bin/kamal setup
bin/kamal deploy
```

## 6) Cloudflare DNS Notes

For private homelab access, use local/split DNS so:

- `admin.joshyorko.com -> 10.10.10.106` on your LAN resolver.

Because cert issuance is DNS-01, you do not need to expose ports `80/443` publicly for Let's Encrypt.

## 7) Optional: Rails Authentication Generator

Authentication has not been generated yet. To add it:

```bash
bin/rails generate authentication
bin/rails db:migrate
```
