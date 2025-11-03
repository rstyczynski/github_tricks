# Sprint 1 - Implementation Notes

## GH-2. Trigger GitHub workflow
Status: Progress

- Added workflow `.github/workflows/dispatch-webhook.yml`:
  - Triggered by `workflow_dispatch` and requires `webhook_url` input.
  - Emits the run identifier in the first step (`Hello from <run_id>.dispatch`) and exposes it as a job output.
  - Calls `scripts/notify-webhook.sh`, which posts `{ "message": "Hello from <run_id>.notify" }` (plus optional `correlationId`) with retry and timeout settings so the workflow never blocks on the endpoint.
  - Appends `notification-summary.md` contents to the job summary for quick inspection.
- Usage example (from the repo root):

```bash
WEBHOOK_URL=PASTE # copy "Your unique URL" from https://webhook.site
gh workflow run dispatch-webhook.yml --raw-field webhook_url=$WEBHOOK_URL
```

- Keep the webhook.site tab open to watch incoming requests for the copied URL.
- `scripts/notify-webhook.sh` logs the correlation ID when provided via environment variable (used by GH-3) and always succeeds, emitting a GitHub workflow warning if the curl invocation fails after retries.
- Both the workflow command and helper accept the webhook URL via CLI flag; `scripts/trigger-and-track.sh` also reads `WEBHOOK_URL` or interactively prompts, so operators can paste the full `https://webhook.site/<your-id>` endpoint.

## GH-3. Workflow correlation
Status: Progress

- Added helper `scripts/trigger-and-track.sh` that generates a UUID correlation ID, sets `CORRELATION_ID` for the workflow run, and polls for the matching run by scanning workflow logs for the token.
- Script echoes the webhook URL in use so operators can double-check they pasted the intended `https://webhook.site/<your-id>` endpoint.
- Polling limits:
  - Default timeout 60 seconds (`--timeout` override) and interval 3 seconds (`--interval` override).
  - Filters by branch (`--ref`) defaulting to the current branch.
- Example usage:

```bash
scripts/trigger-and-track.sh --webhook-url https://webhook.site/<your-id>
```

- To skip the interactive prompt on subsequent runs, export `WEBHOOK_URL=https://webhook.site/<your-id>` before invoking the script.
- Output is JSON, for example:

```json
{"run_id":"1234567890","correlation_id":"a1b2c3d4-e5f6-7a89-b0c1-234d5678ef90"}
```

- Negative test guidance: invoke the helper multiple times concurrently with different `https://webhook.site/<your-id>` URLs (or the same test endpoint) and confirm each run resolves to its own `run_id`. Interrupting the webhook receiver should still return an HTTP status while the workflow continues thanks to retry logic.
- `gh run view <run_id> --log` will contain both `Hello from <run_id>.dispatch` and the `correlationId` lines for manual tracing.

## Testing
Status: Progress

- `actionlint` is not installed in this environment; run `actionlint` locally after prerequisites are in place to validate `.github/workflows/dispatch-webhook.yml`.
- End-to-end test flow once tooling is installed:
  1. Start a local webhook receiver (e.g., `npx http-echo-server 8080`) **or** obtain a public endpoint from https://webhook.site.
  2. Execute `scripts/trigger-and-track.sh --webhook-url http://localhost:8080` (or use the copied `https://webhook.site/<your-id>`).
  3. Inspect receiver logs (or the webhook.site dashboard) for the `Hello from <run_id>.notify` payload and confirm the script prints matching `run_id`.
  4. Run the helper in parallel windows to verify the correlation filter handles concurrent executions.
