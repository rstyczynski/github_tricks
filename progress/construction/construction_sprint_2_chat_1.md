# Construction Review – Sprint 2

- Implemented long-running workflow `.github/workflows/long-run-logger.yml` plus enhancements to `scripts/trigger-and-track.sh` (`--workflow`, `--store-dir`, `--input`, `--json-only`) and `scripts/stream-run-logs.sh` to attempt real-time log streaming.
- Observed GitHub Actions API limitation: `actions/runs/<id>/logs` only refreshes after jobs finish, so no incremental log data is available during execution. Live streaming therefore fails; backlog item GH-4 marked Failed.
- Updated implementation notes to document the failure and provide usage guidance showing logs appear only post-run.
- Tooling (metadata storage, summary mode) verified; requirements dependent on real-time logs remain unmet pending API support.
