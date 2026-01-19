# RCC Remote Architecture

## Overview

This document clarifies the architecture and explains the separation between server and client configurations.

## Two Contexts: Server vs Client

### Server Context (rccremote container)

**Location**: Inside Docker/Kubernetes containers running rccremote

**Purpose**: 
- Build environment catalogs from robot definitions
- Serve catalogs to remote clients via HTTPS
- Maintain persistent shared holotree

**Configuration**:
- `ROBOCORP_HOME=/opt/robocorp` (required)
- Shared holotree enabled
- Docker volume `robocorp_data` mounted at `/opt/robocorp`
- Runs rccremote service on port 4653 (behind nginx on 443/8443)

**Why `/opt/robocorp`?**
- System-wide location suitable for container environments
- Persistent via Docker volumes
- Enables shared holotree for catalog management
- Multiple processes can access the same holotree

### Client Context (user machines)

**Location**: User's workstation or any machine running RCC

**Purpose**:
- Connect to rccremote server
- Download and cache environment catalogs
- Run robots using environments from remote server

**Configuration**:
- `RCC_REMOTE_ORIGIN=https://rccremote.local:8443` (required)
- Uses default `~/.robocorp` (recommended)
- No special ROBOCORP_HOME needed
- SSL profile configured to trust server certificate

**Why `~/.robocorp`?**
- Standard RCC default location
- No elevated permissions required
- User-specific isolation
- No need to modify system directories

## Data Flow

```
Client Machine (~/. robocorp)
    ↓ (HTTPS with SSL verification)
    ↓ export RCC_REMOTE_ORIGIN=https://rccremote.local:8443
    ↓
nginx:443/8443 (SSL termination)
    ↓ (HTTP)
rccremote:4653 (/opt/robocorp)
    ↓
Catalogs served from shared holotree
```

## Configuration Scripts

### `scripts/configure-rcc-profile.sh`

**Context**: Client-side only

**What it does**:
1. Creates `~/.robocorp` directory if needed
2. Configures SSL profile with Root CA certificate
3. Imports profile into RCC configuration
4. Instructs user to set `RCC_REMOTE_ORIGIN`

**What it does NOT do**:
- Does NOT require `/opt/robocorp` on client
- Does NOT need sudo permissions
- Does NOT enable shared holotree on client

### `scripts/entrypoint-rcc.sh`

**Context**: Server-side only (inside container)

**What it does**:
1. Builds catalogs from `/robots` directories
2. Enables shared holotree at `/opt/robocorp`
3. Imports catalog ZIPs
4. Starts rccremote service

**Environment sourcing**:
- Sources `.env` files from robot directories
- Temporarily overrides `ROBOCORP_HOME` during catalog builds
- Restores environment after each build

## Docker Compose Volumes

### `robocorp_data`
- Mounted at: `/opt/robocorp` (container only)
- Purpose: Persistent holotree storage for server
- Scope: Server-side shared catalogs
- NOT used by clients

### `robotmk_rcc_home`
- Mounted at: `/opt/robotmk/rcc_home` (test containers)
- Purpose: Alternative RCC home for test clients
- Scope: Optional, for containerized testing

## Common Misconceptions

### ❌ "Clients must use `/opt/robocorp`"
**False**. Clients use `~/.robocorp` by default. Only the rccremote container needs `/opt/robocorp`.

### ❌ "ROBOCORP_HOME must match between client and server"
**False**. They are independent. The server builds and serves catalogs; clients download and cache them in their own location.

### ❌ "Clients need sudo to create `/opt/robocorp`"
**False**. Clients don't need this directory at all. The configure script now uses `~/.robocorp`.

### ✅ "Only RCC_REMOTE_ORIGIN is needed on clients"
**True**. Plus SSL configuration, which the configure script handles automatically.

## Environment Variables

### Server (Docker Compose)
```bash
ROBOCORP_HOME=/opt/robocorp          # Required in container
RCC_REMOTE_ORIGIN=https://...        # Not used by server
SERVER_NAME=rccremote.local          # For certificate matching
```

### Client (User machine)
```bash
RCC_REMOTE_ORIGIN=https://rccremote.local:8443  # Required
ROBOCORP_HOME=~/.robocorp                        # Optional (default)
```

## Quick Reference

### I want to... deploy the server
```bash
./scripts/deploy-docker.sh --environment development
# Server uses /opt/robocorp inside container
```

### I want to... use the server from my machine
```bash
./scripts/configure-rcc-profile.sh
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443
rcc holotree catalogs
# Uses ~/.robocorp on your machine
```

### I want to... add a new robot
```bash
# Place robot in data/robots/my-robot/
# Restart server to rebuild catalogs
docker compose -f docker-compose/docker-compose.development.yml restart rccremote
```

### I want to... check available catalogs
```bash
# From server
docker exec rccremote-dev rcc holotree catalogs

# From client
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443
rcc holotree catalogs
```

## Troubleshooting

### "Client builds locally instead of using remote"
- Check `RCC_REMOTE_ORIGIN` is set
- Verify SSL profile is configured: `rcc config settings`
- Ensure catalog exists on server: `docker exec rccremote-dev rcc ht catalogs`

### "Permission denied creating /opt/robocorp"
- You're trying to set ROBOCORP_HOME=/opt/robocorp on client
- Solution: Don't set ROBOCORP_HOME, use default ~/.robocorp
- Run `./scripts/configure-rcc-profile.sh` again

### "SSL certificate verification failed"
- Run `./scripts/configure-rcc-profile.sh`
- Verify RCC profile: `rcc config settings | grep certificates`
- Check CA bundle exists: `ls ~/.robocorp/ca-bundle.pem`

## Migration from Old Setup

If you previously configured clients with `/opt/robocorp`:

1. Remove the old configuration:
   ```bash
   rcc config settings  # Note current profile name
   rcc config switch -p default  # Switch to default
   ```

2. Reconfigure with new setup:
   ```bash
   ./scripts/configure-rcc-profile.sh
   export RCC_REMOTE_ORIGIN=https://rccremote.local:8443
   ```

3. Update shell profile:
   ```bash
   # Remove from ~/.bashrc or ~/.zshrc:
   # export ROBOCORP_HOME=/opt/robocorp
   
   # Keep only:
   export RCC_REMOTE_ORIGIN=https://rccremote.local:8443
   ```

4. RCC will now use `~/.robocorp` automatically
