# Implementation Plan

The plan organizes execution of Backlog Items specified in `SRS.md` document in a form of iterations - Sprints after Scrum method. This document is owned by the Product Owner. The Implementor NEVER changes this document. The Product Owner owns the `Status` line under each phase chapter, inserting the design state according to the implementation state machine defined in `rules/GitHub_DEV_RULES*`. Implementors NEVER touch the status, but their actions are driven by it.

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
