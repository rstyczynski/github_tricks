# Sprint 6 - design

## GH-10. Use https://api.github.com/repos/owner/repo/actions/jobs/123456/logs API

Status: Accepted

Description: Reopen Sprint 2’s log-streaming backlog item using the job-level logs endpoint to determine whether it enables live (in-run) access to GitHub Actions logs.

Goal: Run structured experiments against `.github/workflows/long-run-logger.yml` to confirm whether `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` provides incremental log data while a job is executing, and update our tooling/documentation accordingly.

### Feasibility Analysis

- The GitHub REST endpoint `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` is documented to return a ZIP archive of the specified job’s logs (see https://docs.github.com/en/rest/actions/workflow-jobs#download-job-logs). Documentation does not explicitly guarantee availability before job completion, so empirical validation is required.
- We can resolve `job_id` values for an in-progress run using `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs` (exposed via `gh api repos/:owner/:repo/actions/runs/<run_id>/jobs`). This API supports polling while jobs are running.
- Existing Sprint 1 tooling (`scripts/trigger-and-track.sh`) already provides run correlation and stores metadata; Sprint 3 added `scripts/lib/run-utils.sh` for metadata loading. Both can be reused to obtain `run_id` and persist experiment artifacts.
- The long-running workflow `.github/workflows/long-run-logger.yml` emits periodic log lines and is ideal for observing whether mid-run archives change.
- CLI prerequisites (`gh`, `jq`, `unzip`, `curl`) are already covered in Sprint 0 documentation, so no additional tooling is required.
- Risks:
  - API may cache logs and only publish after job completion (as observed for run-level logs).
  - API responses may be large; repeated downloads should be rate-limited to avoid throttling.
  - If job-level archives overwrite rather than append, we must detect whether content length increases during execution.
- Outcome possibilities:
  1. Logs include in-progress content → update tooling to stream by periodically downloading and diffing.
  2. Logs remain empty until completion → document limitation and close hypothesis.

Given API availability and existing tooling, the experiment is feasible. Result is unknown until tested.

### Design

#### High-level approach

1. Trigger `long-run-logger.yml` with configurable sleep/iteration inputs to ensure the job runs long enough for multiple polls.
2. Resolve the job list for the active `run_id` and select the single job (the workflow currently produces one job). Capture its `job_id`, `status`, and `started_at`.
3. Poll the job logs endpoint at configurable intervals during job execution, capturing HTTP status, archive size, and extracted content snapshot for comparison.
4. After job completion, perform a final download to compare against in-run samples.
5. Summarize findings (e.g., whether archive size/content changed mid-run) in implementation notes and, if positive, outline the path to integrate live log streaming in existing scripts.

#### Script additions

- Introduce `scripts/probe-job-logs.sh` to automate the experiment. Responsibilities:
  - Inputs: `--runs-dir`, `--correlation-id`, `--run-id`, `--interval`, `--max-samples`, `--workflow-input` passthrough.
  - Reuse `scripts/trigger-and-track.sh` (invoked internally) when `--run-id` is absent; pass `--store-dir` so metadata lives under `runs/<correlation>/`.
  - Use helpers from `scripts/lib/run-utils.sh` (extend if needed) to load stored metadata and resolve repository owner/repo.
  - Call `gh api repos/:owner/:repo/actions/runs/<run_id>/jobs --paginate --jq '.jobs[] | {id,status,started_at,completed_at,name}'` to retrieve job info each poll.
  - Immediately after retrieving the first `job_id`, download logs via `gh api --method GET --silent --output` (or `curl` using the REST URL). Save each sample as `runs/<correlation>/job-logs/sample_<n>.zip`.
  - After each download, extract to `runs/<correlation>/job-logs/sample_<n>/` and compute:
    - Byte size of ZIP (`stat -f%z` macOS / `stat -c%s` Linux).
    - Byte size / line count of the primary log file (likely `step_summary.txt` or similar).
    - SHA256 checksum to detect identical content.
  - Record sample metadata in `runs/<correlation>/job-logs/samples.json` with timestamp, job status, archive size, checksum, and whether new content appeared compared to previous sample.
  - Continue polling until job status becomes `completed` or `--max-samples` reached. Respect `--interval` (default 5s) and bail if API returns 404/410.
  - Provide `--json` output summarizing findings (e.g., first non-empty sample index, size deltas).

- Update (or create) shared utility functions in `scripts/lib/run-utils.sh` if additional helpers are required (e.g., compressible path resolution). Keep backward compatibility with existing consumers.

- Keep existing `scripts/stream-run-logs.sh` untouched during experiment; only update in implementation phase if the endpoint proves useful.

#### Data collection & analysis

- Store all experiment artifacts under `runs/<correlation>/job-logs/` to avoid interfering with previous sprint outputs (`metadata.json`, `logs/`, etc.).
- Provide a companion summary generator (within the probe script) that prints a table such as:

  ```
  Sample  Timestamp            Job Status    ZIP Size (bytes)  New Content?
  1       2025-02-03T10:00:05Z  in_progress   0                 no
  2       2025-02-03T10:00:10Z  in_progress   0                 no
  3       2025-02-03T10:00:15Z  in_progress   0                 no
  4       2025-02-03T10:00:20Z  completed     12456             yes
  ```

- If the API yields partial content mid-run, include logic to append new lines to stdout (`tail -n+1`). Otherwise, document that all in-progress samples were empty or unchanged.

#### Success criteria

- **Positive finding**: At least one sample captured while `status == "in_progress"` contains non-zero content or differs in checksum from previous sample. Design follow-up: plan modifications to `scripts/stream-run-logs.sh` to reuse job logs polling for near-real-time output.
- **Negative finding**: All samples remain empty (ZIP size zero) or unchanged until `status == "completed"`. Document the limitation with empirical evidence and recommend keeping Sprint 2 conclusion.

#### Validation strategy

- Manual run on GitHub-hosted runners (required) using:

  ```bash
  export WEBHOOK_URL=https://webhook.site/<id>
  scripts/probe-job-logs.sh --webhook-url "$WEBHOOK_URL" --interval 5 --max-samples 12
  ```

- Ensure script handles rate limiting (respect `X-RateLimit-Remaining`) by backing off when remaining calls are low.
- Verify shell portability with `shellcheck` on new/updated scripts.
- Confirm no modifications to workflow YAMLs are necessary; the long-run logger already emits periodic log entries.

#### Documentation updates

- Upon implementation, update `progress/sprint_6_implementation.md` with experiment procedure and findings.
- If API enables live logs, document new usage in README or relevant sprint notes; otherwise, summarize evidence for continued limitation.

