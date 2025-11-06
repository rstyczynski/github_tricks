# Inception Review – Sprint 16 (Chat 1)

Date: 2025-01-27
Sprint: Sprint 16
Backlog Items: GH-23
Status: Inception phase completed

## Context

Product Owner initiated Sprint 16 inception for artifact listing operations. Sprint 16 aims to extend workflow management capabilities with artifact listing operations using pure REST API with curl, following the pattern established in Sprint 15.

## Sprint Status Review

From PLAN.md Implementation Plan:
- **Sprint 16**: Progress (List workflow artifacts - GH-23)
- **Sprint 17**: Proposed (Download workflow artifacts - GH-24)
- **Sprint 18**: Proposed (Delete workflow artifacts - GH-25)

## Project History Summary

### Successful Deliverables (Relevant Sprints)

**Sprint 1** - Workflow triggering and correlation (GH-2, GH-3):
- `.github/workflows/dispatch-webhook.yml` - Reusable workflow with webhook notifications
- `scripts/trigger-and-track.sh` - UUID-based correlation mechanism
- Storage: `runs/<correlation_id>/metadata.json`
- Key pattern: UUID correlation token, run-name matching

**Sprint 3** - Post-run log retrieval (GH-5):
- `scripts/fetch-run-logs.sh` - Log download using `gh api`
- Storage: `runs/<correlation_id>/logs/` with combined.log and logs.json
- Key pattern: Download ZIP archive, extract to structured directories

**Sprint 9** - REST API pattern (GH-12, curl implementation):
- `scripts/view-run-jobs-curl.sh` - curl-based companion to gh CLI viewer
- Token authentication from `./secrets/github_token` (or `./secrets/token`)
- HTTP handling: bearer token headers, GitHub API version pinning
- Repository resolution: CLI flag → `GITHUB_REPOSITORY` env → git remote parsing
- Key pattern: Pure curl with comprehensive error handling

**Sprint 15** - REST API workflow validation (GH-14, GH-15, GH-16):
- `scripts/trigger-workflow-curl.sh` - REST API workflow triggering
- `scripts/correlate-workflow-curl.sh` - REST API workflow correlation
- `scripts/fetch-logs-curl.sh` - REST API log retrieval
- Established pattern: Token auth, repository resolution, HTTP error handling
- Compatible CLI interfaces, JSON output support

## Sprint 16 Requirements Analysis

### GH-23. List workflow artifacts

**Objective**: List artifacts produced by a workflow run using REST API.

**Requirement Details**:
- Enable querying artifacts associated with a specific workflow run
- Support filtering by artifact name
- Retrieve artifact metadata including size, creation date, and expiration date
- Handle authentication with token from `./secrets` directory
- Support pagination for runs with many artifacts
- Provide proper error handling for scenarios such as invalid run IDs or expired artifacts

**API Endpoint**: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`

**Key Capabilities Required**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- List artifacts for a specific workflow run
- Support filtering by artifact name (client-side filtering)
- Retrieve artifact metadata:
  - Artifact ID
  - Artifact name
  - Size (in bytes)
  - Creation date
  - Expiration date
  - Archive download URL
- Handle pagination for runs with many artifacts
- Repository auto-detection from git context
- Comprehensive error handling

**Pattern Reference**: Follow Sprint 15's REST API pattern:
- Token loading from `./secrets/github_token` or `./secrets/token`
- Repository resolution (CLI flag → env → git remote)
- HTTP error handling with descriptive messages
- Bearer token authentication headers
- Pagination handling via Link headers

**Integration Points**:
- Compatible with run_id from correlation mechanism (GH-3, GH-15)
- Complements log retrieval features (GH-5, GH-16)
- Prepares foundation for artifact download (GH-24) and deletion (GH-25)

## Technical Context and Patterns

### Established Patterns from Sprint 15

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
- GitHub API version pinning: `X-GitHub-Api-Version: 2022-11-28`
- Accept header: `Accept: application/vnd.github+json`
- Descriptive errors for 401/403/404/410 cases
- Never leak token contents in errors

**4. Error Handling**:
- HTTP 401: Authentication failure
- HTTP 403: Permission denied or rate limit exceeded
- HTTP 404: Resource not found (invalid run_id)
- HTTP 410: Resource expired/deleted (expired artifacts)
- HTTP 422: Validation error
- HTTP 5xx: Transient server errors (retry with backoff)

**5. Pagination**:
- Parse Link headers for pagination
- Support `--paginate` flag for multi-page results
- Handle `rel="next"` links
- Default: fetch first page only (30 items)

**6. Run ID Resolution**:
- Input priority: `--run-id` → `--correlation-id` → stdin JSON
- Load run_id from metadata if using correlation_id
- Validate run_id format (numeric)

### Compatibility Requirements

**1. CLI Interface Consistency**:
- Maintain same CLI flags and options style as Sprint 15 scripts
- Support same input methods: `--run-id`, `--correlation-id`
- Output format compatibility (JSON, table, verbose)

**2. Metadata Storage**:
- Compatible with existing `runs/<correlation_id>/metadata.json` format
- Can use run_id from correlation scripts

**3. Workflow Compatibility**:
- Works with any workflow run that produces artifacts
- No dependency on specific workflow structure

## Questions and Clarifications

**1. Artifact Name Filtering**:
- API doesn't support server-side filtering by name
- Should we implement client-side filtering (jq-based)?
- Should we support partial name matching or exact match only?

**2. Output Format**:
- Should script produce table format (human-readable) and JSON format?
- Should JSON output include download URLs for automation?
- Should we support filtering output by artifact name?

**3. Pagination**:
- Should script fetch all pages by default or require `--paginate` flag?
- Should we limit maximum number of pages to prevent excessive API calls?

**4. Integration with Future Sprints**:
- Should script output format be compatible with artifact download script (GH-24)?
- Should script output format be compatible with artifact deletion script (GH-25)?

## Summary

Sprint 16 extends workflow management capabilities with artifact listing operations using pure REST API with curl, following the successful pattern established in Sprint 15. The implementation should:

1. **Maintain Compatibility**: Work with existing workflow runs, correlation mechanism, and CLI interfaces
2. **Follow Patterns**: Use Sprint 15's token authentication, repository resolution, HTTP handling patterns
3. **Provide Error Handling**: Comprehensive error handling for all failure scenarios
4. **Support Automation**: JSON output for scripting and automation use cases
5. **Handle Pagination**: Support pagination for runs with many artifacts
6. **Filter Artifacts**: Support filtering by artifact name (client-side)

**Key Deliverables**:
- `scripts/list-artifacts-curl.sh` - REST API artifact listing (GH-23)
- Script uses token authentication from `./secrets` directory
- Script provides comprehensive error handling
- Script supports pagination and artifact name filtering
- Script maintains compatibility with existing scripts

**Status**: Ready to proceed to Elaboration phase.

