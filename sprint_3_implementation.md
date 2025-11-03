# Sprint 3 - Implementation Notes

## GH-5. Workflow log access after run access
Status: Done

- Added shared helper `scripts/lib/run-utils.sh` to centralize run ID and metadata lookups (file, stdin JSON, correlation store).
- Implemented `scripts/fetch-run-logs.sh` that validates the run is completed, downloads the GitHub-generated archive, extracts logs beneath `runs/<correlation>/logs/`, produces a combined transcript, and emits `logs.json` with job/step metadata. Accepts run ID, stored correlation metadata, or stdin JSON.
- Replaced the unusable streaming helper with a stub (`scripts/stream-run-logs.sh`) that informs operators to use the new fetch script since GitHub does not expose live streaming APIs.
- Updated `scripts/test-trigger-and-track.sh` to download logs via the new helper after watching the run to completion, giving an end-to-end example that exercises trigger, correlation, completion, and post-run log retrieval.

## Testing
Status: Done

- Static checks:

```bash
shellcheck scripts/fetch-run-logs.sh scripts/trigger-and-track.sh scripts/test-trigger-and-track.sh scripts/lib/run-utils.sh
actionlint
```

- End-to-end log retrieval (`WEBHOOK_URL` from https://webhook.site, ensure the run finishes before fetching):

```bash
export WEBHOOK_URL=https://webhook.site/<your-id>
scripts/test-trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=6 --input sleep_seconds=5 \
  --store-dir runs
```

- Manual fetch examples:

```bash
# Using correlation metadata stored by trigger-and-track.sh --store-dir runs
scripts/fetch-run-logs.sh --runs-dir runs --correlation-id <uuid> --json

# Using only a known run identifier
scripts/fetch-run-logs.sh --run-id <run_id>
```

- Expired/unauthorized run validation: invoke `scripts/fetch-run-logs.sh --run-id <old_or_invalid_run>` and confirm the script reports HTTP 404/410 with actionable guidance.
