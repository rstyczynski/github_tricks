# Elaboration Sprint 11 - Chat 1

**Date**: 2025-11-06
**Sprint**: 11
**Phase**: Elaboration (Design)
**Status**: Complete - Awaiting Product Owner Approval

## Design Completion Confirmation

### Requirements Addressed

**GH-6. Cancel requested workflow**:
- Requirement: Dispatch workflow and cancel it right after dispatching
- Design solution: `cancel-run.sh --run-id <id>` immediately after `trigger-and-track.sh`
- Expected outcome: Workflow never executes, conclusion: cancelled
- Testing: Immediate cancellation test scenario

**GH-7. Cancel running workflow**:
- Requirement: Dispatch, wait for run_id, then cancel at different stages
- Design solution: Cancel after correlation (early) and during execution (late)
- Expected outcomes:
  - Early: Workflow in queued/early in_progress, cancelled before significant execution
  - Late: Some jobs completed, remaining cancelled
- Testing: Two timing scenarios with status verification

### Major Design Decisions

**1. Dual Implementation Approach** (gh CLI + curl)
- **Decision**: Implement both `cancel-run.sh` (gh CLI) and `cancel-run-curl.sh` (REST API)
- **Rationale**: Supports browser-auth and token-auth workflows, follows Sprint 8/9 pattern
- **Precedent**: Sprint 8 (`view-run-jobs.sh`) and Sprint 9 (`view-run-jobs-curl.sh`)

**2. Input Resolution Pattern** (multiple sources)
- **Decision**: Support `--run-id`, `--correlation-id`, stdin JSON, interactive prompt
- **Rationale**: Consistency with Sprint 8, enables flexible integration
- **Priority**: Explicit flags → correlation metadata → stdin → interactive

**3. Asynchronous by Default, Synchronous Optional** (--wait flag)
- **Decision**: Default returns immediately (HTTP 202), `--wait` polls until cancelled
- **Rationale**: Matches GitHub API async nature, supports both use cases
- **Implementation**: `wait_for_cancellation()` function with 60s timeout, 2s intervals

**4. Force Cancellation Opt-in** (--force flag)
- **Decision**: Standard cancel by default, force-cancel requires explicit flag
- **Rationale**: Prevents accidental cleanup skip, requires intentional usage
- **Use case**: Stuck workflows that ignore standard cancellation signals

**5. Status Before/After Tracking** (get_run_status)
- **Decision**: Query and record status before cancellation
- **Rationale**: Documents which state workflow was in, enables timing analysis
- **Output**: Included in JSON output, shown in human-readable format

**6. Error Handling Granularity** (HTTP status mapping)
- **Decision**: Specific error messages for each HTTP status code
- **HTTP 202**: Success
- **HTTP 409**: Already completed (informational, not hard error)
- **HTTP 404**: Run not found (error)
- **HTTP 403/401**: Permission issues (error with guidance)
- **Rationale**: Clear, actionable feedback for operators

**7. Comprehensive Test Matrix** (10 scenarios)
- **Decision**: Test matrix covering GH-6, GH-7, errors, integration
- **Scenarios**:
  - GH-6: Immediate cancellation
  - GH-7: Early (after correlation) and late (during execution)
  - Errors: Already completed, invalid run ID
  - Integration: Pipeline, --wait flag, --force flag
- **Rationale**: Ensures robust implementation across use cases

**8. Timing Observations Framework** (measurements)
- **Decision**: Document cancellation request latency, completion time, status at cancellation
- **Metrics**:
  - Request latency: <1 second expected
  - Completion time: 5-30 seconds depending on workflow state
  - Jobs completed before cancellation: 0-N
- **Rationale**: Characterize cancellation behavior, guide operator expectations

### Integration Architecture

**Integration with Sprint 1** (trigger-and-track.sh):
```
trigger-and-track.sh → correlation_id → metadata.json
                    ↓
cancel-run.sh --correlation-id <uuid> --runs-dir runs
```

**Integration with Sprint 8/9** (view-run-jobs.sh):
```
cancel-run.sh --run-id <id> --wait
                    ↓
view-run-jobs.sh --run-id <id> → verify conclusion: cancelled
```

**Integration with Sprint 3** (lib/run-utils.sh):
```
cancel-run.sh sources lib/run-utils.sh
              ↓
resolve_run_id() → reads metadata.json
```

### Implementation Specifications

**Primary Script**: `scripts/cancel-run.sh`

**CLI Interface**:
```bash
scripts/cancel-run.sh [--run-id <id>] [--correlation-id <uuid>] 
                      [--runs-dir <dir>] [--force] [--wait] [--json]
```

**Key Functions Designed**:

1. `cancel_run_gh(run_id, force)`:
   - Uses `gh run cancel <run_id>` or `gh api POST /force-cancel`
   - Returns 0 on success (HTTP 202), 1 on failure
   - Error handling for all HTTP status codes

2. `wait_for_cancellation(run_id)`:
   - Polls `gh run view --json status,conclusion` every 2 seconds
   - Exits when status="completed" and conclusion="cancelled"
   - Timeout: 60 seconds, warns if not completed

3. `get_run_status(run_id)`:
   - Queries current status before cancellation
   - Returns status string (queued, in_progress, completed)
   - Used for before/after comparison

4. `resolve_run_id_input()`:
   - Reuses `lib/run-utils.sh` functions
   - Priority: --run-id → --correlation-id → stdin → interactive
   - Consistent with Sprint 8 pattern

**Alternative Script**: `scripts/cancel-run-curl.sh`

**Additional Features**:
- Token loading from file (default: `./secrets/github_token`)
- Repository auto-detection from git remote
- Direct REST API calls with curl
- Follows Sprint 9 implementation pattern

**Output Formats**:

Human-readable:
```
Cancelling workflow run: 1234567890
Status before cancellation: in_progress
Cancellation requested (HTTP 202 Accepted)
[--wait] Waiting for cancellation to complete...
Final status: completed
Final conclusion: cancelled
Cancellation completed in 3 seconds
```

JSON:
```json
{
  "run_id": 1234567890,
  "status_before": "in_progress",
  "cancellation_requested": true,
  "final_status": "completed",
  "final_conclusion": "cancelled",
  "cancellation_duration_seconds": 3
}
```

### Test Strategy Summary

**Test Matrix** (10 scenarios):

| ID | Scenario | State | Method | Expected |
|----|----------|-------|--------|----------|
| GH-6-1 | Immediate cancel | Not started | --run-id | Never executes |
| GH-7-1 | After correlation | Queued | --correlation-id | Cancelled early |
| GH-7-2 | During execution | In progress | --run-id | Partial execution |
| GH-7-3 | Near completion | In progress | --run-id | Most jobs done |
| GH-6-2 | Force cancel | Any | --force | Bypasses always() |
| ERR-1 | Already completed | Completed | --run-id | HTTP 409 |
| ERR-2 | Invalid run ID | N/A | --run-id | HTTP 404 |
| INT-1 | Pipeline | Any | stdin | Composition works |
| INT-2 | Wait flag | Any | --wait | Polls to completion |
| INT-3 | Correlation | Any | --correlation-id | Metadata loads |

**Timing Measurements**:
- Cancellation request latency (expected: <1s)
- Cancellation completion time (expected: 5-30s depending on state)
- Status at cancellation time (queued/in_progress)
- Jobs completed before cancellation (0-N)

**Validation Steps**:
1. Static: `shellcheck scripts/cancel-run.sh`
2. Static: `actionlint` (verify no workflow changes)
3. Manual: Execute each test scenario
4. Manual: Document timing observations
5. Manual: Verify status transitions with `view-run-jobs.sh`

### Source Documents Referenced

**Requirements and Planning**:
- `BACKLOG.md` lines 58-67 (GH-6, GH-7 specifications)
- `PLAN.md` lines 109-117 (Sprint 11, Status: Planned)

**Process and Rules**:
- `rules/GENERAL_RULES_v3.md` (Sprint lifecycle, design approval)
- `rules/GitHub_DEV_RULES_v4.md` (GitHub implementation guidelines)
- `rules/PRODUCT_OWNER_GUIDE_v3.md` (Elaboration phase procedures)
- `rules/GIT_RULES_v1.md` (Semantic commit conventions)

**Technical References**:
- Sprint 1 design (correlation mechanism)
- Sprint 1 implementation (`trigger-and-track.sh`, metadata storage)
- Sprint 3 design (`lib/run-utils.sh` patterns)
- Sprint 5 design Objective 2 (GitHub CLI capabilities, `gh run cancel`)
- Sprint 5 design Objective 3 (REST API, cancellation endpoints)
- Sprint 8 design (script interface patterns, input resolution)
- Sprint 8 implementation (`view-run-jobs.sh` for verification)
- Sprint 9 design (curl-based implementation pattern)
- Sprint 9 implementation (`view-run-jobs-curl.sh` for reference)

**External Documentation**:
- GitHub REST API: https://docs.github.com/en/rest/actions/workflow-runs#cancel-a-workflow-run
- GitHub CLI Manual: https://cli.github.com/manual/gh_run_cancel

### Produced Documents

**Design Document**: `progress/sprint_11_design.md`
- **Size**: 798 lines
- **Status**: Complete, awaiting Product Owner approval
- **Sections**:
  1. Overview and feasibility analysis (confirms API support)
  2. Architecture diagram (ASCII diagram of cancellation flow)
  3. Script design with CLI interface
  4. Implementation details with function specifications
  5. Alternative curl implementation
  6. Error handling for all HTTP status codes
  7. Integration patterns (5 examples)
  8. Test strategy with 10-scenario matrix
  9. Timing observations framework
  10. Compatibility analysis with Sprints 1, 3, 8, 9
  11. Use cases (4 practical examples)
  12. Risks and mitigations (5 risks identified)
  13. Success criteria (10 items)
  14. Documentation specifications

**Elaboration Chat Document**: `progress/elaboration_sprint_11_chat_1.md` (this file)

### Expected Construction Phase Deliverables

**Scripts** (to be implemented):
- `scripts/cancel-run.sh` - Main implementation using gh CLI
- `scripts/cancel-run-curl.sh` - Alternative using REST API (optional)
- Test wrapper script for automated validation

**Documentation** (to be created):
- `progress/sprint_11_implementation.md` - Implementation notes
- Inline help in scripts (`--help` flag)
- Usage examples
- Troubleshooting guide
- Test execution results with timing data

**Test Results** (to be documented):
- Execution of 10 test scenarios
- Timing measurements for each scenario
- Status transition observations
- Edge case behavior documentation

### Success Criteria

Design phase successful when (all ✅):

1. ✅ Feasibility analysis confirms GitHub API supports cancellation
2. ✅ Script design covers both gh CLI and curl implementations
3. ✅ Input resolution follows established Sprint 8 patterns
4. ✅ Integration points with Sprints 1, 3, 8, 9 clearly documented
5. ✅ Test strategy covers GH-6 and GH-7 with 10 scenarios
6. ✅ Error handling addresses all HTTP status codes
7. ✅ Output formats (human, JSON) specified
8. ✅ Timing observations framework documented
9. ✅ Use cases demonstrate practical applications
10. ✅ Risks identified with mitigation strategies

### Questions and Clarifications

**None** - All design elements are clear and ready for implementation:

- ✅ Requirements unambiguous and testable
- ✅ API capabilities confirmed via Sprint 5 research
- ✅ Integration patterns proven in previous sprints
- ✅ Implementation functions fully specified
- ✅ Test strategy comprehensive and measurable
- ✅ Error handling complete
- ✅ Documentation structure defined

### Next Steps

**Awaiting Product Owner Approval**:
- Current design status: "Progress"
- Product Owner to review `progress/sprint_11_design.md`
- Product Owner to change status to "Accepted" in design document
- Product Owner to change Sprint 11 status in `PLAN.md` to "Designed"

**After Approval**:
- Proceed to Construction phase
- Implement `cancel-run.sh` following design specifications
- Execute test matrix
- Document results in `progress/sprint_11_implementation.md`
- Commit implementation with semantic commit messages

## Confirmation

✅ **Design Complete**: Comprehensive design document created (798 lines)

✅ **Requirements Covered**: GH-6 (immediate cancel) and GH-7 (running cancel)

✅ **Technical Feasibility**: Confirmed via Sprint 5 research, GitHub API documentation

✅ **Integration Validated**: Reuses Sprint 1 (correlation), Sprint 3 (utilities), Sprint 8/9 (patterns)

✅ **Test Strategy Defined**: 10 scenarios with timing measurements

✅ **Documentation Specified**: Implementation notes, inline help, usage examples

✅ **Ready for Product Owner Review**: Design awaiting approval before construction phase

