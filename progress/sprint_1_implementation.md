# Sprint 1 - Implementation Notes

## GH-2. Trigger GitHub workflow
Status: Implemented

- Added workflow `.github/workflows/dispatch-webhook.yml`:
  - Triggered by `workflow_dispatch` and requires `webhook_url` input while accepting optional `correlation_id` (defaults empty for GH-2).
  - Sets `run-name: Dispatch Webhook (<correlation_id>)` when the token is supplied so runs are searchable in the Actions UI.
  - Emits the run identifier in the first step (`Hello from <run_id>.dispatch`), echoes the correlation ID when present, and exposes it as a job output.
  - Calls `scripts/notify-webhook.sh`, which posts `{ "message": "Hello from <run_id>.notify" }` (plus optional `correlationId`) with retry and timeout settings so the workflow never blocks on the endpoint.
  - Appends `notification-summary.md` contents to the job summary for quick inspection.
- Usage example (from the repo root):

```bash
export WEBHOOK_URL=PASTE # copy "Your unique URL" from https://webhook.site
gh workflow run dispatch-webhook.yml --raw-field webhook_url=$WEBHOOK_URL
# Optional: gh workflow run ... --raw-field correlation_id=$(uuidgen) when testing correlation manually
```

- Keep the webhook.site tab open to watch incoming requests for the copied URL.
- `scripts/notify-webhook.sh` logs the correlation ID when provided via environment variable (used by GH-3) and always succeeds, emitting a GitHub workflow warning if the curl invocation fails after retries.
- Both the workflow command and helper accept the webhook URL via CLI flag; `scripts/trigger-and-track.sh` also reads `WEBHOOK_URL` or interactively prompts, so operators can paste the full `https://webhook.site/<your-id>` endpoint.

## GH-3. Workflow correlation
Status: Implemented

- Added helper `scripts/trigger-and-track.sh` that generates a UUID correlation ID, echoes the webhook URL, shows a spinner with elapsed time + active count, and repeatedly queries `gh run list --workflow dispatch-webhook.yml --json databaseId,name,headBranch,createdAt,status`, using `jq` (`fromdateiso8601`, branch match, status in `queued`/`in_progress`, run-name contains correlation token) to resolve the correct run without inspecting full logs.
- Script resolves the workflow numeric ID before dispatching (via `gh api repos/:owner/:repo/actions/workflows/dispatch-webhook.yml --jq '.id'`) to prevent file-name related 404 responses, first attempts `gh workflow run dispatch-webhook.yml`, and retries with the numeric ID if GitHub still returns 404.
- Script echoes the webhook URL in use so operators can double-check they pasted the intended `https://webhook.site/<your-id>` endpoint.
- Correlation runs appear in the Actions list with `Dispatch Webhook (<correlation_id>)`, making manual inspection straightforward.
- Polling limits:
  - Default timeout 60 seconds (`--timeout` override) and interval 3 seconds (`--interval` override).
  - Filters by branch (`--ref`) defaulting to the current branch.
- Example usage:

```bash
scripts/trigger-and-track.sh --webhook-url $WEBHOOK_URL
```

- To skip the interactive prompt on subsequent runs, export `WEBHOOK_URL=https://webhook.site/<your-id>` before invoking the script.
- Output is JSON, for example:

```json
{"run_id":"1234567890","correlation_id":"a1b2c3d4-e5f6-7a89-b0c1-234d5678ef90"}
```

- Negative test guidance: invoke the helper multiple times concurrently with different `https://webhook.site/<your-id>` URLs (or the same test endpoint) and confirm each run resolves to its own `run_id`. Interrupting the webhook receiver should still return an HTTP status while the workflow continues thanks to retry logic.
- `gh run view <run_id> --log` will contain both `Hello from <run_id>.dispatch` and the `correlationId` lines for manual tracing.

## Testing
Status: Implemented

- Run lint and correlation tests via copy/paste commands:

```bash
# Lint workflow definitions
actionlint

# Correlation E2E (watches run to completion and validates run name)
export WEBHOOK_URL=https://webhook.site/<your-id>
scripts/test-trigger-and-track.sh --webhook-url "$WEBHOOK_URL"
```

- The helper test script triggers the workflow, parses the returned JSON, and fails if:
  - The run name does not contain the correlation UUID.
  - `gh run watch` reports a non-success conclusion.
- For local receivers, swap the webhook URL: `scripts/test-trigger-and-track.sh --webhook-url http://localhost:8080`.
- Execute the helper concurrently from multiple shells to ensure unique correlation per run.
