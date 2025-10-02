# Quick Start Guide - RCC Remote Workflow

This guide demonstrates the complete workflow for setting up and using RCC Remote with SSL verification.

## Prerequisites

- Docker and Docker Compose installed
- `sudo` access for installing CA certificates
- RCC client installed (optional - will be used for testing)

## Complete Workflow

### 1. Generate CA-Signed Certificates

From the repository root:

```bash
./scripts/cert-management.sh generate-ca-signed --server-name localhost
```

**What this does:**
- Creates a Root CA (Certificate Authority)
- Generates server certificate signed by the Root CA
- Stores certificates in `certs/` directory
- Includes proper Subject Alternative Names (SANs)

**Output files:**
- `certs/rootCA.crt` - Root CA certificate (for clients)
- `certs/rootCA.key` - Root CA private key
- `certs/rootCA.pem` - Root CA in PEM format
- `certs/server.crt` - Server certificate
- `certs/server.key` - Server private key

### 2. Install CA Certificate for RCC Clients

**Linux:**
```bash
sudo cp certs/rootCA.crt /usr/local/share/ca-certificates/rccremote-ca.crt
sudo update-ca-certificates
```

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/rootCA.crt
```

**Windows (PowerShell as Administrator):**
```powershell
certutil -addstore -f "ROOT" certs\rootCA.crt
```

**Why this is required:**
Installing the CA certificate allows RCC clients to verify the SSL connection to the RCC Remote server without certificate warnings.

### 3. Deploy RCC Remote

```bash
./scripts/deploy-docker.sh --environment development
```

**What this does:**
- Creates required directories (`data/robots`, `data/hololib_zip`)
- Builds Docker images for rccremote and nginx
- Starts containers with SSL enabled
- Builds catalogs from robots in `data/robots/`
- Starts rccremote server on port 4653 (behind nginx on 8443)

**Check deployment status:**
```bash
docker ps | grep rccremote
```

You should see:
- `rccremote-dev` - RCC Remote service container
- `rccremote-nginx-dev` - Nginx SSL reverse proxy

### 4. Verify Services

```bash
./scripts/health-check.sh --target localhost:8443
```

**Alternative verification:**
```bash
# Check container health
docker ps --filter "health=healthy" | grep rccremote

# View logs
docker logs rccremote-dev
docker logs rccremote-nginx-dev

# Test HTTPS endpoint
curl -k https://localhost:8443/
```

### 5. Install RCC Client (if not already installed)

```bash
# Linux
wget https://downloads.robocorp.com/rcc/releases/latest/linux64/rcc
chmod +x rcc
sudo mv rcc /usr/local/bin/

# Verify installation
rcc version
```

### 6. Test RCC Connectivity

```bash
# Set RCC Remote origin
export RCC_REMOTE_ORIGIN=https://localhost:8443

# Disable telemetry (optional)
rcc config identity -t

# Test with holotree vars
cd /path/to/your/robot
rcc holotree vars
```

**Expected output should include:**
```
Fill hololib from RCC_REMOTE_ORIGIN
```

This confirms RCC is successfully fetching environment catalogs from your RCC Remote server.

## Adding Your Own Robots

To make your robots available through RCC Remote:

1. Place your robot directories in `data/robots/`:
   ```
   data/robots/
   ├── my-robot-1/
   │   ├── robot.yaml
   │   ├── conda.yaml
   │   └── .env (optional)
   └── my-robot-2/
       ├── robot.yaml
       └── conda.yaml
   ```

2. Restart the containers to rebuild catalogs:
   ```bash
   cd scripts
   docker compose -f ../examples/docker-compose.development.yml down
   ./deploy-docker.sh --environment development
   ```

3. Verify catalogs are available:
   ```bash
   docker logs rccremote-dev 2>&1 | grep "Holotree catalogs:"
   ```

## Using Pre-Built Catalogs (Cross-Platform)

If you've built catalogs on a different platform (e.g., Windows), you can import them:

1. Export the catalog as a ZIP on the build machine:
   ```bash
   rcc holotree export -r robot.yaml -z my-robot.zip
   ```

2. Copy the ZIP file to `data/hololib_zip/` on the RCC Remote server

3. Restart the containers to import the catalog

## Troubleshooting

### RCC shows SSL errors

Make sure the Root CA certificate is installed in your system's trust store (step 2).

### RCC builds locally instead of fetching from remote

This can happen if:
- The exact environment doesn't exist in the remote catalogs yet
- RCC Remote is not accessible
- The `RCC_REMOTE_ORIGIN` environment variable is not set

### Containers not starting

Check logs:
```bash
docker logs rccremote-dev
docker logs rccremote-nginx-dev
```

Common issues:
- Port 8443 already in use
- Missing robot files in `data/robots/`
- Certificate generation failed

### No catalogs available

Check if robots were found during build:
```bash
docker logs rccremote-dev 2>&1 | grep "Robot:"
```

Make sure each robot directory has both `robot.yaml` and `conda.yaml`.

## Production Deployment

For production use, use the production compose file:

```bash
./scripts/deploy-docker.sh --environment production --server-name your-domain.com
```

This deploys on port 443 instead of 8443 and uses production-grade settings.

## Testing the Complete Workflow

Run the automated integration test:

```bash
./tests/integration/test_complete_workflow.sh
```

This tests all steps from certificate generation through RCC connectivity.

## Next Steps

- Configure your robots in `data/robots/`
- Set up monitoring and health checks
- Scale to multiple replicas (Kubernetes)
- Configure custom SSL certificates for production
- Set up automated catalog updates

## References

- [RCC Documentation](https://sema4.ai/docs/automation/rcc/overview)
- [Deployment Guide](../docs/deployment-guide.md)
- [Troubleshooting Guide](../docs/troubleshooting.md)
