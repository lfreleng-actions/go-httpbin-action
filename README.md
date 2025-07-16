<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Setup Go-httpbin GitHub Action

A GitHub Action that sets up a local
[go-httpbin](https://github.com/mccutchen/go-httpbin) service with HTTPS support
using mkcert for testing HTTP API tools and services.

## Features

- 🔒 **HTTPS Support**: Automatically generates valid SSL certificates using mkcert
- 🐳 **Docker-based**: Runs go-httpbin in a Docker container for isolation
- 🔧 **Highly Configurable**: Supports configuration options for different use cases
- 🚀 **Fast Setup**: Optimized for CI/CD pipelines with caching considerations
- 🌐 **Network Flexibility**: Supports both host networking and standard port mapping
- 📊 **Debug Support**: Optional verbose logging for troubleshooting

## Usage

### Basic Usage

```yaml
steps:
  - name: Setup go-httpbin
    uses: lfreleng/setup-go-httpbin@v1
    id: httpbin

  - name: Test API endpoint
    uses: lfreleng-actions/http-api-tool-docker@main
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

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `container-name` | Name for the Docker container | No | `go-httpbin` |
| `port` | Port to expose the service on | No | `8080` |
| `image` | Docker image to use | No | `ghcr.io/mccutchen/go-httpbin` |
| `image-tag` | Tag of the Docker image | No | `latest` |
| `use-host-network` | Use host networking (true/false) | No | `false` |
| `wait-timeout` | Wait time for service ready (seconds) | No | `60` |
| `debug` | Enable debug output (true/false) | No | `false` |
| `cert-file-path` | SSL certificate file path | No | `/tmp/localhost-cert.pem` |
| `key-file-path` | SSL private key file path | No | `/tmp/localhost-key.pem` |
| `certificate-domains` | Extra domains for SSL certificate | No | `` |
| `skip-certificate` | Skip SSL certificate generation | No | `false` |
| `docker-run-args` | Extra Docker run arguments | No | `` |
| `install-deps` | Whether to install dependencies | No | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `container-name` | Name of the created container |
| `service-url` | Base URL of the running service |
| `host-gateway-ip` | Docker host gateway IP for container communication |
| `ca-cert-path` | Path to the mkcert CA certificate (relative to workspace) |
| `cert-file` | Path to the SSL certificate file |
| `key-file` | Path to the SSL private key file |
| `protocol` | Protocol used (http or https) |

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

Access the service at: `https://localhost:8080` or
`https://${{ steps.httpbin.outputs.host-gateway-ip }}:8080` from containers.

### Host Network Mode

Uses Docker host networking for direct access:

```yaml
- uses: lfreleng/setup-go-httpbin@v1
  with:
    use-host-network: 'true'
```

Access the service at: `https://localhost:8080` from both host and containers.

## SSL Certificate Handling

The action automatically:

1. Installs mkcert and creates a local CA
2. Generates SSL certificates for `localhost` and any extra domains
3. Installs the CA certificate in the system trust store
4. Provides paths to certificates for manual SSL verification

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

    # Test connectivity with http-api-tool-docker
    - uses: lfreleng-actions/http-api-tool-docker@main
      with:
        url: "${{ steps.httpbin.outputs.service-url }}/"
        service_name: "Debug connectivity test"
        verify_ssl: false
        debug: true
        retries: 1
      continue-on-error: true

    # Check certificates
    ls -la /tmp/localhost*pem
    openssl x509 -in "${{ steps.httpbin.outputs.cert-file }}" -text \
      -noout | head -10
```

## Requirements

- Ubuntu runner (tested on `ubuntu-latest` and `ubuntu-24.04`)
- Docker (available by default in GitHub Actions runners)
- Internet connectivity (for downloading mkcert and dependencies)

## License

This action uses the Apache License 2.0. See the LICENSE file for details.
