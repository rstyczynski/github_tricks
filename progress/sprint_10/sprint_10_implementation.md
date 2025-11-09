# Sprint 10 - Implementation Notes

## GH-13. Caller gets data produced by a workflow

Status: FAILED - Platform Limitation (Product Owner Decision: Option C)

## Executive Summary

**Status**: Sprint FAILED - Marked as not feasible with current GitHub API
**Decision**: Product Owner selected Option C - Mark as FAILED due to platform limitation
**Reason**: GitHub REST API does NOT expose job outputs, making the requirement impossible to implement as specified
**Date**: 2025-11-06
**Test attempts**: 1/10 (terminated after discovering blocker)

### Critical Finding

**GitHub Actions job outputs are NOT available via REST API**, despite being properly set in workflows.

### Evidence

**Workflow execution**: Run ID 19141702114
**Test case**: Add operation (15 + 25 = 40)
**Workflow logs confirm**:
- Output was generated: `{"operation":"add","inputs":{"value1":"15","value2":"25"},"result":"40",...}`
- Output was set: "Set output 'result_data'" message in "Complete job" step

**API response**:
```json
{
  "name": "process",
  "status": "completed",
  "conclusion": "success",
  "outputs": null  ← NULL despite output being set
}
```

**API endpoint tested**: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`

### Implementation Completed

Despite the blocker, all components were implemented according to design:

#### 1. Workflow: `.github/workflows/data-processor.yml`

**Features implemented**:
- Accepts typed inputs (operation, value1, value2, correlation_id)
- Validates inputs (numeric for add/multiply)
- Performs operations (add, multiply, concat)
- Generates JSON output structure
- Sets job output via `$GITHUB_OUTPUT`
- Displays summary in job summary

**Validation**: ✅ actionlint passed, workflow executes successfully

**Example execution**:
```bash
gh workflow run data-processor.yml \
  --ref main \
  --raw-field operation=add \
  --raw-field value1=15 \
  --raw-field value2=25
```

#### 2. Client Script: `scripts/get-workflow-output.sh`

**Features implemented**:
- Multiple input methods (--run-id, --correlation-id, stdin JSON)
- Integration with Sprint 1 correlation metadata
- Wait mode for workflow completion
- JSON and human-readable output formats
- Comprehensive error handling

**Validation**: ✅ shellcheck passed (SC1091 info only)

**Blocker**: Cannot retrieve outputs because API returns `null`

#### 3. Test Script: `scripts/test-workflow-output.sh`

**Test cases implemented**:
1. Add operation (10 + 20 = 30)
2. Multiply operation (5 * 7 = 35)
3. Concat operation ("hello" + "world" = "helloworld")
4. Correlation ID tracking
5. Pipeline composition

**Status**: Cannot execute due to API limitation

### Alternative Approaches Analysis

#### Option A: Use Artifacts (REJECTED)

**Reason**: Requirement explicitly states "NOT about artifacts"

**Technical feasibility**: ✅ Would work
- Workflow uploads JSON as artifact
- Client downloads artifact via `gh run download` or API
- Proven pattern in ecosystem

**Verdict**: Violates requirement constraint

#### Option B: Parse Logs (POSSIBLE but FRAGILE)

**Approach**:
- Workflow prints JSON to stdout with marker
- Client downloads logs via `gh run view --log`
- Parse logs to extract JSON between markers

**Pros**:
- No artifacts used
- Logs are available via API/CLI
- Simple data retrieval

**Cons**:
- Fragile (log format changes break it)
- Requires log download and parsing
- No structured API endpoint
- Marker collision risk in complex workflows

**Implementation complexity**: Medium

#### Option C: External Webhook (OUT OF SCOPE)

**Approach**:
- Workflow posts data to external service (already implemented in Sprint 1)
- Client retrieves from external service

**Pros**:
- Proven pattern (Sprint 1 webhook mechanism)
- Real-time availability

**Cons**:
- Requires external infrastructure
- Not "GitHub REST API" as required
- Additional complexity

**Verdict**: Out of scope for GH-13

#### Option D: Job Step Output in Logs (RECOMMENDED)

**Approach**:
- Workflow prints JSON with unique marker: `###WORKFLOW_OUTPUT_START###`
- Client downloads logs
- Extract JSON between markers

**Example workflow modification**:
```yaml
- name: Emit output
  run: |
    echo "###WORKFLOW_OUTPUT_START###"
    echo "$result_json"
    echo "###WORKFLOW_OUTPUT_END###"
```

**Example client modification**:
```bash
gh run view "$run_id" --log | \
  sed -n '/###WORKFLOW_OUTPUT_START###/,/###WORKFLOW_OUTPUT_END###/p' | \
  grep -v "###WORKFLOW_OUTPUT"
```

**Pros**:
- No artifacts
- Uses GitHub REST API (log download endpoint)
- Reliable markers
- Simple parsing

**Cons**:
- Requires log parsing
- Not as clean as dedicated API endpoint
- Subject to log retention policies

**Verdict**: Best available option given constraints

### Recommendation

🚨 **RED FLAG: Requirement GH-13 cannot be implemented as specified** 🚨

**Issue**: GitHub REST API does not expose job outputs

**Proposed solutions** (in order of preference):

1. **RECOMMENDED**: Modify requirement to allow log parsing
   - Implement Option D (job step output in logs with markers)
   - Still uses GitHub REST API (logs endpoint)
   - Satisfies "simple data structures" and "no artifacts" constraints
   - Clean separation with markers

2. **ALTERNATIVE**: Relax "no artifacts" constraint
   - Implement Option A (artifacts)
   - Most reliable and structured approach
   - Widely used pattern in GitHub Actions ecosystem
   - Full API support

3. **FALLBACK**: Mark requirement as "not feasible" with current GitHub API
   - Document platform limitation
   - Recommend tracking GitHub API roadmap for job output support

### Product Owner Decision Required

Please select one of the following:

**A.** Accept log parsing approach (Option D) - modify requirement to allow parsing logs as "synchronous interface"

**B.** Accept artifacts approach (Option A) - relax "no artifacts" constraint

**C.** Mark requirement as FAILED due to platform limitation - document for future when GitHub adds API support

**D.** Other approach (please specify)

### Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Workflow | ✅ Complete | Executes correctly, sets outputs |
| Client script | ✅ Complete | All features implemented except retrieval |
| Test script | ✅ Complete | All test cases defined |
| Static validation | ✅ Pass | actionlint, shellcheck |
| Functional tests | 🚫 BLOCKED | API limitation prevents retrieval |
| Documentation | ⏳ Pending | Awaiting decision on approach |

### Test Results

**Attempt 1/10**: BLOCKED
**Blocker**: GitHub API limitation discovered
**Manual verification**: Run 19141702114 executed successfully, outputs confirmed in logs but not in API

### Files Created

1. `.github/workflows/data-processor.yml` - Workflow implementation
2. `scripts/get-workflow-output.sh` - Client script (retrieval blocked)
3. `scripts/test-workflow-output.sh` - Test suite (cannot run)
4. `progress/sprint_10_design.md` - Design document
5. `progress/sprint_10_implementation.md` - This document

### Final Decision

**Product Owner Decision**: Option C - Mark as FAILED due to platform limitation

**Rationale**:
- GitHub API does not currently support job output retrieval
- Requirement explicitly states "NOT artifacts" and "GitHub REST API exclusively"
- Alternative approaches (log parsing, artifacts) would violate requirement constraints
- Sprint documented for future reference when GitHub adds API support

**Sprint Status**: FAILED
**Recommendation**: Monitor GitHub API roadmap for job output endpoint support

### References

- Run ID 19141702114: https://github.com/rstyczynski/github_tricks/actions/runs/19141702114
- GitHub API docs: https://docs.github.com/en/rest/actions/workflow-runs
- Sprint 1 webhook mechanism: `progress/sprint_1_implementation.md`
- Sprint 5 API analysis: `progress/sprint_5_implementation.md`
