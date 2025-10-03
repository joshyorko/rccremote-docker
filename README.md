# rccremote-docker

Enterprise-ready Docker and Kubernetes deployment for [RCC Remote](https://sema4.ai/docs/automation/rcc/overview) with SSL/TLS, automated certificate management, horizontal scaling, and comprehensive monitoring.

## 📚 Documentation

For comprehensive deployment guides and advanced configurations, see:

- **[Deployment Guide](docs/deployment-guide.md)** - Complete deployment instructions for Docker Compose and Kubernetes
- **[Kubernetes Setup](docs/kubernetes-setup.md)** - Kubernetes-specific configuration and best practices
- **[ARC Integration](docs/arc-integration.md)** - GitHub Actions Runner Controller integration
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

## 🚀 Quick Start

Choose your deployment method:

```bash
# Docker Compose (Development)
./scripts/deploy-docker.sh --environment development

# Configure RCC client (REQUIRED - run on each client machine)
./scripts/configure-rcc-profile.sh

# Set environment variables (add to ~/.bashrc or ~/.zshrc for persistence)
export ROBOCORP_HOME=/opt/robocorp
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443

# Test connectivity
rcc holotree vars

# Docker Compose (Production)
./scripts/deploy-docker.sh --environment production

# Kubernetes
./scripts/deploy-k8s.sh --namespace rccremote --replicas 3
```

See [Quick Start Guide](docs/QUICKSTART.md) and [Deployment Guide](docs/deployment-guide.md) for detailed instructions.

---

## Overview

Docker-compose and Kubernetes setup with SSL for [rccremote](https://sema4.ai/docs/automation/rcc/overview).

### Key Features

- **🔒 SSL/TLS Encryption** - Automated certificate generation and management
- **📈 Horizontal Scaling** - Support for 100+ concurrent RCC clients with Kubernetes HPA
- **🔄 High Availability** - 99.9% uptime target with multiple replicas and health probes
- **🐳 Multi-Platform** - Docker Compose and Kubernetes deployment options
- **🏥 Health Monitoring** - Comprehensive health checks and Prometheus metrics
- **🎯 ARC Integration** - Native support for GitHub Actions Runner Controller
- **⚡ Fast Deployment** - Sub-5-minute deployment from start to operational
- **🛡️ Security Hardened** - Non-root containers, minimal privileges, network policies

```mermaid
graph LR
    classDef dotted stroke-dasharray: 5 5;
    rcc -->|HTTPS| nginx
    nginx -->|HTTP| rccremote
    ZIP -. import .-> rccremote
    YAML -. build .-> rccremote
    rccremote -- fetch --> rccremote2[rccremote]:::dotted
    rccremote -- fetch --> rccremote-docker:::dotted
    subgraph import sources
    ZIP
    YAML
    end
    style ZIP fill:#baa773,stroke-width:0px,color:black
    style YAML fill:#baa773,stroke-width:0px,color:black
    style nginx fill:#6589a5,stroke-width:0px,color:black
    style rccremote2 stroke-line:dotted
```

## Background

### Purpose of this project

In order to built RCC environments with **rcc**, the host must be connected to the Internet in order to download the installation sources for Python/Node.js/etc.  
However, for security reasons, test clients are often completely isolated from the Internet.

**RCCRemote** solves this problem by serving the blueprints of these environments (aka "_Catalogs_") for **RCC** clients which can fetch the blueprints from there.  
This centralized approach does not only save network traffic and computing resources, but also is a significant performance gain, because when the clients ask for environments, rccremote only relays the missing files, not the whole environment.

By default, **rccremote** operates unencrypted, meaning **rcc** cannot verify the connection, nor is the data transmission encrypted.  

This setup provides a way to run RCCRemote behind a reverse proxy (nginx) with TLS encryption and server authentication.

## Directory Structure

```
├── docker-compose/           # Docker Compose configurations
│   ├── docker-compose.development.yml    # Development setup (port 8443)
│   ├── docker-compose.production.yml     # Production setup (port 443)
│   └── docker-compose.cloudflare.yml     # Cloudflare Tunnel setup
├── k8s/                      # Kubernetes manifests
│   ├── README.md            # K8s deployment instructions
│   ├── deployment.yaml      # Main deployment with HPA
│   ├── service.yaml         # Service definition
│   └── ...                  # Other k8s resources
├── scripts/                  # Deployment and utility scripts
├── config/                   # Configuration templates
├── docs/                     # Comprehensive documentation
├── data/                     # Runtime data
│   ├── robots/              # Robot definitions for building catalogs
│   └── hololib_zip/         # Pre-built catalog imports
└── certs/                    # SSL/TLS certificates

```

### Terminology

RCC-internal concepts:

- **Hololib**: A **Collection** of currently available **catalogs**.
  - **Catalog**: A blueprint of an environment which can be used to create an arbitrary number of instances of this environment.
- **Holotree**: A **Collection** of currently available **spaces**.
  - **Space**: An instance of an environment. There is a one-to-many relation between catalog and space.

## Deployment

### Docker Compose

Choose the appropriate compose file from the `docker-compose/` directory:

**Development (port 8443, auto-generated certificates):**
```bash
./scripts/deploy-docker.sh --environment development
```

**Production (port 443, requires custom certificates):**
```bash
./scripts/deploy-docker.sh --environment production --server-name your-domain.com
```

### Kubernetes

Deploy to a Kubernetes cluster with high availability:
```bash
./scripts/deploy-k8s.sh --namespace rccremote --replicas 3
```

### RCC Client Configuration (REQUIRED)

After deploying the server, configure RCC clients to use it:

```bash
# Run on each client machine
./scripts/configure-rcc-profile.sh

# Add to ~/.bashrc or ~/.zshrc for persistence
export ROBOCORP_HOME=/opt/robocorp
export RCC_REMOTE_ORIGIN=https://rccremote.local:8443

# Test connectivity
rcc holotree vars
```

See [Quick Start Guide](docs/QUICKSTART.md) and [Deployment Guide](docs/deployment-guide.md) for detailed step-by-step instructions.

## Certificate Management

### Auto-Generated (Development)

The development setup automatically generates self-signed certificates if none are provided.

### Custom Certificates (Production - Recommended)

Generate CA-signed certificates for proper SSL verification:

```bash
./scripts/cert-management.sh generate-ca-signed --server-name your-domain.com
```

This creates:
- `certs/rootCA.crt` - Root CA certificate (install on client machines)
- `certs/server.crt` - Server certificate
- `certs/server.key` - Server private key

**Install Root CA on client machines:**

Linux:
```bash
sudo cp certs/rootCA.crt /usr/local/share/ca-certificates/rccremote-ca.crt
sudo update-ca-certificates
```

See [Deployment Guide - Certificate Management](docs/deployment-guide.md#certificate-management) for other platforms.

## Adding Robot Catalogs

There are two ways to add environment catalogs to RCC Remote: 

- A) `./data/robots` - Containing Robot directories with `robot.yaml`/`conda.yaml`: **build and import** on startup
- B) `./data/hololib_zip` - Containing ZIP files of exported Catalogs: **import** on startup
- C) using another **rccremote** server (cascaded setup, not yet implemented)

Both modes can be used simultanously. In the following, they are explained. 

### Mode A: Add Robot directories

The **rccremote** container first uses **rcc** to build the Catalogs for each directory where it locates `robot.yaml`/`conda.yaml` files.  

As this happens inside of the Docker container, the created Catalogs are **for Linux systems only**.  

By default, all builds compile for the Holotree path `/opt/robocorp`. If the **rcc** clients operate on systems where this path is useable, this is fine. The environment would be created below of this path then. 

To change the holotree path, the Robot folders can contain a `.env` file: 

```
ROBOCORP_HOME=/robotmk/rcc_home/current_user
```

(For examples, see `./data/robots-examples/`).

Before each build, **rcc** sources this file so that the Catalog is built against a custom `ROBOCORP_HOME`.
After each environment creation, the environment gets exported into a ZIP file (volume: hololib_zip_internal).

Finally, all ZIP files are imported into the shared holotree, before the **rccremote** server process gets started. 

### Mode B: Add Hololib ZIP files

This mode is divided into 2 sub steps: 

- **Create the environments** on a build machine (Linux/Windows) which has internet access
- **Add the ZIP files** into `./data/hololib_zip`

#### Step 1: Create the environments

On the machine where you can build environments with internet access, set `ROBOCORP_HOME` to a path where the Catalogs should be built against. 

**Example**: 

You want to create a Hololib ZIP which can be used on a Windows test client (Windows). The system executing the Robot expects all Catalogs and Spaces for user `alice` in `C:\robotmk\rcc_home\alice`.

```
set ROBOCORP_HOME=C:\robotmk\rcc_home\alice
cd myrobot
# create the catalog (+space), using the custom ROBOCORP_HOME
rcc holotree vars
# export the ZIP file
rcc holotree export -r robot.yaml -z rf_playwright_17_18.zip
```

#### Step 2: Add the ZIP files

Copy all exported catalog files into the folder `./data/hololib_zip`.  
When the **rccremote** container gets started, it imports all ZIP files into the shared holotree. 

## rcc: usage with rccremote

In `docker-compose.yaml` you can find the container **rcc**, commented by default.  
You do not need this container in production, but it's useful for testing **rcc** in combination with **rccremote**.

To use that container, follow these steps:

### Start the rcc client container

Uncomment the **rcc** container definition and start it: 

`docker compose up -d rcc`

Open a shell inside the **rcc** container: 

`docker exec -it rcc bash`


### RCC client profile configuration

On startup, the **rcc** container auto-configures the profile SSL-setting depending on whether the folder `certs` contains a root certificate (`rootCA.pem`) or not: 

If `rootCA.pem` is 
  
- **not present** => Profile **no-sslverify** with setting `verify-ssl: false`
- **present** => Profile **cabundle** with `verify-ssl: true` and the PEM content included into the profile YAML configuration

You can verify the active **rcc** profile with `rcc config switch`:

```
root@0ca74438d77f:/# rcc config switch
Available profiles:
- ssl-noverify: disabled SSL verification

Currently active profile is: ssl-noverify    # <----
OK.
```

### Testing rcc fetching the hololib from rccremote

Change into a robot folder below of `/robots` (this is the same host mounted `/robots` folder as on **rccremote**) where `robot.yaml` and `conda.yaml` files are. 

Verify that `RCC_REMOTE_ORIGIN` is set to the nginx server, port 443: 

```
root@0ca74438d77f:/robots/rf7# echo $RCC_REMOTE_ORIGIN
https://rccremote.local:443
```

Execute `rcc holotree vars`. **rcc** should be able to download the hololib from the server: 

![alt text](./img/rcclog.png)

## Debugging 

### Connection test from rcc to nginx

Test without the root certificate: 

    openssl s_client -connect rccremote.local:443
    ...
    ...
    Verify return code: 21 (unable to verify the first certificate)
    Extended master secret: no
    Max Early Data: 0
    ---
    read R BLOCK

Test with Root certificate: 

    openssl s_client -connect rccremote.local:443 -CAfile /etc/certs/rootCA.crt
    Verify return code: 0 (ok)     #  <------------------------------
    Extended master secret: no
    Max Early Data: 0
    ---
    read R BLOCK

### rcc settings

    rcc config diag

### rest

Show crt details: 

    openssl x509 -in /etc/nginx/server.crt -text -noout

Switch to default profile: 

    rcc config switch --noprofile

