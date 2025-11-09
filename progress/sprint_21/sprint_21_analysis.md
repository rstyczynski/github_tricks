# Sprint 21 - Analysis

Status: Complete

## Sprint Overview

Sprint 21 represents a strategic shift from bash/curl REST API scripts to infrastructure-as-code automation using Ansible. This Sprint focuses on **designing** (not implementing) an Ansible Collection that provides idiomatic, reusable, and testable modules for GitHub API operations.

**Sprint Goal**: Design an Ansible Collection architecture that:
1. Handles GitHub API operations (workflows, PRs, artifacts, logs, reviews)
2. Provides idempotent, well-tested Ansible modules
3. Leverages existing REST API knowledge from Sprints 0-20
4. Follows Ansible Best Practices without exceptions
5. Supports authentication via tokens (reuse `./secrets` pattern)
6. Enables declarative infrastructure-as-code workflows

**Nature**: This is a **DESIGN sprint**, not an implementation sprint. The focus is on:
- Collection architecture and structure
- Module interfaces and contracts
- Testing strategy (Molecule + ansible-test)
- Feasibility analysis against GitHub API
- Documentation plan
- Risk assessment

**Deliverable**: Comprehensive design document ready for Product Owner approval before any implementation begins.

## Backlog Items Analysis

### GH-29. Design Ansible Collection to handle GitHub API

**Requirement Summary:**

Create design for an Ansible Collection that handles:
- **Pull requests**: create, list, update, merge
- **Comments and reviews**: add, update, delete comments; submit reviews
- **Approvals**: approve/request changes on PRs
- **Workflows**: trigger, correlate, cancel, monitor
- **Artifacts**: list, download, delete
- **Logs**: retrieve, stream

The requirement states "Design Ansible Collection" - this is explicitly a design-focused sprint requiring architecture, interface specifications, and feasibility validation before any code is written.

**Technical Approach:**

**1. Collection Structure Decision**

Ansible Collections can contain:
- **Modules**: Core automation units (likely primary approach)
- **Roles**: Pre-packaged task sequences
- **Plugins**: Extend Ansible functionality (inventory, lookup, filter)

**Recommended Architecture:**
```
github_api/
├── plugins/
│   └── modules/          # GitHub operation modules
│       ├── workflow_trigger.py
│       ├── workflow_status.py
│       ├── workflow_cancel.py
│       ├── workflow_logs.py
│       ├── pr_create.py
│       ├── pr_update.py
│       ├── pr_merge.py
│       ├── pr_comment.py
│       ├── pr_review.py
│       ├── artifact_list.py
│       ├── artifact_download.py
│       └── artifact_delete.py
├── roles/
│   ├── workflow_orchestrator/  # High-level workflow automation
│   └── pr_lifecycle/           # PR creation to merge automation
├── tests/
│   ├── unit/
│   ├── integration/
│   └── sanity/
├── docs/
├── meta/
│   └── runtime.yml
├── galaxy.yml
└── requirements.txt
```

**2. Module Naming Convention**

Follow Ansible FQCN pattern:
- `yournamespace.github_api.workflow_trigger`
- `yournamespace.github_api.pr_create`
- `yournamespace.github_api.artifact_download`

**Namespace Options:**
- `rstyczynski` (personal namespace)
- `community` (if publishing to Ansible Galaxy)
- Custom organization name

**3. Module Interface Design**

Each module follows Ansible argument_spec pattern with validation:

```python
# Example: workflow_trigger module
argument_spec = dict(
    github_token=dict(type='str', required=True, no_log=True),
    repository=dict(type='str', required=True),  # owner/repo
    workflow=dict(type='str', required=True),    # workflow file name
    ref=dict(type='str', default='main'),
    inputs=dict(type='dict', default={}),
    correlation_id=dict(type='str', required=False),  # auto-generate if not provided
)
```

**Module Return Values:**
```python
# Standardized return across all modules
result = dict(
    changed=True/False,
    run_id='123456',              # For workflow operations
    correlation_id='uuid',        # For tracking
    status='success',
    message='Workflow triggered successfully',
    api_response={},              # Full GitHub API response
)
```

**4. Authentication Strategy**

**Options:**
1. **Token per task**: Pass token to each module call (flexible but repetitive)
2. **Environment variable**: Lookup from GITHUB_TOKEN env (conventional)
3. **Token file**: Read from `./secrets` directory (existing pattern)
4. **Ansible Vault**: Encrypted token in vars (secure)

**Recommended**: Support multiple methods with precedence:
1. Explicit `github_token` parameter (highest priority)
2. `GITHUB_TOKEN` environment variable
3. Token file at `./secrets/github_token` (existing pattern)

**5. Error Handling Framework**

Each module must handle:
- Authentication failures (401/403)
- Rate limiting (403 with X-RateLimit headers)
- Not found errors (404)
- Validation errors (422)
- Network failures
- Timeout scenarios

**Standard Error Structure:**
```python
module.fail_json(
    msg='Workflow trigger failed',
    status_code=422,
    error_type='ValidationError',
    github_message='...',
    documentation_url='...'
)
```

**6. Idempotency Design**

Critical for Ansible compliance:

**Workflow Operations:**
- `workflow_trigger`: Not idempotent (creates new run each time) - document clearly
- `workflow_cancel`: Idempotent (canceling already-canceled is no-op)
- `workflow_logs`: Idempotent (read-only operation)

**PR Operations:**
- `pr_create`: Check if PR already exists (idempotent)
- `pr_update`: Compare current state with desired state (idempotent)
- `pr_merge`: Check if already merged (idempotent)
- `pr_comment`: Check if comment exists before adding (configurable)

**Artifact Operations:**
- `artifact_list`: Idempotent (read-only)
- `artifact_download`: Idempotent (use checksums to avoid re-download)
- `artifact_delete`: Idempotent (404 on already-deleted is success)

**7. Python Dependencies**

Required libraries:
```
# requirements.txt
requests>=2.28.0,<3.0.0         # HTTP client
PyGithub>=2.1.0,<3.0.0          # GitHub API library (optional, for higher-level ops)
python-dateutil>=2.8.0          # Date parsing
urllib3>=1.26.0,<2.0.0          # URL handling
```

**Virtual Environment:**
- Location: `.venv` in project root (Ansible BP requirement)
- Never create in home directory
- Add to `.gitignore`

**8. Testing Strategy - Critical for Collection**

**Level 1: Sanity Tests (ansible-test)**
```bash
ansible-test sanity --docker default -v
```
- Python syntax validation
- Documentation validation
- Module imports check
- FQCN compliance

**Level 2: Unit Tests**
```bash
ansible-test units --docker default -v
```
- Mock GitHub API responses
- Test argument validation
- Test error handling paths
- Test idempotency logic

**Level 3: Integration Tests**
```bash
ansible-test integration --docker default -v
```
- Test against real GitHub API (or mock server)
- End-to-end workflow tests
- Multi-module interaction tests

**Level 4: Molecule Tests (for roles)**
```bash
molecule test
```
- Test roles in containers (Podman)
- Verify idempotency
- Test different scenarios

**9. Reusing Existing Scripts**

**Option A: Pure Python Rewrite**
- Modules implemented in Python using `requests` or `PyGithub`
- Clean, Ansible-native approach
- More work but better long-term

**Option B: Shell Module Wrappers**
- Modules call existing bash/curl scripts
- Quick path, leverages existing work
- Less idiomatic, harder to test

**Recommendation**: Option A (Pure Python)
- Better testing with ansible-test
- Proper error handling and validation
- Idempotency easier to implement
- Documentation auto-generation works better
- Existing scripts provide specification/reference

**10. Documentation Requirements**

Each module needs:
```python
DOCUMENTATION = r'''
---
module: workflow_trigger
short_description: Trigger GitHub workflow via workflow_dispatch
description:
    - Triggers a GitHub Actions workflow using the workflow_dispatch event
    - Returns run_id and correlation_id for tracking
options:
    github_token:
        description: GitHub personal access token
        required: true
        type: str
    repository:
        description: Repository in owner/repo format
        required: true
        type: str
    # ... more options
notes:
    - This module is NOT idempotent (creates new run each time)
    - Requires workflow_dispatch trigger in workflow file
requirements:
    - requests >= 2.28.0
author:
    - Your Name (@github_handle)
'''

EXAMPLES = r'''
- name: Trigger workflow with inputs
  yournamespace.github_api.workflow_trigger:
    github_token: "{{ github_token }}"
    repository: "owner/repo"
    workflow: "deploy.yml"
    ref: "main"
    inputs:
      environment: "production"
      version: "1.2.3"
'''

RETURN = r'''
run_id:
    description: GitHub workflow run ID
    returned: success
    type: int
    sample: 123456789
correlation_id:
    description: Correlation UUID for tracking
    returned: success
    type: str
    sample: "550e8400-e29b-41d4-a716-446655440000"
'''
```

**Dependencies:**

**Foundational Knowledge:**
- Sprint 15-18: REST API implementation (trigger, correlate, logs, artifacts, PRs) - **Complete**
- Sprint 19: API operation summarization - **Complete**
- Sprint 20: End-to-end orchestration - **Complete**
- Ansible Best Practices: rules/ansible/ANSIBLE_BEST_PRACTICES.md - **Reviewed**

**Technical Prerequisites:**
- Python 3.8+ (Ansible requirement)
- Ansible Core 2.12+ (for ansible-test)
- Podman (for Molecule testing)
- GitHub token (./secrets pattern)
- Knowledge of GitHub API endpoints (established)

**No Blockers**: All prerequisites are met.

**Testing Requirements:**

**Functional Testing:**
1. Each module must pass ansible-test sanity
2. Each module must pass ansible-test units
3. Integration tests against GitHub API
4. Molecule tests for roles (if roles created)
5. Idempotency tests (run twice, verify `changed=false` on second run)
6. Error scenario tests (invalid tokens, missing repos, rate limits)

**Test Data:**
- Use test repository (not production)
- Mock API responses for unit tests
- Document test environment setup

**Copy-Paste Execution:**
- All test commands documented
- Setup instructions for test environment
- Expected outputs documented

**Risks/Concerns:**

1. **Complexity**: Ansible Collection development is more complex than bash scripts
   - Mitigation: Start with 2-3 core modules, expand gradually

2. **Testing Overhead**: ansible-test requires specific structure and Docker
   - Mitigation: Follow Ansible Collection skeleton template from the start

3. **Idempotency Challenges**: Some GitHub operations are inherently non-idempotent
   - Mitigation: Document clearly, provide force parameters where appropriate

4. **GitHub API Rate Limiting**: Excessive testing may hit rate limits
   - Mitigation: Use mocks for unit tests, real API only for integration tests

5. **Learning Curve**: Team may need Ansible development training
   - Mitigation: Comprehensive documentation, examples, reference to existing modules

6. **Dependency Management**: PyGithub vs raw requests trade-off
   - Mitigation: Start with requests (lighter), evaluate PyGithub later

7. **Token Security**: Must follow Ansible's no_log best practices
   - Mitigation: Strictly follow Ansible BP for sensitive data handling

**Compatibility Notes:**

**Integration with Existing Work:**
- Existing bash/curl scripts serve as **specification reference**
- REST API patterns from Sprints 15-20 directly map to module implementations
- Token authentication from `./secrets` can be reused
- Correlation mechanism (UUID-based) should be preserved in modules

**Code Reuse:**
- Existing scripts won't be directly called (not Ansible-idiomatic)
- API endpoint knowledge transfers 1:1 to Python implementations
- Error handling patterns can be adapted
- Testing approaches (parameter validation, error cases) transfer

**New Development Paradigm:**
- Shift from imperative scripts to declarative Ansible
- Shift from bash to Python
- Add comprehensive testing framework
- Add documentation standards
- Add idempotency requirements

---

## Overall Sprint Assessment

**Feasibility:** **High**

This Sprint is highly feasible because:
1. **GitHub API Knowledge**: 20 sprints of GitHub API experience provides comprehensive foundation
2. **API Completeness**: All required GitHub API endpoints are available and documented
3. **Ansible Collection Framework**: Well-documented Ansible process with templates and tools
4. **Testing Tools**: ansible-test and Molecule provide complete testing infrastructure
5. **Reference Implementations**: Existing scripts provide clear specifications
6. **No API Limitations**: GitHub API supports all required operations

**Estimated Complexity:** **Moderate to Complex**

Complexity assessment:
- **Collection Structure**: **Moderate** - Well-defined templates available
- **Module Development**: **Moderate** - Ansible module API is well-documented
- **Testing Infrastructure**: **Complex** - ansible-test requires specific setup, Molecule learning curve
- **Idempotency Implementation**: **Moderate to Complex** - Some operations naturally non-idempotent
- **Documentation**: **Moderate** - Standard format but comprehensive coverage required

Overall **Moderate to Complex** due to:
- New technology stack (Ansible Collection development vs bash scripting)
- Comprehensive testing requirements (sanity, unit, integration, Molecule)
- Idempotency requirements challenging for some operations
- Module documentation standards extensive
- Virtual environment and dependency management

Not more complex because:
- GitHub API already understood (20 sprints of experience)
- Ansible Collection skeleton templates available
- ansible-test provides automated validation
- Large community with examples and documentation
- Clear Ansible Best Practices document available

**Prerequisites Met:** **Yes**

All prerequisites are satisfied:
- ✅ 20 sprints of GitHub API knowledge (Sprints 0-20 complete)
- ✅ GitHub API endpoints documented and tested
- ✅ Ansible Best Practices document available (rules/ansible/)
- ✅ GitHub token authentication pattern established
- ✅ Testing tools available (ansible-test, Molecule, Podman)
- ✅ Python environment manageable
- ✅ Design-first approach (this is design sprint)

**Open Questions:**

**None requiring immediate clarification**, but design decisions needed:

1. **Namespace Selection**: Which namespace to use for collection?
   - Recommendation: Use personal namespace initially, community later
   - Not a blocker: Can be decided during design

2. **Dependency Choice**: PyGithub vs raw requests?
   - Recommendation: Start with requests (lighter, more control)
   - Not a blocker: Design phase will evaluate both

3. **Module Scope**: Should we design ALL modules or start with subset?
   - Recommendation: Design architecture for all, detailed specs for core 5-6 modules
   - Not a blocker: Design phase determines scope

4. **Role Design**: Should collection include pre-built roles or modules only?
   - Recommendation: Start with modules, add roles in future sprint
   - Not a blocker: Design phase makes recommendation

These are design decisions to be made during Elaboration phase, not blockers for proceeding.

## Recommended Design Focus Areas

1. **Collection Architecture**
   - Directory structure and organization
   - Namespace selection and naming conventions
   - Module categorization and grouping
   - Plugin vs role vs module decisions
   - Version strategy (galaxy.yml)

2. **Module Interface Contracts**
   - Argument specifications for each module category
   - Return value standards
   - Error handling conventions
   - Authentication parameter design
   - Common parameters (repository, token, etc.)

3. **Authentication Design**
   - Token source precedence (param > env > file)
   - Integration with ./secrets pattern
   - Ansible Vault support
   - no_log compliance for security

4. **Idempotency Strategy**
   - Idempotency matrix (which modules are/aren't idempotent)
   - Check-before-action patterns
   - Force parameter design
   - changed vs unchanged detection logic

5. **Testing Infrastructure**
   - ansible-test sanity requirements
   - Unit test structure and mocking strategy
   - Integration test approach (real vs mock GitHub API)
   - Molecule configuration for roles
   - CI/CD integration plan

6. **Error Handling Framework**
   - GitHub API error mapping to Ansible failures
   - Rate limiting detection and handling
   - Retry logic for transient failures
   - User-friendly error messages
   - Debug output design

7. **Documentation Standards**
   - DOCUMENTATION string format
   - EXAMPLES comprehensiveness
   - RETURN value documentation
   - Role README structure
   - Collection README content

8. **Python Dependency Management**
   - requirements.txt content
   - Python version compatibility
   - Virtual environment setup process
   - Dependency version pinning strategy

9. **Module Priority and Phasing**
   - Which modules for Sprint 21 (design only)
   - Which modules for future implementation sprints
   - Core vs optional module classification
   - Roadmap for collection growth

## Readiness for Design Phase

**Confirmed Ready**

All prerequisites met:
- ✅ Sprint 21 identified and active (Status: Progress in PLAN.md)
- ✅ Backlog Item GH-29 analyzed and understood
- ✅ Previous Sprint context reviewed (Sprints 0-20, especially 15-20)
- ✅ Ansible Best Practices reviewed and understood
- ✅ GitHub API knowledge comprehensive (20 sprints)
- ✅ No technical blockers identified
- ✅ Feasibility confirmed (High)
- ✅ Complexity assessed (Moderate to Complex, manageable)
- ✅ Dependencies verified (all knowledge available)
- ✅ Testing tools identified (ansible-test, Molecule)
- ✅ No open questions requiring Product Owner clarification

**Integration Context Understood:**
- Sprint 15: REST API trigger, correlation, log retrieval - serves as module spec
- Sprint 16: Artifact listing - serves as module spec
- Sprint 17: Artifact downloading - serves as module spec
- Sprint 13-14: PR operations - serves as module spec
- Sprint 19: API summarization - provides interface documentation
- Sprint 20: Orchestration - informs role design
- Ansible Best Practices: Comprehensive ruleset for development

**Ready to proceed to Elaboration Phase** for detailed design of:
1. Complete collection structure and organization
2. Detailed module interface specifications for all GitHub operations
3. Authentication and security design
4. Idempotency strategy for each module type
5. Comprehensive testing infrastructure design
6. Error handling framework
7. Documentation standards and templates
8. Python dependency specifications
9. Implementation roadmap and phasing

---

**Next Step**: Create `progress/sprint_21/sprint_21_design.md` with comprehensive technical specifications for the Ansible Collection, including:
- Collection directory structure
- Module interface specifications
- Authentication design
- Testing infrastructure
- Documentation templates
- Feasibility confirmation against GitHub API and Ansible Collection requirements
