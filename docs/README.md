# Documentation Index

## 📚 Current Documentation (Use These!)

### Primary Guides
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - ⭐ **Complete setup guide for all deployment modes** (Development, Production, Cloudflare, Kubernetes)
- **[troubleshooting.md](troubleshooting.md)** - Common issues and solutions
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture and design decisions

### Reference Documentation
- **[MAKEFILE.md](../MAKEFILE.md)** - Comprehensive Makefile command reference
- **[kubernetes-setup.md](kubernetes-setup.md)** - Advanced Kubernetes configuration
- **[arc-integration.md](arc-integration.md)** - GitHub Actions Runner Controller integration

---

## 🗄️ Deprecated Documentation (For Reference Only)

The following documents have been consolidated into the [SETUP_GUIDE.md](SETUP_GUIDE.md):

- ~~QUICKSTART.md~~ → Use [SETUP_GUIDE.md](SETUP_GUIDE.md) instead
- ~~deployment-guide.md~~ → Use [SETUP_GUIDE.md](SETUP_GUIDE.md) instead  
- ~~CLOUDFLARE_QUICKSTART.md~~ → Use [SETUP_GUIDE.md](SETUP_GUIDE.md) - Cloudflare section instead
- ~~CLOUDFLARE_CLI_INTEGRATION.md~~ → Use [SETUP_GUIDE.md](SETUP_GUIDE.md) - Cloudflare section instead
- ~~cloudflare-tunnel-guide.md~~ → Use [SETUP_GUIDE.md](SETUP_GUIDE.md) - Cloudflare section instead

These files remain for historical reference but are no longer maintained.

---

## 🚀 Quick Links by Task

### I want to...

**Deploy locally for testing**
→ [SETUP_GUIDE.md - Development Setup](SETUP_GUIDE.md#development-setup)

**Deploy to production server**
→ [SETUP_GUIDE.md - Production Setup](SETUP_GUIDE.md#production-setup)

**Deploy with Cloudflare Tunnel**
→ [SETUP_GUIDE.md - Cloudflare Setup](SETUP_GUIDE.md#cloudflare-tunnel-setup)

**Deploy to Kubernetes**
→ [SETUP_GUIDE.md - Kubernetes Setup](SETUP_GUIDE.md#kubernetes-setup)

**Fix connection issues**
→ [troubleshooting.md](troubleshooting.md)

**Understand the architecture**
→ [ARCHITECTURE.md](ARCHITECTURE.md)

**See all Makefile commands**
→ [MAKEFILE.md](../MAKEFILE.md)

---

## 📖 Documentation Structure

```
docs/
├── SETUP_GUIDE.md           ⭐ START HERE - Complete setup for all deployments
├── troubleshooting.md       🔧 Problem solving
├── ARCHITECTURE.md          📐 Technical details
├── kubernetes-setup.md      ☸️  Advanced K8s configuration
├── arc-integration.md       🎯 GitHub Actions integration
├── MAKEFILE.md              📘 Command reference (in root)
└── deprecated/              🗄️  Old docs (for reference)
    ├── QUICKSTART.md
    ├── deployment-guide.md
    ├── CLOUDFLARE_QUICKSTART.md
    └── ...
```

---

## 🆘 Still Can't Find What You Need?

1. Check the [SETUP_GUIDE.md](SETUP_GUIDE.md) Table of Contents
2. Use Ctrl+F to search the guide
3. Check [troubleshooting.md](troubleshooting.md) for common issues
4. Open an issue on [GitHub](https://github.com/yorko-io/rccremote-docker/issues)
