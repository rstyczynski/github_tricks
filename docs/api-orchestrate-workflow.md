# End-to-End Workflow Orchestration

Complete guide for orchestrating GitHub workflow execution from trigger to artifact retrieval using REST API.

**Sprint**: 20  
**Backlog Item**: GH-27  
**Status**: Implemented

## Overview

The workflow orchestration system provides end-to-end automation for:
1. Triggering GitHub workflows with custom parameters
2. Correlating workflows to obtain run IDs
3. Monitoring workflow execution to completion
4. Retrieving workflow logs
5. Downloading and extracting workflow artifacts
6. Validating and displaying results

This orchestration integrates all workflow management capabilities developed in Sprints 15-18 into a single, cohesive automation script.

## Quick Start

```bash
# Basic orchestration
./scripts/orchestrate-workflow.sh \
  --string "test" \
  --length 10

# With custom timeout
./scripts/orchestrate-workflow.sh \
  --string "data" \
  --length 50 \
  --max-wait 1200

# Preserve state for debugging
./scripts/orchestrate-workflow.sh \
  --string "debug" \
  --length 5 \
  --keep-state
```

## Prerequisites

### Required Tools

- **bash** (≥4.0) - Shell interpreter
- **curl** - HTTP client for API calls
- **jq** - JSON processing
- **uuidgen** - UUID generation for correlation

### Required Files

- **Token**: `./secrets/token` - GitHub authentication token with workflow permissions
- **Workflow**: `.github/workflows/process-and-return.yml` - Processing workflow definition

### Required Scripts (from previous Sprints)

All scripts must be executable and in the `scripts/` directory:

- `trigger-workflow-curl.sh` (Sprint 15)
- `correlate-workflow-curl.sh` (Sprint 15)
- `wait-workflow-completion-curl.sh` (Sprint 17)
- `fetch-logs-curl.sh` (Sprint 15)
- `list-artifacts-curl.sh` (Sprint 16)
- `download-artifact-curl.sh` (Sprint 17)

### Verification

```bash
# Verify prerequisites
./scripts/orchestrate-workflow.sh --help
```

If prerequisites are missing, the script will report specific errors.

## Usage

### Command Syntax

```bash
./scripts/orchestrate-workflow.sh --string <value> --length <num> [options]
```

### Required Parameters

#### `--string <value>`

String to include in generated array elements.

**Example**: `--string "test"` generates array: `["test_0", "test_1", "test_2", ...]`

#### `--length <number>`

Number of array elements to generate.

**Constraints**:
- Must be a positive integer
- Minimum: 1
- Maximum: 1000

**Example**: `--length 10` generates 10 array elements

### Optional Parameters

#### `--workflow <file>`

Path to workflow file relative to project root.

**Default**: `.github/workflows/process-and-return.yml`

**Example**: `--workflow .github/workflows/custom.yml`

#### `--max-wait <seconds>`

Maximum time to wait for workflow completion.

**Default**: 600 (10 minutes)

**Example**: `--max-wait 1200` (20 minutes)

#### `--interval <seconds>`

Polling interval for workflow status checks.

**Default**: 5

**Example**: `--interval 10` (check every 10 seconds)

#### `--keep-state`

Preserve state file after completion for debugging.

**Default**: State file is automatically deleted

**State File Location**: `/tmp/orchestrate_<timestamp>.state`

#### `--help`

Display usage information and exit.

## Usage Examples

### Example 1: Basic Orchestration

```bash
./scripts/orchestrate-workflow.sh \
  --string "example" \
  --length 5
```

**Expected Output**:
```
==========================================
  WORKFLOW ORCHESTRATION STARTING
==========================================
Input String: example
Array Length: 5
Workflow: .github/workflows/process-and-return.yml
Max Wait: 600s
Polling Interval: 5s

[INFO] Step 1: Triggering workflow...
[INFO] Correlation ID: abc-123-def-456
[INFO] Workflow triggered successfully

[INFO] Step 2: Correlating workflow to get run_id...
[INFO] Correlation attempt 1/5 (waiting 2s)...
[INFO] Run ID obtained: 1234567890

[INFO] Step 3: Waiting for workflow completion...
[INFO] Workflow completed successfully

[INFO] Step 4: Fetching workflow logs...
[INFO] Logs fetched successfully to runs/1234567890/logs

[INFO] Step 5: Listing artifacts...
[INFO] Found artifact: processing-result (ID: 98765)

[INFO] Step 6: Downloading artifact...
[INFO] Artifact downloaded and extracted successfully

[INFO] Step 7: Extracting and validating results...
[INFO] Results extracted and validated successfully

==========================================
           WORKFLOW RESULTS
==========================================

Correlation ID: abc-123-def-456
Input String:   example
Array Length:   5

Generated Array:
example_0
example_1
example_2
example_3
example_4

==========================================

[INFO] ✓ Array length validation: PASS (5 == 5)
[INFO] ✓ Correlation ID validation: PASS

==========================================
  ORCHESTRATION COMPLETED SUCCESSFULLY
==========================================

Summary:
  Correlation ID:  abc-123-def-456
  Run ID:          1234567890
  Workflow Status: completed
  Logs Directory:  runs/1234567890/logs
  Result File:     artifacts/processing-result/result.json
  Artifact Name:   processing-result
```

**Exit Code**: 0 (success)

### Example 2: Large Array with Custom Timeout

```bash
./scripts/orchestrate-workflow.sh \
  --string "dataset" \
  --length 100 \
  --max-wait 1800 \
  --interval 10
```

**Purpose**: Generate larger dataset with extended timeout  
**Runtime**: ~90-120 seconds  
**Exit Code**: 0 (success)

### Example 3: Debug Mode with State Preservation

```bash
./scripts/orchestrate-workflow.sh \
  --string "debug" \
  --length 3 \
  --keep-state
```

**Purpose**: Preserve state file for debugging  
**State File**: `/tmp/orchestrate_<timestamp>.state`

**State File Contents**:
```bash
CORRELATION_ID=abc-123-def-456
RUN_ID=1234567890
WORKFLOW_STATUS=completed
LOGS_DIR=runs/1234567890/logs
ARTIFACT_ID=98765
ARTIFACT_NAME=processing-result
RESULT_FILE=artifacts/processing-result/result.json
```

### Example 4: Custom Workflow

```bash
./scripts/orchestrate-workflow.sh \
  --string "custom" \
  --length 10 \
  --workflow .github/workflows/my-workflow.yml
```

**Purpose**: Use custom workflow definition  
**Requirement**: Workflow must accept same inputs (input_string, array_length, correlation_id)

## Exit Codes

The orchestration script uses specific exit codes to indicate different failure modes:

| Exit Code | Meaning | Troubleshooting |
|-----------|---------|-----------------|
| 0 | Success | Orchestration completed successfully |
| 1 | Invalid arguments or missing prerequisites | Check parameters and verify all required scripts/tools are installed |
| 2 | Workflow trigger failed | Verify token permissions, workflow file exists, and GitHub API is accessible |
| 3 | Correlation failed | Workflow may not have started, correlation_id may be incorrect, or GitHub API delay |
| 4 | Workflow execution failed | Check workflow logs for errors, verify workflow syntax |
| 5 | Log retrieval failed | Logs may not be available yet, or insufficient permissions |
| 6 | Artifact retrieval failed | Workflow may not have produced artifacts, or artifacts expired |
| 7 | Result extraction/validation failed | Artifact format incorrect, missing required fields, or validation mismatch |

## Orchestration Pipeline

The orchestration executes 7 sequential steps:

### Step 1: Trigger Workflow

**Action**: Dispatch workflow with input parameters  
**Script**: `trigger-workflow-curl.sh`  
**Inputs**:
- `input_string`: User-provided string
- `array_length`: User-provided number
- `correlation_id`: Auto-generated UUID

**Output**: Workflow triggered, correlation ID saved

### Step 2: Correlate Workflow

**Action**: Obtain run_id using correlation_id  
**Script**: `correlate-workflow-curl.sh`  
**Strategy**: Exponential backoff (5 attempts: 2s, 4s, 8s, 16s, 16s)  
**Output**: run_id obtained and saved

**Note**: Correlation typically takes 2-5 seconds, up to 10 seconds in worst case

### Step 3: Wait for Completion

**Action**: Poll workflow status until completion  
**Script**: `wait-workflow-completion-curl.sh`  
**Polling**: Fixed interval (default 5s), configurable max wait  
**Output**: Workflow completion confirmed

### Step 4: Fetch Logs

**Action**: Retrieve workflow execution logs  
**Script**: `fetch-logs-curl.sh`  
**Output**: Logs saved to `runs/<run_id>/logs/`

**Note**: Logs typically available 5-15 seconds after completion

### Step 5: List Artifacts

**Action**: Discover artifacts produced by workflow  
**Script**: `list-artifacts-curl.sh`  
**Output**: Artifact ID and name obtained

### Step 6: Download Artifact

**Action**: Download and extract artifact  
**Script**: `download-artifact-curl.sh`  
**Output**: Artifact extracted to `artifacts/` directory

### Step 7: Extract Results

**Action**: Parse and validate result JSON  
**Processing**: Custom logic with jq  
**Validation**:
- JSON syntax validation
- Required field presence checks
- Array length verification
- Correlation ID verification

**Output**: Results displayed and validated

## Result Format

The workflow produces a JSON result file with the following structure:

```json
{
  "correlation_id": "abc-123-def-456",
  "input_string": "test",
  "requested_length": 10,
  "generated_array": [
    "test_0",
    "test_1",
    "test_2",
    "test_3",
    "test_4",
    "test_5",
    "test_6",
    "test_7",
    "test_8",
    "test_9"
  ],
  "timestamp": "2025-11-07T12:00:00Z",
  "hostname": "runner-hostname",
  "runner": "Linux"
}
```

### Field Descriptions

- **correlation_id**: UUID used for workflow correlation
- **input_string**: Echo of input parameter
- **requested_length**: Number of array elements requested
- **generated_array**: Array of generated strings
- **timestamp**: ISO 8601 timestamp of generation
- **hostname**: GitHub Actions runner hostname
- **runner**: Operating system of runner

## Timing Characteristics

Based on implementation and previous Sprint benchmarks:

### Expected Durations

| Operation | Typical | Worst Case |
|-----------|---------|------------|
| Workflow trigger | 1-2s | 5s |
| Correlation | 2-5s | 10s |
| Workflow execution | 30-60s | 90s |
| Log retrieval | 5-15s | 30s |
| Artifact list | 1-2s | 5s |
| Artifact download | 2-5s | 10s |
| Result extraction | <1s | 2s |

**Total Expected Duration**: 50-95 seconds for typical execution

### Timing Benchmarks

Referenced from previous Sprints:
- **Sprint 3.1**: Correlation timing benchmarks (median ~2-5s)
- **Sprint 5.1**: Log retrieval timing benchmarks (5-15s after completion)

## Error Handling

### Common Errors and Solutions

#### Error: Missing required parameter

```
ERROR: Missing required parameter: --string
```

**Solution**: Provide both --string and --length parameters

```bash
./scripts/orchestrate-workflow.sh --string "value" --length 10
```

#### Error: Array length validation

```
ERROR: Array length must be a positive integer
ERROR: Array length must be at least 1
ERROR: Array length must not exceed 1000
```

**Solution**: Use valid array length (1-1000)

```bash
./scripts/orchestrate-workflow.sh --string "test" --length 50
```

#### Error: Workflow trigger failed

```
ERROR: Failed to trigger workflow
```

**Possible Causes**:
- Invalid or missing token
- Workflow file not found
- GitHub API unavailable
- Insufficient permissions

**Solution**:
1. Verify token exists: `ls -l secrets/token`
2. Verify workflow exists: `ls -l .github/workflows/process-and-return.yml`
3. Test token: `curl -H "Authorization: token $(cat secrets/token)" https://api.github.com/user`
4. Check token permissions (must have workflow scope)

#### Error: Correlation failed

```
ERROR: Failed to correlate workflow after 5 attempts
```

**Possible Causes**:
- Workflow not started yet (GitHub API delay)
- Invalid correlation_id
- GitHub API rate limiting

**Solution**:
1. Wait a few seconds and retry
2. Check GitHub Actions UI to verify workflow was triggered
3. Use --keep-state to inspect correlation_id
4. Check for GitHub API status issues

#### Error: Workflow execution failed

```
ERROR: Workflow did not complete successfully
```

**Possible Causes**:
- Workflow syntax error
- Workflow logic error
- Workflow timeout

**Solution**:
1. Check logs: `cat runs/<run_id>/logs/*.log`
2. Review workflow file for errors
3. Increase timeout: `--max-wait 1200`
4. Check GitHub Actions UI for detailed error

#### Error: Artifact not found

```
ERROR: No artifacts found or failed to list artifacts
```

**Possible Causes**:
- Workflow failed before artifact upload
- Artifact expired (7-day retention)
- Artifact name mismatch

**Solution**:
1. Verify workflow completed successfully
2. Check workflow logs for artifact upload errors
3. Verify artifact retention hasn't expired

## Advanced Usage

### Parallel Orchestration

Execute multiple orchestrations in parallel:

```bash
# Start 3 parallel orchestrations
./scripts/orchestrate-workflow.sh --string "parallel_1" --length 5 &
./scripts/orchestrate-workflow.sh --string "parallel_2" --length 5 &
./scripts/orchestrate-workflow.sh --string "parallel_3" --length 5 &

# Wait for all to complete
wait

echo "All orchestrations complete"
```

**Isolation**: Each orchestration uses unique state file, preventing interference

### Automated Testing

Use exit codes for automated testing:

```bash
#!/bin/bash

if ./scripts/orchestrate-workflow.sh --string "test" --length 5; then
    echo "✓ Test passed"
    exit 0
else
    exit_code=$?
    echo "✗ Test failed with exit code: ${exit_code}"
    exit 1
fi
```

### Integration with CI/CD

```yaml
# GitHub Actions example
- name: Run workflow orchestration
  run: |
    ./scripts/orchestrate-workflow.sh \
      --string "ci-test" \
      --length 10 \
      --max-wait 900
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Custom Result Processing

Extract and process results programmatically:

```bash
# Run orchestration with state preservation
./scripts/orchestrate-workflow.sh \
  --string "data" \
  --length 20 \
  --keep-state

# Extract state file location from output
STATE_FILE="/tmp/orchestrate_*.state"

# Load state and process results
source ${STATE_FILE}
result_json=$(cat "${RESULT_FILE}")

# Extract specific data
array_length=$(echo "${result_json}" | jq '.generated_array | length')
timestamp=$(echo "${result_json}" | jq -r '.timestamp')

echo "Processed ${array_length} items at ${timestamp}"
```

## Workflow Customization

### Creating Custom Workflows

To use a custom workflow with the orchestration system:

**Required Inputs**:
```yaml
on:
  workflow_dispatch:
    inputs:
      input_string:
        description: 'Custom string parameter'
        required: true
        type: string
      array_length:
        description: 'Number of items to process'
        required: true
        type: number
      correlation_id:
        description: 'Correlation ID for tracking'
        required: false
        type: string
```

**Required Artifact**:
- Name: Any valid artifact name
- Contents: Must include `result.json` with structure:
  ```json
  {
    "correlation_id": "${{ inputs.correlation_id }}",
    "input_string": "${{ inputs.input_string }}",
    "requested_length": ${{ inputs.array_length }},
    "generated_array": [...]
  }
  ```

**Example Custom Workflow**:
```bash
./scripts/orchestrate-workflow.sh \
  --string "custom" \
  --length 15 \
  --workflow .github/workflows/my-custom-workflow.yml
```

## Integration Reference

### Integration with Sprint 15 (Trigger, Correlate, Logs)

Orchestration uses these scripts without modification:
- `trigger-workflow-curl.sh` - Workflow dispatch
- `correlate-workflow-curl.sh` - UUID-based correlation
- `fetch-logs-curl.sh` - Log retrieval

### Integration with Sprint 16 (Artifact Listing)

Orchestration uses:
- `list-artifacts-curl.sh` - Artifact discovery with JSON output

### Integration with Sprint 17 (Artifact Download, Wait)

Orchestration uses:
- `download-artifact-curl.sh` - Artifact download with extraction
- `wait-workflow-completion-curl.sh` - Status polling

## Troubleshooting

### Debug Mode

Enable debug mode by preserving state:

```bash
./scripts/orchestrate-workflow.sh \
  --string "debug" \
  --length 5 \
  --keep-state
```

Then inspect state file:

```bash
cat /tmp/orchestrate_*.state
```

### Verbose Logging

All orchestration output includes timestamps and log levels:

```
[2025-11-07 12:00:00] INFO: Step 1: Triggering workflow...
[2025-11-07 12:00:02] INFO: Workflow triggered successfully
[2025-11-07 12:00:02] INFO: Step 2: Correlating workflow to get run_id...
```

### Manual Step Execution

Execute individual steps manually for debugging:

```bash
# Step 1: Trigger
CORRELATION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/process-and-return.yml \
  --correlation-id "${CORRELATION_ID}" \
  --input "input_string=test" \
  --input "array_length=5"

# Step 2: Correlate (wait a few seconds first)
sleep 5
RUN_ID=$(./scripts/correlate-workflow-curl.sh --correlation-id "${CORRELATION_ID}")

# Step 3: Wait
./scripts/wait-workflow-completion-curl.sh --run-id "${RUN_ID}"

# Continue with remaining steps...
```

## Performance Optimization

### Reduce Polling Frequency

For non-urgent workflows, reduce polling frequency to conserve API calls:

```bash
./scripts/orchestrate-workflow.sh \
  --string "batch" \
  --length 100 \
  --interval 30 \
  --max-wait 3600
```

### Parallel Processing

Process multiple datasets in parallel:

```bash
for dataset in data1 data2 data3; do
    ./scripts/orchestrate-workflow.sh \
        --string "${dataset}" \
        --length 50 &
done
wait
```

## Best Practices

1. **Always validate prerequisites** before running in production
2. **Use appropriate timeouts** based on expected workflow duration
3. **Preserve state for debugging** when troubleshooting issues
4. **Monitor API rate limits** when running multiple orchestrations
5. **Clean up old artifacts** to manage storage
6. **Use meaningful string values** for traceability
7. **Log orchestration results** for audit trails

## Related Documentation

- [Trigger Workflows](api-trigger-workflow.md) - Sprint 15 workflow triggering
- [Correlate Runs](api-correlate-runs.md) - Sprint 15 correlation details
- [Retrieve Logs](api-retrieve-logs.md) - Sprint 15 log retrieval
- [Manage Artifacts](api-manage-artifacts.md) - Sprints 16-18 artifact management
- [API Operations Summary](API_OPERATIONS_SUMMARY.md) - Complete API reference

## Support

For issues or questions:

1. Check this documentation for troubleshooting guidance
2. Review test results: `tests/orchestration-test-results.json`
3. Inspect logs: `tests/logs/*.log` or `runs/<run_id>/logs/`
4. Verify all prerequisites are installed
5. Check GitHub API status: https://www.githubstatus.com/

---

**Documentation Version**: 1.0  
**Sprint**: 20  
**Last Updated**: 2025-11-07

