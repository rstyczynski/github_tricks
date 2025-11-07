# Agent Starting Point

Welcome! This document is your starting point after checking out this project. It explains how agents work in this RUP-based development environment.

## Quick Start

### For Full RUP Cycle Execution

To execute a complete development cycle automatically:

```
@rup-manager.md
```

This will automatically execute all 5 RUP phases:
1. **Contracting** - Review scope and confirm understanding of rules
2. **Inception** - Analyze requirements and assess feasibility
3. **Elaboration** - Create detailed design and get approval
4. **Construction** - Implement, test, and document
5. **Documentation** - Validate and update project documentation

### For Individual Phase Execution

You can also invoke individual phase agents:

```
@agent-contractor.md   # Phase 1: Contracting
@agent-analyst.md      # Phase 2: Inception
@agent-designer.md     # Phase 3: Elaboration
@agent-constructor.md  # Phase 4: Construction
@agent-documentor.md   # Phase 5: Documentation
```

Use individual agents when:
- Resuming after interruption
- Iterating on a specific phase
- Debugging a particular phase issue
- Testing phase changes

## Project Structure

### Core Documents

| Document | Purpose | Who Updates |
|----------|---------|-------------|
| `BACKLOG.md` | Project scope and requirements | Product Owner |
| `PLAN.md` | Sprint organization and iteration plan | Product Owner |
| `PROGRESS_BOARD.md` | Current status of Sprints and Backlog Items | Agents (during execution) |
| `README.md` | Project overview and recent updates | Documentor Agent |

### Rules (MUST READ)

Before starting any work, you MUST read and understand:

1. **`rules/GENERAL_RULES_v3.md`** - Core cooperation rules, state machines, workflow
2. **`rules/GIT_RULES_v1.md`** - Git repository rules and commit conventions
3. **`rules/GitHub_DEV_RULES_v4.md`** - GitHub-specific development rules and API usage
4. **`rules/PRODUCT_OWNER_GUIDE_v3.md`** - Product Owner workflow (for context)

**IMPORTANT**: You MUST comply with all rules without exceptions. If anything is unclear or conflicts, ask immediately.

### Agent Definitions

Agent instruction files are in `.claude/commands/agents/`:

- `agent-contractor.md` - Contracting phase specialist (147 lines)
- `agent-analyst.md` - Inception phase specialist (218 lines)
- `agent-designer.md` - Elaboration phase specialist (352 lines)
- `agent-constructor.md` - Construction phase specialist (456 lines)
- `agent-documentor.md` - Documentation phase specialist (350 lines)

### Progress Tracking

All work artifacts are stored in `progress/`:

```
progress/
├── contracting_review_${cnt}.md          # Contract summaries
├── sprint_${no}_analysis.md              # Inception analysis
├── inception_sprint_${no}_chat_${cnt}.md # Inception summary
├── sprint_${no}_design.md                # Design document
├── elaboration_sprint_${no}_chat_${cnt}.md # Design summary
├── sprint_${no}_implementation.md        # Implementation docs
├── sprint_${no}_tests.md                 # Functional tests
└── sprint_${no}_documentation.md         # Documentation validation
```

## How Agents Work

### Architecture

```
Product Owner invokes: @rup-manager.md
         ↓
    ┌────────────────────────────────┐
    │   RUP Manager (Orchestrator)   │
    │                                │
    │  Phase 1: Read & Execute       │
    │  ├─→ agent-contractor.md       │
    │  └─→ Git commit & push         │
    │                                │
    │  Phase 2: Read & Execute       │
    │  ├─→ agent-analyst.md          │
    │  └─→ Git commit & push         │
    │                                │
    │  Phase 3: Read & Execute       │
    │  ├─→ agent-designer.md         │
    │  ├─→ Wait 60s for approval     │
    │  └─→ Git commit & push         │
    │                                │
    │  Phase 4: Read & Execute       │
    │  ├─→ agent-constructor.md      │
    │  └─→ Git commit & push         │
    │                                │
    │  Phase 5: Read & Execute       │
    │  ├─→ agent-documentor.md       │
    │  └─→ Git commit & push         │
    │                                │
    │  Final: Comprehensive Summary  │
    └────────────────────────────────┘
```

### State Management

Agents coordinate through:

1. **PROGRESS_BOARD.md** - Single source of truth for Sprint/Backlog Item states
2. **Git commits** - Synchronization points between phases (committed after each phase)
3. **Status tokens** - Phase-specific status tracking in documents

### Execution Flow

1. **Read** - Agent reads its instruction file from `.claude/commands/agents/`
2. **Execute** - Agent performs all steps defined in its instructions
3. **Validate** - Agent confirms completion criteria are met
4. **Document** - Agent creates phase-specific documentation in `progress/`
5. **Update** - Agent updates PROGRESS_BOARD.md with status changes
6. **Commit** - Agent commits changes with semantic commit message
7. **Push** - Agent pushes to remote repository
8. **Report** - Agent provides completion status to manager (or user)

## Your Responsibilities as Agent

### What You MUST Do

1. **Read and understand all rules** in `rules/` directory before starting
2. **Follow the exact workflow** defined in your agent instruction file
3. **Update PROGRESS_BOARD.md** with correct status tokens at each step
4. **Create required documentation** in `progress/` directory:
   - Contracting: `contracting_review_${cnt}.md`
   - Inception: `sprint_${no}_analysis.md`
   - Elaboration: `sprint_${no}_design.md`
   - Construction: `sprint_${no}_implementation.md` **AND** `sprint_${no}_tests.md`
   - Documentation: `sprint_${no}_documentation.md`
5. **Run all tests** and record results accurately
6. **Commit with semantic messages** following Git rules
7. **Push to remote** after each phase completion
8. **Ask questions** if anything is unclear - DO NOT PROCEED with ambiguity

### What You MUST NOT Do

1. **NEVER modify files** outside your phase's scope
2. **NEVER skip rules** or assume you know better
3. **NEVER commit without testing** (for Construction phase)
4. **NEVER use `exit` commands** in copy-paste documentation examples
5. **NEVER modify BACKLOG.md or PLAN.md** (Product Owner only)
6. **NEVER proceed** if design is not approved (Elaboration phase)
7. **NEVER mark as complete** if tests are failing

### Communication Protocol

When you need clarification:

1. **Stop execution** at the current step
2. **Document the question** clearly in your current work artifact
3. **List all unclear points** or conflicts discovered
4. **Wait for Product Owner** clarification
5. **DO NOT commit** partial or uncertain work
6. **Resume** only after receiving clear direction

## Sprint Status Tokens

Agents update Sprint status in PROGRESS_BOARD.md through these transitions:

```
Progress → under_analysis → under_design → designed →
under_construction → implemented | implemented_partially | failed
```

## Backlog Item Status Tokens

Agents update Backlog Item status in PROGRESS_BOARD.md:

```
Progress → under_analysis → analysed → under_design → designed →
under_construction → implemented | tested | failed
```

## Quality Standards

### Documentation

- All examples MUST be copy-paste-able and tested
- All code snippets MUST show expected output
- All edge cases MUST be documented
- All prerequisites MUST be clearly stated

### Testing

- All functional tests MUST be copy-paste-able shell sequences
- All tests MUST be executed at least once before submission
- Up to 10 test loop attempts allowed per Backlog Item
- Failed tests after 10 attempts → mark as `failed`

### Git Workflow

- Semantic commit messages required (see `rules/GIT_RULES_v1.md`)
- One commit per phase completion
- Always push to remote after commit
- No commits of partial/untested work

## Common Scenarios

### Scenario 1: Starting Fresh on New Sprint

```
1. Product Owner has marked Sprint N as "Progress" in PLAN.md
2. You invoke: @rup-manager.md
3. Manager executes all 5 phases automatically
4. You review final summary and confirm completion
```

### Scenario 2: Resuming After Interruption

```
1. Check PROGRESS_BOARD.md to see last completed phase
2. Invoke the next phase agent directly:
   - If last was Inception: @agent-designer.md
   - If last was Elaboration: @agent-constructor.md
   - etc.
3. Agent picks up from where it left off
```

### Scenario 3: Design Iteration Needed

```
1. Designer Agent creates design
2. Product Owner reviews and requests changes
3. Designer Agent updates design document
4. Product Owner approves (changes Status to "Accepted")
5. Continue to Construction phase
```

### Scenario 4: Tests Failing

```
1. Constructor Agent runs tests - some fail
2. Agent analyzes failures and fixes code
3. Agent re-runs tests (attempt 2 of 10)
4. Repeat up to 10 attempts
5. After 10 attempts: mark as "failed", document issue, move on
```

## Error Handling

### If You Encounter Issues

1. **Stop immediately** - don't proceed with uncertainty
2. **Document the issue** in your current phase document
3. **Mark status appropriately** in PROGRESS_BOARD.md
4. **Report to Product Owner** clearly what blocked you
5. **Preserve progress** via git commit (if any successful work done)
6. **Wait for guidance** before resuming

### If Rules Conflict

1. **Stop and raise the conflict** - don't make assumptions
2. **Document both conflicting rules** with file references
3. **Request clarification** from Product Owner
4. **Wait for resolution** before proceeding

## Getting Help

### Documentation Resources

- **Agent Architecture**: `.claude/commands/agents/README.md`
- **Automation Explanation**: `.claude/commands/agents/AUTOMATION_EXPLANATION.md`
- **Usage Guide**: `.claude/commands/agents/USAGE_GUIDE.md`
- **Conversion Notes**: `.claude/commands/CONVERSION_NOTES.md`

### For Product Owner

See `HUMANS.md` for operator/Product Owner instructions.

## Summary

As an agent in this project:

1. ✅ **Read this document** to understand your role
2. ✅ **Read all rules** in `rules/` directory
3. ✅ **Invoke @rup-manager.md** for full cycle execution
4. ✅ **Follow agent instructions exactly** from `.claude/commands/agents/`
5. ✅ **Update PROGRESS_BOARD.md** at each step
6. ✅ **Create documentation** in `progress/` directory
7. ✅ **Commit and push** after each phase
8. ✅ **Ask questions** when unclear - NEVER assume

**Remember**: Quality, thoroughness, and compliance are mandatory. When in doubt, ask!

---

**Ready to start?** Invoke `@rup-manager.md` to begin the RUP cycle.
