# Inception Review – Sprint 8 (Chat 1)

## Context

Product Owner initiated Sprint 8 inception for GH-12 backlog item. Sprint 7 (GH-11, webhook-based correlation) failed due to requirement for public endpoint. Sprint 8 is a new backlog item.

## Sprint Status Review

From SRS.md Implementation Plan:
- **Sprint 0**: Done (Prerequisites - GH-1)
- **Sprint 1**: Done (Trigger & Correlation - GH-2, GH-3)
- **Sprint 2**: Failed (Real-time logs - GH-4)
- **Sprint 3**: Done (Post-run logs - GH-5)
- **Sprint 4**: Done (Benchmarks - GH-3.1, GH-5.1)
- **Sprint 5**: Implemented (Project review & ecosystem analysis)
- **Sprint 6**: Failed (Job-level logs API - GH-10)
- **Sprint 7**: Failed (Webhook correlation - GH-11)
- **Sprint 8**: Progress (Job phases with status - GH-12)

## Project History Summary

### Successful Deliverables (Sprints 0-5)

**Sprint 0** - Prerequisites and tooling setup:
- Comprehensive operator guide (`progress/sprint_0_prerequisites.md`)
- Tools: GitHub CLI, Go, Java, Podman, act, actionlint, jq
- Library recommendations: hub4j/github-api (Java), google/go-github (Go)

**Sprint 1** - Workflow triggering and correlation:
- `.github/workflows/dispatch-webhook.yml` - reusable workflow
- `scripts/trigger-and-track.sh` - UUID-based correlation (2-5s latency)
- `scripts/notify-webhook.sh` - webhook POST with retry
- Storage: `runs/<correlation_id>/metadata.json`

**Sprint 3** - Post-run log retrieval:
- `scripts/fetch-run-logs.sh` - download/extract logs to ZIP
- `scripts/lib/run-utils.sh` - shared metadata utilities
- Storage: `runs/<correlation_id>/logs/` with combined.log and logs.json

**Sprint 4** - Performance benchmarking:
- `scripts/benchmark-correlation.sh` - measures run_id retrieval timing
- `scripts/benchmark-log-retrieval.sh` - measures log download timing
- Statistical analysis with mean/min/max/median

**Sprint 5** - Project review (research sprint, 1,900+ lines):
- Complete retrospective of Sprints 0-4
- GitHub CLI capabilities inventory
- GitHub API comprehensive analysis
- Major libraries survey (Java, Go, Python)

### Failed Sprints - Root Causes

**Sprint 2 (GH-4)** - Real-time log streaming:
- **Failure reason**: GitHub platform limitation - no streaming API exists
- Evidence: REST API returns 404 for in-progress runs, Web UI uses polling, no webhook log content
- Status: Impossible to implement (confirmed by Sprint 5 research)

**Sprint 6 (GH-10)** - Job-level logs API validation:
- **Failure reason**: Requires public webhook endpoint for testing
- Status: Hypothesis untested

**Sprint 7 (GH-11)** - Webhook-based correlation:
- **Failure reason**: Requires public endpoint unavailable in test environment
- Delivered tooling: `scripts/manage-actions-webhook.sh`, `scripts/process-workflow-webhook.sh`
- Status: Tooling exists but unvalidated

## Sprint 8 (GH-12) Understanding

### Backlog Item: GH-12

**Requirement** (from SRS.md):
> Use GitHub API to get workflow job phases with status mimicking `gh run view <run_id>`. Use API or gh utility. Prefer browser based authentication for simplicity.

**Goal**: Retrieve and display workflow job execution phases (queued, in_progress, completed) with status/conclusion for each job, similar to `gh run view <run_id>` output.

### Available Building Blocks

From previous sprints:
1. **Correlation mechanism** (Sprint 1) - `scripts/trigger-and-track.sh` resolves run_id from UUID
2. **Metadata storage** - `runs/<correlation_id>/metadata.json` pattern established
3. **GitHub CLI authenticated** - `gh run view`, `gh api` available
4. **API endpoint** - `gh api repos/:owner/:repo/actions/runs/:run_id/jobs` returns job details
5. **JSON processing** - `jq` for parsing, established patterns for output

### Key Information to Extract

Based on `gh run view` behavior and API capabilities:
- Job name and ID
- Job status (queued, in_progress, completed)
- Job conclusion (success, failure, cancelled, skipped)
- Started and completed timestamps
- Step-level details (name, status, conclusion)
- Run attempt number

### Design Considerations

1. **Output format**: Human-readable table vs JSON (or both with flag)
2. **Real-time monitoring**: Poll for updates during run vs one-time snapshot
3. **Integration**: Store results in `runs/<correlation_id>/` alongside metadata
4. **Composability**: JSON output enables piping to other scripts
5. **Error handling**: Handle in-progress runs, failed jobs, network errors

### Compatibility Requirements

Must maintain compatibility with:
- Sprint 1 correlation mechanism and metadata format
- Sprint 3 log retrieval (jobs data complements log analysis)
- Established patterns: shellcheck validation, JSON output, error handling
- Storage structure: `runs/<correlation_id>/` directory layout

## Technical Context

**GitHub API Endpoint** (from Sprint 5 research):
- `GET /repos/:owner/:repo/actions/runs/:run_id/jobs` - List jobs for run (paginated)
- Returns: jobs array with step information, status, conclusion, timestamps

**CLI Alternative**:
- `gh run view <run_id>` - Shows run details including job status
- `gh run view <run_id> --json jobs` - JSON output with full job details

**Authentication**: Browser-based auth already configured (Sprint 0 prerequisites)

## Implementor Confirmation

Understanding confirmed:
- Sprint 8 (GH-12) aims to provide tooling for querying workflow job phases with status
- Solution should mimic `gh run view` output but potentially with enhanced formatting/filtering
- Must integrate with existing Sprint 1 correlation and metadata storage patterns
- Prefer using GitHub CLI (`gh run view` or `gh api`) with browser-based authentication
- Design phase next: determine approach, output format, integration points, validation strategy

Ready to proceed with Sprint 8 (GH-12) elaboration phase.
