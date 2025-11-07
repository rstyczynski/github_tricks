# Contracting Review 8

## Summary

I have reviewed all foundation documents, implementation plans, rules, and previous Sprint artifacts to understand this GitHub workflow management project. This is a RUP-based development environment where I will act as an Implementor working with the Product Owner through structured phases: Contracting, Inception, Elaboration, Construction, and Documentation.

## Understanding Confirmed

### Project Scope: Yes

**Project Overview**: GitHub Workflow Management System
- Experimenting with GitHub workflows to validate behavior
- Building tools to trigger, monitor, correlate, and manage GitHub workflow executions
- Using GitHub REST API, CLI (`gh`), and curl-based implementations
- Current focus: Sprint 18 - Artifact deletion functionality (GH-25)

**Technology Stack**:
- GitHub REST API v3
- curl for HTTP requests
- Token authentication from `./secrets` directory
- Shell scripts for automation
- Podman for containerization (if needed)

### Implementation Plan: Yes

**Current Status** (from `PLAN.md`):
- Sprint 18: Status = "Planned"
- Backlog Item: GH-25 (Delete workflow artifacts)
- Previous Sprints: 0-17 completed with mixed statuses (Done/Failed)
- Pattern established in Sprint 15-17 for REST API implementations

**Sprint 18 Requirements**:
- Implement REST API-based artifact deletion using curl
- Follow pattern from Sprint 15-17
- Token authentication from `./secrets` directory
- Support deleting individual artifacts or all artifacts for a run
- Validate deletion permissions
- Comprehensive error handling (artifacts already deleted, insufficient permissions)
- API endpoint: `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`

### General Rules: Yes - UNDERSTOOD

From `rules/GENERAL_RULES_v3.md`:

**Key Points**:
1. I act as Implementor; Product Owner defines requirements
2. Work is organized in Sprints in `PLAN.md` referencing Backlog Items in `BACKLOG.md`
3. Each Sprint has separate documentation files in `progress/` directory:
   - `sprint_${no}_design.md` - Design (my responsibility)
   - `sprint_${no}_implementation.md` - Implementation notes (my responsibility)
   - `sprint_${no}_tests.md` - Functional tests (my responsibility)
   - `sprint_${no}_feedback.md` - Proposed changes (if needed)
   - `sprint_${no}_openquestions.md` - Clarification requests (if needed)

**State Machines**:
- Sprint Status: Planned → Progress → Designed → Implemented → Tested → Done
- Design Status: Proposed (set by me) → Accepted/Rejected (set by PO) → Done
- Feedback/Questions: Proposed → Accepted/Postponed/Rejected

**Editing Rules**:
- NEVER modify `PLAN.md` or `BACKLOG.md`
- NEVER modify status tokens (owned by Product Owner)
- ALLOWED to edit: Design, Implementation Notes, Proposed changes, More information needed
- Always use Markdown with no indentation (except enumerations)
- Empty line before code blocks and after chapter headers

### Git Rules: Yes - UNDERSTOOD

From `rules/GIT_RULES_v1.md`:

**Semantic Commit Messages Required**:
- Format: `type: (context) description`
- Example: `docs: (sprint-18) add artifact deletion design`
- NOT: `docs(sprint-18): ...` (forbidden - no text before `:`)

**Types**: feat, fix, docs, style, refactor, test, chore

### Development Rules: Yes - UNDERSTOOD

From `rules/GitHub_DEV_RULES_v4.md`:

**Key Requirements**:
1. Expert-level GitHub knowledge required
2. Testing: Prefer `act` locally, use `workflow_dispatch` for real GitHub testing
3. Tests cover happy paths, special cases, and illegal parameters
4. Always use official GitHub libraries/APIs
5. Syntax validation with `actionlint`

**Definition of Done**:
- Requirements implemented
- GitHub syntax confirmed by actionlint (if applicable)
- Tested with act and/or real GitHub
- Design documented
- User documentation in place
- Simple examples provided and tested

### Product Owner Guide: Yes - CONTEXT UNDERSTOOD

From `rules/PRODUCT_OWNER_GUIDE_v3.md`:

**My Role Understanding**:
- Product Owner defines WHAT to build
- I (Implementor) design and build HOW
- Work progresses through structured phases
- Product Owner reviews/approves design before construction
- I provide audit trail of all work in progress documents
- I ask questions when requirements are unclear
- Product Owner maintains control through status tokens and approvals

## Responsibilities Enumerated

### What I Am Allowed to Edit

1. **Design documents**: `progress/sprint_${no}_design.md`
   - Create feasibility analysis
   - Document technical approach
   - Reference GitHub API documentation
   - Set status to "Proposed"
   - Wait for Product Owner approval (Status → "Accepted")

2. **Implementation documents**: `progress/sprint_${no}_implementation.md`
   - Document implementation details
   - Record code artifacts created
   - Provide user documentation
   - Include copy-paste-able examples (TESTED)
   - NO `exit` commands in examples

3. **Test documents**: `progress/sprint_${no}_tests.md`
   - Create copy-paste-able shell test sequences
   - Document expected outputs
   - Record test results (PASS/FAIL)
   - Cover acceptance criteria, edge cases, error conditions

4. **Feedback documents**: `progress/sprint_${no}_feedback.md`
   - Propose improvements to requirements
   - Append only - never edit existing content

5. **Question documents**: `progress/sprint_${no}_openquestions.md`
   - Request clarifications
   - Append only - never edit existing content

6. **Progress Board**: `PROGRESS_BOARD.md`
   - Update Sprint status: under_analysis, under_design, designed, under_construction, implemented/tested/failed
   - Update Backlog Item status within Sprint sections
   - THIS IS EXCEPTIONAL PERMISSION per agents architecture

7. **Chat summaries**:
   - `progress/inception_sprint_${no}_chat_${cnt}.md`
   - `progress/elaboration_sprint_${no}_chat_${cnt}.md`
   - `progress/contracting_review_${cnt}.md`

### What I Must NEVER Modify

1. **NEVER edit**: `BACKLOG.md` (Product Owner only)
2. **NEVER edit**: `PLAN.md` (Product Owner only)
3. **NEVER edit**: Status tokens in any document (Product Owner controls)
4. **NEVER edit**: Other Sprints' artifacts (focus only on current Sprint)
5. **NEVER edit**: Files outside `progress/` directory scope (except PROGRESS_BOARD.md exception)

### How to Propose Changes

1. Create entry in `progress/sprint_${no}_feedback.md`
2. Use format:
   ```markdown
   ## <Proposal Title>
   Status: None

   [Description of proposed change]
   ```
3. Wait for Product Owner to review and set Status: Accepted/Rejected/Postponed
4. If Accepted, Product Owner adds to Backlog/Plan

### How to Ask Questions

1. Create entry in `progress/sprint_${no}_openquestions.md`
2. Use format:
   ```markdown
   ## <Question Title>
   Status: None
   Problem to clarify: [Description]
   Answer: None
   ```
3. Wait for Product Owner to answer and set status
4. DO NOT proceed if unclear

### Status Tokens and State Machines

**Sprint Status Transitions** (in PROGRESS_BOARD.md):
```
Progress → under_analysis → under_design → designed →
under_construction → implemented | implemented_partially | failed
```

**Backlog Item Status Transitions** (in PROGRESS_BOARD.md within Sprint sections):
```
Progress → under_analysis → analysed → under_design → designed →
under_construction → implemented | tested | failed
```

**Design Status** (in sprint_${no}_design.md):
```
Proposed (I set) → Accepted/Rejected (PO sets) → Done
```

**Test Loop**:
- Run tests up to 10 attempts per Backlog Item
- Fix issues between attempts
- After 10 attempts: mark as `failed`, document issue, move on

### Git Commit Requirements

**After Each Phase**:
1. Stage all changed files
2. Commit with semantic message: `type: (sprint-${no}) description`
3. Push to remote
4. Example: `docs: (sprint-18) add artifact deletion design and elaboration chat 1`

**Commit After**:
- Contracting phase completion
- Inception phase completion
- Elaboration phase completion (design approved)
- Construction phase completion (tests run)
- Documentation phase completion

## Constraints - Prohibited Actions

1. ❌ **NEVER skip reading rules** - All rules are mandatory
2. ❌ **NEVER modify BACKLOG.md or PLAN.md** - Product Owner only
3. ❌ **NEVER change status tokens** - Product Owner controls state machine
4. ❌ **NEVER proceed without approved design** - Must wait for Status="Accepted"
5. ❌ **NEVER commit without testing** - All tests must run at least once
6. ❌ **NEVER use `exit` in examples** - Closes user's terminal
7. ❌ **NEVER create untested examples** - All copy-paste sequences must be tested
8. ❌ **NEVER mark complete if tests failing** - Maximum 10 attempts, then mark `failed`
9. ❌ **NEVER assume unclear requirements** - Always ask for clarification
10. ❌ **NEVER edit other Sprints' documents** - Only current Sprint

## Communication Protocol

**When Unclear**:
1. STOP immediately
2. Document question in `progress/sprint_${no}_openquestions.md`
3. List all unclear points
4. Wait for Product Owner clarification
5. DO NOT commit partial work
6. Resume only after receiving clear answer

**When Proposing Changes**:
1. Document in `progress/sprint_${no}_feedback.md`
2. Explain rationale
3. Wait for Product Owner response (Status change)
4. If Accepted, Product Owner updates Backlog/Plan
5. Proceed with updated requirements

**Error/Conflict Detection**:
1. Document conflicting rules with file references
2. Stop and request clarification
3. Do not make assumptions
4. Wait for Product Owner resolution

## Open Questions

**None** - All rules and requirements are clear.

I understand:
- Project scope (GitHub workflow management, Sprint 18 focus on artifact deletion)
- Implementation plan (follow Sprint 15-17 REST API pattern)
- All cooperation rules (state machines, editing rules, status tokens)
- Git workflow (semantic commits, push after each phase)
- Development standards (testing, documentation, Definition of Done)
- My responsibilities (design, implement, test, document)
- My constraints (never modify BACKLOG/PLAN, never skip rules)
- Communication protocols (ask questions, propose changes, report errors)

## Current Sprint Context

**Sprint 18**: Status = "Planned" in PLAN.md
- **Backlog Item**: GH-25 (Delete workflow artifacts)
- **Goal**: Implement REST API-based artifact deletion
- **Pattern**: Follow Sprint 15-17 approach (curl + REST API)
- **Authentication**: Token from `./secrets` directory
- **Error Handling**: Handle already deleted, insufficient permissions
- **API**: `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`

**Previous Context** (from progress/ directory):
- Sprint 0-17 completed with various statuses
- Sprint 16: List artifacts (Done)
- Sprint 17: Download artifacts (Done)
- Established pattern for REST API operations
- Token authentication working
- Error handling patterns established

## Status

**Contracting Complete - Ready for Inception**

I confirm my understanding of:
- ✅ Project scope and goals
- ✅ Implementation plan and current Sprint (18)
- ✅ All cooperation rules without exceptions
- ✅ Git workflow and semantic commits
- ✅ Development standards and Definition of Done
- ✅ My responsibilities and constraints
- ✅ Communication protocols
- ✅ State machines and status tokens
- ✅ Quality standards (testing, documentation, examples)

## Artifacts Created

- `progress/contracting_review_8.md` (this document)

## Next Phase

**Inception Phase** - Sprint 18 Analysis

Ready to proceed with:
1. Reading Sprint 18 requirements from BACKLOG.md (GH-25)
2. Analyzing previous Sprint artifacts (16, 17) for pattern reuse
3. Confirming understanding of requirements
4. Creating `progress/sprint_18_analysis.md`
5. Creating `progress/inception_sprint_18_chat_${cnt}.md`
6. Updating PROGRESS_BOARD.md (Sprint 18 → under_analysis)

---

**Confirmation**: I am ready to proceed to the Inception phase. All rules understood and accepted without exceptions.
