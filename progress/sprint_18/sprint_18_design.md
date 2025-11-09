# Sprint 18 - Design

## GH-25. Delete workflow artifacts

Status: Proposed

## Overview

Sprint 18 extends workflow management capabilities with artifact deletion operations. This sprint implements REST API-based artifact deletion using curl, following the pattern established in Sprint 15 and completing the artifact management lifecycle (list, download, delete) initiated in Sprints 16 and 17. The implementation uses token authentication from `./secrets` directory, supports deleting individual artifacts or all artifacts for a run, validates deletion permissions, and provides comprehensive error handling.

**Key Design Decisions**:
- Use curl-based REST API approach (following Sprint 15/16/17 pattern)
- Token authentication from `./secrets/github_token` or `./secrets/token` file
- Support both single artifact and bulk deletion modes
- Require confirmation by default for safety (with `--confirm` flag to skip)
- Provide `--dry-run` mode to preview deletions without executing
- Maintain compatibility with Sprint 16's artifact listing output
- Support same CLI interface patterns for seamless integration
- Comprehensive error handling for all HTTP status codes
- Handle idempotent deletion (404 on already deleted artifacts treated as success)

## Feasibility Analysis

### GitHub REST API Capabilities

**GH-25 (Delete Artifacts)** - `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`:
- ✅ API endpoint available and documented
- ✅ Returns HTTP 204 (No Content) on successful deletion
- ✅ Returns HTTP 404 if artifact not found or already deleted (idempotent)
- ✅ Returns HTTP 403 if insufficient permissions
- ✅ Returns HTTP 401 if authentication fails
- ✅ Deletion is permanent and cannot be undone
- ✅ Error codes: 404 (artifact not found/already deleted), 403 (insufficient permissions), 401 (auth errors)
- Documentation: https://docs.github.com/en/rest/actions/artifacts#delete-an-artifact

**API Behavior**:
- DELETE request returns 204 on success (no response body)
- Deletion is immediate and permanent
- Already deleted artifacts return 404 (safe to retry)
- Requires write permissions (Actions: Write)

**Limitations**:
- ⚠️ No bulk delete endpoint (must delete each artifact separately)
- ⚠️ Deletion is permanent and cannot be undone
- ⚠️ Requires write permissions (more restrictive than read)

### Authentication

**Token File Pattern** (from Sprint 15/16/17):
- Token stored in: `./secrets/github_token` (default) or `./secrets/token`
- Header format: `Authorization: Bearer <token>`
- Required permissions: `Actions: Write` (classic token) or `Actions: Write` (fine-grained token)
- **Note**: Write permissions required (more restrictive than read-only operations)

### Repository Resolution

**Auto-detection from git context** (following Sprint 15/16/17 pattern):
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
1. `--artifact-id <id>` - Direct numeric artifact ID (single deletion)
2. `--run-id <id>` with `--all` flag - Delete all artifacts for run (calls Sprint 16 listing)
3. `--correlation-id <uuid>` with `--all` flag - Load run_id from metadata, then delete all
4. Stdin JSON - Parse JSON input for artifact_id or run_id

### Feasibility Conclusion

**Fully achievable** - GH-25 can be implemented:
- ✅ GitHub API provides required endpoint
- ✅ All required operations supported
- ✅ Authentication pattern established (Sprint 15/16/17)
- ✅ Integration with Sprint 16 for artifact discovery
- ✅ Idempotent deletion (safe to retry)
- ✅ No platform limitations identified
- ✅ Compatible with existing run_id/correlation_id resolution mechanisms

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│          Sprint 18: REST API Artifact Deletion                   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  GH-25: Delete Artifacts (REST API)                       │   │
│  │                                                             │   │
│  │  Input: --artifact-id or --run-id --all,                  │   │
│  │         [--confirm], [--dry-run], [--name-filter]          │   │
│  │         ↓                                                   │   │
│  │  ┌─────────────────┐                                       │   │
│  │  │ Single Deletion  │                                       │   │
│  │  │  (artifact_id)   │                                       │   │
│  │  └────────┬────────┘                                       │   │
│  │           ↓                                                 │   │
│  │  Dry-run: Display artifact info                            │   │
│  │           ↓                                                 │   │
│  │  Confirm: Prompt user (unless --confirm)                   │   │
│  │           ↓                                                 │   │
│  │  DELETE /repos/{owner}/{repo}/actions/artifacts/{id}       │   │
│  │           ↓                                                 │   │
│  │  Handle response (204 success, 404 already deleted)       │   │
│  │                                                             │   │
│  │  ┌─────────────────┐                                       │   │
│  │  │  Bulk Deletion   │                                       │   │
│  │  │    (run_id)      │                                       │   │
│  │  └────────┬────────┘                                       │   │
│  │           ↓                                                 │   │
│  │  Call Sprint 16: list-artifacts-curl.sh                   │   │
│  │           ↓                                                 │   │
│  │  Filter by name (if --name-filter specified)              │   │
│  │           ↓                                                 │   │
│  │  Dry-run: Display list of artifacts to delete             │   │
│  │           ↓                                                 │   │
│  │  Confirm: Prompt user (unless --confirm)                   │   │
│  │           ↓                                                 │   │
│  │  Loop: Delete each artifact (single deletion mode)        │   │
│  │           ↓                                                 │   │
│  │  Summary: Report successes/failures                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  Shared Components (Sprint 15/16/17):                            │
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
│  │  Delete each artifact                             │           │
│  └──────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### GH-25. Delete workflow artifacts

#### Script Design: `scripts/delete-artifact-curl.sh`

**Command-line Interface**:

```bash
scripts/delete-artifact-curl.sh --artifact-id <id> [--confirm] [--dry-run]
                                 [--repo <owner/repo>] [--token-file <path>]
                                 [--help]

scripts/delete-artifact-curl.sh --run-id <id> --all [--name-filter <pattern>]
                                 [--confirm] [--dry-run]
                                 [--repo <owner/repo>] [--token-file <path>]
                                 [--help]

scripts/delete-artifact-curl.sh --correlation-id <uuid> --all
                                 [--name-filter <pattern>] [--confirm] [--dry-run]
                                 [--runs-dir <dir>] [--repo <owner/repo>]
                                 [--token-file <path>] [--help]
```

**Parameters**:

**Input Selection** (mutually exclusive):
- `--artifact-id <id>` - Delete single artifact by artifact ID (numeric)
- `--run-id <id> --all` - Delete all artifacts for workflow run
- `--correlation-id <uuid> --all` - Load run_id from metadata, delete all artifacts

**Deletion Options**:
- `--confirm` - Skip confirmation prompt (default: require confirmation)
- `--dry-run` - Preview deletions without executing (list artifacts that would be deleted)
- `--name-filter <pattern>` - Filter artifacts by name when using `--all` (partial match, case-sensitive)

**Common Options**:
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--runs-dir <dir>` - Base directory for metadata when using `--correlation-id` (default: `runs`)
- `--help` - Display usage information

**Input Resolution**:
- Single deletion: Requires `--artifact-id`
- Bulk deletion: Requires `--run-id --all` or `--correlation-id --all`
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var
- Artifact ID: Validate numeric format

**API Request**:

```
DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}
```

**Response Behavior**:
- HTTP 204 (No Content) - Successful deletion
- HTTP 404 - Artifact not found or already deleted (idempotent, treat as success)
- HTTP 403 - Insufficient permissions
- HTTP 401 - Authentication failure

**Output Structure**:

**Single artifact deletion (success)**:
```
Deleting artifact 123456...
✓ Artifact deleted successfully
```

**Single artifact deletion (already deleted)**:
```
Deleting artifact 123456...
✓ Artifact already deleted (idempotent)
```

**Single artifact deletion (dry-run)**:
```
Dry-run: Would delete artifact 123456 (test-artifact, 1.0 KB)
```

**Bulk deletion (success)**:
```
Found 3 artifacts for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)
  ✓ Deleted artifact 123457 (build-output)
  ✓ Deleted artifact 123458 (coverage-report)

Summary: 3 deleted, 0 failed
```

**Bulk deletion (with failures)**:
```
Found 3 artifacts for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)
  ✗ Failed to delete artifact 123457 (build-output): Insufficient permissions
  ✓ Deleted artifact 123458 (coverage-report)

Summary: 2 deleted, 1 failed
```

**Bulk deletion (dry-run)**:
```
Dry-run: Would delete 3 artifacts for run 1234567890:
  - Artifact 123456 (test-artifact, 1.0 KB)
  - Artifact 123457 (build-output, 2.5 MB)
  - Artifact 123458 (coverage-report, 500 KB)
```

**Confirmation Prompt** (single deletion):
```
Are you sure you want to delete artifact 123456 (test-artifact)? [y/N]: 
```

**Confirmation Prompt** (bulk deletion):
```
Found 3 artifacts for run 1234567890. Delete all? [y/N]: 
```

**Implementation Details**:

**1. Resolve artifact_id**:
```bash
resolve_artifact_id() {
  if [[ -n "$ARTIFACT_ID" ]]; then
    if [[ ! "$ARTIFACT_ID" =~ ^[0-9]+$ ]]; then
      printf 'Error: Invalid artifact ID format: %s\n' "$ARTIFACT_ID" >&2
      exit 1
    fi
    printf '%s' "$ARTIFACT_ID"
  elif [[ -n "$RUN_ID" && "$DOWNLOAD_ALL" == true ]]; then
    # Bulk deletion: list artifacts first
    list_artifacts_for_deletion
  elif [[ -n "$CORRELATION_ID" && "$DOWNLOAD_ALL" == true ]]; then
    # Resolve run_id from correlation_id, then list artifacts
    resolve_run_id "$CORRELATION_ID" "$RUNS_DIR"
    list_artifacts_for_deletion
  else
    printf 'Error: Must specify --artifact-id or --run-id --all or --correlation-id --all\n' >&2
    exit 1
  fi
}
```

**2. List artifacts for bulk deletion**:
```bash
list_artifacts_for_deletion() {
  local run_id="$1"
  local repo="$2"
  local token="$3"
  local name_filter="$4"
  
  # Call Sprint 16's listing script
  local json_output
  json_output=$(scripts/list-artifacts-curl.sh \
    --run-id "$run_id" \
    --repo "$repo" \
    --token-file "$TOKEN_FILE" \
    --json)
  
  # Extract artifact IDs
  if [[ -n "$name_filter" ]]; then
    jq -r ".artifacts[] | select(.name | contains(\"$name_filter\")) | .id" <<< "$json_output"
  else
    jq -r '.artifacts[].id' <<< "$json_output"
  fi
}
```

**3. Delete single artifact**:
```bash
delete_artifact() {
  local artifact_id="$1"
  local repo="$2"
  local token="$3"
  
  local api_url="https://api.github.com/repos/$repo/actions/artifacts/$artifact_id"
  
  local http_code
  http_code=$(curl -s -w '%{http_code}' -o /dev/null \
    -X DELETE \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$api_url")
  
  case "$http_code" in
    204)
      printf '✓ Artifact deleted successfully\n'
      return 0
      ;;
    404)
      printf '✓ Artifact already deleted (idempotent)\n'
      return 0
      ;;
    401)
      printf 'Error: Authentication failed\n' >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to delete artifact\n' >&2
      return 1
      ;;
    *)
      printf 'Error: Unexpected HTTP status %s\n' "$http_code" >&2
      return 1
      ;;
  esac
}
```

**4. Confirmation prompt**:
```bash
confirm_deletion() {
  local artifact_count="$1"
  local artifact_info="$2"
  
  if [[ "$DRY_RUN" == true ]]; then
    return 0  # Skip confirmation in dry-run mode
  fi
  
  if [[ "$CONFIRM" == true ]]; then
    return 0  # Skip confirmation if --confirm flag set
  fi
  
  if [[ "$artifact_count" -eq 1 ]]; then
    printf 'Are you sure you want to delete artifact %s? [y/N]: ' "$artifact_info" >&2
  else
    printf 'Found %d artifacts. Delete all? [y/N]: ' "$artifact_count" >&2
  fi
  
  local response
  read -r response
  case "$response" in
    [yY]|[yY][eE][sS])
      return 0
      ;;
    *)
      printf 'Deletion cancelled\n' >&2
      return 1
      ;;
  esac
}
```

**5. Dry-run mode**:
```bash
dry_run_deletion() {
  local artifact_ids=("$@")
  local repo="$1"
  local token="$2"
  
  printf 'Dry-run: Would delete %d artifacts:\n' "${#artifact_ids[@]}"
  
  for artifact_id in "${artifact_ids[@]}"; do
    # Fetch artifact metadata
    local metadata
    metadata=$(get_artifact_metadata "$artifact_id" "$repo" "$token")
    local name size
    name=$(jq -r '.name' <<< "$metadata")
    size=$(jq -r '.size_in_bytes' <<< "$metadata")
    size_human=$(format_human_size "$size")
    
    printf '  - Artifact %s (%s, %s)\n' "$artifact_id" "$name" "$size_human"
  done
}
```

**6. Bulk deletion loop**:
```bash
delete_all_artifacts() {
  local run_id="$1"
  local repo="$2"
  local token="$3"
  local name_filter="$4"
  
  # List artifacts
  local artifact_ids
  mapfile -t artifact_ids < <(list_artifacts_for_deletion "$run_id" "$repo" "$token" "$name_filter")
  
  if [[ ${#artifact_ids[@]} -eq 0 ]]; then
    printf 'No artifacts found to delete\n'
    return 0
  fi
  
  # Dry-run mode
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_deletion "${artifact_ids[@]}" "$repo" "$token"
    return 0
  fi
  
  # Confirmation
  if ! confirm_deletion "${#artifact_ids[@]}" ""; then
    return 1
  fi
  
  # Delete each artifact
  local success_count=0
  local fail_count=0
  
  printf 'Deleting artifacts...\n'
  for artifact_id in "${artifact_ids[@]}"; do
    if delete_artifact "$artifact_id" "$repo" "$token"; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  done
  
  # Summary
  printf '\nSummary: %d deleted, %d failed\n' "$success_count" "$fail_count"
  
  if [[ $fail_count -gt 0 ]]; then
    return 1
  fi
  return 0
}
```

**Error Handling**:

**HTTP Status Codes**:
- `204` - Success (artifact deleted)
- `404` - Artifact not found or already deleted (idempotent, treat as success)
- `401` - Authentication failure (invalid or missing token)
- `403` - Insufficient permissions (token lacks Actions: Write permission)
- `422` - Validation error (invalid artifact_id format)
- `5xx` - Server error (retry may help)

**Error Messages**:
- Clear, actionable error messages
- Never leak token in error output
- Suggest solutions for common errors (e.g., check permissions)

**Integration with Sprint 16**:

**Bulk Deletion Flow**:
1. Call `list-artifacts-curl.sh --run-id <id> --json`
2. Parse JSON response to extract artifact IDs
3. Filter by name if `--name-filter` specified
4. Delete each artifact individually
5. Report summary of successes/failures

**Dependency**:
- Requires `list-artifacts-curl.sh` from Sprint 16
- Falls back to direct API call if script unavailable (with warning)

## Test Scenarios

### GH-25-1: Delete single artifact (success)

**Input**:
```bash
scripts/delete-artifact-curl.sh --artifact-id 123456
```

**Expected Output**:
```
Are you sure you want to delete artifact 123456 (test-artifact)? [y/N]: y
Deleting artifact 123456...
✓ Artifact deleted successfully
```

**Validation**:
- HTTP 204 response
- Artifact no longer appears in listing
- Confirmation prompt shown (unless --confirm)

### GH-25-2: Delete single artifact (dry-run)

**Input**:
```bash
scripts/delete-artifact-curl.sh --artifact-id 123456 --dry-run
```

**Expected Output**:
```
Dry-run: Would delete artifact 123456 (test-artifact, 1.0 KB)
```

**Validation**:
- No API call made
- Artifact still exists
- No confirmation prompt

### GH-25-3: Delete single artifact (already deleted)

**Input**:
```bash
scripts/delete-artifact-curl.sh --artifact-id 123456 --confirm
```

**Expected Output**:
```
Deleting artifact 123456...
✓ Artifact already deleted (idempotent)
```

**Validation**:
- HTTP 404 response treated as success
- No error reported
- Idempotent behavior confirmed

### GH-25-4: Delete single artifact (insufficient permissions)

**Input**:
```bash
scripts/delete-artifact-curl.sh --artifact-id 123456 --confirm
```

**Expected Output**:
```
Deleting artifact 123456...
Error: Insufficient permissions to delete artifact
```

**Validation**:
- HTTP 403 response
- Clear error message
- Exit code 1

### GH-25-5: Delete all artifacts for run (success)

**Input**:
```bash
scripts/delete-artifact-curl.sh --run-id 1234567890 --all --confirm
```

**Expected Output**:
```
Found 3 artifacts for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)
  ✓ Deleted artifact 123457 (build-output)
  ✓ Deleted artifact 123458 (coverage-report)

Summary: 3 deleted, 0 failed
```

**Validation**:
- All artifacts deleted
- Summary shows correct counts
- Exit code 0

### GH-25-6: Delete all artifacts for run (with name filter)

**Input**:
```bash
scripts/delete-artifact-curl.sh --run-id 1234567890 --all --name-filter "test-" --confirm
```

**Expected Output**:
```
Found 1 artifact matching filter "test-"
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)

Summary: 1 deleted, 0 failed
```

**Validation**:
- Only matching artifacts deleted
- Filter applied correctly
- Other artifacts remain

### GH-25-7: Delete all artifacts for run (dry-run)

**Input**:
```bash
scripts/delete-artifact-curl.sh --run-id 1234567890 --all --dry-run
```

**Expected Output**:
```
Dry-run: Would delete 3 artifacts for run 1234567890:
  - Artifact 123456 (test-artifact, 1.0 KB)
  - Artifact 123457 (build-output, 2.5 MB)
  - Artifact 123458 (coverage-report, 500 KB)
```

**Validation**:
- No API calls made
- Artifacts still exist
- List shows what would be deleted

### GH-25-8: Delete all artifacts for run (with failures)

**Input**:
```bash
scripts/delete-artifact-curl.sh --run-id 1234567890 --all --confirm
```

**Expected Output**:
```
Found 3 artifacts for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)
  ✗ Failed to delete artifact 123457 (build-output): Insufficient permissions
  ✓ Deleted artifact 123458 (coverage-report)

Summary: 2 deleted, 1 failed
```

**Validation**:
- Partial success handled gracefully
- Failures reported clearly
- Exit code 1 (partial failure)

### GH-25-9: Delete using correlation ID

**Input**:
```bash
scripts/delete-artifact-curl.sh --correlation-id <uuid> --all --confirm
```

**Expected Output**:
```
Found 3 artifacts for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)
  ✓ Deleted artifact 123457 (build-output)
  ✓ Deleted artifact 123458 (coverage-report)

Summary: 3 deleted, 0 failed
```

**Validation**:
- Correlation ID resolved to run_id
- Artifacts deleted successfully
- Compatible with existing correlation mechanism

### GH-25-10: Delete with invalid artifact ID

**Input**:
```bash
scripts/delete-artifact-curl.sh --artifact-id invalid
```

**Expected Output**:
```
Error: Invalid artifact ID format: invalid
```

**Validation**:
- Validation before API call
- Clear error message
- Exit code 1

### GH-25-11: Delete with missing required flag

**Input**:
```bash
scripts/delete-artifact-curl.sh --run-id 1234567890
```

**Expected Output**:
```
Error: Must specify --artifact-id or --run-id --all or --correlation-id --all
```

**Validation**:
- Input validation
- Clear error message
- Exit code 1

### GH-25-12: Delete with confirmation cancelled

**Input**:
```bash
scripts/delete-artifact-curl.sh --artifact-id 123456
# User enters 'n' at prompt
```

**Expected Output**:
```
Are you sure you want to delete artifact 123456 (test-artifact)? [y/N]: n
Deletion cancelled
```

**Validation**:
- No API call made
- Artifact still exists
- Exit code 1

## Implementation Notes

**Shared Components** (reuse from Sprint 15/16/17):
- Token loading (`load_token()`)
- Repository resolution (`resolve_repository()`)
- HTTP error handling (`handle_http_error()`)
- Run ID resolution (`resolve_run_id()` from `scripts/lib/run-utils.sh`)

**Script-Specific Components**:
- Artifact ID resolution (`resolve_artifact_id()`)
- Artifact listing integration (`list_artifacts_for_deletion()`)
- Deletion API call (`delete_artifact()`)
- Confirmation prompt (`confirm_deletion()`)
- Dry-run mode (`dry_run_deletion()`)
- Bulk deletion loop (`delete_all_artifacts()`)
- Summary reporting

**Dependencies**:
- `scripts/list-artifacts-curl.sh` (Sprint 16) - For bulk deletion
- `scripts/lib/run-utils.sh` - For run_id resolution
- `jq` - For JSON parsing
- `curl` - For API calls

**Error Handling Strategy**:
- Validate inputs before API calls
- Handle all HTTP status codes appropriately
- Treat 404 as success (idempotent deletion)
- Continue on individual failures in bulk mode
- Provide clear error messages
- Never leak token in error output

**Safety Features**:
- Require confirmation by default
- Provide `--dry-run` mode for preview
- Support `--confirm` flag for automation
- Clear summary of operations
- Idempotent deletion (safe to retry)

## Status

**Design Status**: Proposed

**Ready for Construction**: Yes (pending Product Owner approval)

**Blockers**: None

**Next Steps**:
1. Wait for Product Owner design approval
2. Proceed to Construction phase
3. Implement script following design
4. Execute test scenarios
5. Update progress board

