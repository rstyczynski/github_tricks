#!/usr/bin/env bash
set -euo pipefail

# Test script for cancel-run.sh (GH-6 and GH-7)
# Tests both immediate cancellation and running cancellation scenarios

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANCEL_SCRIPT="$SCRIPT_DIR/cancel-run.sh"
TRIGGER_SCRIPT="$SCRIPT_DIR/trigger-and-track.sh"
VIEW_SCRIPT="$SCRIPT_DIR/view-run-jobs.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Check prerequisites
check_prerequisites() {
  printf 'Checking prerequisites...\n'
  
  if [[ -z "${WEBHOOK_URL:-}" ]]; then
    printf '%bError: WEBHOOK_URL environment variable not set%b\n' "$RED" "$NC"
    printf 'Set it to your webhook.site URL or local webhook receiver\n'
    exit 1
  fi
  
  if ! command -v gh >/dev/null 2>&1; then
    printf '%bError: gh CLI not found%b\n' "$RED" "$NC"
    exit 1
  fi
  
  if ! gh auth status >/dev/null 2>&1; then
    printf '%bError: gh CLI not authenticated%b\n' "$RED" "$NC"
    exit 1
  fi
  
  printf '%bPrerequisites OK%b\n' "$GREEN" "$NC"
}

# Test helper: print test header
print_test_header() {
  local test_id="$1"
  local test_name="$2"
  printf '\n%b=== Test %s: %s ===%b\n' "$YELLOW" "$test_id" "$test_name" "$NC"
}

# Test helper: assert success
assert_success() {
  local test_id="$1"
  local message="$2"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '%b✓ %s: %s%b\n' "$GREEN" "$test_id" "$message" "$NC"
}

# Test helper: assert failure
assert_failure() {
  local test_id="$1"
  local message="$2"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '%b✗ %s: %s%b\n' "$RED" "$test_id" "$message" "$NC"
}

# Test GH-6: Cancel immediately after dispatch
test_gh6_immediate_cancel() {
  print_test_header "GH-6" "Cancel immediately after dispatch"
  
  printf 'Triggering workflow...\n'
  local result
  if ! result=$("$TRIGGER_SCRIPT" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow .github/workflows/dispatch-webhook.yml \
    --store-dir runs \
    --json-only 2>&1); then
    assert_failure "GH-6" "Failed to trigger workflow"
    return 1
  fi
  
  local run_id correlation_id
  run_id=$(echo "$result" | jq -r '.run_id' 2>/dev/null)
  correlation_id=$(echo "$result" | jq -r '.correlation_id' 2>/dev/null)
  
  if [[ -z "$run_id" ]] || [[ "$run_id" == "null" ]]; then
    assert_failure "GH-6" "Failed to get run_id from trigger result"
    return 1
  fi
  
  printf 'Workflow triggered: run_id=%s, correlation_id=%s\n' "$run_id" "$correlation_id"
  
  # Cancel immediately
  printf 'Cancelling immediately...\n'
  local cancel_result
  if ! cancel_result=$("$CANCEL_SCRIPT" --run-id "$run_id" --wait --json 2>&1); then
    assert_failure "GH-6" "Cancel command failed"
    printf 'Cancel output: %s\n' "$cancel_result"
    return 1
  fi
  
  # Parse cancel result
  local final_conclusion
  final_conclusion=$(echo "$cancel_result" | jq -r '.final_conclusion' 2>/dev/null)
  
  if [[ "$final_conclusion" == "cancelled" ]]; then
    assert_success "GH-6" "Workflow successfully cancelled (conclusion: cancelled)"
  else
    assert_failure "GH-6" "Unexpected conclusion: $final_conclusion (expected: cancelled)"
    printf 'Cancel result: %s\n' "$cancel_result"
    return 1
  fi
  
  # Verify with view-run-jobs
  printf 'Verifying with view-run-jobs.sh...\n'
  if "$VIEW_SCRIPT" --run-id "$run_id" --json | jq -e '.conclusion == "cancelled"' >/dev/null 2>&1; then
    assert_success "GH-6" "Verification confirmed: conclusion is cancelled"
  else
    assert_failure "GH-6" "Verification failed: conclusion is not cancelled"
    return 1
  fi
  
  printf '%bGH-6 Test PASSED%b\n' "$GREEN" "$NC"
  return 0
}

# Test GH-7: Cancel after correlation (early timing)
test_gh7_cancel_after_correlation() {
  print_test_header "GH-7-1" "Cancel after correlation (early timing)"
  
  printf 'Triggering workflow with correlation...\n'
  local result
  if ! result=$("$TRIGGER_SCRIPT" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow .github/workflows/dispatch-webhook.yml \
    --store-dir runs \
    --json-only 2>&1); then
    assert_failure "GH-7-1" "Failed to trigger workflow"
    return 1
  fi
  
  local run_id correlation_id
  run_id=$(echo "$result" | jq -r '.run_id' 2>/dev/null)
  correlation_id=$(echo "$result" | jq -r '.correlation_id' 2>/dev/null)
  
  if [[ -z "$correlation_id" ]] || [[ "$correlation_id" == "null" ]]; then
    assert_failure "GH-7-1" "Failed to get correlation_id"
    return 1
  fi
  
  printf 'Workflow triggered: run_id=%s, correlation_id=%s\n' "$run_id" "$correlation_id"
  
  # Cancel using correlation ID
  printf 'Cancelling using correlation ID...\n'
  local cancel_result
  if ! cancel_result=$("$CANCEL_SCRIPT" \
    --correlation-id "$correlation_id" \
    --runs-dir runs \
    --wait --json 2>&1); then
    assert_failure "GH-7-1" "Cancel command failed"
    return 1
  fi
  
  # Parse result
  local final_conclusion status_before
  final_conclusion=$(echo "$cancel_result" | jq -r '.final_conclusion' 2>/dev/null)
  status_before=$(echo "$cancel_result" | jq -r '.status_before' 2>/dev/null)
  
  printf 'Status before cancel: %s\n' "$status_before"
  printf 'Final conclusion: %s\n' "$final_conclusion"
  
  if [[ "$final_conclusion" == "cancelled" ]]; then
    assert_success "GH-7-1" "Workflow cancelled (status before: $status_before)"
  else
    assert_failure "GH-7-1" "Unexpected conclusion: $final_conclusion"
    return 1
  fi
  
  printf '%bGH-7-1 Test PASSED%b\n' "$GREEN" "$NC"
  return 0
}

# Test GH-7: Cancel during execution (late timing)
test_gh7_cancel_during_execution() {
  print_test_header "GH-7-2" "Cancel during execution (late timing)"
  
  # Check if long-run-logger workflow exists
  if [[ ! -f ".github/workflows/long-run-logger.yml" ]]; then
    printf '%bWarning: long-run-logger.yml not found, skipping test%b\n' "$YELLOW" "$NC"
    return 0
  fi
  
  printf 'Triggering long-running workflow...\n'
  local result
  if ! result=$("$TRIGGER_SCRIPT" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow .github/workflows/long-run-logger.yml \
    --input iterations=20 \
    --input sleep_seconds=3 \
    --store-dir runs \
    --json-only 2>&1); then
    assert_failure "GH-7-2" "Failed to trigger workflow"
    return 1
  fi
  
  local run_id
  run_id=$(echo "$result" | jq -r '.run_id' 2>/dev/null)
  
  printf 'Long-running workflow triggered: run_id=%s\n' "$run_id"
  printf 'Waiting for workflow to start running...\n'
  sleep 10
  
  # Check if it's running
  local current_status
  current_status=$(gh run view "$run_id" --json status -q '.status' 2>/dev/null || echo "unknown")
  printf 'Current status: %s\n' "$current_status"
  
  # Cancel during execution
  printf 'Cancelling during execution...\n'
  local cancel_result
  if ! cancel_result=$("$CANCEL_SCRIPT" \
    --run-id "$run_id" \
    --wait --json 2>&1); then
    assert_failure "GH-7-2" "Cancel command failed"
    return 1
  fi
  
  # Parse result
  local final_conclusion status_before
  final_conclusion=$(echo "$cancel_result" | jq -r '.final_conclusion' 2>/dev/null)
  status_before=$(echo "$cancel_result" | jq -r '.status_before' 2>/dev/null)
  
  printf 'Status before cancel: %s\n' "$status_before"
  printf 'Final conclusion: %s\n' "$final_conclusion"
  
  if [[ "$final_conclusion" == "cancelled" ]]; then
    assert_success "GH-7-2" "Workflow cancelled during execution"
    
    # Verify partial execution
    printf 'Checking for partial execution...\n'
    if "$VIEW_SCRIPT" --run-id "$run_id" --json | \
      jq -e '.jobs[] | select(.conclusion == "success")' >/dev/null 2>&1; then
      assert_success "GH-7-2" "Partial execution detected (some jobs completed)"
    else
      printf 'Note: No jobs completed before cancellation\n'
    fi
  else
    assert_failure "GH-7-2" "Unexpected conclusion: $final_conclusion"
    return 1
  fi
  
  printf '%bGH-7-2 Test PASSED%b\n' "$GREEN" "$NC"
  return 0
}

# Test help and basic functionality
test_basic_functionality() {
  print_test_header "BASIC" "Help and basic functionality"
  
  # Test --help
  if "$CANCEL_SCRIPT" --help >/dev/null 2>&1; then
    assert_success "BASIC" "--help flag works"
  else
    assert_failure "BASIC" "--help flag failed"
  fi
  
  # Test missing run ID (should fail with error)
  if "$CANCEL_SCRIPT" --json </dev/null 2>/dev/null; then
    assert_failure "BASIC" "Should fail with no run ID provided"
  else
    assert_success "BASIC" "Correctly fails when no run ID provided"
  fi
}

# Test stdin JSON input
test_stdin_json() {
  print_test_header "INT-1" "Pipeline integration (stdin JSON)"
  
  printf 'Testing pipeline integration...\n'
  local result
  if ! result=$("$TRIGGER_SCRIPT" \
    --webhook-url "$WEBHOOK_URL" \
    --workflow .github/workflows/dispatch-webhook.yml \
    --json-only 2>&1 | \
    "$CANCEL_SCRIPT" --wait --json 2>&1); then
    assert_failure "INT-1" "Pipeline integration failed"
    return 1
  fi
  
  # Parse result
  local final_conclusion
  final_conclusion=$(echo "$result" | jq -r '.final_conclusion' 2>/dev/null)
  
  if [[ "$final_conclusion" == "cancelled" ]]; then
    assert_success "INT-1" "Pipeline integration works (stdin JSON)"
  else
    assert_failure "INT-1" "Pipeline failed, conclusion: $final_conclusion"
    return 1
  fi
  
  printf '%bINT-1 Test PASSED%b\n' "$GREEN" "$NC"
  return 0
}

# Main test execution
main() {
  printf '%b============================================%b\n' "$YELLOW" "$NC"
  printf '%b  Sprint 11 Cancel Run Tests%b\n' "$YELLOW" "$NC"
  printf '%b============================================%b\n' "$YELLOW" "$NC"
  
  check_prerequisites
  
  # Run tests
  test_basic_functionality || true
  test_gh6_immediate_cancel || true
  test_gh7_cancel_after_correlation || true
  test_stdin_json || true
  test_gh7_cancel_during_execution || true
  
  # Print summary
  printf '\n%b============================================%b\n' "$YELLOW" "$NC"
  printf '%b  Test Summary%b\n' "$YELLOW" "$NC"
  printf '%b============================================%b\n' "$YELLOW" "$NC"
  printf 'Tests Passed: %b%d%b\n' "$GREEN" "$TESTS_PASSED" "$NC"
  printf 'Tests Failed: %b%d%b\n' "$RED" "$TESTS_FAILED" "$NC"
  printf 'Total Tests: %d\n' "$((TESTS_PASSED + TESTS_FAILED))"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    printf '\n%b✓ All tests PASSED%b\n' "$GREEN" "$NC"
    return 0
  else
    printf '\n%b✗ Some tests FAILED%b\n' "$RED" "$NC"
    return 1
  fi
}

main "$@"

