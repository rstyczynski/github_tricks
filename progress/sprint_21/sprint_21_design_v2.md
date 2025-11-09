# Sprint 21 - Design (v2 - gh CLI Approach)

## GH-29. Design Ansible Collection to handle GitHub API

Status: Proposed (Revision 2 - gh CLI approach)

**Design Revision**: Changed from pure Python modules to Ansible roles/modules using `gh` CLI utility.

**Rationale**:
- Simpler implementation (leverage existing `gh` CLI)
- We've been using `gh` throughout Sprints 0-20
- `gh` handles authentication, rate limiting, pagination automatically
- Less code to write and maintain
- Faster implementation timeline
- Still provides Ansible benefits (idempotency, declarative, error handling)

### Requirement Summary

Design an Ansible Collection that provides idiomatic, reusable, and testable automation for GitHub API operations including:
- Workflows (trigger, correlate, cancel, monitor, logs)
- Pull Requests (create, list, update, merge)
- Comments and Reviews (add, update, delete, submit reviews, approvals)
- Artifacts (list, download, delete)

This is a **design-only sprint** - deliverable is comprehensive architecture and specifications, not implementation.

### Feasibility Analysis

**Tool Availability:**

✅ **GitHub CLI (`gh`) - Primary Tool:**
- Official GitHub CLI tool
- Supports all required operations
- Handles authentication automatically (GH_TOKEN env var or `gh auth login`)
- Built-in JSON output for parsing (`--json` flag)
- Pagination handled automatically
- Rate limiting handled automatically
- Documentation: https://cli.github.com/manual/

✅ **Workflow Operations (`gh workflow` and `gh run`):**
- Trigger: `gh workflow run <workflow> --ref <branch> -f key=value`
- List runs: `gh run list --workflow <workflow>`
- View run: `gh run view <run-id>`
- Cancel run: `gh run cancel <run-id>`
- Download logs: `gh run download <run-id>` or `gh run view <run-id> --log`
- Watch run: `gh run watch <run-id>`

✅ **Pull Request Operations (`gh pr`):**
- Create: `gh pr create --title "..." --body "..." --base main --head feature`
- List: `gh pr list --state all --json number,title,state`
- View: `gh pr view <number>`
- Update: `gh pr edit <number> --title "..." --body "..."`
- Merge: `gh pr merge <number> --merge|--squash|--rebase`
- Comment: `gh pr comment <number> --body "..."`
- Review: `gh pr review <number> --approve|--request-changes|--comment --body "..."`
- Close: `gh pr close <number>`
- Reopen: `gh pr reopen <number>`

✅ **Artifact Operations (via `gh api`):**
- List: `gh api /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`
- Download: `gh api /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip > artifact.zip`
- Delete: `gh api -X DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`

**Technical Constraints:**

1. **Idempotency Handling:**
   - Check-before-action pattern using `gh` queries
   - Parse JSON output to determine current state
   - Compare with desired state before making changes

2. **Authentication:**
   - `gh` uses GH_TOKEN environment variable (automatic)
   - Or `gh auth login` for interactive auth
   - Or `gh auth login --with-token < token-file`

3. **Error Handling:**
   - Parse `gh` exit codes (0 = success, non-zero = error)
   - Parse stderr for error messages
   - Use `--json` output for structured data

4. **JSON Parsing:**
   - `gh` supports `--json` flag with `--jq` for filtering
   - Ansible has `from_json` filter for parsing
   - Use `register` to capture output for processing

**Risk Assessment:**

- **Risk 1: gh CLI dependency** - Requires gh installed on control node
  - **Mitigation**: Document installation, check in prerequisites, gh widely available
  - **Severity**: Low

- **Risk 2: gh CLI version compatibility** - Different versions may have different features
  - **Mitigation**: Document minimum gh version required, test with specific versions
  - **Severity**: Low

- **Risk 3: JSON parsing complexity** - Complex jq expressions may be hard to maintain
  - **Mitigation**: Keep queries simple, use Ansible filters when possible
  - **Severity**: Low

**Feasibility Conclusion:** ✅ **HIGHLY FEASIBLE** - gh CLI provides all required functionality, simpler than pure Python approach, leverages existing project tooling.

### Design Overview

**Architecture:**

Ansible Collection with **roles** (not pure modules) that use `gh` CLI:

```
rstyczynski.github_api/
├── galaxy.yml                    # Collection metadata
├── README.md                     # Collection documentation
├── .gitignore                    # Git ignore
│
├── roles/
│   ├── workflow_trigger/         # Trigger GitHub workflow
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── workflow_status/          # Get workflow run status
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── workflow_cancel/          # Cancel workflow run
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── workflow_logs/            # Download workflow logs
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── pr_create/                # Create pull request
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── pr_update/                # Update pull request
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── pr_merge/                 # Merge pull request
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── pr_comment/               # Add PR comment
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── pr_review/                # Submit PR review
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── artifact_list/            # List workflow artifacts
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── artifact_download/        # Download artifacts
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   └── artifact_delete/          # Delete artifacts
│       ├── tasks/
│       │   └── main.yml
│       ├── defaults/
│       │   └── main.yml
│       └── README.md
│
├── playbooks/                    # Example playbooks
│   ├── trigger_workflow.yml
│   ├── create_pr.yml
│   ├── download_artifacts.yml
│   └── pr_lifecycle.yml
│
├── tests/
│   └── integration/              # Integration tests
│       ├── test_workflows.yml
│       ├── test_pull_requests.yml
│       └── test_artifacts.yml
│
└── docs/
    ├── workflow_operations.md
    ├── pr_operations.md
    └── artifact_operations.md
```

**Key Components:**

1. **Ansible Roles** (12 roles, one per operation)
   - Each role uses `ansible.builtin.command` or `ansible.builtin.shell` to call `gh` CLI
   - Each role implements idempotency via check-before-action pattern
   - Each role has clear parameters in `defaults/main.yml`
   - Each role returns structured data via `set_fact`

2. **No Python Dependencies**
   - Only requirement: `gh` CLI installed on control node
   - Ansible's built-in JSON parsing (`from_json` filter)
   - No virtual environments needed

3. **Testing Strategy**
   - Integration tests (real `gh` CLI calls against test repository)
   - Idempotency tests (run twice, verify no changes second time)
   - Molecule for role testing (optional)

4. **Documentation**
   - Each role has README with usage examples
   - Collection README with getting started
   - Example playbooks for common workflows

**Data Flow:**

```
Playbook
    ↓
Include Role (e.g., workflow_trigger)
    ↓
Validate Arguments (argument_spec or asserts)
    ↓
Check Current State (gh query)
    ↓
Determine if Action Needed
    ↓
Execute gh CLI Command (if needed)
    ↓
Parse Output (register + from_json)
    ↓
Set Facts (for downstream tasks)
    ↓
Return to Playbook
```

### Technical Specification

**Role Pattern (All roles follow this):**

```yaml
# roles/workflow_trigger/tasks/main.yml
---
- name: Validate required parameters
  ansible.builtin.assert:
    that:
      - workflow_trigger_workflow is defined
      - workflow_trigger_repository is defined
    fail_msg: "Required parameters: workflow_trigger_workflow, workflow_trigger_repository"

- name: Set default values
  ansible.builtin.set_fact:
    workflow_trigger_ref: "{{ workflow_trigger_ref | default('main') }}"
    workflow_trigger_inputs: "{{ workflow_trigger_inputs | default({}) }}"
    workflow_trigger_correlation_id: "{{ workflow_trigger_correlation_id | default(lookup('pipe', 'uuidgen')) }}"

- name: Build gh workflow run command
  ansible.builtin.set_fact:
    gh_command: >-
      gh workflow run {{ workflow_trigger_workflow }}
      --repo {{ workflow_trigger_repository }}
      --ref {{ workflow_trigger_ref }}
      {% for key, value in workflow_trigger_inputs.items() %}
      -f {{ key }}={{ value }}
      {% endfor %}
      -f correlation_id={{ workflow_trigger_correlation_id }}

- name: Trigger workflow
  ansible.builtin.command: "{{ gh_command }}"
  environment:
    GH_TOKEN: "{{ lookup('env', 'GH_TOKEN') | default(lookup('file', './secrets/github_token'), true) }}"
  register: workflow_trigger_result
  changed_when: true

- name: Set result facts
  ansible.builtin.set_fact:
    workflow_triggered: true
    workflow_correlation_id: "{{ workflow_trigger_correlation_id }}"
    workflow_repository: "{{ workflow_trigger_repository }}"
```

**Role Specifications:**

### 1. workflow_trigger

**Purpose**: Trigger GitHub workflow via workflow_dispatch

**Parameters** (defaults/main.yml):
```yaml
workflow_trigger_workflow: ""           # Required: workflow file name
workflow_trigger_repository: ""         # Required: owner/repo
workflow_trigger_ref: "main"            # Optional: branch/tag
workflow_trigger_inputs: {}             # Optional: workflow inputs
workflow_trigger_correlation_id: ""     # Optional: UUID (auto-generated)
```

**gh Command**:
```bash
gh workflow run <workflow> \
  --repo <repository> \
  --ref <ref> \
  -f key1=value1 \
  -f correlation_id=<uuid>
```

**Idempotent**: NO (creates new run each time) - document clearly

**Returns**:
```yaml
workflow_triggered: true
workflow_correlation_id: "<uuid>"
workflow_repository: "<owner/repo>"
```

---

### 2. workflow_status

**Purpose**: Get workflow run status by correlation_id or run_id

**Parameters**:
```yaml
workflow_status_correlation_id: ""      # Optional: correlation UUID
workflow_status_run_id: ""              # Optional: run ID
workflow_status_repository: ""          # Required: owner/repo
workflow_status_timeout: 300            # Optional: max wait seconds
workflow_status_poll_interval: 10       # Optional: poll every N seconds
```

**gh Commands**:
```bash
# Option 1: Find by correlation_id
gh run list --repo <repository> --json databaseId,displayTitle,status,conclusion \
  --jq '.[] | select(.displayTitle | contains("<correlation_id>"))'

# Option 2: Get specific run_id
gh run view <run_id> --repo <repository> --json status,conclusion,createdAt,updatedAt,url
```

**Idempotent**: YES (read-only)

**Returns**:
```yaml
workflow_run_id: 123456789
workflow_status: "completed|in_progress|queued"
workflow_conclusion: "success|failure|cancelled|null"
workflow_url: "https://github.com/..."
```

---

### 3. workflow_cancel

**Purpose**: Cancel workflow run

**Parameters**:
```yaml
workflow_cancel_run_id: ""              # Required: run ID
workflow_cancel_repository: ""          # Required: owner/repo
```

**gh Command**:
```bash
# Check if already cancelled/completed
gh run view <run_id> --repo <repository> --json status,conclusion

# Cancel if still running
gh run cancel <run_id> --repo <repository>
```

**Idempotent**: YES (canceling already-cancelled is no-op)

**Returns**:
```yaml
workflow_cancelled: true|false          # true if was running, false if already done
workflow_final_status: "cancelled|completed"
```

---

### 4. workflow_logs

**Purpose**: Download workflow logs

**Parameters**:
```yaml
workflow_logs_run_id: ""                # Required: run ID
workflow_logs_repository: ""            # Required: owner/repo
workflow_logs_dest: "./logs"            # Optional: local directory
```

**gh Command**:
```bash
gh run view <run_id> --repo <repository> --log > logs/<run_id>.log
```

**Idempotent**: YES (read-only, can re-download)

**Returns**:
```yaml
workflow_logs_path: "./logs/123456789.log"
workflow_logs_size: 12345
```

---

### 5. pr_create

**Purpose**: Create pull request with duplicate checking

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
# Check if PR already exists
gh pr list --repo <repository> --head <head> --base <base> --json number,state

# Create if not exists
gh pr create --repo <repository> \
  --head <head> --base <base> \
  --title "<title>" --body "<body>" \
  {% if pr_create_draft %}--draft{% endif %}
```

**Idempotent**: YES (checks for existing PR)

**Returns**:
```yaml
pr_created: true|false                  # true if created, false if exists
pr_number: 123
pr_url: "https://github.com/..."
pr_state: "open"
```

---

### 6. pr_update

**Purpose**: Update pull request properties

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
gh pr view <number> --repo <repository> --json title,body,baseRefName

# Update if different
gh pr edit <number> --repo <repository> \
  {% if pr_update_title %}--title "<title>"{% endif %} \
  {% if pr_update_body %}--body "<body>"{% endif %} \
  {% if pr_update_base %}--base <base>{% endif %}
```

**Idempotent**: YES (compares current vs desired)

**Returns**:
```yaml
pr_updated: true|false                  # true if changed, false if same
pr_changes: ["title", "body"]           # list of changed fields
```

---

### 7. pr_merge

**Purpose**: Merge pull request

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
gh pr view <number> --repo <repository> --json state,merged

# Merge if open
gh pr merge <number> --repo <repository> \
  --{{ pr_merge_method }} \
  {% if pr_merge_title %}--subject "<title>"{% endif %} \
  {% if pr_merge_message %}--body "<message>"{% endif %}
```

**Idempotent**: YES (checks if already merged)

**Returns**:
```yaml
pr_merged: true|false                   # true if merged, false if already merged
pr_merge_commit: "abc123..."
```

---

### 8. pr_comment

**Purpose**: Add comment to pull request

**Parameters**:
```yaml
pr_comment_repository: ""               # Required: owner/repo
pr_comment_number: 0                    # Required: PR number
pr_comment_body: ""                     # Required: comment text
pr_comment_force: false                 # Optional: always add even if duplicate
```

**gh Command**:
```bash
gh pr comment <number> --repo <repository> --body "<body>"
```

**Idempotent**: CONFIGURABLE (force parameter)

**Returns**:
```yaml
pr_comment_added: true
pr_comment_url: "https://github.com/..."
```

---

### 9. pr_review

**Purpose**: Submit pull request review

**Parameters**:
```yaml
pr_review_repository: ""                # Required: owner/repo
pr_review_number: 0                     # Required: PR number
pr_review_action: ""                    # Required: approve|request-changes|comment
pr_review_body: ""                      # Optional: review comment
```

**gh Command**:
```bash
gh pr review <number> --repo <repository> \
  --{{ pr_review_action }} \
  {% if pr_review_body %}--body "<body>"{% endif %}
```

**Idempotent**: NO (each review is distinct)

**Returns**:
```yaml
pr_review_submitted: true
pr_review_state: "APPROVED|CHANGES_REQUESTED|COMMENTED"
```

---

### 10. artifact_list

**Purpose**: List workflow artifacts

**Parameters**:
```yaml
artifact_list_repository: ""            # Required: owner/repo
artifact_list_run_id: ""                # Required: run ID
artifact_list_name: ""                  # Optional: filter by name
```

**gh Command**:
```bash
gh api /repos/<owner>/<repo>/actions/runs/<run_id>/artifacts \
  --jq '.artifacts[] | {id, name, size_in_bytes, created_at, expired}'
```

**Idempotent**: YES (read-only)

**Returns**:
```yaml
artifacts:
  - id: 123
    name: "build-output"
    size_in_bytes: 1024
    created_at: "2025-01-01T00:00:00Z"
    expired: false
```

---

### 11. artifact_download

**Purpose**: Download workflow artifact

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
gh api /repos/<owner>/<repo>/actions/artifacts/<id>/zip > artifact.zip

# Extract if needed
unzip artifact.zip -d <dest>
```

**Idempotent**: YES (checks if already downloaded with same checksum)

**Returns**:
```yaml
artifact_downloaded: true|false         # false if already exists
artifact_path: "./artifacts/build-output"
artifact_size: 1024
```

---

### 12. artifact_delete

**Purpose**: Delete workflow artifact

**Parameters**:
```yaml
artifact_delete_repository: ""          # Required: owner/repo
artifact_delete_id: ""                  # Required: artifact ID
```

**gh Command**:
```bash
gh api -X DELETE /repos/<owner>/<repo>/actions/artifacts/<id>
```

**Idempotent**: YES (404 on already-deleted is success)

**Returns**:
```yaml
artifact_deleted: true|false            # false if already deleted
```

---

### Error Handling

**Standard Pattern for All Roles:**

```yaml
- name: Execute gh command
  ansible.builtin.command: "{{ gh_command }}"
  environment:
    GH_TOKEN: "{{ lookup('env', 'GH_TOKEN') | default(lookup('file', './secrets/github_token'), true) }}"
  register: result
  failed_when: false
  changed_when: result.rc == 0

- name: Handle errors
  when: result.rc != 0
  block:
    - name: Parse error message
      ansible.builtin.set_fact:
        error_message: "{{ result.stderr | default('Unknown error') }}"

    - name: Handle authentication errors
      ansible.builtin.fail:
        msg: "GitHub authentication failed: {{ error_message }}"
      when: "'authentication' in error_message.lower() or 'token' in error_message.lower()"

    - name: Handle not found errors
      ansible.builtin.fail:
        msg: "Resource not found: {{ error_message }}"
      when: "'not found' in error_message.lower() or '404' in error_message"

    - name: Handle rate limit errors
      ansible.builtin.fail:
        msg: "GitHub rate limit exceeded: {{ error_message }}"
      when: "'rate limit' in error_message.lower()"

    - name: Generic error
      ansible.builtin.fail:
        msg: "gh command failed: {{ error_message }}"
```

### Implementation Approach

**Phase 1: Collection Bootstrap**
- Create collection skeleton with ansible-galaxy collection init
- Set up directory structure for roles
- Create galaxy.yml

**Phase 2: Core Roles (4 roles)**
- workflow_trigger
- workflow_status
- pr_create
- artifact_download

**Phase 3: Remaining Roles (8 roles)**
- All other workflow, PR, and artifact roles

**Phase 4: Testing**
- Integration tests with real GitHub repository
- Idempotency validation

**Phase 5: Documentation**
- README for each role
- Collection README
- Example playbooks

### Testing Strategy

**Integration Tests:**

```yaml
# tests/integration/test_workflows.yml
---
- name: Test workflow operations
  hosts: localhost
  gather_facts: false
  vars:
    test_repository: "rstyczynski/github_tricks"
    test_workflow: "test-workflow.yml"

  tasks:
    - name: Trigger workflow
      include_role:
        name: rstyczynski.github_api.workflow_trigger
      vars:
        workflow_trigger_repository: "{{ test_repository }}"
        workflow_trigger_workflow: "{{ test_workflow }}"
        workflow_trigger_inputs:
          test_param: "integration-test"

    - name: Wait and check status
      include_role:
        name: rstyczynski.github_api.workflow_status
      vars:
        workflow_status_repository: "{{ test_repository }}"
        workflow_status_correlation_id: "{{ workflow_correlation_id }}"
        workflow_status_timeout: 300

    - name: Verify workflow completed
      assert:
        that:
          - workflow_status == "completed"
          - workflow_conclusion == "success"
```

**Idempotency Tests:**

```yaml
- name: Create PR (first time)
  include_role:
    name: rstyczynski.github_api.pr_create
  vars:
    pr_create_repository: "{{ test_repository }}"
    pr_create_head: "test-branch"
    pr_create_base: "main"
    pr_create_title: "Test PR"

- name: Save PR number
  set_fact:
    first_pr_number: "{{ pr_number }}"
    first_pr_created: "{{ pr_created }}"

- name: Create same PR (second time - should be idempotent)
  include_role:
    name: rstyczynski.github_api.pr_create
  vars:
    pr_create_repository: "{{ test_repository }}"
    pr_create_head: "test-branch"
    pr_create_base: "main"
    pr_create_title: "Test PR"

- name: Verify idempotency
  assert:
    that:
      - first_pr_created == true
      - pr_created == false              # Should not create duplicate
      - pr_number == first_pr_number     # Should return existing PR
```

### Integration Notes

**Compatibility with Existing Work:**

- Existing bash/curl scripts serve as reference
- `gh` CLI commands map to same API endpoints used in scripts
- Token authentication compatible (GH_TOKEN or ./secrets/github_token)
- Correlation mechanism (UUID in workflow name) preserved

**Advantages over Python Approach:**

1. **Simpler**: No Python code, no virtual environments, no dependency management
2. **Faster to implement**: Roles are simpler than modules
3. **Leverages existing tools**: We've been using `gh` for 20 sprints
4. **Maintenance**: `gh` maintained by GitHub, not us
5. **Updates**: `gh` CLI updates automatically provide new features

**Trade-offs:**

1. **Dependency on gh CLI**: Must be installed on control node
2. **Less granular error handling**: Depends on `gh` error messages
3. **Performance**: Spawning gh processes vs direct Python API calls (minimal impact)

### Documentation Requirements

**Each Role README.md:**

```markdown
# workflow_trigger

Trigger GitHub workflow via workflow_dispatch event.

## Requirements

- gh CLI installed on control node
- GitHub token (GH_TOKEN env var or ./secrets/github_token)
- Workflow must have workflow_dispatch trigger

## Role Variables

- `workflow_trigger_workflow`: Workflow file name (required)
- `workflow_trigger_repository`: Repository in owner/repo format (required)
- `workflow_trigger_ref`: Branch/tag to run on (default: main)
- `workflow_trigger_inputs`: Dict of workflow inputs (default: {})
- `workflow_trigger_correlation_id`: UUID for tracking (auto-generated)

## Example Playbook

\`\`\`yaml
- hosts: localhost
  roles:
    - role: rstyczynski.github_api.workflow_trigger
      workflow_trigger_repository: "owner/repo"
      workflow_trigger_workflow: "deploy.yml"
      workflow_trigger_ref: "main"
      workflow_trigger_inputs:
        environment: "production"
\`\`\`

## Return Values

- `workflow_triggered`: Always true
- `workflow_correlation_id`: UUID for correlating this run
- `workflow_repository`: Repository that was triggered

## Notes

This role is NOT idempotent - it creates a new workflow run each time.
```

### Design Decisions

**Decision 1: Roles vs Modules**
- **Chosen**: Roles (not pure Python modules)
- **Rationale**: Simpler to implement, leverage `gh` CLI, easier to test

**Decision 2: gh CLI vs Python/requests**
- **Chosen**: gh CLI
- **Rationale**: Already using gh, handles auth/rate limiting/pagination, simpler

**Decision 3: Authentication**
- **Chosen**: GH_TOKEN env var (gh standard) or ./secrets/github_token (backward compat)
- **Rationale**: Works with gh automatically, compatible with existing patterns

**Decision 4: JSON Parsing**
- **Chosen**: gh --json + Ansible from_json filter
- **Rationale**: No external dependencies, built into gh and Ansible

**Decision 5: Idempotency Implementation**
- **Chosen**: Check-before-action pattern using gh queries
- **Rationale**: Simple, reliable, uses gh's built-in query capabilities

## Design Approval Status

**Status: Proposed (v2 - gh CLI approach)**

This design is ready for Product Owner review. Significant simplification from v1 (Python modules).

**Design Artifacts:**
- Complete architecture (12 roles specified)
- Role specifications with parameters and gh commands
- Testing strategy with examples
- Documentation requirements
- Implementation roadmap

**Awaiting:** Product Owner approval to proceed to implementation backlog creation.
