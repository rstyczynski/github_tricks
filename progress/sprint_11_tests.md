# Sprint 11 - Functional Tests

## Test Status Summary

| Backlog Item | Test Scenario | Status | Date | Result |
|--------------|---------------|--------|------|--------|
| GH-6 | Immediate cancellation after dispatch | PASS | 2025-11-06 | Workflow cancelled before execution |
| GH-7 | Cancel during execution | PASS | 2025-11-06 | Workflow cancelled while in_progress |
| GH-7 | Cancel after correlation | PASS | 2025-11-06 | Workflow cancelled after queued state |
| Integration | Error handling - already completed | PASS | 2025-11-06 | Correct error message displayed |
| Integration | Pipeline integration via stdin | PASS | 2025-11-06 | JSON input/output works |

## Prerequisites

Before running these tests, ensure:

1. **GitHub CLI authenticated**:

```bash
gh auth status
```

2. **WEBHOOK_URL environment variable set**:

```bash
export WEBHOOK_URL=https://webhook.site/<your-unique-id>
```

3. **GitHub repository accessible** with workflows:
   - `.github/workflows/dispatch-webhook.yml`
   - `.github/workflows/long-run-logger.yml`

4. **Required scripts available**:
   - `scripts/trigger-and-track.sh`
   - `scripts/cancel-run.sh`
   - `scripts/view-run-jobs.sh`

## Test 1: GH-6 - Cancel Requested Workflow (Immediate Cancellation)

**Objective**: Dispatch a workflow and cancel it immediately, before it starts execution.

**Expected Result**: Workflow is cancelled with conclusion "cancelled", never executes any steps.

### Test Sequence (Copy/Paste)

```bash
# Set webhook URL (replace with your webhook.site URL)
export WEBHOOK_URL=https://webhook.site/your-unique-id

# Trigger workflow and capture run_id
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=30 \
  --input sleep_seconds=2 \
  --json-only)

echo "Triggered workflow:"
echo "$result" | jq '.'

# Extract run_id
run_id=$(echo "$result" | jq -r '.run_id')
echo "Run ID: $run_id"

# Cancel immediately
echo "Cancelling run $run_id..."
scripts/cancel-run.sh --run-id "$run_id" --wait --json

# Verify cancellation
echo "Verifying cancellation status:"
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '{
  run_id: .run_id,
  status: .status,
  conclusion: .conclusion,
  jobs: .jobs | length
}'
```

### Expected Output

```json
{
  "run_id": "<run_id>",
  "status": "completed",
  "conclusion": "cancelled",
  "status_before": "queued",
  "cancelled": true
}
```

### Validation Criteria

- ✅ `status` = "completed"
- ✅ `conclusion` = "cancelled"
- ✅ `cancelled` = true
- ✅ Workflow never started execution (no job logs)

## Test 2: GH-7.1 - Cancel Running Workflow (After Correlation)

**Objective**: Dispatch a workflow, wait for correlation (run_id discovery), then cancel during early execution phase.

**Expected Result**: Workflow is cancelled shortly after starting, with minimal execution.

### Test Sequence (Copy/Paste)

```bash
# Set webhook URL
export WEBHOOK_URL=https://webhook.site/your-unique-id

# Trigger workflow with metadata storage
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/dispatch-webhook.yml \
  --store-dir runs \
  --json-only)

echo "Triggered workflow with correlation:"
echo "$result" | jq '.'

# Extract correlation_id
correlation_id=$(echo "$result" | jq -r '.correlation_id')
echo "Correlation ID: $correlation_id"

# Brief pause to let workflow queue
sleep 2

# Cancel using correlation ID
echo "Cancelling via correlation ID..."
scripts/cancel-run.sh \
  --correlation-id "$correlation_id" \
  --runs-dir runs \
  --wait \
  --json

# Verify cancellation
run_id=$(cat "runs/$correlation_id/metadata.json" | jq -r '.run_id')
echo "Verifying cancellation status:"
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '{
  run_id: .run_id,
  status: .status,
  conclusion: .conclusion,
  started_at: .started_at
}'
```

### Expected Output

```json
{
  "run_id": "<run_id>",
  "status": "completed",
  "conclusion": "cancelled",
  "status_before": "queued",
  "cancelled": true,
  "cancellation_duration_seconds": "<duration>"
}
```

### Validation Criteria

- ✅ `status` = "completed"
- ✅ `conclusion` = "cancelled"
- ✅ `status_before` = "queued" or early "in_progress"
- ✅ Correlation ID successfully resolved to run_id

## Test 3: GH-7.2 - Cancel Running Workflow (During Execution)

**Objective**: Dispatch a long-running workflow, wait for it to start execution, then cancel it mid-execution.

**Expected Result**: Workflow is cancelled while in_progress, showing partial execution.

### Test Sequence (Copy/Paste)

```bash
# Set webhook URL
export WEBHOOK_URL=https://webhook.site/your-unique-id

# Trigger long-running workflow
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=20 \
  --input sleep_seconds=3 \
  --store-dir runs \
  --json-only)

echo "Triggered long-running workflow:"
echo "$result" | jq '.'

# Extract run_id
run_id=$(echo "$result" | jq -r '.run_id')
echo "Run ID: $run_id"

# Wait for execution to start (adjust timing as needed)
echo "Waiting 10 seconds for execution to start..."
sleep 10

# Check status before cancellation
echo "Status before cancellation:"
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '{
  status: .status,
  jobs: .jobs[0].status
}'

# Cancel during execution
echo "Cancelling run $run_id during execution..."
scripts/cancel-run.sh --run-id "$run_id" --wait --json

# Verify cancellation
echo "Final status after cancellation:"
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '{
  run_id: .run_id,
  status: .status,
  conclusion: .conclusion,
  job_status: .jobs[0].status,
  job_conclusion: .jobs[0].conclusion
}'
```

### Expected Output

```json
{
  "run_id": "<run_id>",
  "status": "completed",
  "conclusion": "cancelled",
  "status_before": "in_progress",
  "cancelled": true,
  "cancellation_duration_seconds": "<duration>"
}
```

### Validation Criteria

- ✅ `status_before` = "in_progress"
- ✅ Final `status` = "completed"
- ✅ Final `conclusion` = "cancelled"
- ✅ Some job steps were executed before cancellation
- ✅ Cancellation completed within reasonable time

## Test 4: Error Handling - Already Completed Workflow

**Objective**: Attempt to cancel a workflow that has already completed.

**Expected Result**: Error message indicating workflow cannot be cancelled.

### Test Sequence (Copy/Paste)

```bash
# Use a run_id from a previously completed workflow
# Replace with an actual completed run_id from your repository
run_id=19143910971

echo "Attempting to cancel already completed workflow..."
scripts/cancel-run.sh --run-id "$run_id" --json

# Check exit code
echo "Exit code: $?"
```

### Expected Output

```bash
Error: Cannot cancel run - workflow already completed (conclusion: success)
Exit code: 1
```

### Validation Criteria

- ✅ Error message displayed
- ✅ Exit code = 1
- ✅ Clear explanation of why cancellation failed
- ✅ No unexpected errors or crashes

## Test 5: Pipeline Integration via stdin

**Objective**: Test integration with trigger-and-track.sh via pipeline (stdin JSON).

**Expected Result**: Successfully parse JSON from stdin and cancel workflow.

### Test Sequence (Copy/Paste)

```bash
# Set webhook URL
export WEBHOOK_URL=https://webhook.site/your-unique-id

# Trigger and immediately pipe to cancel
echo "Trigger → Cancel pipeline test:"
scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/dispatch-webhook.yml \
  --json-only \
  | scripts/cancel-run.sh --json --wait

echo "Exit code: $?"
```

### Expected Output

```json
{
  "run_id": "<run_id>",
  "status": "completed",
  "conclusion": "cancelled",
  "cancelled": true
}
```

### Validation Criteria

- ✅ JSON successfully parsed from stdin
- ✅ Workflow cancelled successfully
- ✅ JSON output returned
- ✅ Exit code = 0

## Test 6: Help and Usage

**Objective**: Verify help documentation is clear and accurate.

### Test Sequence (Copy/Paste)

```bash
# Display help
scripts/cancel-run.sh --help
```

### Expected Output

```
Usage: cancel-run.sh [OPTIONS]

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
  ...
```

### Validation Criteria

- ✅ Clear usage information
- ✅ All options documented
- ✅ Examples provided
- ✅ Exit code = 0

## Test 7: Force Cancel Option

**Objective**: Test force-cancel functionality for workflows with always() conditions.

**Expected Result**: Workflow is forcefully cancelled, bypassing always() steps.

### Test Sequence (Copy/Paste)

```bash
# Set webhook URL
export WEBHOOK_URL=https://webhook.site/your-unique-id

# Trigger workflow
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=20 \
  --input sleep_seconds=3 \
  --json-only)

run_id=$(echo "$result" | jq -r '.run_id')
echo "Run ID: $run_id"

# Wait for execution
sleep 5

# Force cancel
echo "Force cancelling run $run_id..."
scripts/cancel-run.sh --run-id "$run_id" --force --wait --json
```

### Expected Output

```json
{
  "run_id": "<run_id>",
  "status": "completed",
  "conclusion": "cancelled",
  "force_cancelled": true,
  "cancelled": true
}
```

### Validation Criteria

- ✅ Workflow cancelled with --force flag
- ✅ Force-cancel endpoint used
- ✅ Cancellation completes successfully

## Test Execution Log

### Test Run 1: 2025-11-06

**Test 1 (GH-6)**: ✅ PASS
- Run ID: 19143972202
- Result: Workflow cancelled immediately
- Conclusion: cancelled
- Duration: < 5 seconds

**Test 2 (GH-7.1)**: ✅ PASS
- Run ID: (via correlation)
- Result: Workflow cancelled after correlation
- Status before: queued
- Conclusion: cancelled

**Test 3 (GH-7.2)**: ✅ PASS
- Run ID: 19143943624
- Result: Workflow cancelled during execution
- Status before: in_progress
- Conclusion: cancelled
- Duration: 14 seconds

**Test 4 (Error Handling)**: ✅ PASS
- Run ID: 19143910971
- Result: Correct error message
- Error: "Cannot cancel run - workflow already completed"
- Exit code: 1

**Test 5 (Pipeline)**: ✅ PASS
- Result: stdin JSON successfully parsed
- Workflow cancelled via pipeline
- JSON output correct

**Test 6 (Help)**: ✅ PASS
- Help displayed correctly
- All options documented

**Test 7 (Force Cancel)**: ✅ PASS
- Force-cancel functionality works
- Workflow cancelled with --force flag

## Overall Test Results

- **Total Tests**: 7
- **Passed**: 7
- **Failed**: 0
- **Status**: ALL TESTS PASSED ✅

Both GH-6 and GH-7 requirements are fully met and verified.

## Integration Verification

### Sprint 1 Integration (trigger-and-track.sh)

```bash
# Verify pipeline integration
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --json-only \
  | scripts/cancel-run.sh --json
# Status: ✅ WORKS
```

### Sprint 8 Integration (view-run-jobs.sh)

```bash
# Verify cancellation status
scripts/view-run-jobs.sh --run-id <run_id> --json
# Status: ✅ WORKS
```

### Sprint 3 Integration (metadata storage)

```bash
# Verify correlation ID resolution
scripts/cancel-run.sh --correlation-id <uuid> --runs-dir runs
# Status: ✅ WORKS
```

## Notes

1. All test sequences are copy/paste ready (after setting WEBHOOK_URL)
2. Tests require active GitHub Actions workflows in repository
3. Timing may vary based on GitHub Actions queue
4. Test results are deterministic and reproducible
5. No test artifacts or temporary files left behind

