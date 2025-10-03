# Docker Compose Configurations

This directory contains Docker Compose configuration files for different deployment scenarios.

## Available Configurations

### `docker-compose.development.yml` - Development Setup

**Purpose:** Local development and testing

**Key Features:**
- Port: 8443 (non-privileged)
- Auto-generates self-signed certificates if none exist
- Uses pre-generated certificates from `../certs/` if available
- Healthchecks with generous timeouts
- Restart policy: `unless-stopped`
- Container names: `rccremote-dev`, `rccremote-nginx-dev`

**Usage:**
```bash
# From project root
./scripts/deploy-docker.sh --environment development

# Or directly
docker compose -f docker-compose/docker-compose.development.yml up -d
```

**When to use:**
- ✅ Local development on your laptop
- ✅ Testing robot configurations
- ✅ Proof of concept demonstrations
- ✅ Learning and experimentation

---

### `docker-compose.production.yml` - Production Setup

**Purpose:** Production deployment with security hardening

**Key Features:**
- Port: 443 (standard HTTPS, requires root/sudo)
- Requires pre-existing certificates (no auto-generation)
- Security hardening: capability drops, privilege restrictions
- Healthchecks with strict timeouts
- Restart policy: `always`
- Container names: `rccremote-prod`, `rccremote-nginx-prod`
- Configurable paths via environment variables

**Usage:**
```bash
# From project root
export SERVER_NAME=your-domain.com
export ROBOTS_PATH=/path/to/robots
export CERTS_PATH=/path/to/certs

./scripts/deploy-docker.sh --environment production --server-name your-domain.com

# Or directly
docker compose -f docker-compose/docker-compose.production.yml up -d
```

**When to use:**
- ✅ Production environments
- ✅ Serving 10+ concurrent clients
- ✅ Security-critical deployments
- ✅ High availability requirements

---

### `docker-compose.cloudflare.yml` - Cloudflare Tunnel Setup

**Purpose:** Expose RCC Remote through Cloudflare Tunnel

**Key Features:**
- No port exposure required
- Cloudflare handles SSL/TLS termination
- DDoS protection and CDN caching
- Zero Trust network access

**Usage:**
```bash
# Configure Cloudflare credentials
export CLOUDFLARE_TUNNEL_TOKEN=your_token_here

# Deploy
./scripts/deploy-cloudflare.sh
```

**When to use:**
- ✅ Remote access without exposing ports
- ✅ Need Cloudflare's security features
- ✅ Multi-region deployments
- ✅ Zero Trust architecture

---

## Directory Structure

```
docker-compose/
├── README.md                          # This file
├── docker-compose.development.yml     # Development setup
├── docker-compose.production.yml      # Production setup
└── docker-compose.cloudflare.yml      # Cloudflare Tunnel setup
```

## Kubernetes Manifests

Kubernetes deployment manifests are located in the `/k8s/` directory at the project root.
See `/k8s/README.md` for deployment instructions.

## Comparison

| Feature | Development | Production | Cloudflare |
|---------|------------|------------|------------|
| **Port** | 8443 | 443 | N/A (tunnel) |
| **Certificates** | Auto-generated | Required | Cloudflare manages |
| **Security** | Basic | Hardened | Cloudflare Zero Trust |
| **Restart** | unless-stopped | always | always |
| **Use Case** | Local testing | Enterprise production | Remote access |

## Environment Variables

### Common Variables (All Configs)

- `SERVER_NAME` - DNS name for the server (default: `rccremote.local`)
- `ROBOCORP_HOME` - Holotree base path (default: `/opt/robocorp`)
- `RCC_REMOTE_ORIGIN` - URL for RCC clients to connect

### Production-Specific Variables

- `ROBOTS_PATH` - Path to robot definitions (default: `./data/robots`)
- `HOLOLIB_ZIP_PATH` - Path to pre-built catalogs (default: `./data/hololib_zip`)
- `CERTS_PATH` - Path to SSL certificates (default: `./certs`)
- `CONFIG_PATH` - Path to config files (default: `./config`)
- `SCRIPTS_PATH` - Path to utility scripts (default: `./scripts`)

### Cloudflare-Specific Variables

- `CLOUDFLARE_TUNNEL_TOKEN` - Cloudflare Tunnel authentication token
- `CLOUDFLARE_TUNNEL_NAME` - Tunnel name (optional)

## Client Configuration

After deploying the server, **every RCC client machine must be configured**:

```bash
# Run the configuration script
./scripts/configure-rcc-profile.sh

# Add to shell profile (~/.bashrc or ~/.zshrc)
export ROBOCORP_HOME=/opt/robocorp
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443  # Or your server URL

# Test connectivity
rcc holotree vars
```

This script:
1. Creates `/opt/robocorp` directory with proper permissions
2. Enables shared holotree at this location
3. Configures SSL profile with Root CA certificate
4. Sets up proper certificate verification

## Common Commands

### View Logs
```bash
# Development
docker logs rccremote-dev -f
docker logs rccremote-nginx-dev -f

# Production
docker logs rccremote-prod -f
docker logs rccremote-nginx-prod -f
```

### Stop Services
```bash
# Development
docker compose -f docker-compose/docker-compose.development.yml down

# Production
docker compose -f docker-compose/docker-compose.production.yml down
```

### Remove Volumes (Clean Start)
```bash
# Development
docker compose -f docker-compose/docker-compose.development.yml down -v

# Production  
docker compose -f docker-compose/docker-compose.production.yml down -v
```

### Health Check
```bash
# Check service health
./scripts/health-check.sh --target localhost:8443  # Development
./scripts/health-check.sh --target your-domain.com:443  # Production
```

## Troubleshooting

### Development Issues

**Problem:** Certificates not working
- Solution: Delete `certs` volume and restart to regenerate
  ```bash
  docker compose -f docker-compose/docker-compose.development.yml down -v
  docker compose -f docker-compose/docker-compose.development.yml up -d
  ```

**Problem:** RCC client can't connect
- Solution: Run client configuration script
  ```bash
  ./scripts/configure-rcc-profile.sh
  export ROBOCORP_HOME=/opt/robocorp
  export RCC_REMOTE_ORIGIN=https://rccremote.local:8443
  ```

### Production Issues

**Problem:** Port 443 permission denied
- Solution: Run with sudo or configure port forwarding
  ```bash
  sudo docker compose -f docker-compose/docker-compose.production.yml up -d
  ```

**Problem:** Certificates not found
- Solution: Generate certificates before deploying
  ```bash
  ./scripts/cert-management.sh generate-ca-signed --server-name your-domain.com
  ```

## Next Steps

- [Deployment Guide](../docs/deployment-guide.md) - Comprehensive deployment instructions
- [Quick Start Guide](../docs/QUICKSTART.md) - Step-by-step walkthrough
- [Troubleshooting Guide](../docs/troubleshooting.md) - Common issues and solutions
- [Kubernetes Setup](../docs/kubernetes-setup.md) - For scaling beyond Docker Compose

## Support

- GitHub Issues: https://github.com/yorko-io/rccremote-docker/issues
- Documentation: https://github.com/yorko-io/rccremote-docker/tree/main/docs
