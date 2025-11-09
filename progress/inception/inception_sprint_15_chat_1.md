# Inception Review – Sprint 15 (Chat 1)

Date: 2025-01-27
Sprint: Sprint 15
Backlog Items: GH-14, GH-15, GH-16
Status: Inception phase completed

## Context

Product Owner initiated Sprint 15 inception for REST API validation of existing workflow features. Sprint 15 aims to validate GH-2 (Trigger workflow), GH-3 (Workflow correlation), and GH-5 (Fetch logs) using pure REST API with curl instead of `gh` CLI, following the pattern established in Sprint 9.

## Sprint Status Review

From PLAN.md Implementation Plan:
- **Sprint 0**: Done (Prerequisites - GH-1)
- **Sprint 1**: Done (Trigger & Correlation - GH-2, GH-3)
- **Sprint 2**: Failed (Real-time logs - GH-4)
- **Sprint 3**: Done (Post-run logs - GH-5)
- **Sprint 4**: Done (Benchmarks - GH-3.1, GH-5.1)
- **Sprint 5**: Implemented (Project review & ecosystem analysis)
- **Sprint 6**: Failed (Job-level logs API - GH-10)
- **Sprint 7**: Failed (Webhook correlation - GH-11)
- **Sprint 8**: Done (Job phases with status - GH-12, gh CLI)
- **Sprint 9**: Done (Job phases with status - GH-12, curl implementation)
- **Sprint 10**: Failed (Workflow output data - GH-13)
- **Sprint 11**: Done (Cancel workflows - GH-6, GH-7)
- **Sprint 12**: Failed (Schedule workflows - GH-8, GH-9)
- **Sprint 13**: Done (PR Management - GH-17, GH-18, GH-19)
- **Sprint 14**: Done (PR Merge & Comments - GH-20, GH-22)
- **Sprint 15**: Proposed → Progress (REST API validation - GH-14, GH-15, GH-16)

## Project History Summary

### Successful Deliverables (Sprints 0-14)

**Sprint 1** - Workflow triggering and correlation (GH-2, GH-3):
- `.github/workflows/dispatch-webhook.yml` - Reusable workflow with webhook notifications
- `scripts/trigger-and-track.sh` - UUID-based correlation mechanism using `gh workflow run` and `gh run list`
- `scripts/notify-webhook.sh` - Webhook POST with retry policy
- Storage: `runs/<correlation_id>/metadata.json`
- Key pattern: UUID correlation token passed as workflow input, embedded in run-name for searchability
- Polling mechanism: `gh run list --json` + jq filtering (timestamp, branch, status, run-name match)

**Sprint 3** - Post-run log retrieval (GH-5):
- `scripts/fetch-run-logs.sh` - Log download using `gh api repos/:owner/:repo/actions/runs/:run_id/logs`
- `scripts/lib/run-utils.sh` - Shared metadata utilities
- Storage: `runs/<correlation_id>/logs/` with combined.log and logs.json
- Key pattern: Download ZIP archive, extract to structured directories, produce combined transcript

**Sprint 9** - REST API pattern (GH-12, curl implementation):
- `scripts/view-run-jobs-curl.sh` - curl-based companion to Sprint 8's gh CLI viewer
- Token authentication from `./secrets/github_token` (or `./secrets/token`)
- HTTP handling: bearer token headers, GitHub API version pinning, retry/backoff
- Repository resolution: CLI flag → `GITHUB_REPOSITORY` env → git remote parsing
- Normalized REST responses into same data shape as gh CLI variant
- Key pattern: Pure curl with comprehensive error handling, no gh CLI dependency

### Failed Sprints (Lessons Learned)

**Sprint 2** - Real-time log streaming (GH-4):
- Failed due to GitHub API limitation - no streaming API available for in-progress workflow logs

**Sprint 6** - Job-level logs API (GH-10):
- Failed to validate incremental log retrieval via jobs API

**Sprint 7** - Webhook-based correlation (GH-11):
- Failed due to requirement for publicly accessible endpoint

**Sprint 10** - Workflow output data (GH-13):
- Failed due to GitHub REST API limitations - workflows cannot return synchronous data structures

**Sprint 12** - Schedule workflows (GH-8, GH-9):
- Failed - GitHub does not provide native scheduling for workflow_dispatch events

## Sprint 15 Requirements Analysis

### GH-14. Trigger workflow with REST API

**Objective**: Validate GH-2 using pure REST API with curl instead of `gh` CLI.

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

### GH-15. Workflow correlation with REST API

**Objective**: Validate GH-3 using pure REST API with curl.

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

### GH-16. Fetch logs with REST API

**Objective**: Validate GH-5 using pure REST API endpoints.

**Current Implementation (GH-5)**:
- Uses `gh api repos/:owner/:repo/actions/runs/:run_id/logs` to download ZIP archive
- Validates run is completed before download
- Extracts logs to structured directories
- Produces combined.log and logs.json metadata

**REST API Requirements**:
- Use `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` to retrieve workflow execution logs
- Handle log streaming and aggregation
- Support multiple jobs per workflow run
- Handle authentication with token from `./secrets` directory
- Provide proper error handling for:
  - Logs not yet available (404 during run)
  - Invalid job IDs (404)
  - Expired logs (410)
  - Authentication failures (401/403)

**Note**: The requirement mentions `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`, but the current implementation uses `/actions/runs/{run_id}/logs`. Need to clarify:
- Should we use job-level logs API (per job) or run-level logs API (aggregated)?
- Current GH-5 uses run-level API which downloads all jobs in single ZIP
- Job-level API might provide per-job log access

**Pattern Reference**: Follow Sprint 9's HTTP handling and error reporting patterns.

## Technical Context and Patterns

### Established Patterns from Sprint 9

**1. Token Authentication**:
- Load token from `./secrets/github_token` or `./secrets/token`
- Validate file exists, readable, non-empty
- Warn about permissions (should be 600)
- Never leak token in error messages

**2. Repository Resolution**:
- Priority: CLI flag (`--repo`) → `GITHUB_REPOSITORY` env → git remote parsing
- Normalize format (remove .git suffix)
- Validate owner/repo format

**3. HTTP Handling**:
- Bearer token headers: `Authorization: Bearer <token>`
- GitHub API version pinning: `Accept: application/vnd.github.v3+json`
- Retry/backoff for transient 5xx/connection failures
- Descriptive errors for 401/403/404 cases
- Never leak token contents in errors

**4. Error Handling**:
- HTTP 401: Authentication failure
- HTTP 403: Permission denied
- HTTP 404: Resource not found
- HTTP 410: Resource expired/deleted
- HTTP 422: Validation error (invalid inputs)
- HTTP 5xx: Transient server errors (retry with backoff)

**5. Pagination**:
- Parse Link headers for pagination
- Support `--paginate` flag for multi-page results
- Handle `rel="next"` links

### Compatibility Requirements

**1. CLI Interface Consistency**:
- Maintain same CLI flags and options as gh CLI versions
- Support same input methods: `--run-id`, `--correlation-id`, stdin JSON
- Output format compatibility (JSON, table, verbose)

**2. Metadata Storage**:
- Reuse `runs/<correlation_id>/metadata.json` format
- Compatible with existing `scripts/lib/run-utils.sh` utilities
- Support `--store-dir` and `--runs-dir` patterns

**3. Workflow Compatibility**:
- Must work with existing `.github/workflows/dispatch-webhook.yml`
- Support same workflow inputs (webhook_url, correlation_id)
- Compatible with existing correlation mechanism (UUID in run-name)

## Questions and Clarifications

**1. Log Retrieval API (GH-16)**:
- Requirement mentions `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`
- Current GH-5 uses `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs`
- Should we:
  - Use job-level API (requires listing jobs first, then fetching each job's logs)?
  - Use run-level API (single ZIP with all jobs, matches current GH-5)?
  - Support both approaches?

**2. Token File Location**:
- Sprint 9 uses `./secrets/github_token` (default) or `./secrets/token`
- Should Sprint 15 follow same pattern?
- Should we support `--token-file` flag for flexibility?

**3. Output Format**:
- Should curl implementations produce identical output to gh CLI versions?
- Should we maintain JSON output for automation compatibility?

## Summary

Sprint 15 aims to validate existing workflow features (GH-2, GH-3, GH-5) using pure REST API with curl, following the successful pattern established in Sprint 9. The implementation should:

1. **Maintain Compatibility**: Work with existing workflows, metadata storage, and CLI interfaces
2. **Follow Patterns**: Use Sprint 9's token authentication, repository resolution, HTTP handling patterns
3. **Provide Error Handling**: Comprehensive error handling for all failure scenarios
4. **Support Automation**: JSON output for scripting and automation use cases

**Key Deliverables**:
- `scripts/trigger-workflow-curl.sh` - REST API workflow triggering (GH-14)
- `scripts/correlate-workflow-curl.sh` - REST API workflow correlation (GH-15)
- `scripts/fetch-logs-curl.sh` - REST API log retrieval (GH-16)
- All scripts use token authentication from `./secrets` directory
- All scripts provide comprehensive error handling
- All scripts maintain compatibility with existing gh CLI implementations

**Status**: Ready to proceed to Elaboration phase.

