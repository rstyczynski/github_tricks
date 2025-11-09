# Inception Sprint 13 - Chat 1

**Date**: 2025-01-15
**Sprint**: 13
**Status**: Progress → Inception Phase
**Backlog Items**: GH-17, GH-18, GH-19

## Sprint 13 Scope Understanding

### Backlog Items

**GH-17. Create Pull Request**
- **Requirement**: Create a pull request from a feature branch to main branch using REST API
- **Goal**: Enable programmatic PR creation with full control over PR metadata including title, body, reviewers, labels, and issue linking
- **API Endpoint**: `POST /repos/{owner}/{repo}/pulls`
- **Key Features**:
  - Handle authentication
  - Validate branch existence
  - Proper error handling for common scenarios (duplicate PRs, invalid branch references)
  - Support for title, body, reviewers, labels, issue linking

**GH-18. List Pull Requests**
- **Requirement**: List pull requests with various filters including state, head branch, base branch, sort order, and direction
- **Goal**: Support querying PRs by their current state (open, closed, or all), filtering by source or target branches, and pagination for repositories with many pull requests
- **API Endpoint**: `GET /repos/{owner}/{repo}/pulls`
- **Key Features**:
  - Filter by state (open, closed, all)
  - Filter by head branch (source branch)
  - Filter by base branch (target branch)
  - Sort order and direction
  - Pagination handling using Link headers
  - Clean interface for filtering and sorting results

**GH-19. Update Pull Request**
- **Requirement**: Update pull request properties including title, body, state, and base branch
- **Goal**: Allow modifying PR metadata after creation, changing the target branch, and closing or reopening pull requests programmatically
- **API Endpoint**: `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`
- **Key Features**:
  - Update title and body
  - Change base branch
  - Close/reopen PRs
  - Validate changes
  - Handle merge conflicts when changing base branch
  - Clear error messages for invalid operations

## Project History and Achievements

### Completed Sprints (Done Status)

**Sprint 0 - Prerequisites**:
- GH-1: Prepared tools and techniques (GitHub CLI, Go, Java libraries)
- Established development environment and tooling
- GitHub CLI authenticated with browser-based auth

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
- **Key Finding**: Documented available GitHub API endpoints and CLI commands

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

**Sprint 12 - Workflow Scheduling**:
- GH-8: Failed to implement workflow scheduling
- GH-9: Failed to implement cancel scheduled workflow
- **Reason**: GitHub does not provide native scheduling for workflow_dispatch events. External schedulers are not an option in this project.

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

**4. API Access Patterns (Sprint 9)**:
- Token file from `./secrets` directory
- curl-based REST API calls
- GitHub CLI (`gh`) as alternative
- Consistent error handling and JSON parsing

**5. Script Structure Patterns**:
- Shell scripts with `set -euo pipefail`
- Source shared utilities from `lib/run-utils.sh`
- Comprehensive error handling
- Human-readable and JSON output formats
- Help documentation with examples

### Available Tools and Libraries

**GitHub CLI (`gh`)**:
- `gh workflow run` - Dispatch workflows
- `gh run cancel` - Cancel runs
- `gh run list` - List runs with filtering
- `gh run view` - View run details
- `gh api` - Direct API access
- `gh pr create` - Create pull requests (may be relevant)
- `gh pr list` - List pull requests (may be relevant)
- `gh pr view` - View pull request details (may be relevant)

**GitHub REST API**:
- `POST /repos/:owner/:repo/actions/workflows/:workflow_id/dispatches` - Dispatch workflow
- `POST /repos/:owner/:repo/actions/runs/:run_id/cancel` - Cancel run
- `GET /repos/:owner/:repo/actions/runs` - List runs
- `GET /repos/:owner/:repo/actions/runs/:run_id` - Get run details
- `POST /repos/:owner/:repo/pulls` - Create pull request (GH-17)
- `GET /repos/:owner/:repo/pulls` - List pull requests (GH-18)
- `PATCH /repos/:owner/:repo/pulls/:pull_number` - Update pull request (GH-19)

**Sprint 5 Research Findings**:
- GitHub API provides comprehensive Pull Request endpoints
- Pull Request operations are well-documented and stable
- Authentication via token (from `./secrets` directory) or GitHub CLI

## Understanding of GH-17, GH-18, and GH-19 Requirements

### GH-17. Create Pull Request

**Current Understanding**:
- Create PR programmatically using REST API
- Support full PR metadata: title, body, reviewers, labels, issue linking
- Validate branch existence before creation
- Handle error cases: duplicate PRs, invalid branches, authentication failures
- **Integration Points**:
  - May need to create feature branches first (git operations)
  - Reuse authentication patterns from Sprint 9 (token from `./secrets`)
  - Follow established script patterns (input methods, JSON output)

**Key Questions**:
- Should script create feature branch if it doesn't exist, or assume it exists?
- What format for reviewers? (usernames, team names, both?)
- How to handle labels? (create if missing, or only use existing?)
- Should script support draft PRs?
- Integration with existing git repository state?

**Technical Approach Considerations**:
- Use `POST /repos/:owner/:repo/pulls` endpoint
- Authentication via token file (Sprint 9 pattern) or `gh api`
- Validate branches exist before PR creation
- Handle HTTP 422 (validation errors) and HTTP 409 (duplicate PR)

### GH-18. List Pull Requests

**Current Understanding**:
- Query PRs with various filters (state, head, base, sort, direction)
- Handle pagination using Link headers
- Provide clean filtering interface
- **Integration Points**:
  - Follow Sprint 8/9 patterns for API calls
  - JSON output for automation
  - Human-readable table output (default)
  - Reuse authentication patterns

**Key Questions**:
- What default filters should be applied? (open PRs only, or all?)
- How to handle pagination? (auto-fetch all pages, or single page with next link?)
- What sort order by default? (created, updated, popularity?)
- Should script support filtering by author, assignee, labels?
- Integration with correlation mechanism? (probably not needed for PRs)

**Technical Approach Considerations**:
- Use `GET /repos/:owner/:repo/pulls` endpoint with query parameters
- Handle pagination: follow Link headers or provide pagination controls
- Support all filter parameters: state, head, base, sort, direction
- Output formats: human-readable table (default) and JSON (`--json`)

### GH-19. Update Pull Request

**Current Understanding**:
- Modify PR properties after creation: title, body, state, base branch
- Handle merge conflicts when changing base branch
- Validate changes before applying
- **Integration Points**:
  - Reuse authentication patterns
  - May need to check mergeable state before base branch changes
  - Follow established error handling patterns

**Key Questions**:
- Should script check mergeable state before base branch change?
- How to handle merge conflicts? (error message, or attempt merge?)
- What happens to status checks when base branch changes?
- Should script support updating reviewers and labels? (different endpoint)
- Integration with GH-17? (update PR created by GH-17 script)

**Technical Approach Considerations**:
- Use `PATCH /repos/:owner/:repo/pulls/:pull_number` endpoint
- Validate PR exists before update
- Check mergeable state for base branch changes
- Handle HTTP 422 (validation errors) and HTTP 409 (merge conflicts)

## Technical Approach Considerations

### Option 1: GitHub CLI-based Implementation

**Approach**:
- Use `gh pr create`, `gh pr list`, `gh pr edit` commands
- Leverage existing GitHub CLI authentication
- Simpler implementation, less error handling needed

**Pros**:
- Simpler implementation
- Reuses existing authentication
- Less API-specific error handling

**Cons**:
- Less control over API parameters
- May not support all features (reviewers, labels in single command)
- Less flexibility for automation

### Option 2: REST API with curl (Sprint 9 Pattern)

**Approach**:
- Use curl with token from `./secrets` directory
- Direct API calls with full control
- Follow Sprint 9 patterns for authentication and error handling

**Pros**:
- Full control over API parameters
- Consistent with Sprint 9 approach
- More flexible for automation
- Better error handling and validation

**Cons**:
- More complex implementation
- Need to handle pagination manually
- More API-specific error codes to handle

### Option 3: Hybrid Approach

**Approach**:
- Use `gh api` command for REST API access
- Combines CLI convenience with API flexibility
- Token-based authentication via GitHub CLI

**Pros**:
- Best of both worlds: CLI convenience + API flexibility
- Consistent authentication (GitHub CLI)
- Easier JSON parsing (gh handles it)

**Cons**:
- Still requires understanding API endpoints
- May need curl fallback for advanced features

## Deliverables (Expected)

**Scripts**:
- `scripts/create-pr.sh` - Create pull request (GH-17)
- `scripts/list-prs.sh` - List pull requests with filters (GH-18)
- `scripts/update-pr.sh` - Update pull request properties (GH-19)
- Optional: Test scripts for each feature

**Documentation**:
- `progress/sprint_13_design.md` - Design with feasibility analysis
- `progress/sprint_13_implementation.md` - Implementation notes and test results
- Usage examples and integration patterns

**Test Results**:
- PR creation with various metadata combinations
- PR listing with different filters
- PR updates (title, body, state, base branch)
- Error handling validation (duplicate PRs, invalid branches, merge conflicts)

## Source Documents Referenced

**Primary Requirements**:
- `BACKLOG.md` lines 93-103 - GH-17, GH-18, GH-19 specifications
- `PLAN.md` lines 129-137 - Sprint 13 definition

**Process Rules**:
- `rules/generic/GENERAL_RULES.md` - Sprint lifecycle, ownership, feedback channels
- `rules/github_actions/GitHub_DEV_RULES.md` - GitHub-specific implementation guidelines
- `rules/generic/PRODUCT_OWNER_GUIDE.md` - Phase transitions and review procedures
- `rules/generic/GIT_RULES.md` - Semantic commit conventions

**Technical References**:
- Sprint 1 design/implementation - Correlation mechanism, dispatch patterns
- Sprint 8/9 design/implementation - API access patterns, authentication, JSON output
- Sprint 11 design/implementation - Script structure patterns, error handling
- Sprint 5 design - GitHub API capabilities research

## Questions and Clarifications Needed

**Critical Questions for GH-17 (Create Pull Request)**:

1. **Branch Management**: Should `create-pr.sh` create the feature branch if it doesn't exist, or assume it exists?
   - Option A: Assume branch exists (simpler, follows Unix philosophy)
   - Option B: Create branch if missing (more convenient, but requires git operations)

2. **Reviewers Format**: What format should reviewers be specified in?
   - Usernames only? (`--reviewers user1,user2`)
   - Team names? (`--reviewers team:backend`)
   - Both supported?

3. **Labels**: Should script create labels if they don't exist, or only use existing labels?
   - Option A: Only use existing labels (fail if label missing)
   - Option B: Create labels if missing (more convenient, but requires additional API call)

4. **Draft PRs**: Should script support creating draft PRs?
   - `--draft` flag?

5. **Integration**: Should script integrate with git repository state?
   - Auto-detect current branch as head?
   - Auto-detect default branch as base?

**Critical Questions for GH-18 (List Pull Requests)**:

1. **Default Filters**: What should be the default behavior?
   - List all PRs (open, closed, merged)?
   - List only open PRs (most common use case)?
   - Configurable default?

2. **Pagination**: How should pagination be handled?
   - Auto-fetch all pages (may be slow for many PRs)?
   - Single page with `--page` parameter?
   - Follow Link headers automatically?

3. **Sort Order**: What should be the default sort order?
   - Created date (newest first)?
   - Updated date (recently updated first)?
   - Configurable?

4. **Additional Filters**: Should script support filtering by:
   - Author (`--author username`)?
   - Assignee (`--assignee username`)?
   - Labels (`--labels label1,label2`)?
   - These are not in the requirement, but may be useful

**Critical Questions for GH-19 (Update Pull Request)**:

1. **Mergeable State**: Should script check mergeable state before changing base branch?
   - Option A: Check and warn if not mergeable
   - Option B: Attempt change and let API return error

2. **Merge Conflicts**: How should merge conflicts be handled when changing base branch?
   - Error message only?
   - Attempt to provide conflict details?

3. **Status Checks**: What happens to status checks when base branch changes?
   - Document behavior?
   - Re-trigger checks?

4. **Reviewers and Labels**: Should script support updating reviewers and labels?
   - These use different endpoints (`POST /repos/:owner/:repo/pulls/:pull_number/requested_reviewers`)
   - Include in GH-19 or separate backlog items?

5. **Integration**: Should script integrate with GH-17?
   - Accept PR number from `create-pr.sh` output?
   - Support correlation mechanism? (probably not needed)

## Confirmation

✅ Sprint 13 scope understood: GH-17 (Create Pull Request), GH-18 (List Pull Requests), GH-19 (Update Pull Request)

✅ Project history reviewed:
- Completed Sprints: 0, 1, 3, 4, 5, 8, 9, 11
- Failed Sprints: 2, 6, 7, 10, 12
- Established patterns: Correlation, status monitoring, cancellation, API access

✅ Technical context understood:
- GitHub API Pull Request endpoints documented
- Established patterns from previous sprints (Sprint 8/9 API access, Sprint 11 script structure)
- Integration points identified

⚠️ **Clarifications Needed**:
- Branch management approach (GH-17)
- Reviewers and labels handling (GH-17)
- Default filters and pagination (GH-18)
- Mergeable state checking (GH-19)
- Integration between scripts

✅ Ready to proceed to Elaboration phase after clarifications received.

