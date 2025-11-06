# Implementation Plan

The plan organizes execution of Backlog Items specified in `BACKLOG.md` document in a form of iterations - Sprints after Scrum method. This document is owned by the Product Owner. The Implementor NEVER changes this document. The Product Owner owns the `Status` line under each phase chapter, inserting the design state according to the implementation state machine defined in `rules/GitHub_DEV_RULES*`. Implementors NEVER touch the status, but their actions are driven by it.

## Sprint 0 - Prerequisites

Status: Done

Document perquisites. Prepare guided documentation with commands leading to prerequisite execution. Operator will copy/paste required command lines.

Backlog Items:

* GH-1. Prepare tools and techniques

## Sprint 1

Status: Done

Backlog Items:

* GH-2. Trigger GitHub workflow
* GH-3. Workflow correlation

## Sprint 2

Status: Failed

Backlog Items:

* GH-4. Workflow log access realtime access

## Sprint 3

Status: Done

Backlog Items:

* GH-5. Workflow log access after run access

## Sprint 4

Status: Done

Backlog Items:

* GH-3.1. Test timings of run_id retrieval
* GH-5.1. Test timings of execution logs retrieval

## Sprint 5

Status: Implemented

Perform project review looking into the market. Focus on:

1. Enumerate project achievements and failures.

2. Enumerate `gh` CLI capabilities listing what was used what is potentially available for next step verifications.

3. Enumerate GitHub API validating if we can achieve requirements.

4. Enumerate major GitHib libraries for Java, Go, Python to find out how these are addressing our issues.

## Sprint 6

Status: Failed

Reopen of Sprint 2 failure with hypothesis that GH-10 solves the requirement. This work is to validate usability or confirm lack of possibility to get live logs.

Backlog Items:

* GH-10. Use https://api.github.com/repos/owner/repo/actions/jobs/123456/logs API

## Sprint 7

Status: Failed

Backlog Items:

* GH-11. Workflow Webhook as a tool to get run_id

## Sprint 8

Status: Done

Backlog Items:

* GH-12. Use GitHub API to get workflow job phases with status.

## Sprint 9

Status: Done

Backlog Items:

* GH-12. Use GitHub API to get workflow job phases with status.

Implement GH-12 using API calls with curl. Use token file from ./secrets directory

## Sprint 10

Status: Failed

Backlog Items:

* GH-13. Caller gets data produced by a workflow

Caller uses GitHub REST API to gets data produced by a workflow. The workflow returns simple data structure derived from a parameters passed by a caller.

## Sprint 11

Status: Done

Backlog Items:

* GH-6. Cancel requested workflow
* GH-7. Cancel running workflow

## Sprint 12

Status: Failed

Backlog Items:

* GH-8. Schedule workflow
* GH-9. Cancel scheduled workflow

GitHub does not provide native scheduling for workflow_dispatch events. External schedulers are not an option in this project.

## Sprint 13

Status: Done

Backlog Items:

* GH-17. Create Pull Request
* GH-18. List Pull Requests
* GH-19. Update Pull Request

## Sprint 14

Status: Done

Backlog Items:

* GH-20. Merge Pull Request
* GH-22. Pull Request Comments

## Sprint 15

Status: Done

Backlog Items:

* GH-14. Trigger workflow with REST API
* GH-15. Workflow correlation with REST API
* GH-16. Fetch logs with REST API

Validate existing workflow features (GH-2, GH-3, GH-5) using pure REST API with curl instead of `gh` CLI. Follow the pattern established in Sprint 9, using token authentication from `./secrets` directory. All implementations should use curl for API calls and provide comprehensive error handling.

## Sprint 16

Status: Done

Backlog Items:

* GH-23. List workflow artifacts

Extend workflow management capabilities with artifact listing operations. Implement REST API-based artifact listing using curl, following the pattern established in Sprint 15. The implementation should use token authentication from `./secrets` directory, handle pagination, support filtering by artifact name, and provide comprehensive error handling. This sprint complements existing workflow log retrieval features by enabling discovery of artifacts produced by workflows.

## Sprint 17

Status: Proposed

Backlog Items:

* GH-24. Download workflow artifacts

Extend workflow management capabilities with artifact download operations. Implement REST API-based artifact download using curl, following the pattern established in Sprint 15. The implementation should use token authentication from `./secrets` directory, handle large file downloads with proper streaming, support downloading individual artifacts or all artifacts for a run, and provide comprehensive error handling for scenarios such as artifacts not yet available or expired artifacts.

## Sprint 18

Status: Proposed

Backlog Items:

* GH-25. Delete workflow artifacts

Extend workflow management capabilities with artifact deletion operations. Implement REST API-based artifact deletion using curl, following the pattern established in Sprint 15. The implementation should use token authentication from `./secrets` directory, support deleting individual artifacts or all artifacts for a run, validate deletion permissions, and provide comprehensive error handling for scenarios such as artifacts already deleted or insufficient permissions.
