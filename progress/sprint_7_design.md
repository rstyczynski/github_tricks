# Sprint 7 - design

## GH-11. Workflow Webhook as a tool to get run_id

Status: Accepted

Description: Validate a production-ready flow where GitHub’s native webhook system provides the workflow `run_id` immediately after a dispatch, without relying on custom workflow steps. Operators must be able to point GitHub to `WEBHOOK_URL` (for example, a https://webhook.site endpoint), receive signed payloads, and map the resulting `run_id` back to the locally generated correlation identifier.

Goal: Extend the existing tooling so the repository webhook created through GitHub APIs captures `workflow_run` events, surfaces the `workflow_run.id`, and stores the event alongside prior Sprint metadata. The solution must coexist with Sprint 1 correlation scripts and Sprint 3 log storage so operators can choose between polling and webhook-driven tracking.

### Feasibility Analysis

- GitHub repository webhooks can be created and managed through the REST API (`POST /repos/{owner}/{repo}/hooks`, `PATCH /repos/{owner}/{repo}/hooks/{hook_id}`, `DELETE /repos/{owner}/{repo}/hooks/{hook_id}`), which is exposed via `gh api` (docs: https://docs.github.com/en/rest/webhooks/repos#create-a-repository-webhook).
- Webhook event `workflow_run` is fired for `workflow_dispatch` runs and delivers `workflow_run.id`, `workflow_run.run_number`, `workflow_run.status`, and the human-readable run name (docs: https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads#workflow_run).
- Payloads are HMAC signed with `X-Hub-Signature-256` when a shared secret is configured, enabling local verification with standard tooling (`openssl`, `python` `hmac`) as recommended by GitHub (docs: https://docs.github.com/en/webhooks-and-events/webhooks/securing-your-webhooks).
- Existing automation already tags workflow `run-name` with the correlation UUID (`Dispatch Webhook (<uuid>)`), so webhook payloads will naturally contain the correlation signal needed to associate events with local metadata.
- No additional GitHub features are required; operators already authenticate with `gh` (Sprint 0) and have workflows plus run-storage directories (Sprints 1 and 3). The only new dependency is the ability to manage repository webhooks and process JSON payloads, both achievable with shell + Python that are presently in use.

### Design

#### Webhook provisioning tooling

- Add `scripts/manage-actions-webhook.sh` to create, inspect, and remove repository webhooks targeting `WEBHOOK_URL`. Subcommands:

  - `register`: Requires `WEBHOOK_URL` and either `GITHUB_WEBHOOK_SECRET` (env) or `--secret-file <path>`. Generates a 64-hex HMAC secret when none exists, stores it in `.webhook/webhook-secret` (gitignored) for reuse, and invokes `gh api` to create a webhook listening on `workflow_run` and `workflow_job` events with `content_type=json`. The created hook id and metadata are saved to `.webhook/active-hook.json` (gitignored).
  - `status`: Uses stored metadata to call `gh api repos/:owner/:repo/hooks/<id>` and display current configuration, verifying that the endpoint matches `WEBHOOK_URL`.
  - `unregister`: Deletes the hook and cleans local metadata. Operates idempotently by checking whether metadata exists before deleting.
- The script will validate prerequisites (`gh`, `jq`, `python3`, `openssl`) via helper checks, reuse the repository name via `gh repo view --json nameWithOwner`, and refuse to overwrite existing hooks unless `--force` is provided. By persisting metadata outside tracked files we avoid committing secrets while ensuring repeatable operator workflows.

#### Event ingestion workflow

- Add `scripts/process-workflow-webhook.sh` to ingest webhook payloads captured from `WEBHOOK_URL`. Inputs:

  - Payload source: `--file <path>` or default stdin so operators can paste raw JSON (e.g., download from webhook.site).
  - Optional headers: `--signature <value>` and `--delivered <id>` allow the script to verify HMAC and record delivery identifiers.
  - Optional override: `--runs-dir` to specify storage root (defaults to `runs`).
- Processing steps:

  1. Load secret from `.webhook/webhook-secret` (or `--secret-file`/env) to verify `X-Hub-Signature-256`. If verification fails the script warns and exits non-zero unless `--skip-verify` is passed (to accommodate webhook.site where secrets may be absent).
  2. Parse JSON to ensure it is a `workflow_run` event, extract `workflow_run.id`, `workflow_run.name`, `workflow_run.run_attempt`, and `workflow_run.status`.
  3. Derive correlation id by parsing the run name: when the pattern `Dispatch Webhook (<uuid>)` is present, capture `<uuid>`; otherwise fall back to `null`.
  4. Write the canonical payload to `runs/<correlation|unknown>/webhook/events/<timestamp>-<delivery>.json` and append a compact summary row to `runs/<correlation|unknown>/webhook/index.json` capturing run id, attempt, status, timestamp, delivery id, and signature validity.
  5. When a correlation id is detected and the `runs/<uuid>.json` metadata file exists (from Sprint 1 tooling), update it in-place to include `"webhook_run_id": "<id>"` and `"webhook_deliveries": [...]` (using `jq` to preserve prior keys). If metadata is absent, create `runs/webhook_orphans/<run_id>.json` so operators can reconcile later.
  6. Emit concise stdout JSON: `{ "correlation_id": "...", "run_id": "...", "status": "...", "verified": true }`, enabling downstream automation or manual confirmation.

- The script will also surface guidance when a webhook payload corresponds to `workflow_job` events (in case the webhook is configured to send them), encouraging the operator to re-run with the correct event type.

#### Correlation-first dispatch helper

- Extend `scripts/trigger-and-track.sh` with a `--webhook-only` flag that skips polling `gh run list` and instead writes the generated correlation UUID plus dispatch metadata to `runs/<uuid>.json` with a placeholder `run_id: null`. The operator can then execute `scripts/process-workflow-webhook.sh` upon receiving the webhook to populate `run_id`. Existing behavior remains default to avoid regressions; the new mode provides a minimal path that mirrors environments where webhook delivery is the authoritative source.
- Add companion utility `scripts/wait-for-webhook.sh` that monitors `runs/<uuid>/webhook/events/` for a new payload (with configurable timeout) and prints the first verified `run_id`. This enables automated demos where the operator syncs webhook.site payloads to disk (e.g., via copy/paste or curl download) and wants local tooling to react once the file appears.

#### Documentation and storage alignment

- Update operator documentation (Sprint 7 implementation notes and tests README) with the new workflow:

  1. Run `scripts/manage-actions-webhook.sh register` to configure GitHub’s webhook pointing to `WEBHOOK_URL`.
  2. Trigger workflow using `scripts/trigger-and-track.sh --webhook-only --store-dir runs`.
  3. When webhook.site receives the payload, download or paste it into a file and process with `scripts/process-workflow-webhook.sh --file payload.json`.
  4. Optionally invoke `scripts/wait-for-webhook.sh --correlation-id <uuid>` to automate detection.

- Introduce `.webhook/` directory (gitignored) to store secrets and hook metadata, ensuring we do not leak credentials while keeping reproducible local state.
- Maintain compatibility with earlier sprint artifacts by only appending data to `runs/<uuid>.json` and storing additional files in dedicated `webhook/` subdirectories.

### Validation

- Static validation: `shellcheck` on all new/modified scripts; ensure `actionlint` still passes (workflows untouched).
- Manual end-to-end test (requires GitHub infrastructure and reachable `WEBHOOK_URL`):

  1. Register webhook with `scripts/manage-actions-webhook.sh register`.
  2. Dispatch workflow using `scripts/trigger-and-track.sh --webhook-only --store-dir runs`.
  3. Capture webhook payload from the configured endpoint, save as `webhook.json`, and process via `scripts/process-workflow-webhook.sh --file webhook.json`.
  4. Confirm the script outputs the `run_id`, updates `runs/<uuid>.json` with `webhook_run_id`, and stores the payload under `runs/<uuid>/webhook/events/`.
  5. Optionally run the existing polling mode to verify the webhook-provided run id matches the polled one.
- Parallel validation: trigger multiple dispatches in quick succession (distinct shells) and ensure each webhook payload is mapped to the correct correlation id, with summaries recorded separately.

### Risks and mitigations

- **External endpoint accessibility**: GitHub must reach `WEBHOOK_URL`. Mitigation: document requirement to use public services (webhook.site, ngrok) and provide `--skip-verify` flag for cases where HMAC secrets are infeasible.
- **Secret management**: Automatically generated secrets must not be committed. Mitigation: store in gitignored `.webhook/` directory and print reminders for operators to back up securely.
- **Payload delivery timing**: Webhook delivery may lag behind dispatch. Mitigation: `scripts/wait-for-webhook.sh` will allow configurable timeout and logging so delays are visible, and operators can fall back to existing polling if needed.
- **Event filtering**: Repository webhooks deliver multiple event types. Mitigation: `scripts/process-workflow-webhook.sh` validates event `action` and aborts when unrelated payloads are supplied, preventing erroneous metadata updates.
