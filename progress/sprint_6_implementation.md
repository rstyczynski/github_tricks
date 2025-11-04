# Sprint 6 - Implementation Notes

## GH-10. Use https://api.github.com/repos/owner/repo/actions/jobs/123456/logs API

Status: Progress

- Added `scripts/probe-job-logs.sh`, a helper that triggers (or attaches to) `long-run-logger.yml`, resolves the active job, and captures successive downloads from `GET /repos/:owner/:repo/actions/jobs/<job_id>/logs`. Each sample is stored under `runs/<correlation>/job-logs/` alongside extracted contents and a `samples.json` ledger containing timestamps, job status, archive size, byte/line counts, and checksum comparison for detecting new content.
- Reused metadata helpers from `scripts/lib/run-utils.sh`, extending the library with `ru_file_size_bytes` for portable file-size retrieval. When no `run_id` is supplied, the probe script delegates to `scripts/trigger-and-track.sh --store-dir <runs_dir>` so correlation metadata is persisted automatically.
- Script CLI highlights:
  - `--interval` (default 5s) and `--max-samples` (default 12) control sampling cadence.
  - `--run-id` / `--correlation-id` reuse existing runs; otherwise the tool triggers a fresh execution (webhook defaults to `https://example.invalid/probe` if omitted).
  - `--json` emits a machine-readable summary with metrics (first sample containing logs, first content change, final job status) for automated analysis.
- Each sample records whether new content appeared by hashing extracted log payloads via Python; plain-text responses are persisted as `.log` files, while compressed payloads (zip/gzip) are unpacked under `runs/<correlation>/job-logs/sample_<n>/` for later inspection. Human-readable mode prints a compact table pointing to these artifacts.
- Added defensive polling: if the run reaches `completed` yet the jobs API still returns no entries or surfaces an error message, the script exits gracefully and reports the condition instead of waiting indefinitely. Removed `--silent` from the jobs API poll so results are captured, and switched to streaming downloads (`gh api > file`) to avoid unsupported flags. Repeated 404s while the job is still starting are tolerated until logs become available.

## Testing

Status: Pending

- Static validation:

```bash
shellcheck -x scripts/probe-job-logs.sh scripts/lib/run-utils.sh
```

- Manual experiment (requires authenticated `gh` CLI and live GitHub runners):

```bash
export WEBHOOK_URL=https://webhook.site/<your-id>
scripts/probe-job-logs.sh \
  --webhook-url "$WEBHOOK_URL" \
  --input iterations=8 \
  --input sleep_seconds=5 \
  --interval 5 \
  --max-samples 15 \
  --runs-dir runs \
  --json
```

- Inspect `runs/<correlation>/job-logs/samples.json` to confirm whether in-progress samples contain non-zero log data before completion; the JSON (or table mode) highlights when new content first appears, and `.log` files under each sample directory show the captured output.
