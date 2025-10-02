# Complete Kubernetes Example for RCC Remote

This directory contains a complete, ready-to-deploy example of RCC Remote on Kubernetes.

## Quick Deployment

```bash
# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Apply all configurations
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f persistent-volume.yaml

# 3. Deploy application
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# 4. Optional: Configure ingress
kubectl apply -f ingress.yaml

# 5. Verify deployment
kubectl get pods -n rccremote
kubectl get svc -n rccremote
```

## Files Overview

- `namespace.yaml` - Creates the rccremote namespace
- `configmap.yaml` - Environment variables and configuration
- `secret.yaml` - TLS certificates (populate with your certs)
- `persistent-volume.yaml` - Storage for holotree and hololib data
- `deployment.yaml` - RCC Remote deployment with HPA
- `service.yaml` - Kubernetes service for stable DNS
- `ingress.yaml` - Optional ingress for external access
- `deploy.sh` - Automated deployment script

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
