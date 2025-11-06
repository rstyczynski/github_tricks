# Sprint 16 - Analysis

**Date**: 2025-01-27
**Sprint**: 16
**Status**: Analysis Complete
**Backlog Items**: GH-23

## Executive Summary

Sprint 16 extends workflow management capabilities with artifact listing operations. This sprint implements REST API-based artifact listing using curl, following the pattern established in Sprint 15. The implementation uses token authentication from `./secrets` directory, handles pagination, supports filtering by artifact name, and provides comprehensive error handling. This sprint complements existing workflow log retrieval features by enabling discovery of artifacts produced by workflows.

## Backlog Items Analysis

### GH-23. List workflow artifacts

**Requirement**: List artifacts produced by a workflow run using REST API. This feature enables querying artifacts associated with a specific workflow run, filtering by artifact name, and retrieving artifact metadata including size, creation date, and expiration date. The implementation should handle authentication with token from `./secrets` directory, support pagination for runs with many artifacts, and provide proper error handling for scenarios such as invalid run IDs or expired artifacts.

**API Endpoint**: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`

**Key Capabilities Required**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- List artifacts for a specific workflow run
- Support filtering by artifact name
- Retrieve artifact metadata:
  - Artifact ID
  - Artifact name
  - Size (in bytes)
  - Creation date
  - Expiration date
  - Archive download URL
- Handle pagination for runs with many artifacts
- Repository auto-detection from git context
- Comprehensive error handling for:
  - Invalid run IDs (404)
  - Authentication failures (401/403)
  - Expired artifacts (410)
  - Artifacts not yet available

**Current Implementation Context**:
- No existing artifact listing implementation in project
- Sprint 15 established REST API pattern with curl
- Artifacts are created by workflows but not yet accessed programmatically
- Artifact download (GH-24) and deletion (GH-25) are planned for future sprints

**REST API Requirements**:
- Use `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts` endpoint
- Handle authentication with token from `./secrets` directory
- Support pagination using Link headers or page/per_page query params
- Filter artifacts by name (client-side filtering after API response)
- Provide proper error handling for:
  - Invalid run IDs (404)
  - Authentication failures (401/403)
  - Expired artifacts (410)
  - Artifacts not yet available

**Pattern Reference**: Follow Sprint 15's REST API pattern:
- Token loading from `./secrets/github_token` or `./secrets/token`
- Repository resolution (CLI flag → env → git remote)
- HTTP error handling with descriptive messages
- Bearer token authentication headers
- Pagination handling via Link headers

**Integration Points**:
- Must work with existing workflow runs (Sprint 1, Sprint 15)
- Compatible with run_id from correlation mechanism (GH-3, GH-15)
- Prepares foundation for artifact download (GH-24) and deletion (GH-25)
- Can be used with existing log retrieval scripts (GH-5, GH-16)

**Technical Considerations**:
- GitHub API returns paginated list of artifacts
- Artifacts are associated with workflow runs, not individual jobs
- Artifact metadata includes download URL (for future GH-24 implementation)
- Artifacts expire after retention period (default: 90 days)
- Pagination needed for runs with many artifacts (>30 artifacts)
- Filtering by name requires client-side filtering (API doesn't support name filter)

**Open Questions**:
- Should script support listing artifacts for multiple runs?
- Should script support filtering by artifact size or expiration date?
- Should script output include download URLs for automation?

## Project History Context

### Completed Sprints (Relevant Patterns)

**Sprint 1 - Workflow Triggering and Correlation** (GH-2, GH-3):
- `.github/workflows/dispatch-webhook.yml` - Reusable workflow with webhook notifications
- `scripts/trigger-and-track.sh` - UUID-based correlation mechanism
- Storage: `runs/<correlation_id>/metadata.json`
- Key pattern: UUID correlation token, run-name matching

**Sprint 3 - Post-Run Log Retrieval** (GH-5):
- `scripts/fetch-run-logs.sh` - Log download using `gh api`
- Storage: `runs/<correlation_id>/logs/` with combined.log and logs.json
- Key pattern: Download ZIP archive, extract to structured directories

**Sprint 9 - REST API Pattern** (GH-12, curl implementation):
- `scripts/view-run-jobs-curl.sh` - curl-based companion to gh CLI viewer
- Token authentication from `./secrets/github_token` (or `./secrets/token`)
- HTTP handling: bearer token headers, GitHub API version pinning
- Repository resolution: CLI flag → `GITHUB_REPOSITORY` env → git remote parsing
- Key pattern: Pure curl with comprehensive error handling

**Sprint 15 - REST API Workflow Validation** (GH-14, GH-15, GH-16):
- `scripts/trigger-workflow-curl.sh` - REST API workflow triggering
- `scripts/correlate-workflow-curl.sh` - REST API workflow correlation
- `scripts/fetch-logs-curl.sh` - REST API log retrieval
- Established pattern: Token auth, repository resolution, HTTP error handling
- Compatible CLI interfaces, JSON output support

### Failed Sprints (Lessons Learned)

**Sprint 2 - Real-time Log Streaming** (GH-4):
- Failed due to GitHub API limitation - no streaming API available

**Sprint 6 - Job-level Logs API** (GH-10):
- Failed to validate incremental log retrieval via jobs API

**Sprint 7 - Webhook-based Correlation** (GH-11):
- Failed due to requirement for publicly accessible endpoint

**Sprint 10 - Workflow Output Data** (GH-13):
- Failed due to GitHub REST API limitations - job outputs not exposed

**Sprint 12 - Schedule Workflows** (GH-8, GH-9):
- Failed - GitHub does not provide native scheduling for workflow_dispatch events

## Established Patterns to Reuse

### 1. Token Authentication Pattern (Sprint 9, Sprint 15)

**Token File Approach**:
- Load token from `./secrets/github_token` (default) or `./secrets/token`
- Validate file exists, readable, non-empty
- Warn about permissions (should be 600)
- Never leak token in error messages

### 2. Repository Resolution Pattern (Sprint 9, Sprint 15)

**Auto-detection Priority**:
1. CLI flag (`--repo owner/repo`)
2. Environment variable (`GITHUB_REPOSITORY`)
3. Git remote parsing (`git config --get remote.origin.url`)

### 3. HTTP Handling Pattern (Sprint 9, Sprint 15)

**curl API Call with Error Handling**:
- Bearer token headers: `Authorization: Bearer <token>`
- GitHub API version pinning: `X-GitHub-Api-Version: 2022-11-28`
- Accept header: `Accept: application/vnd.github+json`
- HTTP error handling for 401, 403, 404, 410, 422, 5xx

### 4. Pagination Handling Pattern (Sprint 9, Sprint 15)

**Pagination Support**:
- Parse Link headers for pagination
- Support `--paginate` flag for multi-page results
- Handle `rel="next"` links
- Default: fetch first page only (30 items)

### 5. Run ID Resolution Pattern (Sprint 15)

**Input Priority**:
1. `--run-id` flag (direct numeric ID)
2. `--correlation-id` flag (load from metadata)
3. Stdin JSON (for automation)

## Technical Approach Analysis

### Selected Approach: REST API with curl (Sprint 15 Pattern)

**Rationale**:
- Full control over API parameters
- Consistent with Sprint 15 approach
- More flexible for automation
- Better error handling and validation
- Direct access to API endpoints without gh CLI dependency

### Implementation Strategy

**Shared Components** (reuse from Sprint 15):
- Token loading function
- Repository resolution function
- HTTP error handling function
- API request wrapper
- Pagination handling

**Script-Specific Components**:
- Run ID resolution (from correlation_id or direct input)
- Artifact listing API call
- Artifact name filtering (client-side)
- Metadata extraction and formatting
- Output formatting (human-readable and JSON)

### Feasibility Assessment

**GitHub API Capabilities Verified**:
- ✅ `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts` endpoint available
- ✅ Returns paginated list of artifacts
- ✅ Artifact metadata includes: id, name, size_in_bytes, created_at, expires_at, archive_download_url
- ✅ Supports pagination via Link headers

**Authentication**:
- ✅ Token file pattern established (Sprint 9, Sprint 15)
- ✅ Bearer token authentication supported
- ✅ Required permissions: Actions: Read

**No Platform Limitations Identified**:
- All required APIs available
- All required operations supported
- No GitHub API limitations blocking implementation

## Expected Deliverables

**Scripts**:
- `scripts/list-artifacts-curl.sh` - REST API artifact listing (GH-23)

**Documentation**:
- `progress/sprint_16_design.md` - Design document
- `progress/sprint_16_implementation.md` - Implementation notes
- Script help documentation (inline `--help`)

**Testing**:
- Static validation (shellcheck)
- Manual test matrix (requires GitHub repository access)
- Integration tests with existing scripts

## Integration Points

**With Sprint 1 (GH-2, GH-3)**:
- Compatible with correlation mechanism (UUID in run-name)
- Can use run_id from correlation scripts

**With Sprint 3 (GH-5)**:
- Complements log retrieval with artifact discovery
- Can be used together to get complete workflow output

**With Sprint 15 (GH-14, GH-15, GH-16)**:
- Follows same REST API pattern
- Reuses token authentication and repository resolution
- Compatible CLI interface style
- Can use run_id from correlation scripts

**With Future Sprints**:
- Prepares foundation for artifact download (GH-24)
- Prepares foundation for artifact deletion (GH-25)

## Risks and Mitigations

### Risk 1: Artifact Availability Timing

**Risk**: Artifacts may not be immediately available after run completion
**Impact**: Listing fails even though artifacts exist
**Mitigation**: Validate run completion before listing, retry logic for 404 errors

### Risk 2: Pagination Complexity

**Risk**: Runs with many artifacts require pagination handling
**Impact**: Script fails to list all artifacts
**Mitigation**: Implement pagination handling via Link headers, support `--paginate` flag

### Risk 3: Artifact Expiration

**Risk**: Artifacts expire after retention period (default: 90 days)
**Impact**: Listing succeeds but artifacts are expired
**Mitigation**: Display expiration date in output, handle 410 errors gracefully

### Risk 4: API Rate Limiting

**Risk**: High-frequency API calls may hit rate limits
**Impact**: HTTP 403 errors
**Mitigation**: Use reasonable API call frequency, handle 403 responses gracefully

### Risk 5: Token Permissions

**Risk**: Token may lack required Actions permissions
**Impact**: HTTP 403 errors
**Mitigation**: Document required permissions, provide clear error messages

## Success Criteria

Sprint 16 analysis is successful when:

1. ✅ Backlog item analyzed comprehensively
2. ✅ Project history reviewed and patterns identified
3. ✅ Technical approach selected and justified
4. ✅ Feasibility confirmed (no platform limitations)
5. ✅ Integration points documented
6. ✅ Risks identified with mitigation strategies
7. ✅ Expected deliverables defined
8. ✅ Ready to proceed to Elaboration phase

## Next Steps

1. **Elaboration Phase**: Create detailed design document (`progress/sprint_16_design.md`)
2. **Design Approval**: Wait for Product Owner approval before construction
3. **Construction Phase**: Implement script following established patterns
4. **Testing**: Execute test matrix with GitHub repository access

## Analysis Artifacts

**Created Files**:
- `progress/sprint_16_analysis.md` - This comprehensive analysis document

**Referenced Files**:
- Sprint 1, 3, 9, 15 documentation for pattern identification
- Previous sprint design/implementation documents for context
- GitHub API documentation for endpoint verification

**Status**: ✅ Analysis Complete - Ready for Elaboration Phase

