# Agent Starting Point

Welcome! This document is your starting point after checking out this project.

## Quick Start

To execute a complete development cycle automatically:

```
@rup-manager.md
```

To execute individual phases:

```
@agent-contractor.md   # Phase 1: Contracting
@agent-analyst.md      # Phase 2: Inception
@agent-designer.md     # Phase 3: Elaboration
@agent-constructor.md  # Phase 4: Construction
@agent-documentor.md   # Phase 5: Documentation
```

## Execution Modes

The RUP process supports two execution modes configured in `PLAN.md`:

### Mode: managed (Default - Interactive)

**Characteristics:**
- Human-supervised execution
- Agents ask for clarification on ambiguities
- Interactive decision-making at each phase
- Recommended for complex or high-risk sprints

**Behavior:**
- Wait for design approval
- Stop for unclear requirements
- Ask about significant implementation choices
- Confirm before making major decisions

### Mode: YOLO (Autonomous - "You Only Live Once")

**Characteristics:**
- Fully autonomous execution
- Agents make reasonable assumptions for weak problems
- No human interaction required
- Faster iteration cycles
- All decisions logged in implementation docs
- Recommended for well-understood, low-risk sprints

**Behavior:**
- Auto-approve designs
- Make reasonable assumptions (documented)
- Proceed with partial test success
- Auto-fix simple issues
- Only stop for critical failures

**Decision Logging:**
All YOLO mode decisions are logged in phase documents with:
- What was ambiguous
- What assumption was made
- Rationale for the decision
- Risk assessment

**Audit Trail:**
The Mode field in PLAN.md creates a permanent git record showing which sprints were autonomous vs supervised.

**How to Detect Mode:**
Read the active Sprint section in PLAN.md:
```markdown
## Sprint 20

Status: Progress
Mode: YOLO          ← Autonomous mode active

Backlog Items:
* GH-27. Feature implementation
```

If no Mode field or `Mode: managed` → Interactive mode (default)

## Rules (MUST READ)

Before starting any work, you MUST read and understand all rules in `rules/` directory:

1. **`rules/generic/GENERAL_RULES*.md`** - Core cooperation rules, state machines, workflow, file ownership
2. **`rules/generic/GIT_RULES*.md`** - Git repository rules and commit conventions
3. **`rules/generic/PRODUCT_OWNER_GUIDE*.md`** - Product Owner workflow (for context)
4. **`rules/github_actions/GitHub_DEV_RULES*.md`** - GitHub-specific development rules and API usage

**IMPORTANT**: You MUST comply with all rules without exceptions. If anything is unclear or conflicts, ask immediately.

## Summary

As an agent:

1. ✅ Read all rules in `rules/` directory
2. ✅ Invoke `@rup-manager.md` for full cycle
3. ✅ Follow agent instructions from `.claude/commands/agents/`
4. ✅ Ask questions when unclear - NEVER assume

**Ready to start?** Invoke `@rup-manager.md` to begin.
