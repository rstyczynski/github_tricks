# Sprint 17 - Implementation Notes

## GH-24. Download workflow artifacts

Status: Implemented

### Implementation Summary

Created `scripts/download-artifact-curl.sh` script that downloads workflow artifacts using pure REST API with curl.

**Key Features**:
- Token authentication from `./secrets/github_token` or `./secrets/token`
- Two download modes:
  - Single artifact: `--artifact-id <id>`
  - Bulk download: `--run-id <id> --all` or `--correlation-id <uuid> --all`
- Optional ZIP extraction via `--extract` flag
- Integration with Sprint 16's `list-artifacts-curl.sh` for bulk operations
- Support for artifact name filtering in bulk mode
- Repository auto-detection from git context
- Comprehensive error handling for all HTTP status codes
- Metadata preservation in JSON format
- Streaming downloads for large files

**Implementation Details**:
- Follows Sprint 15/16's REST API pattern for token loading and repository resolution
- Uses `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip` endpoint
- Handles HTTP 200 (success), 302 (redirect), 404 (not found), 410 (expired), 401/403 (auth errors)
- Download modes: Single artifact by ID, or bulk download by run_id/correlation_id
- ZIP validation: Uses `unzip -t` to validate downloaded archives
- Optional extraction: `--extract` flag extracts ZIP to subdirectory
- Metadata: Saves metadata.json with artifact details and download timestamp

**Static Validation**:
- ✅ Script is executable
- ✅ Shellcheck: No errors (only SC1091 info about sourced file, which is expected)
- ✅ Help output works correctly

**Testing Requirements**:
- Requires GitHub repository with workflow runs that produce artifacts
- Requires valid GitHub token with Actions: Read permissions
- Test scenarios documented in design document (GH-24-1 through GH-24-15)

**Status**: Script implemented and ready for testing. Full testing requires GitHub repository access with workflow runs that produce artifacts.

## Implementation Approach

### Shared Components

Script reuses patterns from Sprint 15/16:

**1. Token Loading**:
- Load token from `./secrets/github_token` (default) or `./secrets/token`
- Validate file exists, readable, non-empty
- Warn about permissions (should be 600)
- Never leak token in error messages
- Function: `load_token()`

**2. Repository Resolution**:
- Priority: `--repo` flag → `GITHUB_REPOSITORY` env → git remote parsing
- Normalize format (remove .git suffix)
- Validate owner/repo format
- Functions: `resolve_repository()`, `normalize_repo()`, `parse_github_url()`, `validate_repo_format()`

**3. Run ID Resolution**:
- Uses `ru_read_run_id_from_runs_dir` from `scripts/lib/run-utils.sh`
- Supports `--run-id` and `--correlation-id`
- Validates run_id format (numeric)
- Function: `resolve_run_id()`

**4. Error Handling**:
- HTTP 200: Success (after redirect)
- HTTP 302: Redirect (followed automatically by curl -L)
- HTTP 401: Authentication failure
- HTTP 403: Permission denied
- HTTP 404: Artifact not found
- HTTP 410: Artifact expired
- HTTP 5xx: Transient server errors
- Invalid ZIP: Validation failure

### Script-Specific Components

**1. Artifact Metadata Retrieval**:
- `get_artifact_metadata()` - Fetches artifact details from GitHub API
- Uses `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}` endpoint
- Returns JSON with artifact name, size, timestamps

**2. Single Artifact Download**:
- `download_artifact()` - Downloads artifact ZIP via REST API
- Uses `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip` endpoint
- Follows redirects with `curl -L`
- Validates ZIP integrity with `unzip -t`
- Streams to file to avoid memory issues

**3. ZIP Extraction**:
- `extract_artifact()` - Extracts ZIP archive to directory
- Creates output directory if needed
- Uses `unzip -q -o` for quiet extraction with overwrite
- Validates ZIP exists before extraction

**4. Metadata Preservation**:
- `save_artifact_metadata()` - Saves metadata.json alongside artifact
- Includes artifact details (id, name, size, timestamps)
- Adds download timestamp and extraction status
- JSON format for programmatic access

**5. Single Artifact Orchestration**:
- `download_single_artifact()` - Orchestrates single artifact download
- Fetches metadata
- Downloads ZIP
- Optionally extracts
- Saves metadata
- Progress indication

**6. Bulk Download Orchestration**:
- `download_all_artifacts()` - Orchestrates bulk download
- Calls Sprint 16's `list-artifacts-curl.sh` to get artifact list
- Filters by name if `--name-filter` specified
- Loops through artifacts, downloading each
- Progress indication with counter [n/total]
- Error handling: continues on individual failures, reports summary

### Integration with Sprint 16

**Integration Point**: Bulk download mode leverages Sprint 16's artifact listing

**Integration Flow**:
1. User provides `--run-id <id> --all`
2. Script calls: `list-artifacts-curl.sh --run-id <id> --json`
3. Parses JSON output to extract artifact IDs and metadata
4. Optional: Filters by name if `--name-filter` specified
5. Loops through artifacts, downloading each individually
6. Uses metadata from listing (avoids separate API call per artifact)

**Command Construction**:
```bash
list_cmd=("$SCRIPT_DIR/list-artifacts-curl.sh" "--run-id" "$run_id" "--repo" "$owner_repo" "--token-file" "$TOKEN_FILE" "--json")
if [[ -n "$name_filter" ]]; then
  list_cmd+=("--name-filter" "$name_filter")
fi
artifacts_json=$("${list_cmd[@]}" 2>/dev/null)
```

**JSON Contract**:
```json
{
  "run_id": "123",
  "total_count": 2,
  "artifacts": [
    {"id": 456, "name": "artifact-1", "size_in_bytes": 1024, ...},
    {"id": 789, "name": "artifact-2", "size_in_bytes": 2048, ...}
  ]
}
```

### Output Directory Structure

**Without extraction** (default):
```
artifacts/
├── artifact-name.zip
└── artifact-name/
    └── metadata.json
```

**With extraction** (`--extract`):
```
artifacts/
├── artifact-name/
│   ├── file1.txt
│   ├── file2.log
│   └── metadata.json
└── artifact-name.zip
```

**Metadata Format** (`metadata.json`):
```json
{
  "id": 123456,
  "node_id": "...",
  "name": "test-artifact",
  "size_in_bytes": 1024,
  "url": "https://api.github.com/repos/owner/repo/actions/artifacts/123456",
  "archive_download_url": "https://api.github.com/repos/owner/repo/actions/artifacts/123456/zip",
  "expires_at": "2025-04-27T12:00:00Z",
  "created_at": "2025-01-27T12:00:00Z",
  "downloaded_at": "2025-11-06T15:30:00Z",
  "extracted": true
}
```

## Usage Examples

### Example 1: Download Single Artifact (Fully Executable)

This example demonstrates a complete workflow from creating a workflow that produces artifacts to downloading them.

**Step 1: Create a workflow that produces artifacts**

The workflow file `.github/workflows/artifact-producer.yml` is already created. It produces two artifacts:
- `test-artifact`: Contains greeting.txt, build-info.txt, and metadata.json
- `build-output`: Contains only build-info.txt

**Step 2: Trigger the workflow and get correlation ID**

```bash
# Generate a unique correlation ID
CORRELATION_ID=$(uuidgen)

# Trigger the workflow
TRIGGER_RESULT=$(scripts/trigger-workflow-curl.sh \
  --workflow artifact-producer.yml \
  --input correlation_id="$CORRELATION_ID" \
  --token-file .secrets/token \
  --json)

# Extract correlation ID from result
echo "$TRIGGER_RESULT" | jq -r '.correlation_id'
```

**Step 3: Correlate to get run_id**

```bash
# Wait a few seconds for workflow to appear in API (typically 2-5 seconds)
sleep 5

# Get run_id using correlation
CORRELATE_RESULT=$(scripts/correlate-workflow-curl.sh \
  --correlation-id "$CORRELATION_ID" \
  --workflow artifact-producer.yml \
  --token-file .secrets/token \
  --json-only)

RUN_ID=$(echo "$CORRELATE_RESULT" | jq -r '.run_id // empty' | tr -d '\n\r' | xargs)

if [[ -z "$RUN_ID" ]] || [[ ! "$RUN_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: Failed to get valid run_id. Correlation may have failed." >&2
  echo "Correlation result: $CORRELATE_RESULT" >&2
  echo "Extracted RUN_ID: '$RUN_ID'" >&2
  # Note: In a standalone script, you would use 'exit 1' here
fi

echo "Run ID: $RUN_ID"
```

**Step 4: Wait for workflow completion**

```bash
# Wait for workflow to complete (default: max 5 minutes, poll every 10 seconds)
scripts/wait-workflow-completion-curl.sh --run-id "$RUN_ID" --token-file .secrets/token

# With custom timeout and interval:
# scripts/wait-workflow-completion-curl.sh --run-id "$RUN_ID" --max-wait 600 --interval 5 --token-file .secrets/token

# Quiet mode (suppress progress output):
# scripts/wait-workflow-completion-curl.sh --run-id "$RUN_ID" --quiet --token-file .secrets/token
```

**Step 5: List artifacts to get artifact ID**

```bash
# List artifacts for the run
ARTIFACTS_JSON=$(scripts/list-artifacts-curl.sh --run-id "$RUN_ID" --token-file .secrets/token --json)

# Display available artifacts
echo "$ARTIFACTS_JSON" | jq -r '.artifacts[] | "\(.id) - \(.name) (\(.size_in_bytes) bytes)"'

# Get the first artifact ID
ARTIFACT_ID=$(echo "$ARTIFACTS_JSON" | jq -r '.artifacts[0].id')

echo "Downloading artifact ID: $ARTIFACT_ID"
```

**Step 6: Download the artifact**

```bash
# Download single artifact
scripts/download-artifact-curl.sh --artifact-id "$ARTIFACT_ID" --token-file .secrets/token

# Output:
# Downloading artifact: test-artifact (ID: 123456)
#   Downloaded to: artifacts/test-artifact.zip
```

**Step 7: Verify the download**

```bash
# Check downloaded file
ls -lh artifacts/test-artifact.zip

# Extract and view contents (if you want to see what's inside)
unzip -l artifacts/test-artifact.zip

# Or extract it
unzip -q artifacts/test-artifact.zip -d artifacts/test-artifact
cat artifacts/test-artifact/greeting.txt
cat artifacts/test-artifact/metadata.json | jq .
```

**Complete Copy-Paste Script**

For a fully executable standalone script, use:

```bash
scripts/download-artifact-example.sh
```

Or view the script source:

```bash
cat scripts/download-artifact-example.sh
```

**Prerequisites:**

Before running the example, ensure you have:
1. GitHub token in `.secrets/token`
2. Required commands: `jq`, `uuidgen`, `unzip`
3. The workflow file `.github/workflows/artifact-producer.yml` exists
4. You're in a git repository with GitHub remote configured

**Expected Output:**

```
=== Step 1: Correlation ID ===
Correlation ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890

=== Step 2: Triggering workflow ===
{
  "workflow": "artifact-producer.yml",
  "workflow_id": 123456,
  "ref": "main",
  "correlation_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "dispatched"
}

=== Step 3: Waiting for workflow to appear (5 seconds) ===

=== Step 4: Getting run_id ===
Run ID: 1234567890

=== Step 5: Waiting for workflow completion ===
Waiting... (status: in_progress, elapsed: 0s)
Waiting... (status: in_progress, elapsed: 10s)
✓ Workflow completed!

=== Step 6: Listing artifacts ===
  123456 - test-artifact (1024 bytes)
  123457 - build-output (256 bytes)

Selected artifact ID: 123456

=== Step 7: Downloading artifact ===
Downloading artifact: test-artifact (ID: 123456)
  Downloaded to: artifacts/test-artifact.zip

=== Step 8: Verifying download ===
-rw-r--r--  1 user  staff  1.0K Nov  6 15:30 artifacts/test-artifact.zip

Artifact contents:
Archive:  artifacts/test-artifact.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
       30  2025-11-06 15:30   greeting.txt
      120  2025-11-06 15:30   build-info.txt
      150  2025-11-06 15:30   metadata.json
---------                     -------
      300                     3 files

✓ Example completed successfully!
Downloaded artifact: artifacts/test-artifact.zip
```

### Example 2: Download Single Artifact with Extraction

```bash
scripts/download-artifact-curl.sh --artifact-id "$artifact_id" --extract

# Output:
# Downloading artifact: test-artifact (ID: 123456)
#   Downloaded to: artifacts/test-artifact.zip
#   Extracted to: artifacts/test-artifact
```

### Example 3: Download All Artifacts for Run

```bash
scripts/download-artifact-curl.sh --run-id 1234567890 --all

# Output:
# Downloading 2 artifact(s)...
#
# [1/2] Downloading artifact: artifact-1 (ID: 123456)
#   Downloaded to: artifacts/artifact-1.zip
#
# [2/2] Downloading artifact: artifact-2 (ID: 123457)
#   Downloaded to: artifacts/artifact-2.zip
#
# Downloaded 2 of 2 artifact(s) to: artifacts
```

### Example 4: Download All Artifacts with Extraction

```bash
scripts/download-artifact-curl.sh --run-id 1234567890 --all --extract

# Output includes extraction for each artifact:
# [1/2] Downloading artifact: artifact-1 (ID: 123456)
#   Downloaded to: artifacts/artifact-1.zip
#   Extracted to: artifacts/artifact-1
```

### Example 5: Download Filtered Artifacts

```bash
scripts/download-artifact-curl.sh --run-id 1234567890 --all --name-filter "build-"

# Downloads only artifacts whose names contain "build-"
```

### Example 6: End-to-End Workflow

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

# Download all artifacts with extraction
scripts/download-artifact-curl.sh \
  --run-id "$run_id" \
  --all \
  --extract \
  --output-dir "my-artifacts"
```

### Example 7: Using Correlation ID

```bash
scripts/download-artifact-curl.sh \
  --correlation-id "$correlation_id" \
  --all \
  --extract
```

## Testing Strategy

### Static Validation

```bash
# Shell script linting
shellcheck scripts/download-artifact-curl.sh

# Script help
scripts/download-artifact-curl.sh --help

# Check executable permission
ls -la scripts/download-artifact-curl.sh
```

**Static Validation Results**:
- ✅ Shellcheck: No errors (only SC1091 info about sourced file)
- ✅ Help output: Works correctly
- ✅ Executable permission: Set correctly

### Manual Testing (Requires GitHub Access)

**Prerequisites**:
1. GitHub repository with workflow runs that produce artifacts
2. GitHub token with Actions: Read permissions
3. Token file: `./secrets/github_token` or `./secrets/token`
4. Workflow run with artifacts (or create test workflow that uploads artifacts)

**Test Matrix**:

**Single Artifact Tests**:
- ⏳ GH-24-1: Download single artifact by artifact_id
- ⏳ GH-24-2: Download single artifact with --extract
- ⏳ GH-24-7: Invalid artifact_id (404 error)
- ⏳ GH-24-8: Expired artifact (410 error)

**Bulk Download Tests**:
- ⏳ GH-24-3: Download all artifacts for run_id
- ⏳ GH-24-4: Download all artifacts with --extract
- ⏳ GH-24-5: Download with --name-filter
- ⏳ GH-24-6: Download with --output-dir
- ⏳ GH-24-12: No artifacts for run

**Integration Tests**:
- ⏳ GH-24-10: Auto-detect repository
- ⏳ GH-24-11: Correlation ID input
- ⏳ GH-24-13: Large artifact download (streaming)
- ⏳ GH-24-14: Invalid ZIP file
- ⏳ GH-24-15: Extraction failure

**Error Handling Tests**:
- ⏳ GH-24-9: Missing required fields (exit code 2)
- ⏳ Authentication failures (401/403)
- ⏳ Network errors

### Integration Tests

**End-to-End Test**:
```bash
# 1. Trigger workflow that produces artifacts
result=$(scripts/trigger-workflow-curl.sh \
  --workflow artifact-producer.yml \
  --json)

correlation_id=$(echo "$result" | jq -r '.correlation_id')

# 2. Correlate to get run_id
run_id=$(scripts/correlate-workflow-curl.sh \
  --correlation-id "$correlation_id" \
  --workflow artifact-producer.yml \
  --json-only)

# 3. Wait for completion

# 4. List artifacts
scripts/list-artifacts-curl.sh --run-id "$run_id"

# 5. Download all artifacts
scripts/download-artifact-curl.sh --run-id "$run_id" --all --extract

# 6. Verify downloads
ls -la artifacts/
```

**Status**: Integration testing pending GitHub repository access with workflow runs that produce artifacts.

## Compatibility with Previous Sprints

**Sprint 16 (GH-23)**:
- ✅ Integrates with `list-artifacts-curl.sh` for bulk downloads
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

## Known Limitations

1. **No Resume Support**: Interrupted downloads must be restarted from beginning
   - Mitigation: GitHub artifacts typically small, full redownload acceptable

2. **Sequential Downloads**: Bulk mode downloads artifacts sequentially, not in parallel
   - Mitigation: Simpler implementation, less risk of rate limiting, future enhancement possible

3. **No Progress Bar**: Large file downloads don't show progress percentage
   - Mitigation: File size typically visible in listing, completion message provided

4. **Unzip Dependency**: Extraction requires `unzip` command
   - Mitigation: Widely available on Unix-like systems, graceful degradation if missing

5. **No Retry Logic**: Failed downloads don't automatically retry
   - Mitigation: User can manually retry, bulk mode continues on individual failures

## Next Steps

**For Full Testing**:
1. Obtain GitHub repository access with workflow runs that produce artifacts
2. Configure GitHub token with appropriate permissions
3. Execute manual test matrix with GitHub repository access
4. Document test results in implementation notes
5. Update progress board with test results

**For Production Use**:
- Script is ready for use
- Follow usage examples in design document
- Ensure token file has correct permissions (600)
- Test in non-production environment first

**Future Enhancements** (not in current scope):
- Parallel downloads for bulk mode
- Progress bar for large downloads
- Retry logic with exponential backoff
- Resume support for interrupted downloads
- Automatic cleanup of old downloads

## Status Summary

**Design**: ✅ Complete (`progress/sprint_17_design.md`)
**Implementation**: ✅ Complete (script implemented)
**Static Validation**: ✅ Complete (shellcheck passed, help works)
**Manual Testing**: ⏳ Pending GitHub repository access with workflow runs that produce artifacts

**Blockers**:
- None (implementation complete)
- Testing requires GitHub repository access with workflow runs that produce artifacts

**Deliverables**:
- ✅ Design document complete
- ✅ Implementation script complete (`scripts/download-artifact-curl.sh`)
- ✅ Script help documentation (inline `--help`)
- ✅ Implementation notes complete (this document)
- ⏳ Test results (pending GitHub access)

**Files Created**:
- `scripts/download-artifact-curl.sh` (564 lines, executable)
- `progress/sprint_17_implementation.md` (this document)

**Files Updated**:
- `PROGRESS_BOARD.md` (Sprint 17 status: under_construction)
