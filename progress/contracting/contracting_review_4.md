# Contracting Review 4 - Sprint 15

Date: 2025-01-27
Sprint: Sprint 15
Backlog Items: GH-14, GH-15, GH-16
Status: Contracting phase completed

## Contract Overview

This contracting phase establishes the agreement between Product Owner and Implementor for Sprint 15 implementation.

### Scope Understanding

**Sprint 15 Objective:**
Validate existing workflow features (GH-2, GH-3, GH-5) using pure REST API with curl instead of `gh` CLI. Follow the pattern established in Sprint 9, using token authentication from `./secrets` directory. All implementations should use curl for API calls and provide comprehensive error handling.

**Backlog Items:**

1. **GH-14. Trigger workflow with REST API**
   - Validate GH-2 (Trigger GitHub workflow) using pure REST API with curl
   - Use `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` endpoint
   - Handle authentication with token from `./secrets` directory
   - Support workflow inputs
   - Provide proper error handling for invalid workflow IDs or authentication failures

2. **GH-15. Workflow correlation with REST API**
   - Validate GH-3 (Workflow correlation) using pure REST API with curl
   - Use `GET /repos/{owner}/{repo}/actions/runs` with filtering to retrieve run_id after workflow dispatch
   - Support UUID-based correlation
   - Handle pagination using Link headers
   - Filter by workflow, branch, actor, and status
   - Provide proper error handling
   - Use token authentication from `./secrets` directory

3. **GH-16. Fetch logs with REST API**
   - Validate GH-5 (Workflow log access after run) using pure REST API endpoints
   - Use `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` to retrieve workflow execution logs
   - Handle log streaming and aggregation
   - Support multiple jobs per workflow run
   - Handle authentication with token from `./secrets` directory
   - Provide proper error handling for logs not yet available or invalid job IDs

### Documentation Reviewed

The Implementor has reviewed and confirmed understanding of:

1. **BACKLOG.md** - Project backlog and Sprint 15 requirements (GH-14, GH-15, GH-16)
2. **PLAN.md** - Implementation plan showing Sprint 15 in "Proposed" status
3. **rules/generic/GENERAL_RULES.md** - Cooperation flow, chapter editing rules, file ownership policies
4. **rules/github_actions/GitHub_DEV_RULES.md** - Testing guidelines, definition of done, tools selection
5. **rules/generic/GIT_RULES.md** - Semantic commit message requirements
6. **rules/generic/PRODUCT_OWNER_GUIDE.md** - Phase transitions and workflow procedures
7. **progress/** directory - Historical sprint work (Sprints 0-14 completed)

### Rules Compliance Confirmation

The Implementor confirms compliance with all rules:

**Content Ownership:**
- NEVER modify `PLAN.md` or status tokens
- NEVER edit other sprints' chapters
- Only edit: Design, Implementation Notes, Proposed changes, More information needed

**Development Process:**
- Follow Contracting → Inception → Elaboration → Construction phases
- Wait for design approval before implementation
- Use prescribed file templates for progress documentation

**Testing Requirements:**
- Test with `actionlint` for GitHub syntax validation
- Test with `act` locally where applicable
- Test on real GitHub infrastructure with `workflow_dispatch`
- Test happy paths, special cases, and illegal parameter values

**Git Requirements:**
- Use semantic commit messages
- Follow conventions from https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716

**Tools:**
- Use `podman` for containers if needed
- Use official GitHub REST API endpoints with curl
- Use token authentication from `./secrets` directory
- Follow pattern established in Sprint 9

### Required Changes

No changes required to existing documentation. All files are properly structured.

### Work Summary for Sprint 15

**Planned Deliverables:**

1. **Design Phase:**
   - `progress/sprint_15_design.md` - Design document for GH-14, GH-15, GH-16
   - Design must include feasibility analysis of GitHub REST API capabilities
   - Design must reference existing implementations (GH-2, GH-3, GH-5) for compatibility

2. **Implementation Phase:**
   - REST API scripts using curl for workflow triggering (GH-14)
   - REST API scripts using curl for workflow correlation (GH-15)
   - REST API scripts using curl for log retrieval (GH-16)
   - All scripts must use token authentication from `./secrets` directory
   - Comprehensive error handling for all scenarios

3. **Testing Phase:**
   - `actionlint` syntax validation (if workflows are modified)
   - Real GitHub infrastructure testing
   - Comprehensive test coverage (happy paths, edge cases, invalid inputs)
   - Error handling validation

4. **Documentation Phase:**
   - `progress/sprint_15_implementation.md` - Implementation notes
   - User documentation (README updates)
   - Simple usage examples
   - Test execution instructions

**Definition of Done:**
- ✓ Requirements implemented
- ✓ GitHub syntax confirmed by `actionlint` (if applicable)
- ✓ Implementation tested on real GitHub infrastructure
- ✓ Design documented
- ✓ User documentation in place
- ✓ Simple example in place

### Implementor Readiness

**Status: READY TO PROCEED**

The Implementor:
- Understands all project rules and constraints
- Confirms compliance with all documentation standards
- Is prepared to follow prescribed phase transitions
- Ready to enter Inception phase upon Product Owner instruction

### Next Steps

1. Product Owner issues Inception phase command
2. Implementor enters Inception phase to detail understanding
3. Implementor enters Elaboration phase to create design
4. Product Owner reviews and approves design
5. Implementor enters Construction phase for implementation

## Contract Acceptance

This contract establishes mutual understanding of:
- Sprint 15 scope and requirements
- Applicable rules and constraints
- Deliverables and success criteria
- Communication and approval processes

**Implementor:** Confirmed and accepted
**Product Owner:** Awaiting acceptance

