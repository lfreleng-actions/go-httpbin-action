#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

set -euo pipefail

# GitHub Actions Local Testing Script
# This script runs both validation and comprehensive tests locally using act

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

check_prerequisites() {
    # Check if act is installed
    if ! command -v act &> /dev/null; then
        echo -e "${RED}❌ Error: 'act' is not installed${NC}"
        echo ""
        echo "Please install act first:"
        echo "  macOS: brew install act"
        echo "  Linux: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
        echo ""
        echo "More info: https://github.com/nektos/act"
        return 1
    fi

    echo -e "${BLUE}ℹ️  Using act version:${NC}"
    act --version
    echo ""

    # Check if Docker is running and accessible
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Error: Docker is not accessible${NC}"
        echo ""
        echo "Possible solutions:"
        echo "1. Start Docker Desktop/daemon"
        echo "2. Add your user to the docker group:"
        echo "   sudo usermod -aG docker \$USER"
        echo "   newgrp docker"
        echo "3. On macOS with Docker Desktop, ensure it's running"
        echo ""
        echo "Try: docker info"
        return 1
    fi

    echo -e "${BLUE}🐳 Docker is accessible${NC}"
    echo ""
}

setup_docker_host() {
    # Build the act command with proper Docker host detection
    if [[ -S "/Users/$USER/.docker/run/docker.sock" ]]; then
        # macOS Docker Desktop
        export DOCKER_HOST="unix:///Users/$USER/.docker/run/docker.sock"
        echo -e "${BLUE}Using Docker Desktop socket: $DOCKER_HOST${NC}"
    elif [[ -S "/var/run/docker.sock" ]]; then
        # Standard Docker daemon
        export DOCKER_HOST="unix:///var/run/docker.sock"
        echo -e "${BLUE}Using standard Docker socket: $DOCKER_HOST${NC}"
    else
        echo -e "${YELLOW}Using default Docker configuration${NC}"
    fi
}

run_validation_tests() {
    echo ""
    echo -e "${YELLOW}🔒 Running Input Validation Tests...${NC}"
    echo "This may take ~5 minutes to complete."
    echo ""

    local act_cmd="act -W .github/workflows/input-validation.yaml -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/amd64"

    echo -e "${BLUE}Command: $act_cmd${NC}"
    echo ""

    if $act_cmd; then
        echo ""
        echo -e "${GREEN}✅ SUCCESS: Input Validation Tests passed!${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}❌ FAILED: Input Validation Tests failed${NC}"
        return 1
    fi
}

run_comprehensive_tests() {
    echo ""
    echo -e "${YELLOW}🧪 Running Comprehensive Tests...${NC}"
    echo "This may take ~10-15 minutes to complete."
    echo ""

    local act_cmd="act -j comprehensive-test-suite -W .github/workflows/testing.yaml -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/amd64"

    echo -e "${BLUE}Command: $act_cmd${NC}"
    echo ""

    if $act_cmd; then
        echo ""
        echo -e "${GREEN}✅ SUCCESS: Comprehensive Tests passed!${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}❌ FAILED: Comprehensive Tests failed${NC}"
        return 1
    fi
}

show_test_results() {
    local validation_result="$1"
    local comprehensive_result="$2"

    echo ""
    echo "========================================="
    echo "🎯 Test Results Summary"
    echo "========================================="

    if [[ $validation_result -eq 0 && $comprehensive_result -eq 0 ]]; then
        echo -e "${GREEN}✅ SUCCESS: All tests passed!${NC}"
        echo ""
        echo "🔒 Security validation complete:"
        echo "  • Command injection attempts were properly blocked"
        echo "  • Valid Docker arguments were properly allowed"
        echo "  • Input validation system is working correctly"
        echo ""
        echo "🧪 Comprehensive testing complete:"
        echo "  • HTTP/HTTPS connectivity tests passed"
        echo "  • SSL certificate validation works correctly"
        echo "  • Request methods and authentication tested"
        echo "  • Network configurations validated"
        echo "  • Docker container management tested"
        echo ""
        echo "The go-httpbin-action is ready for use!"
        return 0
    else
        echo -e "${RED}❌ FAILED: Some tests failed${NC}"
        echo ""
        if [[ $validation_result -ne 0 ]]; then
            echo "• Security validation tests: FAILED"
        else
            echo "• Security validation tests: PASSED"
        fi

        if [[ $comprehensive_result -ne 0 ]]; then
            echo "• Comprehensive functionality tests: FAILED"
        else
            echo "• Comprehensive functionality tests: PASSED"
        fi
        echo ""
        echo "Common issues and solutions:"
        echo "  • Docker permission denied:"
        echo "    - Add user to docker group: sudo usermod -aG docker \$USER && newgrp docker"
        echo "    - On macOS: Ensure Docker Desktop is running"
        echo "  • Network connectivity issues:"
        echo "    - Check internet connection for pulling images"
        echo "  • Resource constraints:"
        echo "    - Free up Docker resources: docker system prune"
        echo "    - Increase Docker memory/CPU limits"
        echo ""
        echo "Please review the output above and fix any issues."
        return 1
    fi
}

# Main execution
main() {
    # Show header
    echo "🧪 GitHub Actions Local Testing"
    echo "==============================="
    echo ""

    # Change to project root
    cd "$PROJECT_ROOT"

    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi

    # Setup Docker
    setup_docker_host

    echo ""
    echo -e "${BLUE}Running both validation and comprehensive tests...${NC}"

    # Run validation tests first
    run_validation_tests
    validation_result=$?

    # Run comprehensive tests second
    run_comprehensive_tests
    comprehensive_result=$?

    # Show results and exit with appropriate code
    show_test_results "$validation_result" "$comprehensive_result"
    exit_code=$?
    exit $exit_code
}

# Execute main function
main "$@"
