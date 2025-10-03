# RCC Remote Docker - Comprehensive Deployment Guide

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment Options](#deployment-options)
- [Quick Start](#quick-start)
- [Docker Compose Deployment](#docker-compose-deployment)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Configuration](#configuration)
- [Security](#security)
- [Monitoring and Health Checks](#monitoring-and-health-checks)
- [Scaling](#scaling)
- [Troubleshooting](#troubleshooting)

## Overview

RCC Remote Docker provides a containerized, SSL-enabled setup for RCC Remote - a service that serves RCC environment blueprints (catalogs) to isolated RCC clients that cannot access the internet directly.

### Architecture

```
rcc client --HTTPS--> nginx:443 --HTTP--> rccremote:4653
```

**Key Features:**
- SSL/TLS encryption for all connections
- Automated certificate generation
- Horizontal scaling support (100+ concurrent clients)
- High availability (99.9% uptime target)
- Multiple deployment options (Docker Compose, Kubernetes)
- Comprehensive health checks and monitoring

## Prerequisites

### Common Requirements
- Linux host (Ubuntu 20.04+ recommended)
- 4 CPU cores minimum (8+ recommended for production)
- 8GB RAM minimum (16GB+ recommended for production)
- 50GB+ storage for holotree data

### Docker Compose
- Docker 20.10+
- Docker Compose 1.29+ (or Docker Compose v2)

### Kubernetes
- Kubernetes cluster 1.20+
- kubectl configured
- Storage provisioner (or local storage)
- 3+ worker nodes for high availability

## Deployment Options

| Option | Use Case | Complexity | HA Support | Scaling |
|--------|----------|------------|------------|---------|
| Docker Compose Dev | Local development, testing | Low | No | Manual |
| Docker Compose Prod | Small-scale production | Low | No | Manual |
| Kubernetes | Enterprise production | Medium | Yes | Automatic |

## Quick Start

### 5-Minute Development Setup

```bash
# 1. Clone repository
git clone https://github.com/yorko-io/rccremote-docker.git
cd rccremote-docker

# 2. Generate CA-signed certificates
./scripts/cert-management.sh generate-ca-signed --server-name localhost

# 3. Install CA certificate for RCC clients (REQUIRED)
sudo cp certs/rootCA.crt /usr/local/share/ca-certificates/rccremote-ca.crt
sudo update-ca-certificates

# 4. Deploy
./scripts/deploy-docker.sh --environment development

# 5. Configure RCC client (REQUIRED)
./scripts/configure-rcc-profile.sh

# 6. Set environment variables for current session
export ROBOCORP_HOME=/opt/robocorp
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443

# 7. Verify
./scripts/health-check.sh --target localhost:8443

# 8. Test RCC connectivity
rcc holotree vars
```

Your RCC Remote is now running at `https://localhost:8443` with proper SSL verification!

## Docker Compose Deployment

### Development Environment

**Purpose:** Local testing, development, proof-of-concept

**Features:**
- Auto-generated self-signed certificates
- Hot-reload support
- Verbose logging
- Single replica

#### Setup

```bash
# Deploy
docker-compose -f docker-compose/docker-compose.development.yml up -d

# Or use deployment script
./scripts/deploy-docker.sh --environment development

# Configure RCC client (REQUIRED for first-time setup)
./scripts/configure-rcc-profile.sh

# Set environment variables
export ROBOCORP_HOME=/opt/robocorp
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443
```

#### Configuration

Edit `docker-compose/docker-compose.development.yml` to customize:
- Port mappings
- Volume mounts
- Resource limits
- Environment variables

### Production Environment

**Purpose:** Production deployment for small-to-medium scale

**Features:**
- Custom certificates required
- Optimized resource settings
- Security hardening
- Restart policies

#### Setup

```bash
# 1. Prepare certificates
./scripts/cert-management.sh generate-ca-signed --server-name your-domain.com

# 2. Install CA certificate to system trust store (REQUIRED for RCC clients)
sudo cp certs/rootCA.crt /usr/local/share/ca-certificates/rccremote-ca.crt
sudo update-ca-certificates

# 3. Configure environment
export SERVER_NAME=your-domain.com
export ROBOTS_PATH=/path/to/robots
export CERTS_PATH=/path/to/certs

# 4. Deploy
./scripts/deploy-docker.sh --environment production

# 5. Configure RCC clients (REQUIRED on each client machine)
./scripts/configure-rcc-profile.sh

# 6. Set environment variables (add to ~/.bashrc or ~/.zshrc)
export ROBOCORP_HOME=/opt/robocorp
export RCC_REMOTE_ORIGIN=https://your-domain.com:443
```

#### Required Certificates

Place in `./certs/` directory:
- `server.crt` - Server certificate (PEM format)
- `server.key` - Private key (PEM format)
- `rootCA.pem` - Root CA certificate (for clients)

## Kubernetes Deployment

### Standard Deployment

**Purpose:** Enterprise production with high availability

**Features:**
- Horizontal Pod Autoscaler (3-10 replicas)
- Persistent volumes for data
- Health checks and probes
- Ingress support
- Rolling updates

#### Quick Deploy

```bash
# 1. Deploy to cluster
./scripts/deploy-k8s.sh --namespace rccremote --replicas 3

# 2. Verify
kubectl get pods -n rccremote
kubectl get svc -n rccremote
```

#### Manual Deployment

```bash
# 1. Create namespace
kubectl apply -f k8s/namespace.yaml

# 2. Apply configurations
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/persistent-volume.yaml

# 3. Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 4. Wait for readiness
kubectl wait --for=condition=available deployment/rccremote -n rccremote --timeout=300s
```

### k3d Testing Cluster

For local Kubernetes testing:

```bash
# 1. Create k3d cluster
k3d cluster create rccremote-test --port "8443:443@loadbalancer"

# 2. Deploy
kubectl apply -f k8s/

# 3. Test
export KUBECONFIG=$(k3d kubeconfig write rccremote-test)
./scripts/health-check.sh --target localhost:8443
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVER_NAME` | DNS name for certificates | `rccremote.local` |
| `ROBOCORP_HOME` | Holotree base path | `/opt/robocorp` |
| `RCC_REMOTE_ORIGIN` | URL for RCC clients | `https://rccremote.local:443` |

### Resource Limits

**Docker Compose:**
```yaml
services:
  rccremote:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

**Kubernetes:**
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### SSL/TLS Configuration

#### Auto-Generated Certificates (Development)

Automatically created on first startup:
- Self-signed certificate
- 365-day validity
- SAN includes localhost, server name, wildcards

#### Custom Certificates (Production)

Requirements:
- X.509 format
- SAN (Subject Alternative Name) extension required
- Minimum 2048-bit RSA key
- Valid certificate chain

Generate with:
```bash
./scripts/cert-management.sh generate-ca-signed \
  --server-name your-domain.com \
  --validity 730
```

#### CA Certificate Installation (REQUIRED for RCC Clients)

After generating CA-signed certificates, the Root CA certificate **must** be installed to the system trust store on machines running RCC clients. This enables proper SSL verification without disabling security.

**Linux (Ubuntu/Debian):**
```bash
sudo cp certs/rootCA.crt /usr/local/share/ca-certificates/rccremote-ca.crt
sudo update-ca-certificates
```

**Linux (RHEL/CentOS):**
```bash
sudo cp certs/rootCA.crt /etc/pki/ca-trust/source/anchors/rccremote-ca.crt
sudo update-ca-trust
```

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/rootCA.crt
```

**Windows (PowerShell as Administrator):**
```powershell
certutil -addstore -f "ROOT" certs\rootCA.crt
```

**Verification:**
After installation, test RCC connectivity:
```bash
export RCC_REMOTE_ORIGIN=https://localhost:8443
rcc holotree vars  # Should work without SSL errors
```

## Security

### Container Security

**Non-Root Execution:**
- All containers run as non-root users (UID 1000)
- Read-only root filesystem where possible
- Dropped capabilities (CAP_DROP: ALL)

**Network Security:**
- SSL/TLS enforced for all external connections
- Internal service communication over localhost
- Network policies (Kubernetes)

**Secrets Management:**
- Kubernetes Secrets for certificates
- Environment variable injection
- No secrets in images or logs

### Certificate Security

**Best Practices:**
- Use CA-signed certificates in production
- Rotate certificates before expiry
- Secure private key storage (permissions 600)
- Regular validation: `./scripts/cert-management.sh validate`

### Access Control

**Kubernetes RBAC:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rccremote
  namespace: rccremote
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: rccremote-role
  namespace: rccremote
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
```

## Monitoring and Health Checks

### Health Endpoints

| Endpoint | Purpose | Success Code |
|----------|---------|--------------|
| `/health/live` | Liveness probe | 200 |
| `/health/ready` | Readiness probe | 200 |
| `/health/startup` | Startup probe | 200 |
| `/metrics` | Prometheus metrics | 200 |

### Testing Health

```bash
# Quick check
./scripts/health-check.sh --target rccremote.local:443

# Detailed check
curl -k https://rccremote.local:443/health/live | jq .
curl -k https://rccremote.local:443/health/ready | jq .
curl -k https://rccremote.local:443/health/startup | jq .
```

### Prometheus Integration

**Metrics Available:**
- Request count and latency
- Active connections
- Catalog cache status
- Resource utilization

**Scrape Configuration:**
```yaml
- job_name: 'rccremote'
  static_configs:
  - targets: ['rccremote.rccremote.svc.cluster.local:4653']
  metrics_path: '/metrics'
  scheme: 'http'
```

## Scaling

### Horizontal Scaling (Kubernetes)

**Automatic (HPA):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: rccremote-hpa
spec:
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Manual:**
```bash
kubectl scale deployment rccremote --replicas=5 -n rccremote
```

### Docker Compose Scaling

Not recommended for production. Use Kubernetes for scaling.

**Manual approach:**
```bash
# Increase replicas in docker-compose.yml
services:
  rccremote:
    deploy:
      replicas: 3

# Deploy
docker-compose up -d --scale rccremote=3
```

### Performance Tuning

**For 100+ concurrent clients:**
- 5+ replicas (Kubernetes)
- 1 CPU, 2GB RAM per replica minimum
- Persistent volume with high IOPS
- Network bandwidth: 100 Mbps+ per replica

## Troubleshooting

### Common Issues

#### 1. Certificate Errors

**Symptom:** SSL verification fails
**Solution:**
```bash
# Validate certificates
./scripts/cert-management.sh validate

# Regenerate if invalid
./scripts/cert-management.sh renew
```

#### 2. Health Checks Failing

**Symptom:** Pods/containers not ready
**Diagnosis:**
```bash
# Docker
docker logs rccremote-dev --tail 100

# Kubernetes
kubectl logs -n rccremote -l app=rccremote -c rccremote --tail 100
```

**Common Causes:**
- RCC initialization timeout (increase startup probe `failureThreshold`)
- Missing certificates
- Storage issues

#### 3. RCC Client Cannot Connect

**Symptom:** `rcc holotree vars` fails with path mismatch or SSL errors
**Solution:**
```bash
# First, configure RCC client properly (most common issue)
./scripts/configure-rcc-profile.sh

# Set environment variables
export ROBOCORP_HOME=/opt/robocorp
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443

# Test connectivity
./scripts/test-connectivity.sh --origin https://rccremote.local:443

# Check SSL configuration
rcc config diag

# If still failing, import CA certificate manually
./scripts/cert-management.sh export
# Follow instructions in client-export/README.md
```

#### 4. Deployment Timeout

**Symptom:** Deployment takes >5 minutes
**Causes:**
- Large catalogs building
- Slow storage
- Insufficient resources

**Solution:**
```bash
# Increase timeout
./scripts/deploy-k8s.sh --timeout 600

# Check resource usage
kubectl top pods -n rccremote
docker stats
```

### Log Collection

**Docker Compose:**
```bash
docker-compose -f docker-compose/docker-compose.production.yml logs -f
```

**Kubernetes:**
```bash
# All pods
kubectl logs -n rccremote -l app=rccremote --all-containers --tail=100

# Specific container
kubectl logs -n rccremote <pod-name> -c rccremote --tail=100
```

### Debug Mode

Enable verbose logging:

**Docker Compose:**
```yaml
environment:
  - DEBUG=true
  - LOG_LEVEL=debug
```

**Kubernetes:**
```bash
kubectl set env deployment/rccremote DEBUG=true LOG_LEVEL=debug -n rccremote
```

## Next Steps

- [Kubernetes Setup Guide](kubernetes-setup.md)
- [ARC Runner Integration](arc-integration.md)
- [Troubleshooting Guide](troubleshooting.md)
- [GitHub Issues](https://github.com/yorko-io/rccremote-docker/issues)

## Support

- GitHub Issues: https://github.com/yorko-io/rccremote-docker/issues
- Documentation: https://github.com/yorko-io/rccremote-docker/tree/main/docs
- RCC Documentation: https://sema4.ai/docs/automation/rcc/overview
