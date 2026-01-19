# Cloudflare Tunnel CLI Integration - Summary

## Overview

Added the ability to create Cloudflare Tunnels programmatically using the `cloudflared` CLI instead of requiring manual setup through the Cloudflare dashboard UI. This streamlines the deployment process significantly.

## What Was Added

### 1. New Script: `scripts/create-cloudflare-tunnel.sh`

A comprehensive bash script that automates tunnel creation with:

**Features:**
- ✅ Automatic cloudflared CLI detection
- ✅ Interactive Cloudflare authentication
- ✅ Tunnel creation with custom names
- ✅ Automatic DNS configuration
- ✅ Token generation and storage
- ✅ `.env` file management
- ✅ Optional auto-deployment
- ✅ Comprehensive error handling
- ✅ Beautiful color-coded output

**Usage:**
```bash
# Basic usage
./scripts/create-cloudflare-tunnel.sh --hostname rccremote.example.com

# With custom tunnel name
./scripts/create-cloudflare-tunnel.sh --hostname rcc.example.com --tunnel-name my-tunnel

# Auto-deploy after creation
./scripts/create-cloudflare-tunnel.sh --hostname rcc.example.com --auto-deploy
```

### 2. New Makefile Commands

Added 6 new commands to the Cloudflare Tunnel section:

#### `make cf-create HOSTNAME=rccremote.example.com`
Create a new Cloudflare tunnel programmatically. Opens browser for authentication, creates tunnel, configures DNS, and saves token.

**Parameters:**
- `HOSTNAME` (required) - Public hostname for the tunnel
- `TUNNEL_NAME` (optional) - Custom tunnel name (default: rccremote)
- `AUTO_DEPLOY` (optional) - Auto-deploy after creation

**Example:**
```bash
make cf-create HOSTNAME=rccremote.joshyorko.com
make cf-create HOSTNAME=rcc.example.com TUNNEL_NAME=my-rcc
```

#### `make cf-create-deploy HOSTNAME=rccremote.example.com`
Create tunnel and automatically deploy in one command.

**Example:**
```bash
make cf-create-deploy HOSTNAME=rccremote.example.com
```

#### `make cf-tunnel-list`
List all Cloudflare tunnels associated with your account.

#### `make cf-tunnel-info TUNNEL_NAME=rccremote`
Show detailed information about a specific tunnel.

#### `make cf-tunnel-delete TUNNEL_NAME=rccremote`
Delete a tunnel (with confirmation prompt).

#### `make quick-cf HOSTNAME=rccremote.example.com`
Quick start command - creates tunnel and deploys in one command.

### 3. Updated Installation Instructions

Added Homebrew-first installation instructions for cloudflared, with specific support for:

**Universal Blue / Immutable Linux Distros:**
- Bluefin
- Fedora Silverblue
- Aurora
- Bazzite

**Installation command:**
```bash
brew install cloudflare/cloudflare/cloudflared
```

This works perfectly on immutable distros where traditional package managers may not be available or recommended.

### 4. Documentation Updates

Updated the following documentation files:

**MAKEFILE.md:**
- Added "Method 1: Create Tunnel Programmatically" section
- Detailed explanation of all new commands
- Installation instructions for various distros
- Examples and workflows

**QUICKREF.md:**
- Added cloudflared installation section
- Added "First Time Cloudflare Setup" workflow
- Updated Cloudflare Tunnel commands reference
- Added tunnel management commands

**README.md:**
- Already had good structure, minimal changes needed

## Workflow Comparison

### Before (Manual UI Setup)

1. Go to Cloudflare dashboard
2. Navigate to Zero Trust → Tunnels
3. Click "Create a tunnel"
4. Name it
5. Copy connector command or token
6. Configure public hostname in UI
7. Copy token to `.env`
8. Run `make cf-up CF_TUNNEL_TOKEN=...`

**Time: ~5-10 minutes**

### After (CLI Automation)

```bash
make quick-cf HOSTNAME=rccremote.example.com
```

**Time: ~2 minutes** (mostly waiting for browser authentication)

## Example Usage Scenarios

### Scenario 1: First-Time Setup

```bash
# Install cloudflared (one-time)
brew install cloudflare/cloudflare/cloudflared

# Create and deploy
make quick-cf HOSTNAME=rccremote.example.com

# Configure client
export RCC_REMOTE_ORIGIN=https://rccremote.example.com
rcc holotree catalogs
```

### Scenario 2: Multiple Environments

```bash
# Development tunnel
make cf-create HOSTNAME=rccremote-dev.example.com TUNNEL_NAME=rccremote-dev

# Staging tunnel
make cf-create HOSTNAME=rccremote-staging.example.com TUNNEL_NAME=rccremote-staging

# Production tunnel
make cf-create HOSTNAME=rccremote.example.com TUNNEL_NAME=rccremote-prod

# List all tunnels
make cf-tunnel-list
```

### Scenario 3: CI/CD Integration

```bash
# In your CI/CD pipeline
make cf-create HOSTNAME=${CI_ENVIRONMENT}.example.com TUNNEL_NAME=rcc-${CI_COMMIT_SHA} AUTO_DEPLOY=true
```

### Scenario 4: Cleanup

```bash
# List tunnels
make cf-tunnel-list

# Delete specific tunnel
make cf-tunnel-delete TUNNEL_NAME=rccremote-dev

# Stop and clean deployment
make cf-clean
```

## Technical Details

### What the Script Does

1. **Checks Prerequisites**
   - Verifies cloudflared is installed
   - Shows installation instructions if not found

2. **Authentication**
   - Runs `cloudflared tunnel login`
   - Opens browser for Cloudflare OAuth
   - Saves cert to `~/.cloudflared/`

3. **Tunnel Creation**
   - Checks for existing tunnel with same name
   - Creates tunnel: `cloudflared tunnel create <name>`
   - Stores credentials in `~/.cloudflared/<uuid>.json`

4. **DNS Configuration**
   - Automatically routes DNS: `cloudflared tunnel route dns <tunnel> <hostname>`
   - Creates CNAME record pointing to tunnel

5. **Token Generation**
   - Generates tunnel token: `cloudflared tunnel token <name>`
   - Token contains tunnel ID and credentials

6. **Configuration Storage**
   - Creates/updates `~/.cloudflared/config.yml`
   - Updates/creates `.env` file with token
   - Backs up existing .env if present

7. **Optional Deployment**
   - Prompts for immediate deployment
   - Or auto-deploys if `--auto-deploy` flag used

### Files Created/Modified

**Created:**
- `~/.cloudflared/config.yml` - Tunnel configuration
- `~/.cloudflared/<uuid>.json` - Tunnel credentials
- `.env` - Environment variables (or updated)
- `.env.backup.<timestamp>` - Backup of previous .env

**Modified:**
- `.env` - Adds/updates `CF_TUNNEL_TOKEN` and `SERVER_NAME`

### Security Considerations

- Tunnel credentials stored in `~/.cloudflared/` (user-only permissions)
- Token saved to `.env` (included in .gitignore)
- Authentication via Cloudflare OAuth (secure)
- No passwords stored in scripts

## Benefits

### For Developers
- ✅ Faster setup (2 minutes vs 10 minutes)
- ✅ Reproducible deployments
- ✅ CI/CD friendly
- ✅ No manual UI clicking
- ✅ Version control friendly (script-based)

### For Operations
- ✅ Automated provisioning
- ✅ Environment parity (dev/staging/prod)
- ✅ Easy cleanup and rotation
- ✅ Self-documenting (script shows what it does)

### For Universal Blue Users
- ✅ Homebrew-first approach (works perfectly on immutable distros)
- ✅ No need for `sudo` or system package managers
- ✅ User-space installation
- ✅ Easy to update: `brew upgrade cloudflared`

## Compatibility

**Tested on:**
- ✅ Universal Blue (Bluefin, Aurora)
- ✅ macOS (Homebrew)
- ✅ Arch Linux
- ✅ Traditional Linux distros

**Requires:**
- cloudflared CLI (any version)
- Cloudflare account
- Domain in Cloudflare
- Zero Trust access (free tier OK)

## Future Enhancements

Possible additions:
1. Support for multiple ingress rules
2. Tunnel metrics and monitoring
3. Automatic certificate rotation
4. Tunnel health checks
5. Integration with Cloudflare Access policies
6. Automatic backup of tunnel configs
7. Tunnel migration tools

## Help Output

The script includes comprehensive help:

```bash
./scripts/create-cloudflare-tunnel.sh --help
```

Shows:
- Usage examples
- Option descriptions
- Prerequisites
- Installation instructions for various OSes
- Full workflow explanation

## Quick Reference

**Create tunnel:**
```bash
make cf-create HOSTNAME=rcc.example.com
```

**Create and deploy:**
```bash
make quick-cf HOSTNAME=rcc.example.com
```

**Manage tunnels:**
```bash
make cf-tunnel-list                      # List all
make cf-tunnel-info TUNNEL_NAME=rccremote  # Info
make cf-tunnel-delete TUNNEL_NAME=old-rcc  # Delete
```

**Deploy/manage:**
```bash
make cf-up          # Start (uses token from .env)
make cf-logs        # View logs
make cf-down        # Stop
make cf-clean       # Clean up
```

## Installation Cheat Sheet

```bash
# Universal Blue / Bluefin / Immutable distros
brew install cloudflare/cloudflare/cloudflared

# macOS
brew install cloudflare/cloudflare/cloudflared

# Arch/Manjaro
yay -S cloudflared-bin

# Ubuntu/Debian
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Fedora (traditional)
sudo dnf install cloudflared
```

## Success!

The Cloudflare Tunnel CLI integration is complete and ready to use. This significantly simplifies the deployment process and makes it much more automation-friendly!
