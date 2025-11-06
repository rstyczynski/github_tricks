# Sprint 17 - Analysis

**Date**: 2025-11-06
**Sprint**: 17
**Status**: Analysis Complete
**Backlog Items**: GH-24

## Executive Summary

Sprint 17 extends workflow management capabilities with artifact download operations. This sprint implements REST API-based artifact download using curl, following the pattern established in Sprint 15 and building upon Sprint 16's artifact listing feature. The implementation uses token authentication from `./secrets` directory, handles large file downloads with proper streaming, supports downloading individual artifacts or all artifacts for a run, and provides comprehensive error handling for scenarios such as artifacts not yet available or expired artifacts.

## Backlog Items Analysis

### GH-24. Download workflow artifacts

**Requirement**: Download artifacts produced by a workflow run using REST API. This feature enables programmatic retrieval of workflow artifacts for further processing, analysis, or distribution. The implementation should handle authentication with token from `./secrets` directory, support downloading individual artifacts or all artifacts for a run, handle large file downloads with proper streaming, and provide proper error handling for scenarios such as artifacts not yet available, expired artifacts, or download failures.

**API Endpoint**: `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip`

**Key Capabilities Required**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- Download individual artifact by artifact_id
- Download all artifacts for a specific workflow run
- Handle large file downloads with proper streaming
- Support custom output directory
- Preserve artifact metadata (name, size)
- Repository auto-detection from git context
- Comprehensive error handling for:
  - Invalid artifact IDs (404)
  - Authentication failures (401/403)
  - Expired artifacts (410)
  - Artifacts not yet available
  - Download failures (network errors, disk space)

**Current Implementation Context**:
- Sprint 16 implemented artifact listing (GH-23)
- Sprint 15 established REST API pattern with curl
- Sprint 3 implemented log download with ZIP extraction
- No existing artifact download implementation
- Artifact deletion (GH-25) planned for future sprint

**REST API Requirements**:
- Use `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip` endpoint
- Handle authentication with token from `./secrets` directory
- Support streaming large files (avoid loading entire file into memory)
- Handle ZIP format responses (GitHub returns artifacts as ZIP archives)
- Provide proper error handling for:
  - Invalid artifact IDs (404)
  - Authentication failures (401/403)
  - Expired artifacts (410)
  - Artifacts not yet available
  - Download failures

**Pattern Reference**: Follow Sprint 15's REST API pattern + Sprint 16's artifact listing pattern:
- Token loading from `./secrets/github_token` or `./secrets/token`
- Repository resolution (CLI flag → env → git remote)
- HTTP error handling with descriptive messages
- Bearer token authentication headers
- Run ID resolution (for downloading all artifacts)

**Integration Points**:
- Must work with Sprint 16's artifact listing (GH-23)
- Compatible with run_id from correlation mechanism (GH-3, GH-15)
- Can be used with existing workflow runs (Sprint 1, Sprint 15)
- Complements log retrieval scripts (GH-5, GH-16)

**Technical Considerations**:
- GitHub API returns artifacts as ZIP archives
- Download URL follows redirect (302 redirect to actual download URL)
- Artifacts are associated with workflow runs, not individual jobs
- Artifacts expire after retention period (default: 90 days)
- Large artifacts require streaming to avoid memory issues
- Download multiple artifacts requires separate API calls per artifact
- ZIP archives need extraction (or save as-is for bulk operations)

**Open Questions**:
- Should script extract ZIP archives automatically or save them as-is?
  - **Decision**: Provide both options via `--extract` flag
- Should script create subdirectories for each artifact when downloading multiple?
  - **Decision**: Yes, use artifact name as subdirectory
- Should script preserve artifact metadata (name, size, timestamps)?
  - **Decision**: Yes, save metadata.json alongside each artifact

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
- **Reusable pattern**: ZIP extraction logic for artifacts

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
- Returns artifact metadata including download URLs
- Key pattern: Artifact discovery, metadata extraction
- **Direct integration point**: Provides artifact_ids for download

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

### 1. Token Authentication Pattern (Sprint 9, Sprint 15, Sprint 16)

**Token File Approach**:
- Load token from `./secrets/github_token` (default) or `./secrets/token`
- Validate file exists, readable, non-empty
- Warn about permissions (should be 600)
- Never leak token in error messages

### 2. Repository Resolution Pattern (Sprint 9, Sprint 15, Sprint 16)

**Auto-detection Priority**:
1. CLI flag (`--repo owner/repo`)
2. Environment variable (`GITHUB_REPOSITORY`)
3. Git remote parsing (`git config --get remote.origin.url`)

### 3. HTTP Handling Pattern (Sprint 9, Sprint 15, Sprint 16)

**curl API Call with Error Handling**:
- Bearer token headers: `Authorization: Bearer <token>`
- GitHub API version pinning: `X-GitHub-Api-Version: 2022-11-28`
- Accept header: `Accept: application/vnd.github+json`
- HTTP error handling for 401, 403, 404, 410, 422, 5xx
- Follow redirects: `curl -L` for download endpoints

### 4. Run ID Resolution Pattern (Sprint 15, Sprint 16)

**Input Priority**:
1. `--run-id` flag (direct numeric ID)
2. `--correlation-id` flag (load from metadata)
3. Stdin JSON (for automation)

### 5. ZIP Extraction Pattern (Sprint 3)

**ZIP Archive Handling**:
- Download ZIP archive to temporary location
- Extract to structured directory
- Preserve file structure within archive
- Clean up temporary files after extraction
- **Reusable for artifact downloads**

### 6. Artifact Discovery Pattern (Sprint 16)

**List Artifacts Integration**:
- Use `list-artifacts-curl.sh` to get artifact metadata
- Extract artifact_id from listing results
- Use artifact_id for download operations
- **Direct integration**: Sprint 17 can call Sprint 16's script

## Technical Approach Analysis

### Selected Approach: REST API with curl (Sprint 15/16 Pattern)

**Rationale**:
- Full control over download parameters
- Consistent with Sprint 15/16 approach
- More flexible for automation
- Better error handling and validation
- Direct access to API endpoints without gh CLI dependency
- Streaming support for large files

### Implementation Strategy

**Shared Components** (reuse from Sprint 15/16):
- Token loading function
- Repository resolution function
- HTTP error handling function
- API request wrapper
- Run ID resolution

**Script-Specific Components**:
- Artifact ID resolution (from artifact_id, run_id, or correlation_id)
- Download API call with streaming support
- ZIP extraction (optional, based on flag)
- Multiple artifact download loop
- Output directory management
- Metadata preservation
- Progress indication (optional)

### Feasibility Assessment

**GitHub API Capabilities Verified**:
- ✅ `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip` endpoint available
- ✅ Returns ZIP archive containing artifact files
- ✅ Supports redirect (302) to actual download URL
- ✅ Compatible with streaming downloads

**Authentication**:
- ✅ Token file pattern established (Sprint 9, Sprint 15, Sprint 16)
- ✅ Bearer token authentication supported
- ✅ Required permissions: Actions: Read

**Download Handling**:
- ✅ curl supports streaming downloads (`-o` or `-O` flags)
- ✅ curl can follow redirects (`-L` flag)
- ✅ ZIP extraction available via `unzip` command

**No Platform Limitations Identified**:
- All required APIs available
- All required operations supported
- No GitHub API limitations blocking implementation

## Expected Deliverables

**Scripts**:
- `scripts/download-artifact-curl.sh` - Download single artifact by artifact_id (GH-24)
- Optional: `scripts/download-all-artifacts-curl.sh` - Download all artifacts for a run (GH-24)
  - **Alternative**: Single script with `--all` flag

**Documentation**:
- `progress/sprint_17_design.md` - Design document
- `progress/sprint_17_implementation.md` - Implementation notes
- Script help documentation (inline `--help`)

**Testing**:
- Static validation (shellcheck)
- Manual test matrix (requires GitHub repository with workflow artifacts)
- Integration tests with Sprint 16 scripts

## Integration Points

**With Sprint 16 (GH-23)**:
- ✅ Use artifact listing to discover artifact_ids
- ✅ Can download artifacts from listing results
- ✅ Pipeline: List → Filter → Download

**With Sprint 15 (GH-14, GH-15, GH-16)**:
- ✅ Follows same REST API pattern
- ✅ Reuses token authentication and repository resolution
- ✅ Compatible CLI interface style
- ✅ Can use run_id from correlation scripts

**With Sprint 3 (GH-5)**:
- ✅ Reuse ZIP extraction pattern from log download
- ✅ Similar directory structure for downloaded artifacts

**With Sprint 1 (GH-2, GH-3)**:
- ✅ Compatible with correlation mechanism (UUID in run-name)
- ✅ Can use run_id from correlation scripts

**With Future Sprints**:
- ✅ Prepares foundation for artifact deletion (GH-25)
- ✅ Complete artifact lifecycle: List → Download → Delete

## Risks and Mitigations

### Risk 1: Large File Downloads

**Risk**: Large artifacts may consume excessive memory or fail to download
**Impact**: Script crashes or fails for large artifacts
**Mitigation**: Use curl streaming (`-o` flag), monitor disk space, add progress indication

### Risk 2: Artifact Expiration

**Risk**: Artifacts expire after retention period (default: 90 days)
**Impact**: HTTP 410 errors when attempting download
**Mitigation**: Check expiration date before download, handle 410 errors gracefully

### Risk 3: Download Failures

**Risk**: Network errors, disk space issues, or interrupted downloads
**Impact**: Partial downloads, corrupted files
**Mitigation**: Validate download completion, support resume (if possible), provide clear error messages

### Risk 4: Multiple Artifact Downloads

**Risk**: Downloading many artifacts may be slow or hit rate limits
**Impact**: Long execution times, potential rate limit errors
**Mitigation**: Add progress indication, handle rate limits gracefully, consider parallel downloads (future enhancement)

### Risk 5: ZIP Extraction Issues

**Risk**: ZIP extraction may fail for corrupted archives
**Impact**: Download succeeds but extraction fails
**Mitigation**: Validate ZIP integrity, provide clear error messages, keep original ZIP if extraction fails

### Risk 6: Redirect Handling

**Risk**: Download URL requires following 302 redirect
**Impact**: Download fails without redirect handling
**Mitigation**: Use `curl -L` flag to follow redirects automatically

## Success Criteria

Sprint 17 analysis is successful when:

1. ✅ Backlog item analyzed comprehensively
2. ✅ Project history reviewed and patterns identified
3. ✅ Technical approach selected and justified
4. ✅ Feasibility confirmed (no platform limitations)
5. ✅ Integration points documented (especially Sprint 16 integration)
6. ✅ Risks identified with mitigation strategies
7. ✅ Expected deliverables defined
8. ✅ Ready to proceed to Elaboration phase

## Next Steps

1. **Elaboration Phase**: Create detailed design document (`progress/sprint_17_design.md`)
2. **Design Approval**: Wait for Product Owner approval before construction
3. **Construction Phase**: Implement script following established patterns
4. **Testing**: Execute test matrix with GitHub repository access and workflow artifacts

## Analysis Artifacts

**Created Files**:
- `progress/sprint_17_analysis.md` - This comprehensive analysis document

**Referenced Files**:
- Sprint 3, 9, 15, 16 documentation for pattern identification
- Previous sprint design/implementation documents for context
- GitHub API documentation for endpoint verification

**Status**: ✅ Analysis Complete - Ready for Elaboration Phase
