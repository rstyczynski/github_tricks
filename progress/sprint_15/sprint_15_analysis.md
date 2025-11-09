# Sprint 15 - Analysis

**Date**: 2025-01-27
**Sprint**: 15
**Status**: Analysis Complete
**Backlog Items**: GH-14, GH-15, GH-16

## Executive Summary

Sprint 15 validates existing workflow features (GH-2, GH-3, GH-5) using pure REST API with curl instead of `gh` CLI. This sprint follows the pattern established in Sprint 9, using token authentication from `./secrets` directory. All implementations use curl for API calls and provide comprehensive error handling, maintaining compatibility with existing gh CLI implementations.

## Backlog Items Analysis

### GH-14. Trigger workflow with REST API

**Requirement**: Validate GH-2 (Trigger GitHub workflow) using pure REST API with curl instead of `gh` CLI. Use GitHub's `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` endpoint. The implementation should handle authentication with token from `./secrets` directory, support workflow inputs, and provide proper error handling for common scenarios such as invalid workflow IDs or authentication failures.

**API Endpoint**: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches`

**Key Capabilities Required**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- Workflow ID resolution (file path or numeric ID)
- Support for workflow inputs via `--input key=value` flags
- Correlation ID support (auto-generated or provided)
- Repository auto-detection from git context
- Comprehensive error handling for all HTTP status codes
- JSON output support for automation

**Current Implementation (GH-2)**:
- Uses `gh workflow run dispatch-webhook.yml --raw-field webhook_url=$WEBHOOK_URL`
- Resolves workflow numeric ID via `gh api repos/:owner/:repo/actions/workflows/dispatch-webhook.yml --jq '.id'`
- Handles 404 errors by retrying with numeric workflow ID

**REST API Requirements**:
- Use `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` endpoint
- Handle authentication with token from `./secrets` directory
- Support workflow inputs (webhook_url, correlation_id, etc.)
- Provide proper error handling for:
  - Invalid workflow IDs (404)
  - Authentication failures (401/403)
  - Invalid inputs (422)

**Pattern Reference**: Follow Sprint 9's `view-run-jobs-curl.sh` pattern:
- Token loading from `./secrets/github_token` or `./secrets/token`
- Repository resolution (CLI flag → env → git remote)
- HTTP error handling with descriptive messages
- Bearer token authentication headers

**Integration Points**:
- Must work with existing `.github/workflows/dispatch-webhook.yml`
- Support same workflow inputs (webhook_url, correlation_id)
- Compatible with existing correlation mechanism (UUID in run-name)
- Can be used as drop-in replacement for `gh workflow run` command

**Technical Considerations**:
- GitHub API returns HTTP 204 (No Content) on success
- Workflow ID can be file path or numeric ID
- Inputs passed as JSON object in request body
- Branch/ref specified via `ref` parameter
- Error codes: 404 (workflow not found), 422 (validation error), 401/403 (auth errors)

**Open Questions**:
- Should script auto-generate correlation_id if not provided?
- Should script support multiple input flags or single JSON input?
- Should script validate workflow exists before dispatch?

### GH-15. Workflow correlation with REST API

**Requirement**: Validate GH-3 (Workflow correlation) using pure REST API with curl. Use `GET /repos/{owner}/{repo}/actions/runs` with filtering to retrieve run_id after workflow dispatch. The implementation should support UUID-based correlation, handle pagination using Link headers, filter by workflow, branch, actor, and status, and provide proper error handling. Use token authentication from `./secrets` directory.

**API Endpoint**: `GET /repos/{owner}/{repo}/actions/runs`

**Key Capabilities Required**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- UUID-based correlation filtering via run-name matching
- Polling mechanism with configurable timeout and interval
- Workflow and branch filtering support
- Metadata storage support (`--store-dir`)
- Repository auto-detection from git context
- Comprehensive error handling

**Current Implementation (GH-3)**:
- Uses `gh run list --workflow dispatch-webhook.yml --json databaseId,name,headBranch,createdAt,status`
- Filters using jq: timestamp, branch match, status in `queued`/`in_progress`, run-name contains correlation token
- Polling with 3-second interval, 60-second timeout

**REST API Requirements**:
- Use `GET /repos/{owner}/{repo}/actions/runs` with filtering
- Support UUID-based correlation (filter by run-name containing correlation_id)
- Handle pagination using Link headers
- Filter by:
  - Workflow (workflow_id or workflow file path)
  - Branch (head_branch)
  - Actor (actor)
  - Status (status: queued, in_progress, completed)
- Provide proper error handling
- Use token authentication from `./secrets` directory

**Pattern Reference**: Follow Sprint 9's pagination handling and filtering approach.

**Integration Points**:
- Compatible with existing correlation mechanism (UUID in run-name)
- Reuse `runs/<correlation_id>/metadata.json` format
- Compatible with existing `scripts/lib/run-utils.sh` utilities
- Support `--store-dir` and `--runs-dir` patterns

**Technical Considerations**:
- GitHub API supports filtering by workflow_id, head_branch, actor, status
- Pagination via Link headers (RFC 5988) or page/per_page query params
- Run-name filtering requires parsing API response with jq
- Polling loop needed to wait for workflow to appear in API
- Typical correlation time: 2-5 seconds (from Sprint 1 benchmarks)

**Open Questions**:
- Should script support pagination for repositories with many runs?
- Should script filter by actor to improve correlation accuracy?
- Should script support watch mode (continuous polling until completion)?

### GH-16. Fetch logs with REST API

**Requirement**: Validate GH-5 (Workflow log access after run) using pure REST API endpoints. Use `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` to retrieve workflow execution logs. The implementation should handle log streaming and aggregation, support multiple jobs per workflow run, handle authentication with token from `./secrets` directory, and provide proper error handling for scenarios such as logs not yet available or invalid job IDs.

**API Endpoint**: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs` (run-level, matches GH-5)
**Alternative Endpoint**: `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` (job-level, mentioned in requirement)

**Key Capabilities Required**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- Run completion validation before download
- ZIP archive download and extraction
- Structured log organization (`logs/<job_name>/step.log`)
- Combined log generation (`combined.log`)
- Metadata JSON generation (`logs.json`)
- Repository auto-detection from git context
- Comprehensive error handling

**Current Implementation (GH-5)**:
- Uses `gh api repos/:owner/:repo/actions/runs/:run_id/logs` to download ZIP archive
- Validates run is completed before download
- Extracts logs to structured directories
- Produces combined.log and logs.json metadata

**REST API Requirements**:
- Use `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs` to retrieve workflow execution logs
- Handle log streaming and aggregation
- Support multiple jobs per workflow run
- Handle authentication with token from `./secrets` directory
- Provide proper error handling for:
  - Logs not yet available (404 during run)
  - Invalid job IDs (404)
  - Expired logs (410)
  - Authentication failures (401/403)

**Note**: The requirement mentions `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`, but the current implementation uses `/actions/runs/{run_id}/logs`. Decision: Use run-level API (matches GH-5 implementation, simpler, single API call).

**Pattern Reference**: Follow Sprint 9's HTTP handling and error reporting patterns.

**Integration Points**:
- Compatible with existing log extraction logic from Sprint 3
- Same output structure (combined.log, logs.json)
- Compatible with existing log processing scripts
- Reuse log extraction and aggregation logic from Sprint 3

**Technical Considerations**:
- GitHub API provides ZIP archive with all job logs
- Logs only available after run completion
- Log retention policy: logs expire after certain period (HTTP 410)
- Multiple jobs per workflow run aggregated in single ZIP
- Job-level API requires listing jobs first, then fetching each job's logs (more complex)

**Open Questions**:
- Should script use run-level API (simpler) or job-level API (per-job access)?
- Should script support incremental log retrieval (if available)?
- Should script validate log availability before download?

## Project History Context

### Completed Sprints (Relevant Patterns)

**Sprint 1 - Workflow Triggering and Correlation** (GH-2, GH-3):
- `.github/workflows/dispatch-webhook.yml` - Reusable workflow with webhook notifications
- `scripts/trigger-and-track.sh` - UUID-based correlation mechanism using `gh workflow run` and `gh run list`
- `scripts/notify-webhook.sh` - Webhook POST with retry policy
- Storage: `runs/<correlation_id>/metadata.json`
- Key pattern: UUID correlation token passed as workflow input, embedded in run-name for searchability
- Polling mechanism: `gh run list --json` + jq filtering (timestamp, branch, status, run-name match)

**Sprint 3 - Post-Run Log Retrieval** (GH-5):
- `scripts/fetch-run-logs.sh` - Log download using `gh api repos/:owner/:repo/actions/runs/:run_id/logs`
- `scripts/lib/run-utils.sh` - Shared metadata utilities
- Storage: `runs/<correlation_id>/logs/` with combined.log and logs.json
- Key pattern: Download ZIP archive, extract to structured directories, produce combined transcript

**Sprint 9 - REST API Pattern** (GH-12, curl implementation):
- `scripts/view-run-jobs-curl.sh` - curl-based companion to Sprint 8's gh CLI viewer
- Token authentication from `./secrets/github_token` (or `./secrets/token`)
- HTTP handling: bearer token headers, GitHub API version pinning, retry/backoff
- Repository resolution: CLI flag → `GITHUB_REPOSITORY` env → git remote parsing
- Normalized REST responses into same data shape as gh CLI variant
- Key pattern: Pure curl with comprehensive error handling, no gh CLI dependency

### Failed Sprints (Lessons Learned)

**Sprint 2 - Real-time Log Streaming** (GH-4):
- Failed due to GitHub API limitation - no streaming API available for in-progress workflow logs

**Sprint 6 - Job-level Logs API** (GH-10):
- Failed to validate incremental log retrieval via jobs API

**Sprint 7 - Webhook-based Correlation** (GH-11):
- Failed due to requirement for publicly accessible endpoint

**Sprint 10 - Workflow Output Data** (GH-13):
- Failed due to GitHub REST API limitations - workflows cannot return synchronous data structures

**Sprint 12 - Schedule Workflows** (GH-8, GH-9):
- Failed - GitHub does not provide native scheduling for workflow_dispatch events

## Established Patterns to Reuse

### 1. Token Authentication Pattern (Sprint 9)

**Token File Approach**:
```bash
load_token() {
  local token_file="$1"
  if [[ ! -f "$token_file" ]]; then
    printf 'Error: Token file not found: %s\n' "$token_file" >&2
    exit 1
  fi
  if [[ ! -r "$token_file" ]]; then
    printf 'Error: Token file not readable: %s\n' "$token_file" >&2
    exit 1
  fi
  warn_token_permissions "$token_file"
  local token
  token="$(tr -d '[:space:]' <"$token_file")"
  if [[ -z "$token" ]]; then
    printf 'Error: Token file is empty: %s\n' "$token_file" >&2
    exit 1
  fi
  printf '%s' "$token"
}
```

**Token File Locations**:
- Default: `./secrets/github_token`
- Alternative: `./secrets/token`
- Custom: `--token-file <path>`

**Security Considerations**:
- Warn about file permissions (should be 600)
- Never leak token in error messages
- Validate token file exists and is readable

### 2. Repository Resolution Pattern (Sprint 9)

**Auto-detection Priority**:
1. CLI flag (`--repo owner/repo`)
2. Environment variable (`GITHUB_REPOSITORY`)
3. Git remote parsing (`git config --get remote.origin.url`)

**Implementation**:
```bash
resolve_repository() {
  if [[ -n "$REPO" ]]; then
    local cleaned
    cleaned="$(normalize_repo "$REPO")"
    validate_repo_format "$cleaned"
    printf '%s' "$cleaned"
    return 0
  fi

  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    local cleaned_env
    cleaned_env="$(normalize_repo "$GITHUB_REPOSITORY")"
    validate_repo_format "$cleaned_env"
    printf '%s' "$cleaned_env"
    return 0
  fi

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local remote_url
    remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"
    if [[ -n "$remote_url" ]]; then
      local parsed
      parsed="$(parse_github_url "$remote_url")"
      validate_repo_format "$parsed"
      printf '%s' "$parsed"
      return 0
    fi
  fi

  printf 'Error: Unable to determine repository. Use --repo owner/repo or set GITHUB_REPOSITORY.\n' >&2
  exit 1
}
```

### 3. HTTP Handling Pattern (Sprint 9)

**curl API Call with Error Handling**:
```bash
api_request() {
  local url="$1"
  local token="$2"
  curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$url" || printf '\n000'
}

handle_http_error() {
  local http_code="$1"
  local body="$2"
  case "$http_code" in
    401)
      printf 'Error: Authentication failed. Check token permissions.\n' >&2
      exit 1
      ;;
    403)
      printf 'Error: Insufficient permissions or rate limit exceeded.\n' >&2
      exit 1
      ;;
    404)
      printf 'Error: Resource not found.\n' >&2
      exit 1
      ;;
    410)
      printf 'Error: Resource expired or deleted.\n' >&2
      exit 1
      ;;
    422)
      printf 'Error: Validation failed.\n' >&2
      echo "$body" | jq -r '.message // "Unknown error"' >&2
      exit 1
      ;;
    5*)
      printf 'Error: Server error (HTTP %s). Retry may succeed.\n' "$http_code" >&2
      exit 1
      ;;
  esac
}
```

**Error Handling**:
- HTTP 401: Authentication failure
- HTTP 403: Permission denied or rate limit exceeded
- HTTP 404: Resource not found
- HTTP 410: Resource expired/deleted
- HTTP 422: Validation error (invalid inputs)
- HTTP 5xx: Transient server errors (retry with backoff)

### 4. Compatibility Requirements

**CLI Interface Consistency**:
- Maintain same CLI flags and options as gh CLI versions
- Support same input methods: `--run-id`, `--correlation-id`, stdin JSON
- Output format compatibility (JSON, table, verbose)

**Metadata Storage**:
- Reuse `runs/<correlation_id>/metadata.json` format
- Compatible with existing `scripts/lib/run-utils.sh` utilities
- Support `--store-dir` and `--runs-dir` patterns

**Workflow Compatibility**:
- Must work with existing `.github/workflows/dispatch-webhook.yml`
- Support same workflow inputs (webhook_url, correlation_id)
- Compatible with existing correlation mechanism (UUID in run-name)

## Technical Approach Analysis

### Selected Approach: REST API with curl (Sprint 9 Pattern)

**Rationale**:
- Full control over API parameters (matches requirement)
- Consistent with Sprint 9 approach
- More flexible for automation
- Better error handling and validation
- Direct access to API endpoints without gh CLI dependency

### Implementation Strategy

**Shared Components**:
- Token loading function (reuse from Sprint 9)
- Repository resolution function (reuse from Sprint 9)
- HTTP error handling function (reuse from Sprint 9)
- API request wrapper (reuse from Sprint 9)

**Script-Specific Components**:
- GH-14: Workflow ID resolution, dispatch request body building
- GH-15: Polling loop, correlation filtering, pagination handling
- GH-16: Run completion validation, log download, extraction logic

### Feasibility Assessment

**GitHub API Capabilities Verified**:
- ✅ GH-14: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` endpoint available
- ✅ GH-15: `GET /repos/{owner}/{repo}/actions/runs` endpoint available with filtering
- ✅ GH-16: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs` endpoint available

**Authentication**:
- ✅ Token file pattern established (Sprint 9)
- ✅ Bearer token authentication supported
- ✅ Required permissions: Actions: Write/Read

**No Platform Limitations Identified**:
- All required APIs available
- All required operations supported
- No GitHub API limitations blocking implementation

## Expected Deliverables

**Scripts**:
- `scripts/trigger-workflow-curl.sh` - REST API workflow triggering (GH-14)
- `scripts/correlate-workflow-curl.sh` - REST API workflow correlation (GH-15)
- `scripts/fetch-logs-curl.sh` - REST API log retrieval (GH-16)

**Documentation**:
- `progress/sprint_15_design.md` - Design document
- `progress/sprint_15_implementation.md` - Implementation notes
- Script help documentation (inline `--help`)

**Testing**:
- Static validation (shellcheck, actionlint)
- Manual test matrix (requires GitHub repository access)
- Integration tests with existing scripts

## Integration Points

**With Sprint 1 (GH-2, GH-3)**:
- Compatible CLI interface
- Same correlation mechanism (UUID in run-name)
- Compatible metadata storage format
- Can be used as drop-in replacement

**With Sprint 3 (GH-5)**:
- Compatible log extraction logic
- Same output structure (combined.log, logs.json)
- Compatible with existing log processing scripts

**With Sprint 9 (REST API Pattern)**:
- Reuse token authentication patterns
- Reuse repository resolution patterns
- Reuse HTTP handling patterns
- Consistent error handling approach

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

Sprint 15 analysis is successful when:

1. ✅ All three backlog items analyzed comprehensively
2. ✅ Project history reviewed and patterns identified
3. ✅ Technical approach selected and justified
4. ✅ Feasibility confirmed (no platform limitations)
5. ✅ Integration points documented
6. ✅ Risks identified with mitigation strategies
7. ✅ Expected deliverables defined
8. ✅ Ready to proceed to Elaboration phase

## Next Steps

1. **Elaboration Phase**: Create detailed design document (`progress/sprint_15_design.md`)
2. **Design Approval**: Wait for Product Owner approval before construction
3. **Construction Phase**: Implement scripts following established patterns
4. **Testing**: Execute test matrix with GitHub repository access

## Analysis Artifacts

**Created Files**:
- `progress/sprint_15_analysis.md` - This comprehensive analysis document

**Referenced Files**:
- Sprint 1, 3, 9 documentation for pattern identification
- Previous sprint design/implementation documents for context
- GitHub API documentation for endpoint verification

**Status**: ✅ Analysis Complete - Ready for Elaboration Phase

