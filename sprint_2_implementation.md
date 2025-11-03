# Sprint 2 - Implementation Notes

## GH-4. Workflow log access realtime access
Status: Progress

- Added `scripts/stream-run-logs.sh` to stream in-flight GitHub Actions logs via `gh api`.
- Script supports `--run-id`, `--run-id-file`, or accepts JSON from `scripts/trigger-and-track.sh`; with `--runs-dir` + `--correlation-id` it loads run metadata stored locally.
- Incrementally tails gzipped job logs, prefixes each line with the job name, and prints a final conclusion message once the run completes.
- `--summary` shows snapshot of run/job statuses without downloading logs; `--once` performs a single poll.
- Extended `scripts/trigger-and-track.sh` with `--store-dir` and `--workflow` to persist run metadata per correlation and target either the dispatch or long-running workflow.
- Added long-running workflow `.github/workflows/long-run-logger.yml` (workflow_dispatch) with configurable iterations and sleep intervals that emits logs every few seconds for realistic streaming tests.
- Example flows:

```bash
# After triggering and correlating (long-running workflow)
export WEBHOOK_URL=PASTE # copy "Your unique URL" from https://webhook.site
scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --workflow .github/workflows/long-run-logger.yml --store-dir runs \
  | scripts/stream-run-logs.sh --interval 2

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
scripts/test-trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --workflow .github/workflows/long-run-logger.yml --store-dir runs \
  | scripts/stream-run-logs.sh --interval 2
```

- Interrupt the receiver or trigger parallel runs to confirm log tails continue updating and correlation remains unique per run. Validate stored metadata by streaming the same run via `--runs-dir runs --correlation-id <uuid>` or `--run-id-file runs/<uuid>.json`.
