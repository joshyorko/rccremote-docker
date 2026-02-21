# RCC Remote Docker - Troubleshooting Guide

## Common Issues

### 1. Certificate Errors

#### Symptom
- "SSL certificate verification failed"
- "unable to verify the first certificate"
- Connection refused with SSL

#### Diagnosis
```bash
# Test SSL connection
openssl s_client -connect rccremote.local:443

# Validate certificates
./scripts/cert-management.sh validate

# Check certificate expiry
openssl x509 -in certs/server.crt -noout -dates
```

#### Solutions

**Self-signed certificate not trusted:**
```bash
# Option 1: Use skip-ssl-verify profile
rcc config switch -p ssl-noverify

# Option 2: Install CA certificate
sudo cp certs/rootCA.pem /usr/local/share/ca-certificates/rccremote.crt
sudo update-ca-certificates

# Option 3: Configure RCC profile with CA
./scripts/cert-management.sh export
# Follow instructions in certs/client-export/README.md
```

**Certificate expired:**
```bash
# Renew certificate
./scripts/cert-management.sh renew

# Restart services
docker-compose restart  # Docker Compose
kubectl rollout restart deployment/rccremote -n rccremote  # Kubernetes
```

**SAN not matching:**
```bash
# Regenerate with correct SERVER_NAME
export SERVER_NAME=your-actual-hostname.com
./scripts/cert-management.sh generate-ca-signed --server-name $SERVER_NAME
```

### 2. Deployment Timeouts

#### Symptom
- Deployment takes >5 minutes
- Pods stuck in "ContainerCreating" or "Pending"
- Health checks never pass

#### Diagnosis
```bash
# Docker Compose
docker-compose logs rccremote --tail 100

# Kubernetes
kubectl describe pod <pod-name> -n rccremote
kubectl logs <pod-name> -c rccremote -n rccremote --tail 100
```

#### Solutions

**Large catalog builds:**
```bash
# Pre-build catalogs and mount as volumes
cd data/robots/myrobot
rcc holotree export -r robot.yaml -z myrobot.zip
mv myrobot.zip ../../hololib_zip/

# Update compose/k8s to skip builds
```

**Storage issues:**
```bash
# Check disk space
df -h

# Kubernetes: Check PV/PVC
kubectl get pv,pvc -n rccremote
kubectl describe pvc rccremote-holotree-pvc -n rccremote

# Clean up old data
docker volume rm rccremote-docker_robocorp_data  # Careful!
```

**Insufficient resources:**
```bash
# Increase resource limits
# Edit docker-compose.yml or k8s/deployment.yaml
resources:
  limits:
    memory: 4Gi  # Increase from 2Gi
    cpu: 2       # Increase from 1
```

### 3. RCC Client Cannot Connect

#### Symptom
- `rcc holotree vars` fails
- "connection refused"
- "remote error: tls: handshake failure"

#### Diagnosis
```bash
# Test health endpoint
curl -k https://rccremote.local:443/health/live

# Test connectivity
./scripts/test-connectivity.sh --origin https://rccremote.local:443

# Check RCC configuration
rcc config diag
```

#### Solutions

**Wrong RCC_REMOTE_ORIGIN:**
```bash
# Set correct origin
export RCC_REMOTE_ORIGIN=https://rccremote.local:443

# Or in robot directory .env
echo "RCC_REMOTE_ORIGIN=https://rccremote.local:443" > .env
```

**Firewall blocking:**
```bash
# Test from same network
telnet rccremote.local 443

# Check iptables/firewall rules
sudo iptables -L -n | grep 443
```

**DNS resolution:**
```bash
# Add to /etc/hosts if needed
echo "127.0.0.1 rccremote.local" | sudo tee -a /etc/hosts

# Or use IP directly
export RCC_REMOTE_ORIGIN=https://192.168.1.100:443
```

### 4. Health Checks Failing

#### Symptom
- `/health/live` returns non-200
- `/health/ready` returns 503
- Kubernetes pods not ready

#### Diagnosis
```bash
# Check all health endpoints
./scripts/health-check.sh --verbose

# Manual check
curl -k https://rccremote.local:443/health/live | jq .
curl -k https://rccremote.local:443/health/ready | jq .
curl -k https://rccremote.local:443/health/startup | jq .
```

#### Solutions

**Startup still in progress:**
```bash
# Wait longer, check startup probe
kubectl get pods -n rccremote -w

# Increase startup probe threshold in k8s/deployment.yaml
startupProbe:
  failureThreshold: 60  # Increase from 30
```

**RCC not initialized:**
```bash
# Check RCC holotree
docker exec rccremote-dev rcc ht catalogs
kubectl exec <pod> -n rccremote -- rcc ht catalogs

# Reinitialize if needed
docker exec rccremote-dev rcc ht shared -e
docker exec rccremote-dev rcc ht init
```

**Port conflicts:**
```bash
# Check if port 4653 is in use
sudo netstat -tulpn | grep 4653
sudo lsof -i :4653

# Kill conflicting process or use different port
```

### 5. Performance Issues

#### Symptom
- Slow catalog downloads
- High CPU/memory usage
- Response times >5 seconds

#### Diagnosis
```bash
# Check resource usage
docker stats

# Kubernetes
kubectl top pods -n rccremote
kubectl top nodes

# Check for bottlenecks
kubectl logs -n rccremote <pod> | grep -i "slow\|timeout\|error"
```

#### Solutions

**Insufficient replicas:**
```bash
# Scale up
kubectl scale deployment rccremote --replicas=5 -n rccremote

# Or enable HPA
kubectl apply -f k8s/deployment.yaml  # Includes HPA
```

**Storage I/O bottleneck:**
```bash
# Use faster storage class
# Edit k8s/persistent-volume.yaml
storageClassName: ssd  # Instead of 'manual'

# Or use network storage with better IOPS
```

**Network bandwidth:**
```bash
# Test network speed
iperf3 -c rccremote.local -p 4653

# Consider increasing pod network resources
```

### 6. Container Startup Failures

#### Symptom
- Container exits immediately
- CrashLoopBackOff (Kubernetes)
- Exit code errors

#### Diagnosis
```bash
# Check logs
docker logs rccremote-dev --tail 200

# Kubernetes
kubectl logs <pod> -n rccremote --previous
kubectl describe pod <pod> -n rccremote
```

#### Solutions

**Permission errors:**
```bash
# Check volume permissions
ls -la data/robots
ls -la data/hololib_zip

# Fix permissions
chmod -R 755 data/robots
chown -R 1000:1000 data/  # UID 1000 is container user
```

**Missing dependencies:**
```bash
# Rebuild Docker image
docker-compose build --no-cache

# Or pull latest
docker pull rccremote:latest
```

**Configuration errors:**
```bash
# Validate environment variables
docker-compose config

# Kubernetes
kubectl get configmap rccremote-config -n rccremote -o yaml
```

## Debugging Tools

### Enable Debug Logging

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

### Interactive Shell

**Docker:**
```bash
docker exec -it rccremote-dev bash
```

**Kubernetes:**
```bash
kubectl exec -it <pod> -n rccremote -- bash
```

### Network Debugging

```bash
# Test from debug pod
kubectl run -it --rm debug --image=alpine --restart=Never -n rccremote -- sh

# Inside pod
apk add curl
curl -k https://rccremote.rccremote.svc.cluster.local:443/health/live
```

## Log Collection

### Docker Compose

```bash
# Collect all logs
docker-compose logs > rccremote-logs.txt

# With timestamps
docker-compose logs -t > rccremote-logs-timestamped.txt
```

### Kubernetes

```bash
# Collect logs from all pods
kubectl logs -n rccremote -l app=rccremote --all-containers > rccremote-k8s-logs.txt

# Collect events
kubectl get events -n rccremote --sort-by='.lastTimestamp' > rccremote-events.txt

# Collect pod descriptions
kubectl describe pods -n rccremote > rccremote-pod-descriptions.txt
```

## Getting Help

### Before Opening an Issue

1. Check this troubleshooting guide
2. Review deployment logs
3. Verify prerequisites met
4. Test with minimal configuration
5. Collect diagnostic information

### Diagnostic Information to Include

```bash
# Version information
docker --version
docker-compose --version
kubectl version

# System information
uname -a
df -h
free -h

# RCC information
rcc version
rcc config diag

# Service status
docker ps -a  # Docker Compose
kubectl get all -n rccremote  # Kubernetes

# Logs (last 100 lines)
# Include relevant log snippets
```

### Support Resources

- **GitHub Issues:** https://github.com/yorko-io/rccremote-docker/issues
- **Documentation:** https://github.com/yorko-io/rccremote-docker/tree/main/docs
- **RCC Documentation:** https://sema4.ai/docs/automation/rcc/overview

## Next Steps

- [Deployment Guide](deployment-guide.md)
- [Kubernetes Setup](kubernetes-setup.md)
- [ARC Integration](arc-integration.md)
