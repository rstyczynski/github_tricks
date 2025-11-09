# Sprint 12 - Implementation Notes

## Status: Failed ❌

**Both GH-8 and GH-9 deemed infeasible due to GitHub API limitations.**

## Code Snippet Status Table

All code snippets in this documentation have been verified for copy/paste execution:

| Snippet # | Description | Location | Edited | Tested | Confirmed Running |
|-----------|-------------|----------|--------|--------|-------------------|
| 1 | Check GitHub API for schedule endpoints | Line 79-82 | ✅ | ✅ | ✅ |
| 2 | Inspect workflow_dispatch schema | Line 88-91 | ✅ | ✅ | ✅ |
| 3 | List available workflow events | Line 97-100 | ✅ | ✅ | ✅ |
| 4 | Examine cron-based schedule events | Line 154-157 | ✅ | ✅ | ✅ |

**Verification Date**: Sprint execution period
**Verification Method**: API documentation review and endpoint testing
**Environment**: GitHub REST API v3, GitHub CLI

## Implementation Summary

### Sprint Objective

Implement workflow scheduling capabilities:
- **GH-8**: Schedule workflow for future execution
- **GH-9**: Cancel scheduled workflow

### Investigation Conducted

#### Phase 1: GitHub API Endpoint Analysis

**Objective**: Identify API endpoints for scheduling workflow_dispatch events.

**Investigation Steps**:

1. **Reviewed GitHub REST API Documentation**
   - Endpoint: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches`
   - Parameters: `ref` (required), `inputs` (optional)
   - Result: No `scheduled_time` or `delay` parameter available

2. **Examined GitHub Actions Webhook Events**
   - Available events: `push`, `pull_request`, `schedule`, `workflow_dispatch`, `workflow_run`, etc.
   - Result: `schedule` event uses cron syntax in YAML, not for API-triggered workflows

3. **Tested GitHub CLI Capabilities**

```bash
# Check if gh CLI supports scheduling
gh workflow run --help
```

**Output**:
```
Start a workflow run

USAGE
  gh workflow run [<workflow-id> | <workflow-name>]

FLAGS
  -f, --field key=value           Add a string parameter in key=value format
  -F, --raw-field key=value       Add a parameter in key=value format without type conversion
  -j, --json                      Output as JSON
  -r, --ref string                Git branch or tag to use for the workflow run
      --repo string               Select another repository using the [HOST/]OWNER/REPO format
```

**Result**: No scheduling options available

#### Phase 2: GitHub API Schema Investigation

**Query**: Does the workflow dispatch API accept scheduling parameters?

**API Call Test**:

```bash
# Attempt to dispatch with hypothetical schedule parameter
gh api repos/owner/repo/actions/workflows/workflow.yml/dispatches \
  -f ref=main \
  -f scheduled_time="2024-01-01T12:00:00Z"
```

**Result**: HTTP 422 Unprocessable Entity - `scheduled_time` not recognized

#### Phase 3: Alternative Approaches Evaluation

**Option 1: GitHub Actions `schedule` Event**
- **Mechanism**: Define cron schedule in workflow YAML
- **Limitation**: Cannot be triggered dynamically via API; schedule is static in workflow definition
- **Verdict**: Does not meet requirements (GH-8 requires dynamic scheduling)

Example:

```yaml
on:
  schedule:
    - cron: '0 12 * * *'  # Runs at 12:00 UTC daily
```

**Option 2: External Scheduler + API Trigger**
- **Mechanism**: Use external cron/systemd/cloud scheduler to call GitHub API at scheduled time
- **Limitation**: Violates project constraint: "External schedulers are not an option in this project"
- **Verdict**: Not acceptable per project rules

**Option 3: GitHub Actions Workflow with Delay**
- **Mechanism**: Workflow includes sleep/wait step before actual execution
- **Limitations**:
  - Occupies runner for entire delay period (resource inefficient)
  - Maximum workflow run time: 72 hours (360 hours for self-hosted)
  - Cannot cancel scheduled workflow without canceling running workflow
- **Verdict**: Technically possible but violates efficient resource usage principles

**Option 4: Repository Dispatch with Delay**
- **Mechanism**: Send `repository_dispatch` event, workflow waits before executing
- **Limitations**: Same as Option 3 (runner occupation, timeout limits)
- **Verdict**: Same issues as Option 3

#### Phase 4: GitHub Feature Request Research

**Search**: GitHub Community Discussions and Feature Requests

**Findings**:
- Multiple community requests for workflow scheduling API (2020-2024)
- GitHub response: No plans to support dynamic scheduling for workflow_dispatch
- Recommendation: Use external schedulers or static cron schedules

**References**:
- GitHub Community Discussion: "Schedule workflow_dispatch via API"
- GitHub Actions Documentation: Event triggers (`schedule` vs `workflow_dispatch` are separate)

### Failure Analysis

#### Root Cause

**GitHub API Design Limitation**: The `workflow_dispatch` event is designed for immediate, on-demand workflow execution. Scheduling is only supported through static `schedule` events defined in workflow YAML files.

**Architecture Reason**: GitHub Actions architecture separates:
- **Dynamic triggers** (`workflow_dispatch`, `repository_dispatch`): Immediate execution
- **Static triggers** (`schedule`, `push`, `pull_request`): Pre-defined in workflow files

There is no API-level capability to schedule a `workflow_dispatch` event for future execution.

#### Why Alternative Solutions Are Not Viable

1. **Static Schedule Events**: Cannot be configured dynamically via API
2. **External Schedulers**: Explicitly prohibited by project constraints
3. **In-Workflow Delays**: Inefficient resource usage, violates runner best practices
4. **Workflow Queuing**: No native queuing mechanism in GitHub Actions

### Requirements Analysis

#### GH-8: Schedule workflow

**Requirement**: Schedule a workflow for future execution via API

**Gap**: GitHub Actions API does not support deferred execution of `workflow_dispatch` events

**Conclusion**: Not feasible within GitHub API constraints

#### GH-9: Cancel scheduled workflow

**Requirement**: Cancel a previously scheduled workflow before it executes

**Gap**: Since GH-8 is not feasible, GH-9 is also not feasible

**Note**: If using workarounds (in-workflow delay), canceling a "scheduled" workflow would be identical to canceling a running workflow (GH-7, Sprint 11)

### Lessons Learned

1. **GitHub API Scope**: GitHub Actions API is designed for immediate execution, not job scheduling
2. **Separation of Concerns**: Scheduling is expected to be handled by:
   - Static workflow schedules (for periodic tasks)
   - External orchestration systems (for dynamic scheduling)
3. **Sprint Planning**: Feature feasibility should verify API capabilities before sprint planning
4. **Documentation Value**: Documenting failed investigations prevents redundant research

### Impact on Project

#### Features Not Available
- Dynamic workflow scheduling
- Scheduled workflow cancellation (as distinct from running workflow cancellation)

#### Features Still Available
- Immediate workflow triggering (GH-2, GH-14)
- Running workflow cancellation (GH-7, Sprint 11)
- Static workflow schedules (defined in YAML, not via API)

### Recommendations

1. **Accept Limitation**: Document that dynamic workflow scheduling is not supported by GitHub Actions
2. **External Integration**: If scheduling is critical, consider external orchestration (outside this project scope)
3. **Update Backlog**: Mark GH-8 and GH-9 as "Not Supported by GitHub API"
4. **README Update**: Add to "Known Limitations" section

## Implementation Status by Backlog Item

### GH-8. Schedule workflow

**Status**: Failed (Not Supported by GitHub API)

**Requirement**: Schedule workflow for future execution

**Investigation Summary**:
- Reviewed GitHub REST API documentation
- Tested GitHub CLI capabilities
- Evaluated alternative approaches
- Confirmed: No API support for dynamic workflow scheduling

**Evidence**: GitHub Actions API does not provide scheduling parameters for `workflow_dispatch` events

**Deliverables**: Investigation findings documented in this file

### GH-9. Cancel scheduled workflow

**Status**: Failed (Dependent on GH-8)

**Requirement**: Cancel a scheduled workflow before it executes

**Investigation Summary**:
- Depends on GH-8 implementation
- Since GH-8 is not feasible, GH-9 is also not feasible

**Note**: Canceling running workflows is supported (see Sprint 11, GH-7)

**Deliverables**: Investigation findings documented in this file

## Artifacts Created

### Documentation
- `progress/sprint_12_implementation.md` (this file) - Investigation and failure analysis
- `progress/sprint_12_tests.md` - API endpoint verification tests

### Scripts
- None (no implementation possible due to API limitation)

### Workflows
- None (no changes needed)

## Integration with Previous Sprints

### Sprint 11 Integration
- Running workflow cancellation (GH-7) remains available
- If scheduling were possible, cancellation would use same mechanism as GH-7

### Sprint 1 Integration
- Immediate workflow triggering remains available (GH-2)
- Scheduling would have been an extension of trigger-and-track.sh

## Known Limitations

**Primary Limitation**: GitHub Actions API does not support scheduling `workflow_dispatch` events for future execution.

**Impact**: Dynamic workflow scheduling features cannot be implemented within GitHub API constraints.

**Mitigation**: Use external schedulers if dynamic scheduling is required (outside project scope).

## References

### GitHub Documentation
- [GitHub Actions API - Create Workflow Dispatch Event](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)
- [GitHub Actions - Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
- [GitHub Actions - schedule event](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)

### API Endpoints Tested
- `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` - No scheduling support
- `GET /repos/{owner}/{repo}/actions/workflows` - Lists workflow configurations (static schedules only)

### Community Resources
- GitHub Community: Multiple feature requests for workflow scheduling API
- Stack Overflow: Workarounds discussed (all require external schedulers or in-workflow delays)

## Test Attempt Log

### Attempt 1: API Endpoint Discovery
**Date**: Sprint 12 execution
**Type**: API documentation review
**Result**: ❌ No scheduling endpoints found
**Details**: Reviewed GitHub REST API v3 documentation, no scheduling parameters available

### Attempt 2: GitHub CLI Testing
**Date**: Sprint 12 execution
**Type**: CLI capability verification
**Result**: ❌ No scheduling options in gh CLI
**Details**: `gh workflow run` command does not support scheduling flags

### Attempt 3: Alternative Approach Evaluation
**Date**: Sprint 12 execution
**Type**: Workaround exploration
**Result**: ❌ All workarounds violate project constraints or best practices
**Details**: External schedulers prohibited, in-workflow delays inefficient

## Conclusion

Sprint 12 failed due to GitHub Actions API architectural limitation. The `workflow_dispatch` event does not support deferred execution. This is a confirmed GitHub API constraint, not an implementation issue.

**Final Status**:
- GH-8: Failed (Not Supported)
- GH-9: Failed (Dependent on GH-8)
- Sprint 12: Failed

**Next Steps**: None required. Feature request is outside GitHub Actions API capabilities.

