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



### GH-29.1. Ansible Collection - Infrastructure Setup

**Prerequisites:** GH-29 design v2 complete
**Family:** Infrastructure (Foundation)

Create Ansible Collection infrastructure:

1. **Collection Skeleton**
   - Use `ansible-galaxy collection init rstyczynski.github_api`
   - Set up directory structure for roles
   - Create galaxy.yml (namespace: rstyczynski, name: github_api, version: 0.1.0)
   - Create collection README.md
   - Set up .gitignore

2. **Prerequisites and Setup**
   - Document gh CLI installation (>= 2.0.0)
   - Document authentication (GH_TOKEN or gh auth login or ./secrets/github_token)
   - Create test repository setup guide
   - Document Ansible requirements (>= 2.12)

3. **Role Standards and Templates**
   - Create role template with standard structure (tasks/main.yml, defaults/main.yml, README.md)
   - Document consistent parameter naming (prefixed with role name)
   - Create standard error handling pattern for gh CLI calls
   - Create authentication lookup pattern (GH_TOKEN > ./secrets/github_token)
   - Create JSON parsing examples

4. **Testing Infrastructure**
   - Create tests/integration/ structure
   - Create example test playbook template
   - Document testing approach

**Deliverables:**
- Working collection skeleton
- Role template and standards documented
- Development environment setup guide
- Ready for role implementation

**Testing:**
- Verify gh CLI available and authenticated
- ansible-galaxy collection build succeeds
- Template role can be instantiated

---

### GH-29.1.1. workflow_trigger Role

**Prerequisites:** GH-29.1 complete
**Family:** Workflow operations

Implement role to trigger GitHub workflows via gh CLI.

**Role Specification:**
- **Name**: workflow_trigger
- **Purpose**: Trigger GitHub workflow using `gh workflow run`
- **Idempotent**: NO (creates new run each time) - document clearly

**Parameters** (defaults/main.yml):
```yaml
workflow_trigger_repository: ""         # Required: owner/repo
workflow_trigger_workflow: ""           # Required: workflow file name
workflow_trigger_ref: "main"            # Optional: branch/tag
workflow_trigger_inputs: {}             # Optional: workflow inputs dict
workflow_trigger_correlation_id: ""     # Optional: UUID (auto-generated)
```

**gh Command**:
```bash
gh workflow run {{ workflow_trigger_workflow }} \
  --repo {{ workflow_trigger_repository }} \
  --ref {{ workflow_trigger_ref }} \
  {% for key, value in workflow_trigger_inputs.items() %}
  -f {{ key }}={{ value }} \
  {% endfor %}
  -f correlation_id={{ workflow_trigger_correlation_id }}
```

**Returns** (set_fact):
```yaml
workflow_triggered: true
workflow_correlation_id: "<uuid>"
workflow_repository: "<owner/repo>"
```

**Deliverables:**
- tasks/main.yml with trigger logic
- defaults/main.yml with parameters
- README.md with usage examples
- Integration test playbook

**Testing:**
- Trigger workflow successfully
- Correlation ID generated/used
- Inputs passed correctly
- Error handling (auth, invalid workflow)

---

### GH-29.1.2. workflow_status Role

**Prerequisites:** GH-29.1 complete
**Family:** Workflow operations

Implement role to get workflow run status.

**Role Specification:**
- **Name**: workflow_status
- **Purpose**: Get workflow run status by correlation_id or run_id
- **Idempotent**: YES (read-only)

**Parameters**:
```yaml
workflow_status_repository: ""          # Required: owner/repo
workflow_status_correlation_id: ""      # Optional: correlation UUID
workflow_status_run_id: ""              # Optional: run ID
workflow_status_timeout: 300            # Optional: max wait seconds
workflow_status_poll_interval: 10       # Optional: poll every N seconds
```

**gh Commands**:
```bash
# Find by correlation_id
gh run list --repo {{ repository }} \
  --json databaseId,displayTitle,status,conclusion \
  --jq '.[] | select(.displayTitle | contains("{{ correlation_id }}"))'

# Or get specific run_id
gh run view {{ run_id }} --repo {{ repository }} \
  --json status,conclusion,createdAt,updatedAt,url
```

**Returns**:
```yaml
workflow_run_id: 123456789
workflow_status: "completed|in_progress|queued"
workflow_conclusion: "success|failure|cancelled|null"
workflow_url: "https://github.com/..."
```

**Deliverables:**
- Correlation-based lookup
- Direct run_id lookup
- Optional polling with timeout
- README with examples

**Testing:**
- Find by correlation_id
- Find by run_id
- Polling until completion
- Timeout handling

---

### GH-29.1.3. workflow_cancel Role

**Prerequisites:** GH-29.1 complete
**Family:** Workflow operations

Implement role to cancel workflow runs.

**Role Specification:**
- **Name**: workflow_cancel
- **Purpose**: Cancel workflow run
- **Idempotent**: YES (canceling already-cancelled is no-op)

**Parameters**:
```yaml
workflow_cancel_repository: ""          # Required: owner/repo
workflow_cancel_run_id: ""              # Required: run ID
```

**gh Commands**:
```bash
# Check status first
gh run view {{ run_id }} --repo {{ repository }} --json status,conclusion

# Cancel if still running
gh run cancel {{ run_id }} --repo {{ repository }}
```

**Returns**:
```yaml
workflow_cancelled: true|false          # true if was running, false if already done
workflow_final_status: "cancelled|completed"
```

**Deliverables:**
- Idempotency check (skip if already cancelled/completed)
- README with examples

**Testing:**
- Cancel running workflow
- Attempt to cancel completed workflow (should be idempotent)
- Attempt to cancel already-cancelled (should be idempotent)

---

### GH-29.1.4. workflow_logs Role

**Prerequisites:** GH-29.1 complete
**Family:** Workflow operations

Implement role to download workflow logs.

**Role Specification:**
- **Name**: workflow_logs
- **Purpose**: Download workflow execution logs
- **Idempotent**: YES (read-only, can re-download)

**Parameters**:
```yaml
workflow_logs_repository: ""            # Required: owner/repo
workflow_logs_run_id: ""                # Required: run ID
workflow_logs_dest: "./logs"            # Optional: destination directory
```

**gh Command**:
```bash
gh run view {{ run_id }} --repo {{ repository }} --log > {{ dest }}/{{ run_id }}.log
```

**Returns**:
```yaml
workflow_logs_path: "./logs/123456789.log"
workflow_logs_size: 12345
```

**Deliverables:**
- Log download to specified directory
- File size reporting
- README with examples

**Testing:**
- Download logs from completed workflow
- Verify file created
- Re-download (idempotency)

---

### GH-29.2.1. pr_create Role

**Prerequisites:** GH-29.1 complete
**Family:** Pull request operations

Implement role to create pull requests with duplicate checking.

**Role Specification:**
- **Name**: pr_create
- **Purpose**: Create pull request with idempotency via duplicate checking
- **Idempotent**: YES (checks for existing PR with same head/base)

**Parameters**:
```yaml
pr_create_repository: ""                # Required: owner/repo
pr_create_head: ""                      # Required: source branch
pr_create_base: "main"                  # Required: target branch
pr_create_title: ""                     # Required: PR title
pr_create_body: ""                      # Optional: PR description
pr_create_draft: false                  # Optional: create as draft
```

**gh Commands**:
```bash
# Check if PR exists
gh pr list --repo {{ repository }} \
  --head {{ head }} --base {{ base }} --json number,state

# Create if not exists
gh pr create --repo {{ repository }} \
  --head {{ head }} --base {{ base }} \
  --title "{{ title }}" --body "{{ body }}" \
  {% if draft %}--draft{% endif %}
```

**Returns**:
```yaml
pr_created: true|false                  # true if created, false if exists
pr_number: 123
pr_url: "https://github.com/..."
pr_state: "open"
```

**Deliverables:**
- Duplicate checking logic
- Draft PR support
- README with examples

**Testing:**
- Create new PR
- Attempt to create duplicate (should be idempotent)
- Create draft PR

---

### GH-29.2.2. pr_update Role

**Prerequisites:** GH-29.1 complete
**Family:** Pull request operations

Implement role to update pull request properties.

**Role Specification:**
- **Name**: pr_update
- **Purpose**: Update PR title, body, or base branch
- **Idempotent**: YES (compares current vs desired state)

**Parameters**:
```yaml
pr_update_repository: ""                # Required: owner/repo
pr_update_number: 0                     # Required: PR number
pr_update_title: ""                     # Optional: new title
pr_update_body: ""                      # Optional: new body
pr_update_base: ""                      # Optional: new base branch
```

**gh Commands**:
```bash
# Get current state
gh pr view {{ number }} --repo {{ repository }} \
  --json title,body,baseRefName

# Update if different
gh pr edit {{ number }} --repo {{ repository }} \
  {% if title %}--title "{{ title }}"{% endif %} \
  {% if body %}--body "{{ body }}"{% endif %} \
  {% if base %}--base {{ base }}{% endif %}
```

**Returns**:
```yaml
pr_updated: true|false                  # true if changed, false if same
pr_changes: ["title", "body"]           # list of changed fields
```

**Deliverables:**
- State comparison logic
- Selective updates (only change what's different)
- README with examples

**Testing:**
- Update title only
- Update multiple fields
- Attempt update with same values (should be idempotent)

---

### GH-29.2.3. pr_merge Role

**Prerequisites:** GH-29.1 complete
**Family:** Pull request operations

Implement role to merge pull requests.

**Role Specification:**
- **Name**: pr_merge
- **Purpose**: Merge pull request with strategy selection
- **Idempotent**: YES (checks if already merged)

**Parameters**:
```yaml
pr_merge_repository: ""                 # Required: owner/repo
pr_merge_number: 0                      # Required: PR number
pr_merge_method: "merge"                # Optional: merge|squash|rebase
pr_merge_title: ""                      # Optional: commit title
pr_merge_message: ""                    # Optional: commit message
```

**gh Commands**:
```bash
# Check if already merged
gh pr view {{ number }} --repo {{ repository }} --json state,merged

# Merge if open
gh pr merge {{ number }} --repo {{ repository }} \
  --{{ method }} \
  {% if title %}--subject "{{ title }}"{% endif %} \
  {% if message %}--body "{{ message }}"{% endif %}
```

**Returns**:
```yaml
pr_merged: true|false                   # true if merged, false if already merged
pr_merge_commit: "abc123..."
pr_merge_method_used: "merge|squash|rebase"
```

**Deliverables:**
- Merge strategy support (merge, squash, rebase)
- Already-merged check
- README with examples

**Testing:**
- Merge with each strategy
- Attempt to merge already-merged PR (should be idempotent)
- Custom commit message

---

### GH-29.2.4. pr_comment Role

**Prerequisites:** GH-29.1 complete
**Family:** Pull request operations

Implement role to add comments to pull requests.

**Role Specification:**
- **Name**: pr_comment
- **Purpose**: Add comment to PR
- **Idempotent**: CONFIGURABLE (force parameter)

**Parameters**:
```yaml
pr_comment_repository: ""               # Required: owner/repo
pr_comment_number: 0                    # Required: PR number
pr_comment_body: ""                     # Required: comment text
pr_comment_force: false                 # Optional: always add even if duplicate
```

**gh Command**:
```bash
gh pr comment {{ number }} --repo {{ repository }} --body "{{ body }}"
```

**Returns**:
```yaml
pr_comment_added: true
pr_comment_url: "https://github.com/..."
```

**Deliverables:**
- Comment addition
- Optional force parameter
- README with examples

**Testing:**
- Add comment to PR
- Test with force=true (always add)
- Test with force=false (optional duplicate checking)

---

### GH-29.2.5. pr_review Role

**Prerequisites:** GH-29.1 complete
**Family:** Pull request operations

Implement role to submit pull request reviews.

**Role Specification:**
- **Name**: pr_review
- **Purpose**: Submit PR review (approve, request changes, comment)
- **Idempotent**: NO (each review is distinct)

**Parameters**:
```yaml
pr_review_repository: ""                # Required: owner/repo
pr_review_number: 0                     # Required: PR number
pr_review_action: ""                    # Required: approve|request-changes|comment
pr_review_body: ""                      # Optional: review comment
```

**gh Command**:
```bash
gh pr review {{ number }} --repo {{ repository }} \
  --{{ action }} \
  {% if body %}--body "{{ body }}"{% endif %}
```

**Returns**:
```yaml
pr_review_submitted: true
pr_review_state: "APPROVED|CHANGES_REQUESTED|COMMENTED"
```

**Deliverables:**
- Review submission (all 3 types)
- README with examples and non-idempotent warning

**Testing:**
- Submit approval
- Submit request-changes
- Submit comment review

---

### GH-29.3.1. artifact_list Role

**Prerequisites:** GH-29.1 complete
**Family:** Artifact operations

Implement role to list workflow artifacts.

**Role Specification:**
- **Name**: artifact_list
- **Purpose**: List artifacts for a workflow run
- **Idempotent**: YES (read-only)

**Parameters**:
```yaml
artifact_list_repository: ""            # Required: owner/repo
artifact_list_run_id: ""                # Required: run ID
artifact_list_name: ""                  # Optional: filter by name
```

**gh Command**:
```bash
gh api /repos/{{ owner }}/{{ repo }}/actions/runs/{{ run_id }}/artifacts \
  --jq '.artifacts[] | {id, name, size_in_bytes, created_at, expired}'
```

**Returns**:
```yaml
artifacts:
  - id: 123
    name: "build-output"
    size_in_bytes: 1024
    created_at: "2025-01-01T00:00:00Z"
    expired: false
```

**Deliverables:**
- List all artifacts for run
- Optional name filtering
- README with examples

**Testing:**
- List artifacts from workflow run
- Filter by name
- Handle run with no artifacts

---

### GH-29.3.2. artifact_download Role

**Prerequisites:** GH-29.1 complete
**Family:** Artifact operations

Implement role to download workflow artifacts.

**Role Specification:**
- **Name**: artifact_download
- **Purpose**: Download artifact zip file
- **Idempotent**: YES (checks if already downloaded with matching checksum)

**Parameters**:
```yaml
artifact_download_repository: ""        # Required: owner/repo
artifact_download_id: ""                # Required: artifact ID
artifact_download_dest: "./artifacts"   # Optional: destination directory
artifact_download_extract: true         # Optional: extract zip
```

**gh Commands**:
```bash
# Download
gh api /repos/{{ owner }}/{{ repo }}/actions/artifacts/{{ id }}/zip \
  > {{ dest }}/artifact-{{ id }}.zip

# Extract if requested
unzip {{ dest }}/artifact-{{ id }}.zip -d {{ dest }}/artifact-{{ id }}/
```

**Returns**:
```yaml
artifact_downloaded: true|false         # false if already exists
artifact_path: "./artifacts/artifact-123"
artifact_size: 1024
```

**Deliverables:**
- Download artifact
- Optional extraction
- Checksum validation for idempotency
- README with examples

**Testing:**
- Download and extract artifact
- Re-download (should be idempotent)
- Download without extraction

---

### GH-29.3.3. artifact_delete Role

**Prerequisites:** GH-29.1 complete
**Family:** Artifact operations

Implement role to delete workflow artifacts.

**Role Specification:**
- **Name**: artifact_delete
- **Purpose**: Delete artifact
- **Idempotent**: YES (404 on already-deleted is success)

**Parameters**:
```yaml
artifact_delete_repository: ""          # Required: owner/repo
artifact_delete_id: ""                  # Required: artifact ID
```

**gh Command**:
```bash
gh api -X DELETE /repos/{{ owner }}/{{ repo }}/actions/artifacts/{{ id }}
```

**Returns**:
```yaml
artifact_deleted: true|false            # false if already deleted
```

**Deliverables:**
- Delete artifact
- Handle already-deleted (idempotent)
- README with examples

**Testing:**
- Delete artifact
- Attempt to delete already-deleted (should be idempotent)
- Handle not-found gracefully

---

### GH-29.3.4. Collection Documentation

**Prerequisites:** All roles (GH-29.1.1-4, GH-29.2.1-5, GH-29.3.1-3) complete
**Family:** Documentation

Complete collection documentation and example playbooks.

**Deliverables:**

1. **Collection README.md**
   - Getting started guide
   - Installation: `ansible-galaxy collection install rstyczynski.github_api`
   - Requirements (gh CLI >= 2.0.0, Ansible >= 2.12, GitHub token)
   - Quick examples for each role family
   - Links to role documentation

2. **Example Playbooks** (playbooks/ directory)
   - `trigger_workflow.yml`: Trigger and monitor workflow
   - `create_pr.yml`: Create PR with review
   - `download_artifacts.yml`: List and download artifacts
   - `pr_lifecycle.yml`: Complete PR workflow (create → review → merge)
   - `workflow_orchestration.yml`: Full workflow lifecycle
   - All examples tested and copy-paste-able

3. **Category Guides** (docs/ directory)
   - `workflow_operations.md`: Complete guide to workflow roles
   - `pr_operations.md`: Complete guide to PR roles
   - `artifact_operations.md`: Complete guide to artifact roles
   - Common patterns and best practices

4. **Publishing**
   - CHANGELOG.md (version 0.1.0)
   - LICENSE (MIT)
   - ansible-galaxy collection build
   - Test installation from built tarball

**Testing:**
- All example playbooks execute successfully
- ansible-galaxy collection build succeeds
- Collection installable: `ansible-galaxy collection install rstyczynski-github_api-0.1.0.tar.gz`
- Documentation renders correctly

---

### GH-29.4.1. workflow_orchestrator Role (Optional)

**Prerequisites:** GH-29.3.4 complete
**Family:** Advanced orchestration

High-level role that orchestrates complete workflow lifecycle.

**Purpose**: Trigger → monitor → logs → artifacts in single role invocation.

**Parameters**:
```yaml
workflow_orch_repository: ""
workflow_orch_workflow: ""
workflow_orch_inputs: {}
workflow_orch_download_logs: true
workflow_orch_download_artifacts: true
workflow_orch_timeout: 600
```

**Uses Roles**:
- workflow_trigger
- workflow_status (with polling)
- workflow_logs (if requested)
- artifact_list + artifact_download (if requested)

**Note**: Optional future enhancement.

---

### GH-29.4.2. pr_lifecycle Role (Optional)

**Prerequisites:** GH-29.3.4 complete
**Family:** Advanced orchestration

High-level role for complete PR workflow.

**Purpose**: Create → wait for review → merge in single role invocation.

**Parameters**:
```yaml
pr_lifecycle_repository: ""
pr_lifecycle_head: ""
pr_lifecycle_base: "main"
pr_lifecycle_title: ""
pr_lifecycle_auto_merge: false
pr_lifecycle_merge_method: "merge"
```

**Uses Roles**:
- pr_create
- pr_update (optional)
- pr_merge (if auto_merge=true after checks pass)

**Note**: Optional future enhancement.
