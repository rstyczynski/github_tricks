# Sprint 1 - design

## GH-2. Trigger GitHub workflow
Status: Implemented

Description: User triggers GitHub Workflow that manifests its progress via webhooks with a basic retry policy that never blocks the endpoint. Workflow emits `Hello from <id>.<step>`.

Goal: Let the user trigger a GitHub Workflow that reports its progress through webhooks, guaranteeing retries without blocking the endpoint and emitting `Hello from <id>.<step>`.

- Author a reusable workflow `.github/workflows/dispatch-webhook.yml` triggered by `workflow_dispatch` with required input `webhook_url` and optional `correlation_id` (empty by default for GH-2 usage). Use `run-name` to append the correlation ID when provided so runs are easy to spot in the Actions UI.
- Workflow structure:
  - Job `emit` runs on `ubuntu-latest`.
  - First step uses an `actions/github-script@v7` step to emit `Hello from <run_id>.dispatch` to the workflow log, echo the optional correlation ID, and expose `${{ github.run_id }}` via job outputs for logging only.
  - Second step invokes a shell script (`scripts/notify-webhook.sh`) that posts JSON `{ "message": "Hello from <run_id>.<step>" }` to the provided webhook. Use `curl` with `--retry 5 --retry-all-errors --max-time 5` to satisfy the “basic retry policy” requirement and ensure the workflow never blocks on an unresponsive endpoint (capture failures, convert to warnings).
  - Third step emits a terminal summary with the webhook response status to aid manual tracing.
- Provide documentation snippet in sprint notes showing how to trigger via `gh workflow run dispatch-webhook.yml --raw-field webhook_url=https://webhook.site/<your-id>` (with `--raw-field correlation_id=` omitted for GH-2) using a unique endpoint from webhook.site.
- Place reusable shell logic under `scripts/` and make it idempotent, using `trap` to clean temporary files when writing payloads.

## GH-3. Workflow correlation
Status: Implemented

Description: Triggering GitHub workflow returns “accepted” without a job identifier. Apply a best practice to obtain the GitHub workflow `id`, either by injecting data into the request or gathering it asynchronously.

Goal: Apply a best practice that surfaces the GitHub workflow run identifier after triggering so clients can follow up with API calls despite the initial “accepted” response.

- Extend operational tooling with a helper (`scripts/trigger-and-track.sh`) that:
  1. Accepts the webhook URL via CLI flag, `WEBHOOK_URL` env var, or interactive prompt, encouraging use of a dedicated `https://webhook.site/<your-id>` endpoint.
  2. Resolves the numeric workflow ID by calling `gh api repos/:owner/:repo/actions/workflows/dispatch-webhook.yml --jq '.id'` to avoid file-name cache issues.
  3. Generates a UUID correlation token and stores it locally.
  4. Attempts to dispatch via `gh workflow run dispatch-webhook.yml`; if GitHub responds with `404 Not Found`, retry with the numeric workflow ID. Both paths include `webhook_url` and `correlation_id` inputs so the webhook payload contains the token.
  5. Polls `gh run list --workflow dispatch-webhook.yml --json databaseId,name,headBranch,createdAt,status` and uses `jq` (`fromdateiso8601`, branch match, `status` in `queued`/`in_progress`, run-name contains correlation token) to find the first run created after dispatch. Spinner feedback reports elapsed time and how many active runs were examined.
  6. Returns the resolved `run_id` and prints it to stdout as JSON `{ "run_id": <id>, "correlation_id": "<uuid>" }`.
- Adjust `scripts/notify-webhook.sh` to include the correlation token when `CORRELATION_ID` is set, keeping backward compatibility if the variable is absent.
- To support parallel triggers, the polling loop:
  - Records the dispatch timestamp before triggering and restricts search to runs created after that timestamp.
  - Limits polling duration (e.g., 60 seconds) with 3-second intervals; if no run matches, prints an error to stderr and exits non-zero.
  - Uses `jq` to parse the workflow run list and ensures unique match (guards against duplicates by verifying `id`, `status`, and presence of the correlation token).
- Document negative test guidance: spawn multiple concurrent invocations of the helper against distinct `https://webhook.site/<your-id>` URLs (or the same endpoint) and verify each resolves to its own run ID.
- Add `README` section (later) describing how other clients can implement the correlation strategy using direct REST API calls if `gh` is unavailable.
