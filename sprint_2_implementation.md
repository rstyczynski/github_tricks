# Sprint 2 - Implementation Notes

## GH-4. Workflow log access realtime access
Status: Failed

**Result**: backlog item cannot be completed with current GitHub API/CLI because active job logs are not accessible in real time.

Tried to implement:
- Added `scripts/stream-run-logs.sh` to poll zipped logs via `gh api`. GitHub only refreshes the archive after jobs finish, so realtime streaming is not achievable with the current API; logs appear only after completion.
- Script supports `--run-id`, `--run-id-file`, or accepts JSON from `scripts/trigger-and-track.sh`; with `--runs-dir` + `--correlation-id` it loads run metadata stored locally.
- Script downloads the archive periodically, emits any new lines (which never change mid-run), and prints the full log once the run completes. No output is observed while the job is running. `--summary` shows a snapshot without logs.
- Extended `scripts/trigger-and-track.sh` with `--store-dir` and `--workflow` to persist run metadata per correlation and target either the dispatch or long-running workflow.
- Added long-running workflow `.github/workflows/long-run-logger.yml` (workflow_dispatch) with configurable iterations and sleep intervals to demonstrate the limitation and to document the failure scenario.

- Example flows:

```bash
# After triggering and correlating (long-running workflow)
export WEBHOOK_URL=PASTE # copy "Your unique URL" from https://webhook.site
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=12 --input sleep_seconds=5 \
  --store-dir runs --json-only \
  | scripts/stream-run-logs.sh

# Stream later using stored metadata
scripts/stream-run-logs.sh --runs-dir runs --correlation-id <uuid>

# Monitor an existing run
scripts/stream-run-logs.sh --run-id <run_id>

# Snapshot statuses once without logs
scripts/stream-run-logs.sh --run-id <run_id> --summary --once

# Trigger long-running logger on demand (no correlation helper)
gh workflow run long-run-logger.yml --raw-field iterations=12 --raw-field sleep_seconds=5 --raw-field correlation_id=$(uuidgen)
```

## Testing
Status: Progress

- Lint scripts:

```bash
shellcheck scripts/stream-run-logs.sh scripts/trigger-and-track.sh scripts/test-trigger-and-track.sh
actionlint
```

- End-to-end log streaming:

```bash
 export WEBHOOK_URL=https://webhook.site/<id>
 scripts/test-trigger-and-track.sh --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=12 --input sleep_seconds=5 \
  --store-dir runs --json-only \
  | scripts/stream-run-logs.sh
```

- Interrupt the receiver or trigger parallel runs to confirm metadata persists. Only final logs are printed after completion; realtime output is not available. Validate stored metadata via `--runs-dir runs --correlation-id <uuid>` or `--run-id-file runs/<uuid>.json`.
