# Deploy Setup (Fresh DevPod -> Homelab)

This project is designed so DevPods can be ephemeral. Keep long-lived secrets and cert state on the homelab server.

Server target:
- Host: `10.10.10.106`
- User: `kdlocpanda`
- Domain: `admin.joshyorko.com`

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

## 2) One-time Server Bootstrap

Install Docker + certbot DNS plugin on the server:

```bash
ssh kdlocpanda@10.10.10.106 "sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io certbot python3-certbot-dns-cloudflare"
```

## 3) Add Cloudflare API Token (on server, not in repo)

Run these commands on the server (or via SSH command wrapper):

```bash
ssh kdlocpanda@10.10.10.106 "mkdir -p ~/.secrets/certbot && chmod 700 ~/.secrets/certbot"
ssh kdlocpanda@10.10.10.106 "cat > ~/.secrets/certbot/cloudflare.ini <<'EOF'
dns_cloudflare_api_token = REPLACE_WITH_CLOUDFLARE_DNS_EDIT_TOKEN
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
