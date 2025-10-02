# Data Model: RCC Remote Docker Streamlining & Enhancement

## Core Entities

### Deployment Manifest
**Purpose**: Configuration templates for Docker Compose and Kubernetes deployments
**Attributes**:
- `type`: enum [docker-compose, kubernetes]
- `environment`: enum [development, staging, production]
- `server_name`: string (DNS name for certificates)
- `replica_count`: integer (1 for docker-compose, 2+ for kubernetes)
- `resource_limits`: object {cpu, memory, storage}
- `scaling_config`: object {min_replicas, max_replicas, target_cpu_percent}

**Validation Rules**:
- `server_name` must be valid DNS name
- `replica_count` >= 1
- `resource_limits.cpu` format: "100m", "1", "2.5"
- `resource_limits.memory` format: "128Mi", "1Gi", "2Gi"

**State Transitions**: draft → validated → deployed → running → terminated

### Certificate Bundle
**Purpose**: SSL/TLS certificates with proper CA chain and validation
**Attributes**:
- `cert_type`: enum [custom, auto-generated-selfsigned, auto-generated-ca]
- `server_cert`: string (PEM format)
- `server_key`: string (PEM format, encrypted at rest)
- `root_ca`: string (PEM format, optional for self-signed)
- `expiry_date`: datetime
- `san_names`: array of strings (Subject Alternative Names)

**Validation Rules**:
- `server_cert` and `server_key` must be valid PEM format
- `expiry_date` must be in future
- `san_names` must include `server_name` from deployment manifest
- Certificate and key must be cryptographically paired

**Relationships**: One-to-one with Deployment Manifest

### Health Endpoint
**Purpose**: Diagnostic interfaces providing system and component health information
**Attributes**:
- `endpoint_path`: string ["/health/live", "/health/ready", "/health/startup"]
- `response_code`: integer [200, 503, 500]
- `response_body`: object {status, timestamp, checks}
- `timeout_seconds`: integer (default: 30)
- `failure_threshold`: integer (consecutive failures before unhealthy)

**Validation Rules**:
- `endpoint_path` must start with "/"
- `response_code` must be valid HTTP status
- `timeout_seconds` between 1 and 300
- `failure_threshold` between 1 and 10

**Relationships**: Many-to-one with Service Configuration

### Sample Catalog
**Purpose**: Pre-built hololib ZIP files for testing and demonstration
**Attributes**:
- `catalog_name`: string (unique identifier)
- `zip_file_path`: string (relative path to ZIP file)
- `python_version`: string (e.g., "3.11.5")
- `conda_dependencies`: array of strings
- `robocorp_home_path`: string (target path for environments)
- `size_bytes`: integer
- `checksum_sha256`: string

**Validation Rules**:
- `catalog_name` must be alphanumeric with hyphens/underscores
- ZIP file must exist and be valid
- `checksum_sha256` must match actual file checksum
- `size_bytes` must be positive integer

**Relationships**: Many-to-many with Deployment Manifest (catalogs can be used across deployments)

### Service Configuration
**Purpose**: Kubernetes Service definitions with stable DNS names and port mappings
**Attributes**:
- `service_name`: string (Kubernetes service name)
- `service_type`: enum [ClusterIP, NodePort, LoadBalancer]
- `ports`: array of objects {name, port, target_port, protocol}
- `selector_labels`: object (key-value pairs for pod selection)
- `dns_name`: string (fully qualified service DNS name)

**Validation Rules**:
- `service_name` must be valid Kubernetes name (DNS-1123 subdomain)
- `ports` array must not be empty
- `target_port` must match container port
- `dns_name` format: `{service_name}.{namespace}.svc.cluster.local`

**Relationships**: One-to-many with Health Endpoint

### Security Profile
**Purpose**: Container security configurations with non-root users and minimal privileges
**Attributes**:
- `run_as_user`: integer (non-root UID, default: 1000)
- `run_as_group`: integer (non-root GID, default: 1000)
- `read_only_root_filesystem`: boolean (default: true)
- `allowed_capabilities`: array of strings (minimal required capabilities)
- `seccomp_profile`: string (seccomp profile name)
- `selinux_options`: object (SELinux context options)

**Validation Rules**:
- `run_as_user` must be > 0 (non-root)
- `run_as_group` must be > 0 (non-root)
- `allowed_capabilities` should be minimal set
- `seccomp_profile` must exist if specified

**Relationships**: One-to-one with Deployment Manifest

## Entity Relationships

```
Deployment Manifest 1:1 Certificate Bundle
Deployment Manifest 1:1 Security Profile
Deployment Manifest 1:n Service Configuration
Service Configuration 1:n Health Endpoint
Deployment Manifest n:m Sample Catalog
```

## Data Volume Estimation

- **Small Environment** (1-10 clients): ~10 deployment manifests, ~5 certificate bundles
- **Medium Environment** (10-100 clients): ~50 deployment manifests, ~20 certificate bundles  
- **Large Environment** (100+ clients): ~200 deployment manifests, ~100 certificate bundles
- **Sample Catalogs**: ~20 pre-built catalogs, 50-200MB each
- **Health Endpoints**: 3 per service configuration, ~100 health checks/minute at scale

## Storage Requirements

- **Configuration Data**: <1MB per deployment (YAML manifests)
- **Certificate Storage**: ~10KB per certificate bundle
- **Sample Catalogs**: 1-4GB total for complete catalog library
- **Health Check Logs**: ~100MB/day at enterprise scale
- **Persistent Volumes**: 10-100GB for holotree data depending on catalog count