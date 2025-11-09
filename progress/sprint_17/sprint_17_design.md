# Sprint 17 - Design

## GH-24. Download workflow artifacts

Status: Proposed

## Overview

Sprint 17 extends workflow management capabilities with artifact download operations. This sprint implements REST API-based artifact download using curl, following the pattern established in Sprint 15 and building upon Sprint 16's artifact listing feature. The implementation uses token authentication from `./secrets` directory, handles large file downloads with proper streaming, supports downloading individual artifacts or all artifacts for a run, and provides comprehensive error handling.

**Key Design Decisions**:
- Use curl-based REST API approach (following Sprint 15/16 pattern)
- Token authentication from `./secrets/github_token` or `./secrets/token` file
- Support both single artifact and bulk download modes
- Optional ZIP extraction via `--extract` flag
- Maintain compatibility with Sprint 16's artifact listing output
- Support same CLI interface patterns for seamless integration
- Comprehensive error handling for all HTTP status codes
- Streaming downloads for large files (avoid memory issues)

## Feasibility Analysis

### GitHub REST API Capabilities

**GH-24 (Download Artifacts)** - `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip`:
- ✅ API endpoint available and documented
- ✅ Returns ZIP archive containing artifact files
- ✅ Supports HTTP redirect (302) to actual download URL
- ✅ Response headers include Content-Length for progress tracking
- ✅ Compatible with streaming downloads via curl
- ✅ Error codes: 404 (artifact not found), 410 (artifact expired), 401/403 (auth errors)
- Documentation: https://docs.github.com/en/rest/actions/artifacts#download-an-artifact

**API Behavior**:
- Returns 302 redirect to S3-hosted ZIP file
- ZIP archive contains artifact files with original structure
- Content-Disposition header suggests filename
- Artifacts are ZIP compressed by GitHub

**Limitations**:
- ⚠️ No bulk download endpoint (must download each artifact separately)
- ⚠️ Artifacts expire after retention period (default: 90 days)
- ⚠️ No resume support for interrupted downloads

### Authentication

**Token File Pattern** (from Sprint 15/16):
- Token stored in: `./secrets/github_token` (default) or `./secrets/token`
- Header format: `Authorization: Bearer <token>`
- Required permissions: `Actions: Read` (classic token) or `Actions: Read` (fine-grained token)

### Repository Resolution

**Auto-detection from git context** (following Sprint 15/16 pattern):
```bash
git config --get remote.origin.url
# Parse: https://github.com/owner/repo.git or git@github.com:owner/repo.git
```

**Fallback options**:
1. `--repo owner/repo` CLI flag
2. `GITHUB_REPOSITORY` environment variable
3. Error if cannot resolve

### Artifact ID Resolution

**Input Priority**:
1. `--artifact-id <id>` - Direct numeric artifact ID (single download)
2. `--run-id <id>` with `--all` flag - Download all artifacts for run (calls Sprint 16 listing)
3. `--correlation-id <uuid>` with `--all` flag - Load run_id from metadata, then download all
4. Stdin JSON - Parse JSON input for artifact_id or run_id

### Feasibility Conclusion

**Fully achievable** - GH-24 can be implemented:
- ✅ GitHub API provides required endpoint
- ✅ All required operations supported
- ✅ Authentication pattern established (Sprint 15/16)
- ✅ Integration with Sprint 16 for artifact discovery
- ✅ Streaming support via curl
- ✅ No platform limitations identified
- ✅ Compatible with existing run_id/correlation_id resolution mechanisms

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│          Sprint 17: REST API Artifact Download                   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  GH-24: Download Artifacts (REST API)                     │   │
│  │                                                             │   │
│  │  Input: --artifact-id or --run-id --all,                  │   │
│  │         [--extract], [--output-dir], [--name-filter]      │   │
│  │         ↓                                                   │   │
│  │  ┌─────────────────┐                                       │   │
│  │  │ Single Download │                                       │   │
│  │  │  (artifact_id)  │                                       │   │
│  │  └────────┬────────┘                                       │   │
│  │           ↓                                                 │   │
│  │  GET /repos/{owner}/{repo}/actions/artifacts/{id}/zip     │   │
│  │           ↓                                                 │   │
│  │  Download ZIP (follow redirects, stream to file)          │   │
│  │           ↓                                                 │   │
│  │  Optional: Extract ZIP to subdirectory                     │   │
│  │           ↓                                                 │   │
│  │  Save metadata.json                                        │   │
│  │                                                             │   │
│  │  ┌─────────────────┐                                       │   │
│  │  │  Bulk Download  │                                       │   │
│  │  │    (run_id)     │                                       │   │
│  │  └────────┬────────┘                                       │   │
│  │           ↓                                                 │   │
│  │  Call Sprint 16: list-artifacts-curl.sh                   │   │
│  │           ↓                                                 │   │
│  │  Filter by name (if --name-filter specified)              │   │
│  │           ↓                                                 │   │
│  │  Loop: Download each artifact (single download mode)      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  Shared Components (Sprint 15/16):                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Token Auth  │  │  Repo Resolve │  │  Error Handle │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                   │
│  Integration with Sprint 16:                                     │
│  ┌──────────────────────────────────────────────────┐           │
│  │  list-artifacts-curl.sh --run-id <id> --json     │           │
│  │           ↓                                        │           │
│  │  Extract artifact_ids from JSON response          │           │
│  │           ↓                                        │           │
│  │  Download each artifact                           │           │
│  └──────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### GH-24. Download workflow artifacts

#### Script Design: `scripts/download-artifact-curl.sh`

**Command-line Interface**:

```bash
scripts/download-artifact-curl.sh --artifact-id <id> [--extract] [--output-dir <dir>]
                                   [--repo <owner/repo>] [--token-file <path>]
                                   [--help]

scripts/download-artifact-curl.sh --run-id <id> --all [--name-filter <pattern>]
                                   [--extract] [--output-dir <dir>]
                                   [--repo <owner/repo>] [--token-file <path>]
                                   [--help]

scripts/download-artifact-curl.sh --correlation-id <uuid> --all
                                   [--name-filter <pattern>] [--extract]
                                   [--output-dir <dir>] [--runs-dir <dir>]
                                   [--repo <owner/repo>] [--token-file <path>]
                                   [--help]
```

**Parameters**:

**Input Selection** (mutually exclusive):
- `--artifact-id <id>` - Download single artifact by artifact ID (numeric)
- `--run-id <id> --all` - Download all artifacts for workflow run
- `--correlation-id <uuid> --all` - Load run_id from metadata, download all artifacts

**Download Options**:
- `--extract` - Extract ZIP archives after download (default: keep as ZIP)
- `--output-dir <dir>` - Output directory for downloads (default: `artifacts`)
- `--name-filter <pattern>` - Filter artifacts by name when using `--all` (partial match, case-sensitive)

**Common Options**:
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--runs-dir <dir>` - Base directory for metadata when using `--correlation-id` (default: `runs`)
- `--help` - Display usage information

**Input Resolution**:
- Single download: Requires `--artifact-id`
- Bulk download: Requires `--run-id --all` or `--correlation-id --all`
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var
- Artifact ID: Validate numeric format

**API Request**:

```
GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip
```

**Response Behavior**:
- HTTP 302 redirect to download URL
- Follow redirect to download ZIP archive
- Content-Type: application/zip
- Content-Disposition: attachment; filename="artifact-name.zip"

**Output Structure**:

**Single artifact download (default)**:
```
artifacts/
├── artifact-name.zip
└── artifact-name/
    └── metadata.json
```

**Single artifact download (--extract)**:
```
artifacts/
├── artifact-name/
│   ├── file1.txt
│   ├── file2.log
│   └── metadata.json
└── artifact-name.zip (optional, keep for reference)
```

**Bulk download (--all, default)**:
```
artifacts/
├── artifact-1.zip
├── artifact-1/
│   └── metadata.json
├── artifact-2.zip
└── artifact-2/
    └── metadata.json
```

**Bulk download (--all --extract)**:
```
artifacts/
├── artifact-1/
│   ├── files...
│   └── metadata.json
└── artifact-2/
    ├── files...
    └── metadata.json
```

**metadata.json format**:
```json
{
  "artifact_id": 123456,
  "artifact_name": "test-artifact",
  "run_id": 1234567890,
  "size_in_bytes": 1024,
  "created_at": "2025-01-27T12:00:00Z",
  "expires_at": "2025-04-27T12:00:00Z",
  "downloaded_at": "2025-11-06T10:30:00Z",
  "extracted": true
}
```

**Implementation Details**:

**1. Download single artifact**:
```bash
download_artifact() {
  local owner_repo="$1"
  local artifact_id="$2"
  local output_file="$3"
  local token="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  # Download with redirect following and progress indication
  local http_code
  http_code=$(curl -L -w "%{http_code}" -o "$output_file" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/artifacts/$artifact_id/zip")

  if [[ "$http_code" != "200" ]]; then
    handle_download_error "$http_code" "$artifact_id"
    return 1
  fi

  # Validate ZIP file
  if ! unzip -t "$output_file" >/dev/null 2>&1; then
    printf 'Error: Downloaded file is not a valid ZIP archive\n' >&2
    return 1
  fi

  return 0
}
```

**2. Extract ZIP archive**:
```bash
extract_artifact() {
  local zip_file="$1"
  local output_dir="$2"

  if [[ ! -f "$zip_file" ]]; then
    printf 'Error: ZIP file not found: %s\n' "$zip_file" >&2
    return 1
  fi

  # Create output directory
  mkdir -p "$output_dir"

  # Extract ZIP
  if ! unzip -q -o "$zip_file" -d "$output_dir"; then
    printf 'Error: Failed to extract ZIP archive: %s\n' "$zip_file" >&2
    return 1
  fi

  return 0
}
```

**3. Get artifact metadata from Sprint 16**:
```bash
get_artifact_metadata() {
  local owner_repo="$1"
  local run_id="$2"
  local artifact_id="$3"
  local token="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  # Call GitHub API to get artifact details
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/artifacts/$artifact_id")

  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    return 1
  fi

  echo "$response_body"
  return 0
}
```

**4. Save metadata**:
```bash
save_artifact_metadata() {
  local artifact_metadata="$1"
  local output_dir="$2"
  local extracted="$3"

  local metadata_file="$output_dir/metadata.json"

  # Add download timestamp and extraction status
  echo "$artifact_metadata" | jq \
    --arg downloaded_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --argjson extracted "$extracted" \
    '. + {downloaded_at: $downloaded_at, extracted: $extracted}' \
    > "$metadata_file"
}
```

**5. Download all artifacts for run**:
```bash
download_all_artifacts() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  local output_dir="$4"
  local extract="$5"
  local name_filter="$6"

  # Call Sprint 16's list-artifacts-curl.sh to get artifact list
  local artifacts_json
  artifacts_json=$(scripts/list-artifacts-curl.sh \
    --run-id "$run_id" \
    --repo "$owner_repo" \
    --token-file <(echo "$token") \
    --json)

  if [[ $? -ne 0 ]]; then
    printf 'Error: Failed to list artifacts for run %s\n' "$run_id" >&2
    return 1
  fi

  # Filter by name if specified
  if [[ -n "$name_filter" ]]; then
    artifacts_json=$(echo "$artifacts_json" | jq --arg filter "$name_filter" \
      '.artifacts |= [.[] | select(.name | contains($filter))]')
  fi

  # Extract artifact IDs and names
  local artifact_count
  artifact_count=$(echo "$artifacts_json" | jq -r '.artifacts | length')

  if [[ "$artifact_count" -eq 0 ]]; then
    printf 'No artifacts found for run %s\n' "$run_id"
    return 0
  fi

  printf 'Downloading %d artifact(s)...\n' "$artifact_count"

  # Download each artifact
  local i=0
  while [[ $i -lt $artifact_count ]]; do
    local artifact_id artifact_name
    artifact_id=$(echo "$artifacts_json" | jq -r ".artifacts[$i].id")
    artifact_name=$(echo "$artifacts_json" | jq -r ".artifacts[$i].name")

    printf '[%d/%d] Downloading artifact: %s (ID: %s)\n' \
      $((i + 1)) "$artifact_count" "$artifact_name" "$artifact_id"

    # Download single artifact
    local artifact_dir="$output_dir/$artifact_name"
    local artifact_zip="$output_dir/$artifact_name.zip"

    if ! download_artifact "$owner_repo" "$artifact_id" "$artifact_zip" "$token"; then
      printf 'Warning: Failed to download artifact %s\n' "$artifact_name" >&2
      i=$((i + 1))
      continue
    fi

    # Extract if requested
    if [[ "$extract" == "true" ]]; then
      mkdir -p "$artifact_dir"
      if extract_artifact "$artifact_zip" "$artifact_dir"; then
        printf '  Extracted to: %s\n' "$artifact_dir"
      else
        printf '  Warning: Extraction failed, keeping ZIP file\n' >&2
      fi
    fi

    # Save metadata
    mkdir -p "$artifact_dir"
    local metadata
    metadata=$(echo "$artifacts_json" | jq -r ".artifacts[$i]")
    save_artifact_metadata "$metadata" "$artifact_dir" "$extract"

    i=$((i + 1))
  done

  printf 'Downloaded %d artifact(s) to: %s\n' "$artifact_count" "$output_dir"
  return 0
}
```

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 200 | Success (after redirect) | N/A (download artifact) |
| 302 | Redirect to download URL | N/A (follow redirect) |
| 404 | Artifact not found | "Artifact not found (ID: {artifact_id})" |
| 410 | Artifact expired | "Artifact expired (ID: {artifact_id})" |
| 403 | Insufficient permissions | "Insufficient permissions to download artifact" |
| 401 | Authentication failed | "Authentication failed. Check token permissions." |
| Other | Unknown error | "Download failed (HTTP {code})" |

**Additional Error Scenarios**:
- Invalid ZIP file → "Downloaded file is not a valid ZIP archive"
- Extraction failure → "Failed to extract ZIP archive"
- Disk space issues → "Failed to write file (disk space?)"
- Invalid artifact_id → "Invalid artifact ID format (must be numeric)"

**Exit Codes**:
- `0`: Artifact(s) downloaded successfully
- `1`: Error (API error, download failure, invalid parameters)
- `2`: Invalid arguments or missing required parameters

## Integration Patterns

### Pattern 1: Download Single Artifact by ID

```bash
# Get artifact ID from Sprint 16
artifact_id=$(scripts/list-artifacts-curl.sh --run-id "$run_id" --json | \
  jq -r '.artifacts[0].id')

# Download artifact
scripts/download-artifact-curl.sh --artifact-id "$artifact_id"
```

### Pattern 2: Download All Artifacts for Run

```bash
# Trigger workflow
correlation_id=$(scripts/trigger-workflow-curl.sh \
  --workflow test.yml \
  --json | jq -r '.correlation_id')

# Correlate to get run_id
run_id=$(scripts/correlate-workflow-curl.sh \
  --correlation-id "$correlation_id" \
  --workflow test.yml \
  --json-only)

# Wait for completion...

# Download all artifacts
scripts/download-artifact-curl.sh --run-id "$run_id" --all --extract
```

### Pattern 3: List, Filter, and Download

```bash
# List artifacts with name filter
scripts/list-artifacts-curl.sh --run-id "$run_id" --name-filter "build-" --json

# Download filtered artifacts
scripts/download-artifact-curl.sh --run-id "$run_id" --all --name-filter "build-" --extract
```

### Pattern 4: Download with Correlation ID

```bash
# Use correlation_id directly
scripts/download-artifact-curl.sh \
  --correlation-id "$correlation_id" \
  --all \
  --extract \
  --output-dir "my-artifacts"
```

### Pattern 5: Integration with Log Retrieval

```bash
# Fetch logs
scripts/fetch-logs-curl.sh --run-id "$run_id"

# Download artifacts
scripts/download-artifact-curl.sh --run-id "$run_id" --all --extract

# Complete workflow output now available
```

## Testing Strategy

### GH-24 (Download Artifacts)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-24-1 | Download single artifact by artifact_id | Artifact ZIP downloaded |
| GH-24-2 | Download single artifact with --extract | Artifact extracted to directory |
| GH-24-3 | Download all artifacts for run_id | All artifacts downloaded |
| GH-24-4 | Download all artifacts with --extract | All artifacts extracted |
| GH-24-5 | Download with --name-filter | Only matching artifacts downloaded |
| GH-24-6 | Download with --output-dir | Artifacts saved to custom directory |
| GH-24-7 | Invalid artifact_id | HTTP 404, error message |
| GH-24-8 | Expired artifact | HTTP 410, error message |
| GH-24-9 | Missing required fields | Exit code 2, usage message |
| GH-24-10 | Auto-detect repository | Uses git config |
| GH-24-11 | Correlation ID input | Loads run_id from metadata |
| GH-24-12 | No artifacts for run | Message "No artifacts found" |
| GH-24-13 | Large artifact download | Streaming works, no memory issues |
| GH-24-14 | Invalid ZIP file | Error message, cleanup |
| GH-24-15 | Extraction failure | Keep ZIP file, error message |

**Integration Tests**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| INT-1 | List + Download pipeline | Artifacts listed and downloaded |
| INT-2 | Trigger + Correlate + Download | End-to-end workflow |
| INT-3 | Download + Extract + Verify | Files extracted correctly |
| INT-4 | Multiple artifact download | All artifacts downloaded successfully |

## Compatibility with Previous Sprints

**Sprint 16 (GH-23)**:
- ✅ Uses artifact listing output for bulk downloads
- ✅ Compatible JSON output format
- ✅ Can use artifact_ids from listing results
- ✅ Pipeline: List → Download

**Sprint 15 (GH-14, GH-15, GH-16)**:
- ✅ Follows same REST API pattern
- ✅ Reuses token authentication and repository resolution
- ✅ Compatible CLI interface style
- ✅ Can use run_id from correlation scripts

**Sprint 3 (GH-5)**:
- ✅ Reuses ZIP extraction pattern
- ✅ Similar directory structure for artifacts
- ✅ Metadata preservation approach

**Sprint 1 (GH-2, GH-3)**:
- ✅ Compatible with correlation mechanism (UUID in run-name)
- ✅ Can use run_id from correlation scripts

## Risks and Mitigations

### Risk 1: Large File Downloads

**Risk**: Large artifacts may consume excessive memory or fail to download
**Impact**: Script crashes or fails for large artifacts
**Mitigation**: Use curl streaming (`-o` flag), monitor disk space, test with large artifacts

### Risk 2: Artifact Expiration

**Risk**: Artifacts expire after retention period (default: 90 days)
**Impact**: HTTP 410 errors when attempting download
**Mitigation**: Check expiration date before download (via Sprint 16), handle 410 errors gracefully

### Risk 3: Download Failures

**Risk**: Network errors, disk space issues, or interrupted downloads
**Impact**: Partial downloads, corrupted files
**Mitigation**: Validate ZIP integrity after download, provide clear error messages, cleanup failed downloads

### Risk 4: Multiple Artifact Downloads

**Risk**: Downloading many artifacts may be slow or hit rate limits
**Impact**: Long execution times, potential rate limit errors
**Mitigation**: Add progress indication, handle rate limits gracefully, sequential downloads (parallel in future)

### Risk 5: ZIP Extraction Issues

**Risk**: ZIP extraction may fail for corrupted archives
**Impact**: Download succeeds but extraction fails
**Mitigation**: Validate ZIP integrity before extraction, keep original ZIP if extraction fails

### Risk 6: Redirect Handling

**Risk**: Download URL requires following 302 redirect
**Impact**: Download fails without redirect handling
**Mitigation**: Use `curl -L` flag to follow redirects automatically

### Risk 7: Integration with Sprint 16

**Risk**: Sprint 16 script changes may break bulk download
**Impact**: `--all` flag fails
**Mitigation**: Use stable Sprint 16 JSON output, validate JSON structure

## Success Criteria

Sprint 17 design is successful when:

1. ✅ Feasibility analysis confirms GitHub API supports all operations
2. ✅ Script design covers all required functionality for GH-24
3. ✅ CLI interface maintains compatibility with existing scripts
4. ✅ Integration with Sprint 16 clearly defined
5. ✅ Error handling addresses all HTTP status codes and scenarios
6. ✅ Output structure and metadata format specified
7. ✅ Integration patterns documented
8. ✅ Test strategy covers all scenarios
9. ✅ Risks identified with mitigation strategies
10. ✅ Compatibility with previous sprints maintained

## Documentation

**Implementation Notes** (to be created in construction phase):
- `progress/sprint_17_implementation.md`
- Usage examples for script
- Test execution results

**Script Help** (inline in script):
- `scripts/download-artifact-curl.sh --help`

## Design Approval

**Status**: Awaiting Product Owner review

This design document is ready for Product Owner review. Implementation will proceed after approval (status change to "Accepted") or automatically after 60 seconds per RUP cycle instructions.

**Design addresses**:
- ✅ GH-24: Download workflow artifacts with REST API, streaming support
- ✅ Integration with Sprint 16 for artifact discovery
- ✅ Support for single and bulk downloads
- ✅ Optional ZIP extraction
- ✅ Comprehensive test strategy
- ✅ Error handling and risk mitigation
