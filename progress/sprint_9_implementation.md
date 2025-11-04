# Sprint 9 - Implementation Notes

## GH-12. Use GitHub API to get workflow job phases with status (curl implementation)

Status: Implemented

### Implementation Summary

- Added `scripts/view-run-jobs-curl.sh`, a curl-based companion to Sprint 8’s viewer that surfaces workflow jobs and steps directly through GitHub’s REST API using token authentication from `./secrets`.
- Reused metadata helpers from `scripts/lib/run-utils.sh`, keeping identical CLI ergonomics (`--run-id`, `--correlation-id`, stdin JSON, watch mode, verbose view, JSON export) so operators can swap between gh CLI and curl implementations without workflow changes.
- Implemented repository resolution pipeline (CLI flag → `GITHUB_REPOSITORY` env → git remote parsing) with validation and `.git` normalization to support cross-repo monitoring.
- Added robust HTTP handling: bearer token headers, GitHub API version pinning, retry/backoff for transient 5xx/connection failures, and descriptive errors for 401/403/404 cases without ever leaking token contents.
- Normalized REST responses into the same data shape used by Sprint 8 (databaseId/createdAt/steps[]) so downstream formatters deliver identical table, verbose, and JSON outputs.
- Watch mode now polls with curl while reusing the shared display pipeline, keeping live refresh parity with the gh CLI variant.

### Validation

- ✅ `shellcheck -x scripts/view-run-jobs-curl.sh`
- ℹ️ Manual end-to-end tests require a configured GitHub token plus runnable workflows; follow Sprint 9 design test matrix once credentials and remote infrastructure are available.

### Manual Test Recipes

All commands assume your GitHub PAT lives in `.secrets/token` (adjust or copy to `./secrets/github_token` if preferred) and that it carries the scopes listed in the design. Supply a working webhook endpoint (e.g., from https://webhook.site) in `$WEBHOOK_URL`; the trigger script stores metadata under `runs/<correlation_id>.json`, which is later reused by the viewer.

```bash
# 0) Environment prep
chmod 600 .secrets/token
read -r GITHUB_TOKEN < .secrets/token        # export PAT for gh CLI calls
export GITHUB_TOKEN
WEBHOOK_URL="https://webhook.site/your-uuid" # replace with your webhook URL

# 1) Trigger the dispatcher workflow and capture IDs
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --store-dir runs \
  --json-only)
echo "$result" | jq

run_id=$(echo "$result" | jq -r '.run_id')
correlation_id=$(echo "$result" | jq -r '.correlation_id')

# 2) Table view via curl implementation
scripts/view-run-jobs-curl.sh \
  --run-id "$run_id" \
  --token-file .secrets/token

# 3) Verbose view with step durations
scripts/view-run-jobs-curl.sh \
  --run-id "$run_id" \
  --token-file .secrets/token \
  --verbose

# 4) JSON output for piping into jq
scripts/view-run-jobs-curl.sh \
  --run-id "$run_id" \
  --token-file .secrets/token \
  --json | jq '.jobs[].name'

# 5) Correlation lookup (uses metadata saved in step 1)
scripts/view-run-jobs-curl.sh \
  --correlation-id "$correlation_id" \
  --runs-dir runs \
  --token-file .secrets/token

# 6) Explicit repository override (useful outside local clone)
scripts/view-run-jobs-curl.sh \
  --run-id "$run_id" \
  --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
  --token-file .secrets/token

# 7) Watch mode for live polling (clear-screen refresh)
scripts/view-run-jobs-curl.sh \
  --run-id "$run_id" \
  --token-file .secrets/token \
  --watch
```
