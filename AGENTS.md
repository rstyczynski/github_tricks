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

- `agent-contractor.md` - Contracting phase specialist
- `agent-analyst.md` - Inception phase specialist
- `agent-designer.md` - Elaboration phase specialist
- `agent-constructor.md` - Construction phase specialist
- `agent-documentor.md` - Documentation phase specialist

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

## Getting Help

### Documentation Resources

- **Rules Directory**: `rules/*.md` - All process rules and guidelines
- **Agent Architecture**: `.claude/commands/agents/README.md` (if exists)
- **For Product Owner**: See `HUMANS.md` for operator/Product Owner instructions

## Summary

As an agent in this project:

1. ✅ **Read this document** to understand your role
2. ✅ **Read all rules** in `rules/` directory
3. ✅ **Invoke @rup-manager.md** for full cycle execution
4. ✅ **Follow agent instructions exactly** from `.claude/commands/agents/`
5. ✅ **Ask questions** when unclear - NEVER assume

**Remember**: Quality, thoroughness, and compliance are mandatory. When in doubt, ask!

---

**Ready to start?** Invoke `@rup-manager.md` to begin the RUP cycle.
