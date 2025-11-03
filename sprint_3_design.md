# Sprint 3 - design

## GH-5. Workflow log access after run access
Status: Accepted

Description: Operators need reliable access to workflow logs once a run has completed, using either a stored correlation token or a known run identifier. Solution must reuse the metadata repository established in Sprint 2, work with existing long-running workflow assets, and support concurrent consumers.

Goal: Provide deterministic tooling that fetches, stores, and presents completed-run logs while remaining compatible with prior correlation scripts and documentation.

- Introduce helper script `scripts/fetch-run-logs.sh` dedicated to post-run log retrieval.
  - Accepts `--run-id`, `--run-id-file`, or `--runs-dir` + `--correlation-id` so it plugs into metadata captured by `trigger-and-track.sh --store-dir` (same CLI affordances as `stream-run-logs.sh`).
  - Confirms the run is in a terminal state via `gh run view --json status,conclusion` before downloading logs, short-circuiting with a warning if the run is still active (and optionally redirecting the operator to `stream-run-logs.sh`).
  - Retrieves the official log archive with `gh api repos/:owner/:repo/actions/runs/<run_id>/logs`, stores the raw `.zip` (default `runs/<correlation_id>/logs/<run_id>.zip`), and extracts its contents into a structured directory (`runs/<correlation_id>/logs/<job_name>/step.log`). Handles cases where only the run ID is provided by deriving an output folder under `runs/<run_id>`.
  - Produces an aggregated plaintext transcript (`combined.log`) by concatenating job/step logs in chronological order, adding job boundaries, and echoes the location to stdout for downstream tooling.
  - Emits a machine-readable JSON summary (`logs.json`) capturing timestamps, job names, conclusion status, and artifact paths to facilitate future automation.
  - Gracefully reports retention/permission errors (HTTP 410/404) with actionable guidance and non-zero exit status.
- Update `scripts/stream-run-logs.sh` for complementary behavior:
  - Detect when invoked for a completed run without `--summary` and direct users to `fetch-run-logs.sh` (keeping backward compatibility but preventing redundant downloads).
  - Share metadata-loading helpers via `. lib/run-utils.sh` if necessary (light refactor) so both scripts read correlation files consistently.
- Extend `scripts/trigger-and-track.sh` documentation (no functional change) noting that `--store-dir` enables one-click log retrieval because `fetch-run-logs.sh` will look for the stored JSON.
- Design documentation additions:
  - Describe default storage layout (`runs/<correlation_id>/metadata.json`, `runs/<correlation_id>/logs/…`) and concurrency expectations (scripts operate on per-correlation subdirectories to avoid collisions).
  - Provide user flow examples: (1) trigger long-run logger -> store metadata -> fetch logs; (2) fetch logs for historical run ID; (3) handle expired logs.
- Validation strategy:
  - `shellcheck` for new/modified scripts.
  - `actionlint` to ensure workflows untouched.
  - Integration walkthrough: trigger `long-run-logger.yml` with `trigger-and-track.sh --store-dir runs`, wait for completion (manual or via helper), invoke `fetch-run-logs.sh --runs-dir runs --correlation-id <uuid>`, verify combined log contains periodic messages and summary JSON references extracted files.
  - Negative test: attempt to fetch logs for in-progress run to confirm early exit, and for an intentionally invalid/expired run ID to confirm clear error messaging.
