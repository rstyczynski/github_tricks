# Elaboration Review – Sprint 15 (Chat 1)

Date: 2025-01-27
Sprint: Sprint 15
Backlog Items: GH-14, GH-15, GH-16
Status: Elaboration phase completed - Design accepted

## Context

Product Owner accepted the design for Sprint 15 after review. All three backlog items (GH-14, GH-15, GH-16) are now approved and ready for construction phase.

## Design Summary

### GH-14. Trigger workflow with REST API

**Status**: Accepted

**Design Approach**:
- Script: `scripts/trigger-workflow-curl.sh`
- Uses `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` endpoint
- Token authentication from `./secrets/github_token` or `./secrets/token`
- Workflow ID resolution (file path or numeric ID)
- Support for workflow inputs via `--input key=value` flags
- Correlation ID support (auto-generated or provided)
- Comprehensive error handling for HTTP 204, 404, 422, 401, 403

**Key Design Decisions**:
- Follow Sprint 9's token authentication and repository resolution patterns
- Maintain compatibility with existing `.github/workflows/dispatch-webhook.yml`
- Support same workflow inputs as gh CLI version
- JSON output support for automation

### GH-15. Workflow correlation with REST API

**Status**: Accepted

**Design Approach**:
- Script: `scripts/correlate-workflow-curl.sh`
- Uses `GET /repos/{owner}/{repo}/actions/runs` with filtering
- UUID-based correlation filtering via run-name matching
- Polling mechanism with configurable timeout (default 60s) and interval (default 3s)
- Workflow and branch filtering support
- Metadata storage support (`--store-dir`)
- Pagination handling via Link headers

**Key Design Decisions**:
- Follow Sprint 1's correlation logic but using REST API
- Filter by workflow_id, head_branch, status (queued/in_progress)
- Filter run-name containing correlation_id using jq
- Compatible with existing `runs/<correlation_id>/metadata.json` format

### GH-16. Fetch logs with REST API

**Status**: Accepted

**Design Approach**:
- Script: `scripts/fetch-logs-curl.sh`
- Uses `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs` endpoint (run-level API)
- Run completion validation before download
- ZIP archive download and extraction
- Structured log organization (`logs/<job_name>/step.log`)
- Combined log generation (`combined.log`)
- Metadata JSON generation (`logs.json`)

**Key Design Decisions**:
- Use run-level API (matches GH-5 implementation, simpler, single API call)
- Reuse log extraction and aggregation logic from Sprint 3
- Same output structure as existing `fetch-run-logs.sh`
- Compatible with existing log processing scripts

## Design Process

### Phase 1: Requirements Analysis

Reviewed Sprint 15 requirements from BACKLOG.md:
- GH-14: Validate GH-2 using pure REST API with curl
- GH-15: Validate GH-3 using pure REST API with curl
- GH-16: Validate GH-5 using pure REST API endpoints

### Phase 2: Pattern Identification

Identified key patterns to reuse:
- **Sprint 9**: Token authentication, repository resolution, HTTP handling
- **Sprint 1**: Correlation mechanism (UUID in run-name)
- **Sprint 3**: Log extraction and aggregation logic

### Phase 3: Feasibility Analysis

Verified GitHub API capabilities:
- ✅ GH-14: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` available
- ✅ GH-15: `GET /repos/{owner}/{repo}/actions/runs` available with filtering
- ✅ GH-16: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs` available

**Conclusion**: All three backlog items are fully feasible, no platform limitations identified.

### Phase 4: Design Documentation

Created comprehensive design document (`progress/sprint_15_design.md`) covering:
- Architecture diagrams
- Script designs with CLI interfaces
- Implementation details
- Error handling strategies
- Integration patterns
- Testing strategies
- Compatibility requirements
- Risks and mitigations

### Phase 5: Design Review

Design document reviewed by Product Owner and accepted. All three backlog items marked as "Accepted" status.

## Design Artifacts

**Created Files**:
- `progress/sprint_15_design.md` - Comprehensive design document (833 lines)

**Design Document Contents**:
- Executive summary
- Feasibility analysis
- Architecture diagrams
- Script designs (GH-14, GH-15, GH-16)
- Implementation details
- Error handling specifications
- Integration patterns
- Testing strategies
- Compatibility requirements
- Risks and mitigations
- Success criteria

## Key Design Decisions

### 1. Token Authentication Pattern

**Decision**: Use Sprint 9's token file pattern
- Default: `./secrets/github_token`
- Alternative: `./secrets/token`
- Custom: `--token-file <path>`

**Rationale**: Consistent with established patterns, supports automation use cases

### 2. Repository Resolution Pattern

**Decision**: Use Sprint 9's auto-detection pattern
- Priority: CLI flag → `GITHUB_REPOSITORY` env → git remote parsing

**Rationale**: Seamless developer experience, works in CI/CD environments

### 3. Log Retrieval API Choice

**Decision**: Use run-level API (`/actions/runs/{run_id}/logs`) instead of job-level API

**Rationale**: 
- Matches existing GH-5 implementation
- Simpler (single API call vs multiple)
- Aggregates all jobs in single ZIP
- Compatible with existing log processing logic

### 4. CLI Interface Compatibility

**Decision**: Maintain compatibility with existing gh CLI scripts

**Rationale**: 
- Drop-in replacement capability
- Familiar interface for operators
- Easy migration path

### 5. Error Handling Approach

**Decision**: Comprehensive error handling for all HTTP status codes

**Rationale**: 
- Clear error messages for operators
- Proper exit codes for automation
- Never leak token in error messages

## Integration Points

### With Sprint 1 (GH-2, GH-3)

- Compatible CLI interface
- Same correlation mechanism (UUID in run-name)
- Compatible metadata storage format
- Can be used as drop-in replacement

### With Sprint 3 (GH-5)

- Compatible log extraction logic
- Same output structure (combined.log, logs.json)
- Compatible with existing log processing scripts

### With Sprint 9 (REST API Pattern)

- Reuse token authentication patterns
- Reuse repository resolution patterns
- Reuse HTTP handling patterns
- Consistent error handling approach

## Testing Strategy

### Static Validation

- Shell script linting (`shellcheck`)
- GitHub workflow syntax validation (`actionlint`)

### Manual Testing (Requires GitHub Access)

**GH-14 Tests**:
- Trigger workflow with minimal fields
- Trigger workflow with inputs
- Trigger workflow with correlation_id
- Invalid workflow file (404 error)
- Invalid branch (422 error)
- JSON output format
- Auto-detect repository

**GH-15 Tests**:
- Correlate with valid correlation_id
- Correlate with workflow filter
- Correlate with branch filter
- Timeout scenario
- JSON output format
- Store metadata

**GH-16 Tests**:
- Fetch logs for completed run
- Fetch logs for in-progress run (error)
- Fetch logs with correlation_id
- Invalid run_id (404 error)
- Expired logs (410 error)
- Produce combined.log
- Produce logs.json

## Risks and Mitigations

### Risk 1: Workflow ID Resolution Complexity

**Mitigation**: Try file path first, fallback to numeric ID, clear error messages

### Risk 2: Correlation Timeout

**Mitigation**: Polling with configurable timeout and interval, clear timeout messages

### Risk 3: Log Availability Timing

**Mitigation**: Validate run completion before download, retry logic for 404 errors

### Risk 4: API Rate Limiting

**Mitigation**: Use reasonable polling intervals, handle 403 responses gracefully

### Risk 5: Token Permissions

**Mitigation**: Document required permissions, provide clear error messages

## Next Steps

**Construction Phase**:
1. Implement `scripts/trigger-workflow-curl.sh` following design
2. Implement `scripts/correlate-workflow-curl.sh` following design
3. Implement `scripts/fetch-logs-curl.sh` following design
4. Run static validation (shellcheck, actionlint)
5. Execute manual test matrix with GitHub repository access
6. Update implementation notes with test results

**Testing Requirements**:
- GitHub repository with workflow_dispatch workflows
- Valid GitHub token with Actions: Write/Read permissions
- Webhook URL from https://webhook.site (for end-to-end testing)

## Design Approval

**Status**: ✅ All backlog items accepted

- ✅ GH-14: Design accepted
- ✅ GH-15: Design accepted
- ✅ GH-16: Design accepted

**Ready for**: Construction phase

## Summary

Sprint 15 design phase completed successfully. All three backlog items have been designed following established patterns from Sprint 9, maintaining compatibility with existing implementations from Sprints 1 and 3. The design document provides comprehensive specifications for implementation, including CLI interfaces, error handling, integration patterns, and testing strategies.

**Design Document**: `progress/sprint_15_design.md`
**Status**: Accepted and ready for construction phase

