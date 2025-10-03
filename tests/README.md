# RCC Remote Docker - Test Suite

Comprehensive test suite for RCC Remote Docker deployment validation.

## Test Structure

```
tests/
├── contract/         # Contract tests (API compliance)
├── integration/      # Integration tests (end-to-end workflows)
├── load/            # Load and performance tests
└── validation/      # Deployment validation tests
```

## Running Tests

### Prerequisites

- Docker and Docker Compose (for Docker tests)
- kubectl and k3d (for Kubernetes tests)
- curl, jq, nc (for API tests)
- RCC binary (downloaded automatically by tests)

### Contract Tests

Test API compliance with OpenAPI specifications:

```bash
# Test health API endpoints
./tests/contract/test_health_api.sh

# Test deployment API endpoints
./tests/contract/test_deployment_api.sh
```

### Integration Tests

Test complete workflows:

```bash
# Test Docker Compose deployment
./tests/integration/test_docker_deployment.sh

# Test Kubernetes deployment (requires k3d)
./tests/integration/test_k8s_deployment.sh

# Test RCC client connectivity
./tests/integration/test_rcc_connectivity.sh
```

### Load Tests

Test system performance and scalability:

```bash
# Test with 100+ concurrent clients (default)
./tests/load/test_concurrent_clients.sh

# Test with custom client count and duration
CLIENT_COUNT=200 DURATION=120 ./tests/load/test_concurrent_clients.sh
```

### Validation Tests

Validate deployment requirements:

```bash
# End-to-end deployment validation
DEPLOYMENT_TYPE=docker ./tests/validation/test_e2e_deployment.sh
DEPLOYMENT_TYPE=k8s ./tests/validation/test_e2e_deployment.sh

# Performance validation (<5 minute deployment)
DEPLOYMENT_TYPE=docker ./tests/validation/test_performance.sh
```

## Test Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET` | https://localhost:8443 | Target server for API tests |
| `CLIENT_COUNT` | 100 | Number of concurrent clients for load tests |
| `DURATION` | 60 | Duration in seconds for sustained load tests |
| `DEPLOYMENT_TYPE` | docker | Deployment type: docker or k8s |
| `RCC_REMOTE_ORIGIN` | https://rccremote.local:8443 | RCC Remote origin URL |

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  contract-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Contract Tests
        run: |
          ./tests/contract/test_health_api.sh
          ./tests/contract/test_deployment_api.sh

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Integration Tests
        run: |
          ./tests/integration/test_docker_deployment.sh
          ./tests/integration/test_rcc_connectivity.sh

  validation-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Validation Tests
        run: |
          ./tests/validation/test_e2e_deployment.sh
```

## Test Reports

All tests output colored terminal output:
- 🟢 Green: Success
- 🔴 Red: Failure
- 🟡 Yellow: Warning

Example output:
```
[CONTRACT TEST] Testing Health API Contract against https://localhost:8443
[CONTRACT TEST] Testing /health/live endpoint...
[CONTRACT TEST]   ✓ /health/live contract validated
[CONTRACT TEST] Testing /health/ready endpoint...
[CONTRACT TEST]   ✓ /health/ready contract validated
[CONTRACT TEST] All Health API contract tests PASSED ✓
```

## Troubleshooting

### Tests Fail with Connection Errors

Ensure the target service is running:
```bash
# Check if service is up
curl -k https://localhost:8443/health/live

# Start development environment
docker-compose -f docker-compose/docker-compose.development.yml up -d
```

### k3d Tests Fail

Ensure k3d is installed and Docker is running:
```bash
# Install k3d
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Verify installation
k3d version
```

### Load Tests Timeout

Increase concurrent request limit or duration:
```bash
CONCURRENT_REQUESTS=5 DURATION=180 ./tests/load/test_concurrent_clients.sh
```

## Test Coverage

| Test Category | Coverage |
|---------------|----------|
| Health API | ✅ /health/live, /health/ready, /health/startup, /metrics |
| Deployment API | ✅ /deployment/validate, /certificates/generate, /catalogs |
| Docker Deployment | ✅ Development and production configs |
| Kubernetes Deployment | ✅ Full manifest stack with k3d |
| RCC Connectivity | ✅ Client configuration and catalog fetching |
| Load Testing | ✅ 100+ concurrent clients, sustained load |
| Performance | ✅ <5 minute deployment validation |
| Security | ✅ Non-root execution, SSL/TLS enforcement |

## Contributing

When adding new tests:

1. Follow the existing test structure
2. Use consistent output formatting (log/error/warn functions)
3. Make tests idempotent (can be run multiple times)
4. Clean up resources after test completion
5. Document any new environment variables
6. Update this README with new test descriptions

## Test Development

### Template for New Tests

```bash
#!/bin/bash

# Test description
# Purpose of this test

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# Test implementation
test_something() {
    log "Testing something..."
    
    # Test logic here
    
    log "  ✓ Test passed"
}

main() {
    log "Starting test..."
    test_something
    log "Test completed ✓"
}

main
```

## Support

- GitHub Issues: https://github.com/yorko-io/rccremote-docker/issues
- Documentation: https://github.com/yorko-io/rccremote-docker/tree/main/docs
