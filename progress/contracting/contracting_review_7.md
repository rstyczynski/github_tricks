# Contracting Review 7

Date: 2025-01-27
Sprint: 18
Backlog Item: GH-25. Delete workflow artifacts

## Agent Cooperation Specification (ACS) Confirmation

I have reviewed and understood all project documents and rules:

### 1. Project Scope (BACKLOG.md)

**Project:** GitHub Workflow experimentation and validation
**Status:** Progress (Sprint 18)

**Current Focus:** Sprint 18 - GH-25. Delete workflow artifacts
- Implement REST API-based artifact deletion using curl
- Follow pattern established in Sprint 15
- Support deleting individual artifacts or all artifacts for a run
- Validate deletion permissions
- Use token authentication from `./secrets` directory
- Comprehensive error handling for scenarios such as artifacts already deleted or insufficient permissions

**Project History:**
- Sprint 17 (Done): GH-24. Download workflow artifacts - implemented
- Sprint 16 (Done): GH-23. List workflow artifacts - implemented
- Sprint 15 (Done): REST API implementations for trigger, correlation, and logs
- Sprint 14 (Done): PR merge and comments
- Sprint 13 (Done): PR create, list, update
- Sprint 12 (Failed): Scheduling workflows (not supported by GitHub)
- Sprint 11 (Done): Cancel workflow operations

### 2. Implementation Plan (PLAN.md)

**Sprint 18 Status:** Planned

**Sprint 18 Scope:**
- GH-25. Delete workflow artifacts
- Extend workflow management capabilities with artifact deletion operations
- Implement REST API-based artifact deletion using curl
- Follow the pattern established in Sprint 15
- Use token authentication from `./secrets` directory
- Support deleting individual artifacts or all artifacts for a run
- Validate deletion permissions
- Comprehensive error handling for scenarios such as artifacts already deleted or insufficient permissions

### 3. Technology Constraints (GitHub_DEV_RULES.md)

**Testing Guidelines:**
1. Prefer `act` to test functionality locally
2. Workflows tested on real GitHub infrastructure with `workflow_dispatch`
3. Tests for happy paths and special cases
4. Tests verify behavior in out-of-context cases (e.g., illegal parameter values)

**Definition of Done:**
1. Requirements implemented
2. GitHub syntax confirmed by `actionlint`
3. Implementation tested with `act` and/or real GitHub infrastructure
4. Design documented
5. User documentation in place
6. Simple example in place

**Tools and Libraries:**
1. Always use official GitHub access libraries
2. May use Ansible collection if available from GitHub

### 4. Cooperation Rules (GENERAL_RULES.md)

**Role:** Implementor within Agentic Programming framework

**Ownership:**
- **Product Owner owns:** PLAN.md, status fields, BACKLOG.md
- **Implementor owns:** Design, Implementation Notes, Proposed changes, More information needed

**Document Structure:**
- Design: `progress/sprint_${no}_design.md`
- Implementation: `progress/sprint_${no}_implementation.md`
- Feedback: `progress/sprint_${no}_feedback.md`
- Open Questions: `progress/sprint_${no}_openquestions.md`
- Analysis: `progress/sprint_${no}_analysis.md`
- Chat summaries: `progress/<phase>_sprint_${no}_chat_${cnt}.md`

**Prohibited Actions:**
- Do NOT modify PLAN.md
- Do NOT modify status tokens
- Do NOT modify Test data
- Do NOT edit other Sprints' design chapters

**Allowed Actions:**
- Edit Design chapter for active Sprint
- Edit Implementation Notes (excluding status tokens)
- Add to Proposed changes
- Add to More information needed
- Update PROGRESS_BOARD.md with backlog item status (allowed extension)

**State Machine Flow:**
- Sprint: Planned → Progress → Designed → Implemented → Tested → Done
- Design: Proposed → Accepted → Done
- Feedback: Proposed → Accepted/Postponed/Rejected

### 5. Coding Standards (GIT_RULES.md)

**Git Rules:**
- Use semantic commit messages: https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716
- Commit format examples:
  - `feat: add new feature`
  - `fix: resolve bug`
  - `docs: update documentation`
  - `test: add tests`
  - `refactor: improve code structure`

**Markdown Rules:**
- No indentation under chapters (except enumerations)
- Always add empty line before code blocks and enumerations
- Always add empty line after chapters and list headers
- Follow Markdown linting rules

### 6. Progress Board Rules

**PROGRESS_BOARD.md Management:**
- Update Sprint status when phase starts
- Update Backlog Item status when work begins
- Allowed statuses for Backlog Items:
  - `proposed` → `under_analysis` → `analysed` → `under_design` → `designed` → `under_construction` → `implemented` → `tested` → `failed`

## Required Changes for Sprint 18

Based on the requirements, I will need to:

1. **Inception Phase:**
   - Analyze GH-25 requirements
   - Review Sprint 17 artifacts to understand pattern
   - Create `progress/sprint_18_analysis.md`
   - Update PROGRESS_BOARD.md: Sprint 18 → `under_analysis`, GH-25 → `under_analysis`

2. **Elaboration Phase:**
   - Design artifact deletion implementation
   - Document REST API endpoints and usage
   - Create diagrams for deletion flow
   - Handle permission validation
   - Create `progress/sprint_18_design.md`
   - Update PROGRESS_BOARD.md: Sprint 18 → `under_design`, GH-25 → `under_design`

3. **Construction Phase:**
   - Implement deletion script following Sprint 15 pattern
   - Add support for individual and bulk deletions
   - Implement error handling
   - Create user documentation and examples
   - Test with `act` and/or real GitHub infrastructure
   - Create `progress/sprint_18_implementation.md`
   - Update PROGRESS_BOARD.md: Sprint 18 → `under_construction`, GH-25 → `under_construction`

4. **Testing:**
   - Test deleting single artifact
   - Test deleting all artifacts for a run
   - Test error scenarios (already deleted, insufficient permissions, invalid IDs)
   - Update PROGRESS_BOARD.md: GH-25 → `tested` (or `failed` if issues)

## Clarification Questions

None at this time. The requirements are clear based on:
- Sprint 17 implementation provides pattern to follow
- Sprint 16 established artifact listing pattern
- Sprint 15 established REST API with curl pattern
- Backlog item GH-25 provides comprehensive requirements
- GitHub API documentation available for reference

## Summary

**What has to be done:**

Sprint 18 aims to extend workflow management capabilities by implementing artifact deletion functionality. This completes the artifact management lifecycle (list, download, delete) and follows the REST API pattern established in Sprint 15.

**Key deliverables:**
1. Shell script using curl to delete artifacts via REST API
2. Support for deleting individual artifacts by artifact_id
3. Support for deleting all artifacts for a given run_id
4. Proper permission validation before deletion
5. Comprehensive error handling for common failure scenarios
6. User documentation with usage examples
7. Functional tests demonstrating success paths and error handling

**Technical approach:**
- Use `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}` endpoint
- Token authentication from `./secrets` directory
- Follow curl-based pattern from Sprint 15
- Handle HTTP status codes (204 success, 404 not found, 403 permission denied)
- Implement bulk deletion by listing artifacts first (using Sprint 16's script)

## Readiness Confirmation

✓ I confirm understanding of:
- Project scope and current Sprint 18 objectives
- Technology constraints and testing requirements
- Cooperation rules and document ownership
- Coding standards and git rules
- Progress board management
- Definition of done criteria

✓ I am ready to proceed with:
1. Inception Phase: Analyze Sprint 18 requirements
2. Elaboration Phase: Design artifact deletion implementation
3. Construction Phase: Implement, test, and document

All rules are clear. No blockers identified. Ready to proceed with Sprint 18 implementation.

