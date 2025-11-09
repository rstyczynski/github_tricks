# Sprint 11 - Design

## GH-6. Cancel requested workflow

Status: Progress

## GH-7. Cancel running workflow

Status: Progress

## Overview

Sprint 11 implements workflow cancellation capabilities, allowing operators to cancel workflows at different stages: immediately after dispatch (GH-6) and during execution (GH-7). This builds upon the correlation mechanism from Sprint 1 and the monitoring tools from Sprints 8-9.

## Feasibility Analysis

### GitHub API Capabilities

**Cancellation Endpoint** (from Sprint 5 research, REST API documentation):
- `POST /repos/:owner/:repo/actions/runs/:run_id/cancel`
  - Returns: HTTP 202 (Accepted) - asynchronous operation
  - Effect: Cancels workflow run, sets conclusion to "cancelled"
  - Status after cancellation: "completed" with conclusion "cancelled"
  - Documentation: https://docs.github.com/en/rest/actions/workflow-runs#cancel-a-workflow-run

**Force Cancellation Endpoint**:
- `POST /repos/:owner/:repo/actions/runs/:run_id/force-cancel`
  - Returns: HTTP 202 (Accepted)
  - Effect: Force cancels, bypassing `always()` conditions in workflow
  - Use case: Workflows stuck or ignoring standard cancellation

**GitHub CLI Command** (from Sprint 5 CLI analysis):
- `gh run cancel <run_id>`
  - Wraps REST API endpoint
  - Returns immediately (202 Accepted)
  - Documented as available but unused in previous sprints

### Cancellation Behavior Analysis

**Based on GitHub Actions documentation and Sprint 5 research:**

1. **Cancellation is asynchronous**: API returns 202 immediately, actual cancellation takes time
2. **Status transitions**: queued/in_progress → completing → completed (with conclusion: cancelled)
3. **Job-level impact**: 
   - Running jobs receive cancellation signal
   - Queued jobs never start
   - Completed jobs remain completed
4. **Steps with `if: always()` or `if: cancelled()` still execute** (unless force-cancel used)
5. **Cleanup steps may run** before final cancellation

### Feasibility Conclusion

**Fully achievable** - Both GH-6 and GH-7 requirements can be met:
- ✅ GitHub API provides cancellation endpoint
- ✅ GitHub CLI provides `gh run cancel` command
- ✅ Sprint 1 correlation provides run_id resolution
- ✅ Sprint 8/9 monitoring enables status verification
- ✅ No platform limitations identified

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Sprint 11: Cancel Run                     │
│                                                               │
│  Input Sources:                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  --run-id    │  │--correlation │  │  stdin JSON  │      │
│  │              │  │     -id      │  │   (pipe)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │               │
│         └──────────────────┴──────────────────┘              │
│                            │                                  │
│                            ▼                                  │
│                  ┌──────────────────┐                        │
│                  │  resolve_run_id  │                        │
│                  │   (run-utils.sh) │                        │
│                  └──────────────────┘                        │
│                            │                                  │
│                            ▼                                  │
│         ┌──────────────────────────────────┐                │
│         │                                    │                │
│         ▼                                    ▼                │
│  ┌─────────────┐                    ┌─────────────┐         │
│  │  gh run     │                    │  curl POST  │         │
│  │  cancel     │                    │  /cancel    │         │
│  └─────────────┘                    └─────────────┘         │
│         │                                    │                │
│         └──────────────┬───────────────────┘                │
│                        │                                      │
│                        ▼                                      │
│              ┌──────────────────┐                           │
│              │  HTTP 202        │                           │
│              │  (Accepted)      │                           │
│              └──────────────────┘                           │
│                        │                                      │
│                        ▼                                      │
│         ┌──────────────────────────────┐                    │
│         │  Optional: --wait            │                    │
│         │  Poll status until           │                    │
│         │  conclusion: cancelled       │                    │
│         └──────────────────────────────┘                    │
│                        │                                      │
│                        ▼                                      │
│              ┌──────────────────┐                           │
│              │  Output result   │                           │
│              │  (JSON or text)  │                           │
│              └──────────────────┘                           │
└─────────────────────────────────────────────────────────────┘

Integration with existing tools:
- Sprint 1: trigger-and-track.sh → correlation_id → run_id
- Sprint 8/9: view-run-jobs.sh → status monitoring
- Sprint 3: runs/<correlation_id>/metadata.json → run_id lookup
```

### Script Design: `scripts/cancel-run.sh`

**Command-line Interface**:

```bash
scripts/cancel-run.sh [--run-id <id>] [--correlation-id <uuid>] [--runs-dir <dir>] 
                      [--force] [--wait] [--json] [--help]
```

**Parameters**:
- `--run-id <id>` - Workflow run ID (numeric)
- `--correlation-id <uuid>` - Load run_id from stored metadata in `runs/<uuid>/metadata.json`
- `--runs-dir <dir>` - Base directory for metadata (default: `runs`)
- `--force` - Use force-cancel API endpoint (bypasses `always()` conditions)
- `--wait` - Poll until cancellation completes (status becomes "completed" with conclusion "cancelled")
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Input Resolution** (priority order, following Sprint 8 pattern):
1. `--run-id` explicitly provided
2. `--correlation-id` loads from stored metadata via `run-utils.sh`
3. stdin JSON (from `trigger-and-track.sh` output piped in)
4. Interactive prompt (if terminal and no other input)

**Output Formats**:

**Human-readable (default)**:
```
Cancelling workflow run: 1234567890
Status before cancellation: in_progress
Cancellation requested (HTTP 202 Accepted)
Run URL: https://github.com/owner/repo/actions/runs/1234567890

[If --wait specified:]
Waiting for cancellation to complete...
Final status: completed
Final conclusion: cancelled
Cancellation completed in 3 seconds
```

**JSON output (--json)**:
```json
{
  "run_id": 1234567890,
  "status_before": "in_progress",
  "cancellation_requested": true,
  "force": false,
  "url": "https://github.com/owner/repo/actions/runs/1234567890",
  "waited": true,
  "final_status": "completed",
  "final_conclusion": "cancelled",
  "cancellation_duration_seconds": 3
}
```

### Implementation Details

**Script Structure**:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/run-utils.sh"

# Default values
RUNS_DIR="runs"
FORCE=false
WAIT=false
JSON_OUTPUT=false
RUN_ID=""
CORRELATION_ID=""

# Function declarations
usage() { ... }
resolve_run_id_input() { ... }  # Reuse run-utils.sh patterns
get_run_status() { ... }         # Query current status before cancellation
cancel_run_gh() { ... }          # GitHub CLI implementation
cancel_run_curl() { ... }        # curl implementation (optional)
wait_for_cancellation() { ... } # Poll until cancelled (if --wait)
format_output() { ... }          # Format human or JSON output

# Main execution flow
main() {
  parse_arguments "$@"
  run_id=$(resolve_run_id_input)
  status_before=$(get_run_status "$run_id")
  cancel_run_gh "$run_id" "$FORCE"
  
  if [[ "$WAIT" == "true" ]]; then
    wait_for_cancellation "$run_id"
  fi
  
  format_output
}

main "$@"
```

**Key Functions**:

**1. `cancel_run_gh(run_id, force)`**:
```bash
cancel_run_gh() {
  local run_id="$1"
  local force="${2:-false}"
  local http_code
  
  if [[ "$force" == "true" ]]; then
    # Use force-cancel endpoint via gh api
    http_code=$(gh api -X POST \
      "/repos/{owner}/{repo}/actions/runs/$run_id/force-cancel" \
      -w "%{http_code}" 2>/dev/null || echo "000")
  else
    # Use standard gh run cancel
    if gh run cancel "$run_id" 2>/dev/null; then
      return 0
    else
      return 1
    fi
  fi
  
  # Check HTTP response
  if [[ "$http_code" == "202" ]] || [[ $? -eq 0 ]]; then
    return 0
  else
    printf 'Error: Failed to cancel run %s (HTTP %s)\n' "$run_id" "$http_code" >&2
    return 1
  fi
}
```

**2. `wait_for_cancellation(run_id)`**:
```bash
wait_for_cancellation() {
  local run_id="$1"
  local max_wait=60  # 60 seconds max
  local interval=2   # Check every 2 seconds
  local elapsed=0
  local start_time
  start_time=$(date +%s)
  
  printf 'Waiting for cancellation to complete...\n' >&2
  
  while [[ $elapsed -lt $max_wait ]]; do
    local status conclusion
    
    # Query run status
    read -r status conclusion < <(gh run view "$run_id" --json status,conclusion \
      --jq '[.status, .conclusion // "null"] | join(" ")')
    
    if [[ "$status" == "completed" ]] && [[ "$conclusion" == "cancelled" ]]; then
      local end_time
      end_time=$(date +%s)
      local duration=$((end_time - start_time))
      printf 'Cancellation completed in %d seconds\n' "$duration" >&2
      return 0
    fi
    
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  
  printf 'Warning: Cancellation did not complete within %d seconds\n' "$max_wait" >&2
  return 1
}
```

**3. `get_run_status(run_id)`**:
```bash
get_run_status() {
  local run_id="$1"
  local status conclusion
  
  # Query current status before cancellation
  read -r status conclusion < <(gh run view "$run_id" --json status,conclusion \
    --jq '[.status, .conclusion // "null"] | join(" ")')
  
  printf '%s\n' "$status"
}
```

### Alternative Implementation: curl variant

**Script**: `scripts/cancel-run-curl.sh`

Following Sprint 9 pattern, provide curl-based alternative for environments without gh CLI:

```bash
cancel_run_curl() {
  local run_id="$1"
  local force="${2:-false}"
  local token="$3"
  local owner repo
  
  # Resolve repository (auto-detect from git or use flag)
  read -r owner repo < <(resolve_repository)
  
  local endpoint
  if [[ "$force" == "true" ]]; then
    endpoint="https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/force-cancel"
  else
    endpoint="https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/cancel"
  fi
  
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$endpoint")
  
  http_code=$(echo "$response" | tail -n1)
  
  if [[ "$http_code" == "202" ]]; then
    return 0
  elif [[ "$http_code" == "409" ]]; then
    printf 'Error: Cannot cancel run %s - workflow not cancellable\n' "$run_id" >&2
    return 1
  else
    printf 'Error: Failed to cancel run %s (HTTP %s)\n' "$run_id" "$http_code" >&2
    return 1
  fi
}
```

### Error Handling

**HTTP Status Codes** (from GitHub API documentation):

- **202 (Accepted)**: Cancellation request accepted, processing asynchronously
- **409 (Conflict)**: Run cannot be cancelled (already completed or cancelled)
- **404 (Not Found)**: Run ID does not exist
- **403 (Forbidden)**: Insufficient permissions to cancel run
- **401 (Unauthorized)**: Authentication failed

**Error Messages**:

```bash
# Run not found
Error: Run ID 1234567890 not found

# Already completed
Error: Cannot cancel run 1234567890 - workflow already completed

# Permission denied
Error: Insufficient permissions to cancel run 1234567890

# Correlation ID not found
Error: No metadata found for correlation ID <uuid> in runs/

# Generic failure
Error: Failed to cancel run 1234567890 (HTTP 500)
```

**Exit Codes**:
- `0`: Cancellation successful
- `1`: Cancellation failed (API error, run not found, already completed)
- `2`: Invalid arguments or missing input

### Integration Patterns

**Pattern 1: Cancel immediately after dispatch (GH-6)**

```bash
# Trigger workflow
result=$(scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --json-only)
run_id=$(echo "$result" | jq -r '.run_id')

# Cancel immediately
scripts/cancel-run.sh --run-id "$run_id" --json

# Expected: Workflow cancelled before execution starts
```

**Pattern 2: Cancel after correlation (GH-7, early timing)**

```bash
# Trigger and correlate
result=$(scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only)
correlation_id=$(echo "$result" | jq -r '.correlation_id')

# Cancel using correlation ID
scripts/cancel-run.sh --correlation-id "$correlation_id" --runs-dir runs --wait

# Expected: Workflow in queued or early in_progress state
```

**Pattern 3: Cancel during execution (GH-7, running state)**

```bash
# Trigger long-running workflow
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=20 --input sleep_seconds=5 \
  --store-dir runs --json-only)

correlation_id=$(echo "$result" | jq -r '.correlation_id')

# Wait for workflow to enter running state
sleep 15

# Verify it's running
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --runs-dir runs

# Cancel during execution
scripts/cancel-run.sh --correlation-id "$correlation_id" --runs-dir runs --wait --json

# Expected: Some jobs completed, others cancelled
```

**Pattern 4: Pipeline integration with stdin**

```bash
# Pipeline: trigger → cancel
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --json-only \
  | scripts/cancel-run.sh --json

# Seamless composition via JSON stdin/stdout
```

**Pattern 5: Force cancel stuck workflow**

```bash
# Cancel workflow that ignores standard cancellation
scripts/cancel-run.sh --run-id 1234567890 --force --wait

# Uses force-cancel endpoint, bypasses always() conditions
```

### Testing Strategy

**Test Matrix**:

| Test ID | Scenario | Workflow State | Cancel Method | Expected Outcome |
|---------|----------|----------------|---------------|------------------|
| GH-6-1 | Cancel immediately | Not started | --run-id | Never executes, conclusion: cancelled |
| GH-7-1 | Cancel after correlation | Queued | --correlation-id | Never executes or partially executes |
| GH-7-2 | Cancel during execution | In progress | --run-id | Partial execution, conclusion: cancelled |
| GH-7-3 | Cancel near completion | In progress (late) | --run-id | Most jobs complete, conclusion: cancelled |
| GH-6-2 | Force cancel | Any | --force | Bypasses always(), conclusion: cancelled |
| ERR-1 | Cancel completed run | Completed | --run-id | HTTP 409, error message |
| ERR-2 | Cancel invalid run ID | N/A | --run-id | HTTP 404, error message |
| INT-1 | Pipeline integration | Any | stdin JSON | Seamless composition |
| INT-2 | With --wait flag | Any | --wait | Polls until cancelled |

**Test Execution Plan**:

**Static Validation**:
```bash
shellcheck scripts/cancel-run.sh
actionlint  # Verify no workflow changes
```

**Test 1: GH-6 - Cancel immediately after dispatch**:
```bash
# Trigger
result=$(scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --json-only)
run_id=$(echo "$result" | jq -r '.run_id')

# Cancel immediately (before correlation completes)
scripts/cancel-run.sh --run-id "$run_id" --wait --json > cancel-result.json

# Verify
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '{status, conclusion}'
# Expected: {"status": "completed", "conclusion": "cancelled"}

# Verify no jobs executed
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '.jobs | length'
# Expected: 0 or jobs with status "queued" only
```

**Test 2: GH-7 - Cancel after correlation (queued/early)**:
```bash
# Trigger and correlate
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/dispatch-webhook.yml \
  --store-dir runs --json-only)

correlation_id=$(echo "$result" | jq -r '.correlation_id')

# Cancel using correlation
scripts/cancel-run.sh \
  --correlation-id "$correlation_id" \
  --runs-dir runs \
  --wait --json > cancel-result.json

# Verify status
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --runs-dir runs --json \
  | jq '{status, conclusion, jobs: [.jobs[] | {name, status, conclusion}]}'

# Document which state workflow was in at cancellation time
jq '.status_before' cancel-result.json
```

**Test 3: GH-7 - Cancel during execution**:
```bash
# Trigger long-running workflow
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=20 --input sleep_seconds=5 \
  --store-dir runs --json-only)

run_id=$(echo "$result" | jq -r '.run_id')
correlation_id=$(echo "$result" | jq -r '.correlation_id')

# Wait for workflow to start running
echo "Waiting for workflow to start..."
sleep 15

# Verify it's running
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '.status'
# Expected: "in_progress"

# Cancel during execution
start_time=$(date +%s)
scripts/cancel-run.sh --run-id "$run_id" --wait --json > cancel-result.json
end_time=$(date +%s)

echo "Cancellation took $((end_time - start_time)) seconds"

# Verify final state
scripts/view-run-jobs.sh --run-id "$run_id" --json \
  | jq '{status, conclusion, jobs: [.jobs[] | {name, status, conclusion}]}'

# Expected: status "completed", conclusion "cancelled"
# Some jobs may be "completed" (ran before cancellation)
# Some jobs may be "cancelled" (didn't complete)
```

**Test 4: Error handling - already completed**:
```bash
# Use run ID from completed workflow
scripts/cancel-run.sh --run-id <completed_run_id>

# Expected: Error message, exit code 1
# Error: Cannot cancel run <id> - workflow already completed
```

**Test 5: Force cancel**:
```bash
# Trigger workflow with always() conditions
# (would need test workflow with always() steps)
result=$(scripts/trigger-and-track.sh ...)
run_id=$(echo "$result" | jq -r '.run_id')

# Standard cancel
scripts/cancel-run.sh --run-id "$run_id"

# Force cancel (bypasses always())
scripts/cancel-run.sh --run-id "$run_id" --force --wait
```

**Test 6: Pipeline integration**:
```bash
# Test stdin JSON input
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --json-only \
  | scripts/cancel-run.sh --json \
  | jq .

# Expected: Seamless composition, JSON output
```

### Timing Observations

**Measurements to Document**:

1. **Cancellation request latency**: Time from `cancel-run.sh` invocation to HTTP 202 response
   - Expected: <1 second (API call overhead only)

2. **Cancellation completion time**: Time from HTTP 202 to final status "completed/cancelled"
   - Varies by workflow state:
     - Queued: <5 seconds (never started)
     - In progress (early): 5-15 seconds (signal propagation + cleanup)
     - In progress (late): 10-30 seconds (running jobs complete or timeout)

3. **Status at cancellation time**:
   - GH-6: Typically "queued" (never started)
   - GH-7 (early): "queued" or "in_progress"
   - GH-7 (late): "in_progress"

4. **Job completion before cancellation**:
   - Early cancel: 0 jobs completed
   - Late cancel: 1-N jobs completed, remaining cancelled

**Create timing report**:
```json
{
  "test": "GH-7-cancel-during-execution",
  "run_id": 1234567890,
  "dispatch_time": "2025-01-15T10:30:00Z",
  "cancel_time": "2025-01-15T10:30:15Z",
  "completion_time": "2025-01-15T10:30:23Z",
  "status_at_cancel": "in_progress",
  "cancellation_duration_seconds": 8,
  "jobs_completed_before_cancel": 1,
  "jobs_cancelled": 2
}
```

### Compatibility with Previous Sprints

**Sprint 1 (trigger-and-track.sh)**:
- ✅ Reuse UUID correlation mechanism
- ✅ Read from `runs/<correlation_id>/metadata.json`
- ✅ Accept JSON output via stdin
- ✅ No modifications to Sprint 1 scripts required

**Sprint 3 (fetch-run-logs.sh)**:
- ✅ Use same `lib/run-utils.sh` functions
- ✅ Follow same metadata loading patterns
- ✅ Cancelled runs still have logs available (for partial execution)

**Sprint 8/9 (view-run-jobs.sh)**:
- ✅ Use job viewer to verify cancellation
- ✅ Monitor status transitions
- ✅ No modifications to Sprint 8/9 scripts required

**Sprint 5 (research)**:
- ✅ Implements recommendations from Sprint 5 (use `gh run cancel`)
- ✅ Validates API capabilities documented in Sprint 5

### Use Cases

**Use Case 1: Cancel accidental dispatch**
```bash
# Operator realizes wrong workflow triggered
result=$(scripts/trigger-and-track.sh --workflow .github/workflows/deploy-prod.yml --json-only)
# Oops, meant to trigger staging!

# Quick cancel
echo "$result" | scripts/cancel-run.sh --json
```

**Use Case 2: Cancel long-running test**
```bash
# Test running longer than expected
correlation_id="<uuid-from-earlier>"
scripts/cancel-run.sh --correlation-id "$correlation_id" --runs-dir runs --wait
```

**Use Case 3: Emergency stop in CI/CD**
```bash
#!/bin/bash
# Emergency stop script in CI/CD pipeline
if [[ -f critical-error.txt ]]; then
  echo "Critical error detected, cancelling workflow"
  scripts/cancel-run.sh --run-id "$GITHUB_RUN_ID" --force
  exit 1
fi
```

**Use Case 4: Automated cancellation logic**
```bash
# Cancel if another run starts
old_run_id="$1"
new_run_id="$2"

echo "New run $new_run_id started, cancelling old run $old_run_id"
scripts/cancel-run.sh --run-id "$old_run_id" --json
```

### Risks and Mitigations

**Risk 1: Cancellation timing race condition**
- **Risk**: Workflow completes before cancellation request processed
- **Impact**: HTTP 409 error (already completed)
- **Mitigation**: Detect 409 response, report as informational not error
- **Mitigation**: Document expected behavior in error messages

**Risk 2: Cancellation doesn't complete**
- **Risk**: Workflow stuck in "completing" state indefinitely
- **Impact**: `--wait` flag times out
- **Mitigation**: Configurable timeout (default 60s)
- **Mitigation**: Warning message if timeout reached
- **Mitigation**: Document force-cancel option for stuck workflows

**Risk 3: Partial execution confusion**
- **Risk**: Operators unsure what executed before cancellation
- **Impact**: Difficult to determine system state
- **Mitigation**: Use `view-run-jobs.sh` to show which jobs completed
- **Mitigation**: Document that logs available for partial execution
- **Mitigation**: JSON output includes timing information

**Risk 4: Permission issues**
- **Risk**: Token/auth lacks cancel permissions
- **Impact**: HTTP 403 error
- **Mitigation**: Clear error message explaining permission requirement
- **Mitigation**: Document required scopes in Sprint 0 prerequisites update

**Risk 5: Force-cancel misuse**
- **Risk**: Force-cancel used unnecessarily, skipping cleanup
- **Impact**: Resources not properly cleaned up
- **Mitigation**: Default to standard cancel
- **Mitigation**: Document force-cancel use cases clearly
- **Mitigation**: Require explicit `--force` flag

### Success Criteria

Sprint 11 design is successful when:

1. ✅ Feasibility analysis confirms GitHub API supports cancellation
2. ✅ Script design covers both gh CLI and curl implementations
3. ✅ Input resolution follows established Sprint 8 patterns
4. ✅ Integration points with Sprints 1, 3, 8/9 clearly documented
5. ✅ Test strategy covers GH-6 (immediate cancel) and GH-7 (different timings)
6. ✅ Error handling addresses all HTTP status codes
7. ✅ Output formats (human, JSON) specified
8. ✅ Timing observations documented for measurement
9. ✅ Use cases demonstrate practical applications
10. ✅ Risks identified with mitigation strategies

## Documentation

**Implementation Notes** (to be created in construction phase):
- `progress/sprint_11_implementation.md`
- Usage examples for each cancellation scenario
- Test execution results with timing data
- Troubleshooting guide

**Script Help** (inline in script):
```bash
scripts/cancel-run.sh --help
```
Output:
```
Usage: scripts/cancel-run.sh [OPTIONS]

Cancel GitHub Actions workflow run.

INPUT (first match wins):
  --run-id <id>           Workflow run ID (numeric)
  --correlation-id <uuid> Load run_id from stored metadata
  stdin                   JSON from trigger-and-track.sh

OPTIONS:
  --runs-dir <dir>        Base directory for metadata (default: runs)
  --force                 Use force-cancel (bypasses always() conditions)
  --wait                  Poll until cancellation completes
  --json                  Output JSON format
  --help                  Show this help message

EXAMPLES:
  # Cancel by run ID
  scripts/cancel-run.sh --run-id 1234567890

  # Cancel using correlation ID
  scripts/cancel-run.sh --correlation-id <uuid> --runs-dir runs

  # Cancel and wait for completion
  scripts/cancel-run.sh --run-id 1234567890 --wait

  # Force cancel stuck workflow
  scripts/cancel-run.sh --run-id 1234567890 --force

  # Pipeline integration
  scripts/trigger-and-track.sh --webhook-url "$URL" --json-only \\
    | scripts/cancel-run.sh --json
```

## Design Approval

**Status**: Awaiting Product Owner review

This design document is ready for Product Owner review. Implementation will proceed after approval (status change to "Accepted").

**Design addresses**:
- ✅ GH-6: Cancel requested workflow (immediately after dispatch)
- ✅ GH-7: Cancel running workflow (at different execution stages)
- ✅ Integration with existing Sprint 1, 3, 8, 9 tooling
- ✅ Comprehensive test strategy with timing observations
- ✅ Error handling and risk mitigation

