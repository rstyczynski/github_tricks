#!/bin/bash

# Test orchestration end-to-end functionality
# Sprint 20, GH-27

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RESULTS_FILE="${PROJECT_ROOT}/tests/orchestration-test-results.json"
LOG_DIR="${PROJECT_ROOT}/tests/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "${LOG_DIR}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    echo ""
    echo "=========================================="
    echo "Running test: ${test_name}"
    echo "=========================================="
    
    local start_time
    start_time=$(date +%s)
    
    local exit_code=0
    local log_file="${LOG_DIR}/${test_name// /_}.log"
    
    # Run test and capture output
    if eval "${test_command}" > "${log_file}" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local status="FAIL"
    local status_icon="✗"
    if [[ ${exit_code} -eq ${expected_exit_code} ]]; then
        status="PASS"
        status_icon="✓"
    fi
    
    if [[ "${status}" == "PASS" ]]; then
        log_info "${status_icon} ${test_name}: ${status} (${duration}s)"
    else
        log_error "${status_icon} ${test_name}: ${status} (${duration}s)"
        log_error "  Exit code: ${exit_code} (expected: ${expected_exit_code})"
        log_error "  Log file: ${log_file}"
    fi
    
    # Record result
    jq -n \
        --arg name "${test_name}" \
        --arg status "${status}" \
        --arg exit_code "${exit_code}" \
        --arg expected "${expected_exit_code}" \
        --arg duration "${duration}" \
        --arg log_file "${log_file}" \
        '{
            test: $name,
            status: $status,
            exit_code: ($exit_code | tonumber),
            expected_exit_code: ($expected | tonumber),
            duration_seconds: ($duration | tonumber),
            log_file: $log_file,
            timestamp: now | todateiso8601
        }' >> "${RESULTS_FILE}.tmp"
    
    return $([ "${status}" == "PASS" ] && echo 0 || echo 1)
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for required scripts
    if [[ ! -x "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh" ]]; then
        log_error "orchestrate-workflow.sh not found or not executable"
        return 1
    fi
    
    # Check for workflow file
    if [[ ! -f "${PROJECT_ROOT}/.github/workflows/process-and-return.yml" ]]; then
        log_error "process-and-return.yml workflow not found"
        return 1
    fi
    
    # Check for token
    if [[ ! -f "${PROJECT_ROOT}/secrets/token" ]]; then
        log_warning "Token file not found - some tests may fail"
    fi
    
    log_info "Prerequisites check complete"
    return 0
}

main() {
    echo "=========================================="
    echo "   ORCHESTRATION TEST SUITE"
    echo "   Sprint 20 - GH-27"
    echo "=========================================="
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    # Initialize results file
    echo "[]" > "${RESULTS_FILE}"
    rm -f "${RESULTS_FILE}.tmp"
    
    local failed_count=0
    
    # Test 1: Help message
    if run_test \
        "Help message display" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --help" \
        0; then
        : # success
    else
        ((failed_count++))
    fi
    
    # Test 2: Missing required parameter (should fail)
    if run_test \
        "Missing required parameter" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string test" \
        1; then
        : # success
    else
        ((failed_count++))
    fi
    
    # Test 3: Invalid array length (should fail)
    if run_test \
        "Invalid array length (negative)" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string test --length -5" \
        1; then
        : # success
    else
        ((failed_count++))
    fi
    
    # Test 4: Invalid array length (zero - should fail)
    if run_test \
        "Invalid array length (zero)" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string test --length 0" \
        1; then
        : # success
    else
        ((failed_count++))
    fi
    
    # Test 5: Invalid array length (too large - should fail)
    if run_test \
        "Invalid array length (>1000)" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string test --length 1001" \
        1; then
        : # success
    else
        ((failed_count++))
    fi
    
    # Only run integration tests if token exists
    if [[ -f "${PROJECT_ROOT}/secrets/token" ]]; then
        log_info "Token found - running integration tests"
        
        # Test 6: Basic orchestration (small array)
        if run_test \
            "Basic orchestration (length=5)" \
            "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string test --length 5" \
            0; then
            : # success
        else
            ((failed_count++))
        fi
        
        # Test 7: Medium array
        log_warning "Skipping medium array test to conserve GitHub Actions minutes"
        # Uncomment to enable:
        # if run_test \
        #     "Medium array orchestration (length=10)" \
        #     "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string medium --length 10" \
        #     0; then
        #     : # success
        # else
        #     ((failed_count++))
        # fi
    else
        log_warning "Token not found - skipping integration tests"
        log_warning "To run integration tests, add token to ${PROJECT_ROOT}/secrets/token"
    fi
    
    # Aggregate results
    if [[ -f "${RESULTS_FILE}.tmp" ]]; then
        jq -s '.' "${RESULTS_FILE}.tmp" > "${RESULTS_FILE}"
        rm -f "${RESULTS_FILE}.tmp"
    fi
    
    # Summary
    echo ""
    echo "=========================================="
    echo "         TEST SUMMARY"
    echo "=========================================="
    
    local total_tests
    total_tests=$(jq '. | length' "${RESULTS_FILE}")
    local passed_tests
    passed_tests=$(jq '[.[] | select(.status == "PASS")] | length' "${RESULTS_FILE}")
    local failed_tests
    failed_tests=$(jq '[.[] | select(.status == "FAIL")] | length' "${RESULTS_FILE}")
    
    echo "Total tests:  ${total_tests}"
    echo "Passed:       ${passed_tests}"
    echo "Failed:       ${failed_tests}"
    echo ""
    echo "Results file: ${RESULTS_FILE}"
    echo "Log directory: ${LOG_DIR}"
    echo ""
    
    if [[ ${failed_tests} -gt 0 ]]; then
        log_error "Some tests failed"
        echo ""
        echo "Failed tests:"
        jq -r '.[] | select(.status == "FAIL") | "  - \(.test) (exit code: \(.exit_code), expected: \(.expected_exit_code))"' "${RESULTS_FILE}"
        echo ""
        exit 1
    fi
    
    log_info "All tests passed!"
    echo ""
    exit 0
}

main "$@"

