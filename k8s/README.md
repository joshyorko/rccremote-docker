# Kubernetes Manifests for RCC Remote

This directory contains production-ready Kubernetes manifests for deploying RCC Remote with high availability, auto-scaling, and comprehensive health checks.

## Quick Deployment

### Option 1: Using the Deployment Script (Recommended)

```bash
# From project root
./scripts/deploy-k8s.sh --namespace rccremote --replicas 3

# With custom settings
./scripts/deploy-k8s.sh \
  --namespace automation \
  --replicas 5 \
  --environment production \
  --timeout 600
```

### Option 2: Manual kubectl Apply

```bash
# From project root
cd k8s

# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Apply all configurations
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f persistent-volume.yaml

# 3. Deploy application
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f health-check.yaml

# 4. Optional: Configure ingress
kubectl apply -f ingress.yaml

# 5. Verify deployment
kubectl get pods -n rccremote
kubectl get svc -n rccremote
kubectl wait --for=condition=available deployment/rccremote -n rccremote --timeout=300s
```

## Manifest Files

| File | Description | Required |
|------|-------------|----------|
| `namespace.yaml` | Creates the rccremote namespace | ✅ Yes |
| `configmap.yaml` | Environment variables and configuration | ✅ Yes |
| `secret.yaml` | TLS certificates placeholder | ✅ Yes |
| `persistent-volume.yaml` | Storage for holotree and hololib data | ✅ Yes |
| `deployment.yaml` | RCC Remote deployment with auto-scaling | ✅ Yes |
| `service.yaml` | Kubernetes service for stable DNS | ✅ Yes |
| `health-check.yaml` | Health check jobs and monitoring | ⚠️ Optional |
| `ingress.yaml` | External access configuration | ⚠️ Optional |

## Architecture

```
Internet/Clients
       ↓
   [Ingress] (optional)
       ↓
   [Service: rccremote.rccremote.svc.cluster.local:443]
       ↓
   [Deployment: 3-10 replicas with HPA]
       ↓
   [PersistentVolume: holotree + hololib data]
```

## Prerequisites

- Kubernetes cluster (v1.20+)
- kubectl configured
- Storage provisioner (or use local storage)
- cert-manager (optional, for automatic certificates)

## Configuration

### Custom Certificates

Edit `secret.yaml` and add your certificates:

```yaml
stringData:
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
```

### Resource Requirements

Default configuration:
- 3 replicas for high availability
- Autoscaling: 3-10 replicas based on CPU/memory
- Per-pod resources: 512Mi-2Gi memory, 250m-1 CPU

Adjust in `deployment.yaml` based on your needs.

## Testing

```bash
# Port-forward for local testing
kubectl port-forward -n rccremote svc/rccremote 8443:443

# Test health endpoints
curl -k https://localhost:8443/health/live
curl -k https://localhost:8443/health/ready

# Test from RCC client
export RCC_REMOTE_ORIGIN=https://rccremote.rccremote.svc.cluster.local:443
rcc holotree vars -r robot.yaml
```

## ARC Runner Integration

For GitHub Actions Runner Controller integration:

1. Deploy in the same namespace as ARC runners
2. Configure ARC to use service DNS: `rccremote.automation.svc.cluster.local`
3. Mount CA certificate for SSL verification
4. Configure catalog caching for resilience

See `docs/arc-integration.md` for detailed instructions.

## Monitoring

Health check endpoints:
- `/health/live` - Liveness probe
- `/health/ready` - Readiness probe  
- `/health/startup` - Startup probe
- `/metrics` - Prometheus metrics

## Troubleshooting

```bash
# Check pod logs
kubectl logs -n rccremote -l app=rccremote -c rccremote
kubectl logs -n rccremote -l app=rccremote -c nginx

# Check events
kubectl get events -n rccremote --sort-by='.lastTimestamp'

# Describe resources
kubectl describe deployment -n rccremote rccremote
kubectl describe svc -n rccremote rccremote

# Check HPA status
kubectl get hpa -n rccremote
```

## Cleanup

```bash
kubectl delete -f .
kubectl delete namespace rccremote
```
