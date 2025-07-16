<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- SPDX-FileCopyrightText: 2025 The Linux Foundation -->

# Scripts Directory

This directory contains utility scripts for the go-httpbin-action project.

## Scripts

### `run-tests.sh` - Local Test Runner

Runs GitHub Actions workflows locally using [act](https://github.com/nektos/act).
This script runs both security validation tests and comprehensive
functionality tests sequentially.

**Prerequisites:**

- [Docker](https://www.docker.com/) must be running
- Install [act](https://github.com/nektos/act):

  ```bash
  # macOS
  brew install act

  # Linux
  curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
  ```

**Usage:**

```bash
# Run both validation and comprehensive tests
./scripts/run-tests.sh
```

The script automatically runs:

1. Security validation tests (~5 minutes)
2. Comprehensive functionality tests (~10-15 minutes)

**What validation tests cover:**

- **Security validation:** Command injection, code execution, variable
  expansion attacks
- **Valid inputs:** Standard Docker resource limits, flags, quoted arguments
- **Edge cases:** Empty inputs, whitespace handling, multi-line YAML parsing

**What comprehensive tests cover:**

- **HTTP/HTTPS connectivity:** Basic and SSL-enabled requests
- **Certificate management:** Custom certificates, CA bundles, mkcert
  integration
- **Request methods:** GET, POST, PUT, DELETE with different payloads
- **Authentication:** Basic auth, custom headers, bearer tokens
- **Network configurations:** Host network mode, custom ports, container
  networking
- **Docker management:** Container lifecycle, resource limits, volume mounts
- **Response validation:** Status codes, content matching, timeout handling
- **Error handling:** Retry logic, failure scenarios, edge cases

**Exit codes:** `0` for success, `1` for failure.

## Adding New Scripts

When adding new scripts:

1. Make them executable: `chmod +x scripts/your-script.sh`
2. Add shebang: `#!/usr/bin/env bash` (for compatibility)
3. Include error handling: `set -euo pipefail`
4. Document the script in this README
5. Test with existing validation workflows

## Testing Strategy

The project uses **GitHub Actions-first testing**:

- **Local Testing:** Use `./scripts/run-tests.sh` to run both security and
  functionality tests
- **CI/CD:** Workflows run automatically on push/PR
- **Development:** Local testing with `act` provides immediate feedback

This ensures local testing matches the production environment across both
security and functionality.
