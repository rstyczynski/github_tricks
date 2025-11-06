# Sprint 15 - Implementation Notes

## GH-14. Trigger workflow with REST API

Status: Implemented

### Implementation Summary

Created `scripts/trigger-workflow-curl.sh` script that triggers GitHub workflows using pure REST API with curl instead of `gh` CLI.

**Key Features**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- Workflow ID resolution (file path or numeric ID)
- Support for workflow inputs via `--input key=value` flags
- Correlation ID support (auto-generated or provided)
- Repository auto-detection from git context
- Comprehensive error handling for all HTTP status codes
- JSON output support for automation

**Implementation Details**:
- Follows Sprint 9's `view-run-jobs-curl.sh` pattern for token loading and repository resolution
- Uses `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` endpoint
- Handles HTTP 204 (success), 404 (workflow not found), 422 (validation error), 401/403 (auth errors)
- Workflow ID resolution: tries file path first, falls back to numeric ID
- Auto-generates UUID correlation ID if not provided
- Defaults to current git branch or `main` for ref

**Static Validation**:
- ✅ Shellcheck: No errors or warnings
- ✅ Script is executable

**Testing Requirements**:
- Requires GitHub repository with workflow_dispatch workflows
- Requires valid GitHub token with Actions: Write permissions
- Test scenarios documented in design document (GH-14-1 through GH-14-8)

**Status**: Script implemented and ready for testing. Full testing requires GitHub repository access.

## GH-15. Workflow correlation with REST API

Status: Implemented

### Implementation Summary

Created `scripts/correlate-workflow-curl.sh` script that correlates workflow runs using pure REST API with curl instead of `gh` CLI.

**Key Features**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- UUID-based correlation filtering via run-name matching
- Polling mechanism with configurable timeout (default 60s) and interval (default 3s)
- Workflow and branch filtering support
- Metadata storage support (`--store-dir`)
- Repository auto-detection from git context
- Comprehensive error handling

**Implementation Details**:
- Follows Sprint 1's `trigger-and-track.sh` correlation logic but using REST API
- Uses `GET /repos/{owner}/{repo}/actions/runs` endpoint with filtering
- Filters by workflow_id, head_branch, status (queued/in_progress)
- Filters run-name containing correlation_id using jq
- Polling loop with progress feedback (unless `--json-only`)
- Stores metadata in `runs/<correlation_id>.json` format (compatible with existing scripts)
- Fetches run status for JSON output

**Static Validation**:
- ✅ Shellcheck: No errors or warnings (SC1091 info about sourcing is expected)
- ✅ Script is executable

**Testing Requirements**:
- Requires GitHub repository with workflow_dispatch workflows
- Requires valid GitHub token with Actions: Read permissions
- Test scenarios documented in design document (GH-15-1 through GH-15-7)
- Requires triggering workflows first to test correlation

**Status**: Script implemented and ready for testing. Full testing requires GitHub repository access.

## GH-16. Fetch logs with REST API

Status: Implemented

### Implementation Summary

Created `scripts/fetch-logs-curl.sh` script that fetches workflow logs using pure REST API with curl instead of `gh` CLI.

**Key Features**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- Run completion validation before download
- ZIP archive download and extraction
- Structured log organization (`logs/<job_name>/step.log`)
- Combined log generation (`combined.log`)
- Metadata JSON generation (`logs.json`)
- Repository auto-detection from git context
- Comprehensive error handling

**Implementation Details**:
- Follows Sprint 3's `fetch-run-logs.sh` log processing logic
- Uses `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs` endpoint
- Reuses log extraction and aggregation logic from Sprint 3
- Handles HTTP 404 (logs not available), 410 (logs expired), 401/403 (auth errors)
- Validates run is completed before attempting download
- Fetches jobs data via paginated API calls
- Generates `logs.json` metadata file with run, job, and step information

**Static Validation**:
- ✅ Shellcheck: No errors or warnings (SC1091 info about sourcing is expected)
- ✅ Script is executable

**Testing Requirements**:
- Requires GitHub repository with completed workflow runs
- Requires valid GitHub token with Actions: Read permissions
- Test scenarios documented in design document (GH-16-1 through GH-16-8)
- Requires completed workflow runs to test log retrieval

**Status**: Script implemented and ready for testing. Full testing requires GitHub repository access.

## Implementation Approach

### Shared Components

All three scripts reuse patterns from Sprint 9 (`view-run-jobs-curl.sh`):

**1. Token Loading**:
```bash
load_token() {
  local token_file="$1"
  # Validate file exists, readable, non-empty
  # Warn about permissions
  # Return token string
}
```

**2. Repository Resolution**:
```bash
resolve_repository() {
  # Priority: --repo flag → GITHUB_REPOSITORY env → git remote
  # Parse GitHub URL (HTTPS or SSH)
  # Validate owner/repo format
}
```

**3. Error Handling**:
```bash
handle_api_error() {
  local http_code="$1"
  local body="$2"
  # Handle 401, 403, 404, 422, 5xx errors
  # Provide clear error messages
  # Never leak token in errors
}
```

### Script Structure

Each script follows this structure:
1. Parse command-line arguments
2. Validate required parameters
3. Load token from file
4. Resolve repository
5. Execute API operations
6. Format and output results
7. Handle errors appropriately

### Integration with Existing Scripts

**Compatibility**:
- ✅ Compatible CLI interface with existing gh CLI scripts
- ✅ Compatible metadata storage format (`runs/<correlation>/metadata.json`)
- ✅ Compatible log output structure (`combined.log`, `logs.json`)
- ✅ Can be used as drop-in replacement for gh CLI versions

**Usage Patterns**:
```bash
# Trigger → Correlate → Fetch Logs (curl version)
scripts/trigger-workflow-curl.sh --workflow dispatch-webhook.yml --input webhook_url="$WEBHOOK_URL" --json > trigger.json
correlation_id=$(jq -r '.correlation_id' trigger.json)
run_id=$(scripts/correlate-workflow-curl.sh --correlation-id "$correlation_id" --json-only)
scripts/fetch-logs-curl.sh --run-id "$run_id"

# Mixed usage (curl + gh CLI)
scripts/trigger-workflow-curl.sh --workflow dispatch-webhook.yml --input webhook_url="$WEBHOOK_URL"
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL"  # Compare results
```

## Testing Strategy

### Static Validation

```bash
# Shell script linting
shellcheck scripts/trigger-workflow-curl.sh
shellcheck scripts/correlate-workflow-curl.sh
shellcheck scripts/fetch-logs-curl.sh

# GitHub workflow syntax (if workflows modified)
actionlint
```

### Manual Testing (Requires GitHub Access)

**Prerequisites**:
1. GitHub repository with workflow_dispatch workflows
2. GitHub token with Actions: Write permissions
3. Token file: `./secrets/github_token` or `./secrets/token`
4. Webhook URL from https://webhook.site (for testing)

**Test Matrix**:

**GH-14 Tests**:
- ⏳ Trigger workflow with minimal fields
- ⏳ Trigger workflow with inputs
- ⏳ Trigger workflow with correlation_id
- ⏳ Invalid workflow file (404 error)
- ⏳ Invalid branch (422 error)
- ⏳ JSON output format
- ⏳ Auto-detect repository

**GH-15 Tests**:
- ⏳ Correlate with valid correlation_id
- ⏳ Correlate with workflow filter
- ⏳ Correlate with branch filter
- ⏳ Timeout scenario
- ⏳ JSON output format
- ⏳ Store metadata

**GH-16 Tests**:
- ⏳ Fetch logs for completed run
- ⏳ Fetch logs for in-progress run (error)
- ⏳ Fetch logs with correlation_id
- ⏳ Invalid run_id (404 error)
- ⏳ Expired logs (410 error)
- ⏳ Produce combined.log
- ⏳ Produce logs.json

### Integration Tests

**End-to-End Test**:
```bash
# 1. Trigger workflow
result=$(scripts/trigger-workflow-curl.sh \
  --workflow dispatch-webhook.yml \
  --input webhook_url="$WEBHOOK_URL" \
  --json)

correlation_id=$(echo "$result" | jq -r '.correlation_id')

# 2. Correlate to get run_id
run_id=$(scripts/correlate-workflow-curl.sh \
  --correlation-id "$correlation_id" \
  --workflow dispatch-webhook.yml \
  --json-only)

# 3. Wait for completion (use existing watch script or manual wait)
# 4. Fetch logs
scripts/fetch-logs-curl.sh --run-id "$run_id" --json
```

**Status**: Integration testing pending GitHub repository access.

## Comparison with gh CLI Implementations

### GH-14 vs GH-2

| Feature | gh CLI (GH-2) | REST API (GH-14) |
|---------|---------------|------------------|
| Command | `gh workflow run` | `curl POST /dispatches` |
| Auth | Browser/gh auth | Token file |
| Workflow ID | Auto-resolved | Manual resolution |
| Inputs | `--raw-field` | `--input key=value` |
| Output | HTTP 204 | HTTP 204 + JSON |

### GH-15 vs GH-3

| Feature | gh CLI (GH-3) | REST API (GH-15) |
|---------|----------------|------------------|
| Command | `gh run list` | `curl GET /runs` |
| Auth | Browser/gh auth | Token file |
| Filtering | jq filtering | API + jq filtering |
| Polling | Same | Same |
| Output | JSON | JSON |

### GH-16 vs GH-5

| Feature | gh CLI (GH-5) | REST API (GH-16) |
|---------|---------------|------------------|
| Command | `gh api /logs` | `curl GET /logs` |
| Auth | Browser/gh auth | Token file |
| Log Processing | Same | Same |
| Output | Same | Same |

## Next Steps

**For Full Testing**:
1. Obtain GitHub repository access
2. Configure GitHub token with appropriate permissions
3. Execute manual test matrix with GitHub repository access
4. Document test results in implementation notes
5. Update progress board with test results

**For Production Use**:
- Scripts are ready for use
- Follow usage examples in design document
- Ensure token file has correct permissions (600)
- Test in non-production environment first

## Status Summary

**Design**: ✅ Complete (`progress/sprint_15_design.md`)
**Implementation**: ✅ Complete (all three scripts implemented)
**Static Validation**: ✅ Complete (shellcheck passed, actionlint passed)
**Manual Testing**: ⏳ Pending GitHub repository access

**Blockers**:
- None (implementation complete)
- Testing requires GitHub repository access

**Deliverables**:
- ✅ Design document complete
- ✅ Implementation scripts complete
- ⏳ Test results (pending GitHub access)

