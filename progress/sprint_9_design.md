# Sprint 9 - Design

## GH-12. Use GitHub API to get workflow job phases with status (curl implementation)

Status: Done

Description: Implement GH-12 using API calls with curl. Use token file from ./secrets directory. This is an alternative implementation to Sprint 8, demonstrating direct REST API usage with token-based authentication instead of gh CLI with browser authentication.

Goal: Provide operators with curl-based tooling to retrieve and display workflow job phases with status, maintaining functional parity with Sprint 8's output formats while demonstrating enterprise-grade token authentication pattern and direct REST API interaction.

### Feasibility Analysis

**GitHub REST API Endpoints** (from Sprint 5 research):

Primary endpoint for run details:
- `GET /repos/:owner/:repo/actions/runs/:run_id`
- Returns: run metadata (id, name, status, conclusion, created_at, url)
- Documentation: https://docs.github.com/en/rest/actions/workflow-runs

Primary endpoint for jobs:
- `GET /repos/:owner/:repo/actions/runs/:run_id/jobs`
- Returns: jobs array with steps, status, conclusion, timestamps
- Supports pagination via `per_page` and `page` parameters (default 30, max 100)
- Documentation: https://docs.github.com/en/rest/actions/workflow-jobs

**Authentication Methods**:
- Personal Access Token (PAT) - classic or fine-grained
- Token stored in file: `./secrets/github_token` (or similar)
- Header format: `Authorization: Bearer <token>` or `Authorization: token <token>`
- Alternative: `Authorization: token <token>` (GitHub accepts both formats)

**Required Permissions** (fine-grained token):
- Repository: Actions - Read (required for workflow runs and jobs)
- Or classic token scope: `repo` (full repository access) or `public_repo` (public repos only)

**Available Tools**:
- `curl` - HTTP client (available on all platforms)
- `jq` - JSON processor (already required by Sprint 0)
- `bash` - Shell scripting (standard)
- Standard Unix utilities: `date`, `column`, `printf`, `cat`, `grep`

**Repository Resolution Options**:

1. **Auto-detect from git context** (recommended):
   ```bash
   git config --get remote.origin.url
   # Parse: https://github.com/owner/repo.git or git@github.com:owner/repo.git
   ```

2. **Environment variable**:
   ```bash
   GITHUB_REPOSITORY="owner/repo"
   ```

3. **CLI flag**:
   ```bash
   --repo owner/repo
   ```

4. **Metadata from Sprint 1**:
   - Store owner/repo in `runs/<correlation_id>/metadata.json` during trigger

**Rate Limiting**:
- Authenticated: 5,000 requests/hour (same as Sprint 8)
- Each script invocation: 1-2 API calls (run details + jobs)
- Watch mode: Same as Sprint 8 (20 calls/minute worst case, 1,200/hour)
- Well within rate limits

**Feasibility**: **Fully achievable** - All required APIs, tools, and authentication methods are available and proven working.

### Design

#### Script: `scripts/view-run-jobs-curl.sh`

A new script that retrieves and displays workflow job phases using curl API calls, providing the same functionality as Sprint 8's `view-run-jobs.sh` but with token-based authentication and direct REST API usage.

**Command-line interface**:

```bash
scripts/view-run-jobs-curl.sh [--run-id <id>] [--correlation-id <uuid>] [--runs-dir <dir>] [--repo <owner/repo>] [--token-file <path>] [--json] [--verbose] [--watch]
```

**Parameters**:
- `--run-id <id>` - Workflow run ID (numeric)
- `--correlation-id <uuid>` - Load run_id from stored metadata in `runs/<uuid>/metadata.json`
- `--runs-dir <dir>` - Base directory for metadata (default: `runs`)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected from git if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--json` - Output JSON format instead of human-readable table
- `--verbose` - Include step-level details
- `--watch` - Poll for updates until run completes (refresh every 3 seconds)

**Input priority** (first match wins):
1. `--run-id` explicitly provided
2. `--correlation-id` loads from stored metadata
3. Stdin JSON (from `trigger-and-track.sh` output)
4. Interactive prompt (if terminal)

**Reuse existing patterns** from Sprint 8:
- Output format specifications (table, verbose, JSON, watch)
- CLI interface (similar flags and behavior)
- Integration with `scripts/lib/run-utils.sh` for metadata loading

#### Functionality

**Core operation**:

1. **Load token from file**:
   - Default: `./secrets/github_token`
   - Validate file exists and is readable
   - Read token (strip whitespace)
   - Mask token in error messages for security

2. **Resolve repository owner/name**:
   - Auto-detect from `git config --get remote.origin.url`
   - Parse GitHub URLs (HTTPS and SSH formats)
   - Fallback to `--repo` flag if provided
   - Fallback to `GITHUB_REPOSITORY` env var
   - Error if cannot resolve

3. **Resolve run_id** (same as Sprint 8):
   - From `--run-id` flag
   - From `--correlation-id` loading metadata
   - From stdin JSON
   - From interactive prompt

4. **Fetch run data via curl**:
   ```bash
   curl -s -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id"
   ```

5. **Fetch jobs data via curl**:
   ```bash
   curl -s -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/jobs?per_page=100"
   ```

6. **Parse JSON with jq** and **format output**:
   - Table format (default)
   - Verbose format (with steps)
   - JSON format
   - Watch mode (poll every 3s)

**Output formats** (same as Sprint 8):

**Format 1: Human-readable table (default)**
```
Run: 1234567890 (Dispatch Webhook (uuid))
Status: in_progress
Started: 2025-01-15 10:30:00 UTC
URL: https://github.com/owner/repo/actions/runs/1234567890

Job                    Status        Conclusion    Started              Completed
--------------------- ------------- ------------- -------------------- --------------------
emit                  in_progress   -             2025-01-15 10:30:05  -
```

**Format 2: Verbose with steps (--verbose)**
```
Run: 1234567890 (Dispatch Webhook (uuid))
Status: in_progress
Started: 2025-01-15 10:30:00 UTC
URL: https://github.com/owner/repo/actions/runs/1234567890

Job: emit
  Status: in_progress
  Started: 2025-01-15 10:30:05

  Step                          Status        Conclusion    Duration
  ----------------------------- ------------- ------------- --------
  1. Set up job                 completed     success       2s
  2. actions/github-script@v7   in_progress   -             -
```

**Format 3: JSON output (--json)**
```json
{
  "run_id": 1234567890,
  "run_name": "Dispatch Webhook (uuid)",
  "status": "in_progress",
  "conclusion": null,
  "started_at": "2025-01-15T10:30:00Z",
  "completed_at": null,
  "url": "https://github.com/owner/repo/actions/runs/1234567890",
  "jobs": [...]
}
```

**Format 4: Watch mode (--watch)**
- Clears screen and re-displays every 3 seconds
- Exits when run status reaches terminal state (completed/cancelled/failed)
- Uses same curl calls with polling loop

#### Implementation Details

**Script structure**:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Source shared utilities (for correlation metadata loading)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/run-utils.sh"

# Default values
TOKEN_FILE="./secrets/github_token"
RUNS_DIR="runs"
OUTPUT_FORMAT="table"
VERBOSE=false
WATCH=false
RUN_ID=""
CORRELATION_ID=""
REPO=""

# Parse arguments
# Load token from file
# Resolve repository (auto-detect or from flag)
# Resolve run_id (reuse Sprint 8 patterns)
# Fetch data via curl
# Format and display output
# Handle watch mode loop if enabled
```

**Key functions**:

- `load_token(token_file)` - Read token from file, validate, return token string
- `resolve_repository()` - Auto-detect from git or use flag/env
- `parse_github_url(url)` - Extract owner/repo from GitHub URL
- `resolve_run_id()` - Reuse Sprint 8 logic with run-utils.sh
- `fetch_run_data(owner, repo, run_id, token)` - curl call to /runs/:run_id
- `fetch_jobs_data(owner, repo, run_id, token)` - curl call to /runs/:run_id/jobs
- `merge_run_and_jobs(run_json, jobs_json)` - Combine responses for formatting
- `format_table(data)` - Same as Sprint 8
- `format_verbose(data)` - Same as Sprint 8
- `format_json(data)` - Same as Sprint 8
- `calculate_duration(started, completed)` - Same as Sprint 8
- `watch_loop(owner, repo, run_id, token, format_func)` - Poll loop with 3s interval

**Token file handling**:
```bash
load_token() {
  local token_file="$1"

  if [[ ! -f "$token_file" ]]; then
    printf 'Error: Token file not found: %s\n' "$token_file" >&2
    printf 'Create a GitHub token and save it to %s\n' "$token_file" >&2
    exit 1
  fi

  if [[ ! -r "$token_file" ]]; then
    printf 'Error: Token file not readable: %s\n' "$token_file" >&2
    exit 1
  fi

  local token
  token=$(cat "$token_file" | tr -d '[:space:]')

  if [[ -z "$token" ]]; then
    printf 'Error: Token file is empty: %s\n' "$token_file" >&2
    exit 1
  fi

  printf '%s' "$token"
}
```

**Repository resolution**:
```bash
resolve_repository() {
  # 1. Check --repo flag
  if [[ -n "$REPO" ]]; then
    printf '%s' "$REPO"
    return 0
  fi

  # 2. Check GITHUB_REPOSITORY env var
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    printf '%s' "$GITHUB_REPOSITORY"
    return 0
  fi

  # 3. Auto-detect from git remote
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if [[ -n "$remote_url" ]]; then
      parse_github_url "$remote_url"
      return 0
    fi
  fi

  printf 'Error: Cannot determine repository (use --repo owner/repo)\n' >&2
  exit 1
}

parse_github_url() {
  local url="$1"
  # HTTPS: https://github.com/owner/repo.git
  # SSH: git@github.com:owner/repo.git

  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    printf '%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  else
    printf 'Error: Cannot parse GitHub URL: %s\n' "$url" >&2
    exit 1
  fi
}
```

**curl API call with error handling**:
```bash
fetch_run_data() {
  local owner="$1"
  local repo="$2"
  local run_id="$3"
  local token="$4"
  local max_retries=3
  local retry_count=0
  local backoff=1

  while [[ $retry_count -lt $max_retries ]]; do
    local response http_code
    response=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id")

    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
      printf '%s' "$response"
      return 0
    elif [[ "$http_code" == "401" ]]; then
      printf 'Error: Unauthorized - check token permissions\n' >&2
      exit 1
    elif [[ "$http_code" == "404" ]]; then
      printf 'Error: Run ID %s not found in %s/%s\n' "$run_id" "$owner" "$repo" >&2
      exit 1
    elif [[ "$http_code" == "403" ]]; then
      printf 'Error: Rate limit exceeded or forbidden\n' >&2
      exit 1
    fi

    retry_count=$((retry_count + 1))
    if [[ $retry_count -lt $max_retries ]]; then
      sleep "$backoff"
      backoff=$((backoff * 2))
    fi
  done

  printf 'Error: Failed to fetch run data after %d attempts\n' "$max_retries" >&2
  exit 1
}
```

**Jobs data fetching** (with pagination handling):
```bash
fetch_jobs_data() {
  local owner="$1"
  local repo="$2"
  local run_id="$3"
  local token="$4"

  # Fetch with per_page=100 (max allowed)
  # Most workflows have < 100 jobs, so pagination rarely needed
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/jobs?per_page=100")

  http_code=$(echo "$response" | tail -n1)
  response=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    printf '%s' "$response"
    return 0
  fi

  printf 'Error: Failed to fetch jobs data (HTTP %s)\n' "$http_code" >&2
  exit 1
}
```

**Merge run and jobs data**:
```bash
merge_run_and_jobs() {
  local run_data="$1"
  local jobs_data="$2"

  # Extract jobs array from jobs_data and merge with run_data
  jq -s '{
    run_id: .[0].id,
    run_name: .[0].name,
    status: .[0].status,
    conclusion: .[0].conclusion,
    started_at: .[0].created_at,
    completed_at: .[0].updated_at,
    url: .[0].html_url,
    jobs: .[1].jobs
  }' <(echo "$run_data") <(echo "$jobs_data")
}
```

**Error handling**:
- Token file missing/unreadable: Clear error with path
- Token empty: Clear error
- Repository resolution failed: Clear error with suggestions
- HTTP 401 (Unauthorized): "Check token permissions"
- HTTP 404 (Not found): "Run ID not found in owner/repo"
- HTTP 403 (Rate limited): "Rate limit exceeded"
- HTTP 5xx: Retry with exponential backoff
- Network errors: Retry with exponential backoff
- JSON parsing errors: Clear error with jq output
- All errors exit with non-zero status

**Status/Conclusion mapping** (same as Sprint 8):
- Status values: `queued`, `in_progress`, `completed`, `waiting`
- Conclusion values: `success`, `failure`, `cancelled`, `skipped`, `neutral`, `timed_out`, `action_required`
- Display `-` for null conclusion (in-progress jobs)

### Integration with Existing Tooling

**With Sprint 1 (trigger-and-track.sh)**:
```bash
# Trigger and immediately view job status
result=$(scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only)
echo "$result" | scripts/view-run-jobs-curl.sh --json

# Or using correlation ID
correlation_id=$(echo "$result" | jq -r '.correlation_id')
scripts/view-run-jobs-curl.sh --correlation-id "$correlation_id" --runs-dir runs --watch
```

**With Sprint 3 (fetch-run-logs.sh)**:
```bash
# View job status before fetching logs
scripts/view-run-jobs-curl.sh --correlation-id "$correlation_id" --runs-dir runs

# Wait for completion, then fetch logs
scripts/view-run-jobs-curl.sh --correlation-id "$correlation_id" --watch
scripts/fetch-run-logs.sh --correlation-id "$correlation_id" --runs-dir runs
```

**With Sprint 8 (view-run-jobs.sh)**:
```bash
# Both scripts can be used interchangeably (same output formats)
scripts/view-run-jobs.sh --run-id 123456  # gh CLI version
scripts/view-run-jobs-curl.sh --run-id 123456  # curl version

# Same JSON output structure for compatibility
```

### Validation Strategy

**Static validation**:
```bash
shellcheck scripts/view-run-jobs-curl.sh
actionlint  # Ensure no workflow changes
```

**Manual testing** (requires GitHub repository access and token):

**Test 0: Token file setup**
```bash
# Create token file
mkdir -p ./secrets
echo "ghp_your_token_here" > ./secrets/github_token
chmod 600 ./secrets/github_token

# Verify token works
curl -H "Authorization: Bearer $(cat ./secrets/github_token)" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/user
```

**Test 1: Basic job status retrieval**
```bash
# Trigger workflow and get run_id
result=$(scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only)
run_id=$(echo "$result" | jq -r '.run_id')

# View job status with curl version
scripts/view-run-jobs-curl.sh --run-id "$run_id"
```
Expected: Table with job name, status, timestamps, URL

**Test 2: Repository auto-detection**
```bash
# Should auto-detect repo from git context
scripts/view-run-jobs-curl.sh --run-id "$run_id"

# Verify detected repo
git config --get remote.origin.url
```
Expected: Correct repository detected and used in API calls

**Test 3: Verbose output with steps**
```bash
scripts/view-run-jobs-curl.sh --run-id "$run_id" --verbose
```
Expected: Job details with step-level breakdown

**Test 4: JSON output for programmatic use**
```bash
scripts/view-run-jobs-curl.sh --run-id "$run_id" --json | jq '.jobs[].name'
```
Expected: JSON with jobs array, pipe to jq should extract job names

**Test 5: Integration with correlation**
```bash
correlation_id=$(echo "$result" | jq -r '.correlation_id')
scripts/view-run-jobs-curl.sh --correlation-id "$correlation_id" --runs-dir runs
```
Expected: Loads run_id from metadata, displays job status

**Test 6: Watch mode (real-time monitoring)**
```bash
# Trigger long-running workflow
scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --input iterations=10 --input sleep_seconds=5 \
  --store-dir runs --json-only > run.json

# Watch job progress with curl version
correlation_id=$(jq -r '.correlation_id' run.json)
scripts/view-run-jobs-curl.sh --correlation-id "$correlation_id" --runs-dir runs --watch
```
Expected: Screen refreshes every 3s, job status updates, exits when complete

**Test 7: Error handling - missing token**
```bash
mv ./secrets/github_token ./secrets/github_token.bak
scripts/view-run-jobs-curl.sh --run-id "$run_id"
mv ./secrets/github_token.bak ./secrets/github_token
```
Expected: Clear error message about missing token file

**Test 8: Error handling - invalid token**
```bash
echo "invalid_token" > ./secrets/github_token.test
scripts/view-run-jobs-curl.sh --run-id "$run_id" --token-file ./secrets/github_token.test
```
Expected: HTTP 401 error with message "Unauthorized - check token permissions"

**Test 9: Error handling - invalid run ID**
```bash
scripts/view-run-jobs-curl.sh --run-id 9999999999
```
Expected: HTTP 404 error with message "Run ID not found"

**Test 10: Explicit repository specification**
```bash
scripts/view-run-jobs-curl.sh --run-id "$run_id" --repo "rstyczynski/github_tricks"
```
Expected: Uses explicit repo, ignores git auto-detection

**Test 11: Output format parity with Sprint 8**
```bash
# Compare outputs
scripts/view-run-jobs.sh --run-id "$run_id" --json > sprint8.json
scripts/view-run-jobs-curl.sh --run-id "$run_id" --json > sprint9.json
diff <(jq -S . sprint8.json) <(jq -S . sprint9.json)
```
Expected: Identical JSON structure (same schema)

### Compatibility with Previous Sprints

**Sprint 1 compatibility**:
- ✅ Reads `runs/<correlation_id>/metadata.json` format (via run-utils.sh)
- ✅ Accepts JSON from `trigger-and-track.sh --json-only` via stdin
- ✅ Uses same `--runs-dir` and `--correlation-id` CLI patterns

**Sprint 3 compatibility**:
- ✅ Sources `scripts/lib/run-utils.sh` for metadata loading
- ✅ Follows same error handling patterns
- ✅ Complements log retrieval (view jobs before/after fetching logs)

**Sprint 8 compatibility**:
- ✅ Same output format schema (table, verbose, JSON)
- ✅ Same CLI interface (similar flags)
- ✅ Interchangeable usage for end users
- ✅ JSON output structure identical for programmatic compatibility

### Use Cases

**Use Case 1: Direct API usage without gh CLI**
```bash
# Environment where gh CLI not available
scripts/view-run-jobs-curl.sh --run-id 1234567890
```
Operator uses curl-based script in restricted environment.

**Use Case 2: Token-based authentication (CI/CD)**
```bash
# CI/CD pipeline with token in secrets
export TOKEN_FILE=/var/secrets/github_token
scripts/view-run-jobs-curl.sh --run-id 1234567890 --token-file "$TOKEN_FILE"
```
Automated pipeline uses token file authentication.

**Use Case 3: Cross-repo monitoring**
```bash
# Monitor workflow in different repository
scripts/view-run-jobs-curl.sh --run-id 1234567890 --repo "other-owner/other-repo"
```
Operator monitors workflows across multiple repositories.

**Use Case 4: Educational - understanding GitHub API**
```bash
# Learn GitHub REST API patterns
scripts/view-run-jobs-curl.sh --run-id 1234567890 --verbose
# Then inspect script to see curl commands
```
Developers learn direct API interaction patterns.

### Risks and Mitigations

**Risk 1: Token file security**
- **Impact**: Token leaked if file permissions too open
- **Mitigation**: Document recommended file permissions (chmod 600)
- **Mitigation**: Check file permissions in script, warn if too open
- **Mitigation**: Never echo token to stdout/logs (mask in errors)

**Risk 2: Repository auto-detection fails**
- **Impact**: Cannot resolve owner/repo, script fails
- **Mitigation**: Clear error message with fallback options (--repo flag, env var)
- **Mitigation**: Document auto-detection requirements (git remote configured)

**Risk 3: Pagination needed for jobs (>100 jobs)**
- **Impact**: Missing jobs if workflow has >100 jobs
- **Mitigation**: Use per_page=100 (max) to minimize pagination needs
- **Mitigation**: Document limitation (most workflows have <100 jobs)
- **Mitigation**: Future enhancement: handle pagination with Link header

**Risk 4: Token expiration**
- **Impact**: Script fails with 401 after token expires
- **Mitigation**: Clear error message explaining token issue
- **Mitigation**: Document token refresh process

**Risk 5: API response schema changes**
- **Impact**: jq parsing fails if GitHub changes response format
- **Mitigation**: Use GitHub API version header (X-GitHub-Api-Version: 2022-11-28)
- **Mitigation**: Test with real API responses
- **Mitigation**: Error handling for jq parse failures

### Token File Setup Documentation

**Creating a GitHub Personal Access Token**:

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token (classic or fine-grained)
3. Required permissions:
   - Classic: `repo` scope
   - Fine-grained: Actions (Read)
4. Copy token
5. Save to file:
   ```bash
   mkdir -p ./secrets
   echo "ghp_your_token_here" > ./secrets/github_token
   chmod 600 ./secrets/github_token
   ```
6. Add to `.gitignore`:
   ```
   secrets/
   ```

**Token file format**:
```
ghp_1234567890abcdef1234567890abcdef12345678
```
- Single line
- No quotes
- No spaces
- GitHub PAT format: `ghp_` prefix (classic) or `github_pat_` (fine-grained)

### Success Criteria

Sprint 9 implementation is successful when:

1. ✅ `scripts/view-run-jobs-curl.sh` exists and passes `shellcheck` validation
2. ✅ Script uses `curl` for API calls (not `gh` CLI)
3. ✅ Token authentication from file (default: `./secrets/github_token`)
4. ✅ Repository auto-detection from git context
5. ✅ Human-readable table format displays job name, status, conclusion, timestamps, URL
6. ✅ Verbose format displays step-level details with durations
7. ✅ JSON format outputs structured data consumable by `jq`
8. ✅ Watch mode polls every 3 seconds and exits on completion
9. ✅ Integration with Sprint 1: accepts `--correlation-id` and loads from `runs/` metadata
10. ✅ Integration with Sprint 1: accepts stdin JSON from `trigger-and-track.sh`
11. ✅ Error handling: clear messages for token issues, network errors, API errors
12. ✅ All manual tests pass (11 test cases documented above)
13. ✅ Documentation complete: inline help, token setup guide, implementation notes
14. ✅ Output format parity with Sprint 8 (JSON schema identical)

### Design Approval

This design document is ready for Product Owner review. Implementation will proceed after approval (status change to "Accepted").
