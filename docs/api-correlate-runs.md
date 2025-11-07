# Correlate GitHub Workflow Runs via REST API

**API Operation Summary** | Sprint 15 Implementation (GH-15)

## Purpose

Correlate triggered workflow runs using UUID-based identification to retrieve `run_id` for subsequent operations (log retrieval, status monitoring, cancellation). Essential for tracking workflow execution after trigger.

## API Endpoint

```
GET /repos/{owner}/{repo}/actions/runs?created=>={timestamp}&per_page=100
```

**Documentation**: [GitHub REST API - List workflow runs](https://docs.github.com/en/rest/actions/workflow-runs#list-workflow-runs)

## Usage Example

```bash
# Step 1: Trigger workflow with correlation ID
CORRELATION_ID=$(uuidgen)
./scripts/trigger-workflow-curl.sh \
  --workflow .github/workflows/test.yml \
  --correlation-id "$CORRELATION_ID"

# Step 2: Correlate to get run_id (wait 2-5 seconds for run visibility)
sleep 3
./scripts/correlate-workflow-curl.sh --correlation-id "$CORRELATION_ID"
```

**Expected Output**:
```
✓ Workflow run found
  Run ID: 123456789
  Status: in_progress
  Correlation ID: a1b2c3d4-5678-90ab-cdef-1234567890ab
```

## Correlation Strategies

### UUID-Based Correlation (Recommended)
- Uses correlation_id in workflow run name
- Pattern: `run-name: "workflow-${{ github.event.inputs.correlation_id }}"`
- Most reliable for automated workflows

### Filtering Options
- `--workflow <workflow_name>`: Filter by workflow file
- `--branch <branch>`: Filter by branch
- `--actor <username>`: Filter by triggering user
- `--status <status>`: Filter by run status

## Timing Considerations

**Typical Delays** (from Sprint 3.1 benchmarks):
- Minimum: 2-3 seconds after trigger
- Average: 3-5 seconds
- Maximum observed: 8-10 seconds

**Best Practice**: Implement retry logic with exponential backoff

## Implementation Reference

**Sprint**: Sprint 15 (GH-15)
**Script**: `scripts/correlate-workflow-curl.sh`
**Timing Data**: `progress/sprint_4_tests.md` (Sprint 3.1 benchmarks)
