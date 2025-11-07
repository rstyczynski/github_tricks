# Human Operator / Product Owner Guide

Welcome! This document is your starting point as a Product Owner or operator managing AI agents in this RUP-based development project.

## Quick Start

### First Time Setup

1. **Define your project scope** in `BACKLOG.md`
2. **Organize iterations** in `PLAN.md`
3. **Review the workflow guide** in `rules/PRODUCT_OWNER_GUIDE_v3.md`
4. **Understand project rules** in `rules/GENERAL_RULES_v3.md`
5. **Mark your first Sprint as "Progress"** in `PLAN.md`
6. **Invoke the agent**: Send `@rup-manager.md` to your AI agent
7. **Monitor progress** via `PROGRESS_BOARD.md` and git commits

### Daily Operation

```
1. Check PROGRESS_BOARD.md for current status
2. Review completed phase artifacts in progress/
3. Approve designs when Status="Proposed" in sprint_*_design.md
4. Answer agent questions when they arise
5. Mark next Sprint as "Progress" when ready
6. Repeat!
```

## Your Role as Product Owner

### What You Do

1. **Define Requirements** - Write clear Backlog Items in BACKLOG.md
2. **Plan Sprints** - Organize work into Sprints in PLAN.md
3. **Review Designs** - Approve or request changes during Elaboration phase
4. **Answer Questions** - Provide clarifications when agents ask
5. **Accept Deliverables** - Review implementation and test results
6. **Manage Backlog** - Add, modify, prioritize Backlog Items
7. **Monitor Progress** - Track Sprint status via PROGRESS_BOARD.md

### What Agents Do

1. **Analyze Requirements** - Review your Backlog Items and confirm understanding
2. **Design Solutions** - Create detailed technical designs for approval
3. **Implement Code** - Build the features according to approved designs
4. **Test Thoroughly** - Run comprehensive tests with up to 10 retry attempts
5. **Document Everything** - Create user docs, test docs, implementation notes
6. **Update Status** - Keep PROGRESS_BOARD.md current at each step
7. **Commit & Push** - Save work to git after each phase

## Project Structure

### Documents You Own

| Document | Your Responsibility | When to Update |
|----------|---------------------|----------------|
| `BACKLOG.md` | Define all features and requirements | As needs evolve |
| `PLAN.md` | Organize Backlog Items into Sprints | Before each Sprint |
| `sprint_*_design.md` | Review and approve designs | During Elaboration phase |
| `rules/PRODUCT_OWNER_GUIDE_v3.md` | Your workflow reference | Rarely (rules doc) |

### Documents You Monitor

| Document | Purpose | When to Check |
|----------|---------|---------------|
| `PROGRESS_BOARD.md` | Current Sprint/Item status | Daily |
| `progress/sprint_*_implementation.md` | Implementation details | After Construction |
| `progress/sprint_*_tests.md` | Test results | After Construction |
| `README.md` | Project overview | After Documentation phase |

### Documents You Don't Touch

| Document | Owner | Purpose |
|----------|-------|---------|
| `AGENTS.md` | System | Agent starting point |
| `progress/contracting_review_*.md` | Agent | Contract summaries |
| `progress/sprint_*_analysis.md` | Agent | Inception analysis |
| `progress/inception_sprint_*_chat_*.md` | Agent | Inception summaries |
| `progress/elaboration_sprint_*_chat_*.md` | Agent | Design summaries |
| `progress/sprint_*_documentation.md` | Agent | Documentation validation |

## BACKLOG.md Structure

Your backlog should follow this format:

```markdown
# Project Backlog

## Backlog Items

### GH-1: Feature Name

**Status**: [Backlog | Progress | Done]

**Description**:
Clear description of what needs to be built.

**Acceptance Criteria**:
- Criterion 1
- Criterion 2

**Technical Constraints**:
- Any limitations or requirements
- APIs that must be used
- Technologies to avoid

**Priority**: [High | Medium | Low]

**Sprint**: [Sprint number or "Backlog"]
```

### Good Backlog Item Example

```markdown
### GH-25: Implement Workflow Artifact Deletion

**Status**: Progress

**Description**:
Add capability to delete artifacts from completed workflow runs to free up storage space.

**Acceptance Criteria**:
- Script accepts artifact ID or name as parameter
- Confirms deletion with user (unless --force flag used)
- Reports success/failure clearly
- Handles errors gracefully (artifact not found, permission denied)

**Technical Constraints**:
- Must use GitHub REST API v3
- Must support authentication via token file
- Must work with existing scripts/download-artifact-curl.sh patterns

**Priority**: High

**Sprint**: Sprint 18
```

## PLAN.md Structure

Your plan should organize Sprints:

```markdown
# Project Plan

## Sprint 18

**Status**: Progress

**Goal**: Implement artifact management features

**Backlog Items**:
- GH-25: Workflow Artifact Deletion
- GH-26: Artifact Cleanup Automation

**Target Duration**: 2 days

**Notes**:
- Focus on API integration
- Reuse existing authentication patterns
```

### Sprint Status Values

| Status | Meaning | When to Use |
|--------|---------|-------------|
| `Planned` | Sprint defined but not started | During planning |
| `Progress` | Sprint is active (agents work on this) | When ready to start |
| `Done` | Sprint completed successfully | After all items delivered |
| `Cancelled` | Sprint abandoned | If requirements change |

## RUP Cycle Phases

### Phase 1: Contracting

**What Happens**: Agent reviews all rules and confirms understanding

**Your Role**:
- Wait for agent to ask questions if any rules are unclear
- Provide clarifications if needed
- Approve when agent confirms readiness

**Output**: `progress/contracting_review_${cnt}.md`

**Duration**: ~2-5 minutes

---

### Phase 2: Inception

**What Happens**: Agent analyzes your Backlog Items and Sprint goals

**Your Role**:
- Answer questions about requirements
- Clarify acceptance criteria if needed
- Confirm when agent understanding is correct

**Output**:
- `progress/sprint_${no}_analysis.md`
- `progress/inception_sprint_${no}_chat_${cnt}.md`

**Duration**: ~5-10 minutes

**Status Updates**: Sprint → `under_analysis`, Items → `analysed`

---

### Phase 3: Elaboration

**What Happens**: Agent creates detailed technical design for your approval

**Your Role**: **CRITICAL - REQUIRES YOUR ATTENTION**
1. Agent creates design document with Status="Proposed"
2. **REVIEW** `progress/sprint_${no}_design.md` carefully
3. Check feasibility analysis (are APIs available?)
4. Verify design matches your requirements
5. **EITHER**:
   - Change Status to "Accepted" if approved
   - Request changes via comments (keep Status="Proposed")
   - Wait and agent assumes approval after 60 seconds

**Output**:
- `progress/sprint_${no}_design.md`
- `progress/elaboration_sprint_${no}_chat_${cnt}.md`

**Duration**: ~10-20 minutes (including your review time)

**Status Updates**: Sprint → `under_design` → `designed`, Items → `designed`

**⚠️ IMPORTANT**: Construction will not proceed until design is approved!

---

### Phase 4: Construction

**What Happens**: Agent implements code, creates tests, runs test loops

**Your Role**:
- Monitor progress via PROGRESS_BOARD.md status changes
- Wait for completion (this is the longest phase)
- Review results when agent reports completion

**Output**:
- Code artifacts (scripts, tools)
- `progress/sprint_${no}_implementation.md`
- `progress/sprint_${no}_tests.md`

**Duration**: ~30-90 minutes (depends on complexity)

**Status Updates**: Sprint → `under_construction`, Items → `implemented` | `tested` | `failed`

**Test Loop**: Agent runs tests up to 10 times per item, fixing issues. After 10 attempts, item marked as `failed`.

---

### Phase 5: Documentation

**What Happens**: Agent validates all docs and updates README

**Your Role**:
- Review final documentation
- Check README.md for recent updates section
- Confirm all looks good

**Output**:
- Updated `README.md`
- `progress/sprint_${no}_documentation.md`

**Duration**: ~5-10 minutes

**Status Updates**: Sprint → `implemented` | `implemented_partially` | `failed`

---

## Monitoring Progress

### Check PROGRESS_BOARD.md

This file shows real-time status:

```markdown
## Sprint 18

**Status**: under_construction

### Backlog Items

| ID | Title | Status |
|----|-------|--------|
| GH-25 | Artifact Deletion | under_construction |
| GH-26 | Cleanup Automation | designed |
```

### Status Transitions You'll See

**Sprint Status Flow**:
```
Progress → under_analysis → under_design → designed →
under_construction → implemented | implemented_partially | failed
```

**Backlog Item Status Flow**:
```
Progress → under_analysis → analysed → under_design → designed →
under_construction → implemented | tested | failed
```

### Git Commits

Agent commits after each phase with semantic messages:

```
docs(contract): add contracting review 1
docs(inception): add sprint 18 analysis and inception chat 1
docs(design): add sprint 18 design and elaboration chat 1
feat(sprint-18): implement artifact deletion (status: implemented)
docs(sprint-18): update documentation and README
```

## Design Approval Workflow

This is your most important interaction point!

### Step 1: Agent Creates Design

Agent creates `progress/sprint_18_design.md` with:

```markdown
## GH-25: Workflow Artifact Deletion

Status: Proposed

### Feasibility Analysis
...

### Design Overview
...

### Technical Specification
...
```

### Step 2: You Review Design

Check:
- ✅ Does design match your requirements?
- ✅ Are the APIs actually available (check documentation links)?
- ✅ Are risks identified and mitigated?
- ✅ Is the approach sensible?
- ✅ Are acceptance criteria addressed?

### Step 3: You Approve or Request Changes

**Option A - Approve**:
Change `Status: Proposed` to `Status: Accepted`

**Option B - Request Changes**:
Add comments in design doc explaining what needs to change, keep `Status: Proposed`

**Option C - Auto-approve**:
Wait 60 seconds and agent assumes approval

### Step 4: Agent Proceeds

Once `Status: Accepted`, agent moves to Construction phase

## Handling Agent Questions

When agent asks questions:

### Example Question

```markdown
## Open Questions

1. Should artifact deletion be recursive (delete all artifacts in a run)?
2. What should happen if artifact is still being used by another process?
3. Should we log deletions to a separate audit file?
```

### Your Response

Be clear and specific:

```markdown
Answers:
1. Yes, make it recursive with a flag --recursive (default: no)
2. Return error and don't delete - safety first
3. Yes, log to progress/artifact_deletion_audit.log
```

### Agent Continues

Agent updates design based on your answers and proceeds

## Common Scenarios

### Scenario 1: Starting a New Sprint

```
1. You: Add Backlog Items to BACKLOG.md
2. You: Create Sprint in PLAN.md with Status="Progress"
3. You: Invoke @rup-manager.md
4. Agent: Executes all 5 phases automatically
5. You: Review design when prompted (Phase 3)
6. You: Review final results (Phase 5)
7. You: Mark Sprint as "Done" in PLAN.md
```

### Scenario 2: Design Needs Changes

```
1. Agent: Creates design with Status="Proposed"
2. You: Review and find issues
3. You: Add comments in design doc requesting changes
4. You: Keep Status="Proposed"
5. Agent: Updates design based on feedback
6. Agent: Waits for your approval again
7. You: Review changes and set Status="Accepted"
8. Agent: Proceeds to Construction
```

### Scenario 3: Tests Fail After 10 Attempts

```
1. Agent: Runs tests, fails after 10 attempts
2. Agent: Marks Backlog Item as "failed" in PROGRESS_BOARD.md
3. Agent: Documents issue in sprint_*_tests.md
4. Agent: Continues with other Backlog Items
5. You: Review the issue
6. You: Either:
   - Adjust requirements in BACKLOG.md
   - Provide additional context/clarification
   - Accept partial Sprint completion
7. You: Decide whether to retry in next Sprint
```

### Scenario 4: Resuming After Interruption

```
1. You: Check PROGRESS_BOARD.md to see last completed phase
2. You: Invoke next phase agent directly:
   - If stuck in Elaboration: @agent-constructor.md
   - If stuck in Construction: @agent-documentor.md
3. Agent: Picks up from last checkpoint
4. Agent: Completes remaining phases
```

## Quality Expectations

Agents are instructed to deliver:

### Documentation Quality
- ✅ All examples copy-paste-able and tested
- ✅ All code snippets show expected output
- ✅ Prerequisites clearly stated
- ✅ Edge cases documented
- ✅ No `exit` commands in copy-paste examples

### Test Quality
- ✅ All tests as copy-paste-able shell sequences
- ✅ All acceptance criteria covered
- ✅ Error conditions tested
- ✅ Results recorded as PASS/FAIL
- ✅ Up to 10 retry attempts per failing test

### Code Quality
- ✅ Follows project conventions
- ✅ Implements approved design exactly
- ✅ Handles errors gracefully
- ✅ Includes inline documentation
- ✅ Compatible with existing code

## Troubleshooting

### Agent Won't Proceed

**Likely Cause**: Agent needs clarification or approval

**Check**:
1. Did agent ask questions you haven't answered?
2. Is design waiting for approval (Status="Proposed")?
3. Are there conflicting rules agent can't resolve?

**Solution**: Provide the requested information/approval

---

### Tests Keep Failing

**Likely Cause**: Requirements unclear or technically infeasible

**Check**:
1. Review `progress/sprint_*_tests.md` for failure details
2. Check if design missed something
3. Verify requirements are achievable with available APIs

**Solution**:
- Clarify requirements in BACKLOG.md
- Request design revision
- Accept partial implementation

---

### PROGRESS_BOARD.md Out of Sync

**Likely Cause**: Manual edits or agent interruption

**Check**:
1. Review recent git commits
2. Check for uncommitted changes
3. Verify Sprint status matches reality

**Solution**:
- Manually fix PROGRESS_BOARD.md to match actual state
- Or revert to last known good commit

---

### Too Many Files in progress/

**Normal**: Each Sprint creates 6-8 files

**To Clean Up**:
```bash
# Archive old completed Sprints
mkdir -p progress/archive
mv progress/sprint_1_* progress/archive/
mv progress/sprint_2_* progress/archive/
```

## Tips for Success

### 1. Write Clear Backlog Items

❌ **Bad**: "Make the system faster"

✅ **Good**:
```markdown
### GH-30: Optimize Workflow Listing Performance

**Description**: Reduce time to list workflows from ~5s to <1s

**Acceptance Criteria**:
- Implements caching for workflow metadata
- Uses pagination to fetch only needed results
- Completes listing in under 1 second for typical repos

**Technical Constraints**:
- Must use GitHub API v3 rate limits efficiently
- Cache TTL should be configurable
```

### 2. Keep Sprints Focused

- **Good Sprint Size**: 2-4 related Backlog Items
- **Bad Sprint Size**: 10+ unrelated items or 1 massive item
- **Sweet Spot**: Items that take 1-3 hours each to implement

### 3. Review Designs Carefully

This is your main quality gate:
- Check API availability before approving
- Verify design matches requirements
- Don't approve if uncertain - ask questions!

### 4. Trust the Test Loop

If tests fail after 10 attempts, it's likely:
- Requirements need clarification
- Design missed something
- Technically not feasible as specified

Don't keep retrying - investigate and adjust requirements

### 5. Monitor Git Commits

Each phase commit gives you a checkpoint:
- Review commit messages for progress
- Check diffs to see what changed
- Revert if something went wrong

## Advanced Topics

### Running Individual Phase Agents

Sometimes you want fine control:

```bash
# Run just Contracting
@agent-contractor.md

# Run just Construction (assumes Elaboration done)
@agent-constructor.md
```

### Skipping Phases (Not Recommended)

Phases depend on each other, but if you must:

```
# Manually create missing artifacts
touch progress/sprint_18_analysis.md
touch progress/sprint_18_design.md

# Then run Construction
@agent-constructor.md
```

⚠️ **Risk**: Agent may fail due to missing information

### Parallel Sprints (Future)

Currently not supported, but architecture allows for future enhancement to run multiple Sprints in parallel

## Getting Help

### Documentation

- **This file (HUMANS.md)**: Operator guide (you are here)
- **AGENTS.md**: Agent starting point
- **rules/PRODUCT_OWNER_GUIDE_v3.md**: Detailed PO workflow
- **rules/GENERAL_RULES_v3.md**: Project rules and state machines
- **.claude/commands/agents/README.md**: Agent architecture details

### Common Issues

See "Troubleshooting" section above

### Support

Review existing Sprint artifacts in `progress/` for examples of expected outputs

## Summary

As Product Owner / Operator:

1. ✅ **Define** requirements in BACKLOG.md
2. ✅ **Plan** Sprints in PLAN.md (mark as "Progress")
3. ✅ **Invoke** agent via @rup-manager.md
4. ✅ **Review** designs during Elaboration phase
5. ✅ **Approve** designs (change Status to "Accepted")
6. ✅ **Monitor** PROGRESS_BOARD.md for status
7. ✅ **Review** results when complete
8. ✅ **Mark** Sprint as "Done" when satisfied

**Remember**: Agents handle the implementation - you handle the requirements and direction!

---

**Ready to start?** Define your first Sprint in PLAN.md and invoke `@rup-manager.md`

Happy agentic coding! 🚀
