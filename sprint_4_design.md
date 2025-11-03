# Sprint 4 - design

## GH-3.1. Test timings of run_id retrieval

Status: Done

Description: Execute series of tests of products "GH-3. Workflow correlation" to find out typical delay time to retrieve run_id. Execute 10-20 jobs measuring run_id retrieval time. Present each timing and compute mean value.

Goal: Measure and characterize the performance of the correlation mechanism delivered in Sprint 1, specifically the time required to resolve a workflow run_id after dispatching a workflow.

### Feasibility Analysis

The requirement is fully feasible using existing GitHub APIs and tooling:

- GitHub CLI (`gh workflow run`, `gh run list`) provides reliable workflow dispatch and run querying capabilities (documented at https://cli.github.com/manual/gh_workflow_run and https://cli.github.com/manual/gh_run_list).
- Sprint 1's `scripts/trigger-and-track.sh` already implements the correlation mechanism using UUID-based run-name matching and polling via `gh run list`.
- Shell-based timing measurement is available through `date +%s` (epoch seconds) or `date +%s%3N` (milliseconds where supported).
- Statistical computation (mean) can be performed using standard Unix utilities (`awk`, `bc`) or Python for precision.
- No GitHub API limitations prevent this measurement; polling frequency and timeout are configurable in the existing script.

References:
- GitHub CLI manual: https://cli.github.com/manual/
- `trigger-and-track.sh` implementation: sprint_1_implementation.md

### Design

Create a timing benchmark script `scripts/benchmark-correlation.sh` that wraps `scripts/trigger-and-track.sh` to measure run_id retrieval performance across multiple executions.

**Script Interface**:

```bash
scripts/benchmark-correlation.sh [--runs <count>] [--workflow <file>] [--webhook-url <url>] [--output <file>]
```

**Parameters**:
- `--runs <count>`: Number of test iterations (default: 10, min: 10, max: 30)
- `--workflow <file>`: Target workflow (default: `.github/workflows/dispatch-webhook.yml`)
- `--webhook-url <url>`: Webhook endpoint for notifications (reads from `WEBHOOK_URL` env if not provided)
- `--output <file>`: Write timing results to JSON file (optional, in addition to stdout)

**Measurement Methodology**:

1. For each iteration (1 to N):
   - Record start timestamp (T1) using `date +%s%3N` (milliseconds precision if available, fallback to seconds)
   - Invoke `scripts/trigger-and-track.sh --webhook-url <url> --workflow <workflow> --json-only`
   - Capture JSON output containing `run_id` and `correlation_id`
   - Record end timestamp (T2) immediately after successful response
   - Calculate elapsed time: `elapsed = T2 - T1` (milliseconds or seconds)
   - Store tuple: `(iteration, correlation_id, run_id, elapsed_ms, timestamp)`

2. After all iterations complete:
   - Compute statistics: mean, min, max, median (if sorted)
   - Output individual measurements as table (human-readable) and JSON (machine-readable)
   - Report summary statistics

**Output Format**:

Terminal output (human-readable):
```
Benchmark: run_id retrieval timing (N runs)
Workflow: .github/workflows/dispatch-webhook.yml
Webhook: https://webhook.site/<id>

Run  Correlation ID                        Run ID      Elapsed (ms)
---  ------------------------------------  ----------  ------------
1    a1b2c3d4-e5f6-7890-abcd-ef1234567890  1234567890  3245
2    b2c3d4e5-f678-9012-bcde-f12345678901  1234567891  2987
...
N    ...                                    ...         ...

Statistics:
  Mean:     3156 ms
  Min:      2876 ms
  Max:      4123 ms
  Median:   3102 ms
```

JSON output (machine-readable, written to file if `--output` specified):
```json
{
  "benchmark": "run_id_retrieval",
  "workflow": ".github/workflows/dispatch-webhook.yml",
  "webhook_url": "https://webhook.site/<id>",
  "runs": 10,
  "timestamp": "2025-01-15T10:30:00Z",
  "measurements": [
    {
      "iteration": 1,
      "correlation_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "run_id": "1234567890",
      "elapsed_ms": 3245,
      "timestamp": "2025-01-15T10:30:05Z"
    },
    ...
  ],
  "statistics": {
    "mean_ms": 3156,
    "min_ms": 2876,
    "max_ms": 4123,
    "median_ms": 3102
  }
}
```

**Implementation Details**:

- Use existing `trigger-and-track.sh` without modification; parse its JSON output with `jq`.
- Implement timing using high-resolution timestamps where available (milliseconds preferred).
- Add configurable delay between iterations (default 5 seconds) to avoid rate limiting and allow GitHub to process each run.
- Check for `WEBHOOK_URL` environment variable or require `--webhook-url` flag; fail early if missing.
- Include error handling: if any iteration fails, log the error but continue with remaining runs; report failed iterations in final output.
- Use `awk` or Python for statistical calculations to ensure precision.
- Clean up triggered workflow runs (optional): offer `--cleanup` flag to cancel test runs after correlation succeeds to avoid cluttering Actions history.

**Dependencies**:
- Existing Sprint 1 tooling: `scripts/trigger-and-track.sh`
- GitHub CLI authenticated and configured
- Target workflow deployed in repository
- Valid webhook endpoint (https://webhook.site or local receiver)
- Standard Unix utilities: `jq`, `awk` or Python 3

**Validation Strategy**:
- Test with 10 runs against `dispatch-webhook.yml` on real GitHub infrastructure
- Verify all 10 runs produce valid timing measurements
- Confirm statistics are computed correctly (manual spot-check)
- Run `shellcheck` on the new script
- Ensure existing `trigger-and-track.sh` behavior is unchanged

## GH-5.1. Test timings of execution logs retrieval

Status: Done

Description: Execute series of tests of products "GH-5. Workflow log access after run access" to find out typical delay time to retrieve logs after job execution. Execute 10-20 jobs measuring log retrieval time. Present each timing and compute mean value.

Goal: Measure and characterize the performance of the post-run log retrieval mechanism delivered in Sprint 3, specifically the time required to download and extract workflow logs after a run completes.

### Feasibility Analysis

The requirement is fully feasible using existing GitHub APIs and tooling:

- GitHub Actions API provides deterministic log archive access via `/repos/:owner/:repo/actions/runs/:run_id/logs` endpoint after run completion (documented at https://docs.github.com/en/rest/actions/workflow-runs#download-workflow-run-logs).
- Sprint 3's `scripts/fetch-run-logs.sh` already implements log retrieval with completion validation, download, extraction, and aggregation.
- Log availability timing is observable: GitHub makes archives available shortly after run completion (typically within seconds, subject to infrastructure load).
- Measurement requires completed workflow runs; using `long-run-logger.yml` from Sprint 2 ensures predictable, fast-completing test runs.
- Shell-based timing measurement is available through standard Unix utilities.
- No API limitations prevent this measurement; retry and timeout handling are already implemented in `fetch-run-logs.sh`.

References:
- GitHub Actions API: https://docs.github.com/en/rest/actions/workflow-runs
- `fetch-run-logs.sh` implementation: sprint_3_implementation.md
- `long-run-logger.yml` workflow: sprint_2_implementation.md

### Design

Create a timing benchmark script `scripts/benchmark-log-retrieval.sh` that triggers workflow runs to completion, then measures the time required to retrieve logs using `scripts/fetch-run-logs.sh`.

**Script Interface**:

```bash
scripts/benchmark-log-retrieval.sh [--runs <count>] [--webhook-url <url>] [--output <file>] [--store-dir <dir>]
```

**Parameters**:
- `--runs <count>`: Number of test iterations (default: 10, min: 10, max: 30)
- `--webhook-url <url>`: Webhook endpoint for workflow notifications (reads from `WEBHOOK_URL` env if not provided)
- `--output <file>`: Write timing results to JSON file (optional, in addition to stdout)
- `--store-dir <dir>`: Directory for run metadata and logs (default: `runs`)

**Measurement Methodology**:

1. For each iteration (1 to N):
   - **Setup Phase** (not measured):
     - Invoke `scripts/trigger-and-track.sh --webhook-url <url> --workflow .github/workflows/long-run-logger.yml --input iterations=3 --input sleep_seconds=2 --store-dir <dir> --json-only`
     - Parse JSON output to obtain `run_id` and `correlation_id`
     - Use `gh run watch <run_id> --exit-status` to wait for completion (not measured, setup only)

   - **Measurement Phase**:
     - Record start timestamp (T1) using `date +%s%3N` immediately before log retrieval
     - Invoke `scripts/fetch-run-logs.sh --runs-dir <dir> --correlation-id <correlation_id> --json`
     - Wait for script to complete (download, extract, aggregate logs)
     - Record end timestamp (T2) immediately after successful completion
     - Calculate elapsed time: `elapsed = T2 - T1` (milliseconds or seconds)
     - Store tuple: `(iteration, correlation_id, run_id, elapsed_ms, timestamp, log_size_kb)`

2. After all iterations complete:
   - Compute statistics: mean, min, max, median
   - Output individual measurements as table (human-readable) and JSON (machine-readable)
   - Report summary statistics

**What is Measured**:

The elapsed time includes:
- API call to download log archive (GitHub `/actions/runs/:run_id/logs` endpoint)
- Network transfer time (download `.zip` file)
- Local I/O: write archive to disk, extract contents, read/aggregate logs
- Generation of `combined.log` and `logs.json` metadata

The measurement specifically captures the operator's experience: "How long after I know the run is complete do I have to wait to access the logs?"

**What is NOT Measured**:

- Workflow execution time (controlled variable: `long-run-logger.yml` with fixed iterations)
- Time to trigger and correlate (Sprint 1 concern, tested in GH-3.1)
- Time waiting for completion (setup phase, not the subject of this benchmark)

**Output Format**:

Terminal output (human-readable):
```
Benchmark: Log retrieval timing (N runs)
Workflow: .github/workflows/long-run-logger.yml
Webhook: https://webhook.site/<id>
Store Directory: runs/

Run  Correlation ID                        Run ID      Elapsed (ms)  Log Size (KB)
---  ------------------------------------  ----------  ------------  -------------
1    a1b2c3d4-e5f6-7890-abcd-ef1234567890  1234567890  1234          45
2    b2c3d4e5-f678-9012-bcde-f12345678901  1234567891  1189          46
...
N    ...                                    ...         ...           ...

Statistics:
  Mean:     1256 ms
  Min:      1123 ms
  Max:      1456 ms
  Median:   1234 ms
```

JSON output (machine-readable, written to file if `--output` specified):
```json
{
  "benchmark": "log_retrieval",
  "workflow": ".github/workflows/long-run-logger.yml",
  "webhook_url": "https://webhook.site/<id>",
  "store_dir": "runs",
  "runs": 10,
  "timestamp": "2025-01-15T11:00:00Z",
  "measurements": [
    {
      "iteration": 1,
      "correlation_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "run_id": "1234567890",
      "elapsed_ms": 1234,
      "log_size_kb": 45,
      "timestamp": "2025-01-15T11:01:30Z"
    },
    ...
  ],
  "statistics": {
    "mean_ms": 1256,
    "min_ms": 1123,
    "max_ms": 1456,
    "median_ms": 1234
  }
}
```

**Implementation Details**:

- Use existing `trigger-and-track.sh` and `fetch-run-logs.sh` without modification.
- Target `long-run-logger.yml` with minimal iterations (`--input iterations=3 --input sleep_seconds=2`) to ensure fast, predictable completion (total runtime ~6-8 seconds).
- Use `gh run watch --exit-status` in setup phase to deterministically wait for completion; exit if any run fails.
- Implement timing using high-resolution timestamps where available (milliseconds preferred).
- Add configurable delay between iterations (default 10 seconds) to allow GitHub to finalize log archives and avoid rate limiting.
- Capture log archive size from downloaded `.zip` file for correlation analysis (larger logs may take longer to retrieve).
- Include error handling: if any iteration's log retrieval fails, log the error but continue with remaining runs; report failed iterations separately.
- Use `awk` or Python for statistical calculations.
- Store all run metadata and logs under `--store-dir` (default `runs/`) for post-benchmark inspection.

**Dependencies**:
- Existing Sprint 1 tooling: `scripts/trigger-and-track.sh`
- Existing Sprint 3 tooling: `scripts/fetch-run-logs.sh`, `scripts/lib/run-utils.sh`
- Existing Sprint 2 workflow: `.github/workflows/long-run-logger.yml`
- GitHub CLI authenticated and configured
- Valid webhook endpoint (https://webhook.site or local receiver)
- Standard Unix utilities: `jq`, `awk` or Python 3

**Validation Strategy**:
- Test with 10 runs against `long-run-logger.yml` on real GitHub infrastructure
- Verify all 10 runs complete successfully and logs are retrieved
- Confirm timing measurements exclude setup/completion wait phases
- Confirm statistics are computed correctly (manual spot-check)
- Run `shellcheck` on the new script
- Ensure existing `fetch-run-logs.sh` behavior is unchanged
- Inspect a sample of downloaded logs to verify correctness

## Test Data

Both benchmarks will use the following test configuration:

- **Webhook endpoint**: `https://webhook.site/<operator-provided-id>` (unique endpoint per test session to avoid collisions)
- **Repository**: Current repository (detected via `gh repo view --json nameWithOwner`)
- **Branch**: Current branch (detected via `git branch --show-current` or `--ref` override)
- **Storage directory**: `runs/` (metadata and logs for all test runs)

For GH-3.1:
- **Target workflow**: `.github/workflows/dispatch-webhook.yml` (fast, minimal overhead)
- **Iterations**: 10 (default), adjustable via `--runs`

For GH-5.1:
- **Target workflow**: `.github/workflows/long-run-logger.yml`
- **Workflow inputs**: `iterations=3`, `sleep_seconds=2` (total runtime ~6-8 seconds)
- **Iterations**: 10 (default), adjustable via `--runs`

## Documentation Updates

Both benchmark scripts will include:
- Inline usage documentation (`--help` flag)
- Example invocations in implementation notes
- Interpretation guidance: what the measurements represent and typical expected ranges
- Troubleshooting section: common failure modes (rate limiting, webhook unavailable, authentication issues)

Implementation notes will document how to run the benchmarks and interpret results:
```bash
# GH-3.1: Benchmark correlation timing
export WEBHOOK_URL=https://webhook.site/<your-id>
scripts/benchmark-correlation.sh --runs 10 --output correlation-timings.json

# GH-5.1: Benchmark log retrieval timing
export WEBHOOK_URL=https://webhook.site/<your-id>
scripts/benchmark-log-retrieval.sh --runs 10 --output log-retrieval-timings.json --store-dir runs
```
