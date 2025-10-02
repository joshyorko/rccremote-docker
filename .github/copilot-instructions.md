# RCC Remote Docker - Copilot Instructions

## Project Overview

This is a containerized SSL-enabled setup for [RCCRemote](https://sema4.ai/docs/automation/rcc/overview) - a service that serves RCC environment blueprints (catalogs) to isolated RCC clients that cannot access the internet directly. The architecture uses nginx as an SSL reverse proxy fronting the rccremote service.

## Architecture & Data Flow

```
rcc client --HTTPS--> nginx:443 --HTTP--> rccremote:4653
```

**Key concepts:**
- **Hololib**: Collection of available environment catalogs (blueprints)
- **Holotree**: Collection of available spaces (environment instances)
- **Catalog**: Environment blueprint that can create multiple instances
- **Space**: Actual environment instance created from a catalog

## Container Structure

- `rccremote`: Main service container running Ubuntu with RCC v17.28.4 and rccremote v17.18.0
- `nginx`: SSL reverse proxy with auto-generated or custom certificates
- `rcc`: Optional test client container (commented by default)

## Critical File Patterns

### Robot Structure
Robot directories in `/data/robots/` must contain:
- `robot.yaml`: Task definitions and environment configs
- `conda.yaml`: Dependency specifications
- `.env` (optional): Custom `ROBOCORP_HOME` path for environment builds

### Certificate Management
- Place custom certs in `/certs/`: `server.crt`, `server.key`, `rootCA.pem`
- Auto-generation creates self-signed certs if `/certs/` is empty
- Server name controlled by `SERVER_NAME` environment variable

## Key Workflows

### Container Startup Sequence (rccremote mode)
1. Build hololibs from `/robots/` directories with `robot.yaml`+`conda.yaml`
2. Export built environments to ZIP files in `/hololib_zip_internal/`
3. Import internal ZIPs and external ZIPs from `/hololib_zip/`
4. Initialize shared holotree with `rcc ht shared -e && rcc ht init`
5. Start rccremote server on port 4653

### Environment Variable Sourcing
The entrypoint script sources `.env` files from robot directories to set custom `ROBOCORP_HOME` paths before building catalogs, enabling cross-platform environment compatibility.

### SSL Profile Auto-Configuration
RCC client containers auto-configure SSL profiles based on certificate presence:
- If `rootCA.pem` exists: Uses `ssl-cabundle` profile with verification
- Otherwise: Uses `ssl-noverify` profile with `verify-ssl: false`

## Volume Mappings & Data Persistence

- `./data/robots/` → `/robots`: Source robot definitions
- `./data/hololib_zip/` → `/hololib_zip`: Pre-built catalog imports
- `./certs/` → `/etc/certs`: SSL certificates
- `hololib_zip_internal`: Internal build artifacts
- `robocorp_data`: Shared holotree data at `/opt/robocorp`
- `robotmk_rcc_home`: RCC home directories at `/opt/robotmk/rcc_home`

## Development Commands

### Testing Connection
```bash
# Test SSL without root CA
openssl s_client -connect rccremote.local:443

# Test with root CA
openssl s_client -connect rccremote.local:443 -CAfile /etc/certs/rootCA.crt
```

### RCC Client Testing
```bash
# Start test client
docker compose up -d rcc
docker exec -it rcc bash

# Verify hololib fetching
cd /robots/rf7
rcc holotree vars  # Should download from rccremote
```

### Certificate Generation
```bash
cd scripts
./create-signed-cert.sh  # Creates signed certificates with rootCA
./create-selfsigned-cert.sh  # Creates self-signed certificates
```

## Configuration Templates

- `config/nginx.conf.template`: Nginx SSL proxy config with `${SERVER_NAME}` substitution
- `config/rcc-profiles.d/`: SSL profile templates for RCC client configuration
- `scripts/openssl.cnf.template`: OpenSSL configuration for certificate generation

## Common Gotchas

- Robot builds happen inside Linux containers, so catalogs are Linux-only unless using pre-built cross-platform ZIPs
- The `ROBOCORP_HOME` path in robot `.env` files must match target client system paths exactly
- RCC telemetry is disabled by default via `rcc config identity -t`
- Environment restoration after `.env` sourcing uses temporary saved state to avoid variable pollution
