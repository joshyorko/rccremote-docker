# Quick Start: Cloudflare Tunnel with CLI

## TL;DR - Get Running in 2 Minutes

```bash
# 1. Install cloudflared (one-time, works on Universal Blue/Bluefin)
brew install cloudflare/cloudflare/cloudflared

# 2. Create tunnel and deploy (one command!)
make quick-cf HOSTNAME=rccremote.example.com

# 3. Configure RCC client (no SSL profile needed!)
export RCC_REMOTE_ORIGIN=https://rccremote.example.com

# 4. Test
rcc holotree catalogs
```

Done! Your RCC Remote is now accessible from anywhere with trusted SSL.

## What Just Happened?

The `make quick-cf` command:
1. ✅ Authenticated you with Cloudflare (browser popup)
2. ✅ Created a tunnel named "rccremote"
3. ✅ Configured DNS (CNAME: rccremote.example.com → tunnel)
4. ✅ Generated and saved the tunnel token to `.env`
5. ✅ Started the Docker containers
6. ✅ Connected the tunnel to your RCC Remote service

## For Universal Blue / Bluefin Users

Perfect! Homebrew is the recommended way:

```bash
# Install cloudflared
brew install cloudflare/cloudflare/cloudflared

# Verify installation
cloudflared --version

# Create tunnel
make quick-cf HOSTNAME=rccremote.yourdomain.com
```

No `sudo` needed, no system packages, just works! ✨

## Managing Your Tunnel

```bash
# List all tunnels
make cf-tunnel-list

# Get tunnel details
make cf-tunnel-info TUNNEL_NAME=rccremote

# View logs
make cf-logs

# Stop
make cf-down

# Delete tunnel
make cf-tunnel-delete TUNNEL_NAME=rccremote
```

## Multiple Environments

```bash
# Development
make cf-create HOSTNAME=rccremote-dev.example.com TUNNEL_NAME=rcc-dev

# Production
make cf-create HOSTNAME=rccremote.example.com TUNNEL_NAME=rcc-prod

# Switch between them by changing .env or using CF_TUNNEL_TOKEN
```

## Troubleshooting

**Browser didn't open for auth?**
```bash
cloudflared tunnel login
```

**Tunnel exists already?**
The script will prompt you to use existing or create with new name.

**Need to recreate?**
```bash
make cf-tunnel-delete TUNNEL_NAME=rccremote
make cf-create HOSTNAME=rccremote.example.com
```

**Want manual control?**
```bash
# Create without auto-deploy
make cf-create HOSTNAME=rccremote.example.com

# Deploy later
make cf-up
```

## Why This is Better Than Manual Setup

| Manual UI Method | CLI Method (`make quick-cf`) |
|-----------------|---------------------------|
| 10 minutes | 2 minutes |
| Click through dashboard | One command |
| Copy/paste token | Auto-saved to .env |
| Manual DNS config | Auto-configured |
| Hard to automate | CI/CD ready |

## Cost

**$0** - Cloudflare Tunnel is free (included in free tier)

## Next Steps

- Add to CI/CD pipeline
- Set up multiple environments
- Configure Cloudflare Access for authentication
- Enable WAF rules for security

## Need Help?

```bash
make help                    # See all commands
./scripts/create-cloudflare-tunnel.sh --help  # Script help
```

Or check the full docs:
- `docs/CLOUDFLARE_CLI_INTEGRATION.md` - Detailed guide
- `MAKEFILE.md` - All Makefile commands
- `docs/cloudflare-tunnel-guide.md` - Cloudflare specifics
