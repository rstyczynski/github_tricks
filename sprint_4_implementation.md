# Sprint 4 - Implementation Notes

## GH-3.1. Test timings of run_id retrieval

Status: Implemented

Implemented timing benchmark script `scripts/benchmark-correlation.sh` that measures the performance of the correlation mechanism from Sprint 1 by wrapping `scripts/trigger-and-track.sh`.

**Script Features**:

- Executes configurable number of test runs (default 10, range 10-30)
- Measures elapsed time from workflow dispatch to run_id resolution
- Uses millisecond-precision timestamps where available
- Collects individual measurements: iteration, correlation_id, run_id, elapsed_ms, timestamp
- Computes statistics: mean, min, max, median using Python
- Outputs human-readable table to stderr and optional JSON to file
- Includes error handling: continues on failures, reports failed runs
- Adds 5-second delay between iterations to avoid rate limiting

**Usage Examples**:

Basic usage with environment variable:

```bash
export WEBHOOK_URL=https://webhook.site/<your-id>
scripts/benchmark-correlation.sh
```

Custom configuration:

```bash
scripts/benchmark-correlation.sh \
  --runs 15 \
  --workflow .github/workflows/dispatch-webhook.yml \
  --webhook-url https://webhook.site/<your-id> \
  --output correlation-timings.json
```

**Example Output**:

```
Benchmark: run_id retrieval timing (10 runs)
Workflow: .github/workflows/dispatch-webhook.yml
Webhook: https://webhook.site/<your-id>

Run   Correlation ID                        Run ID      Elapsed (ms)
---   --------------------------------------  ----------  ------------
1     a1b2c3d4-e5f6-7890-abcd-ef1234567890  1234567890  3245
2     b2c3d4e5-f678-9012-bcde-f12345678901  1234567891  2987
...

Statistics:
  Mean:     3156 ms
  Min:      2876 ms
  Max:      4123 ms
  Median:   3102 ms
```

**Implementation Details**:

- Uses existing `trigger-and-track.sh` without modification via `--json-only` flag
- Parses JSON output with `jq` to extract run_id and correlation_id
- Timing measurement: captures timestamp before/after trigger-and-track invocation
- Falls back to second-precision if millisecond timestamps unavailable
- Python 3 used for statistical calculations to ensure accuracy
- Validates all dependencies at startup: jq, python3, trigger-and-track.sh executable

**Validation**:

Passed shellcheck validation:

```bash
shellcheck scripts/benchmark-correlation.sh
# No errors reported
```

Manual testing requires real GitHub infrastructure:

```bash
# Set webhook endpoint from https://webhook.site
export WEBHOOK_URL=https://webhook.site/<your-unique-id>

# Run benchmark with default settings (10 runs)
scripts/benchmark-correlation.sh --output results.json

# Verify JSON output structure
jq '.statistics' results.json
```

## GH-5.1. Test timings of execution logs retrieval

Status: Implemented

Implemented timing benchmark script `scripts/benchmark-log-retrieval.sh` that measures the performance of post-run log retrieval from Sprint 3 by triggering workflows to completion, then measuring `scripts/fetch-run-logs.sh` execution time.

**Script Features**:

- Executes configurable number of test runs (default 10, range 10-30)
- Triggers `long-run-logger.yml` with minimal iterations (3 iterations, 2s sleep = ~6-8s runtime)
- Waits for workflow completion using `gh run watch` (not measured)
- Measures only log retrieval phase: time from completion to logs downloaded/extracted
- Collects individual measurements: iteration, correlation_id, run_id, elapsed_ms, log_size_kb, timestamp
- Computes statistics: mean, min, max, median using Python
- Outputs human-readable table to stderr and optional JSON to file
- Includes error handling: continues on failures, reports failed runs
- Adds 10-second delay between iterations to allow GitHub to finalize log archives

**Usage Examples**:

Basic usage with environment variable:

```bash
export WEBHOOK_URL=https://webhook.site/<your-id>
scripts/benchmark-log-retrieval.sh
```

Custom configuration:

```bash
scripts/benchmark-log-retrieval.sh \
  --runs 15 \
  --webhook-url https://webhook.site/<your-id> \
  --store-dir runs \
  --output log-retrieval-timings.json
```

**Example Output**:

```
Benchmark: Log retrieval timing (10 runs)
Workflow: .github/workflows/long-run-logger.yml
Webhook: https://webhook.site/<your-id>
Store Directory: runs

Run   Correlation ID                        Run ID      Elapsed (ms)  Log Size (KB)
---   --------------------------------------  ----------  ------------  -------------
1     a1b2c3d4-e5f6-7890-abcd-ef1234567890  1234567890  1234          45
2     b2c3d4e5-f678-9012-bcde-f12345678901  1234567891  1189          46
...

Statistics:
  Mean:     1256 ms
  Min:      1123 ms
  Max:      1456 ms
  Median:   1234 ms
```

**Implementation Details**:

- Uses existing `trigger-and-track.sh` and `fetch-run-logs.sh` without modification
- Workflow triggering includes `--input iterations=3 --input sleep_seconds=2` for predictable, fast completion
- Timing measurement: captures timestamp immediately before/after fetch-run-logs invocation
- Setup phase (trigger + wait for completion) is NOT measured, only log retrieval phase
- Captures log archive size from downloaded `.zip` file for correlation analysis
- Python 3 used for statistical calculations
- Validates all dependencies at startup: jq, gh, python3, both helper scripts executable

**Validation**:

Passed shellcheck validation:

```bash
shellcheck scripts/benchmark-log-retrieval.sh
# No errors reported
```

Manual testing requires real GitHub infrastructure and takes longer due to workflow execution:

```bash
# Set webhook endpoint from https://webhook.site
export WEBHOOK_URL=https://webhook.site/<your-unique-id>

# Run benchmark with default settings (10 runs)
# Note: This will take several minutes due to workflow execution time
scripts/benchmark-log-retrieval.sh --output log-results.json

# Verify JSON output structure
jq '.statistics' log-results.json

# Inspect stored logs and metadata
ls -lh runs/
```

## Testing

Status: Implemented

**Static Validation**:

Both benchmark scripts passed shellcheck validation without errors:

```bash
shellcheck scripts/benchmark-correlation.sh scripts/benchmark-log-retrieval.sh
```

**Manual Testing Guidance**:

Due to the nature of these benchmarks (measuring real GitHub API performance), testing requires:

1. Active GitHub repository with workflows deployed
2. GitHub CLI authenticated (`gh auth status`)
3. Valid webhook endpoint from https://webhook.site

**Test Directory Structure**:

Benchmark test scripts and outputs are organized in the `tests/` directory:

```
tests/
├── README.md                        # Testing documentation
├── run-correlation-benchmark.sh     # GH-3.1 wrapper script
├── run-log-retrieval-benchmark.sh   # GH-5.1 wrapper script
├── correlation-results.json         # GH-3.1 output (gitignored)
└── log-results.json                 # GH-5.1 output (gitignored)
```

**GH-3.1 Testing Steps (Using Wrapper Script)**:

```bash
# 1. Set up webhook endpoint
export WEBHOOK_URL=https://webhook.site/<your-unique-id>

# 2. Run correlation timing benchmark (wrapper script outputs to tests/)
tests/run-correlation-benchmark.sh

# 3. Verify results
jq '.statistics' tests/correlation-results.json
# Expected: mean timing in milliseconds, typically 2000-5000ms depending on GitHub load

# 4. Check for failed runs
jq '.failed_runs' tests/correlation-results.json
# Expected: 0 (all runs should succeed)
```

Alternative (direct script invocation):

```bash
scripts/benchmark-correlation.sh --runs 10 --output tests/correlation-results.json
```

**GH-5.1 Testing Steps (Using Wrapper Script)**:

```bash
# 1. Set up webhook endpoint
export WEBHOOK_URL=https://webhook.site/<your-unique-id>

# 2. Run log retrieval timing benchmark (takes ~15-20 minutes for 10 runs)
tests/run-log-retrieval-benchmark.sh

# 3. Verify results
jq '.statistics' tests/log-results.json
# Expected: mean timing in milliseconds, typically 1000-3000ms depending on log size and GitHub load

# 4. Inspect downloaded logs
ls -lh runs/*/logs/
# Expected: directories containing extracted job logs and combined.log

# 5. Check for failed runs
jq '.failed_runs' tests/log-results.json
# Expected: 0 (all runs should succeed)
```

Alternative (direct script invocation):

```bash
scripts/benchmark-log-retrieval.sh --runs 10 --output tests/log-results.json
```

**Expected Behavior**:

- **GH-3.1**: Measures dispatch-to-correlation latency, includes GitHub API polling delays
- **GH-5.1**: Measures log-download-and-extraction latency after workflow completion
- Both scripts handle transient failures gracefully and report them separately
- Statistics exclude failed runs
- JSON output can be used for further analysis or visualization

**Troubleshooting**:

Common issues and solutions:

1. **Missing webhook URL**: Set `WEBHOOK_URL` environment variable or use `--webhook-url` flag
2. **Authentication errors**: Run `gh auth login` to authenticate GitHub CLI
3. **Rate limiting**: Increase delay between iterations if GitHub returns 429 errors
4. **Workflow not found**: Ensure workflows are committed and pushed to repository
5. **Long execution time**: GH-5.1 requires waiting for workflow completion; 10 runs take ~15-20 minutes

## Documentation

**User-facing documentation** is included in each script via `--help` flag:

```bash
scripts/benchmark-correlation.sh --help
scripts/benchmark-log-retrieval.sh --help
```

**Design documentation**: See `sprint_4_design.md` for detailed design rationale, measurement methodology, and feasibility analysis.

**Dependencies**:

Both scripts require:
- bash (with `set -euo pipefail`)
- jq (JSON parsing)
- python3 (statistical calculations)
- gh (GitHub CLI, authenticated)
- Existing Sprint 1 tooling: `scripts/trigger-and-track.sh`
- Existing Sprint 3 tooling: `scripts/fetch-run-logs.sh` (GH-5.1 only)
- Deployed workflows: `.github/workflows/dispatch-webhook.yml` (GH-3.1), `.github/workflows/long-run-logger.yml` (GH-5.1)

All dependencies are available from Sprint 0 prerequisites guide (`sprint_0_prerequisites.md`).
