# Inception Sprint 12 - Chat 1

**Date**: 2025-01-15
**Sprint**: 12
**Status**: Progress → Inception Phase
**Backlog Items**: GH-8, GH-9

## Sprint 12 Scope Understanding

### Backlog Items

**GH-8. Schedule workflow**
- **Requirement**: Schedule a workflow to run at a future time
- **Current State**: TODO in backlog (no detailed specification)
- **Goal**: Enable delayed execution of workflow_dispatch workflows
- **Context**: From Sprint 5 research, GitHub API does not provide cron-style scheduling for workflow_dispatch events

**GH-9. Cancel scheduled workflow**
- **Requirement**: Cancel a previously scheduled workflow
- **Current State**: TODO in backlog (no detailed specification)
- **Goal**: Provide ability to cancel scheduled workflows before they execute
- **Context**: Depends on GH-8 implementation approach

## Project History and Achievements

### Completed Sprints (Done Status)

**Sprint 0 - Prerequisites**:
- GH-1: Prepared tools and techniques (GitHub CLI, Go, Java libraries)
- Established development environment and tooling

**Sprint 1 - Workflow Triggering and Correlation**:
- GH-2: Implemented workflow dispatch with webhook notifications
- GH-3: Implemented correlation mechanism using UUID tokens
- **Key Deliverables**:
  - `.github/workflows/dispatch-webhook.yml` - Reusable workflow
  - `scripts/trigger-and-track.sh` - Dispatch and correlation script
  - `scripts/notify-webhook.sh` - Webhook notification script
  - `lib/run-utils.sh` - Shared utilities for run ID resolution
- **Pattern Established**: UUID-based correlation with metadata storage in `runs/<correlation_id>/metadata.json`

**Sprint 3 - Post-Run Log Access**:
- GH-5: Implemented workflow log retrieval after completion
- **Key Deliverables**:
  - `scripts/fetch-run-logs.sh` - Log retrieval script
- **Pattern Established**: Metadata-based run ID lookup, log archive download and extraction

**Sprint 4 - Timing Benchmarks**:
- GH-3.1: Test timings of run_id retrieval (10-20 jobs)
- GH-5.1: Test timings of execution logs retrieval (10-20 jobs)
- **Key Deliverables**:
  - Benchmark scripts and timing reports
  - Mean timing calculations documented

**Sprint 5 - Market Research**:
- Comprehensive review of project achievements and failures
- Enumerated `gh` CLI capabilities
- Enumerated GitHub API capabilities
- Enumerated major GitHub libraries (Java, Go, Python)
- **Key Finding for GH-8/GH-9**: GitHub API does not provide cron-style scheduling for workflow_dispatch. Scheduling dispatch events requires external scheduler (cron, systemd timers, cloud scheduler). Alternative: Use GitHub Actions scheduled workflows (`on: schedule: cron`) but that's static, not dispatch-based.

**Sprint 8 - Job Status Monitoring**:
- GH-12: Implemented workflow job phases and status retrieval
- **Key Deliverables**:
  - `scripts/view-run-jobs.sh` - GitHub CLI-based job viewer
  - `scripts/view-run-jobs-curl.sh` - curl-based alternative
- **Pattern Established**: Status monitoring with JSON output, multiple input methods (run_id, correlation_id)

**Sprint 9 - Job Status Monitoring (API Variant)**:
- GH-12: Implemented using curl and REST API calls
- Token file from `./secrets` directory
- **Pattern Established**: Alternative implementation using direct API calls

**Sprint 11 - Workflow Cancellation**:
- GH-6: Cancel requested workflow (immediately after dispatch)
- GH-7: Cancel running workflow (at different execution stages)
- **Key Deliverables**:
  - `scripts/cancel-run.sh` - Cancellation script with multiple input methods
  - `scripts/test-cancel-run.sh` - Comprehensive test suite
- **Pattern Established**: Integration with Sprint 1 correlation, status verification via Sprint 8/9 tools
- **Key Capabilities**: `gh run cancel <run_id>`, force-cancel endpoint, status polling

### Failed Sprints

**Sprint 2 - Real-time Log Access**:
- GH-4: Failed to implement real-time log access during workflow execution
- **Reason**: GitHub API limitations - logs not available incrementally during run

**Sprint 6 - Job Logs API Validation**:
- GH-10: Failed to validate incremental log retrieval via jobs API
- **Reason**: Reopening Sprint 2 failure, hypothesis that GH-10 solves requirement - validation failed

**Sprint 7 - Webhook-based Correlation**:
- GH-11: Failed to implement webhook as tool to get run_id
- **Reason**: GitHub webhook events require publicly accessible endpoint, complexity vs benefit trade-off

**Sprint 10 - Workflow Output Data**:
- GH-13: Failed to implement caller getting data produced by workflow
- **Reason**: GitHub REST API limitations - workflows cannot return synchronous data structures

## Technical Context and Patterns

### Established Patterns

**1. Correlation Mechanism (Sprint 1)**:
- UUID-based correlation tokens
- Metadata storage: `runs/<correlation_id>/metadata.json`
- Polling-based run_id resolution
- Integration via `lib/run-utils.sh` shared utilities

**2. Input Methods (Sprint 8, 11)**:
- Priority order: `--run-id` → `--correlation-id` → stdin JSON → interactive prompt
- Consistent CLI interface across scripts
- JSON output for automation (`--json` flag)

**3. Status Monitoring (Sprint 8/9)**:
- `scripts/view-run-jobs.sh` for status verification
- Status transitions: queued → in_progress → completed
- Conclusion tracking: success/failure/cancelled

**4. Cancellation (Sprint 11)**:
- `gh run cancel <run_id>` command
- Force-cancel endpoint for stuck workflows
- Asynchronous cancellation with polling option (`--wait`)

### Available Tools and Libraries

**GitHub CLI (`gh`)**:
- `gh workflow run` - Dispatch workflows
- `gh run cancel` - Cancel runs
- `gh run list` - List runs with filtering
- `gh run view` - View run details
- `gh api` - Direct API access

**GitHub REST API**:
- `POST /repos/:owner/:repo/actions/workflows/:workflow_id/dispatches` - Dispatch workflow
- `POST /repos/:owner/:repo/actions/runs/:run_id/cancel` - Cancel run
- `GET /repos/:owner/:repo/actions/runs` - List runs
- `GET /repos/:owner/:repo/actions/runs/:run_id` - Get run details

**Sprint 5 Research Findings**:
- No `gh workflow schedule` command exists
- No GitHub API endpoint for scheduling dispatch events
- External scheduler required: cron, systemd timers, cloud scheduler + `gh workflow run`
- Alternative: `on: schedule: cron:` in workflow definition (static, not dispatch-based)

## Understanding of GH-8 and GH-9 Requirements

### GH-8. Schedule workflow

**Current Understanding**:
- Requirement is minimal: "Schedule workflow" (TODO in backlog)
- Based on Sprint 5 research, GitHub does not provide native scheduling for workflow_dispatch
- **Possible Interpretations**:
  1. **External Scheduler Approach**: Create a script that schedules future `gh workflow run` invocations using system cron or similar
  2. **Workflow-based Scheduler**: Create a workflow that uses `on: schedule: cron:` to trigger other workflows
  3. **Delayed Dispatch**: Store scheduled dispatch requests and execute them at specified time

**Key Questions**:
- What scheduling mechanism should be used? (cron, systemd timer, in-memory scheduler)
- What format for schedule specification? (cron expression, ISO 8601 datetime, relative time)
- Where should schedule metadata be stored? (filesystem, database, workflow inputs)
- Should scheduled workflows be stored with correlation IDs for tracking?
- How to handle timezone considerations?

**Integration Points**:
- Reuse `scripts/trigger-and-track.sh` for actual dispatch
- Reuse correlation mechanism for tracking scheduled vs executed runs
- Reuse `runs/` directory structure for metadata storage
- Consider integration with `scripts/cancel-run.sh` for GH-9

### GH-9. Cancel scheduled workflow

**Current Understanding**:
- Requirement is minimal: "Cancel scheduled workflow" (TODO in backlog)
- Depends on GH-8 implementation approach
- **Possible Interpretations**:
  1. **Cancel Before Execution**: Remove scheduled entry before it triggers
  2. **Cancel After Dispatch**: If workflow already dispatched but not started, cancel it (overlaps with GH-6)
  3. **Cancel Running Scheduled Workflow**: If scheduled workflow is running, cancel it (overlaps with GH-7)

**Key Questions**:
- What identifies a "scheduled workflow"? (correlation_id, schedule_id, run_id after dispatch)
- Should cancellation prevent dispatch, or cancel after dispatch?
- How to track scheduled vs executed state?
- Integration with existing `scripts/cancel-run.sh`?

**Integration Points**:
- Reuse `scripts/cancel-run.sh` if cancellation happens after dispatch
- Reuse correlation mechanism for tracking
- Reuse metadata storage patterns

## Technical Approach Considerations

### Option 1: External Cron-based Scheduler

**Approach**:
- Script `scripts/schedule-workflow.sh` stores schedule metadata in `runs/scheduled/`
- System cron executes `scripts/execute-scheduled.sh` periodically
- `execute-scheduled.sh` checks scheduled entries and dispatches workflows
- `scripts/cancel-scheduled.sh` removes entries from scheduled queue

**Pros**:
- Simple implementation
- Reuses existing dispatch mechanism
- Clear separation of concerns

**Cons**:
- Requires system cron setup (not portable)
- No in-process scheduling
- Timezone handling complexity

### Option 2: Workflow-based Scheduler

**Approach**:
- Create `.github/workflows/scheduler.yml` with `on: schedule: cron:`
- Scheduler workflow reads schedule metadata and dispatches target workflows
- Schedule metadata stored in repository (file or workflow inputs)

**Pros**:
- No external dependencies
- Uses GitHub infrastructure
- Portable across environments

**Cons**:
- Limited to GitHub Actions cron syntax (5-minute minimum interval)
- Requires repository commits for schedule changes
- Less flexible than external scheduler

### Option 3: In-Memory Scheduler Script

**Approach**:
- Script `scripts/schedule-workflow.sh` accepts schedule and stores metadata
- Long-running daemon script `scripts/scheduler-daemon.sh` polls scheduled entries
- Executes dispatches at scheduled times

**Pros**:
- More flexible than cron
- Can run as background process
- Better control over execution

**Cons**:
- Requires long-running process
- More complex implementation
- Process management overhead

## Deliverables (Expected)

**Scripts**:
- `scripts/schedule-workflow.sh` - Schedule a workflow for future execution
- `scripts/cancel-scheduled.sh` - Cancel a scheduled workflow
- Optional: `scripts/execute-scheduled.sh` - Execute scheduled workflows (if cron-based)
- Optional: `scripts/scheduler-daemon.sh` - Daemon process (if in-memory approach)

**Documentation**:
- `progress/sprint_12_design.md` - Design with feasibility analysis
- `progress/sprint_12_implementation.md` - Implementation notes and test results
- Usage examples and integration patterns

**Test Results**:
- Schedule creation and storage verification
- Scheduled execution timing validation
- Cancellation before execution verification
- Integration with existing Sprint 1, 11 tools

## Source Documents Referenced

**Primary Requirements**:
- `BACKLOG.md` lines 69-75 - GH-8 and GH-9 specifications (minimal)
- `PLAN.md` lines 118-126 - Sprint 12 definition

**Process Rules**:
- `rules/generic/GENERAL_RULES.md` - Sprint lifecycle, ownership, feedback channels
- `rules/github_actions/GitHub_DEV_RULES.md` - GitHub-specific implementation guidelines
- `rules/generic/PRODUCT_OWNER_GUIDE.md` - Phase transitions and review procedures
- `rules/generic/GIT_RULES.md` - Semantic commit conventions

**Technical References**:
- Sprint 1 design/implementation - Correlation mechanism, dispatch patterns
- Sprint 5 design (Objective 2, 3) - GitHub CLI capabilities, API limitations for scheduling
- Sprint 11 design/implementation - Cancellation patterns, integration with correlation

## Questions and Clarifications Needed

**Critical Questions for GH-8**:

1. **Scheduling Mechanism**: What scheduling approach should be used?
   - External cron/systemd timer?
   - Workflow-based scheduler (`on: schedule: cron:`)?
   - In-memory daemon process?
   - Other approach?

2. **Schedule Format**: What format should be used for schedule specification?
   - Cron expression (e.g., `0 2 * * *`)?
   - ISO 8601 datetime (e.g., `2025-01-20T14:30:00Z`)?
   - Relative time (e.g., `+1h`, `+30m`)?
   - One-time vs recurring schedules?

3. **Storage Location**: Where should schedule metadata be stored?
   - Filesystem: `runs/scheduled/<schedule_id>/metadata.json`?
   - Repository file (for workflow-based approach)?
   - Other location?

4. **Scope**: Should scheduling support:
   - One-time scheduled dispatch?
   - Recurring schedules (cron-like)?
   - Both?

5. **Integration**: Should scheduled workflows:
   - Use correlation IDs for tracking (like Sprint 1)?
   - Support webhook URLs (like Sprint 1)?
   - Support all workflow inputs?

**Critical Questions for GH-9**:

1. **Cancellation Scope**: What does "cancel scheduled workflow" mean?
   - Remove from schedule before dispatch?
   - Cancel after dispatch but before execution (overlaps GH-6)?
   - Cancel during execution (overlaps GH-7)?
   - All of the above?

2. **Identification**: How should scheduled workflows be identified?
   - Schedule ID (UUID)?
   - Correlation ID (if scheduled workflow uses correlation)?
   - Run ID (after dispatch)?

3. **Integration**: Should `scripts/cancel-scheduled.sh`:
   - Integrate with `scripts/cancel-run.sh` (Sprint 11)?
   - Be a separate script?
   - Support both scheduled cancellation and run cancellation?

## Confirmation

✅ Sprint 12 scope understood: GH-8 (Schedule workflow) and GH-9 (Cancel scheduled workflow)

✅ Project history reviewed:
- Completed Sprints: 0, 1, 3, 4, 5, 8, 9, 11
- Failed Sprints: 2, 6, 7, 10
- Established patterns: Correlation, status monitoring, cancellation

✅ Technical context understood:
- GitHub API limitations for scheduling (Sprint 5 research)
- Established patterns from previous sprints
- Integration points identified

⚠️ **Clarifications Needed**:
- Scheduling mechanism and format (GH-8)
- Cancellation scope and identification (GH-9)
- Storage and integration approach

✅ Ready to proceed to Elaboration phase after clarifications received.

## Sprint Failure Decision

**Date**: 2025-01-15

**Decision**: Sprint 12 marked as **Failed**

**Reason**: 
- GitHub does not provide native scheduling for workflow_dispatch events
- External schedulers (cron, systemd timers, cloud schedulers) are not an option in this project
- Alternative approach (`on: schedule: cron:` in workflow definition) is static and not dispatch-based, which does not meet the requirement

**Impact**:
- GH-8 (Schedule workflow): Cannot be implemented - GitHub API limitation
- GH-9 (Cancel scheduled workflow): Cannot be implemented - Depends on GH-8

**Documentation Updated**:
- `PLAN.md`: Sprint 12 status changed from "Progress" to "Failed"
- `PROGRESS_BOARD.md`: Sprint 12 and backlog items marked as "failed" with reason documented

