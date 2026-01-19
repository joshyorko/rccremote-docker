# ARC Runner Integration Guide

## Overview

This guide explains how to integrate RCC Remote with GitHub Actions Runner Controller (ARC) for automated environment provisioning in Kubernetes-based CI/CD pipelines.

## Prerequisites

- Kubernetes cluster with RCC Remote deployed
- ARC (Actions Runner Controller) installed
- Same namespace deployment (recommended)

## Architecture

```
ARC Runner Pod → RCC Remote Service → Catalog Cache → Environment Creation
```

## Setup

### 1. Deploy RCC Remote in ARC Namespace

```bash
# Deploy to actions namespace
./scripts/deploy-k8s.sh --namespace actions --replicas 3

# Verify service DNS
kubectl get svc -n actions rccremote
# Service: rccremote.actions.svc.cluster.local
```

### 2. Configure RCC in Runner Pods

Add to RunnerDeployment manifest:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: arc-runner
  namespace: actions
spec:
  template:
    spec:
      initContainers:
      - name: setup-rcc
        image: rccremote:latest
        command:
        - sh
        - -c
        - |
          # Install RCC
          wget -O /rcc-bin/rcc https://github.com/joshyorko/rcc/releases/download/v18.7.0/rcc-linux64
          chmod +x /rcc-bin/rcc
          
          # Configure SSL profile
          cat > /tmp/rcc-profile.yaml <<EOF
          profiles:
            arc-rccremote:
              description: ARC with RCC Remote
              settings:
                verify-ssl: true
                ca-bundle: |
          $(cat /certs/rootCA.pem | sed 's/^/        /')
          EOF
          
          /rcc-bin/rcc config import -f /tmp/rcc-profile.yaml
          /rcc-bin/rcc config switch -p arc-rccremote
        volumeMounts:
        - name: rcc-bin
          mountPath: /rcc-bin
        - name: rcc-certs
          mountPath: /certs
      containers:
      - name: runner
        env:
        - name: RCC_REMOTE_ORIGIN
          value: "https://rccremote.actions.svc.cluster.local:443"
        - name: PATH
          value: "/rcc-bin:$(PATH)"
        volumeMounts:
        - name: rcc-bin
          mountPath: /rcc-bin
        - name: rcc-home
          mountPath: /opt/robocorp
      volumes:
      - name: rcc-bin
        emptyDir: {}
      - name: rcc-home
        emptyDir: {}
      - name: rcc-certs
        secret:
          secretName: rccremote-certs
```

### 3. Mount CA Certificate

```bash
# Extract CA from RCC Remote
kubectl get secret rccremote-certs -n actions \
  -o jsonpath='{.data.rootCA\.pem}' | base64 -d > rootCA.pem

# Create secret for runners
kubectl create secret generic rccremote-ca \
  --from-file=rootCA.pem=rootCA.pem \
  -n actions
```

### 4. Catalog Caching

Enable persistent volume for catalog caching:

```yaml
volumes:
- name: rcc-cache
  persistentVolumeClaim:
    claimName: rcc-cache-pvc
```

## Workflow Usage

### Example GitHub Actions Workflow

```yaml
name: Robot Test
on: [push]

jobs:
  test:
    runs-on: arc-runner
    steps:
    - uses: actions/checkout@v3
    
    - name: Run Robot
      run: |
        # RCC automatically uses RCC_REMOTE_ORIGIN
        rcc run --robot robot.yaml
```

## Resilience Configuration

### Catalog Caching

RCC Remote caches catalogs in persistent volumes. If connectivity is lost, cached catalogs are used.

**Configure cache:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rcc-cache-pvc
  namespace: actions
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
```

### Health Checks

ARC runners should check RCC Remote health before jobs:

```yaml
steps:
- name: Check RCC Remote
  run: |
    curl -kf https://rccremote.actions.svc.cluster.local:443/health/ready
```

## Scaling

### RCC Remote Scaling for ARC

```bash
# Scale based on runner count
# Rule: 1 RCC Remote replica per 20-30 concurrent runners

# For 100 runners
kubectl scale deployment rccremote --replicas=5 -n actions

# Or use HPA
kubectl autoscale deployment rccremote \
  --min=3 --max=10 \
  --cpu-percent=70 \
  -n actions
```

## Monitoring

### Metrics

Monitor RCC Remote usage from ARC runners:

```bash
# Check active connections
kubectl logs -n actions -l app=rccremote | grep "RCC REMOTE ORIGIN"

# Check catalog downloads
kubectl exec -n actions <rccremote-pod> -- rcc ht catalogs
```

## Troubleshooting

### Runner Cannot Connect

```bash
# Test from runner pod
kubectl exec -n actions <runner-pod> -- \
  curl -kv https://rccremote.actions.svc.cluster.local:443/health/live

# Check DNS resolution
kubectl exec -n actions <runner-pod> -- \
  nslookup rccremote.actions.svc.cluster.local
```

### SSL Verification Fails

```bash
# Verify CA certificate is mounted
kubectl exec -n actions <runner-pod> -- cat /certs/rootCA.pem

# Check RCC profile
kubectl exec -n actions <runner-pod> -- rcc config switch
```

### Slow Environment Creation

- Increase RCC Remote replicas
- Use faster storage for holotree
- Pre-build common catalogs

## Best Practices

1. **Co-location:** Deploy RCC Remote in same namespace as ARC
2. **Caching:** Use persistent volumes for catalog caching
3. **Monitoring:** Set up alerts for RCC Remote health
4. **Scaling:** Scale RCC Remote with runner count
5. **Security:** Use SSL verification with CA certificates

## Next Steps

- [Deployment Guide](deployment-guide.md)
- [Kubernetes Setup](kubernetes-setup.md)
- [Troubleshooting](troubleshooting.md)
