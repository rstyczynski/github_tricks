# GitHub Workflow

version: 1
status: Progress

Experimenting with GitHub workflows to validate its behavior.

## Instructions for the Implementor

### Project overview

Project implements GitHub workflow. You are contracted to participate as an GitHub workflow Implementor within the Agentic Programming framework. Read this SRS.md and all referenced documents. Project scope is drafted in Backlog chapter. All other chapters and files are critical to understand the context.

Follow `rules/github_actions/GitHub_DEV_RULES*` document for information about implementation process and the contract between the Product Owner and the Implementor. Especially notice chapter ownership rules and editing policies. You HAVE TO obey this document without exceptions.

### Tools and libraries

1. Use `podman` in case of required container

2. Use `https://webhook.site` as public webhook

### Implementor's generated content

The Implementor is responsible for design and implementation notes. Has right to propose changes, and asks for clarification. Details of this ownership is explained in file `rules/generic/GENERAL_RULES*`.

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

### GH-23. List workflow artifacts

List artifacts produced by a workflow run using REST API. This feature enables querying artifacts associated with a specific workflow run, filtering by artifact name, and retrieving artifact metadata including size, creation date, and expiration date. The implementation should handle authentication with token from `./secrets` directory, support pagination for runs with many artifacts, and provide proper error handling for scenarios such as invalid run IDs or expired artifacts. API endpoint: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`.

### GH-24. Download workflow artifacts

Download artifacts produced by a workflow run using REST API. This feature enables programmatic retrieval of workflow artifacts for further processing, analysis, or distribution. The implementation should handle authentication with token from `./secrets` directory, support downloading individual artifacts or all artifacts for a run, handle large file downloads with proper streaming, and provide proper error handling for scenarios such as artifacts not yet available, expired artifacts, or download failures. API endpoint: `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip`.

### GH-25. Delete workflow artifacts

Delete artifacts from a workflow run using REST API. This feature enables cleanup of artifacts to manage repository storage and comply with retention policies. The implementation should handle authentication with token from `./secrets` directory, support deleting individual artifacts or all artifacts for a run, validate deletion permissions, and provide proper error handling for scenarios such as artifacts already deleted or insufficient permissions. API endpoint: `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`.

### GH-26.1. Summarize: Trigger workflow via REST API

Provide a concise summary and guide for triggering GitHub workflows using the REST API (POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches). Include usage purpose, supported parameters (workflow_id, inputs), required authentication, and invocation examples. This summary should be easy to update as trigger mechanisms evolve and serve as a quick reference for users and maintainers. Build new workflow for this task. Do not use existing one with custom WEBHOOK.

### GH-26.2. Summarize: Correlate workflow runs via REST API

Summarize how to correlate workflow runs using the REST API (GET /repos/{owner}/{repo}/actions/runs), describing how to identify runs by UUID, filter by workflow, branch, actor, and status, and handle pagination. Include invocation patterns, parameter options, and best practices for reliable correlations.

### GH-26.3. Summarize: Retrieve workflow logs via REST API

Document the process for retrieving workflow job logs via the REST API (GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs), with a summary of required authentication, log streaming, aggregation for multiple jobs, and error scenarios (logs not available, invalid job_id). Include usage examples and highlight best practices.

### GH-26.4. Summarize: Manage workflow artifacts via REST API

Provide a comprehensive guide summarizing all artifact management operations available via REST API, including listing artifacts (GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts), downloading artifacts (GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip), and deleting artifacts (DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}). For each, detail purpose, options, error handling, and best practices.

### GH-26.5. Summarize: Manage pull requests via REST API

Summarize all programmatic pull request operations provided via REST API, including creating pull requests (POST /repos/{owner}/{repo}/pulls), listing pull requests (GET /repos/{owner}/{repo}/pulls), updating pull requests (PATCH /repos/{owner}/{repo}/pulls/{pull_number}), merging pull requests (PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge), and handling PR comments (POST /repos/{owner}/{repo}/pulls/{pull_number}/comments). Each summary should cover usage scenario, primary parameters, invocation templates, and error cases.

### GH-26.6. Auto-generate API operations summary

Design and implement automation to generate or template the overall API operations summary based on the latest set of implemented Backlog Items. This ensures the API summary remains current with ongoing feature additions or changes, reducing manual maintenance and serving as an authoritative reference checklist. Build new workflows for summary generation; do not use any existing workflow with custom WEBHOOK triggers.

### GH-27. Trigger long running workflow via REST API to download logs, and artifacts after completion

Use already existing scripts to establish a sequence of script invocations.

### GH-28. Ansible role to handle GitHub workflow

1. Ansible Role wrapper for:
    * triggers workflow
    * gets run_id using correlaiton_id added to the workflow name

### GH-29. Design Ansible Collection to handle GitHub API

**Note:** Analysis and design completed in Sprint 21. See `progress/sprint_21/sprint_21_analysis.md`, `progress/sprint_21/sprint_21_design.md` (v1 - Python approach), and `progress/sprint_21/sprint_21_design_v2.md` (v2 - gh CLI approach).

**Market Analysis Finding:** No comprehensive GitHub API Ansible collection exists. community.general has only 5 basic modules (repo, webhook, issue, release) - ZERO modules for workflows, PRs, or artifacts.

**Design Evolution:**
- **v1 (rejected)**: Pure Python modules - deemed too complex for current phase
- **v2 (approved)**: Ansible roles using `gh` CLI - simpler, leverages existing project tooling

Ansible Collection design completed using gh CLI approach: 12 roles for workflows, PRs, and artifacts. Uses `gh` CLI utility instead of Python, significantly simpler implementation.

Implementation items created: GH-29.1 through GH-29.4 (hierarchical family numbering).


### GH-29.1. Ansible Collection - Infrastructure and Workflow Roles

**Prerequisites:** GH-29 design v2 complete
**Family:** Workflow operations

Create Ansible Collection infrastructure using gh CLI approach and implement core roles:

1. **Collection Skeleton**
   - Use `ansible-galaxy collection init rstyczynski.github_api`
   - Set up directory structure for roles
   - Create galaxy.yml (namespace: rstyczynski, name: github_api)
   - Create collection README.md
   - Set up .gitignore

2. **Prerequisites and Setup**
   - Document gh CLI installation (>= 2.0.0)
   - Document authentication (GH_TOKEN or gh auth login)
   - Create test repository setup guide
   - Document Ansible requirements (>= 2.12)

3. **Core Workflow Roles (4 roles)**
   - `workflow_trigger`: Trigger workflow using `gh workflow run`
   - `workflow_status`: Get status using `gh run view` with correlation
   - `workflow_cancel`: Cancel using `gh run cancel`
   - `workflow_logs`: Download logs using `gh run view --log`

4. **Role Standards**
   - Each role has tasks/main.yml, defaults/main.yml, README.md
   - Consistent parameter naming (prefixed with role name)
   - Standard error handling pattern for gh CLI calls
   - Authentication via GH_TOKEN or ./secrets/github_token
   - JSON output parsing using from_json filter

5. **Testing Infrastructure**
   - Create tests/integration/ structure
   - Create test playbooks for workflow roles
   - Test against real GitHub test repository

**Deliverables:**
- Working collection with 4 workflow roles
- Each role tested and documented
- Collection README with examples
- Installation and setup guide

**Testing:**
- Each role passes idempotency test
- Integration tests against GitHub test repository
- Example playbooks execute successfully

### GH-29.2. Ansible Collection - Pull Request Roles

**Prerequisites:** GH-29.1 complete
**Family:** Pull request operations

Implement GitHub Pull Request management roles using gh CLI:

1. **PR Management Roles (5 roles)**
   - `pr_create`: Create PR using `gh pr create` with duplicate checking
   - `pr_update`: Update PR using `gh pr edit`
   - `pr_merge`: Merge PR using `gh pr merge` with idempotency check
   - `pr_comment`: Add comments using `gh pr comment`
   - `pr_review`: Submit reviews using `gh pr review`

2. **Idempotency Patterns**
   - pr_create: Check existing with `gh pr list --head --base`
   - pr_update: Query current state with `gh pr view`, compare, update if different
   - pr_merge: Check if merged with `gh pr view --json state,merged`
   - pr_comment: Configurable with force parameter
   - pr_review: Not idempotent, requires explicit force

3. **JSON Parsing**
   - Use `gh pr list --json` for queries
   - Use `gh pr view --json` for state checking
   - Parse with Ansible from_json filter
   - Set facts for downstream use

**Deliverables:**
- 5 PR management roles implemented
- Each role with idempotency handling
- Each role documented with examples
- Integration tests for PR lifecycle

**Testing:**
- Create → update → merge workflow test
- Idempotency validation (run twice, verify changed status)
- Comment and review functionality tests

### GH-29.3. Ansible Collection - Artifact Roles and Documentation

**Prerequisites:** GH-29.2 complete
**Family:** Artifact operations

Implement artifact management roles and complete collection documentation:

1. **Artifact Management Roles (3 roles)**
   - `artifact_list`: List using `gh api /repos/.../artifacts`
   - `artifact_download`: Download using `gh api ... > file` with checksum validation
   - `artifact_delete`: Delete using `gh api -X DELETE`

2. **Complete Integration Tests**
   - End-to-end workflow: trigger → status → logs → artifacts
   - End-to-end PR: create → comment → review → merge
   - Idempotency tests for all 12 roles
   - Error handling tests (auth, not found, rate limit)

3. **Documentation**
   - Collection README with getting started
   - Individual role READMEs with examples
   - Category guides (workflows, PRs, artifacts)
   - Example playbooks (tested and copy-paste-able):
     - trigger_workflow.yml
     - create_pr.yml
     - download_artifacts.yml
     - pr_lifecycle.yml
     - workflow_orchestration.yml

4. **Publication Preparation**
   - CHANGELOG.md
   - LICENSE (MIT)
   - Version tagging (0.1.0)
   - ansible-galaxy collection build

**Deliverables:**
- 3 artifact roles implemented
- Complete test suite passing
- Complete documentation
- Collection ready for publication to Ansible Galaxy

**Testing:**
- All 12 roles pass integration tests
- All example playbooks execute successfully
- ansible-galaxy collection build succeeds
- Collection installable and usable

### GH-29.4. Ansible Collection - Advanced Roles (Optional Future)

**Prerequisites:** GH-29.3 complete
**Family:** Advanced orchestration (optional)

Optional advanced orchestration roles (future enhancement):

1. **High-Level Orchestration Roles**
   - `workflow_orchestrator`: Complete workflow lifecycle (trigger → monitor → logs → artifacts)
   - `pr_lifecycle`: Complete PR workflow (create → review → merge with checks)
   - `release_manager`: Tag → build → test → release workflow

2. **Utility Roles**
   - `github_auth_check`: Verify gh CLI authentication and permissions
   - `github_repository_info`: Query repository details
   - `github_rate_limit_check`: Check API rate limit status

**Note:** This is optional/future work. GH-30 through GH-32 deliver complete functional collection.
