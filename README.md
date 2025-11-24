<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Go-httpbin GitHub Action

A GitHub Action that sets up a local
[go-httpbin](https://github.com/mccutchen/go-httpbin) service with HTTPS support.

## go-httpbin-action

## Features

- 🔒 **HTTPS Support**: Automatically generates valid SSL certificates using mkcert
- 🐳 **Docker-based**: Runs go-httpbin in a Docker container for isolation
- 🔧 **Highly Configurable**: Supports configuration options for different use cases
- 🚀 **Fast Setup**: Optimized for CI/CD pipelines with built-in readiness checking
- 🌐 **Network Flexibility**: Supports both host networking and standard port mapping
- 📊 **Debug Support**: Optional verbose logging for troubleshooting
- ✅ **Reliable Readiness**: Uses `lfreleng-actions/http-api-tool-docker`
  for robust service verification

## Usage

### Basic Usage

```yaml
steps:
  # Start the go-httpbin container with built-in readiness check
  - name: Setup go-httpbin
    uses: lfreleng/setup-go-httpbin@v1
    id: httpbin

  # Testing (the action includes built-in readiness check)
  - name: Test go-httpbin endpoint
    uses: lfreleng-actions/http-api-tool-docker@v0.1.0
    with:
      url: "${{ steps.httpbin.outputs.service-url }}/get"
      service_name: "go-httpbin GET endpoint"
      verify_ssl: false
      expected_http_code: 200
      regex: '"url"'
      debug: true
```

### Advanced Usage

```yaml
steps:
  - name: Setup go-httpbin with custom configuration
    uses: lfreleng/setup-go-httpbin@v1
    id: httpbin
    with:
      container-name: 'my-httpbin'
      port: '9090'
      use-host-network: 'true'
      debug: 'true'
      wait-timeout: '120'
      certificate-domains: 'myservice.local,api.test'
      docker-run-args: '--cpus=0.5 --memory=256m'

  - name: Test with proper SSL verification
    uses: lfreleng-actions/http-api-tool-docker@main
    with:
      url: "${{ steps.httpbin.outputs.service-url }}/get"
      service_name: "go-httpbin SSL verified endpoint"
      verify_ssl: true
      ca_bundle_path: "${{ steps.httpbin.outputs.ca-cert-path }}"
      expected_http_code: 200
      regex: '"url"'
      debug: true
```

### HTTP Mode (No SSL)

```yaml
steps:
  - name: Setup go-httpbin without SSL
    uses: lfreleng/setup-go-httpbin@v1
    id: httpbin
    with:
      skip-certificate: 'true'

  - name: Test HTTP endpoint
    uses: lfreleng-actions/http-api-tool-docker@main
    with:
      url: "${{ steps.httpbin.outputs.service-url }}/get"
      service_name: "go-httpbin HTTP endpoint"
      verify_ssl: false
      expected_http_code: 200
      regex: '"url"'
      debug: true
```

### Skip Built-in Readiness Check

```yaml
steps:
  - name: Setup go-httpbin without readiness check
    uses: lfreleng/setup-go-httpbin@v1
    id: httpbin
    with:
      skip-readiness-check: 'true'

  # Handle readiness checking manually
  - name: Custom readiness check
    uses: lfreleng-actions/http-api-tool-docker@main
    with:
      url: "${{ steps.httpbin.outputs.service-url }}/get"
      service_name: "Custom readiness check"
      verify_ssl: false
      expected_http_code: 200
      retries: 30
      initial_sleep_time: 2
```

## Inputs

<!-- markdownlint-disable MD013 -->

| Input                  | Description                                     | Required | Default                        |
| ---------------------- | ----------------------------------------------- | -------- | ------------------------------ |
| `container-name`       | Name for the Docker container                   | No       | `go-httpbin`                   |
| `port`                 | Port to expose the service on                   | No       | `8080`                         |
| `image`                | Docker image to use                             | No       | `ghcr.io/mccutchen/go-httpbin` |
| `image-tag`            | Tag of the Docker image                         | No       | `latest`                       |
| `use-host-network`     | Use host networking (true/false)                | No       | `false`                        |
| `wait-timeout`         | Wait time for service ready (retries)           | No       | `60`                           |
| `debug`                | Enable debug output (true/false)                | No       | `false`                        |
| `cert-file-path`       | SSL certificate file path                       | No       | `<secure>/cert.pem`            |
| `key-file-path`        | SSL private key file path                       | No       | `<secure>/key.pem`             |
| `certificate-domains`  | Extra domains for SSL certificate               | No       | ``                             |
| `skip-certificate`     | Skip SSL certificate generation                 | No       | `false`                        |
| `docker-run-args`      | Extra Docker run arguments                      | No       | ``                             |
| `install-deps`         | Whether to install dependencies                 | No       | `true`                         |
| `go-version`           | Go version for building mkcert (if unavailable) | No       | `1.24`                         |
| `skip-readiness-check` | Skip the built-in readiness check               | No       | `false`                        |

<!-- markdownlint-enable MD013 -->

## Outputs

<!-- markdownlint-disable MD013 -->

| Output            | Description                                               |
| ----------------- | --------------------------------------------------------- |
| `container-name`  | Name of the created container                             |
| `service-url`     | Base URL for accessing the service                        |
| `host-gateway-ip` | Docker host gateway IP for container communication        |
| `ca-cert-path`    | Path to the mkcert CA certificate (relative to workspace) |
| `cert-file`       | Path to the SSL certificate file                          |
| `key-file`        | Path to the SSL private key file                          |
| `protocol`        | Protocol used (http or https)                             |

<!-- markdownlint-enable MD013 -->

## Environment Variables

The action also sets the following environment variables for convenience:

- `HOST_GATEWAY`: Docker host gateway IP
- `PROTOCOL`: Protocol in use (http or https)
- `MKCERT_CA_PATH`: Path to the mkcert CA certificate (when using HTTPS)
- `GO_HTTPBIN_URL`: Base URL of the running service

## Network Modes

### Standard Mode (default)

Uses Docker port mapping to expose the service on the specified port:

```yaml
- uses: lfreleng/setup-go-httpbin@v1
  with:
    port: '8080'
```

The service URL is automatically set to the Docker host gateway IP (typically
`172.17.0.1`) with the specified port for container-to-container communication.

**From the host (your local machine):** Access the service at
`https://localhost:${{ inputs.port }}` (e.g., `https://localhost:8080`).

**From containers (like http-api-tool-docker):** Use the `service-url` output,
which points to `https://$HOST_GATEWAY:${{ inputs.port }}` for proper
container-to-container networking.

### Host Network Mode

Uses Docker host networking for direct access:

```yaml
- uses: lfreleng/setup-go-httpbin@v1
  with:
    use-host-network: 'true'
```

Access the service at: `https://localhost:8080`.

**Note**: In host network mode, the container uses port 8080 directly on the
host network namespace. The port input has no effect in this mode.

## SSL Certificate Handling

The action automatically:

1. Installs mkcert and creates a local CA
2. Generates SSL certificates for `localhost` and any extra domains
3. Installs the CA certificate in the system trust store
4. Provides paths to certificates for manual SSL verification

**Security Note**: The action stores certificates in secure temporary
directories with restricted permissions (700) rather than world-readable `/tmp`
directories. The secure directories receive automatic cleanup when the action
completes.

### Using with SSL Verification

```yaml
# With proper SSL verification using http-api-tool-docker
- uses: lfreleng-actions/http-api-tool-docker@main
  with:
    url: "${{ steps.httpbin.outputs.service-url }}/get"
    service_name: "API Test"
    verify_ssl: true
    ca_bundle_path: "${{ steps.httpbin.outputs.ca-cert-path }}"
    expected_http_code: 200

# Without SSL verification (for testing)
- uses: lfreleng-actions/http-api-tool-docker@main
  with:
    url: "${{ steps.httpbin.outputs.service-url }}/get"
    service_name: "API Test"
    verify_ssl: false
    expected_http_code: 200
```

## Common Use Cases

### Comprehensive API Testing

```yaml
jobs:
  test-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup go-httpbin
        uses: lfreleng/setup-go-httpbin@v1
        id: httpbin

      - name: Test GET endpoint
        uses: lfreleng-actions/http-api-tool-docker@main
        with:
          url: "${{ steps.httpbin.outputs.service-url }}/get"
          service_name: "GET endpoint test"
          verify_ssl: true
          ca_bundle_path: "${{ steps.httpbin.outputs.ca-cert-path }}"
          expected_http_code: 200
          regex: '"url"'
          debug: true

      - name: Test POST endpoint
        uses: lfreleng-actions/http-api-tool-docker@main
        with:
          url: "${{ steps.httpbin.outputs.service-url }}/post"
          service_name: "POST endpoint test"
          http_method: "POST"
          request_body: '{"test": "data"}'
          content_type: "application/json"
          verify_ssl: false
          expected_http_code: 200
          regex: '"json"'

      - name: Test authentication
        uses: lfreleng-actions/http-api-tool-docker@main
        with:
          url: "${{ steps.httpbin.outputs.service-url }}/basic-auth/user/pass"
          service_name: "Auth endpoint test"
          auth_string: "user:pass"
          verify_ssl: false
          expected_http_code: 200
          regex: '"authenticated"'
```

### Testing Custom HTTP Tools

```yaml
jobs:
  test-api-tool:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup go-httpbin
        uses: lfreleng/setup-go-httpbin@v1
        id: httpbin

      - name: Test custom API tool
        run: |
          ./my-api-tool test \
            --url "${{ steps.httpbin.outputs.service-url }}/get" \
            --ca-bundle "${{ steps.httpbin.outputs.ca-cert-path }}"
```

### Error Handling and Edge Cases

```yaml
jobs:
  test-error-cases:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup go-httpbin
        uses: lfreleng/setup-go-httpbin@v1
        id: httpbin

      - name: Test 404 handling
        uses: lfreleng-actions/http-api-tool-docker@main
        with:
          url: "${{ steps.httpbin.outputs.service-url }}/status/404"
          service_name: "404 endpoint test"
          verify_ssl: false
          expected_http_code: 404
          debug: true

      - name: Test timeout handling
        uses: lfreleng-actions/http-api-tool-docker@main
        with:
          url: "${{ steps.httpbin.outputs.service-url }}/delay/3"
          service_name: "Timeout test"
          verify_ssl: false
          curl_timeout: 5
          max_response_time: 4
          fail_on_timeout: false
          debug: true

      - name: Test large response
        uses: lfreleng-actions/http-api-tool-docker@main
        with:
          url: "${{ steps.httpbin.outputs.service-url }}/bytes/2048"
          service_name: "Large response test"
          verify_ssl: false
          expected_http_code: 200
          include_response_body: true
```

### Testing Docker Containers

```yaml
jobs:
  test-docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup go-httpbin
        uses: lfreleng/setup-go-httpbin@v1
        id: httpbin
        with:
          use-host-network: 'true'  # Better for container-to-container communication

      - name: Test containerized application
        run: |
          docker run --rm --network=host my-app:test \
            test-endpoint "${{ steps.httpbin.outputs.service-url }}/post"

### Performance and Load Testing

```yaml
jobs:
  performance-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup go-httpbin
        uses: lfreleng/setup-go-httpbin@v1
        id: httpbin
        with:
          debug: 'false'  # Reduce noise during performance tests
          wait-timeout: '120'  # Allow more time for heavy load
          docker-run-args: '--cpus=1.0 --memory=512m'  # Resource limits

      - name: Test response time limits
        uses: lfreleng-actions/http-api-tool-docker@main
        with:
          url: "${{ steps.httpbin.outputs.service-url }}/delay/1"
          service_name: "Performance test"
          verify_ssl: false
          max_response_time: 2
          fail_on_timeout: true
          retries: 3
          debug: true
```

## Troubleshooting

### Enable Debug Mode

```yaml
- uses: lfreleng/setup-go-httpbin@v1
  with:
    debug: 'true'
```

This will provide verbose output including:

- Certificate generation details
- Container startup logs
- Network connectivity tests
- Final service verification

### Common Issues

1. **Service not ready timeout**: Increase `wait-timeout` value
2. **SSL certificate issues**: Check `ca-cert-path` output and use it explicitly
3. **Network connectivity**: Try `use-host-network: 'true'` for
   container-to-container communication
4. **Port conflicts**: Change the `port` input to an available port

### Manual Debugging

```yaml
- name: Debug go-httpbin setup
  run: |
    # Check container status
    docker ps -a -f name="${{ steps.httpbin.outputs.container-name }}"

    # Check container logs
    docker logs "${{ steps.httpbin.outputs.container-name }}"

- name: Test connectivity with http-api-tool-docker
  uses: lfreleng-actions/http-api-tool-docker@main
  with:
    url: "${{ steps.httpbin.outputs.service-url }}/"
    service_name: "Debug connectivity test"
    verify_ssl: false
    debug: true
    retries: 1
  continue-on-error: true

- name: Check certificates
  run: |
    # Check certificates
    ls -la /tmp/localhost*pem
    openssl x509 -in "${{ steps.httpbin.outputs.cert-file }}" -text \
      -noout | head -10
```

## Testing and Development

This project uses a **comprehensive testing approach** with both local testing
capabilities and CI/CD integration.

### Local Testing

Run the input validation test suite locally:

```bash
# Run all security validation tests
./tests/test-input-validation.sh

# Run with verbose output for debugging
./tests/test-input-validation.sh -v

# Keep containers after tests for inspection
./tests/test-input-validation.sh --no-cleanup

# Show help and options
./tests/test-input-validation.sh --help
```

### Test Suite Overview

#### Input Validation Tests (`tests/test-input-validation.sh`)

A comprehensive shell script that validates the action's security measures
and input handling:

**Security Tests (Should Fail):**

- **Command Injection:** `--memory=512m; curl evil.com`
- **Variable Expansion:** `--env=${HOME}/malicious`, `--env=$PATH`
- **Code Execution:** `--memory=$(curl evil.com)`, `--memory=\`curl evil.com\``
- **Shell Redirection:** `--memory < /etc/passwd`, `--memory > /tmp/evil`
- **Invalid Formats:** `--mem@ry=512m`

**Valid Input Tests (Should Succeed):**

- **Resource Limits:** `--memory=512m --cpu-shares=512`
- **Network Config:** `--network=bridge --publish=8080:8080`
- **Combined Args:** `--memory=512m --cpu-shares=512 --restart=unless-stopped`
- **Short Flags:** `-m 512m`
- **Empty Args:** `""`

**Test Features:**

- **Local Execution:** Run the same tests locally and in CI
- **No Parameter Escaping:** Direct string testing without GitHub Actions
  template expansion issues
- **Comprehensive Coverage:** 16 different security and functionality scenarios
- **Colored Output:** Clear pass/fail indicators with detailed logging
- **Cleanup Management:** Automatic container cleanup with optional retention

#### CI/CD Integration

The test suite integrates with GitHub Actions workflow:

```yaml
# .github/workflows/input-validation.yaml
- name: 'Run Input Validation Tests'
  run: ./tests/test-input-validation.sh --verbose
```

**Workflow Benefits:**

- **Simplified Configuration:** Single script call instead of 25+ individual
  test steps
- **Better Maintainability:** Easy to add new tests without complex YAML
- **Consistent Environment:** Same validation logic runs locally and in CI
- **Enhanced Security:** No GitHub Actions template expansion interference
- **Clear Reporting:** Detailed test results with artifact generation

### Adding New Tests

To add a new security test:

1. **Create Test Function:**

```bash
test_new_security_scenario() {
    run_action_test \
        "Description of security test" \
        "container-name" \
        "port" \
        "malicious-docker-args" \
        "true"  # Should fail
}
```

1. **Add to Main Function:**

```bash
# In main() function
test_new_security_scenario
```

1. **Test Locally:**

```bash
./tests/test-input-validation.sh -v
```

### Validation Logic

The test suite uses the same security validation logic as the action:

```bash
# Command injection patterns
[[ "$arg" == *";"* ]] || [[ "$arg" == *"&"* ]] || [[ "$arg" == *"|"* ]]

# Code execution patterns
[[ "$arg" == *'$('* ]] || [[ "$arg" == *'`'* ]]

# Variable expansion patterns
[[ "$arg" == *'${'* ]] || [[ "$arg" =~ \$[A-Za-z_] ]]

# Shell redirection
[[ "$arg" == *"<"* ]] || [[ "$arg" == *">"* ]]

# Docker argument format
[[ "$arg" =~ ^--?[a-zA-Z0-9-]+(=.*)?$ ]]
```

### Prerequisites for Local Testing

- **Bash 4.0+** for the test script
- **Docker** (for container cleanup validation)
- **Git** (for repository operations)

### Troubleshooting Tests

**Test Script Issues:**

```bash
# Make script executable
chmod +x tests/test-input-validation.sh

# Check script syntax
bash -n tests/test-input-validation.sh

# Run with debug output
./tests/test-input-validation.sh -v
```

**Common Problems:**

- **Permission Denied:** Ensure script is executable
- **Docker Access:** Verify Docker daemon is running
- **Path Issues:** Run from repository root directory

**Debug Commands:**

```bash
# Check test environment
docker --version
bash --version

# Verify action structure
ls -la action.yaml

# Test single validation
echo '--env=$PATH' | grep '\$[A-Za-z_]'
```

## Requirements

- Linux or macOS runner (Windows is not supported)
- Docker (available by default in GitHub Actions runners)
- Go 1.18+ (will be automatically installed if not available or too old)
- Internet connectivity (for downloading dependencies and building mkcert from source)

## Security and Cross-Platform Support

This action installs `mkcert` from source for enhanced security and
cross-platform compatibility:

- **Source Verification**: Pins to a specific Git commit
  (`2a46726cebac0ff4e1f133d90b4e4c42f1edf44a`) for mkcert v1.4.4
- **Cross-Platform**: Works on Linux and macOS runners
  (Windows is not supported)
- **Go Version Management**: Automatically installs Go if not available
  or if version is too old
- **Platform-Specific Dependencies**: Installs appropriate NSS tools
  for each supported platform

## License

This action uses the Apache License 2.0. See the LICENSE file for details.
