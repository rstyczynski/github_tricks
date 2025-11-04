# Sprint 7 - design

## GH-11. Workflow Webhook as a tool to get run_id

Status: Proposed

Description: Demonstrate a minimal flow where a repository webhook delivers the workflow `run_id` for dispatches so operators can correlate runs without polling APIs.

Goal: Provide lightweight scripts that set up the webhook, capture payloads, and record the resulting `run_id` alongside the correlation identifier generated during dispatch. The solution must reuse existing Sprint 1/3 storage layout (`runs/`) and remain intentionally simple—no secrets, no signature validation.

### Feasibility Analysis

- GitHub repository webhooks can be managed via the REST API exposed by the CLI (`gh api repos/:owner/:repo/hooks`). Creating a hook that listens to `workflow_run` events requires only a target URL and the event list (docs: https://docs.github.com/en/rest/webhooks/repos#create-a-repository-webhook).
- `workflow_run` payloads contain the numeric `workflow_run.id`, the workflow name, and the run name (which already embeds the correlation UUID produced by Sprint 1 tooling).
- Because this sprint is a demo, we can operate without HMAC secrets—GitHub happily delivers unsigned payloads when no secret is provided.
- Existing tooling already writes metadata to `runs/<correlation_id>.json`. We can append the webhook-provided `run_id` to the same file and drop raw payloads under `runs/<correlation_id>/webhook/`.
- Dependencies (`gh`, `jq`, `python3`) are already part of previous sprints, so no extra setup is needed.

### Design

#### Webhook setup helper

- Add `scripts/manage-actions-webhook.sh` with three subcommands:
  - `register`: Requires `WEBHOOK_URL` env var (or `--webhook-url`). Calls `gh api repos/:owner/:repo/hooks -f name=web -F active=true -F events[]=workflow_run -F config.url=<url> -F config.content_type=json`. Stores the resulting hook id in `runs/_webhook_hook.json` for later use and prints friendly instructions.
  - `status`: Reads the stored hook id (if present) and prints current webhook details via `gh api repos/:owner/:repo/hooks/<id>`.
  - `unregister`: Deletes the stored hook id via `gh api repos/:owner/:repo/hooks/<id> -X DELETE` and removes the local file. All metadata lives under `runs/`, which is already gitignored, keeping things simple.
- The script performs only basic checks (ensure `gh`, `jq`, `WEBHOOK_URL`, and stored id exist) and outputs plain text summaries—no secrets, no signature handling.

#### Payload processing

- Add `scripts/process-workflow-webhook.sh` that ingests a payload copied from the webhook receiver (stdin or `--file <path>`). Steps:
  1. Parse JSON with `jq` and confirm the top-level key `workflow_run` exists. If a different event is supplied, print a warning and exit.
  2. Extract `workflow_run.id`, `workflow_run.run_attempt`, `workflow_run.status`, and `workflow_run.name`.
  3. Derive the correlation UUID from the run name pattern `Dispatch Webhook (<uuid>)`; if the pattern is absent, flag `"correlation_id": null`.
  4. Write the raw payload into `runs/<correlation_id_or_unknown>/webhook/<timestamp>.json`, creating directories on demand.
  5. Update (or create) `runs/<correlation_id>.json` with the fields:
     ```json
     {
       "run_id": "...",
       "correlation_id": "...",
       "workflow": "...",
       "repo": "...",
       "stored_at": "...",
       "webhook_run_id": "...",
       "webhook_status": "...",
       "webhook_attempt": ...
     }
     ```
     When the file already exists (from Sprint 1 polling), merge the new keys without disturbing earlier content.
  6. Emit a one-line JSON summary `{ "run_id": ..., "correlation_id": ..., "status": ... }` to stdout for quick confirmation.
- The script deliberately skips authentication checks or signature validation—operators simply download payloads from services like webhook.site and feed them in.

#### Trigger helper tweak

- Extend `scripts/trigger-and-track.sh` with a `--webhook-only` flag. When enabled:
  - Dispatch workflow exactly as today but skip the polling loop.
  - Store metadata in `runs/<correlation_id>.json` with `run_id: null` and a note like `"webhook_pending": true`.
  - Print the correlation identifier so operators know which payload to associate when the webhook arrives.
- Existing behavior remains the default, letting users choose between polling and webhook-based correlation.

### Validation

- Static checks: run `shellcheck` on all new or modified scripts; ensure workflows still pass `actionlint`.
- Manual demo (GitHub-hosted runners required):
  1. `WEBHOOK_URL=https://webhook.site/<id> scripts/manage-actions-webhook.sh register`
  2. `scripts/trigger-and-track.sh --webhook-only --store-dir runs --webhook-url "$WEBHOOK_URL"`
  3. Save the webhook payload from the receiver to `payload.json`.
  4. `scripts/process-workflow-webhook.sh --file payload.json`
  5. Inspect `runs/<correlation_id>.json` to confirm the injected `run_id` matches the payload.
- Optional: run the trigger helper without `--webhook-only` to show the traditional polling approach still works.

### Risks and mitigations

- **Webhook delivery delays**: Payload might arrive after the polling timeout. Mitigation: design keeps existing polling flow available; documentation will encourage patience or fall back to polling.
- **Incorrect payload pasted**: Without signature checks, users could paste unrelated JSON. Mitigation: script clearly warns when `workflow_run` is missing or correlation cannot be derived.
- **Hook drift**: If someone manually deletes or edits the webhook in GitHub, local metadata becomes stale. Mitigation: `status` subcommand surfaces current hook info so operators can re-register quickly.
