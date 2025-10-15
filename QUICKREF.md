# RCC Remote Docker - Quick Reference Card

## 🚀 Quick Start

```bash
# Development (one command)
make quick-dev

# Production
make quick-prod SERVER_NAME=your-domain.com

# Kubernetes
make quick-k8s
```

## 📦 Common Commands

### Development
```bash
make dev-up              # Start
make dev-down            # Stop
make dev-logs            # View logs
make dev-restart         # Restart
make dev-clean           # Clean (remove volumes)
make dev-shell-rccremote # Shell into container
```

### Production
```bash
make prod-up SERVER_NAME=your-domain.com
make prod-down
make prod-logs
make prod-restart SERVER_NAME=your-domain.com
make prod-clean
make prod-shell-rccremote
```

### Cloudflare Tunnel
```bash
# Create tunnel programmatically
make cf-create HOSTNAME=rccremote.example.com

# Create and auto-deploy
make cf-create-deploy HOSTNAME=rccremote.example.com

# List all tunnels
make cf-tunnel-list

# Get tunnel info
make cf-tunnel-info TUNNEL_NAME=rccremote

# Delete tunnel
make cf-tunnel-delete TUNNEL_NAME=rccremote

# Deploy with existing token
make cf-up CF_TUNNEL_TOKEN=your_token
make cf-down
make cf-logs
make cf-restart
make cf-clean
```

### Kubernetes
```bash
make k8s-deploy          # Deploy (3 replicas)
make k8s-deploy NAMESPACE=prod REPLICAS=5
make k8s-status          # Check status
make k8s-logs            # View logs
make k8s-shell           # Shell into pod
make k8s-port-forward    # Port forward to localhost:8443
make k8s-delete          # Delete all resources
make k8s-uninstall       # Full uninstall (namespace + all resources)
```

## 🔐 Certificates

```bash
make certs-generate      # Self-signed (dev)
make certs-signed        # CA-signed (prod)
make certs-manage        # Interactive management
make certs-clean         # Remove all certs
```

## 🔧 Client Setup

```bash
make client-configure    # Configure RCC profile
make client-setup-dev    # Setup for dev + add to shell
make client-setup-prod SERVER_NAME=your-domain.com
```

Then add to shell:
```bash
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443  # Dev
export RCC_REMOTE_ORIGIN=https://your-domain.com       # Prod
```

## 🧪 Testing

```bash
make test-health         # Health check
make test-connectivity   # RCC connectivity
make test-integration    # Integration tests
make test-all           # All tests
```

## 🛠️ Build & Maintenance

```bash
make build              # Build images
make build-tag          # Build and tag for registry
make push               # Build, tag and push to registry
make pull               # Pull from registry
make registry-login     # Login to Docker registry

make build-dev          # Build dev
make build-prod         # Build prod

make logs               # Auto-detect environment
make ps                 # Show containers/pods
make shell              # Shell (auto-detect)

make uninstall          # Uninstall (auto-detect environment)
make clean              # Clean all deployments
make clean-all          # Clean + remove images
make reset              # Clean + rebuild
```

## 📊 Monitoring

```bash
make monitor            # Live container monitoring
make env-info           # Environment variables
make env-check          # Check prerequisites
make validate           # Validate configs
```

## 💾 Backup & Restore

```bash
make backup             # Backup volumes
make restore BACKUP_FILE=backups/robots-20250109-120000.tar.gz
```

## 📚 Documentation

```bash
make help               # Show all commands
make docs               # List all docs
make docs-quickstart    # View quick start
make docs-architecture  # View architecture

# Or open files:
- MAKEFILE.md           # Complete Makefile guide
- docs/QUICKSTART.md    # Step-by-step guide
- docs/deployment-guide.md
- docs/kubernetes-setup.md
- docs/troubleshooting.md
```

## 🎯 Common Workflows

### First Time Development Setup
```bash
make quick-dev                    # Generates certs + starts
make client-setup-dev             # Configure client
rcc holotree catalogs             # Test
```

### First Time Cloudflare Setup
```bash
# Install cloudflared (if not already installed)
brew install cloudflare/cloudflare/cloudflared

# Create tunnel and deploy
make quick-cf HOSTNAME=rccremote.example.com
# OR create manually without auto-deploy
make cf-create HOSTNAME=rccremote.example.com
make cf-up

# Configure client (no SSL profile needed!)
export RCC_REMOTE_ORIGIN=https://rccremote.example.com
rcc holotree catalogs
```

### First Time Production Setup
```bash
make certs-signed SERVER_NAME=your-domain.com
make prod-up SERVER_NAME=your-domain.com
make client-setup-prod SERVER_NAME=your-domain.com
make test-connectivity
```

### Daily Development
```bash
make dev-up                       # Start
make dev-logs                     # Watch logs
make shell                        # Debug
make dev-restart                  # Restart
```

### Deploying Updates
```bash
make build                        # Build new image
make dev-down && make dev-up      # Restart dev
# OR
make prod-down && make prod-up SERVER_NAME=your-domain.com
```

### Troubleshooting
```bash
make logs                         # Check logs
make ps                          # Check status
make env-check                   # Verify prerequisites
make validate                    # Validate configs
make test-health                 # Test endpoints
```

## ⚙️ Environment Variables

Create `.env` file (copy from `.env.example`):
```bash
SERVER_NAME=rccremote.local
RCC_REMOTE_ORIGIN=https://rccremote.local:8443
NAMESPACE=rccremote
REPLICAS=3
CF_TUNNEL_TOKEN=your_token
```

Or pass on command line:
```bash
make prod-up SERVER_NAME=your-domain.com
make k8s-deploy NAMESPACE=production REPLICAS=5
```

## 🔍 Health Endpoints

Once deployed, check health:
```bash
# Development
curl -k https://localhost:8443/health/live
curl -k https://localhost:8443/health/ready

# Production
curl https://your-domain.com/health/live
curl https://your-domain.com/health/ready
```

## 🆘 Emergency Commands

```bash
# Stop everything
make clean

# Nuclear option (remove all data)
make clean-all

# Start fresh
make reset

# Backup before cleanup
make backup
make clean-all
# Restore later
make restore BACKUP_FILE=backups/robots-TIMESTAMP.tar.gz
```

## 📞 Getting Help

```bash
make help                        # Show all commands
make env-info                    # Show config
make env-check                   # Check system
```

Online:
- Issues: https://github.com/yorko-io/rccremote-docker/issues
- Docs: https://github.com/yorko-io/rccremote-docker/tree/main/docs

## 💡 Tips

1. **Always use `make help`** to see available commands
2. **Check `make env-check`** before starting
3. **Use `make quick-dev`** for fastest dev setup
4. **Run `make validate`** to check configurations
5. **Use `make backup`** before major changes
6. **Check `make logs`** when troubleshooting
7. **Use `make monitor`** for live status updates

## 🔐 Security Notes

- **Development**: Uses port 8443, self-signed certs
- **Production**: Uses port 443, requires CA-signed certs
- **Cloudflare**: Handles SSL automatically
- **Never commit** `.env` files or certificates to git

## 🎓 Learning Path

1. Start: `make quick-dev` → Test → Read logs
2. Explore: `make help` → Try different commands
3. Configure: Copy `.env.example` → Customize
4. Deploy: `make quick-prod SERVER_NAME=your-domain.com`
5. Scale: `make k8s-deploy REPLICAS=5`
6. Monitor: `make monitor` + `make test-all`

---

**Pro Tip**: Add this to your shell:
```bash
alias rcc-dev='cd ~/path/to/rccremote-docker && make dev-up'
alias rcc-logs='cd ~/path/to/rccremote-docker && make logs'
alias rcc-stop='cd ~/path/to/rccremote-docker && make dev-down'
```
