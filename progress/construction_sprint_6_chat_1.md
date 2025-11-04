# Construction Review – Sprint 6 (Chat 1)

## Summary

- Implemented and exercised `scripts/probe-job-logs.sh`, which automates triggering or attaching to `long-run-logger.yml`, polling the run for its job id, and downloading successive payloads from `GET /repos/:owner/:repo/actions/jobs/{job_id}/logs`.
- Added support utilities (`ru_file_size_bytes`) and normalization logic so downloaded payloads are stored as `.log` files with companion metadata in `runs/<correlation>/job-logs/samples.json`.
- Multiple executions confirmed the endpoint only succeeds after the job finishes. During each run the script received repeated `HTTP 404` responses while `status=in_progress`, and the first successful artifact (e.g., `runs/CE7C3B24-DF8E-4281-B836-3F85948B7C21/job-logs/sample_01.log`, `runs/EE7B0BD0-F5A7-48A2-ACCB-A95485C6E2BD/job-logs/sample_01.log`) was captured immediately after `status=completed`. This proves GH-10 cannot deliver real-time logs under current GitHub APIs.
- Updated `progress/sprint_6_implementation.md` to mark the backlog item as **Failed** with references to the captured evidence.

## Verification

- `shellcheck -x scripts/probe-job-logs.sh scripts/lib/run-utils.sh`
- `scripts/probe-job-logs.sh --webhook-url https://webhook.site/533814D4-1F6C-43E3-A005-297E1126AA25 --input iterations=4 --input sleep_seconds=4 --interval 5 --max-samples 6 --runs-dir runs`
- `scripts/probe-job-logs.sh --webhook-url https://webhook.site/533814D4-1F6C-43E3-A005-297E1126AA25 --input iterations=4 --input sleep_seconds=10 --interval 5 --max-samples 6 --runs-dir runs`
