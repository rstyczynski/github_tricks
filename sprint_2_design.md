# Sprint 2 - design

## GH-4. Workflow log access realtime access
Status: Failed

Description: Clients require access to workflow logs while the run is still executing, not just after completion.

Goal: Deliver a repeatable way to stream in-flight GitHub Actions logs so operators can monitor progress in real time and diagnose failures quickly.

- Introduce CLI helper `scripts/stream-run-logs.sh` that follows an existing workflow run (identified via `--run-id`, a stored metadata file, or `scripts/trigger-and-track.sh` output piped through stdin).
- The helper will:
  - Reuse scripts/trigger-and-track.sh to get GitHub run_id.
  - Stream logs by delegating to `gh run watch --log`, ensuring real-time output identical to GitHub CLI while still supporting stored metadata/resume scenarios.
- Add summary playback support:
  - Provide `--summary` flag to print the most recent job/step statuses (without logs) by inspecting the job list, emulating a lightweight dashboard for slow connections.
  - Detect and warn if the API refuses partial logs (e.g., due to retention policy), guiding the operator to fall back to `gh run watch`.
- Extend `scripts/trigger-and-track.sh` with `--store-dir`, `--workflow`, and `--input key=value` flags to persist run metadata (JSON files keyed by correlation ID), target the long-running workflow, and pass arbitrary workflow_dispatch inputs while always injecting the generated correlation ID.
- Allow `scripts/stream-run-logs.sh` to accept `--run-id-file`, `--runs-dir`, and `--correlation-id` to retrieve stored run IDs from the local metadata repository.
- Introduce a dedicated long-running workflow `.github/workflows/long-run-logger.yml` triggered via `workflow_dispatch` that:
  - Accepts optional `correlation_id`, iteration count, and sleep interval inputs.
  - Emits a log line every few seconds for the requested iterations, enabling realistic streaming tests.
  - Completes with a short final message while preserving earlier sprints' workflows untouched.
- Update documentation in Sprint 3 implementation notes to describe usage patterns:
  - Monitoring a run after capturing the run ID with `scripts/trigger-and-track.sh`.
  - Watching an arbitrary existing run by passing `--run-id` manually.
  - Combining with `WEBHOOK_URL=https://webhook.site/<id>` to observe trigger → log streaming end-to-end.
- Ensure the helper honours repository-authenticated workflows (uses the authenticated `gh` token) and works in environments configured with Podman (no Docker dependency).
