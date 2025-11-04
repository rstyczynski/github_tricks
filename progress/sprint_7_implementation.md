# Sprint 7 - Implementation Notes

## GH-11. Workflow Webhook as a tool to get run_id

Status: Failed

Failure reason: GitHub webhook requires PUBLIC endpoint.

- Added `scripts/manage-actions-webhook.sh` to register, inspect, and remove a `workflow_run` repository webhook via `gh api`, caching the hook metadata in `runs/_webhook_hook.json` for easy cleanup.
- Added `scripts/process-workflow-webhook.sh` that accepts webhook payloads (file or stdin), extracts `run_id` and correlation UUID, stores the raw payload under `runs/<correlation>/webhook/`, and updates `runs/<correlation>.json` with the webhook-provided identifiers.
- Updated `scripts/trigger-and-track.sh` with a `--webhook-only` flag to skip polling while storing placeholder metadata so operators can rely purely on incoming webhook payloads.
- Verified shell portability with `shellcheck scripts/manage-actions-webhook.sh scripts/process-workflow-webhook.sh scripts/trigger-and-track.sh`.
- Manual end-to-end validation still pending (requires real GitHub webhook delivery); will document the steps once executed.
