# Inception Sprint 10 - Chat 1

Date: 2025-11-06
Sprint: Sprint 10
Backlog Item: GH-13. Caller gets data produced by a workflow
Status: Inception phase completed

## Sprint 10 Overview

**Goal:** Implement GH-13 - Caller gets data produced by a workflow

**Requirement:** Caller uses GitHub REST API to get data produced by a workflow. The workflow returns simple data structure derived from parameters passed by a caller.

**Key Constraints:**
- NOT about artifacts
- Focus on simple data structures
- Must use synchronous interfaces (from caller's perspective)
- Use GitHub REST API exclusively

## Understanding from Project History

### Completed Sprints Analysis

**Sprint 0 (Done) - Prerequisites:**
- Established tooling: GitHub CLI (gh), actionlint for validation
- Authentication: Browser-based auth for simplicity
- Container support: podman if needed

**Sprint 1 (Done) - Workflow Triggering & Correlation:**
- **Achievement:** `.github/workflows/dispatch-webhook.yml` - workflow triggered via `workflow_dispatch`
- **Achievement:** `scripts/trigger-and-track.sh` - correlation mechanism using UUID in run-name
- **Achievement:** `scripts/lib/run-utils.sh` - shared utilities for run ID resolution
- **Key Pattern:** Correlation via run-name: `Dispatch Webhook (<correlation_id>)`
- **Key Pattern:** Metadata storage in `runs/<correlation_id>/metadata.json`
- **Key Pattern:** JSON output for pipeline composition

**Sprint 3 (Done) - Log Retrieval After Run:**
- **Achievement:** `scripts/fetch-run-logs.sh` - downloads logs after workflow completion
- **Achievement:** Shared utilities in `scripts/lib/run-utils.sh`
- **Key Pattern:** Post-run data retrieval via GitHub API
- **Key Pattern:** Multiple input methods: run_id, correlation_id, stdin JSON

**Sprint 4 (Done) - Timing Benchmarks:**
- Measured run_id retrieval timing
- Measured log retrieval timing
- Validated performance characteristics

**Sprint 5 (Implemented) - Project Review:**
- Enumerated GitHub CLI capabilities
- Enumerated GitHub API endpoints
- Reviewed libraries for Java, Go, Python
- Validated technical feasibility

**Sprint 8 & 9 (Done) - Job Status Retrieval:**
- **Achievement:** `scripts/view-run-jobs.sh` - retrieves job phases via gh CLI
- **Achievement:** `scripts/view-run-jobs-curl.sh` - retrieves job phases via REST API with curl
- **Key Pattern:** Multiple output formats (table, verbose, JSON)
- **Key Pattern:** Watch mode for real-time monitoring
- **Key Pattern:** GitHub API: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`
- **Key Achievement:** Successfully retrieves structured workflow execution data via REST API

### Failed/Not Applicable Sprints

**Sprint 2 (Failed) - Real-time Log Access:**
- GitHub does not provide streaming log API during workflow execution
- Logs only available after completion

**Sprint 6 (Failed) - Job-level Log API:**
- Attempted `GET /repos/owner/repo/actions/jobs/{job_id}/logs`
- Confirmed logs not available in real-time

**Sprint 7 (Failed) - Workflow Webhook for run_id:**
- GitHub webhook system not suitable for immediate run_id retrieval
- Sprint 1 correlation approach remains the best solution

## Reusable Components for Sprint 10

### 1. Workflow Foundation

**Existing workflows:**
- `.github/workflows/dispatch-webhook.yml` - accepts inputs (webhook_url, correlation_id)
- `.github/workflows/long-run-logger.yml` - accepts inputs (correlation_id, iterations, sleep_seconds)

**Reusable patterns:**
- `workflow_dispatch` with typed inputs
- Input parameter handling
- Correlation ID tracking
- Run-name formatting for searchability

### 2. Script Infrastructure

**Core utilities (`scripts/lib/run-utils.sh`):**
- `ru_read_run_id_from_runs_dir()` - load from correlation metadata
- `ru_read_run_id_from_stdin()` - accept JSON via pipe
- `ru_metadata_path_for_correlation()` - path resolution

**Trigger & correlation (`scripts/trigger-and-track.sh`):**
- Workflow dispatch with correlation ID
- Metadata storage in `runs/<correlation_id>/metadata.json`
- JSON output for composition
- Polling mechanism for run_id resolution

**Job status retrieval:**
- `scripts/view-run-jobs.sh` - gh CLI approach
- `scripts/view-run-jobs-curl.sh` - REST API approach with token auth

### 3. GitHub API Patterns

**Proven API endpoints:**
- `GET /repos/{owner}/{repo}/actions/runs/{run_id}` - run metadata
- `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs` - job details with steps
- `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` - trigger workflow

**Authentication patterns:**
- gh CLI: browser-based auth (Sprint 0)
- curl: token from `./secrets/github_token` (Sprint 9)

**Data retrieval patterns:**
- Poll for run completion
- Fetch structured data via REST API
- Transform into desired output format

### 4. Testing Patterns

**Validation approach:**
- `actionlint` for workflow syntax
- `shellcheck` for script quality
- Manual E2E tests with real GitHub infrastructure
- Benchmark scripts for performance measurement

## Sprint 10 Goals and Deliverables

### Goal

Enable caller to retrieve simple data structures produced by a workflow without using artifacts. Workflow accepts input parameters, processes them, and returns derived data that caller can retrieve via GitHub REST API.

### Key Questions to Answer in Design Phase

1. **How does workflow output data?**
   - Job outputs?
   - Step outputs?
   - Workflow conclusion data?
   - Job summary?

2. **How does caller retrieve the data?**
   - Which GitHub API endpoint?
   - What data structure format?
   - Synchronous polling pattern?

3. **What data transformation occurs?**
   - What input parameters?
   - What processing logic?
   - What output structure?

### Expected Deliverables

**1. Workflow Implementation:**
- New or modified workflow accepting input parameters
- Logic to process inputs and produce output data
- Mechanism to expose output data (job outputs, step outputs, etc.)

**2. Client Script Implementation:**
- Script to trigger workflow with parameters
- Script to retrieve output data after workflow completion
- Reuse existing patterns from Sprint 1 (correlation) and Sprint 8/9 (data retrieval)

**3. Testing:**
- `actionlint` validation of workflow syntax
- E2E test: trigger workflow with sample inputs
- E2E test: retrieve and validate output data
- Test edge cases: invalid inputs, missing parameters

**4. Documentation:**
- Design document: `progress/sprint_10_design.md`
- Implementation notes: `progress/sprint_10_implementation.md`
- User README with usage examples
- Test execution instructions

### Success Criteria

1. Workflow accepts typed input parameters
2. Workflow processes inputs and produces derived data structure
3. Output data available via GitHub REST API (not artifacts)
4. Client can retrieve output data reliably after workflow completion
5. Solution reuses existing correlation and retrieval patterns
6. All tests pass (syntax validation, E2E, edge cases)
7. Documentation complete with examples

## Integration with Existing Infrastructure

**Trigger pattern (from Sprint 1):**
```bash
# Trigger with correlation tracking
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow <new-workflow>.yml \
  --input param1=value1 \
  --input param2=value2 \
  --store-dir runs \
  --json-only)

correlation_id=$(echo "$result" | jq -r '.correlation_id')
run_id=$(echo "$result" | jq -r '.run_id')
```

**Data retrieval pattern (from Sprint 8/9):**
```bash
# View job status and extract outputs
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '.jobs[].outputs'
```

**Expected new pattern for Sprint 10:**
```bash
# New script to extract workflow outputs
scripts/get-workflow-output.sh --run-id "$run_id" --json
# or
scripts/get-workflow-output.sh --correlation-id "$correlation_id" --runs-dir runs
```

## Technical Considerations

### GitHub API Capabilities (from Sprint 5 review)

**Workflow outputs are exposed via:**
- Job outputs: Steps can set outputs that become job outputs
- Job outputs become visible via API: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`
- Response includes `outputs` field at job level

**Example workflow pattern:**
```yaml
jobs:
  process:
    outputs:
      result: ${{ steps.compute.outputs.result }}
    steps:
      - id: compute
        run: |
          # Process inputs
          echo "result={\"key\":\"value\"}" >> "$GITHUB_OUTPUT"
```

**API retrieval:**
```bash
gh api /repos/{owner}/{repo}/actions/runs/{run_id}/jobs \
  --jq '.jobs[].outputs'
```

### Compatibility Requirements

- Reuse `scripts/lib/run-utils.sh` shared functions
- Follow existing CLI patterns (--run-id, --correlation-id, --json, stdin)
- Store metadata in `runs/<correlation_id>/` directory structure
- Maintain JSON output for pipeline composition
- Use same authentication patterns (gh CLI or token file)

## Open Questions for Design Phase

1. **Output structure:** What specific data structure should the workflow produce?
   - Simple key-value pairs?
   - Nested JSON structure?
   - Multiple outputs from multiple jobs?

2. **Input processing:** What transformation should the workflow perform?
   - Mathematical computation?
   - String manipulation?
   - Data validation/formatting?

3. **Error handling:** How to handle processing failures?
   - Job outputs when step fails?
   - Error structure in output?
   - Caller detection of failures?

4. **Scope:** Single job or multiple jobs with combined outputs?

These will be addressed in the Elaboration (design) phase.

## Understanding Summary

**I understand Sprint 10 requires:**

1. Implementing workflow that accepts parameters and produces structured output
2. Implementing client script to retrieve that output via GitHub REST API
3. NOT using artifacts - using job/workflow outputs instead
4. Reusing proven patterns from Sprints 1, 3, 8, and 9
5. Following established testing and documentation standards
6. Maintaining compatibility with existing infrastructure

**Reusable components identified:**
- Workflow dispatch mechanism (Sprint 1)
- Correlation tracking system (Sprint 1)
- Run utilities library (Sprint 3)
- Job data retrieval patterns (Sprint 8/9)
- Authentication patterns (Sprint 0, 9)
- Testing patterns (all sprints)

**Technical approach validated:**
- GitHub API supports job outputs
- Sprint 8/9 proved job data retrieval works
- Sprint 1 proved parameter passing works
- Combination enables Sprint 10 requirement

**Ready for next phase:** Elaboration (design) to specify exact workflow logic, data structures, and client implementation.

## Status

All project history reviewed. All reusable components identified. Sprint 10 goals and deliverables understood. Technical feasibility confirmed based on Sprint 5 analysis and Sprint 8/9 implementation.

**Ready to proceed to Elaboration phase upon Product Owner instruction.**
