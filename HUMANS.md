# Human Operator / Product Owner Guide

Welcome! This document is your starting point as a Product Owner or operator managing AI agents in this RUP-based development project.

## Quick Start

### First Time Setup

1. **Define your project scope** in `BACKLOG.md`
2. **Organize iterations** in `PLAN.md`
3. **Read the complete Product Owner Guide**: `rules/PRODUCT_OWNER_GUIDE*.md`
4. **Mark your first Sprint as "Progress"** in `PLAN.md`
5. **Invoke the agent**: Send `@rup-manager.md` to your AI agent
6. **Monitor progress** via `PROGRESS_BOARD.md` and git commits

### Daily Operation

```
1. Check PROGRESS_BOARD.md for current status
2. Review completed phase artifacts in progress/
3. Approve designs when needed (change Status to "Accepted")
4. Answer agent questions when they arise
5. Mark next Sprint as "Progress" when ready
```

## Your Role

### Files You Own and Modify

- **`BACKLOG.md`** - Project requirements and Backlog Items
- **`PLAN.md`** - Sprint planning and iteration organization
- **Status tokens** in design/implementation files (Proposed/Accepted/Rejected)

### Files Agents Own

- **`progress/*.md`** - All analysis, design, implementation, test, documentation files
- **`PROGRESS_BOARD.md`** - Current status tracking (agents update)
- **`README.md`** - Project overview (agents update)
- **Code and tests** in `scripts/`, `.github/`, `tests/`

## Working with Agents

### Invoking Agents

**Full RUP Cycle**:
```
@rup-manager.md
```

**Individual Phases**:
```
@agent-contractor.md   # Review scope
@agent-analyst.md      # Analyze requirements
@agent-designer.md     # Create design
@agent-constructor.md  # Implement & test
@agent-documentor.md   # Document & validate
```

### Agent Workflow

Agents execute RUP phases automatically:
1. **Contracting** - Confirm understanding of scope and rules
2. **Inception** - Analyze requirements and assess feasibility
3. **Elaboration** - Create detailed design (waits for your approval)
4. **Construction** - Implement, test, and document
5. **Documentation** - Validate docs and update README

### When Agents Need You

Agents will stop and wait when:
- **Design approval needed** - Review and change Status to "Accepted"
- **Clarification needed** - Answer questions in openquestions files
- **Conflicts found** - Provide guidance to resolve

## Rules and Guidelines

All detailed rules are in the `rules/` directory:

1. **`rules/PRODUCT_OWNER_GUIDE*.md`** - Your complete workflow guide
2. **`rules/GENERAL_RULES*.md`** - Cooperation rules and file ownership
3. **`rules/GIT_RULES*.md`** - Git conventions
4. **`rules/GitHub_DEV_RULES*.md`** - Development standards

**Read these files** for complete details on:
- Sprint state machines
- Backlog Item states
- File ownership policies
- Design approval process
- Status token usage
- Git workflow
- Quality gates

## Monitoring Progress

### PROGRESS_BOARD.md

Check this file to see current Sprint and Backlog Item status:

```
| Sprint | Sprint Status | Backlog Item | Item Status |
|--------|---------------|--------------|-------------|
| Sprint 20 | implemented | GH-27. ... | tested |
```

### Git Commits

Each phase completion creates a git commit:
- Check commit messages for phase summaries
- All commits follow semantic format: `type: (sprint-XX) description`

### Progress Files

Check `progress/` directory for detailed artifacts:
- `sprint_${no}_analysis.md` - Requirements analysis
- `sprint_${no}_design.md` - Technical design
- `sprint_${no}_implementation.md` - Implementation notes
- `sprint_${no}_tests.md` - Test results
- `sprint_${no}_documentation.md` - Documentation validation

## Summary

As Product Owner:

1. ✅ Define scope in `BACKLOG.md`
2. ✅ Plan iterations in `PLAN.md`
3. ✅ Read complete guide: `rules/PRODUCT_OWNER_GUIDE*.md`
4. ✅ Invoke agents: `@rup-manager.md`
5. ✅ Monitor via `PROGRESS_BOARD.md`
6. ✅ Approve designs when requested
7. ✅ Answer questions when agents ask

**For complete details**, see `rules/PRODUCT_OWNER_GUIDE*.md`

---

**Ready to start?** Mark a Sprint as "Progress" in `PLAN.md` and invoke `@rup-manager.md`
