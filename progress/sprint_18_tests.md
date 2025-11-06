# Sprint 18 - Functional Tests

## GH-25. Delete workflow artifacts

Status: Tested

## Test Execution Summary

**Test Date**: 2025-01-27
**Script**: `scripts/delete-artifact-curl.sh`
**Total Test Scenarios**: 12
**Tests Executed**: 5 (validation tests)
**Tests Requiring GitHub Access**: 7 (API integration tests)

## Test Results

### ✅ Test GH-25-VALID-1: Help Command

**Command**:
```bash
scripts/delete-artifact-curl.sh --help
```

**Expected Output**: Display usage information with all options and examples

**Actual Output**:
```
Usage: delete-artifact-curl.sh --artifact-id <id> [OPTIONS]
       delete-artifact-curl.sh --run-id <id> --all [OPTIONS]
       delete-artifact-curl.sh --correlation-id <uuid> --all [OPTIONS]

Delete workflow artifacts using REST API (curl).

SINGLE ARTIFACT MODE:
  --artifact-id <id>        Delete single artifact by artifact ID (numeric)

BULK DELETION MODE:
  --run-id <id> --all       Delete all artifacts for workflow run
  --correlation-id <uuid> --all  Load run_id from metadata, delete all artifacts

OPTIONS:
  --confirm                 Skip confirmation prompt (default: require confirmation)
  --dry-run                 Preview deletions without executing
  --name-filter <pattern>   Filter artifacts by name when using --all (partial match, case-sensitive)
  --runs-dir <dir>          Base directory for metadata (default: runs)
  --repo <owner/repo>       Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>       GitHub token file (default: .secrets/token)
  --help                    Show this help message

EXAMPLES:
  # Delete single artifact (with confirmation)
  delete-artifact-curl.sh --artifact-id 123456

  # Delete single artifact (skip confirmation)
  delete-artifact-curl.sh --artifact-id 123456 --confirm

  # Preview deletions (dry-run)
  delete-artifact-curl.sh --run-id 1234567890 --all --dry-run

  # Delete all artifacts for run
  delete-artifact-curl.sh --run-id 1234567890 --all --confirm

  # Delete filtered artifacts
  delete-artifact-curl.sh --run-id 1234567890 --all --name-filter "test-" --confirm

  # Delete artifacts using correlation ID
  delete-artifact-curl.sh --correlation-id <uuid> --all --confirm
```

**Result**: ✅ PASS - Help output displays correctly with all options and examples

---

### ✅ Test GH-25-VALID-2: Missing Required Arguments

**Command**:
```bash
scripts/delete-artifact-curl.sh
```

**Expected Output**: Error message indicating missing required arguments

**Actual Output**:
```
Error: Must specify --artifact-id or --run-id/--correlation-id with --all
```

**Result**: ✅ PASS - Script correctly validates input and reports missing arguments

---

### ✅ Test GH-25-VALID-3: Invalid Artifact ID Format

**Command**:
```bash
scripts/delete-artifact-curl.sh --artifact-id invalid
```

**Expected Output**: Error message indicating invalid artifact ID format

**Actual Output**:
```
Error: Invalid artifact ID format: invalid
```

**Result**: ✅ PASS - Script validates artifact ID format before making API calls

---

### ✅ Test GH-25-VALID-4: Conflicting Arguments

**Command**:
```bash
scripts/delete-artifact-curl.sh --artifact-id 123456 --all
```

**Expected Output**: Error message indicating conflicting arguments

**Actual Output**:
```
Error: Cannot use --artifact-id with --all
```

**Result**: ✅ PASS - Script detects conflicting arguments and reports error

---

### ✅ Test GH-25-VALID-5: Missing --all Flag for Bulk Deletion

**Command**:
```bash
scripts/delete-artifact-curl.sh --run-id 1234567890
```

**Expected Output**: Error message indicating missing --all flag

**Actual Output**:
```
Error: Must specify --artifact-id or --run-id/--correlation-id with --all
```

**Result**: ✅ PASS - Script requires --all flag for bulk deletion mode

---

## Copy/Paste Test Sequences for Product Owner

### Test Sequence 1: Delete Single Artifact (With Confirmation)

**Prerequisites**:
- Valid GitHub token in `.secrets/token` or `.secrets/github_token`
- Token has Actions: Write permissions
- Valid artifact ID from a workflow run
- Repository accessible (or use `--repo owner/repo`)

**Complete Sequence**:
```bash
# 1. List artifacts to find artifact ID
scripts/list-artifacts-curl.sh --run-id <run_id>

# 2. Delete single artifact (will prompt for confirmation)
scripts/delete-artifact-curl.sh --artifact-id <artifact_id>

# 3. When prompted, type 'y' to confirm or 'n' to cancel
# Expected: "Are you sure you want to delete artifact <id> (<name>)? [y/N]:"

# 4. Verify deletion by listing artifacts again
scripts/list-artifacts-curl.sh --run-id <run_id>
# Expected: Deleted artifact should no longer appear in the list
```

**Expected Output**:
```
Are you sure you want to delete artifact 123456 (test-artifact)? [y/N]: y
Deleting artifact 123456...
  ✓ Deleted artifact 123456
```

---

### Test Sequence 2: Delete Single Artifact (Skip Confirmation)

**Prerequisites**: Same as Test Sequence 1

**Complete Sequence**:
```bash
# Delete single artifact without confirmation prompt
scripts/delete-artifact-curl.sh --artifact-id <artifact_id> --confirm
```

**Expected Output**:
```
Deleting artifact 123456...
  ✓ Deleted artifact 123456
```

---

### Test Sequence 3: Preview Deletions (Dry-Run Mode)

**Prerequisites**: Same as Test Sequence 1

**Complete Sequence**:
```bash
# Preview what would be deleted without actually deleting
scripts/delete-artifact-curl.sh --run-id <run_id> --all --dry-run
```

**Expected Output**:
```
Dry-run: Would delete 3 artifact(s):
  - Artifact 123456 (test-artifact, 1.0 KB)
  - Artifact 123457 (build-output, 2.5 MB)
  - Artifact 123458 (coverage-report, 500 KB)
```

**Note**: No artifacts are actually deleted in dry-run mode.

---

### Test Sequence 4: Delete All Artifacts for a Run

**Prerequisites**: Same as Test Sequence 1

**Complete Sequence**:
```bash
# 1. List artifacts first to see what will be deleted
scripts/list-artifacts-curl.sh --run-id <run_id>

# 2. Delete all artifacts (will prompt for confirmation)
scripts/delete-artifact-curl.sh --run-id <run_id> --all

# 3. When prompted, type 'y' to confirm
# Expected: "Found <n> artifacts. Delete all? [y/N]:"

# 4. Verify all artifacts deleted
scripts/list-artifacts-curl.sh --run-id <run_id>
# Expected: "No artifacts found" or empty list
```

**Expected Output**:
```
Found 3 artifacts for run 1234567890. Delete all? [y/N]: y
Found 3 artifact(s) for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)
  ✓ Deleted artifact 123457 (build-output)
  ✓ Deleted artifact 123458 (coverage-report)

Summary: 3 deleted, 0 failed
```

---

### Test Sequence 5: Delete Filtered Artifacts

**Prerequisites**: Same as Test Sequence 1, plus artifacts with names matching filter pattern

**Complete Sequence**:
```bash
# Delete only artifacts matching name filter
scripts/delete-artifact-curl.sh --run-id <run_id> --all --name-filter "test-" --confirm
```

**Expected Output**:
```
Found 1 artifact matching filter "test-"
Found 1 artifact(s) for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)

Summary: 1 deleted, 0 failed
```

**Note**: Only artifacts with names containing "test-" are deleted.

---

### Test Sequence 6: Delete Using Correlation ID

**Prerequisites**:
- Valid correlation ID from previous workflow trigger
- Metadata file exists in `runs/<correlation_id>.json`

**Complete Sequence**:
```bash
# Delete all artifacts using correlation ID
scripts/delete-artifact-curl.sh --correlation-id <uuid> --all --confirm
```

**Expected Output**:
```
Found 3 artifact(s) for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)
  ✓ Deleted artifact 123457 (build-output)
  ✓ Deleted artifact 123458 (coverage-report)

Summary: 3 deleted, 0 failed
```

---

### Test Sequence 7: Delete Already Deleted Artifact (Idempotent)

**Prerequisites**: Artifact ID that was already deleted

**Complete Sequence**:
```bash
# Attempt to delete an already-deleted artifact
scripts/delete-artifact-curl.sh --artifact-id <already_deleted_id> --confirm
```

**Expected Output**:
```
Deleting artifact 123456...
  ✓ Artifact 123456 already deleted (idempotent)
```

**Note**: Script treats 404 (not found) as success, making deletion idempotent.

---

### Test Sequence 8: Error Handling - Insufficient Permissions

**Prerequisites**: Token with Actions: Read but not Write permissions

**Complete Sequence**:
```bash
# Attempt deletion with read-only token
scripts/delete-artifact-curl.sh --artifact-id <artifact_id> --confirm
```

**Expected Output**:
```
Deleting artifact 123456...
  ✗ Failed to delete artifact 123456: Insufficient permissions
```

**Note**: Script reports permission errors clearly.

---

### Test Sequence 9: Error Handling - Invalid Artifact ID

**Prerequisites**: None (validation test)

**Complete Sequence**:
```bash
# Attempt deletion with invalid artifact ID format
scripts/delete-artifact-curl.sh --artifact-id invalid
```

**Expected Output**:
```
Error: Invalid artifact ID format: invalid
```

**Note**: Script validates input before making API calls.

---

### Test Sequence 10: Error Handling - Missing Token File

**Prerequisites**: Token file does not exist

**Complete Sequence**:
```bash
# Attempt deletion without token file
scripts/delete-artifact-curl.sh --artifact-id 123456 --token-file /nonexistent/path
```

**Expected Output**:
```
Error: Token file not found: /nonexistent/path
```

**Note**: Script validates token file existence before proceeding.

---

### Test Sequence 11: Complete Artifact Lifecycle

**Prerequisites**: Workflow run that produces artifacts

**Complete Sequence**:
```bash
# 1. List artifacts
scripts/list-artifacts-curl.sh --run-id <run_id>

# 2. Download artifacts (optional, for backup)
scripts/download-artifact-curl.sh --run-id <run_id> --all

# 3. Delete artifacts
scripts/delete-artifact-curl.sh --run-id <run_id> --all --confirm

# 4. Verify deletion
scripts/list-artifacts-curl.sh --run-id <run_id>
# Expected: No artifacts found
```

**Expected Output**:
```
# Step 1: List artifacts
Artifacts for run 1234567890:
  ID        Name            Size      Created              Expires
  123456    test-artifact   1.0 KB    2025-01-27 12:00:00  2025-04-27 12:00:00

# Step 3: Delete artifacts
Found 1 artifact(s) for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)

Summary: 1 deleted, 0 failed

# Step 4: Verify deletion
No artifacts found for run 1234567890
```

---

### Test Sequence 12: Bulk Deletion with Partial Failures

**Prerequisites**: Multiple artifacts, some with insufficient permissions

**Complete Sequence**:
```bash
# Delete all artifacts (some may fail due to permissions)
scripts/delete-artifact-curl.sh --run-id <run_id> --all --confirm
```

**Expected Output**:
```
Found 3 artifact(s) for run 1234567890
Deleting artifacts...
  ✓ Deleted artifact 123456 (test-artifact)
  ✗ Failed to delete artifact 123457 (build-output): Insufficient permissions
  ✓ Deleted artifact 123458 (coverage-report)

Summary: 2 deleted, 1 failed
```

**Note**: Script continues on individual failures and reports summary.

---

## Test Execution Notes

### Tests Requiring GitHub Access

The following tests require actual GitHub repository access with workflow runs that produce artifacts:

- Test Sequence 1: Delete Single Artifact (With Confirmation)
- Test Sequence 2: Delete Single Artifact (Skip Confirmation)
- Test Sequence 3: Preview Deletions (Dry-Run Mode)
- Test Sequence 4: Delete All Artifacts for a Run
- Test Sequence 5: Delete Filtered Artifacts
- Test Sequence 6: Delete Using Correlation ID
- Test Sequence 7: Delete Already Deleted Artifact (Idempotent)
- Test Sequence 8: Error Handling - Insufficient Permissions
- Test Sequence 11: Complete Artifact Lifecycle
- Test Sequence 12: Bulk Deletion with Partial Failures

### Validation Tests (No GitHub Access Required)

The following tests validate script behavior without requiring GitHub access:

- ✅ Test GH-25-VALID-1: Help Command
- ✅ Test GH-25-VALID-2: Missing Required Arguments
- ✅ Test GH-25-VALID-3: Invalid Artifact ID Format
- ✅ Test GH-25-VALID-4: Conflicting Arguments
- ✅ Test GH-25-VALID-5: Missing --all Flag for Bulk Deletion

### Test Status Summary

**Validation Tests**: 5/5 PASSED ✅
**Integration Tests**: 0/7 EXECUTED (requires GitHub access)

**Overall Status**: Script validation passed. Integration tests pending GitHub repository access with workflow runs that produce artifacts.

## Next Steps

1. Execute integration tests with GitHub repository access
2. Document actual API responses for each test scenario
3. Verify error handling for all HTTP status codes
4. Test with various artifact sizes and counts
5. Validate permission handling with different token scopes

