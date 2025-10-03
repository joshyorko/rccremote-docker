# Quickstart: RCC Remote Docker Streamlining & Enhancement

## Prerequisites
- Docker and Docker Compose installed
- kubectl and k3d installed (for Kubernetes testing)
- RCC client installed for connectivity testing
- 5 minutes for complete deployment

## Docker Compose Deployment (Development)

### 1. Clone and Navigate
```bash
git clone <repository-url>
cd rccremote-docker
git checkout 001-streamlining-rcc-remote
```

### 2. Quick Start with Auto-Generated Certificates
```bash
# Start with development configuration
docker-compose -f docker-compose/docker-compose.development.yml up -d

# Verify deployment completed in <5 minutes
scripts/health-check.sh --timeout=300
```

**Expected Result**: SSL-enabled RCC Remote running on https://rccremote.local:8443 with auto-generated self-signed certificates

### 3. Test RCC Connectivity
```bash
# Set environment for RCC client
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443

# Verify catalog fetching works
cd data/robots-samples/rf7
rcc holotree vars

# Should show catalog download from rccremote
```

**Expected Result**: RCC client successfully downloads environment catalog from containerized RCC Remote

## Kubernetes Deployment (Production)

### 1. Create k3d Test Cluster
```bash
# Create lightweight Kubernetes cluster
k3d cluster create rccremote-test --port "8443:443@loadbalancer"

# Verify cluster is ready
kubectl cluster-info
```

### 2. Deploy RCC Remote to Kubernetes
```bash
# Deploy all Kubernetes resources
scripts/deploy-k8s.sh --environment=production --replicas=3

# Wait for deployment to be ready (should be <5 minutes)
kubectl wait --for=condition=available deployment/rccremote --timeout=300s
```

**Expected Result**: 3 RCC Remote replicas running with 99.9% availability configuration

### 3. Verify Health Checks
```bash
# Test all health endpoints
curl -k https://rccremote.local:8443/health/live
curl -k https://rccremote.local:8443/health/ready
curl -k https://rccremote.local:8443/health/startup

# Check Prometheus metrics
curl -k https://rccremote.local:8443/metrics
```

**Expected Results**:
- `/health/live`: Returns 200 with service status
- `/health/ready`: Returns 200 with readiness status  
- `/health/startup`: Returns 200 when initialization complete
- `/metrics`: Returns Prometheus-formatted metrics

## Load Testing (100+ Concurrent Clients)

### 1. Scale Up for Enterprise Load
```bash
# Scale deployment to handle 100+ clients
kubectl scale deployment rccremote --replicas=5

# Verify horizontal scaling
kubectl get pods -l app=rccremote
```

### 2. Run Concurrent Client Test
```bash
# Test with 100 concurrent RCC clients
tests/load/test-concurrent-clients.sh --clients=100 --duration=300

# Monitor resource usage
kubectl top pods -l app=rccremote
```

**Expected Result**: System handles 100+ concurrent clients while maintaining <5s response times

## ARC Runner Integration

### 1. Deploy in Same Namespace
```bash
# Create namespace for co-location
kubectl create namespace automation

# Deploy RCC Remote to automation namespace
kubectl apply -f k8s/ -n automation

# Verify service discovery
kubectl get svc -n automation
```

### 2. Configure ARC Runner SSL Trust
```bash
# Extract root CA certificate
kubectl get secret rccremote-certs -n automation -o jsonpath='{.data.rootCA\.pem}' | base64 -d > rootCA.pem

# Configure ARC runner pods to use CA bundle
# (Mount rootCA.pem and configure RCC ssl-cabundle profile)
```

**Expected Result**: ARC runners can connect to `rccremote.automation.svc.cluster.local` with SSL verification

## Failure Recovery Testing

### 1. Test Certificate Failure Behavior
```bash
# Remove certificates to trigger failure
rm -rf certs/*

# Attempt deployment (should fail fast)
docker-compose up -d

# Verify clear error message and no partial deployment
```

**Expected Result**: Deployment fails immediately with clear certificate error message

### 2. Test Connectivity Resilience
```bash
# Start RCC Remote and populate catalog cache
docker-compose up -d
rcc holotree vars  # Populates cache

# Simulate network failure
docker-compose stop rccremote

# Test cached catalog fallback
rcc holotree vars  # Should use cached data
```

**Expected Result**: RCC client falls back to cached catalogs during connectivity issues

## Validation Checklist

### Deployment Performance
- [ ] Docker Compose deployment completes in <5 minutes
- [ ] Kubernetes deployment completes in <5 minutes  
- [ ] Certificate auto-generation works reliably
- [ ] Health checks respond correctly

### Scale and Reliability
- [ ] System supports 100+ concurrent RCC clients
- [ ] Horizontal scaling works automatically
- [ ] 99.9% uptime achieved with multiple replicas
- [ ] Graceful handling of pod restarts

### Security and Integration
- [ ] SSL/TLS enforced for all connections
- [ ] Certificate validation working properly
- [ ] ARC runner integration with service discovery
- [ ] Cached catalog fallback during connectivity loss

### Operational Excellence
- [ ] Clear error messages for misconfigurations
- [ ] Comprehensive health endpoint responses
- [ ] Prometheus metrics available for monitoring
- [ ] Documentation covers troubleshooting scenarios

## Troubleshooting

### Common Issues
1. **Certificate generation fails**: Check `SERVER_NAME` environment variable matches DNS requirements
2. **Deployment timeout**: Verify Docker/Kubernetes resource limits and network connectivity
3. **RCC client can't connect**: Confirm SSL certificates and firewall settings
4. **Health checks failing**: Check container logs and resource utilization

### Log Locations
- Docker Compose: `docker-compose logs rccremote`
- Kubernetes: `kubectl logs deployment/rccremote`
- Health checks: Available via `/health/*` endpoints

### Support Resources
- Full documentation: `docs/deployment-guide.md`
- Kubernetes setup: `docs/kubernetes-setup.md`
- ARC integration: `docs/arc-integration.md`
- Troubleshooting: `docs/troubleshooting.md`