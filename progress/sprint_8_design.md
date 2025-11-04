# Sprint 8 - Design

## GH-12. Use GitHub API to get workflow job phases with status

Status: Proposed

Description: Use GitHub API to get workflow job phases with status mimicking `gh run view <run_id>`. Use API or gh utility. Prefer browser-based authentication for simplicity.

Goal: Provide operators with tooling to retrieve and display workflow job execution phases (queued, in_progress, completed) with status/conclusion for each job and step, similar to the output of `gh run view <run_id>` but with enhanced flexibility for filtering, monitoring, and integration with existing Sprint 1/3 tooling.

### Feasibility Analysis

**GitHub CLI Capabilities** (from Sprint 5 research):
- `gh run view <run_id>` - Shows run summary with job status
- `gh run view <run_id> --verbose` - Shows job steps with status
- `gh run view <run_id> --json jobs` - JSON output with full job details including steps
- Available JSON fields: `attempt, conclusion, createdAt, databaseId, displayTitle, event, headBranch, headSha, jobs, name, number, startedAt, status, updatedAt, url, workflowDatabaseId, workflowName`

**GitHub API Endpoint**:
- `GET /repos/:owner/:repo/actions/runs/:run_id/jobs` - List jobs for run (paginated)
- Returns array of job objects with:
  - `id`, `run_id`, `name`, `status`, `conclusion`
  - `started_at`, `completed_at` timestamps
  - `steps[]` array with step-level details (name, status, conclusion, number, started_at, completed_at)
  - Documentation: https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run

**Available Building Blocks** (from previous sprints):
- Sprint 1: `scripts/trigger-and-track.sh` provides run_id resolution via UUID correlation
- Sprint 1: `runs/<correlation_id>/metadata.json` stores run_id and correlation data
- Sprint 3: `scripts/lib/run-utils.sh` provides shared metadata loading functions
- Sprint 0: GitHub CLI authenticated with browser-based auth

**Dependencies**:
- `gh` CLI (authenticated) - already installed and configured (Sprint 0)
- `jq` - JSON parsing - already required (Sprint 0)
- Standard Unix utilities: `date`, `column`, `printf`

**Feasibility**: **Fully achievable** - All required tools and APIs are available, authenticated, and proven working in previous sprints.

### Design

#### Script: `scripts/view-run-jobs.sh`

A new script that retrieves and displays workflow job phases with status, providing multiple output formats and integration with existing metadata storage.

**Command-line interface**:

```bash
scripts/view-run-jobs.sh [--run-id <id>] [--correlation-id <uuid>] [--runs-dir <dir>] [--json] [--verbose] [--watch]
```

**Parameters**:
- `--run-id <id>` - Workflow run ID (numeric)
- `--correlation-id <uuid>` - Load run_id from stored metadata in `runs/<uuid>/metadata.json`
- `--runs-dir <dir>` - Base directory for metadata (default: `runs`)
- `--json` - Output JSON format instead of human-readable table
- `--verbose` - Include step-level details (like `gh run view --verbose`)
- `--watch` - Poll for updates until run completes (refresh every 3 seconds)

**Input priority** (first match wins):
1. `--run-id` explicitly provided
2. `--correlation-id` loads from stored metadata
3. Stdin JSON (from `trigger-and-track.sh` output)
4. Interactive prompt (if terminal)

**Reuse existing patterns** from `scripts/lib/run-utils.sh`:
- `resolve_run_id()` function to handle input sources
- Consistent error messaging and validation

#### Functionality

**Core operation**:
1. **Resolve run_id** from input (direct, correlation metadata, stdin JSON, or prompt)
2. **Fetch job data**:
   - Use `gh run view <run_id> --json jobs` to retrieve full job details
   - Extract: `jobs[]` array with id, name, status, conclusion, started_at, completed_at, steps[]
3. **Display results**:
   - **Human-readable format** (default): Table showing job phases with status
   - **JSON format** (`--json`): Structured output for programmatic consumption
   - **Verbose format** (`--verbose`): Include step-level details
   - **Watch mode** (`--watch`): Poll every 3 seconds, refresh display until completion

**Output formats**:

**Format 1: Human-readable table (default)**
```
Run: 1234567890 (Dispatch Webhook (uuid))
Status: in_progress
Started: 2025-01-15 10:30:00 UTC

Job                    Status        Conclusion    Started              Completed
--------------------- ------------- ------------- -------------------- --------------------
emit                  in_progress   -             2025-01-15 10:30:05  -
```

**Format 2: Human-readable with verbose steps (--verbose)**
```
Run: 1234567890 (Dispatch Webhook (uuid))
Status: in_progress
Started: 2025-01-15 10:30:00 UTC

Job: emit
  Status: in_progress
  Started: 2025-01-15 10:30:05

  Step                          Status        Conclusion    Duration
  ----------------------------- ------------- ------------- --------
  1. Set up job                 completed     success       2s
  2. actions/github-script@v7   in_progress   -             -
  3. Notify webhook             queued        -             -
```

**Format 3: JSON output (--json)**
```json
{
  "run_id": "1234567890",
  "run_name": "Dispatch Webhook (uuid)",
  "status": "in_progress",
  "conclusion": null,
  "started_at": "2025-01-15T10:30:00Z",
  "completed_at": null,
  "jobs": [
    {
      "id": "9876543210",
      "name": "emit",
      "status": "in_progress",
      "conclusion": null,
      "started_at": "2025-01-15T10:30:05Z",
      "completed_at": null,
      "steps": [
        {
          "name": "Set up job",
          "status": "completed",
          "conclusion": "success",
          "number": 1,
          "started_at": "2025-01-15T10:30:05Z",
          "completed_at": "2025-01-15T10:30:07Z"
        },
        {
          "name": "actions/github-script@v7",
          "status": "in_progress",
          "conclusion": null,
          "number": 2,
          "started_at": "2025-01-15T10:30:07Z",
          "completed_at": null
        }
      ]
    }
  ]
}
```

**Format 4: Watch mode (--watch)**
- Clears screen and re-displays table every 3 seconds
- Shows elapsed time since run started
- Exits when run reaches terminal status (completed/cancelled/failed)
- Uses `gh run view <run_id> --json status,conclusion,jobs` for each poll

#### Integration with Existing Tooling

**With Sprint 1 (trigger-and-track.sh)**:
```bash
# Trigger and immediately view job status
result=$(scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only)
echo "$result" | scripts/view-run-jobs.sh --json

# Or using correlation ID
correlation_id=$(echo "$result" | jq -r '.correlation_id')
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --runs-dir runs --watch
```

**With Sprint 3 (fetch-run-logs.sh)**:
```bash
# View job status before fetching logs
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --runs-dir runs

# Wait for completion, then fetch logs
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --watch
scripts/fetch-run-logs.sh --correlation-id "$correlation_id" --runs-dir runs
```

**Metadata storage** (optional):
- Save job status snapshot to `runs/<correlation_id>/jobs.json` when `--runs-dir` + `--correlation-id` provided
- Enables historical comparison or offline review

#### Implementation Details

**Script structure**:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/run-utils.sh"

# Parse arguments
# Resolve run_id (using run-utils.sh functions)
# Fetch job data via gh CLI
# Format and display output
# Handle watch mode loop if enabled
```

**Key functions**:
- `fetch_job_data(run_id)` - Call `gh run view <run_id> --json jobs` and parse response
- `format_table(jobs_json)` - Convert JSON to human-readable table using `column -t`
- `format_verbose(jobs_json)` - Convert JSON to verbose format with step details
- `watch_loop(run_id, format_func)` - Poll every 3s, refresh display, exit on completion
- `calculate_duration(started, completed)` - Compute elapsed time for completed jobs/steps

**Error handling**:
- Run not found (HTTP 404): "Error: Run ID <id> not found"
- Network errors: Retry with exponential backoff (3 attempts max)
- Invalid correlation ID: "Error: No metadata found for correlation ID <uuid>"
- Missing run_id in metadata: "Error: Metadata file missing run_id field"

**Status/Conclusion mapping**:
- Status values: `queued`, `in_progress`, `completed`, `waiting`
- Conclusion values: `success`, `failure`, `cancelled`, `skipped`, `neutral`, `timed_out`, `action_required`
- Display `-` for null conclusion (in-progress jobs)

### Validation Strategy

**Static validation**:
```bash
shellcheck scripts/view-run-jobs.sh
actionlint  # Ensure no workflow changes
```

**Manual testing** (requires GitHub repository access):

**Test 1: Basic job status retrieval**
```bash
# Trigger workflow and get run_id
result=$(scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only)
run_id=$(echo "$result" | jq -r '.run_id')

# View job status (table format)
scripts/view-run-jobs.sh --run-id "$run_id"
```

**Expected output**: Table with job name, status, timestamps

**Test 2: Verbose output with steps**
```bash
scripts/view-run-jobs.sh --run-id "$run_id" --verbose
```

**Expected output**: Job details with step-level breakdown

**Test 3: JSON output for programmatic use**
```bash
scripts/view-run-jobs.sh --run-id "$run_id" --json | jq '.jobs[].name'
```

**Expected output**: JSON with jobs array, pipe to jq should extract job names

**Test 4: Integration with correlation**
```bash
correlation_id=$(echo "$result" | jq -r '.correlation_id')
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --runs-dir runs
```

**Expected output**: Loads run_id from metadata, displays job status

**Test 5: Watch mode (real-time monitoring)**
```bash
# Trigger long-running workflow
scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=10 --input sleep_seconds=5 \
  --store-dir runs --json-only > run.json

# Watch job progress
correlation_id=$(jq -r '.correlation_id' run.json)
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --runs-dir runs --watch
```

**Expected behavior**:
- Screen refreshes every 3 seconds
- Job status updates from queued → in_progress → completed
- Script exits when run completes

**Test 6: Error handling**
```bash
# Non-existent run ID
scripts/view-run-jobs.sh --run-id 9999999999

# Invalid correlation ID
scripts/view-run-jobs.sh --correlation-id "invalid-uuid" --runs-dir runs
```

**Expected behavior**: Clear error messages, non-zero exit status

**Test 7: Piping from trigger-and-track**
```bash
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only \
  | scripts/view-run-jobs.sh --json \
  | jq '.jobs[].status'
```

**Expected behavior**: Seamless composition via JSON stdin/stdout

### Compatibility with Previous Sprints

**Sprint 1 compatibility**:
- ✅ Reads `runs/<correlation_id>/metadata.json` format (no changes required)
- ✅ Accepts JSON from `trigger-and-track.sh --json-only` via stdin
- ✅ Uses same `--runs-dir` and `--correlation-id` CLI patterns

**Sprint 3 compatibility**:
- ✅ Uses `scripts/lib/run-utils.sh` shared functions
- ✅ Follows same error handling and validation patterns
- ✅ Complements log retrieval (view jobs before fetching logs)

**Sprint 4 compatibility**:
- ✅ JSON output enables potential benchmarking of job execution times
- ✅ Could be wrapped in future benchmark script if needed

**Sprint 5 recommendations**:
- ✅ Uses `gh run view` (documented in Sprint 5 CLI analysis)
- ✅ Follows shell-based approach validated as appropriate for project scope

### Use Cases

**Use Case 1: Monitor workflow progress during execution**
```bash
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only > run.json
correlation_id=$(jq -r '.correlation_id' run.json)
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --runs-dir runs --watch
```
Operator sees real-time job status updates until completion.

**Use Case 2: Quick status check**
```bash
scripts/view-run-jobs.sh --correlation-id "$correlation_id" --runs-dir runs
```
Operator gets snapshot of current job phases without watching.

**Use Case 3: Programmatic job status querying**
```bash
scripts/view-run-jobs.sh --run-id 1234567890 --json | jq '.jobs[] | select(.conclusion == "failure")'
```
Automation script identifies failed jobs for alerting or retry logic.

**Use Case 4: Integration with CI/CD pipeline**
```bash
#!/bin/bash
# Deploy script that waits for workflow completion
result=$(scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only)
run_id=$(echo "$result" | jq -r '.run_id')

# Wait for completion
scripts/view-run-jobs.sh --run-id "$run_id" --watch

# Check if all jobs succeeded
jobs_json=$(scripts/view-run-jobs.sh --run-id "$run_id" --json)
failed_jobs=$(echo "$jobs_json" | jq '[.jobs[] | select(.conclusion != "success")] | length')

if [ "$failed_jobs" -gt 0 ]; then
  echo "Deployment failed: $failed_jobs job(s) did not succeed"
  exit 1
fi

echo "Deployment successful: all jobs completed"
```

**Use Case 5: Debugging workflow failures**
```bash
# View verbose output to identify which step failed
scripts/view-run-jobs.sh --run-id "$run_id" --verbose

# Then fetch full logs for the failed job
scripts/fetch-run-logs.sh --run-id "$run_id"
```

### Risks and Mitigations

**Risk 1: GitHub API rate limiting**
- **Impact**: Watch mode makes repeated API calls (20 calls/minute in worst case)
- **Mitigation**: 3-second polling interval (well within 5,000 requests/hour authenticated limit)
- **Mitigation**: Exit watch mode immediately on completion (no unnecessary polling)
- **Mitigation**: Document rate limit considerations in script help

**Risk 2: Large job count formatting**
- **Impact**: Workflows with many jobs (50+) may produce unwieldy table output
- **Mitigation**: Default table format is concise (one line per job)
- **Mitigation**: Use `--json` for programmatic processing of large job sets
- **Mitigation**: Consider future enhancement: `--filter` to show subset of jobs

**Risk 3: In-progress runs may have incomplete data**
- **Impact**: Jobs not yet started show null timestamps
- **Mitigation**: Display `-` for null values in table format
- **Mitigation**: JSON format preserves nulls for accurate programmatic handling
- **Mitigation**: Watch mode shows progressive data updates

**Risk 4: Terminal width constraints**
- **Impact**: Wide tables may wrap or truncate on narrow terminals
- **Mitigation**: Use `column -t` for automatic column width adjustment
- **Mitigation**: JSON format always available for machine consumption
- **Mitigation**: Document minimum terminal width recommendation (80 columns)

**Risk 5: Long job names causing misalignment**
- **Impact**: Job names longer than ~25 characters break table formatting
- **Mitigation**: Truncate job names with ellipsis in table format (`${name:0:22}...`)
- **Mitigation**: Full names always available in verbose and JSON formats

### Future Enhancements (Out of Scope)

**Not included in Sprint 8 but could be added later**:
1. **Job filtering**: `--filter status=failed` or `--filter job-name=test`
2. **Summary statistics**: Show counts of jobs by status/conclusion
3. **Step-level watch mode**: Real-time updates for step progress
4. **Diff mode**: Compare job status between two runs
5. **Notification on completion**: Alert when watch mode detects completion
6. **Export to CSV/HTML**: Alternative output formats beyond table/JSON

### Documentation

**Inline help** (`--help` flag):
```
Usage: scripts/view-run-jobs.sh [OPTIONS]

View workflow job phases with status, mimicking 'gh run view' with enhanced flexibility.

INPUT (first match wins):
  --run-id <id>           Workflow run ID (numeric)
  --correlation-id <uuid> Load run_id from stored metadata
  stdin                   JSON from trigger-and-track.sh

OPTIONS:
  --runs-dir <dir>        Base directory for metadata (default: runs)
  --json                  Output JSON format
  --verbose               Include step-level details
  --watch                 Poll for updates until completion (3s interval)
  --help                  Show this help message

EXAMPLES:
  # View jobs for specific run ID
  scripts/view-run-jobs.sh --run-id 1234567890

  # View jobs using correlation ID
  scripts/view-run-jobs.sh --correlation-id <uuid> --runs-dir runs

  # Watch job progress in real-time
  scripts/view-run-jobs.sh --run-id 1234567890 --watch

  # Verbose output with step details
  scripts/view-run-jobs.sh --run-id 1234567890 --verbose

  # JSON output for programmatic use
  scripts/view-run-jobs.sh --run-id 1234567890 --json | jq '.jobs[].name'

  # Integration with trigger-and-track
  scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only \\
    | scripts/view-run-jobs.sh --watch
```

**Implementation notes** (in `sprint_8_implementation.md`):
- Usage examples for each mode (table, verbose, JSON, watch)
- Integration patterns with Sprint 1/3 tooling
- Troubleshooting common issues (authentication, network errors, terminal width)
- Performance characteristics (API calls per watch iteration, rate limit headroom)

### Success Criteria

Sprint 8 implementation is successful when:

1. ✅ `scripts/view-run-jobs.sh` exists and passes `shellcheck` validation
2. ✅ Script retrieves job data using `gh run view --json jobs`
3. ✅ Human-readable table format displays job name, status, conclusion, timestamps
4. ✅ Verbose format displays step-level details
5. ✅ JSON format outputs structured data consumable by `jq`
6. ✅ Watch mode polls every 3 seconds and exits on completion
7. ✅ Integration with Sprint 1: accepts `--correlation-id` and loads from `runs/` metadata
8. ✅ Integration with Sprint 1: accepts stdin JSON from `trigger-and-track.sh`
9. ✅ Integration with Sprint 3: uses `scripts/lib/run-utils.sh` shared functions
10. ✅ Error handling: clear messages for missing run_id, invalid correlation_id, network errors
11. ✅ All manual tests pass (7 test cases documented above)
12. ✅ Documentation complete: inline help, implementation notes, usage examples

### Design Approval

This design document is ready for Product Owner review. Implementation will proceed after approval (status change to "Accepted").
