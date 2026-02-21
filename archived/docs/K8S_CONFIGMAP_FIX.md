# Kubernetes ConfigMap Fix Guide

## Problem

Your deployment is failing with:
```
MountVolume.SetUp failed for volume "scripts" : configmap "rccremote-scripts" not found
MountVolume.SetUp failed for volume "nginx-config" : configmap "rccremote-nginx-config" not found
```

## Solution

The ConfigMaps were missing from the original manifests. They've now been added to `k8s/configmap.yaml`.

### Quick Fix (One Command)

```bash
make k8s-fix-config
```

This will:
1. Apply the updated ConfigMaps
2. Restart the deployment
3. Wait for rollout to complete

### Manual Fix (Step by Step)

```bash
# 1. Apply the ConfigMaps
make k8s-apply-config

# 2. Restart the deployment
make k8s-restart

# 3. Check status
make k8s-status

# 4. Watch the pods
kubectl get pods -n rccremote -w
```

### Alternative: Full Reinstall

If you want a clean slate:

```bash
# 1. Uninstall everything
make k8s-uninstall

# 2. Redeploy
make k8s-deploy

# Or use quick command
make uninstall
make quick-k8s
```

## What Was Added

### 1. `rccremote-nginx-config` ConfigMap

Contains the nginx configuration for SSL termination and proxying to rccremote service.

**Key features:**
- SSL/TLS configuration
- Health check endpoints
- Proxy settings for rccremote backend
- Increased timeouts for large catalog transfers

### 2. `rccremote-scripts` ConfigMap

Contains the `entrypoint-rcc.sh` script that:
- Initializes holotree
- Builds catalogs from robot directories
- Imports catalog ZIP files
- Starts the rccremote server

### 3. New Makefile Commands

```bash
make k8s-apply-config     # Apply ConfigMaps only
make k8s-restart          # Restart deployment (rollout restart)
make k8s-fix-config       # Fix ConfigMaps and restart (recommended)
make k8s-uninstall        # Complete uninstall with namespace
make uninstall            # Auto-detect and uninstall any deployment
```

## Verification

After running `make k8s-fix-config`, verify the fix:

```bash
# Check pods are running
kubectl get pods -n rccremote

# Check ConfigMaps exist
kubectl get configmaps -n rccremote

# Check deployment status
make k8s-status

# View logs
make k8s-logs
```

You should see:
- Pods in `Running` state (not `Init` or `Error`)
- ConfigMaps: `rccremote-config`, `rccremote-nginx-config`, `rccremote-scripts`
- No mount errors in events

## Testing the Deployment

```bash
# Port forward to test locally
make k8s-port-forward

# In another terminal, test health endpoints
curl -k https://localhost:8443/health/live
curl -k https://localhost:8443/health/ready

# Configure RCC client
export RCC_REMOTE_ORIGIN=https://localhost:8443
rcc holotree catalogs
```

## Troubleshooting

### Pods still in Init state?

```bash
# Check pod details
kubectl describe pod -n rccremote <pod-name>

# Check events
make k8s-events

# View init container logs
kubectl logs -n rccremote <pod-name> -c cert-init
```

### ConfigMaps not updating?

```bash
# Force delete and reapply
kubectl delete configmap -n rccremote rccremote-nginx-config rccremote-scripts
make k8s-apply-config
make k8s-restart
```

### Need to start over?

```bash
# Complete cleanup and redeploy
make k8s-uninstall
make quick-k8s NAMESPACE=rccremote REPLICAS=3
```

## Next Steps

Once the deployment is running:

1. **Test connectivity:**
   ```bash
   make test-k8s
   ```

2. **Monitor the deployment:**
   ```bash
   make k8s-logs
   ```

3. **Configure ingress** (optional):
   ```bash
   kubectl apply -f k8s/ingress.yaml
   ```

4. **Set up auto-scaling:**
   The HPA (HorizontalPodAutoscaler) is already configured and will scale between 3-10 replicas based on CPU/memory usage.

5. **Add your robots:**
   - Create ConfigMap with robot definitions
   - Or mount a PersistentVolume with robots
   - Update and restart: `make k8s-fix-config`

## Summary

The issue was caused by missing ConfigMaps that the deployment expected. The fix:

1. ✅ Added `rccremote-nginx-config` ConfigMap
2. ✅ Added `rccremote-scripts` ConfigMap  
3. ✅ Added helper commands: `k8s-fix-config`, `k8s-restart`, `k8s-uninstall`
4. ✅ Added auto-detect `uninstall` command

**Run this now:**
```bash
make k8s-fix-config
```

Your deployment should be running within 1-2 minutes!
