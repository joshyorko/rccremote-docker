<!--
Sync Impact Report:
- Version change: Template → 1.0.0 (initial constitution)
- New principles: All five core principles established for containerized RCC environment management
- Added sections: Container Orchestration Standards, Security Requirements, Operational Workflow
- Templates requiring updates: ✅ All validated (plan-template.md, spec-template.md, tasks-template.md, agent-file-template.md)
- Follow-up TODOs: None - all placeholders filled
-->

# RCCRemote-Docker Constitution

## Core Principles

### I. Container-First Architecture
All system components MUST be containerized with explicit service boundaries and well-defined interfaces. Each container serves a single responsibility: rccremote for environment management, nginx for SSL termination, rcc for client testing. Container orchestration through docker-compose ensures reproducible deployments with consistent volume mappings and networking. 

**Rationale**: Containerization provides isolation, reproducibility, and consistent deployment across environments while maintaining clear separation of concerns between SSL handling, environment management, and client functionality.

### II. Security-by-Design
SSL/TLS encryption MUST be enforced for all client communications with automatic certificate management. The system MUST support both custom certificates (production) and auto-generated certificates (development/testing) with proper certificate validation workflows. RCC client SSL profiles MUST auto-configure based on certificate presence to ensure secure communication.

**Rationale**: RCC environments often contain sensitive automation code and credentials. Unencrypted transmission creates security vulnerabilities, especially in isolated network environments where rccremote serves as the central trust point.

### III. Environment Reproducibility (NON-NEGOTIABLE)
All RCC environment builds MUST be deterministic and cross-platform compatible. Environment definitions (robot.yaml, conda.yaml) combined with custom ROBOCORP_HOME paths MUST produce identical catalog behavior across Linux containers and target client systems. Environment sourcing from .env files MUST preserve and restore shell state to prevent variable pollution.

**Rationale**: Environment reproducibility is the core value proposition of RCC. Any deviation breaks the fundamental promise that environments work identically across development, testing, and production systems.

### IV. Data Flow Transparency
The system MUST maintain clear data flow: robots → catalogs → ZIP exports → holotree import → rccremote serving. Each transformation step MUST be logged with detailed output for debugging. Build artifacts MUST be preserved in internal volumes for inspection and troubleshooting.

**Rationale**: Environment builds are complex multi-step processes. When builds fail or environments behave unexpectedly, clear visibility into each transformation step is essential for rapid diagnosis and resolution.

### V. Operational Reliability
Container startup sequences MUST be deterministic with proper dependency management and health checks. The system MUST gracefully handle missing certificates, empty robot directories, and network failures. Background processes MUST support monitoring and restart capabilities without data loss.

**Rationale**: In isolated network environments, rccremote becomes a critical infrastructure service. Downtime directly impacts all dependent automation workflows, requiring high availability and predictable recovery procedures.

## Container Orchestration Standards

All services MUST define explicit resource constraints, health checks, and restart policies. Volume mappings MUST separate user data (./data/robots, ./certs) from system data (robocorp_data, hololib_zip_internal) to enable backup and migration strategies. Network aliases MUST support custom SERVER_NAME configuration for certificate matching.

Container entrypoints MUST support multiple operational modes (rccremote server, rcc client) with shared initialization logic. Environment variable sourcing MUST be isolated per robot build to prevent cross-contamination while preserving the ability to customize ROBOCORP_HOME paths.

## Security Requirements

Certificate generation scripts MUST create proper X.509 certificates with Subject Alternative Name (SAN) attributes matching SERVER_NAME configuration. Root CA certificates MUST be properly distributed to client containers with automatic profile configuration. Self-signed certificates are acceptable for development but MUST be clearly identified as such.

SSL profiles MUST auto-configure based on certificate availability: ssl-cabundle for verified certificates, ssl-noverify for development environments. RCC telemetry MUST be disabled by default to prevent data leakage in isolated environments.

## Operational Workflow

Feature development MUST follow TDD principles with integration testing for multi-container scenarios. Changes to certificate handling, environment building, or RCC integration MUST be validated against both development (self-signed) and production (CA-signed) certificate workflows.

Performance testing MUST validate environment build times, ZIP export/import cycles, and SSL handshake performance under realistic load conditions. Documentation MUST include troubleshooting guides for common failure scenarios: certificate mismatches, build failures, and network connectivity issues.

## Governance

This constitution supersedes all other development practices. All pull requests MUST verify compliance with container-first architecture, security-by-design, and environment reproducibility principles. 

Complexity violations MUST be explicitly justified with reference to RCC operational requirements or container orchestration constraints. Use `.github/copilot-instructions.md` for runtime development guidance and specific implementation patterns.

Version increments follow semantic versioning: MAJOR for backward-incompatible changes to container interfaces or certificate handling, MINOR for new features like additional environment sources or monitoring capabilities, PATCH for bug fixes and documentation improvements.

**Version**: 1.0.0 | **Ratified**: 2025-10-02 | **Last Amended**: 2025-10-02