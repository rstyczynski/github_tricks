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

**Note:** Analysis and design completed in Sprint 21. See `progress/sprint_21/sprint_21_analysis.md` and `progress/sprint_21/sprint_21_design.md`.

**Market Analysis Finding:** No comprehensive GitHub API Ansible collection exists. community.general has only 5 basic modules (repo, webhook, issue, release) - ZERO modules for workflows, PRs, or artifacts.

Ansible Collection design completed for: pull requests, comments, approvals, reviews, workflows, artifacts, logs. Design includes 12 modules, testing strategy (ansible-test), error handling framework, and authentication design.

Implementation items created: GH-30 through GH-35.

### GH-30. Ansible Collection - Infrastructure Setup

**Prerequisites:** GH-29 design complete

Create Ansible Collection infrastructure and bootstrap:

1. **Collection Skeleton**
   - Use `ansible-galaxy collection init rstyczynski.github_api`
   - Set up directory structure per design
   - Create galaxy.yml with metadata (namespace, version, dependencies)
   - Create requirements.txt with Python dependencies (requests>=2.28.0, python-dateutil>=2.8.0, urllib3>=1.26.0)
   - Set up .gitignore (.venv, *.pyc, __pycache__, etc.)

2. **Development Environment**
   - Create Python virtual environment (.venv in project directory per Ansible BP)
   - Install Ansible Core >= 2.12.0
   - Install ansible-test
   - Install Python dependencies from requirements.txt

3. **Testing Infrastructure**
   - Create tests/sanity/ directory structure
   - Create tests/unit/plugins/modules/ structure
   - Create tests/integration/targets/ structure
   - Configure ansible-test settings
   - Create test fixtures and mocks

4. **Shared Components**
   - Implement `get_github_token()` helper (param > env > file precedence)
   - Implement `github_api_call()` wrapper with comprehensive error handling
   - Create error handling patterns (401/403/404/422/rate limit)
   - Create module template for consistent structure

5. **Documentation Framework**
   - Create docs/ directory structure
   - Create README.md template
   - Set up module documentation pattern (DOCUMENTATION/EXAMPLES/RETURN)

**Deliverables:**
- Working collection skeleton
- Shared helper functions tested
- ansible-test sanity passes on skeleton
- Development environment documented

**Testing:**
- Run `ansible-test sanity --docker default -v` - must pass
- Verify virtual environment setup
- Verify shared components unit tests pass

### GH-31. Ansible Collection - Workflow Modules

**Prerequisites:** GH-30 complete

Implement GitHub Actions workflow management modules:

1. **workflow_trigger.py**
   - Trigger workflow_dispatch events
   - Parameters: workflow (file), ref (branch), inputs (dict), correlation_id (optional UUID)
   - API: POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches
   - Idempotent: NO (document clearly, creates new run each time)
   - Returns: correlation_id, changed=true
   - Full DOCUMENTATION/EXAMPLES/RETURN docstrings

2. **workflow_status.py**
   - Get workflow run status by correlation_id or run_id
   - Parameters: correlation_id OR run_id, repository
   - API: GET /repos/{owner}/{repo}/actions/runs (with filter)
   - Idempotent: YES (read-only)
   - Returns: run_id, status, conclusion, created_at, updated_at, html_url
   - Support polling pattern with retries

3. **workflow_cancel.py**
   - Cancel workflow run
   - Parameters: run_id, repository
   - API: POST /repos/{owner}/{repo}/actions/runs/{run_id}/cancel
   - Idempotent: YES (canceling already-canceled is no-op)
   - Returns: changed (true if was running, false if already canceled/completed)

4. **workflow_logs.py**
   - Retrieve workflow execution logs
   - Parameters: run_id, repository, dest (local path)
   - API: GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs, GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs
   - Idempotent: YES (read-only)
   - Returns: logs_path, job_count

**Deliverables:**
- 4 workflow modules implemented
- Each module with unit tests (mocked GitHub API)
- Each module with integration tests
- Each module passes ansible-test sanity/units
- Documentation for all modules

**Testing:**
- Unit tests with mocked API responses
- Integration tests against real GitHub API or VCR recordings
- Idempotency tests (run twice, verify changed status)
- Error scenario tests (auth failures, rate limits, not found)

### GH-32. Ansible Collection - Pull Request Modules

**Prerequisites:** GH-30 complete

Implement GitHub Pull Request management modules:

1. **pr_create.py**
   - Create pull request with duplicate checking for idempotency
   - Parameters: head (source branch), base (target branch), title, body, draft (optional)
   - API: GET /repos/{owner}/{repo}/pulls (check existing), POST /repos/{owner}/{repo}/pulls
   - Idempotent: YES (checks if PR with same head/base exists)
   - Returns: changed, pr_number, pr_url, pr_state

2. **pr_update.py**
   - Update pull request properties
   - Parameters: pr_number, title (optional), body (optional), state (optional), base (optional)
   - API: GET /repos/{owner}/{repo}/pulls/{pull_number}, PATCH /repos/{owner}/{repo}/pulls/{pull_number}
   - Idempotent: YES (compares current vs desired state)
   - Returns: changed, pr_number, pr_url, updated_fields[]

3. **pr_merge.py**
   - Merge pull request
   - Parameters: pr_number, merge_method (merge|squash|rebase), commit_title (optional), commit_message (optional)
   - API: GET /repos/{owner}/{repo}/pulls/{pull_number}, PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge
   - Idempotent: YES (checks if already merged)
   - Returns: changed, merged (bool), sha (merge commit SHA)

4. **pr_comment.py**
   - Add comment to pull request
   - Parameters: pr_number, body (comment text), force (default: false), path (optional), position (optional)
   - API: POST /repos/{owner}/{repo}/issues/{issue_number}/comments OR POST /repos/{owner}/{repo}/pulls/{pull_number}/comments
   - Idempotent: CONFIGURABLE (force param)
   - Returns: changed, comment_id, comment_url

5. **pr_review.py**
   - Submit pull request review
   - Parameters: pr_number, event (APPROVE|REQUEST_CHANGES|COMMENT), body (optional), force (required: true)
   - API: POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews
   - Idempotent: NO (requires force parameter)
   - Returns: changed, review_id, review_state

**Deliverables:**
- 5 PR modules implemented
- Each module with unit tests
- Each module with integration tests
- Each module passes ansible-test sanity/units
- Documentation for all modules

**Testing:**
- Create/update/merge/comment/review workflow tests
- Idempotency validation
- Error handling (merge conflicts, permissions, validation errors)

### GH-33. Ansible Collection - Artifact Modules

**Prerequisites:** GH-30 complete

Implement GitHub workflow artifact management modules:

1. **artifact_list.py**
   - List artifacts for workflow run
   - Parameters: run_id, repository, name (optional filter)
   - API: GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts
   - Idempotent: YES (read-only)
   - Returns: artifacts[] (id, name, size_in_bytes, created_at, expired)

2. **artifact_download.py**
   - Download workflow artifact
   - Parameters: artifact_id, repository, dest (local path), extract (default: true)
   - API: GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip
   - Idempotent: YES (checks if already downloaded with matching checksum)
   - Returns: changed (false if already downloaded), artifact_path, artifact_size

3. **artifact_delete.py**
   - Delete workflow artifact
   - Parameters: artifact_id, repository
   - API: DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}
   - Idempotent: YES (404 on already-deleted is success)
   - Returns: changed (false if already deleted)

**Deliverables:**
- 3 artifact modules implemented
- Each module with unit tests
- Each module with integration tests
- Each module passes ansible-test sanity/units
- Documentation for all modules

**Testing:**
- List/download/delete workflow tests
- Large artifact handling
- Expired artifact handling
- Checksum validation for downloads

### GH-34. Ansible Collection - Integration Tests and Validation

**Prerequisites:** GH-31, GH-32, GH-33 complete (all modules implemented)

Complete integration testing and collection validation:

1. **ansible-test Integration**
   - Create integration test targets for each module
   - Test against real GitHub API (or VCR recordings)
   - Test inter-module workflows (trigger → status → logs → artifacts)
   - Test error scenarios across modules

2. **End-to-End Scenarios**
   - Complete workflow lifecycle (trigger → monitor → cancel)
   - Complete PR lifecycle (create → comment → review → merge)
   - Artifact management workflow (trigger → wait → list → download)

3. **Collection Validation**
   - Run `ansible-test sanity --docker default -v` on complete collection
   - Run `ansible-test units --docker default -v` on all modules
   - Run `ansible-test integration --docker default -v` on all targets
   - Verify all tests pass

4. **Performance Testing**
   - Rate limit handling validation
   - Large artifact download performance
   - Pagination handling with many results

**Deliverables:**
- Complete integration test suite
- All ansible-test validations passing
- Performance benchmarks documented
- Test coverage report

**Testing:**
- Full collection passes ansible-test sanity
- Full collection passes ansible-test units
- Full collection passes ansible-test integration
- Code coverage > 80%

### GH-35. Ansible Collection - Documentation and Examples

**Prerequisites:** GH-34 complete (all modules tested and validated)

Complete collection documentation and example playbooks:

1. **Collection README.md**
   - Getting started guide
   - Installation instructions (ansible-galaxy collection install)
   - Requirements (Python 3.8+, Ansible 2.12+, GitHub token with scopes)
   - Quick examples for each module category
   - Links to detailed documentation

2. **Module Documentation Validation**
   - Verify all modules have complete DOCUMENTATION strings
   - Verify all modules have at least 3 EXAMPLES each
   - Verify all modules have complete RETURN documentation
   - Ensure documentation follows Ansible standards

3. **Category Guides**
   - Create docs/workflow_operations.md (complete workflow module guide)
   - Create docs/pr_operations.md (complete PR module guide)
   - Create docs/artifact_operations.md (complete artifact module guide)
   - Include common patterns and best practices

4. **Example Playbooks**
   - Create docs/examples/trigger_workflow.yml
   - Create docs/examples/create_pr.yml
   - Create docs/examples/download_artifacts.yml
   - Create docs/examples/pr_lifecycle.yml (create → review → merge)
   - Create docs/examples/workflow_orchestration.yml (full workflow lifecycle)
   - All examples must be tested and copy-paste-able

5. **Development Documentation**
   - Create CONTRIBUTING.md with development setup
   - Document testing procedures
   - Document release process
   - Create developer guide for adding new modules

6. **Publish Preparation**
   - Prepare for Ansible Galaxy publication
   - Create CHANGELOG.md
   - Version tagging strategy
   - License file (MIT per design)

**Deliverables:**
- Complete collection documentation
- All example playbooks tested
- Development guide
- Ready for publication to Ansible Galaxy

**Testing:**
- All example playbooks execute successfully
- Documentation generates correctly
- ansible-galaxy collection build succeeds
- Collection installable via ansible-galaxy
