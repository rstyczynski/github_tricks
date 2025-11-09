# Sprint 21 - Design

## GH-29. Design Ansible Collection to handle GitHub API

Status: Proposed

### Requirement Summary

Design an Ansible Collection that provides idiomatic, reusable, and testable automation for GitHub API operations including:
- Workflows (trigger, correlate, cancel, monitor, logs)
- Pull Requests (create, list, update, merge)
- Comments and Reviews (add, update, delete, submit reviews, approvals)
- Artifacts (list, download, delete)

This is a **design-only sprint** - deliverable is comprehensive architecture and specifications, not implementation.

### Feasibility Analysis

**API Availability:**

All required operations are supported by GitHub REST API:

✅ **Workflow Operations:**
- Trigger: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` (Sprint 15)
- List runs: `GET /repos/{owner}/{repo}/actions/runs` (Sprint 15)
- Get run: `GET /repos/{owner}/{repo}/actions/runs/{run_id}` (Sprint 15)
- Cancel run: `DELETE /repos/{owner}/{repo}/actions/runs/{run_id}` (Sprint 11)
- Get logs: `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` (Sprint 15)

✅ **Pull Request Operations:**
- Create: `POST /repos/{owner}/{repo}/pulls` (Sprint 13)
- List: `GET /repos/{owner}/{repo}/pulls` (Sprint 13)
- Update: `PATCH /repos/{owner}/{repo}/pulls/{pull_number}` (Sprint 13)
- Merge: `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge` (Sprint 14)
- Comments: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` (Sprint 14)
- Reviews: `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews` (GitHub API)

✅ **Artifact Operations:**
- List: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts` (Sprint 16)
- Download: `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip` (Sprint 17)
- Delete: `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}` (Sprint 18)

**References:**
- GitHub REST API documentation: https://docs.github.com/rest
- Sprints 13-20: All endpoints tested and validated
- Ansible Collection development guide: https://docs.ansible.com/ansible/latest/dev_guide/developing_collections.html

**Technical Constraints:**

1. **Idempotency Limitations:**
   - Workflow trigger is NOT idempotent (creates new run each time) ✅ Will document clearly
   - PR create requires duplicate checking ✅ Will implement check-first pattern
   - Some operations naturally idempotent (read operations, delete when already deleted)

2. **Rate Limiting:**
   - GitHub API has rate limits (5000/hour authenticated) ✅ Will implement proper error handling
   - Must handle 403 responses with X-RateLimit headers ✅ Design includes rate limit detection

3. **Authentication:**
   - Requires GitHub Personal Access Token ✅ Multiple sources supported (param, env, file)
   - Token must have appropriate scopes ✅ Will document required scopes

4. **Testing Requirements:**
   - ansible-test requires specific directory structure ✅ Will follow collection skeleton
   - Integration tests need GitHub API access ✅ Will use mocks for unit tests, real API for integration
   - Molecule requires Podman ✅ Documented in requirements

**Risk Assessment:**

- **Risk 1: Testing complexity** - ansible-test has steep learning curve
  - **Mitigation**: Use ansible-galaxy collection init to generate skeleton, follow examples from community collections
  - **Severity**: Medium

- **Risk 2: Non-idempotent operations** - Some GitHub operations cannot be truly idempotent
  - **Mitigation**: Clear documentation, force parameters where appropriate, check-first patterns
  - **Severity**: Low (well understood, documented pattern)

- **Risk 3: Scope creep** - Collection could grow very large
  - **Mitigation**: Phase implementation - start with core 6-8 modules, expand later
  - **Severity**: Low (design phase, no code yet)

- **Risk 4: Python dependency management** - Conflicts with existing Python environment
  - **Mitigation**: Use .venv per Ansible BP, document setup clearly
  - **Severity**: Low (standard practice)

**Feasibility Conclusion:** ✅ **FEASIBLE** - All required APIs available, Ansible Collection framework well-documented, 20 sprints of GitHub API experience provides solid foundation.

### Design Overview

**Architecture:**

Ansible Collection with modular design:

```
rstyczynski.github_api/
├── galaxy.yml                    # Collection metadata
├── README.md                     # Collection documentation
├── requirements.txt              # Python dependencies
├── .gitignore                    # Git ignore (.venv, etc.)
│
├── plugins/
│   └── modules/                  # Ansible modules (primary delivery)
│       ├── workflow_trigger.py   # Trigger GitHub workflow
│       ├── workflow_status.py    # Get workflow run status
│       ├── workflow_cancel.py    # Cancel workflow run
│       ├── workflow_logs.py      # Retrieve workflow logs
│       ├── pr_create.py          # Create pull request
│       ├── pr_update.py          # Update pull request
│       ├── pr_merge.py           # Merge pull request
│       ├── pr_comment.py         # Add/manage PR comments
│       ├── pr_review.py          # Submit PR review
│       ├── artifact_list.py      # List workflow artifacts
│       ├── artifact_download.py  # Download artifacts
│       └── artifact_delete.py    # Delete artifacts
│
├── roles/                        # Pre-built automation (future sprint)
│   ├── workflow_orchestrator/    # End-to-end workflow execution
│   └── pr_lifecycle/             # PR creation to merge
│
├── tests/
│   ├── integration/              # Integration tests (ansible-test)
│   │   └── targets/
│   │       ├── workflow_trigger/
│   │       ├── pr_create/
│   │       └── ...
│   ├── unit/                     # Unit tests (ansible-test)
│   │   └── plugins/
│   │       └── modules/
│   │           ├── test_workflow_trigger.py
│   │           └── ...
│   └── sanity/                   # Sanity tests (ansible-test)
│       └── ignore.txt
│
├── docs/
│   ├── workflow_operations.md   # Workflow module documentation
│   ├── pr_operations.md          # PR module documentation
│   ├── artifact_operations.md   # Artifact module documentation
│   └── examples/                 # Playbook examples
│       ├── trigger_workflow.yml
│       ├── create_pr.yml
│       └── download_artifacts.yml
│
└── meta/
    └── runtime.yml               # Collection runtime configuration
```

**Key Components:**

1. **Ansible Modules** (Primary delivery - Sprint 21 design scope)
   - Pure Python implementation using `requests` library
   - Follow Ansible module API (AnsibleModule, argument_spec, etc.)
   - Comprehensive DOCUMENTATION/EXAMPLES/RETURN docstrings
   - Idempotency where possible, clear documentation where not

2. **Testing Infrastructure**
   - ansible-test sanity: Python syntax, documentation validation
   - ansible-test units: Mock GitHub API responses, test logic
   - ansible-test integration: Real GitHub API (or mock server)
   - Molecule (future): For role testing if roles implemented

3. **Documentation**
   - Module docstrings (DOCUMENTATION/EXAMPLES/RETURN)
   - Collection README with getting started guide
   - Category-specific guides (workflows, PRs, artifacts)
   - Playbook examples for common use cases

4. **Python Dependencies**
   - requests: HTTP client for GitHub API
   - python-dateutil: Date parsing and formatting
   - urllib3: URL handling
   - All in requirements.txt with version constraints

**Data Flow:**

```
Playbook Task
    ↓
Ansible Module (Python)
    ↓
Argument Validation (argument_spec)
    ↓
Authentication Resolution (param > env > file)
    ↓
GitHub API Call (requests library)
    ↓
Response Processing
    ↓
Idempotency Check (if applicable)
    ↓
Return Result (changed, failed, result data)
```

### Technical Specification

**Module Interface Pattern (All modules follow this):**

```python
# Standard structure for all modules
from ansible.module_utils.basic import AnsibleModule
import requests
import os

DOCUMENTATION = r'''
---
module: <module_name>
short_description: <Brief description>
description:
    - <Detailed description>
    - <Additional details>
options:
    github_token:
        description: GitHub personal access token
        required: false  # Can use env var or file
        type: str
        no_log: true
    github_api_url:
        description: GitHub API base URL
        required: false
        type: str
        default: https://api.github.com
    repository:
        description: Repository in owner/repo format
        required: true
        type: str
    # ... module-specific options
requirements:
    - requests >= 2.28.0
author:
    - Robert Styczynski (@rstyczynski)
'''

EXAMPLES = r'''
- name: <Example use case>
  rstyczynski.github_api.<module_name>:
    github_token: "{{ lookup('env', 'GITHUB_TOKEN') }}"
    repository: "owner/repo"
    # ... example parameters
'''

RETURN = r'''
changed:
    description: Whether any change was made
    returned: always
    type: bool
message:
    description: Human-readable message
    returned: always
    type: str
# ... module-specific return values
'''

def run_module():
    module_args = dict(
        github_token=dict(type='str', required=False, no_log=True),
        github_api_url=dict(type='str', default='https://api.github.com'),
        repository=dict(type='str', required=True),
        # ... module-specific arguments
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    # Get token from: 1) param, 2) env, 3) file
    token = get_github_token(module)

    # Module logic here
    try:
        result = perform_github_operation(module, token)
        module.exit_json(**result)
    except Exception as e:
        module.fail_json(msg=str(e))

def get_github_token(module):
    """Resolve GitHub token from multiple sources"""
    # 1. Explicit parameter (highest priority)
    if module.params['github_token']:
        return module.params['github_token']

    # 2. Environment variable
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        return token

    # 3. Token file (./secrets/github_token)
    token_file = './secrets/github_token'
    if os.path.exists(token_file):
        with open(token_file, 'r') as f:
            return f.read().strip()

    module.fail_json(msg='GitHub token not provided. Use github_token parameter, GITHUB_TOKEN env var, or ./secrets/github_token file')

def perform_github_operation(module, token):
    """Perform the actual GitHub API operation"""
    # Implementation here
    pass

if __name__ == '__main__':
    run_module()
```

**APIs Used (Per Module):**

**1. workflow_trigger.py**
- Endpoint: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches`
- Method: POST
- Purpose: Trigger workflow_dispatch event
- Documentation: https://docs.github.com/rest/actions/workflows#create-a-workflow-dispatch-event
- Idempotent: NO (creates new run each time) - documented clearly
- Parameters: workflow (file), ref (branch), inputs (dict), correlation_id (optional)
- Returns: correlation_id (for tracking), status

**2. workflow_status.py**
- Endpoint: `GET /repos/{owner}/{repo}/actions/runs` (with correlation), then `GET /repos/{owner}/{repo}/actions/runs/{run_id}`
- Method: GET
- Purpose: Get workflow run status by correlation_id or run_id
- Documentation: https://docs.github.com/rest/actions/workflow-runs
- Idempotent: YES (read-only)
- Parameters: correlation_id OR run_id, repository
- Returns: run_id, status, conclusion, created_at, updated_at, html_url

**3. workflow_cancel.py**
- Endpoint: `POST /repos/{owner}/{repo}/actions/runs/{run_id}/cancel`
- Method: POST
- Purpose: Cancel a workflow run
- Documentation: https://docs.github.com/rest/actions/workflow-runs#cancel-a-workflow-run
- Idempotent: YES (canceling already-canceled is no-op)
- Parameters: run_id, repository
- Returns: changed (true if was running, false if already canceled/completed)

**4. workflow_logs.py**
- Endpoint: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs` then `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`
- Method: GET
- Purpose: Retrieve workflow execution logs
- Documentation: https://docs.github.com/rest/actions/workflow-jobs
- Idempotent: YES (read-only)
- Parameters: run_id, repository, dest (local path to save logs)
- Returns: logs_path (where logs saved), job_count

**5. pr_create.py**
- Endpoint: `GET /repos/{owner}/{repo}/pulls` (check existing), then `POST /repos/{owner}/{repo}/pulls` (create if not exists)
- Method: GET, POST
- Purpose: Create pull request (with duplicate checking for idempotency)
- Documentation: https://docs.github.com/rest/pulls/pulls#create-a-pull-request
- Idempotent: YES (checks if PR with same head/base exists before creating)
- Parameters: head (source branch), base (target branch), title, body, draft
- Returns: changed, pr_number, pr_url, pr_state

**6. pr_update.py**
- Endpoint: `GET /repos/{owner}/{repo}/pulls/{pull_number}` (get current), then `PATCH /repos/{owner}/{repo}/pulls/{pull_number}` (update if different)
- Method: GET, PATCH
- Purpose: Update pull request properties
- Documentation: https://docs.github.com/rest/pulls/pulls#update-a-pull-request
- Idempotent: YES (compares current state with desired state)
- Parameters: pr_number, title (optional), body (optional), state (optional), base (optional)
- Returns: changed, pr_number, pr_url, updated_fields[]

**7. pr_merge.py**
- Endpoint: `GET /repos/{owner}/{repo}/pulls/{pull_number}` (check mergeable), then `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge`
- Method: GET, PUT
- Purpose: Merge pull request
- Documentation: https://docs.github.com/rest/pulls/pulls#merge-a-pull-request
- Idempotent: YES (checks if already merged before attempting)
- Parameters: pr_number, merge_method (merge|squash|rebase), commit_title (optional), commit_message (optional)
- Returns: changed, merged, sha (merge commit SHA)

**8. pr_comment.py**
- Endpoint: `POST /repos/{owner}/{repo}/issues/{issue_number}/comments` OR `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` (for review comments)
- Method: POST
- Purpose: Add comment to pull request
- Documentation: https://docs.github.com/rest/pulls/comments
- Idempotent: CONFIGURABLE (force: always create, default: check for duplicate comment)
- Parameters: pr_number, body (comment text), force (default: false), path (optional, for inline comments), position (optional)
- Returns: changed, comment_id, comment_url

**9. pr_review.py**
- Endpoint: `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews`
- Method: POST
- Purpose: Submit pull request review
- Documentation: https://docs.github.com/rest/pulls/reviews#create-a-review-for-a-pull-request
- Idempotent: NO (each review submission is distinct) - force parameter required
- Parameters: pr_number, event (APPROVE|REQUEST_CHANGES|COMMENT), body (optional), force (required: true to confirm non-idempotent action)
- Returns: changed, review_id, review_state

**10. artifact_list.py**
- Endpoint: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`
- Method: GET
- Purpose: List artifacts for a workflow run
- Documentation: https://docs.github.com/rest/actions/artifacts#list-workflow-run-artifacts
- Idempotent: YES (read-only)
- Parameters: run_id, repository, name (optional filter)
- Returns: artifacts[] (id, name, size_in_bytes, created_at, expired)

**11. artifact_download.py**
- Endpoint: `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip`
- Method: GET
- Purpose: Download workflow artifact
- Documentation: https://docs.github.com/rest/actions/artifacts#download-an-artifact
- Idempotent: YES (checks if already downloaded with matching checksum)
- Parameters: artifact_id, repository, dest (local path), extract (default: true)
- Returns: changed (false if already downloaded), artifact_path, artifact_size

**12. artifact_delete.py**
- Endpoint: `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`
- Method: DELETE
- Purpose: Delete workflow artifact
- Documentation: https://docs.github.com/rest/actions/artifacts#delete-an-artifact
- Idempotent: YES (404 on already-deleted is success)
- Parameters: artifact_id, repository
- Returns: changed (false if already deleted)

**Data Structures:**

**galaxy.yml (Collection Metadata):**
```yaml
namespace: rstyczynski
name: github_api
version: 0.1.0
readme: README.md
authors:
  - Robert Styczynski (@rstyczynski)
description: Ansible Collection for GitHub API operations (workflows, PRs, artifacts)
license:
  - MIT
tags:
  - github
  - api
  - workflows
  - pullrequests
  - cicd
dependencies: {}
repository: https://github.com/rstyczynski/github_tricks
documentation: https://github.com/rstyczynski/github_tricks/tree/main/ansible_collection
homepage: https://github.com/rstyczynski/github_tricks
issues: https://github.com/rstyczynski/github_tricks/issues
```

**requirements.txt (Python Dependencies):**
```txt
requests>=2.28.0,<3.0.0
python-dateutil>=2.8.0,<3.0.0
urllib3>=1.26.0,<2.0.0
```

**meta/runtime.yml:**
```yaml
requires_ansible: '>=2.12.0'
```

**Error Handling:**

**Standard Error Categories:**

1. **Authentication Errors (401, 403)**
   - Missing token
   - Invalid token
   - Insufficient permissions
   - Rate limiting
   - Action: module.fail_json with clear message and required scopes

2. **Not Found Errors (404)**
   - Repository doesn't exist
   - Workflow doesn't exist
   - PR doesn't exist
   - Artifact doesn't exist
   - Action: For delete operations treat as success, for others fail with helpful message

3. **Validation Errors (422)**
   - Invalid parameters
   - Cannot merge PR (conflicts, checks failing)
   - Workflow dispatch not enabled
   - Action: module.fail_json with validation details from GitHub response

4. **Network Errors**
   - Timeout
   - Connection failure
   - DNS resolution
   - Action: Retry logic (configurable), then fail with network error details

5. **Rate Limit Errors (403 with X-RateLimit headers)**
   - Exceeded API rate limit
   - Action: module.fail_json with rate limit details (reset time, remaining calls)

**Error Handling Pattern:**

```python
def github_api_call(module, method, endpoint, token, data=None):
    """Standard GitHub API call with comprehensive error handling"""
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }

    url = f"{module.params['github_api_url']}/{endpoint.lstrip('/')}"

    try:
        if method == 'GET':
            response = requests.get(url, headers=headers, timeout=30)
        elif method == 'POST':
            response = requests.post(url, headers=headers, json=data, timeout=30)
        elif method == 'PATCH':
            response = requests.patch(url, headers=headers, json=data, timeout=30)
        elif method == 'PUT':
            response = requests.put(url, headers=headers, json=data, timeout=30)
        elif method == 'DELETE':
            response = requests.delete(url, headers=headers, timeout=30)

        # Check for rate limiting
        if response.status_code == 403 and 'X-RateLimit-Remaining' in response.headers:
            if response.headers['X-RateLimit-Remaining'] == '0':
                reset_time = response.headers.get('X-RateLimit-Reset', 'unknown')
                module.fail_json(
                    msg=f'GitHub API rate limit exceeded. Resets at {reset_time}',
                    rate_limit_remaining=0,
                    rate_limit_reset=reset_time
                )

        # Check for authentication errors
        if response.status_code == 401:
            module.fail_json(msg='Authentication failed. Check github_token validity.')

        if response.status_code == 403:
            module.fail_json(
                msg='Authorization failed. Token may lack required permissions.',
                github_message=response.json().get('message', 'No details')
            )

        # Check for not found (context-dependent handling)
        if response.status_code == 404:
            return None  # Caller decides how to handle

        # Check for validation errors
        if response.status_code == 422:
            errors = response.json().get('errors', [])
            module.fail_json(
                msg='GitHub API validation error',
                validation_errors=errors,
                github_message=response.json().get('message', 'No details')
            )

        # Raise for other errors
        response.raise_for_status()

        return response.json() if response.content else {}

    except requests.exceptions.Timeout:
        module.fail_json(msg=f'Request timeout after 30 seconds: {method} {url}')
    except requests.exceptions.ConnectionError as e:
        module.fail_json(msg=f'Connection error: {str(e)}')
    except requests.exceptions.RequestException as e:
        module.fail_json(msg=f'Request failed: {str(e)}')
```

### Implementation Approach

**Phase 1: Collection Bootstrap (Design Sprint 21 output)**
- Create collection skeleton with ansible-galaxy collection init
- Set up directory structure
- Create galaxy.yml with metadata
- Create requirements.txt with Python dependencies
- Set up .gitignore (.venv, *.pyc, __pycache__, etc.)
- Create stub README.md

**Phase 2: Core Module Implementation (Future Sprint)**
- Implement workflow_trigger.py
- Implement workflow_status.py
- Implement pr_create.py
- Implement artifact_download.py
- Each with full DOCUMENTATION/EXAMPLES/RETURN
- Each with error handling using standard pattern

**Phase 3: Testing Infrastructure (Future Sprint)**
- Create ansible-test sanity configuration
- Create unit tests with mocked GitHub API
- Create integration test targets
- Validate with ansible-test sanity/units/integration

**Phase 4: Remaining Modules (Future Sprint)**
- Implement remaining 8 modules
- Follow same pattern as Phase 2
- Add tests for each

**Phase 5: Roles and Advanced Features (Future Sprint)**
- Create workflow_orchestrator role
- Create pr_lifecycle role
- Add examples and playbooks

### Testing Strategy

**Level 1: Sanity Tests (ansible-test sanity)**

```bash
# From collection root
ansible-test sanity --docker default -v
```

**Validates:**
- Python syntax and style (PEP 8)
- Module documentation format (DOCUMENTATION/EXAMPLES/RETURN)
- Proper imports and dependencies
- FQCN usage throughout
- No deprecated Ansible features

**Success Criteria:**
- All sanity tests pass
- No import errors
- Documentation validates

**Level 2: Unit Tests (ansible-test units)**

```bash
ansible-test units --docker default -v
```

**Test Structure:**
```python
# tests/unit/plugins/modules/test_workflow_trigger.py
import json
from ansible.module_utils import basic
from ansible.module_utils._text import to_bytes
from ansible_collections.rstyczynski.github_api.plugins.modules import workflow_trigger
import pytest
from unittest.mock import patch, MagicMock

def test_workflow_trigger_success():
    """Test successful workflow trigger"""
    set_module_args({
        'github_token': 'test_token',
        'repository': 'owner/repo',
        'workflow': 'test.yml',
        'ref': 'main',
        'inputs': {'key': 'value'}
    })

    with patch('requests.post') as mock_post:
        mock_post.return_value = MagicMock(
            status_code=204,
            headers={}
        )

        with pytest.raises(AnsibleExitJson) as result:
            workflow_trigger.run_module()

        assert result.value.args[0]['changed'] == True
        assert 'correlation_id' in result.value.args[0]

def test_workflow_trigger_auth_failure():
    """Test authentication failure handling"""
    set_module_args({
        'github_token': 'invalid_token',
        'repository': 'owner/repo',
        'workflow': 'test.yml'
    })

    with patch('requests.post') as mock_post:
        mock_post.return_value = MagicMock(
            status_code=401,
            json=lambda: {'message': 'Bad credentials'}
        )

        with pytest.raises(AnsibleFailJson) as result:
            workflow_trigger.run_module()

        assert 'Authentication failed' in result.value.args[0]['msg']
```

**Success Criteria:**
- All unit tests pass
- Code coverage > 80%
- All error paths tested
- Idempotency logic validated

**Level 3: Integration Tests (ansible-test integration)**

```bash
ansible-test integration --docker default -v workflow_trigger
```

**Test Structure:**
```yaml
# tests/integration/targets/workflow_trigger/tasks/main.yml
---
- name: Test workflow trigger
  block:
    - name: Trigger test workflow
      rstyczynski.github_api.workflow_trigger:
        github_token: "{{ github_token }}"
        repository: "{{ test_repository }}"
        workflow: "test-workflow.yml"
        ref: "main"
        inputs:
          test_param: "integration_test"
      register: trigger_result

    - name: Verify trigger succeeded
      assert:
        that:
          - trigger_result.changed == true
          - trigger_result.correlation_id is defined

    - name: Check workflow status
      rstyczynski.github_api.workflow_status:
        github_token: "{{ github_token }}"
        repository: "{{ test_repository }}"
        correlation_id: "{{ trigger_result.correlation_id }}"
      register: status_result
      retries: 10
      delay: 5
      until: status_result.status in ['completed', 'cancelled', 'failure']

    - name: Verify workflow was found
      assert:
        that:
          - status_result.run_id is defined
```

**Success Criteria:**
- All integration tests pass against real GitHub API
- Or pass against mock GitHub API server (VCR.py recordings)
- Test both success and failure scenarios

**Level 4: Idempotency Tests**

```yaml
# tests/integration/targets/pr_create/tasks/idempotency.yml
- name: Create PR (first time)
  rstyczynski.github_api.pr_create:
    github_token: "{{ github_token }}"
    repository: "{{ test_repository }}"
    head: "test-branch"
    base: "main"
    title: "Test PR for idempotency"
  register: pr_create_1

- name: Create same PR (second time - should be idempotent)
  rstyczynski.github_api.pr_create:
    github_token: "{{ github_token }}"
    repository: "{{ test_repository }}"
    head: "test-branch"
    base: "main"
    title: "Test PR for idempotency"
  register: pr_create_2

- name: Verify idempotency
  assert:
    that:
      - pr_create_1.changed == true
      - pr_create_2.changed == false
      - pr_create_1.pr_number == pr_create_2.pr_number
```

**Success Criteria:**
- Running task twice: changed=true first time, changed=false second time
- Final state same regardless of starting state

### Integration Notes

**Dependencies:**

**From Previous Sprints:**
- Sprint 15-18: REST API endpoint knowledge (direct mapping to module implementations)
- Sprint 19: API operation summaries (inform module documentation)
- Sprint 20: Orchestration patterns (inform role design)
- Token authentication from ./secrets (precedence: param > env > file pattern)

**Ansible Framework:**
- Ansible Core >= 2.12.0
- ansible-test (for testing)
- Python 3.8+

**Development Tools:**
- Podman (for Molecule testing - future)
- Git (version control)
- Text editor with Python support

**Compatibility:**

**Integration with Existing Work:**
- Existing bash/curl scripts serve as **specification reference**
- Module implementations in Python replace bash scripts
- API endpoint URLs identical
- Error handling patterns adapted from scripts
- Token authentication pattern preserved (./secrets/github_token supported)

**Collection vs Scripts:**
- Collection provides: idempotency, check mode, comprehensive error handling, documentation
- Scripts provided: quick prototyping, direct API access
- Both can coexist: use collection for playbooks, scripts for ad-hoc testing

**Naming Alignment:**
```
Script                          → Module
trigger-workflow-curl.sh        → workflow_trigger
correlate-workflow-curl.sh      → workflow_status (correlation support)
fetch-logs-curl.sh              → workflow_logs
list-artifacts-curl.sh          → artifact_list
download-artifact-curl.sh       → artifact_download
```

**Reusability:**

**From Existing Scripts:**
- API endpoint knowledge (1:1 mapping)
- Parameter structures (translate to argument_spec)
- Error scenarios (translate to fail_json calls)
- Authentication pattern (token from ./secrets supported)

**For Future Work:**
- Modules can be imported by roles
- Roles can orchestrate multiple modules
- Collection can be published to Ansible Galaxy
- Can be dependency for other collections

### Documentation Requirements

**User Documentation:**

**1. Collection README.md**
- Getting started guide
- Installation instructions (ansible-galaxy collection install)
- Requirements (Python, tokens, permissions)
- Quick examples for each module category
- Links to detailed documentation

**2. Module Documentation (in each .py file)**
- DOCUMENTATION: Full parameter reference with types, defaults, required
- EXAMPLES: At least 3 examples per module (basic, advanced, error handling)
- RETURN: All return values documented with types and sample values

**3. Category Guides (docs/)**
- workflow_operations.md: Complete guide to workflow modules
- pr_operations.md: Complete guide to PR modules
- artifact_operations.md: Complete guide to artifact modules
- Each with playbook examples and common patterns

**4. Example Playbooks (docs/examples/)**
- trigger_workflow.yml: Trigger and monitor workflow
- create_pr.yml: Create PR from feature branch
- download_artifacts.yml: Download artifacts from workflow
- pr_lifecycle.yml: Complete PR workflow (create → review → merge)

**Technical Documentation:**

**1. Development Guide**
- Setting up development environment (.venv setup)
- Running tests (sanity, units, integration)
- Contributing guidelines
- Module development pattern

**2. Testing Documentation**
- How to run ansible-test
- How to write unit tests
- How to write integration tests
- Mock GitHub API for testing

**3. Architecture Documentation**
- Collection structure explanation
- Module design patterns
- Authentication flow
- Error handling framework

### Design Decisions

**Decision 1: Pure Python Modules vs Shell Wrappers**
**Decision Made:** Pure Python modules using `requests` library
**Rationale:**
- Better integration with ansible-test
- Easier to implement idempotency
- Proper error handling and validation
- Documentation auto-generation
- Community best practice
**Alternatives Considered:** Wrap existing bash/curl scripts
**Why Rejected:** Not idiomatic, harder to test, less maintainable

**Decision 2: requests vs PyGithub library**
**Decision Made:** Use `requests` library directly
**Rationale:**
- Lighter dependency (fewer transitive dependencies)
- More control over API calls
- Existing script knowledge maps directly
- Easier to debug
- PyGithub adds abstraction layer we don't need
**Alternatives Considered:** PyGithub library
**Why Rejected:** Heavier dependency, adds unnecessary abstraction

**Decision 3: Module Scope - Full vs Phased**
**Decision Made:** Design all 12 core modules, implement in phases
**Rationale:**
- Complete architecture visible from start
- Consistent interfaces across modules
- Can implement priority modules first
- Easier to estimate total effort
**Alternatives Considered:** Design only subset
**Why Rejected:** Would need redesign later, inconsistent interfaces

**Decision 4: Include Roles in Sprint 21**
**Decision Made:** Design collection with roles/ directory, implement roles in future sprint
**Rationale:**
- Modules are primary delivery
- Roles require modules to exist first
- Roles add complexity to testing
- Can be separate sprint after modules proven
**Alternatives Considered:** Include roles in Sprint 21
**Why Rejected:** Scope too large, modules must be stable first

**Decision 5: Authentication Token Precedence**
**Decision Made:** Parameter > Environment > File (./secrets)
**Rationale:**
- Explicit parameter highest priority (Ansible convention)
- Environment variable for CI/CD (common pattern)
- File support for existing ./secrets pattern (backwards compatible)
- Ansible Vault support via parameter (security best practice)
**Alternatives Considered:** Single source only
**Why Rejected:** Less flexible, breaks existing patterns

**Decision 6: Namespace Selection**
**Decision Made:** Use `rstyczynski` namespace
**Rationale:**
- Personal namespace appropriate for project
- Can publish to Ansible Galaxy under personal namespace
- Can transfer to `community` namespace later if needed
- No organizational approval required
**Alternatives Considered:** community namespace
**Why Rejected:** Requires community approval process, premature

**Decision 7: Non-Idempotent Module Handling**
**Decision Made:** Document clearly, require force parameter for destructive/non-idempotent operations
**Rationale:**
- Honest about limitations (Ansible Best Practice)
- force parameter makes intent explicit
- Prevents accidental repeated execution
- Standard Ansible pattern (file module, etc.)
**Alternatives Considered:** Try to fake idempotency
**Why Rejected:** Misleading, could cause confusion

### Open Design Questions

**None** - All design decisions resolved:

✅ Library choice: requests
✅ Module scope: 12 core modules designed
✅ Role inclusion: Future sprint
✅ Authentication: Multi-source with precedence
✅ Namespace: rstyczynski
✅ Idempotency: Honest documentation + force parameters
✅ Testing: ansible-test sanity/units/integration

Design is complete and ready for Product Owner review.

---

# Design Summary

## Overall Architecture

**Ansible Collection Structure:**
- 12 Ansible modules (Python) for GitHub API operations
- Comprehensive testing (sanity, unit, integration)
- Full documentation (DOCUMENTATION/EXAMPLES/RETURN per module)
- Role support directory (for future implementation)
- Standard Ansible Collection layout

**Technology Stack:**
- Python 3.8+ with requests library
- Ansible Core 2.12+
- ansible-test for validation
- Git for version control

**Integration Model:**
- Modules replace bash/curl scripts with idiomatic Ansible
- Existing scripts serve as specification reference
- Token authentication compatible with ./secrets pattern
- Can coexist with existing scripts

## Shared Components

**1. Authentication Resolution Function**
```python
def get_github_token(module):
    """Resolve token from: param > env > file"""
    # Shared by all modules
```

**2. GitHub API Call Wrapper**
```python
def github_api_call(module, method, endpoint, token, data=None):
    """Standard API call with comprehensive error handling"""
    # Shared by all modules
```

**3. Error Handling Patterns**
- 401/403: Authentication/authorization failures
- 404: Not found (context-dependent handling)
- 422: Validation errors
- 403 + rate limit headers: Rate limiting
- Network errors: Timeout, connection failures

**4. Module Documentation Pattern**
- DOCUMENTATION: Full parameter reference
- EXAMPLES: Minimum 3 examples per module
- RETURN: All return values documented

## Design Risks

**Risk 1: ansible-test Learning Curve**
- **Impact**: Medium - Could slow initial testing setup
- **Mitigation**: Use ansible-galaxy collection init skeleton, follow community examples
- **Status**: Manageable

**Risk 2: Integration Testing Complexity**
- **Impact**: Medium - Requires GitHub API access or sophisticated mocking
- **Mitigation**: Use VCR.py for API response recording, or dedicated test repository
- **Status**: Manageable

**Risk 3: Idempotency Challenges**
- **Impact**: Low - Some operations inherently non-idempotent
- **Mitigation**: Clear documentation, force parameters, check-first patterns
- **Status**: Resolved in design

**Risk 4: Scope Creep**
- **Impact**: Low - Collection could grow beyond core modules
- **Mitigation**: Phased implementation, clear module priority
- **Status**: Controlled by design

## Resource Requirements

**Development Environment:**
- Python 3.8+ with venv support
- Git
- Text editor with Python support
- Access to GitHub (for integration testing)

**Python Dependencies:**
- requests >= 2.28.0, < 3.0.0
- python-dateutil >= 2.8.0, < 3.0.0
- urllib3 >= 1.26.0, < 2.0.0

**Ansible Requirements:**
- Ansible Core >= 2.12.0
- ansible-test (included with Ansible)
- Podman (optional, for Molecule if roles implemented)

**GitHub Requirements:**
- Personal Access Token with scopes:
  - `repo` (for repository access)
  - `workflow` (for workflow dispatch)
  - `write:packages` (for artifact deletion)
- Test repository for integration tests

**Infrastructure:**
- None required (all local development)
- CI/CD optional (GitHub Actions can run ansible-test)

## Design Approval Status

**Status: Proposed**

This design is ready for Product Owner review. All feasibility questions answered, all technical decisions made, comprehensive specifications provided.

**Design Artifacts:**
- Complete collection architecture (12 modules specified)
- Module interface specifications with parameters and return values
- API endpoint mapping for all operations
- Testing strategy (sanity, unit, integration, idempotency)
- Error handling framework
- Documentation requirements
- Implementation roadmap

**Awaiting:** Product Owner approval to proceed to Construction phase (implementation).

**Note:** This is a DESIGN sprint - no implementation will occur until design is approved.
