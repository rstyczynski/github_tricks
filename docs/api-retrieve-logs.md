# Retrieve GitHub Workflow Logs via REST API

**API Operation Summary** | Sprint 15 Implementation (GH-16)

## Purpose

Retrieve execution logs from completed or running workflow jobs. Supports single-job retrieval and multi-job aggregation.

## API Endpoint

```
GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs
```

**Documentation**: [GitHub REST API - Download job logs](https://docs.github.com/en/rest/actions/workflow-jobs#download-job-logs)

## Usage Example

```bash
# Retrieve logs for a run
./scripts/fetch-logs-curl.sh --run-id 123456789

# With correlation ID
./scripts/fetch-logs-curl.sh --correlation-id "$CORRELATION_ID"
```

**Expected Output**:
```
✓ Logs retrieved successfully
  Jobs: 3
  Total size: 45 KB
  Output: logs/run_123456789/

Files created:
  - logs/run_123456789/job_1_build.log
  - logs/run_123456789/job_2_test.log
  - logs/run_123456789/job_3_deploy.log
  - logs/run_123456789/combined.log
```

## Log Availability Timing

**From Sprint 5.1 benchmarks**:
- Logs available: 1-2 seconds after job completion
- Early fetch returns HTTP 404
- Implement retry logic for robustness

## Multi-Job Aggregation

Script automatically:
1. Lists all jobs for run
2. Downloads each job log
3. Creates combined.log with all logs
4. Preserves individual job logs

## Implementation Reference

**Sprint**: Sprint 15 (GH-16)
**Script**: `scripts/fetch-logs-curl.sh`
**Timing Data**: `progress/sprint_4_tests.md` (Sprint 5.1 benchmarks)
