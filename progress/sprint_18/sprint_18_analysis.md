# Sprint 18 - Analysis

**Date**: 2025-01-27
**Sprint**: 18
**Status**: Analysis Complete
**Backlog Items**: GH-25

## Executive Summary

Sprint 18 extends workflow management capabilities with artifact deletion operations. This sprint implements REST API-based artifact deletion using curl, following the pattern established in Sprint 15 and completing the artifact management lifecycle (list, download, delete) initiated in Sprints 16 and 17. The implementation uses token authentication from `./secrets` directory, supports deleting individual artifacts or all artifacts for a run, validates deletion permissions, and provides comprehensive error handling for scenarios such as artifacts already deleted or insufficient permissions.

## Backlog Items Analysis

### GH-25. Delete workflow artifacts

**Requirement**: Delete artifacts from a workflow run using REST API. This feature enables cleanup of artifacts to manage repository storage and comply with retention policies. The implementation should handle authentication with token from `./secrets` directory, support deleting individual artifacts or all artifacts for a run, validate deletion permissions, and provide proper error handling for scenarios such as artifacts already deleted or insufficient permissions.

**API Endpoint**: `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`

**Key Capabilities Required**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- Delete individual artifact by artifact_id
- Delete all artifacts for a specific workflow run
- Validate deletion permissions before attempting deletion
- Repository auto-detection from git context
- Comprehensive error handling for:
  - Invalid artifact IDs (404)
  - Authentication failures (401/403)
  - Insufficient permissions (403)
  - Artifacts already deleted (404)
  - Artifacts not yet available

**Current Implementation Context**:
- Sprint 17 implemented artifact download (GH-24)
- Sprint 16 implemented artifact listing (GH-23)
- Sprint 15 established REST API pattern with curl
- No existing artifact deletion implementation
- Artifact management lifecycle: List → Download → Delete (complete)

**REST API Requirements**:
- Use `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}` endpoint
- Handle authentication with token from `./secrets` directory
- Support deleting single artifact by artifact_id
- Support deleting all artifacts for a run_id (requires listing first)
- Provide proper error handling for:
  - Invalid artifact IDs (404)
  - Authentication failures (401/403)
  - Insufficient permissions (403)
  - Artifacts already deleted (404)

**Pattern Reference**: Follow Sprint 15's REST API pattern + Sprint 16/17's artifact management pattern:
- Token loading from `./secrets/github_token` or `./secrets/token`
- Repository resolution (CLI flag → env → git remote)
- HTTP error handling with descriptive messages
- Bearer token authentication headers
- Run ID resolution (for deleting all artifacts)
- Integration with Sprint 16's artifact listing for bulk operations

**Integration Points**:
- Must work with Sprint 16's artifact listing (GH-23) for bulk deletion
- Compatible with run_id from correlation mechanism (GH-3, GH-15)
- Completes artifact management lifecycle with Sprint 17's download (GH-24)
- Can be used with existing workflow runs (Sprint 1, Sprint 15)

**Technical Considerations**:
- GitHub API returns HTTP 204 (No Content) on successful deletion
- Deletion is permanent and cannot be undone
- Artifacts can only be deleted by users with write permissions
- Bulk deletion requires listing artifacts first (use Sprint 16's script)
- Deletion permissions are validated by GitHub API (403 if insufficient)
- Already deleted artifacts return 404 (idempotent behavior)

**Open Questions**:
- Should script confirm deletion before proceeding?
  - **Decision**: Provide `--confirm` flag for safety, default to requiring confirmation
- Should script support dry-run mode to preview deletions?
  - **Decision**: Yes, add `--dry-run` flag to list artifacts that would be deleted
- Should script preserve artifact metadata after deletion?
  - **Decision**: No, deletion is permanent and metadata should be removed
- Should script support filtering by artifact name when deleting all?
  - **Decision**: Yes, reuse name filtering pattern from Sprint 16/17

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

**Sprint 16 - Artifact Listing** (GH-23):
- `scripts/list-artifacts-curl.sh` - REST API artifact listing
- Lists artifacts for a workflow run
- Returns artifact metadata including artifact IDs
- Key pattern: Artifact discovery, metadata extraction
- **Direct integration point**: Provides artifact_ids for deletion

**Sprint 17 - Artifact Download** (GH-24):
- `scripts/download-artifact-curl.sh` - REST API artifact download
- Downloads single artifact or all artifacts for a run
- Supports ZIP extraction and metadata preservation
- Key pattern: Artifact retrieval, bulk operations
- **Complements deletion**: Complete artifact lifecycle

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

### 1. Token Authentication Pattern (Sprint 9, Sprint 15, Sprint 16, Sprint 17)

**Token File Approach**:
- Load token from `./secrets/github_token` (default) or `./secrets/token`
- Validate file exists, readable, non-empty
- Warn about permissions (should be 600)
- Never leak token in error messages

### 2. Repository Resolution Pattern (Sprint 9, Sprint 15, Sprint 16, Sprint 17)

**Auto-detection Priority**:
1. CLI flag (`--repo owner/repo`)
2. Environment variable (`GITHUB_REPOSITORY`)
3. Git remote parsing (`git config --get remote.origin.url`)

### 3. HTTP Handling Pattern (Sprint 9, Sprint 15, Sprint 16, Sprint 17)

**curl API Call with Error Handling**:
- Bearer token headers: `Authorization: Bearer <token>`
- GitHub API version pinning: `X-GitHub-Api-Version: 2022-11-28`
- Accept header: `Accept: application/vnd.github+json`
- HTTP error handling for 401, 403, 404, 410, 422, 5xx
- DELETE requests return 204 on success (no content)

### 4. Run ID Resolution Pattern (Sprint 15, Sprint 16, Sprint 17)

**Input Priority**:
1. `--run-id` flag (direct numeric ID)
2. `--correlation-id` flag (load from metadata)
3. Stdin JSON (for automation)

### 5. Artifact Discovery Pattern (Sprint 16)

**List Artifacts Integration**:
- Use `list-artifacts-curl.sh` to get artifact metadata
- Extract artifact_id from listing results
- Use artifact_id for deletion operations
- **Direct integration**: Sprint 18 can call Sprint 16's script for bulk deletion

### 6. Bulk Operations Pattern (Sprint 17)

**Multiple Artifact Handling**:
- List artifacts first (using Sprint 16's script)
- Iterate over artifact IDs
- Perform operation on each artifact
- Handle errors gracefully (continue on individual failures)
- Provide summary of operations

## Technical Approach Analysis

### Selected Approach: REST API with curl (Sprint 15/16/17 Pattern)

**Rationale**:
- Full control over deletion parameters
- Consistent with Sprint 15/16/17 approach
- More flexible for automation
- Better error handling and validation
- Direct access to API endpoints without gh CLI dependency
- Completes artifact management lifecycle

### Implementation Strategy

**Shared Components** (reuse from Sprint 15/16/17):
- Token loading function
- Repository resolution function
- HTTP error handling function
- API request wrapper
- Run ID resolution

**Script-Specific Components**:
- Artifact ID resolution (from artifact_id, run_id, or correlation_id)
- Deletion API call with proper HTTP method
- Bulk deletion loop (using Sprint 16's listing)
- Permission validation before deletion
- Confirmation prompt (optional, via flag)
- Dry-run mode (preview deletions without executing)
- Name filtering (reuse from Sprint 16/17)

### Feasibility Assessment

**GitHub API Capabilities Verified**:
- ✅ `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}` endpoint available
- ✅ Returns HTTP 204 (No Content) on successful deletion
- ✅ Returns HTTP 404 if artifact not found or already deleted
- ✅ Returns HTTP 403 if insufficient permissions
- ✅ Idempotent operation (safe to retry)

**Authentication**:
- ✅ Token file pattern established (Sprint 9, Sprint 15, Sprint 16, Sprint 17)
- ✅ Bearer token authentication supported
- ✅ Required permissions: Actions: Write (for deletion)

**Deletion Handling**:
- ✅ curl supports DELETE method (`-X DELETE`)
- ✅ HTTP 204 indicates success (no response body)
- ✅ Bulk deletion requires listing artifacts first (Sprint 16 integration)

**No Platform Limitations Identified**:
- All required APIs available
- All required operations supported
- No GitHub API limitations blocking implementation

## Expected Deliverables

**Scripts**:
- `scripts/delete-artifact-curl.sh` - Delete single artifact by artifact_id (GH-25)
- Support for bulk deletion via `--all` flag (uses Sprint 16's listing)

**Documentation**:
- `progress/sprint_18_design.md` - Design document
- `progress/sprint_18_implementation.md` - Implementation notes
- Script help documentation (inline `--help`)

**Testing**:
- Static validation (shellcheck)
- Manual test matrix (requires GitHub repository with workflow artifacts)
- Integration tests with Sprint 16 scripts
- Permission validation tests

## Integration Points

**With Sprint 16 (GH-23)**:
- ✅ Use artifact listing to discover artifact_ids for bulk deletion
- ✅ Can delete artifacts from listing results
- ✅ Pipeline: List → Filter → Delete

**With Sprint 17 (GH-24)**:
- ✅ Completes artifact lifecycle: List → Download → Delete
- ✅ Compatible CLI interface style
- ✅ Can use same artifact_ids

**With Sprint 15 (GH-14, GH-15, GH-16)**:
- ✅ Follows same REST API pattern
- ✅ Reuses token authentication and repository resolution
- ✅ Compatible CLI interface style
- ✅ Can use run_id from correlation scripts

**With Sprint 1 (GH-2, GH-3)**:
- ✅ Compatible with correlation mechanism (UUID in run-name)
- ✅ Can use run_id from correlation scripts

**Artifact Management Lifecycle**:
- ✅ **List** (Sprint 16): Discover artifacts
- ✅ **Download** (Sprint 17): Retrieve artifacts
- ✅ **Delete** (Sprint 18): Cleanup artifacts
- Complete lifecycle management for workflow artifacts

## Risks and Mitigations

### Risk 1: Accidental Deletion

**Risk**: Users may accidentally delete important artifacts
**Impact**: Permanent data loss
**Mitigation**: Require confirmation by default, provide `--confirm` flag, add `--dry-run` mode

### Risk 2: Permission Validation

**Risk**: Deletion may fail due to insufficient permissions
**Impact**: HTTP 403 errors, unclear error messages
**Mitigation**: Validate permissions before deletion, provide clear error messages, document required permissions

### Risk 3: Bulk Deletion Failures

**Risk**: Some artifacts may fail to delete in bulk operations
**Impact**: Partial deletion, unclear state
**Mitigation**: Continue on individual failures, provide summary of successes/failures, allow retry

### Risk 4: Already Deleted Artifacts

**Risk**: Attempting to delete already deleted artifacts
**Impact**: HTTP 404 errors, script failures
**Mitigation**: Handle 404 gracefully (idempotent operation), treat as success

### Risk 5: Rate Limiting

**Risk**: Bulk deletion may hit API rate limits
**Impact**: HTTP 403 errors, incomplete deletion
**Mitigation**: Add delays between deletions, handle rate limit errors gracefully, provide retry mechanism

### Risk 6: Integration with Sprint 16

**Risk**: Dependency on Sprint 16's listing script for bulk operations
**Impact**: Script fails if listing script unavailable
**Mitigation**: Document dependency, provide fallback to direct API calls, validate script availability

## Success Criteria

Sprint 18 analysis is successful when:

1. ✅ Backlog item analyzed comprehensively
2. ✅ Project history reviewed and patterns identified
3. ✅ Technical approach selected and justified
4. ✅ Feasibility confirmed (no platform limitations)
5. ✅ Integration points documented (especially Sprint 16 integration)
6. ✅ Risks identified with mitigation strategies
7. ✅ Expected deliverables defined
8. ✅ Ready to proceed to Elaboration phase

## Next Steps

1. **Elaboration Phase**: Create detailed design document (`progress/sprint_18_design.md`)
2. **Design Approval**: Wait for Product Owner approval before construction
3. **Construction Phase**: Implement script following established patterns
4. **Testing**: Execute test matrix with GitHub repository access and workflow artifacts

## Analysis Artifacts

**Created Files**:
- `progress/sprint_18_analysis.md` - This comprehensive analysis document

**Referenced Files**:
- Sprint 15, 16, 17 documentation for pattern identification
- Previous sprint design/implementation documents for context
- GitHub API documentation for endpoint verification

**Status**: ✅ Analysis Complete - Ready for Elaboration Phase

