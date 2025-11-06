# Sprint 16 - Design

## GH-23. List workflow artifacts

Status: Proposed

## Overview

Sprint 16 extends workflow management capabilities with artifact listing operations. This sprint implements REST API-based artifact listing using curl, following the pattern established in Sprint 15. The implementation uses token authentication from `./secrets` directory, handles pagination, supports filtering by artifact name, and provides comprehensive error handling.

**Key Design Decisions**:
- Use curl-based REST API approach (following Sprint 15 pattern)
- Token authentication from `./secrets/github_token` or `./secrets/token` file
- Maintain compatibility with existing run_id resolution mechanisms
- Support same CLI interface patterns for seamless integration
- Comprehensive error handling for all HTTP status codes
- Client-side filtering by artifact name (API doesn't support server-side filtering)
- Pagination support via Link headers

## Feasibility Analysis

### GitHub REST API Capabilities

**GH-23 (List Artifacts)** - `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`:
- ✅ API endpoint available and documented
- ✅ Returns paginated list of artifacts
- ✅ Artifact metadata includes:
  - `id` - Artifact ID (numeric)
  - `node_id` - GraphQL node ID
  - `name` - Artifact name
  - `size_in_bytes` - Size in bytes
  - `url` - API URL for artifact
  - `archive_download_url` - Download URL (for GH-24)
  - `expires_at` - Expiration timestamp (ISO 8601)
  - `created_at` - Creation timestamp (ISO 8601)
- ✅ Supports pagination via Link headers or page/per_page query params
- ✅ Error codes: 404 (run not found), 410 (artifacts expired), 401/403 (auth errors)
- Documentation: https://docs.github.com/en/rest/actions/artifacts#list-workflow-run-artifacts

**Limitations**:
- ⚠️ API does not support server-side filtering by artifact name
- ⚠️ Filtering must be done client-side (jq-based)
- ⚠️ Artifacts expire after retention period (default: 90 days)

### Authentication

**Token File Pattern** (from Sprint 15):
- Token stored in: `./secrets/github_token` (default) or `./secrets/token`
- Header format: `Authorization: Bearer <token>`
- Required permissions: `Actions: Read` (classic token) or `Actions: Read` (fine-grained token)

### Repository Resolution

**Auto-detection from git context** (following Sprint 15 pattern):
```bash
git config --get remote.origin.url
# Parse: https://github.com/owner/repo.git or git@github.com:owner/repo.git
```

**Fallback options**:
1. `--repo owner/repo` CLI flag
2. `GITHUB_REPOSITORY` environment variable
3. Error if cannot resolve

### Run ID Resolution

**Input Priority** (following Sprint 15 pattern):
1. `--run-id <id>` - Direct numeric run ID
2. `--correlation-id <uuid>` - Load run_id from `runs/<correlation_id>/metadata.json`
3. Stdin JSON - Parse JSON input for run_id

### Feasibility Conclusion

**Fully achievable** - GH-23 can be implemented:
- ✅ GitHub API provides required endpoint
- ✅ All required operations supported
- ✅ Authentication pattern established (Sprint 15)
- ✅ No platform limitations identified
- ✅ Compatible with existing run_id resolution mechanisms

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│          Sprint 16: REST API Artifact Listing                      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-23: List Artifacts (REST API)                         │ │
│  │                                                            │ │
│  │  Input: --run-id or --correlation-id, [--name-filter],   │ │
│  │         [--paginate]                                      │ │
│  │         ↓                                                  │ │
│  │  GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts │ │
│  │         ↓                                                  │ │
│  │  Filter by name (client-side), paginate if needed         │ │
│  │         ↓                                                  │ │
│  │  Output: Artifact list (table or JSON)                    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Shared Components:                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Token Auth  │  │  Repo Resolve │  │  Error Handle │     │
│  │  (Sprint 15) │  │  (Sprint 15)  │  │  (Sprint 15)  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### GH-23. List workflow artifacts

#### Script Design: `scripts/list-artifacts-curl.sh`

**Command-line Interface**:

```bash
scripts/list-artifacts-curl.sh [--run-id <id>] [--correlation-id <uuid>]
                                [--name-filter <pattern>] [--paginate]
                                [--repo <owner/repo>] [--token-file <path>]
                                [--runs-dir <dir>] [--json] [--help]
```

**Parameters**:
- `--run-id <id>` - Workflow run ID (numeric)
- `--correlation-id <uuid>` - Load run_id from stored metadata
- `--name-filter <pattern>` - Filter artifacts by name (partial match, case-sensitive)
- `--paginate` - Fetch all pages (default: first page only, 30 items)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--runs-dir <dir>` - Base directory for metadata (default: `runs`)
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Input Resolution**:
- Input priority: `--run-id` → `--correlation-id` → stdin JSON
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var
- Run ID: Validate numeric format

**API Request**:

```
GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts?per_page=30&page=1
```

**Response Structure**:

```json
{
  "total_count": 2,
  "artifacts": [
    {
      "id": 123456,
      "node_id": "MDg6QXJ0aWZhY3QxMjM0NTY=",
      "name": "test-artifact",
      "size_in_bytes": 1024,
      "url": "https://api.github.com/repos/owner/repo/actions/artifacts/123456",
      "archive_download_url": "https://api.github.com/repos/owner/repo/actions/artifacts/123456/zip",
      "expires_at": "2025-04-27T12:00:00Z",
      "created_at": "2025-01-27T12:00:00Z"
    }
  ]
}
```

**Output Formats**:

**Human-readable (default)**:
```
Artifacts for run 1234567890:
  ID        Name            Size      Created              Expires
  123456    test-artifact   1.0 KB    2025-01-27 12:00:00  2025-04-27 12:00:00
  123457    build-output    2.5 MB    2025-01-27 12:00:01  2025-04-27 12:00:01

Total: 2 artifacts
```

**JSON output (--json)**:
```json
{
  "run_id": 1234567890,
  "total_count": 2,
  "artifacts": [
    {
      "id": 123456,
      "name": "test-artifact",
      "size_in_bytes": 1024,
      "size_human": "1.0 KB",
      "created_at": "2025-01-27T12:00:00Z",
      "expires_at": "2025-04-27T12:00:00Z",
      "archive_download_url": "https://api.github.com/repos/owner/repo/actions/artifacts/123456/zip"
    }
  ]
}
```

**Implementation Details**:

**1. Resolve run_id**:
```bash
resolve_run_id() {
  local runs_dir="$1"
  local correlation_id="$2"
  
  if [[ -n "$correlation_id" ]]; then
    local metadata_file="$runs_dir/$correlation_id/metadata.json"
    if [[ ! -f "$metadata_file" ]]; then
      printf 'Error: Metadata file not found: %s\n' "$metadata_file" >&2
      exit 1
    fi
    jq -r '.run_id // empty' "$metadata_file"
    return 0
  fi
  
  # Try stdin JSON
  if [[ -t 0 ]]; then
    return 1
  fi
  
  local stdin_data
  stdin_data="$(cat)"
  if [[ -n "$stdin_data" ]]; then
    echo "$stdin_data" | jq -r '.run_id // empty'
    return 0
  fi
  
  return 1
}
```

**2. List artifacts via API**:
```bash
list_artifacts() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  local page="${4:-1}"
  
  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"
  
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/artifacts?per_page=30&page=$page")
  
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | sed '$d')
  
  if [[ "$http_code" != "200" ]]; then
    handle_api_error "$http_code" "$response_body"
    return 1
  fi
  
  echo "$response_body"
  return 0
}
```

**3. Pagination handling**:
```bash
fetch_all_artifacts() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  
  local page=1
  local all_artifacts="[]"
  local has_next=true
  
  while [[ "$has_next" == "true" ]]; do
    local response
    response=$(list_artifacts "$owner_repo" "$run_id" "$token" "$page")
    
    local artifacts
    artifacts=$(echo "$response" | jq -c '.artifacts // []')
    all_artifacts=$(echo "$all_artifacts" "$artifacts" | jq -s 'add')
    
    # Check for next page via Link header or total_count
    local total_count
    total_count=$(echo "$response" | jq -r '.total_count // 0')
    local current_count
    current_count=$(echo "$all_artifacts" | jq 'length')
    
    if [[ $current_count -ge $total_count ]]; then
      has_next=false
    else
      page=$((page + 1))
    fi
  done
  
  echo "$all_artifacts"
}
```

**4. Filter by name**:
```bash
filter_artifacts_by_name() {
  local artifacts_json="$1"
  local name_filter="$2"
  
  if [[ -z "$name_filter" ]]; then
    echo "$artifacts_json"
    return 0
  fi
  
  echo "$artifacts_json" | jq --arg filter "$name_filter" \
    '[.[] | select(.name | contains($filter))]'
}
```

**5. Format human-readable output**:
```bash
format_artifact_table() {
  local artifacts_json="$1"
  
  echo "$artifacts_json" | jq -r '
    "ID\tName\tSize\tCreated\tExpires",
    (.[] | 
      "\(.id)\t\(.name)\t\(.size_in_bytes | . / 1024 | . * 100 | floor / 100) KB\t\(.created_at)\t\(.expires_at)"
    )
  ' | column -t -s $'\t'
}
```

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 200 | Success | N/A (output artifact list) |
| 404 | Run not found | "Run not found (ID: {run_id})" |
| 410 | Artifacts expired | "Artifacts expired for run {run_id}" |
| 403 | Insufficient permissions | "Insufficient permissions to list artifacts" |
| 401 | Authentication failed | "Authentication failed. Check token permissions." |
| Other | Unknown error | "API request failed (HTTP {code})" |

**Exit Codes**:
- `0`: Artifacts listed successfully
- `1`: Error (API error, invalid run_id, missing parameters)
- `2`: Invalid arguments or missing required parameters

## Integration Patterns

### Pattern 1: List Artifacts After Workflow Run

```bash
# Trigger workflow
scripts/trigger-workflow-curl.sh \
  --workflow dispatch-webhook.yml \
  --input webhook_url="$WEBHOOK_URL" \
  --json > trigger.json

correlation_id=$(jq -r '.correlation_id' trigger.json)

# Correlate to get run_id
run_id=$(scripts/correlate-workflow-curl.sh \
  --correlation-id "$correlation_id" \
  --workflow dispatch-webhook.yml \
  --json-only)

# Wait for completion, then list artifacts
scripts/list-artifacts-curl.sh --run-id "$run_id" --json
```

### Pattern 2: Integration with Log Retrieval

```bash
# Fetch logs
scripts/fetch-logs-curl.sh --run-id "$run_id"

# List artifacts
scripts/list-artifacts-curl.sh --run-id "$run_id"
```

### Pattern 3: Filter Artifacts by Name

```bash
# List only artifacts matching pattern
scripts/list-artifacts-curl.sh \
  --run-id "$run_id" \
  --name-filter "build-" \
  --json
```

## Testing Strategy

### GH-23 (List Artifacts)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-23-1 | List artifacts for valid run_id | Returns artifact list |
| GH-23-2 | List artifacts with name filter | Returns filtered artifacts |
| GH-23-3 | List artifacts with pagination | Returns all artifacts across pages |
| GH-23-4 | Invalid run_id | HTTP 404, error message |
| GH-23-5 | Expired artifacts | HTTP 410 or empty list |
| GH-23-6 | Missing required fields | Exit code 2, usage message |
| GH-23-7 | JSON output format | Valid JSON with artifact details |
| GH-23-8 | Auto-detect repository | Uses git config |
| GH-23-9 | Correlation ID input | Loads run_id from metadata |
| GH-23-10 | No artifacts for run | Empty list (total_count: 0) |

## Compatibility with Previous Sprints

**Sprint 1 (GH-2, GH-3)**:
- ✅ Compatible with correlation mechanism (UUID in run-name)
- ✅ Can use run_id from correlation scripts

**Sprint 3 (GH-5)**:
- ✅ Complements log retrieval with artifact discovery
- ✅ Can be used together to get complete workflow output

**Sprint 15 (GH-14, GH-15, GH-16)**:
- ✅ Follows same REST API pattern
- ✅ Reuses token authentication and repository resolution
- ✅ Compatible CLI interface style
- ✅ Can use run_id from correlation scripts

## Risks and Mitigations

### Risk 1: Artifact Availability Timing

**Risk**: Artifacts may not be immediately available after run completion
**Impact**: Listing fails even though artifacts exist
**Mitigation**: Validate run completion before listing, retry logic for 404 errors

### Risk 2: Pagination Complexity

**Risk**: Runs with many artifacts require pagination handling
**Impact**: Script fails to list all artifacts
**Mitigation**: Implement pagination handling via Link headers, support `--paginate` flag

### Risk 3: Artifact Expiration

**Risk**: Artifacts expire after retention period (default: 90 days)
**Impact**: Listing succeeds but artifacts are expired
**Mitigation**: Display expiration date in output, handle 410 errors gracefully

### Risk 4: API Rate Limiting

**Risk**: High-frequency API calls may hit rate limits
**Impact**: HTTP 403 errors
**Mitigation**: Use reasonable API call frequency, handle 403 responses gracefully

### Risk 5: Token Permissions

**Risk**: Token may lack required Actions permissions
**Impact**: HTTP 403 errors
**Mitigation**: Document required permissions, provide clear error messages

## Success Criteria

Sprint 16 design is successful when:

1. ✅ Feasibility analysis confirms GitHub API supports all operations
2. ✅ Script design covers all required functionality for GH-23
3. ✅ CLI interface maintains compatibility with existing scripts
4. ✅ Error handling addresses all HTTP status codes
5. ✅ Output formats (human-readable and JSON) specified
6. ✅ Integration patterns documented
7. ✅ Test strategy covers all scenarios
8. ✅ Risks identified with mitigation strategies
9. ✅ Compatibility with previous sprints maintained

## Documentation

**Implementation Notes** (to be created in construction phase):
- `progress/sprint_16_implementation.md`
- Usage examples for script
- Test execution results

**Script Help** (inline in script):
- `scripts/list-artifacts-curl.sh --help`

## Design Approval

**Status**: Awaiting Product Owner review

This design document is ready for Product Owner review. Implementation will proceed after approval (status change to "Accepted").

**Design addresses**:
- ✅ GH-23: List workflow artifacts with REST API, full metadata support
- ✅ Integration with existing Sprint 1, 3, 15 tooling
- ✅ Comprehensive test strategy
- ✅ Error handling and risk mitigation

