# GitHub Workflow

version: 1
status: Progress

Experimenting with GitHub workflows to validate its behavior.

## Instructions for the Implementor

### Project overview

Project implements GitHub workflow. You are contracted to participate as an GitHub workflow Implementor within the Agentic Programming framework. Read this SRS.md and all referenced documents. Project scope is drafted in Backlog chapter. All other chapters and files are critical to understand the context.

Follow `rules/GitHub_DEV_RULES*` document for information about implementation process and the contract between the Product Owner and the Implementor. Especially notice chapter ownership rules and editing policies. You HAVE TO obey this document without exceptions.

### Tools and libraries

1. Use `podman` in case of required container

2. Use `https://webhook.site` as public webhook

### Implementor's generated content

The Implementor is responsible for design and implementation notes. Has right to propose changes, and asks for clarification. Details of this ownership is explained in file `rules/GENERAL_RULES*`.

## Backlog

Project aim to deliver all the features listed in a below Backlog. Backlog Items selected for implementation are added to iterations - Sprints listed in `Implementation Plan` chapter. Full list of Backlog Items presents general direction and aim for this project.

### GH-1. Prepare tools and techniques

Prepare toolset fot GitHub workflow interaction. GitHub CLI, GO, and Java libraries should be used. Propose proper libraries for Go and especially Java, which will be used for production coding. Before installing any tool - check if it does exist in the environment. Do not install if exists.

### GH-2. Trigger GitHub workflow

User triggers GitHub Workflow, that manifests it's progress by invoking webhooks. Webhooks are called with basic retry policy and guarantee that will never blocked by the end point. User provides webhook as a parameter. Workflow emits "Hello from <id>.<step>.

### GH-3. Workflow correlation

Triggering GitHub workflow returns "accepted" code without any information about job identifier that can be used for further API interaction. Goal is to apply the best practice to access `id` form GitHub for a triggered workflow. Any solution is ok: it may be injection of information to the request or async information from the running workflow.

### GH-3.1. Test timings of run_id retrieval

Execute series of tests of products "GH-3. Workflow correlation" to find out typical delay time to retrieve run_id. Execute 10-20 jobs measuring run_id retrieval time. Present each timing and compute mean value.

### GH-4. Workflow log access realtime access

Client running the workflow require to access workflow's log in the real time - during a run. Workflow should run longer time for this feature to be tested, during this longer run should emit log each few seconds. Operator used correlation_id or run_id if available in local repository. On this stage, the `repository` may be a file in a directory for easy parallel access.

### GH-5. Workflow log access after run access

Client running the workflow require to access workflow's log after the run. Operator used correlation_id or run_id if available in local repository. On this stage, the `repository` may be a file in a directory for easy parallel access.

### GH-5.1. Test timings of execution logs retrieval

Execute series of tests of products "GH-5. Workflow log access after run access" to find out typical delay time to retrieve logs after job execution. Execute 10-20 jobs measuring log retrieval time. Present each timing and compute mean value.

### GH-6. Cancel requested workflow

TODO

### GH-7. Cancel running workflow

TODO

### GH-8. Schedule workflow

TODO

### GH-9. Cancel scheduled workflow

TODO

### GH-10. Use https://api.github.com/repos/owner/repo/actions/jobs/123456/logs API

Use https://api.github.com/repos/owner/repo/actions/jobs/123456/logs API to validate if logs are supplied during run. Run long running workflow (the one from this project) and use above API to get log few times during a run. Having increasing logs is a proof that this API may be used for incremental log retrieval.

### GH-11. Workflow Webhook as a tool to get run_id

Validate working model of a webhook informing about run_id for a dispatched workflow. Webhook triggering systems must be the one provided by GitHub API, not the custom one. You can configure receiving endpoint by env's WEBHOOK_URL.

### GH-12. Use GitHub API to get workflow job phases with status.

Use GitHub API to get workflow job phases with status mimicking `gh run view <run_id>`. Use API or gh utility. Prefer browser based authentication for simplicity. 

TODO

### GH-999. Template

TODO

#### Testing

1. Correlation must be tested with parallel executions proving that parallel clients will always have access to workflows triggered by them.
2. Negative test may try to break the link between client call and the actual workflow run

More specific testing may be specified for each `Backlog Item` and `Sprint`.

## Implementation Plan

This chapter is owned by the Product Owner. The Implementor NEVER changes this chapter. Product owner owns `Status` line under phase chapter inserting here design state according to implementation's state machine defined in  `rules/GitHub_DEV_RULES*`. Implementor NEVER touches the status, but his actions are driven by the status.

### Sprint 0 - Prerequisites

Status: Done

Document perquisites. Prepare guided documentation with commands leading to prerequisite execution. Operator will copy/paste required command lines.

Backlog Items:

* GH-1. Prepare tools and techniques

### Sprint 1

Status: Done

Backlog Items:

* GH-2. Trigger GitHub workflow
* GH-3. Workflow correlation

### Sprint 2

Status: Failed

Backlog Items:

* GH-4. Workflow log access realtime access

### Sprint 3

Status: Done

Backlog Items:

* GH-5. Workflow log access after run access

### Sprint 4

Status: Done

Backlog Items:

* GH-3.1. Test timings of run_id retrieval
* GH-5.1. Test timings of execution logs retrieval

### Sprint 5

Status: Implemented

Perform project review looking into the market. Focus on:

1. Enumerate project achievements and failures.

2. Enumerate `gh` CLI capabilities listing what was used what is potentially available for next step verifications.

3. Enumerate GitHub API validating if we can achieve requirements.

4. Enumerate major GitHib libraries for Java, Go, Python to find out how these are addressing our issues.

### Sprint 6

Status: Failed

Reopen of Sprint 2 failure with hypothesis that GH-10 solves the requirement. This work is to validate usability or confirm lack of possibility to get live logs.

Backlog Items:

* GH-10. Use https://api.github.com/repos/owner/repo/actions/jobs/123456/logs API

### Sprint 7

Status: Failed

Backlog Items:

* GH-11. Workflow Webhook as a tool to get run_id

### Sprint 7

Status: Progress

Backlog Items:

* GH-12. Use GitHub API to get workflow job phases with status.
