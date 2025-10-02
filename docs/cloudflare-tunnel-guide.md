# Cloudflare Tunnel Deployment Guide

## Overview

Deploy RCC Remote with Cloudflare Tunnel for production-ready SSL without certificate management.

**Benefits:**
- ✅ Trusted SSL certificates (Cloudflare's CA)
- ✅ No custom RCC SSL profile needed
- ✅ Access from anywhere (no port forwarding)
- ✅ Built-in DDoS protection and WAF
- ✅ Zero certificate management

## Prerequisites

1. **Cloudflare Account** with a domain (e.g., `joshyorko.com`)
2. **Cloudflare Zero Trust** access (free tier works)
3. **Docker and Docker Compose** installed

## Setup Steps

### 1. Create Cloudflare Tunnel

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Access** → **Tunnels**
3. Click **Create a tunnel**
4. Name it: `rccremote`
5. Choose **Docker** as the connector type
6. **Copy the tunnel token** (starts with `eyJ...`)

### 2. Configure Public Hostname

In the tunnel configuration:

1. **Public Hostname:**
   - Subdomain: `rccremote`
   - Domain: `joshyorko.com`
   - Path: (leave empty)

2. **Service:**
   - Type: `HTTP`
   - URL: `rccremote:4653`

3. **Save tunnel**

### 3. Set Environment Variables

Create a `.env` file in the project root:

```bash
# Cloudflare Tunnel Token (from step 1)
CF_TUNNEL_TOKEN=eyJhIjoiYjU2M...your-token-here

# Server name (must match Cloudflare tunnel hostname)
SERVER_NAME=rccremote.joshyorko.com
```

Or export directly:

```bash
export CF_TUNNEL_TOKEN="eyJhIjoiYjU2M...your-token-here"
export SERVER_NAME="rccremote.joshyorko.com"
```

### 4. Deploy

```bash
cd /path/to/rccremote-docker
docker compose -f examples/docker-compose.cloudflare.yml up -d
```

### 5. Verify Deployment

Check service health:

```bash
docker compose -f examples/docker-compose.cloudflare.yml ps
docker logs rccremote-cloudflared
```

Test connectivity:

```bash
curl -I https://rccremote.joshyorko.com
```

## Client Configuration

### Simple Setup (No Custom SSL Profile Needed!)

Since Cloudflare uses a trusted CA, clients don't need custom SSL configuration:

```bash
# Set environment variables
export RCC_REMOTE_ORIGIN=https://rccremote.joshyorko.com
export ROBOCORP_HOME=/opt/robocorp

# Create the directory if it doesn't exist
sudo mkdir -p /opt/robocorp
sudo chown -R $USER:$USER /opt/robocorp

# Enable shared holotree
rcc holotree shared --enable

# Test
rcc holotree vars
```

That's it! No certificate installation, no custom profiles needed.

### Optional: Add to Shell Profile

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export RCC_REMOTE_ORIGIN=https://rccremote.joshyorko.com
export ROBOCORP_HOME=/opt/robocorp
```

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│             │         │              │         │             │
│  RCC Client │ HTTPS   │  Cloudflare  │  HTTP   │  rccremote  │
│             │────────▶│   Tunnel     │────────▶│  :4653      │
│             │         │ (SSL Term)   │         │             │
└─────────────┘         └──────────────┘         └─────────────┘
                                │
                        Cloudflare's Trusted CA
                        (no custom certs!)
```

## Managing the Deployment

### View Logs

```bash
# All services
docker compose -f examples/docker-compose.cloudflare.yml logs -f

# RCC Remote only
docker logs rccremote-cf -f

# Cloudflared only
docker logs rccremote-cloudflared -f
```

### Stop Services

```bash
docker compose -f examples/docker-compose.cloudflare.yml down
```

### Update and Restart

```bash
docker compose -f examples/docker-compose.cloudflare.yml pull
docker compose -f examples/docker-compose.cloudflare.yml up -d
```

## Troubleshooting

### Tunnel Not Connecting

Check cloudflared logs:

```bash
docker logs rccremote-cloudflared
```

Common issues:
- Invalid tunnel token
- Tunnel not started in Cloudflare dashboard
- Network connectivity issues

### RCC Client Can't Connect

1. Verify tunnel is active in Cloudflare dashboard
2. Check DNS resolution:
   ```bash
   nslookup rccremote.joshyorko.com
   ```
3. Test HTTPS connectivity:
   ```bash
   curl -v https://rccremote.joshyorko.com
   ```

### Catalog Path Mismatch

If you see "Could not get lock" or path-related errors:

```bash
# Ensure ROBOCORP_HOME matches the server
export ROBOCORP_HOME=/opt/robocorp

# Create and own the directory
sudo mkdir -p /opt/robocorp
sudo chown -R $USER:$USER /opt/robocorp

# Enable shared holotree
rcc holotree shared --enable
```

## Advanced Configuration

### Custom Robot Paths

To build catalogs for different target systems, create `.env` files in robot directories:

**Example: `data/robots/production-bot/.env`**
```bash
ROBOCORP_HOME=/opt/robocorp
```

**Example: `data/robots/robotmk-bot/.env`**
```bash
ROBOCORP_HOME=/robotmk/rcc_home/user1
```

### Multiple Environments

You can run multiple RCC Remote instances with different Cloudflare tunnels:

1. Create additional tunnels in Cloudflare (e.g., `rccremote-dev.joshyorko.com`, `rccremote-prod.joshyorko.com`)
2. Copy and modify the docker-compose file with different container names
3. Use different tunnel tokens for each environment

### Access Control

Use Cloudflare Access to restrict who can connect:

1. Go to **Access** → **Applications** in Cloudflare Zero Trust
2. Create a new application for `rccremote.joshyorko.com`
3. Add access policies (e.g., require email domain, IP ranges)

## Production Recommendations

1. **Use separate tunnel tokens** for dev/staging/production
2. **Enable Cloudflare WAF** rules for additional security
3. **Monitor tunnel health** via Cloudflare dashboard
4. **Set up alerts** for tunnel downtime
5. **Use Cloudflare Analytics** to monitor usage
6. **Enable rate limiting** to prevent abuse
7. **Backup catalog volumes** regularly

## Cost

- **Cloudflare Tunnel**: Free (included in Free tier)
- **Cloudflare Zero Trust**: Free tier supports up to 50 users
- **No certificate costs**: Cloudflare handles SSL for free

## Security Notes

- Traffic between Cloudflare and your server uses Cloudflare's secure tunnel
- Internal traffic (cloudflared → rccremote) is HTTP but isolated in Docker network
- For additional security, you can still enable mTLS between cloudflared and rccremote
- Cloudflare provides DDoS protection automatically

## Next Steps

- Review [Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- Set up [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/) for authentication
- Configure [WAF rules](https://developers.cloudflare.com/waf/) for your domain
