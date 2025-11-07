# Trigger GitHub Workflow via REST API

**API Operation Summary** | Sprint 15 Implementation (GH-14)

## Purpose

Trigger GitHub workflow executions programmatically using the REST API. This operation allows automation tools and scripts to initiate workflow_dispatch workflows without using the GitHub CLI, providing full control over workflow inputs, branches, and correlation tracking.

## API Endpoint

```
POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches
```

**Documentation**: [GitHub REST API - Create a workflow dispatch event](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)

## Authentication

**Required Permission**: `Actions: Write`

**Token Storage**: Place your GitHub Personal Access Token in one of these locations:
- `./secrets/github_token`
- `./secrets/token`

**Token Format**: Plain text file containing the token (one line, no additional content)

## Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `workflow_id` | string | Workflow file path (e.g., `.github/workflows/myworkflow.yml`) or workflow ID number |
| `ref` | string | Git reference (branch, tag, or commit SHA). Defaults to repository's default branch |

### Optional Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `inputs` | object | Key-value pairs for workflow inputs (must match workflow input definitions) |

### Project-Specific Extensions

The `scripts/trigger-workflow-curl.sh` implementation adds:

| Extension | Description |
|-----------|-------------|
| `--correlation-id` | UUID for tracking workflow runs (auto-generated if not provided) |
| `--input key=value` | Multiple inputs via repeated flags |
| `--json` | JSON output format for automation |
| `--repo owner/repo` | Override repository auto-detection |

## Usage Examples

### Example 1: Minimal Workflow Trigger

**Purpose**: Trigger a workflow with only required parameters

```bash
# Trigger workflow on default branch
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/dispatch-webhook.yml
```

**Expected Output**:
```
✓ Workflow triggered successfully
  Workflow: dispatch-webhook.yml
  Correlation ID: 12345678-1234-1234-1234-123456789012
  Repository: rstyczynski/github_tricks
  Branch: main

Use this correlation ID to track the workflow run:
  ./scripts/correlate-workflow-curl.sh --correlation-id 12345678-1234-1234-1234-123456789012
```

### Example 2: Trigger with Workflow Inputs

**Purpose**: Pass input parameters to workflow

```bash
# Trigger workflow with custom inputs
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/dispatch-webhook.yml \
  --input message="Hello from API" \
  --input priority=high
```

**Expected Output**:
```
✓ Workflow triggered successfully
  Workflow: dispatch-webhook.yml
  Inputs:
    - message: Hello from API
    - priority: high
  Correlation ID: 87654321-4321-4321-4321-210987654321
```

### Example 3: Trigger with Custom Correlation ID

**Purpose**: Use your own tracking identifier

```bash
# Generate your own correlation ID
CORRELATION_ID=$(uuidgen)
echo "Tracking with: $CORRELATION_ID"

# Trigger workflow
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/dispatch-webhook.yml \
  --correlation-id "$CORRELATION_ID"
```

**Expected Output**:
```
✓ Workflow triggered successfully
  Workflow: dispatch-webhook.yml
  Correlation ID: a1b2c3d4-5678-90ab-cdef-1234567890ab
  (user-provided)
```

### Example 4: JSON Output for Automation

**Purpose**: Get machine-readable output

```bash
# Trigger and capture JSON output
RESULT=$(./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/dispatch-webhook.yml \
  --json)

echo "$RESULT" | jq .
```

**Expected Output**:
```json
{
  "success": true,
  "workflow_id": "dispatch-webhook.yml",
  "correlation_id": "12345678-abcd-ef01-2345-6789abcdef01",
  "repository": "rstyczynski/github_tricks",
  "ref": "main"
}
```

### Example 5: Trigger on Specific Branch

**Purpose**: Trigger workflow on non-default branch

```bash
# Trigger on feature branch
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/test-workflow.yml \
  --ref feature/new-api
```

## Error Scenarios

### Error 1: Workflow Not Found (HTTP 404)

**Cause**: Workflow file path incorrect or workflow doesn't exist

**Example**:
```bash
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/nonexistent.yml
```

**Error Message**:
```
✗ Error: Workflow not found (HTTP 404)
  Workflow: nonexistent.yml

Possible causes:
  - Workflow file doesn't exist
  - Incorrect file path
  - Workflow not on specified branch
```

**Resolution**: Verify workflow file path and ensure workflow exists in repository

### Error 2: Validation Error (HTTP 422)

**Cause**: Invalid inputs or workflow not configured for workflow_dispatch

**Example**:
```bash
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/dispatch-webhook.yml \
  --input invalid_key=value
```

**Error Message**:
```
✗ Error: Validation failed (HTTP 422)

Possible causes:
  - Workflow doesn't have 'workflow_dispatch' trigger
  - Input key doesn't match workflow input definitions
  - Input validation failed
```

**Resolution**: Check workflow file for workflow_dispatch configuration and valid input definitions

### Error 3: Authentication Error (HTTP 401/403)

**Cause**: Invalid or missing token, insufficient permissions

**Example**:
```bash
# With invalid token file
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/dispatch-webhook.yml
```

**Error Message**:
```
✗ Error: Authentication failed (HTTP 401)

Required:
  - Valid GitHub token in ./secrets/token or ./secrets/github_token
  - Token must have 'Actions: Write' permission
```

**Resolution**: Verify token file exists and has correct permissions

## Best Practices

### 1. Use Correlation IDs for Tracking

Always use correlation IDs to track workflow runs, especially in automation:

```bash
CORRELATION_ID=$(uuidgen)

# Trigger workflow
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/myworkflow.yml \
  --correlation-id "$CORRELATION_ID"

# Later, correlate to get run_id
./scripts/correlate-workflow-curl.sh \
  --correlation-id "$CORRELATION_ID"
```

### 2. Validate Inputs Before Triggering

Check that inputs match workflow definitions:

```bash
# Good: Inputs match workflow definition
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/parameterized.yml \
  --input environment=production \
  --input version=v1.2.3
```

### 3. Use JSON Output in Scripts

For automated workflows, use JSON output and error checking:

```bash
RESULT=$(./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/deploy.yml \
  --json 2>&1)

if echo "$RESULT" | jq -e '.success == true' > /dev/null; then
  CORRELATION_ID=$(echo "$RESULT" | jq -r '.correlation_id')
  echo "Workflow triggered: $CORRELATION_ID"
else
  echo "Failed to trigger workflow"
  echo "$RESULT"
fi
```

### 4. Handle Rate Limiting

GitHub API has rate limits. For high-frequency triggering, implement backoff:

```bash
# Trigger multiple workflows with delay
for workflow in workflow1.yml workflow2.yml workflow3.yml; do
  ./scripts/trigger-workflow-curl.sh --workflow .github/workflows/$workflow
  sleep 2  # Prevent rate limiting
done
```

## Related Operations

After triggering a workflow, you typically want to:

1. **Correlate the run**: Use correlation ID to get `run_id`
   - See: [Correlate Workflow Runs](api-correlate-runs.md)
   - Script: `./scripts/correlate-workflow-curl.sh`

2. **Retrieve logs**: Once run completes, fetch execution logs
   - See: [Retrieve Workflow Logs](api-retrieve-logs.md)
   - Script: `./scripts/fetch-logs-curl.sh`

3. **Manage artifacts**: Download or list artifacts produced by workflow
   - See: [Manage Workflow Artifacts](api-manage-artifacts.md)
   - Scripts: `./scripts/list-artifacts-curl.sh`, `./scripts/download-artifact-curl.sh`

## Complete Workflow Example

**Scenario**: Trigger workflow, wait for completion, retrieve logs

```bash
# Step 1: Trigger workflow with correlation ID
CORRELATION_ID=$(uuidgen)
echo "Correlation ID: $CORRELATION_ID"

./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/test-workflow.yml \
  --correlation-id "$CORRELATION_ID" \
  --input test_suite=integration

# Step 2: Wait a few seconds for run to appear
sleep 5

# Step 3: Correlate to get run_id
RUN_ID=$(./scripts/correlate-workflow-curl.sh \
  --correlation-id "$CORRELATION_ID" \
  --json | jq -r '.run_id')

echo "Run ID: $RUN_ID"

# Step 4: Wait for completion (optional - use wait script)
./scripts/wait-workflow-completion-curl.sh --run-id "$RUN_ID"

# Step 5: Fetch logs
./scripts/fetch-logs-curl.sh --run-id "$RUN_ID"
```

## Implementation Reference

**Sprint**: Sprint 15 (GH-14)
**Script**: `scripts/trigger-workflow-curl.sh`
**Design**: `progress/sprint_15_design.md`
**Implementation**: `progress/sprint_15_implementation.md`
**Tests**: `progress/sprint_15_tests.md`

## API Rate Limits

**Primary Rate Limit**: 5,000 requests per hour (authenticated)
**Secondary Rate Limit**: ~50 workflow triggers per hour per workflow

**Monitoring**: Check response headers for rate limit status:
- `X-RateLimit-Limit`: Total limit
- `X-RateLimit-Remaining`: Remaining requests
- `X-RateLimit-Reset`: Reset time (Unix timestamp)

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-11 | Initial implementation (Sprint 15) |

---

**See Also**:
- [Correlate Workflow Runs](api-correlate-runs.md)
- [Retrieve Workflow Logs](api-retrieve-logs.md)
- [Manage Workflow Artifacts](api-manage-artifacts.md)
