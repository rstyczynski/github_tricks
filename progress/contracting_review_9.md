# Contracting Review 9

## Project Overview

This project implements GitHub workflow automation tools and techniques using REST API. The project follows the Rational Unified Process (RUP) adapted for agentic development, with clear phases: Contracting, Inception, Elaboration, and Construction.

**Project Scope**: Experimenting with GitHub workflows to validate behavior and provide programmatic interfaces for workflow management, artifact handling, and pull request operations.

## Current Sprint

**Sprint 20** - Status: **Progress**

**Backlog Item:**
- GH-27: Trigger workflow via REST API to compute processed parameters, and download logs, and artifacts after completion

**Goal**: Use already existing scripts to establish a sequence of script invocations. Provide parameters: string and number, and return in artifacts array of string with the provided length.

## Understanding Confirmed

### Project Scope (✓ Yes)

**Summary**: The BACKLOG.md document outlines 27 GitHub workflow-related backlog items spanning workflow triggering, correlation, log access, artifact management, and pull request operations. Sprint 20 is currently in Progress status, focusing on GH-27 which involves orchestrating existing scripts into a comprehensive workflow sequence.

**Previous Work**: The project has successfully completed Sprints 0-19, implementing:
- Prerequisites and tool setup (Sprint 0)
- Workflow triggering and correlation (Sprints 1, 3)
- Log access after run (Sprint 3)
- Timing benchmarks (Sprint 4)
- REST API implementations for trigger, correlation, and log retrieval (Sprint 15)
- Artifact management (Sprints 16-18)
- API documentation and automation (Sprint 19)

### Implementation Plan (✓ Yes)

**Summary**: PLAN.md organizes execution into Sprints with clear status tracking. Sprint 20 is marked as "Progress" and requires orchestrating existing scripts for end-to-end workflow execution with parameter processing and artifact retrieval.

**Previous Sprints**:
- Sprints 0-19 are marked as Done (except 2, 6, 7, 10, 12 which are Failed)
- Sprint 20 is the current active sprint

### General Rules (✓ Yes - rules/GENERAL_RULES_v3.md)

**Key Points Understood:**
1. **Role**: Acting as Implementor executing goals specified by Product Owner
2. **Sprint Focus**: Only work on Backlog Items designated to current Sprint (Sprint 20: GH-27)
3. **Ownership Rules**:
   - **PROHIBITED**: Modify BACKLOG.md, PLAN.md, status tokens
   - **ALLOWED**: Edit Design, Implementation Notes (excluding status), Proposed changes, More information needed
4. **Cooperation Flow**:
   - Product Owner specifies Implementation Plan in PLAN.md
   - Implementor creates design in `progress/sprint_<id>_design.md`
   - Design must be approved before construction begins
   - Implementation notes go in `progress/sprint_<id>_implementation.md`
   - Feedback goes in `progress/sprint_<id>_feedback.md` and `progress/sprint_<id>_openquestions.md`

5. **State Machines**:
   - Sprint FSM: Planned → Progress → Designed → Implemented → Tested → Done (or Failed/Rejected/Postponed)
   - Design FSM: Proposed → Accepted/Rejected → Done
   - Feedback FSM: Proposed → Accepted/Postponed/Rejected

6. **Documentation Rules**:
   - Use Markdown without indentation (except enumerations)
   - Add empty lines before code blocks and after chapters
   - Follow linting rules

### Git Rules (✓ Yes - rules/GIT_RULES_v1.md)

**Key Points Understood:**
1. Use semantic commit messages following: https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716
2. **Critical Format Rule**: Semantic message type comes BEFORE colon with no text between type and colon
   - ✗ FORBIDDEN: `docs(sprint-14): message`
   - ✓ CORRECT: `docs: (sprint-14) message`

### Development Rules (✓ Yes - rules/GitHub_DEV_RULES_v4.md)

**Key Points Understood:**
1. **Expertise Level**: Expert knowledge of GitHub APIs required
2. **Testing Guidelines**:
   - Prefer `act` for local testing
   - Test on real GitHub infrastructure with `workflow_dispatch`
   - Test happy paths and special/edge cases
   - Test illegal parameter values
3. **Definition of Done**:
   - Requirements implemented
   - GitHub syntax confirmed by `actionlint`
   - Implementation tested with `act` and/or real GitHub
   - Design documented
   - User documentation in place
   - Simple example in place
4. **Tools**: Always use official GitHub access libraries; may use Ansible collection if available

### Product Owner Guide (✓ Yes - rules/PRODUCT_OWNER_GUIDE_v3.md)

**Context Understood**: This document guides the Product Owner's workflow through the RUP phases. As Implementor, I understand:
- Product Owner controls phase transitions via status tokens
- Product Owner reviews and accepts/rejects designs
- Interventions may occur for technical noncompliance, procedural violations, conceptual defects, or late changes
- Clear communication is essential; questions must be raised immediately

## Responsibilities Enumerated

### What I MUST Do

1. **Read and understand all rules** in `rules/` directory before starting (✓ Completed)
2. **Follow exact workflow** from agent instruction files
3. **Create design document** in `progress/sprint_20_design.md` with feasibility analysis
4. **Await design approval** before starting implementation
5. **Update implementation notes** in `progress/sprint_20_implementation.md`
6. **Create test documentation** in `progress/sprint_20_tests.md`
7. **Run all tests** and record results accurately (up to 10 test loop attempts per Backlog Item)
8. **Commit with semantic messages** following Git rules (correct format: `type: (context) message`)
9. **Push to remote** after each phase completion
10. **Ask questions immediately** if anything is unclear

### What I MUST NOT Do

1. **NEVER modify** BACKLOG.md or PLAN.md
2. **NEVER modify** status tokens (owned by Product Owner)
3. **NEVER skip rules** or assume I know better
4. **NEVER commit without testing** (for Construction phase)
5. **NEVER use `exit` commands** in copy-paste documentation examples
6. **NEVER proceed** if design is not approved
7. **NEVER mark as complete** if tests are failing
8. **NEVER edit** already closed parts without going through Proposed changes process
9. **NEVER use wrong commit format** (no text between type and colon)

### How to Propose Changes

Create or append to `progress/sprint_20_feedback.md`:
```markdown
# Sprint 20 - Feedback

## <Proposal Name>
Status: None
[Description of proposed change]
```

### How to Ask Questions

Create or append to `progress/sprint_20_openquestions.md`:
```markdown
# Sprint 20 - More information needed

## <Question Title>
Status: None
Problem to clarify: [Description]
Answer: None
```

### Status Tokens and State Machines

**Sprint Status Progression** (Product Owner owns):
```
Progress → Designed → Implemented → Tested → Done
                 ↓         ↓           ↓
               Failed   Failed     Failed
```

**Design Status** (Product Owner owns):
```
Proposed → Accepted → Done
    ↓
Rejected
```

**My Actions Based on Status**:
- When Sprint = "Progress" → Create design, set to "Proposed"
- When Design = "Accepted" → Proceed with implementation
- When Design = "Rejected" → Review feedback and revise
- NEVER change status tokens myself

### Git Commit Requirements

**Format**: `<type>: (<context>) <description>`

**Examples**:
- ✓ `docs: (sprint-20) add design document for GH-27`
- ✓ `feat: (sprint-20) implement workflow orchestration script`
- ✓ `test: (sprint-20) add functional tests for end-to-end workflow`
- ✗ `docs(sprint-20): add design document` ← WRONG FORMAT

**Types**: feat, fix, docs, test, refactor, chore

## Constraints

1. **File Modification Scope**: Only edit files in `progress/` directory for current Sprint 20
2. **Testing Limits**: Maximum 10 test loop attempts; after 10 failures, mark as `failed` and document issue
3. **Authentication**: Use token from `./secrets` directory for GitHub API calls
4. **Tools**: Use `podman` for containers, `https://webhook.site` for public webhooks
5. **No Over-Engineering**: Implement simplistic solutions meeting exact requirements without additions

## Communication Protocol

**When I Need Clarification:**
1. STOP execution immediately
2. Document question in `progress/sprint_20_openquestions.md`
3. List all unclear points or conflicts
4. Wait for Product Owner clarification
5. DO NOT commit partial or uncertain work
6. Resume only after receiving clear direction

**Decision Points:**
- After Contracting → Confirm readiness before Inception
- After Inception → Confirm understanding before Elaboration
- After Elaboration → Wait for design acceptance (Product Owner changes status to "Accepted")
- During Construction → Stop after 10 failed test attempts

## Open Questions

**None** - All aspects of the contracting phase are clear. I understand:
- The project scope and Sprint 20 objectives
- All cooperation rules from GENERAL_RULES_v3.md
- Git commit format requirements from GIT_RULES_v1.md
- Development and testing standards from GitHub_DEV_RULES_v4.md
- My role boundaries and responsibilities
- Status token management (Product Owner only)
- Communication protocols for feedback and clarification

## Status

**Contracting Complete - Ready for Inception**

## Artifacts Created

- `progress/contracting_review_9.md` (this document)

## Next Phase

**Inception Phase** - Ready to proceed when Product Owner initiates with Sprint 20 analysis prompt.

---

**Confirmation**: I have reviewed and understood all foundation documents, rules, and responsibilities. I am ready to proceed with the Inception phase for Sprint 20 (GH-27) when directed by the Product Owner.
