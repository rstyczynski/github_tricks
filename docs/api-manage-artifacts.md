# Manage GitHub Workflow Artifacts via REST API

**API Operation Summary** | Sprints 16-18 Implementation (GH-23, GH-24, GH-25)

## Purpose

Complete artifact lifecycle management: listing, downloading, and deleting workflow artifacts. Enables automation of artifact cleanup, archival, and distribution.

## API Endpoints

### List Artifacts
```
GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts
```

### Download Artifact
```
GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip
```

### Delete Artifact
```
DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}
```

**Documentation**: [GitHub REST API - Artifacts](https://docs.github.com/en/rest/actions/artifacts)

## Complete Lifecycle Example

```bash
# Step 1: List artifacts for a run
./scripts/list-artifacts-curl.sh --run-id 123456789

# Step 2: Download specific artifact
./scripts/download-artifact-curl.sh --artifact-id 987654321

# Step 3: Delete artifact after processing
./scripts/delete-artifact-curl.sh --artifact-id 987654321 --confirm
```

## List Artifacts (GH-23)

**Sprint**: 16
**Script**: `scripts/list-artifacts-curl.sh`

```bash
# List all artifacts for a run
./scripts/list-artifacts-curl.sh --run-id 123456789

# Filter by name
./scripts/list-artifacts-curl.sh --run-id 123456789 --name "test-results"

# JSON output
./scripts/list-artifacts-curl.sh --run-id 123456789 --json
```

## Download Artifacts (GH-24)

**Sprint**: 17
**Script**: `scripts/download-artifact-curl.sh`

```bash
# Download by artifact ID
./scripts/download-artifact-curl.sh --artifact-id 987654321

# Download by name and run ID
./scripts/download-artifact-curl.sh \
  --run-id 123456789 \
  --name "test-results"

# Download all artifacts for a run
./scripts/download-artifact-curl.sh --run-id 123456789 --all
```

## Delete Artifacts (GH-25)

**Sprint**: 18
**Script**: `scripts/delete-artifact-curl.sh`

### Safety Features
- Confirmation prompt (default)
- Dry-run mode (`--dry-run`)
- Idempotent (HTTP 404 treated as success)

```bash
# Delete with confirmation
./scripts/delete-artifact-curl.sh --artifact-id 987654321

# Delete without confirmation (automation)
./scripts/delete-artifact-curl.sh --artifact-id 987654321 --confirm

# Dry-run to preview
./scripts/delete-artifact-curl.sh --run-id 123456789 --all --dry-run

# Bulk delete with name filter
./scripts/delete-artifact-curl.sh \
  --run-id 123456789 \
  --all \
  --name "test-*" \
  --confirm
```

## Integration Pattern: List → Download → Delete

```bash
# Complete workflow
RUN_ID=123456789

# 1. List artifacts
echo "Listing artifacts for run $RUN_ID..."
ARTIFACTS=$(./scripts/list-artifacts-curl.sh --run-id "$RUN_ID" --json)

# 2. Download all artifacts
echo "Downloading artifacts..."
./scripts/download-artifact-curl.sh --run-id "$RUN_ID" --all

# 3. Delete artifacts after processing
echo "Cleaning up artifacts..."
./scripts/delete-artifact-curl.sh --run-id "$RUN_ID" --all --confirm
```

## Implementation References

- **Sprint 16** (GH-23): List artifacts - `progress/sprint_16_implementation.md`
- **Sprint 17** (GH-24): Download artifacts - `progress/sprint_17_implementation.md`
- **Sprint 18** (GH-25): Delete artifacts - `progress/sprint_18_implementation.md`
