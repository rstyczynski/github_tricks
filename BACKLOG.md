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

Project aim to deliver all the features listed in a below Backlog. Backlog Items selected for implementation are added to iterations detailed in `PLAN.md`. Full list of Backlog Items presents general direction and aim for this project.

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

Dispatch workflow and cancel it right after dispatching

### GH-7. Cancel running workflow

Dispatch workflow, wait for run_id discovery, and:

* cancel right after getting run_id. Check which status is the workflow in.
* cancel in running state

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

### GH-13. Caller gets data produced by a workflow

Caller expects to get data produced by a workflow. It's not about artifacts but simple data structures that may be passed by synchronous interfaces.

### GH-14. Trigger workflow with REST API

Validate GH-2 (Trigger GitHub workflow) using pure REST API with curl instead of `gh` CLI. Use GitHub's `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` endpoint. The implementation should handle authentication with token from `./secrets` directory, support workflow inputs, and provide proper error handling for common scenarios such as invalid workflow IDs or authentication failures.

### GH-15. Workflow correlation with REST API

Validate GH-3 (Workflow correlation) using pure REST API with curl. Use `GET /repos/{owner}/{repo}/actions/runs` with filtering to retrieve run_id after workflow dispatch. The implementation should support UUID-based correlation, handle pagination using Link headers, filter by workflow, branch, actor, and status, and provide proper error handling. Use token authentication from `./secrets` directory.

### GH-16. Fetch logs with REST API

Validate GH-5 (Workflow log access after run) using pure REST API endpoints. Use `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` to retrieve workflow execution logs. The implementation should handle log streaming and aggregation, support multiple jobs per workflow run, handle authentication with token from `./secrets` directory, and provide proper error handling for scenarios such as logs not yet available or invalid job IDs.

### GH-17. Create Pull Request

Create a pull request from a feature branch to main branch using REST API. This feature enables programmatic PR creation with full control over PR metadata including title, body, reviewers, labels, and issue linking. The implementation should handle authentication, validate branch existence, and provide proper error handling for common scenarios such as duplicate PRs or invalid branch references. API endpoint: `POST /repos/{owner}/{repo}/pulls`.

### GH-18. List Pull Requests

List pull requests with various filters including state, head branch, base branch, sort order, and direction. This feature supports querying PRs by their current state (open, closed, or all), filtering by source or target branches, and pagination for repositories with many pull requests. The implementation should handle pagination using Link headers and provide a clean interface for filtering and sorting results. API endpoint: `GET /repos/{owner}/{repo}/pulls`.

### GH-19. Update Pull Request

Update pull request properties including title, body, state, and base branch. This feature allows modifying PR metadata after creation, changing the target branch, and closing or reopening pull requests programmatically. The implementation should validate changes, handle merge conflicts when changing base branch, and provide clear error messages for invalid operations. API endpoint: `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`.

### GH-20. Merge Pull Request

Merge pull request with different merge strategies including merge commit, squash and merge, and rebase and merge. This feature requires checking the mergeable state before attempting merge and handling various merge scenarios such as conflicts, required status checks, and branch protection rules. The implementation should validate merge eligibility, support all three merge strategies, and provide detailed feedback about merge results or failures. API endpoint: `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge`.

### GH-22. Pull Request Comments

Add, update, and delete comments on pull requests including both general PR comments and inline code review comments. This feature enables programmatic code review workflows, allowing automated or scripted review processes to interact with PR discussions. The implementation should support adding comments at specific line positions for code reviews, updating existing comments, deleting comments, and reacting to comments with emojis. API endpoint: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`.

