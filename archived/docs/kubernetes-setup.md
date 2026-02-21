# Kubernetes Setup Guide for RCC Remote

## Table of Contents

- [Prerequisites](#prerequisites)
- [Cluster Requirements](#cluster-requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Storage](#storage)
- [Networking](#networking)
- [Security](#security)
- [Scaling](#scaling)
- [Upgrading](#upgrading)

## Prerequisites

- Kubernetes cluster 1.20+
- kubectl installed and configured
- Cluster admin access
- Storage provisioner or local volumes
- 3+ worker nodes (for HA)

## Cluster Requirements

### Resources

**Minimum (single instance):**
- 2 CPU cores
- 4GB RAM
- 20GB storage

**Recommended (HA, 3 replicas):**
- 6 CPU cores (2 per replica)
- 12GB RAM (4GB per replica)
- 100GB storage

### Network

- Ingress controller (optional, for external access)
- LoadBalancer support (or NodePort)
- DNS resolution for services

## Installation

### Quick Install

```bash
# 1. Deploy with automation script
cd rccremote-docker
./scripts/deploy-k8s.sh --namespace rccremote --replicas 3

# 2. Verify deployment
kubectl get all -n rccremote
```

### Manual Install

#### Step 1: Create Namespace

```bash
kubectl create namespace rccremote
kubectl label namespace rccremote environment=production
```

#### Step 2: Configure Storage

```bash
# Apply PersistentVolume and PVC
kubectl apply -f k8s/persistent-volume.yaml
```

#### Step 3: Configure Certificates

**Option A: Use init container (auto-generate)**
```bash
# Certificates will be auto-generated on first startup
kubectl apply -f k8s/secret.yaml
```

**Option B: Use existing certificates**
```bash
# Create secret from files
kubectl create secret tls rccremote-certs \
  --cert=./certs/server.crt \
  --key=./certs/server.key \
  -n rccremote

# Add CA certificate
kubectl create secret generic rccremote-ca-bundle \
  --from-file=ca-bundle.crt=./certs/rootCA.pem \
  -n rccremote
```

#### Step 4: Deploy Application

```bash
# Apply manifests in order
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml  # Optional

# Wait for deployment
kubectl wait --for=condition=available deployment/rccremote \
  -n rccremote --timeout=300s
```

## Configuration

### ConfigMap

Edit `k8s/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rccremote-config
  namespace: rccremote
data:
  SERVER_NAME: "rccremote.example.com"  # Update this
  ROBOCORP_HOME: "/opt/robocorp"
  RCCREMOTE_HOSTNAME: "0.0.0.0"
  RCCREMOTE_PORT: "4653"
```

Apply changes:
```bash
kubectl apply -f k8s/configmap.yaml
kubectl rollout restart deployment/rccremote -n rccremote
```

### Resource Limits

Edit `k8s/deployment.yaml`:

```yaml
resources:
  requests:
    memory: "1Gi"      # Increase for large catalogs
    cpu: "500m"        # Increase for high load
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### Replicas

```bash
# Edit HPA for autoscaling
kubectl edit hpa rccremote-hpa -n rccremote

# Or scale manually
kubectl scale deployment rccremote --replicas=5 -n rccremote
```

## Storage

### PersistentVolume Configuration

**Local Storage:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: rccremote-holotree-pv
spec:
  storageClassName: manual
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/rccremote/holotree"
```

**NFS Storage:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: rccremote-holotree-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: nfs-server.example.com
    path: "/exports/rccremote/holotree"
```

**Cloud Storage (AWS EBS):**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: rccremote-holotree-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  awsElasticBlockStore:
    volumeID: <volume-id>
    fsType: ext4
```

### Backup Strategy

```bash
# Backup holotree data
kubectl exec -n rccremote <pod-name> -- \
  tar czf /tmp/holotree-backup.tar.gz -C /opt/robocorp .

kubectl cp rccremote/<pod-name>:/tmp/holotree-backup.tar.gz \
  ./backups/holotree-$(date +%Y%m%d).tar.gz
```

## Networking

### Service Configuration

**ClusterIP (internal only):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: rccremote
  namespace: rccremote
spec:
  type: ClusterIP
  selector:
    app: rccremote
  ports:
  - port: 443
    targetPort: 443
```

**LoadBalancer (external access):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: rccremote-lb
  namespace: rccremote
spec:
  type: LoadBalancer
  selector:
    app: rccremote
  ports:
  - port: 443
    targetPort: 443
```

### Ingress Configuration

**Nginx Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rccremote-ingress
  namespace: rccremote
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  tls:
  - hosts:
    - rccremote.example.com
    secretName: rccremote-tls
  rules:
  - host: rccremote.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rccremote
            port:
              number: 443
```

### DNS Configuration

**Internal DNS:**
- ClusterIP Service: `rccremote.rccremote.svc.cluster.local`
- Short name (same namespace): `rccremote`

**External DNS:**
- Configure DNS A record pointing to LoadBalancer IP
- Or use ExternalDNS for automatic DNS management

## Security

### RBAC Configuration

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
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rccremote-rolebinding
  namespace: rccremote
subjects:
- kind: ServiceAccount
  name: rccremote
  namespace: rccremote
roleRef:
  kind: Role
  name: rccremote-role
  apiGroup: rbac.authorization.k8s.io
```

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: rccremote-netpol
  namespace: rccremote
spec:
  podSelector:
    matchLabels:
      app: rccremote
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}  # Allow from any namespace
    ports:
    - protocol: TCP
      port: 443
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53  # DNS
  - to:
    - podSelector:
        matchLabels:
          app: rccremote
```

### Pod Security Policy

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: rccremote-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  readOnlyRootFilesystem: false
```

## Scaling

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: rccremote-hpa
  namespace: rccremote
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rccremote
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Vertical Pod Autoscaler (Optional)

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: rccremote-vpa
  namespace: rccremote
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: rccremote
  updatePolicy:
    updateMode: "Auto"
```

## Upgrading

### Update Strategy

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # Zero downtime
```

### Upgrade Process

```bash
# 1. Update image in deployment
kubectl set image deployment/rccremote \
  rccremote=rccremote:v2.0.0 \
  -n rccremote

# 2. Monitor rollout
kubectl rollout status deployment/rccremote -n rccremote

# 3. Verify
kubectl get pods -n rccremote
./scripts/health-check.sh

# 4. Rollback if needed
kubectl rollout undo deployment/rccremote -n rccremote
```

### Configuration Updates

```bash
# Update ConfigMap
kubectl apply -f k8s/configmap.yaml

# Restart pods to pick up changes
kubectl rollout restart deployment/rccremote -n rccremote
```

## Monitoring

### Health Checks

```bash
# Check pod health
kubectl get pods -n rccremote

# Check events
kubectl get events -n rccremote --sort-by='.lastTimestamp'

# Test health endpoints
kubectl port-forward -n rccremote svc/rccremote 8443:443
curl -k https://localhost:8443/health/live
```

### Logs

```bash
# All pods
kubectl logs -n rccremote -l app=rccremote --all-containers

# Specific pod
kubectl logs -n rccremote <pod-name> -c rccremote --tail=100 -f

# Previous pod instance
kubectl logs -n rccremote <pod-name> -c rccremote --previous
```

### Resource Usage

```bash
# Metrics server required
kubectl top pods -n rccremote
kubectl top nodes
```

## Troubleshooting

### Pod Not Starting

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n rccremote

# Check logs
kubectl logs <pod-name> -n rccremote

# Check init container
kubectl logs <pod-name> -c cert-init -n rccremote
```

### Storage Issues

```bash
# Check PV/PVC status
kubectl get pv,pvc -n rccremote

# Describe PVC for binding issues
kubectl describe pvc rccremote-holotree-pvc -n rccremote
```

### Network Issues

```bash
# Test internal connectivity
kubectl run -it --rm debug --image=alpine --restart=Never -n rccremote -- \
  wget -O- https://rccremote.rccremote.svc.cluster.local:443/health/live

# Check service endpoints
kubectl get endpoints -n rccremote
```

## Next Steps

- [Deployment Guide](deployment-guide.md)
- [ARC Integration](arc-integration.md)
- [Troubleshooting](troubleshooting.md)
