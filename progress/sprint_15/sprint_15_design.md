# Sprint 15 - Design

## GH-14. Trigger workflow with REST API

Status: Accepted

## GH-15. Workflow correlation with REST API

Status: Accepted

## GH-16. Fetch logs with REST API

Status: Accepted

## Overview

Sprint 15 validates existing workflow features (GH-2, GH-3, GH-5) using pure REST API with curl instead of `gh` CLI. This sprint follows the pattern established in Sprint 9, using token authentication from `./secrets` directory. All implementations use curl for API calls and provide comprehensive error handling.

**Key Design Decisions**:
- Use curl-based REST API approach (following Sprint 9 pattern)
- Token authentication from `./secrets/github_token` or `./secrets/token` file
- Maintain compatibility with existing gh CLI implementations
- Support same CLI interface patterns for seamless migration
- Comprehensive error handling for all HTTP status codes
- Follow established input method priority order

## Feasibility Analysis

### GitHub REST API Capabilities

**GH-14 (Trigger Workflow)** - `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches`:
- ✅ API endpoint available and documented
- ✅ Supports workflow inputs via `inputs` JSON object
- ✅ Supports branch/ref specification via `ref` parameter
- ✅ Returns HTTP 204 (No Content) on success
- ✅ Error codes well-documented: 404 (workflow not found), 422 (validation error)
- Documentation: https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event

**GH-15 (Workflow Correlation)** - `GET /repos/{owner}/{repo}/actions/runs`:
- ✅ API endpoint available and documented
- ✅ Supports filtering by workflow, branch, actor, status
- ✅ Supports pagination via Link headers or page/per_page query params
- ✅ Returns runs array with metadata (id, name, status, created_at, etc.)
- ✅ Filtering by run-name (contains correlation_id) via API response parsing
- Documentation: https://docs.github.com/en/rest/actions/workflow-runs#list-workflow-runs-for-a-repository

**GH-16 (Fetch Logs)** - `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs`:
- ✅ API endpoint available and documented
- ✅ Returns ZIP archive with all job logs
- ✅ Supports multiple jobs per workflow run (aggregated in ZIP)
- ✅ Error codes: 404 (logs not available), 410 (logs expired)
- ✅ Note: Requirement mentions job-level API, but run-level API matches current GH-5 implementation
- Documentation: https://docs.github.com/en/rest/actions/workflow-runs#download-workflow-run-logs

**Alternative Job-Level API** - `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`:
- ✅ Available for per-job log access
- ⚠️ Requires listing jobs first (`GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`)
- ⚠️ Multiple API calls needed for multi-job workflows
- **Decision**: Use run-level API (matches GH-5 implementation, simpler, single API call)

### Authentication

**Token File Pattern** (from Sprint 9):
- Token stored in: `./secrets/github_token` (default) or `./secrets/token`
- Header format: `Authorization: Bearer <token>`
- Required permissions: `repo` scope (classic token) or `Actions: Write` (fine-grained token)

### Repository Resolution

**Auto-detection from git context** (following Sprint 9 pattern):
```bash
git config --get remote.origin.url
# Parse: https://github.com/owner/repo.git or git@github.com:owner/repo.git
```

**Fallback options**:
1. `--repo owner/repo` CLI flag
2. `GITHUB_REPOSITORY` environment variable
3. Error if cannot resolve

### Feasibility Conclusion

**Fully achievable** - All three backlog items can be implemented:
- ✅ GitHub API provides all required endpoints
- ✅ All required operations supported
- ✅ Authentication pattern established (Sprint 9)
- ✅ No platform limitations identified
- ✅ Compatible with existing GH-2, GH-3, GH-5 implementations

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│          Sprint 15: REST API Workflow Validation                  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-14: Trigger Workflow (REST API)                      │ │
│  │                                                            │ │
│  │  Input: --workflow, --ref, --input key=value,            │ │
│  │         [--correlation-id]                                │ │
│  │         ↓                                                  │ │
│  │  POST /repos/{owner}/{repo}/actions/workflows/{id}/      │ │
│  │        dispatches                                         │ │
│  │         ↓                                                  │ │
│  │  Output: HTTP 204 (success) or error                      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-15: Workflow Correlation (REST API)                  │ │
│  │                                                            │ │
│  │  Input: --correlation-id, [--workflow], [--ref],          │ │
│  │         [--timeout], [--interval]                        │ │
│  │         ↓                                                  │ │
│  │  GET /repos/{owner}/{repo}/actions/runs?workflow=...      │ │
│  │         ↓                                                  │ │
│  │  Filter by run-name (contains correlation_id)             │ │
│  │         ↓                                                  │ │
│  │  Output: {run_id, correlation_id} JSON                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-16: Fetch Logs (REST API)                             │ │
│  │                                                            │ │
│  │  Input: --run-id or --correlation-id, [--output-dir]      │ │
│  │         ↓                                                  │ │
│  │  GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs     │ │
│  │         ↓                                                  │ │
│  │  Download ZIP, extract, produce combined.log              │ │
│  │         ↓                                                  │ │
│  │  Output: Logs directory path                              │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Shared Components:                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Token Auth  │  │  Repo Resolve │  │  Error Handle│       │
│  │  (Sprint 9)  │  │  (Sprint 9)   │  │  (Sprint 9)  │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### GH-14. Trigger workflow with REST API

#### Script Design: `scripts/trigger-workflow-curl.sh`

**Command-line Interface**:

```bash
scripts/trigger-workflow-curl.sh --workflow <file> [--ref <branch>] 
                                  [--input key=value] [--correlation-id <uuid>]
                                  [--repo <owner/repo>] [--token-file <path>]
                                  [--json] [--help]
```

**Parameters**:
- `--workflow <file>` - Workflow file path (e.g., `dispatch-webhook.yml`) or workflow ID (required)
- `--ref <branch>` - Branch/ref to trigger workflow on (default: current branch or `main`)
- `--input key=value` - Workflow input (can be specified multiple times)
- `--correlation-id <uuid>` - Correlation UUID (auto-generated if omitted)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Input Resolution**:
- Required parameter: `--workflow` (error if missing)
- Workflow ID resolution: Try file path first, then resolve numeric ID via API
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var
- Correlation ID: Generate UUID if not provided

**API Request Body**:

```json
{
  "ref": "main",
  "inputs": {
    "webhook_url": "https://webhook.site/your-id",
    "correlation_id": "a1b2c3d4-e5f6-7a89-b0c1-234d5678ef90"
  }
}
```

**Output Formats**:

**Human-readable (default)**:
```
Workflow triggered successfully
Workflow: dispatch-webhook.yml (ID: 123456)
Branch: main
Correlation ID: a1b2c3d4-e5f6-7a89-b0c1-234d5678ef90
```

**JSON output (--json)**:
```json
{
  "workflow": "dispatch-webhook.yml",
  "workflow_id": 123456,
  "ref": "main",
  "correlation_id": "a1b2c3d4-e5f6-7a89-b0c1-234d5678ef90",
  "status": "dispatched"
}
```

**Implementation Details**:

**1. Resolve workflow ID**:
```bash
resolve_workflow_id() {
  local owner_repo="$1"
  local workflow="$2"
  local token="$3"
  
  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"
  
  # Try as file path first
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflow")
  
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | sed '$d')
  
  if [[ "$http_code" == "200" ]]; then
    echo "$response_body" | jq -r '.id'
    return 0
  fi
  
  # If file path fails, try as numeric ID
  if [[ "$workflow" =~ ^[0-9]+$ ]]; then
    echo "$workflow"
    return 0
  fi
  
  echo "Error: Workflow not found: $workflow" >&2
  return 1
}
```

**2. Build request body**:
```bash
build_dispatch_body() {
  local ref="$1"
  local correlation_id="$2"
  shift 2
  local inputs=("$@")
  
  local body_json="{"
  body_json+="\"ref\":$(jq -n --arg ref "$ref" '$ref')"
  
  if [[ ${#inputs[@]} -gt 0 ]] || [[ -n "$correlation_id" ]]; then
    body_json+=",\"inputs\":{"
    local first=true
    
    if [[ -n "$correlation_id" ]]; then
      body_json+="\"correlation_id\":$(jq -n --arg id "$correlation_id" '$id')"
      first=false
    fi
    
    for input in "${inputs[@]}"; do
      if [[ "$input" =~ ^([^=]+)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        [[ "$first" == "false" ]] && body_json+=","
        body_json+="\"$key\":$(jq -n --arg val "$value" '$val')"
        first=false
      fi
    done
    
    body_json+="}"
  fi
  
  body_json+="}"
  echo "$body_json"
}
```

**3. Dispatch workflow via API**:
```bash
dispatch_workflow() {
  local owner_repo="$1"
  local workflow_id="$2"
  local token="$3"
  local body_json="$4"
  
  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"
  
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body_json" \
    "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflow_id/dispatches")
  
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | sed '$d')
  
  case "$http_code" in
    204)
      return 0
      ;;
    404)
      echo "Error: Workflow not found (ID: $workflow_id)" >&2
      return 1
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      echo "Error: Validation failed - $error_msg" >&2
      echo "$response_body" | jq -r '.errors[]? | "  - \(.field // "unknown"): \(.message // "error")" | .' >&2
      return 1
      ;;
    403)
      echo "Error: Insufficient permissions to trigger workflow" >&2
      return 1
      ;;
    401)
      echo "Error: Authentication failed. Check token permissions." >&2
      return 1
      ;;
    *)
      echo "Error: API request failed (HTTP $http_code)" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2
      return 1
      ;;
  esac
}
```

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 204 | Success | N/A (output success message) |
| 404 | Workflow not found | "Workflow not found (ID: {id})" |
| 422 | Validation error | "Validation failed - {message}" + field errors |
| 403 | Insufficient permissions | "Insufficient permissions to trigger workflow" |
| 401 | Authentication failed | "Authentication failed. Check token permissions." |
| Other | Unknown error | "API request failed (HTTP {code})" |

**Exit Codes**:
- `0`: Workflow triggered successfully
- `1`: Error (API error, validation failure, missing parameters)
- `2`: Invalid arguments or missing required parameters

### GH-15. Workflow correlation with REST API

#### Script Design: `scripts/correlate-workflow-curl.sh`

**Command-line Interface**:

```bash
scripts/correlate-workflow-curl.sh --correlation-id <uuid> [--workflow <file>]
                                    [--ref <branch>] [--timeout <seconds>]
                                    [--interval <seconds>] [--store-dir <dir>]
                                    [--repo <owner/repo>] [--token-file <path>]
                                    [--json-only] [--help]
```

**Parameters**:
- `--correlation-id <uuid>` - Correlation UUID (required)
- `--workflow <file>` - Workflow file path or ID (optional, filters by workflow)
- `--ref <branch>` - Branch/ref filter (default: current branch or `main`)
- `--timeout <seconds>` - Maximum time to wait (default: 60)
- `--interval <seconds>` - Polling interval (default: 3)
- `--store-dir <dir>` - Directory to store metadata (optional)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--json-only` - Output only JSON (no progress messages)
- `--help` - Display usage information

**Input Resolution**:
- Required parameter: `--correlation-id` (error if missing)
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var
- Workflow filter: Optional, improves correlation accuracy

**API Query Parameters**:

```
GET /repos/{owner}/{repo}/actions/runs?workflow_id={id}&head_branch={branch}&status=queued,in_progress&per_page=30
```

**Correlation Strategy**:
1. Poll `GET /repos/{owner}/{repo}/actions/runs` with filters
2. Filter results by:
   - Workflow ID (if provided)
   - Branch (head_branch)
   - Status (queued, in_progress)
   - Run name contains correlation_id
3. Return first matching run_id

**Output Formats**:

**Human-readable (default)**:
```
Searching for workflow run with correlation ID: a1b2c3d4-e5f6-7a89-b0c1-234d5678ef90
Polling... (elapsed: 5s, checked: 2 runs)
Found run ID: 1234567890
```

**JSON output (--json-only)**:
```json
{
  "run_id": 1234567890,
  "correlation_id": "a1b2c3d4-e5f6-7a89-b0c1-234d5678ef90",
  "workflow": "dispatch-webhook.yml",
  "status": "in_progress"
}
```

**Implementation Details**:

**1. Poll workflow runs**:
```bash
poll_workflow_runs() {
  local owner_repo="$1"
  local workflow_id="$2"
  local branch="$3"
  local token="$4"
  local correlation_id="$5"
  
  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"
  
  local query="status=queued,in_progress&per_page=30"
  [[ -n "$workflow_id" ]] && query+="&workflow_id=$workflow_id"
  [[ -n "$branch" ]] && query+="&head_branch=$branch"
  
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs?$query")
  
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | sed '$d')
  
  if [[ "$http_code" != "200" ]]; then
    handle_api_error "$http_code" "$response_body"
    return 1
  fi
  
  # Filter by correlation_id in run name
  echo "$response_body" | jq -r --arg corr_id "$correlation_id" \
    '.workflow_runs[] | select(.name | contains($corr_id)) | .id' | head -n1
}
```

**2. Correlation loop**:
```bash
correlate_workflow() {
  local owner_repo="$1"
  local workflow_id="$2"
  local branch="$3"
  local token="$4"
  local correlation_id="$5"
  local timeout="$6"
  local interval="$7"
  local json_only="$8"
  
  local start_time=$(date +%s)
  local elapsed=0
  local checked=0
  
  while [[ $elapsed -lt $timeout ]]; do
    local run_id
    run_id=$(poll_workflow_runs "$owner_repo" "$workflow_id" "$branch" "$token" "$correlation_id")
    checked=$((checked + 1))
    
    if [[ -n "$run_id" ]]; then
      if [[ "$json_only" != "true" ]]; then
        echo "Found run ID: $run_id"
      fi
      echo "$run_id"
      return 0
    fi
    
    elapsed=$(($(date +%s) - start_time))
    if [[ "$json_only" != "true" ]]; then
      printf "\rPolling... (elapsed: %ds, checked: %d runs)" "$elapsed" "$checked" >&2
    fi
    
    sleep "$interval"
  done
  
  echo "Error: Timeout waiting for workflow run with correlation ID: $correlation_id" >&2
  return 1
}
```

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 200 | Success | N/A (output run_id) |
| 404 | Repository not found | "Repository not found" |
| 403 | Insufficient permissions | "Insufficient permissions to list workflow runs" |
| 401 | Authentication failed | "Authentication failed. Check token permissions." |
| Timeout | No run found | "Timeout waiting for workflow run" |

**Exit Codes**:
- `0`: Run ID found successfully
- `1`: Error (API error, timeout, missing parameters)
- `2`: Invalid arguments or missing required parameters

### GH-16. Fetch logs with REST API

#### Script Design: `scripts/fetch-logs-curl.sh`

**Command-line Interface**:

```bash
scripts/fetch-logs-curl.sh [--run-id <id>] [--correlation-id <uuid>]
                            [--runs-dir <dir>] [--output-dir <dir>]
                            [--repo <owner/repo>] [--token-file <path>]
                            [--json] [--help]
```

**Parameters**:
- `--run-id <id>` - Workflow run ID (numeric)
- `--correlation-id <uuid>` - Load run_id from stored metadata
- `--runs-dir <dir>` - Base directory for metadata (default: `runs`)
- `--output-dir <dir>` - Output directory for logs (default: `runs/<correlation>/logs`)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Input Resolution**:
- Input priority: `--run-id` → `--correlation-id` → stdin JSON
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var

**API Endpoint**:

```
GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs
```

**Implementation Details**:

**1. Validate run completion**:
```bash
check_run_completion() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  
  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"
  
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id")
  
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | sed '$d')
  
  if [[ "$http_code" != "200" ]]; then
    handle_api_error "$http_code" "$response_body"
    return 1
  fi
  
  local status
  status=$(echo "$response_body" | jq -r '.status')
  
  if [[ "$status" != "completed" ]]; then
    echo "Error: Run $run_id is still $status. Wait for completion before fetching logs." >&2
    return 1
  fi
  
  return 0
}
```

**2. Download logs**:
```bash
download_logs() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  local output_file="$4"
  
  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"
  
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/logs" \
    -o "$output_file")
  
  http_code=$(echo "$response" | tail -n1)
  
  case "$http_code" in
    200)
      return 0
      ;;
    404)
      echo "Error: Logs not available for run $run_id (may still be processing)" >&2
      return 1
      ;;
    410)
      echo "Error: Logs expired for run $run_id (GitHub retention policy)" >&2
      return 1
      ;;
    403)
      echo "Error: Insufficient permissions to download logs" >&2
      return 1
      ;;
    401)
      echo "Error: Authentication failed. Check token permissions." >&2
      return 1
      ;;
    *)
      echo "Error: Failed to download logs (HTTP $http_code)" >&2
      return 1
      ;;
  esac
}
```

**3. Extract and process logs** (reuse logic from Sprint 3):
- Download ZIP archive
- Extract to structured directories (`logs/<job_name>/step.log`)
- Produce `combined.log` with chronological concatenation
- Emit `logs.json` metadata file

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 200 | Success | N/A (output logs directory path) |
| 404 | Logs not available | "Logs not available (may still be processing)" |
| 410 | Logs expired | "Logs expired (GitHub retention policy)" |
| 403 | Insufficient permissions | "Insufficient permissions to download logs" |
| 401 | Authentication failed | "Authentication failed. Check token permissions." |
| Other | Unknown error | "Failed to download logs (HTTP {code})" |

**Exit Codes**:
- `0`: Logs downloaded successfully
- `1`: Error (API error, run not completed, missing parameters)
- `2`: Invalid arguments or missing required parameters

## Integration Patterns

### Pattern 1: Trigger → Correlate → Fetch Logs

```bash
# Trigger workflow
scripts/trigger-workflow-curl.sh \
  --workflow dispatch-webhook.yml \
  --input webhook_url="$WEBHOOK_URL" \
  --correlation-id "$(uuidgen)" \
  --json > trigger.json

correlation_id=$(jq -r '.correlation_id' trigger.json)

# Correlate to get run_id
run_id=$(scripts/correlate-workflow-curl.sh \
  --correlation-id "$correlation_id" \
  --workflow dispatch-webhook.yml \
  --json-only)

# Wait for completion, then fetch logs
scripts/fetch-logs-curl.sh --run-id "$run_id" --json
```

### Pattern 2: Integration with Existing Scripts

```bash
# Use curl version for triggering
scripts/trigger-workflow-curl.sh --workflow dispatch-webhook.yml --input webhook_url="$WEBHOOK_URL"

# Use existing correlation script (gh CLI) for comparison
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL"

# Use curl version for log fetching
scripts/fetch-logs-curl.sh --run-id 1234567890
```

## Testing Strategy

### GH-14 (Trigger Workflow)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-14-1 | Trigger workflow with minimal fields | HTTP 204, workflow triggered |
| GH-14-2 | Trigger workflow with inputs | HTTP 204, inputs passed correctly |
| GH-14-3 | Trigger workflow with correlation_id | HTTP 204, correlation_id in inputs |
| GH-14-4 | Invalid workflow file | HTTP 404, error message |
| GH-14-5 | Invalid branch | HTTP 422, validation error |
| GH-14-6 | Missing required fields | Exit code 2, usage message |
| GH-14-7 | JSON output format | Valid JSON with workflow details |
| GH-14-8 | Auto-detect repository | Uses git config |

### GH-15 (Workflow Correlation)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-15-1 | Correlate with valid correlation_id | Returns run_id within timeout |
| GH-15-2 | Correlate with workflow filter | Faster correlation, correct run_id |
| GH-15-3 | Correlate with branch filter | Filters by branch, correct run_id |
| GH-15-4 | Timeout scenario | Exit code 1, timeout message |
| GH-15-5 | Invalid correlation_id | Timeout (no match found) |
| GH-15-6 | JSON output format | Valid JSON with run_id and correlation_id |
| GH-15-7 | Store metadata | Creates metadata.json file |

### GH-16 (Fetch Logs)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-16-1 | Fetch logs for completed run | Downloads ZIP, extracts logs |
| GH-16-2 | Fetch logs for in-progress run | Exit code 1, error message |
| GH-16-3 | Fetch logs with correlation_id | Loads run_id from metadata |
| GH-16-4 | Invalid run_id | HTTP 404, error message |
| GH-16-5 | Expired logs | HTTP 410, error message |
| GH-16-6 | JSON output format | Valid JSON with log paths |
| GH-16-7 | Produce combined.log | Creates combined.log file |
| GH-16-8 | Produce logs.json | Creates logs.json metadata |

## Compatibility with Previous Sprints

**Sprint 1 (GH-2, GH-3)**:
- ✅ Compatible CLI interface (similar flags)
- ✅ Same correlation mechanism (UUID in run-name)
- ✅ Compatible metadata storage format
- ✅ Can be used as drop-in replacement

**Sprint 3 (GH-5)**:
- ✅ Compatible log extraction logic
- ✅ Same output structure (combined.log, logs.json)
- ✅ Compatible with existing log processing scripts

**Sprint 9 (REST API Pattern)**:
- ✅ Reuse token file authentication: `./secrets/github_token`
- ✅ Follow curl-based REST API approach
- ✅ Consistent error handling patterns
- ✅ Repository auto-detection from git config

## Risks and Mitigations

### Risk 1: Workflow ID Resolution Complexity

**Risk**: Resolving workflow ID from file path may fail
**Impact**: Script fails to trigger workflow
**Mitigation**: Try file path first, fallback to numeric ID, clear error messages

### Risk 2: Correlation Timeout

**Risk**: Workflow may not appear in API immediately after dispatch
**Impact**: Correlation fails even though workflow was triggered
**Mitigation**: Polling with configurable timeout and interval, clear timeout messages

### Risk 3: Log Availability Timing

**Risk**: Logs may not be immediately available after run completion
**Impact**: Fetch fails even though run completed
**Mitigation**: Validate run completion before download, retry logic for 404 errors

### Risk 4: API Rate Limiting

**Risk**: High-frequency polling may hit rate limits
**Impact**: HTTP 403 errors
**Mitigation**: Use reasonable polling intervals, handle 403 responses gracefully

### Risk 5: Token Permissions

**Risk**: Token may lack required Actions permissions
**Impact**: HTTP 403 errors
**Mitigation**: Document required permissions, provide clear error messages

## Success Criteria

Sprint 15 design is successful when:

1. ✅ Feasibility analysis confirms GitHub API supports all operations
2. ✅ Script designs cover all required functionality for GH-14, GH-15, GH-16
3. ✅ CLI interfaces maintain compatibility with existing gh CLI implementations
4. ✅ Error handling addresses all HTTP status codes
5. ✅ Output formats (human-readable and JSON) specified
6. ✅ Integration patterns documented
7. ✅ Test strategy covers all scenarios
8. ✅ Risks identified with mitigation strategies
9. ✅ Compatibility with previous sprints maintained

## Documentation

**Implementation Notes** (to be created in construction phase):
- `progress/sprint_15_implementation.md`
- Usage examples for each script
- Test execution results
- Comparison with gh CLI implementations

**Script Help** (inline in each script):
- `scripts/trigger-workflow-curl.sh --help`
- `scripts/correlate-workflow-curl.sh --help`
- `scripts/fetch-logs-curl.sh --help`

## Design Approval

**Status**: Awaiting Product Owner review

This design document is ready for Product Owner review. Implementation will proceed after approval (status change to "Accepted").

**Design addresses**:
- ✅ GH-14: Trigger workflow with REST API, full input support
- ✅ GH-15: Workflow correlation with REST API, UUID-based filtering
- ✅ GH-16: Fetch logs with REST API, run-level log aggregation
- ✅ Integration with existing Sprint 1, 3, 9 tooling
- ✅ Comprehensive test strategy
- ✅ Error handling and risk mitigation

