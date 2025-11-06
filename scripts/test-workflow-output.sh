#!/usr/bin/env bash
# test-workflow-output.sh - E2E test for workflow output retrieval
#
# Usage:
#   scripts/test-workflow-output.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test configuration
WEBHOOK_URL="${WEBHOOK_URL:-https://webhook.site/test}"
WORKFLOW_FILE="data-processor.yml"
RUNS_DIR="runs"
FAILED_TESTS=0
PASSED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_test() {
  echo "----------------------------------------"
  echo "TEST: $1"
  echo "----------------------------------------"
}

log_pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  FAILED_TESTS=$((FAILED_TESTS + 1))
}

log_info() {
  echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Test 1: Add operation
test_add_operation() {
  log_test "Add Operation: 10 + 20 = 30"

  log_info "Triggering workflow..."
  result=$("${SCRIPT_DIR}/trigger-and-track.sh" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow "$WORKFLOW_FILE" \
    --input operation=add \
    --input value1=10 \
    --input value2=20 \
    --store-dir "$RUNS_DIR" \
    --json-only 2>&1) || {
    log_fail "Failed to trigger workflow"
    return 1
  }

  run_id=$(echo "$result" | jq -r '.run_id')
  correlation_id=$(echo "$result" | jq -r '.correlation_id')

  log_info "Run ID: $run_id"
  log_info "Correlation ID: $correlation_id"

  # Wait for workflow to complete
  log_info "Waiting for workflow completion..."
  gh run watch "$run_id" --exit-status || {
    log_fail "Workflow execution failed"
    return 1
  }

  # Retrieve output
  log_info "Retrieving workflow output..."
  output=$("${SCRIPT_DIR}/get-workflow-output.sh" --run-id "$run_id" --json 2>&1) || {
    log_fail "Failed to retrieve workflow output"
    echo "Error: $output"
    return 1
  }

  # Validate output structure
  operation=$(echo "$output" | jq -r '.operation')
  result_value=$(echo "$output" | jq -r '.result')
  input1=$(echo "$output" | jq -r '.inputs.value1')
  input2=$(echo "$output" | jq -r '.inputs.value2')

  if [[ "$operation" != "add" ]]; then
    log_fail "Expected operation 'add', got '$operation'"
    return 1
  fi

  if [[ "$result_value" != "30" ]]; then
    log_fail "Expected result '30', got '$result_value'"
    return 1
  fi

  if [[ "$input1" != "10" ]] || [[ "$input2" != "20" ]]; then
    log_fail "Input values not preserved correctly"
    return 1
  fi

  log_pass "Add operation test"
  echo "Output: $output" | jq .
}

# Test 2: Multiply operation
test_multiply_operation() {
  log_test "Multiply Operation: 5 * 7 = 35"

  log_info "Triggering workflow..."
  result=$("${SCRIPT_DIR}/trigger-and-track.sh" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow "$WORKFLOW_FILE" \
    --input operation=multiply \
    --input value1=5 \
    --input value2=7 \
    --store-dir "$RUNS_DIR" \
    --json-only 2>&1) || {
    log_fail "Failed to trigger workflow"
    return 1
  }

  run_id=$(echo "$result" | jq -r '.run_id')

  log_info "Run ID: $run_id"
  log_info "Waiting for completion..."
  gh run watch "$run_id" --exit-status || {
    log_fail "Workflow execution failed"
    return 1
  }

  output=$("${SCRIPT_DIR}/get-workflow-output.sh" --run-id "$run_id" --json 2>&1) || {
    log_fail "Failed to retrieve workflow output"
    return 1
  }

  result_value=$(echo "$output" | jq -r '.result')

  if [[ "$result_value" != "35" ]]; then
    log_fail "Expected result '35', got '$result_value'"
    return 1
  fi

  log_pass "Multiply operation test"
}

# Test 3: Concat operation
test_concat_operation() {
  log_test "Concat Operation: 'hello' + 'world' = 'helloworld'"

  log_info "Triggering workflow..."
  result=$("${SCRIPT_DIR}/trigger-and-track.sh" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow "$WORKFLOW_FILE" \
    --input operation=concat \
    --input value1=hello \
    --input value2=world \
    --store-dir "$RUNS_DIR" \
    --json-only 2>&1) || {
    log_fail "Failed to trigger workflow"
    return 1
  }

  run_id=$(echo "$result" | jq -r '.run_id')

  log_info "Run ID: $run_id"
  log_info "Waiting for completion..."
  gh run watch "$run_id" --exit-status || {
    log_fail "Workflow execution failed"
    return 1
  }

  output=$("${SCRIPT_DIR}/get-workflow-output.sh" --run-id "$run_id" --json 2>&1) || {
    log_fail "Failed to retrieve workflow output"
    return 1
  }

  result_value=$(echo "$output" | jq -r '.result')

  if [[ "$result_value" != "helloworld" ]]; then
    log_fail "Expected result 'helloworld', got '$result_value'"
    return 1
  fi

  log_pass "Concat operation test"
}

# Test 4: Correlation ID tracking
test_correlation_tracking() {
  log_test "Correlation ID Tracking"

  log_info "Triggering workflow with correlation tracking..."
  result=$("${SCRIPT_DIR}/trigger-and-track.sh" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow "$WORKFLOW_FILE" \
    --input operation=add \
    --input value1=100 \
    --input value2=200 \
    --store-dir "$RUNS_DIR" \
    --json-only 2>&1) || {
    log_fail "Failed to trigger workflow"
    return 1
  }

  run_id=$(echo "$result" | jq -r '.run_id')
  correlation_id=$(echo "$result" | jq -r '.correlation_id')

  log_info "Run ID: $run_id"
  log_info "Correlation ID: $correlation_id"
  log_info "Waiting for completion..."

  gh run watch "$run_id" --exit-status || {
    log_fail "Workflow execution failed"
    return 1
  }

  # Retrieve via correlation ID
  log_info "Retrieving output via correlation ID..."
  output=$("${SCRIPT_DIR}/get-workflow-output.sh" \
    --correlation-id "$correlation_id" \
    --runs-dir "$RUNS_DIR" \
    --json 2>&1) || {
    log_fail "Failed to retrieve output via correlation ID"
    return 1
  }

  result_value=$(echo "$output" | jq -r '.result')

  if [[ "$result_value" != "300" ]]; then
    log_fail "Expected result '300', got '$result_value'"
    return 1
  fi

  log_pass "Correlation tracking test"
}

# Test 5: Pipeline composition
test_pipeline_composition() {
  log_test "Pipeline Composition (stdin)"

  log_info "Testing pipeline: trigger | get-output"
  output=$("${SCRIPT_DIR}/trigger-and-track.sh" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow "$WORKFLOW_FILE" \
    --input operation=multiply \
    --input value1=3 \
    --input value2=4 \
    --store-dir "$RUNS_DIR" \
    --json-only 2>&1 | tee /dev/stderr | {
      # Extract run_id and wait for completion
      read -r trigger_result
      run_id=$(echo "$trigger_result" | jq -r '.run_id')
      log_info "Waiting for run $run_id to complete..."
      gh run watch "$run_id" --exit-status
      # Pass through for get-workflow-output
      echo "$trigger_result"
    } | "${SCRIPT_DIR}/get-workflow-output.sh" --json 2>&1) || {
    log_fail "Pipeline composition failed"
    return 1
  }

  result_value=$(echo "$output" | jq -r '.result')

  if [[ "$result_value" != "12" ]]; then
    log_fail "Expected result '12', got '$result_value'"
    return 1
  fi

  log_pass "Pipeline composition test"
}

# Main test execution
main() {
  echo "========================================"
  echo "Workflow Output E2E Tests"
  echo "========================================"
  echo ""

  # Check prerequisites
  if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI not found"
    exit 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "Error: jq not found"
    exit 1
  fi

  # Run tests
  test_add_operation || true
  echo ""
  test_multiply_operation || true
  echo ""
  test_concat_operation || true
  echo ""
  test_correlation_tracking || true
  echo ""
  test_pipeline_composition || true

  # Summary
  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
  echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
  echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
  echo "========================================"

  if [[ $FAILED_TESTS -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
