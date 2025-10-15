# Makefile Usage Guide

This Makefile provides a unified interface for deploying and managing RCC Remote Docker across different environments and platforms.

## Quick Reference

```bash
# Show all available commands
make help

# Quick start development environment
make quick-dev

# Quick start production environment
make quick-prod SERVER_NAME=your-domain.com

# Quick start Kubernetes
make quick-k8s
```

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Common Workflows](#common-workflows)
4. [Development Deployment](#development-deployment)
5. [Production Deployment](#production-deployment)
6. [Cloudflare Tunnel Deployment](#cloudflare-tunnel-deployment)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Testing & Validation](#testing--validation)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

Check if you have all required tools:

```bash
make env-check
```

Required:
- Docker (with Compose V2)
- OpenSSL
- Bash/Zsh

Optional:
- kubectl (for Kubernetes deployments)
- RCC (for client testing)

## Environment Setup

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Edit `.env` to match your configuration:
```bash
# Minimum required for development
SERVER_NAME=rccremote.local

# For production
SERVER_NAME=your-domain.com
```

3. View current environment:
```bash
make env-info
```

## Common Workflows

### First Time Setup (Development)

```bash
# 1. Generate certificates
make certs-generate

# 2. Setup sample robots
make setup-samples

# 3. Start development environment
make dev-up

# 4. Configure RCC client
make client-configure

# 5. Set environment variable
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443

# 6. Test connectivity
make test-connectivity
```

### First Time Setup (Production)

```bash
# 1. Generate CA-signed certificates
make certs-signed SERVER_NAME=your-domain.com

# 2. Setup your robot definitions in data/robots/

# 3. Build production image
make build-prod

# 4. Start production environment
make prod-up SERVER_NAME=your-domain.com

# 5. Configure clients
make client-setup-prod SERVER_NAME=your-domain.com
```

### Daily Development Tasks

```bash
# View logs
make logs

# Restart services
make dev-restart

# Shell into container
make shell

# Check status
make ps

# Run tests
make test-all
```

## Development Deployment

## Docker Build & Setup

### Basic Build Commands

```bash
# Build locally
make build

# Build and tag for registry
make build-tag

# Build for specific environment
make build-dev
make build-prod
```

### Docker Registry

Push images to a container registry (GitHub Container Registry by default):

```bash
# Login to registry (one-time)
make registry-login

# Build, tag and push
make push

# Push with custom tag
make push IMAGE_TAG=v1.0.0

# Pull from registry
make pull
```

**Configuration:**
```bash
# Set in .env or export
DOCKER_REGISTRY=ghcr.io                    # Registry host
DOCKER_REPO=yorko-io/rccremote-docker      # Repository path
IMAGE_TAG=latest                           # Image tag
```

See [Docker Registry Guide](docs/DOCKER_REGISTRY.md) for detailed instructions.

## Certificate Management

### Configuration

Development uses:
- Port: 8443
- Auto-generated certificates
- Containers: `rccremote-dev`, `rccremote-nginx-dev`

### Shell Access

```bash
# RCC Remote container
make dev-shell-rccremote

# Nginx container
make dev-shell-nginx
```

## Production Deployment

### Prerequisites

Production requires:
1. Valid SSL certificates in `./certs/`
2. `SERVER_NAME` environment variable set
3. Root/sudo access (for port 443)

### Basic Commands

```bash
# Start production environment
make prod-up SERVER_NAME=your-domain.com

# Stop production environment
make prod-down

# View logs
make prod-logs

# Restart services
make prod-restart SERVER_NAME=your-domain.com

# Clean environment
make prod-clean
```

### Certificate Management

```bash
# Generate self-signed certificates
make certs-generate

# Generate CA-signed certificates
make certs-signed

# Interactive certificate management
make certs-manage

# Clean certificates
make certs-clean
```

### Shell Access

```bash
# RCC Remote container
make prod-shell-rccremote

# Nginx container
make prod-shell-nginx
```

## Cloudflare Tunnel Deployment

Cloudflare Tunnel provides secure remote access without exposing ports.

### Prerequisites

Install cloudflared CLI:
```bash
# Homebrew (recommended for most systems including Universal Blue/Bluefin)
brew install cloudflare/cloudflare/cloudflared

# Arch Linux
yay -S cloudflared-bin

# Traditional Linux (Debian/Ubuntu)
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

### Method 1: Create Tunnel Programmatically (Recommended)

Create a tunnel using the CLI without touching the Cloudflare dashboard:

```bash
# One command - create and deploy
make quick-cf HOSTNAME=rccremote.example.com

# Or create without auto-deploy
make cf-create HOSTNAME=rccremote.example.com

# Then deploy later
make cf-up
```

The script will:
1. Check if cloudflared is installed
2. Authenticate you with Cloudflare (opens browser)
3. Create the tunnel
4. Configure DNS routing
5. Generate and save the token to `.env`
6. Optionally deploy the service

### Method 2: Use Existing Tunnel

If you already created a tunnel in the Cloudflare dashboard:

1. Get your tunnel token from https://one.dash.cloudflare.com/
2. Deploy:

```bash
# Start with token
make cf-up CF_TUNNEL_TOKEN=your_token

# Stop
make cf-down

# View logs
make cf-logs

# Restart
make cf-restart

# Clean
make cf-clean
```

### Managing Tunnels

```bash
# List all your tunnels
make cf-tunnel-list

# Get info about a specific tunnel
make cf-tunnel-info TUNNEL_NAME=rccremote

# Delete a tunnel
make cf-tunnel-delete TUNNEL_NAME=rccremote
```

### Custom Configuration

Override defaults:
```bash
# Custom tunnel name
make cf-create HOSTNAME=rcc.example.com TUNNEL_NAME=my-rcc-tunnel

# Create and auto-deploy
make cf-create-deploy HOSTNAME=rcc.example.com
```

### Environment Variables

Set in `.env`:
```bash
CF_TUNNEL_TOKEN=your_cloudflare_tunnel_token
SERVER_NAME=rccremote.example.com
```

## Kubernetes Deployment

Deploy RCC Remote to Kubernetes with high availability and auto-scaling.

### Quick Deploy

```bash
# Build and deploy (default: 3 replicas)
make quick-k8s

# Custom deployment
make k8s-deploy NAMESPACE=automation REPLICAS=5
```

### Advanced Commands

```bash
# Manual apply (step by step)
make k8s-apply

# Delete all resources (keeps namespace)
make k8s-delete

# Complete uninstall (removes namespace)
make k8s-uninstall

# Check status
make k8s-status

# View logs
make k8s-logs

# Shell into pod
make k8s-shell

# Port forward for testing
make k8s-port-forward

# Describe resources
make k8s-describe

# View events
make k8s-events
```

### Configuration

Override defaults:
```bash
make k8s-deploy NAMESPACE=rccremote REPLICAS=5
```

## Testing & Validation

### Health Checks

```bash
# Run health check
make test-health

# Test RCC connectivity
make test-connectivity
```

### Integration Tests

```bash
# Run all integration tests
make test-integration

# Test Docker deployment
make test-docker

# Test Kubernetes deployment
make test-k8s

# Test RCC client connectivity
make test-rcc

# Run all tests
make test-all
```

### Validation

```bash
# Validate all docker-compose configurations
make validate
```

## Client Configuration

Configure RCC clients to connect to your RCC Remote server.

### Development Client

```bash
# Configure and add to shell profile
make client-setup-dev

# Or manual configuration
make client-configure
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443
```

### Production Client

```bash
# Configure for production
make client-setup-prod SERVER_NAME=your-domain.com

# Or manual
make client-configure
export RCC_REMOTE_ORIGIN=https://your-domain.com
```

## Maintenance

### Monitoring

```bash
# View running containers/pods
make ps

# Monitor containers (live refresh)
make monitor

# View logs (auto-detect environment)
make logs
```

### Backup & Restore

```bash
# Backup data volumes
make backup

# Restore from backup
make restore BACKUP_FILE=backups/robots-20250109-120000.tar.gz
```

### Cleanup

```bash
# Clean current environment
make clean

# Clean everything (images + volumes)
make clean-all

# Complete reset (clean + rebuild)
make reset
```

## Troubleshooting

### Common Issues

**Problem: Port 443 permission denied**
```bash
# Solution: Use sudo for production
sudo make prod-up SERVER_NAME=your-domain.com
```

**Problem: Certificates not working**
```bash
# Development: Regenerate certificates
make dev-clean
make certs-generate
make dev-up

# Production: Check certificate validity
openssl x509 -in certs/server.crt -text -noout
```

**Problem: RCC client can't connect**
```bash
# Reconfigure client
make client-configure

# Verify environment variable
echo $RCC_REMOTE_ORIGIN

# Test connectivity
make test-connectivity
```

**Problem: Docker container won't start**
```bash
# View logs
make logs

# Check container status
docker ps -a

# Clean and restart
make dev-clean
make dev-up
```

### Debug Commands

```bash
# Check environment
make env-info

# Validate configurations
make validate

# View detailed status
make ps
make k8s-status  # For Kubernetes
```

### Getting Help

```bash
# Show all available commands
make help

# View environment information
make env-info

# Check prerequisites
make env-check
```

## Advanced Usage

### Custom Paths

Override default paths:
```bash
make prod-up \
  SERVER_NAME=your-domain.com \
  ROBOTS_PATH=/custom/path/robots \
  CERTS_PATH=/custom/path/certs
```

### Multiple Environments

Run different environments simultaneously:
```bash
# Development (port 8443)
make dev-up

# Production (port 443) - different terminal
sudo make prod-up SERVER_NAME=prod.example.com
```

### Script Permissions

If scripts aren't executable:
```bash
make update-scripts
```

## Best Practices

1. **Development**: Use `make quick-dev` for fast setup
2. **Production**: Always use CA-signed certificates with `make certs-signed`
3. **Testing**: Run `make test-all` before deploying to production
4. **Backups**: Regular backups with `make backup`
5. **Monitoring**: Use `make monitor` to watch container health
6. **Logs**: Check logs regularly with `make logs`
7. **Updates**: Keep images updated with `make build`

## Examples

### Complete Development Workflow

```bash
# 1. Setup
make quick-dev
make client-setup-dev

# 2. Develop
make dev-logs  # Watch logs
make shell     # Debug

# 3. Test
make test-all

# 4. Cleanup
make dev-clean
```

### Complete Production Workflow

```bash
# 1. Prepare
make certs-signed SERVER_NAME=rcc.example.com
make build-prod

# 2. Deploy
make prod-up SERVER_NAME=rcc.example.com

# 3. Verify
make test-health
make test-connectivity

# 4. Configure clients
make client-setup-prod SERVER_NAME=rcc.example.com

# 5. Monitor
make prod-logs
```

### Kubernetes Production Deployment

```bash
# 1. Build
make build

# 2. Deploy with HA
make k8s-deploy NAMESPACE=production REPLICAS=5

# 3. Verify
make k8s-status
make k8s-logs

# 4. Test
make k8s-port-forward  # In one terminal
make test-connectivity  # In another terminal
```

## Reference

### All Make Targets

Run `make help` to see all available targets organized by category:

- **General**: help, version
- **Docker Build & Setup**: build, build-dev, build-prod
- **Certificate Management**: certs-generate, certs-signed, certs-clean, certs-manage
- **Development Deployment**: dev-up, dev-down, dev-logs, dev-restart, dev-clean, dev-shell-*
- **Production Deployment**: prod-up, prod-down, prod-logs, prod-restart, prod-clean, prod-shell-*
- **Cloudflare Tunnel**: cf-up, cf-down, cf-logs, cf-restart, cf-clean
- **Kubernetes**: k8s-deploy, k8s-apply, k8s-delete, k8s-status, k8s-logs, k8s-shell, k8s-port-forward
- **Testing & Health Checks**: test-health, test-connectivity, test-integration, test-all
- **Client Configuration**: client-configure, client-setup-dev, client-setup-prod
- **Maintenance**: logs, ps, clean, clean-all, reset, backup, restore
- **Quick Start**: quick-dev, quick-prod, quick-k8s
- **Documentation**: docs, docs-quickstart, docs-architecture
- **Utilities**: validate, setup-samples, shell, update-scripts, env-info, env-check

### Environment Variables

See `.env.example` for all configurable environment variables.

Key variables:
- `SERVER_NAME`: Server hostname/domain
- `NAMESPACE`: Kubernetes namespace
- `REPLICAS`: Number of replicas
- `CF_TUNNEL_TOKEN`: Cloudflare tunnel token

## Support

- **Documentation**: Check `docs/` directory
- **Issues**: https://github.com/yorko-io/rccremote-docker/issues
- **Quick Start**: `make docs-quickstart`
- **Architecture**: `make docs-architecture`
