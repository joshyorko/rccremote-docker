# Docker Registry & Image Publishing Guide

## Overview

This guide explains how to build, tag, and push Docker images to a container registry (GitHub Container Registry by default).

## Quick Start

```bash
# 1. Login to registry
make registry-login

# 2. Build and push
make push

# 3. Pull on another machine
make pull
```

## Configuration

### Environment Variables

Set these in `.env` or export them:

```bash
# Registry configuration
DOCKER_REGISTRY=ghcr.io                    # Default: GitHub Container Registry
DOCKER_REPO=yorko-io/rccremote-docker      # Your repo path
IMAGE_TAG=latest                           # Tag to use (latest, v1.0.0, etc.)

# Full image name will be: ghcr.io/yorko-io/rccremote-docker:latest
```

### Custom Registry

To use a different registry:

```bash
# Docker Hub
export DOCKER_REGISTRY=docker.io
export DOCKER_REPO=username/rccremote-docker

# AWS ECR
export DOCKER_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com
export DOCKER_REPO=rccremote-docker

# Google Container Registry
export DOCKER_REGISTRY=gcr.io
export DOCKER_REPO=project-id/rccremote-docker

# Azure Container Registry
export DOCKER_REGISTRY=myregistry.azurecr.io
export DOCKER_REPO=rccremote-docker
```

## Commands

### `make registry-login`

Login to the Docker registry.

**GitHub Container Registry:**
```bash
make registry-login
# Prompts for:
# - GitHub Username
# - GitHub Personal Access Token (with packages:write permission)
```

**Create GitHub Token:**
1. Go to https://github.com/settings/tokens/new
2. Select scope: `write:packages`
3. Generate token
4. Copy and use in login prompt

**Other Registries:**
```bash
# Docker Hub
docker login

# AWS ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Google GCR
gcloud auth configure-docker

# Azure ACR
az acr login --name myregistry
```

### `make build`

Build the Docker image locally without tagging for registry.

```bash
make build
# Creates: rccremote:latest
```

### `make build-tag`

Build and tag the image for registry push.

```bash
make build-tag
# Creates: 
#   - rccremote:latest (local)
#   - ghcr.io/yorko-io/rccremote-docker:latest (registry tag)
```

### `make push`

Build, tag, and push to registry (all in one).

```bash
# Using defaults
make push

# Custom tag
make push IMAGE_TAG=v1.0.0

# Custom registry
make push DOCKER_REGISTRY=docker.io DOCKER_REPO=username/rccremote
```

**What it does:**
1. Runs `make build-tag`
2. Pushes to registry
3. Shows final image name

### `make pull`

Pull the image from registry.

```bash
# Using defaults
make pull

# Custom tag
make pull IMAGE_TAG=v1.0.0

# Custom registry
make pull DOCKER_REGISTRY=docker.io DOCKER_REPO=username/rccremote
```

## Workflows

### Workflow 1: Local Development → Push to Registry

```bash
# 1. Build and test locally
make build
make dev-up
make test-all

# 2. Login to registry (one-time)
make registry-login

# 3. Push to registry
make push

# 4. Verify
docker images | grep rccremote
```

### Workflow 2: Versioned Release

```bash
# Build and tag with version
make push IMAGE_TAG=v1.2.3

# Also tag as latest
make push IMAGE_TAG=latest

# Both tags now available in registry:
#   - ghcr.io/yorko-io/rccremote-docker:v1.2.3
#   - ghcr.io/yorko-io/rccremote-docker:latest
```

### Workflow 3: Multi-Architecture Build

```bash
# Build for multiple platforms
docker buildx create --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/yorko-io/rccremote-docker:latest \
  -f Dockerfile-rcc \
  --push \
  .
```

### Workflow 4: Deploy from Registry

On deployment machines:

```bash
# 1. Pull latest image
make pull

# 2. Deploy
make quick-k8s

# Or for Docker Compose
make prod-up SERVER_NAME=your-domain.com
```

### Workflow 5: CI/CD Pipeline

```bash
# In your CI/CD pipeline (GitHub Actions, GitLab CI, etc.)

# Login
echo "$REGISTRY_TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin

# Build and push
make push IMAGE_TAG=$CI_COMMIT_SHA

# Deploy
make k8s-deploy NAMESPACE=production
```

## GitHub Container Registry

### Making Images Public

1. Go to https://github.com/users/yorko-io/packages/container/rccremote-docker/settings
2. Scroll to "Danger Zone"
3. Click "Change visibility"
4. Select "Public"

### Package Permissions

Control who can push/pull:
1. Go to package settings
2. Navigate to "Manage Actions access"
3. Add repository access

### Linking to Repository

```bash
# Add label to Dockerfile
LABEL org.opencontainers.image.source=https://github.com/yorko-io/rccremote-docker
```

## Kubernetes Integration

Update deployment to use registry image:

```yaml
# k8s/deployment.yaml
spec:
  containers:
  - name: rccremote
    image: ghcr.io/yorko-io/rccremote-docker:latest
    imagePullPolicy: Always
```

Deploy with specific tag:

```bash
# Update image in deployment
kubectl set image deployment/rccremote \
  rccremote=ghcr.io/yorko-io/rccremote-docker:v1.2.3 \
  -n rccremote

# Or redeploy
make k8s-deploy
```

### Private Registry with Kubernetes

Create image pull secret:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password=your-token \
  --docker-email=your-email \
  -n rccremote

# Add to deployment:
spec:
  imagePullSecrets:
  - name: regcred
```

## Troubleshooting

### Login Failed

**GitHub:**
```bash
# Ensure token has correct permissions
# Scope required: write:packages

# Test token
echo "$GITHUB_TOKEN" | docker login ghcr.io -u your-username --password-stdin
```

### Push Failed - Unauthorized

```bash
# Re-login
make registry-login

# Verify login
docker info | grep Username
```

### Image Not Found

```bash
# Check image exists
docker images | grep rccremote

# Verify tag
make env-info

# Pull explicitly
docker pull ghcr.io/yorko-io/rccremote-docker:latest
```

### Wrong Architecture

```bash
# Check your platform
uname -m

# Build for specific platform
docker build --platform linux/amd64 -f Dockerfile-rcc -t rccremote:latest .

# Or use buildx for multi-arch
docker buildx build --platform linux/amd64,linux/arm64 ...
```

## Best Practices

### 1. Use Semantic Versioning

```bash
# Tag releases with versions
make push IMAGE_TAG=v1.2.3

# Keep latest updated
make push IMAGE_TAG=latest
```

### 2. Automate in CI/CD

```yaml
# .github/workflows/build.yml
- name: Build and push
  run: |
    echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
    make push IMAGE_TAG=${{ github.sha }}
    make push IMAGE_TAG=latest
```

### 3. Scan for Vulnerabilities

```bash
# Use Trivy
trivy image ghcr.io/yorko-io/rccremote-docker:latest

# Use Docker Scout
docker scout cves ghcr.io/yorko-io/rccremote-docker:latest
```

### 4. Keep Images Small

```bash
# Check image size
docker images ghcr.io/yorko-io/rccremote-docker

# Use multi-stage builds in Dockerfile
# Clean up in same RUN command
# Use .dockerignore
```

### 5. Tag Strategy

- `latest` - Current stable version
- `v1.2.3` - Specific version
- `dev` - Development builds
- `sha-abc123` - Commit-specific builds

## Alternative Registries

### Docker Hub

```bash
export DOCKER_REGISTRY=docker.io
export DOCKER_REPO=username/rccremote-docker
make registry-login  # Will prompt differently
make push
```

### Self-Hosted Registry

```bash
# Run your own registry
docker run -d -p 5000:5000 --name registry registry:2

# Use it
export DOCKER_REGISTRY=localhost:5000
export DOCKER_REPO=rccremote-docker
make push
```

## Summary

**Quick Commands:**
```bash
make registry-login         # Login (one-time)
make push                   # Build and push
make pull                   # Pull image
make push IMAGE_TAG=v1.0.0  # Push with version
```

**Environment Variables:**
```bash
DOCKER_REGISTRY    # Registry host (default: ghcr.io)
DOCKER_REPO        # Repository path (default: yorko-io/rccremote-docker)
IMAGE_TAG          # Image tag (default: latest)
```

**Full Image Name:**
```
${DOCKER_REGISTRY}/${DOCKER_REPO}:${IMAGE_TAG}
# Example: ghcr.io/yorko-io/rccremote-docker:latest
```
