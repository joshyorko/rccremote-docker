# rccremote-docker

Enterprise-ready Docker and Kubernetes deployment for [RCC Remote](https://sema4.ai/docs/automation/rcc/overview) with SSL/TLS, automated certificate management, horizontal scaling, and comprehensive monitoring.

## � Quick Start

**Choose your deployment:**

### 🏠 Local Development
```bash
make quick-dev
export RCC_REMOTE_ORIGIN=https://localhost:8443
rcc holotree catalogs
```

### 🌍 Cloudflare Tunnel (Public Access, No Server Needed)
```bash
make quick-cf HOSTNAME=rccremote.yourdomain.com
export RCC_REMOTE_ORIGIN=https://rccremote.yourdomain.com
rcc holotree catalogs
```

### 🏢 Production Server
```bash
make certs-signed SERVER_NAME=your-domain.com
make prod-up SERVER_NAME=your-domain.com
export RCC_REMOTE_ORIGIN=https://your-domain.com
rcc holotree catalogs
```

### ☸️ Kubernetes
```bash
make quick-k8s
export RCC_REMOTE_ORIGIN=https://your-k8s-service.com
rcc holotree catalogs
```

## 📚 Documentation

- **[Complete Setup Guide](docs/SETUP_GUIDE.md)** - ⭐ **Start here!** Comprehensive guide for all deployment modes
- **[Architecture Overview](docs/ARCHITECTURE.md)** - Technical architecture and design decisions
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Makefile Commands](docs/MAKEFILE.md)** - All available commands and usage

## 💡 Which Deployment Should I Choose?

| Scenario | Deployment | Command |
|----------|------------|---------|
| Testing locally | Development | `make quick-dev` |
| Need public access, no server | Cloudflare Tunnel | `make quick-cf HOSTNAME=rccremote.yourdomain.com` |
| Have server with public IP | Production | `make prod-up SERVER_NAME=your-domain.com` |
| Enterprise with Kubernetes | Kubernetes | `make quick-k8s` |

**Not sure?** See the [Setup Guide](docs/SETUP_GUIDE.md) for a decision tree and detailed instructions.

---

## 📖 What is RCC Remote?

RCC Remote serves environment blueprints (catalogs) to isolated RCC clients that cannot access the internet directly. This is essential for:

- **Offline/Air-gapped Environments** - Test clients isolated from the internet
- **Performance** - Centralized catalog management saves bandwidth and build time  
- **Security** - Control what environments are available to clients
- **Consistency** - Ensure all clients use the same environment versions

### Architecture

```
┌─────────────┐   HTTPS    ┌─────────┐   HTTP    ┌────────────┐
│ RCC Client  │ ─────────> │  nginx  │ ────────> │ rccremote  │
└─────────────┘   Port 443  └─────────┘  Port 4653└────────────┘
                             (SSL Proxy)            (Catalog Server)
```

**Key Concepts:**
- **Catalog (Hololib)**: Blueprint of an environment that can create multiple instances
- **Space (Holotree)**: Actual environment instance created from a catalog
- **RCC Client**: Tool that requests and builds environments from catalogs

---

## ✨ Features

- **🔒 SSL/TLS Encryption** - Secure connections with automated certificate management
- **📈 Horizontal Scaling** - Support for 100+ concurrent RCC clients (Kubernetes)
- **🔄 High Availability** - 99.9% uptime target with health checks and auto-recovery
- **🐳 Multi-Platform** - Docker Compose and Kubernetes deployment options
- **🏥 Health Monitoring** - Comprehensive health checks and Prometheus metrics
- **⚡ Fast Deployment** - Sub-5-minute deployment from start to operational
- **🛡️ Security Hardened** - Non-root containers, minimal privileges, network policies
- **☁️ Cloud-Ready** - Built-in Cloudflare Tunnel support for zero-config public access

---

## 🎯 Essential Commands

### Development
```bash
make quick-dev              # Start development environment
make dev-logs              # View logs
make dev-down              # Stop services
make client-configure      # Configure RCC client
```

### Production
```bash
make certs-signed SERVER_NAME=your-domain.com  # Generate certificates
make prod-up SERVER_NAME=your-domain.com       # Start production
make prod-logs                                 # View logs
make prod-down                                 # Stop services
```

### Cloudflare
```bash
make quick-cf HOSTNAME=rccremote.yourdomain.com  # Setup tunnel
make cf-logs                                     # View logs
make cf-down                                     # Stop tunnel
make cf-tunnel-list                              # List tunnels
```

### Kubernetes
```bash
make quick-k8s             # Deploy to Kubernetes
make k8s-status            # View status
make k8s-logs              # View logs
make k8s-restart           # Restart deployment
```

### Maintenance
```bash
make test-health           # Health check
make ps                    # Show running containers/pods
make backup                # Backup robot data
make help                  # Show all commands
```

---

## 🔧 Prerequisites

- **Docker** 20.10+ and Docker Compose
- **Linux host** (Ubuntu 20.04+, Fedora, or Universal Blue)
- **8GB RAM** minimum
- **50GB+ storage** for holotree data
- **RCC client** (optional, for testing) - [Download here](https://sema4.ai/docs/automation/rcc/overview)

**Check your system:**
```bash
make env-check
```

---

## 📦 Adding Robots

### Method 1: Robot Directories (Built on Startup)

Place robot definitions in `data/robots/`:

```bash
data/robots/
├── my-robot/
│   ├── robot.yaml
│   └── conda.yaml
```

Restart to build catalogs:
```bash
make dev-restart  # or prod-restart
```

### Method 2: Pre-built ZIP Catalogs (Import on Startup)

Export from a build machine:
```bash
cd /path/to/robot
rcc holotree export -r robot.yaml -z my-robot.zip
```

Copy to server:
```bash
cp my-robot.zip data/hololib_zip/
make dev-restart
```

---

## 🧪 Testing Your Deployment

```bash
# Quick health check
make test-health

# Test RCC connectivity
rcc holotree catalogs

# Run all tests
make test-all

# Manual verification
curl -k https://localhost:8443/
```

---

## 🤝 Contributing

Issues and pull requests are welcome! See our [GitHub repository](https://github.com/yorko-io/rccremote-docker).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Robocorp/Sema4.ai](https://sema4.ai) for RCC and RCC Remote
- nginx for the excellent reverse proxy
- Cloudflare for the amazing tunnel service

---

**Need help?** Check the [Complete Setup Guide](docs/SETUP_GUIDE.md) or [Troubleshooting Guide](docs/troubleshooting.md).
