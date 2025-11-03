
# General cooperation rules

## Design

Design is owned by the Implementor and is stored in `sprint_<id>_design.md` file for each Sprint.

Product Owner exceptionally may insert slight changes. Product owner owns `Status` line under phase chapter inserting here design state according to design's state machine defined in `rules/GitHub_DEV_RULES_v3.md`. Implementor NEVER touches the status, but his actions are driven by the status.

General template for the file:

```markdown
# Sprint <id> - design

## <Backlog Item A>

Status: Progress

Design details for <Backlog Item A>

## <Backlog Item B>

Status: Progress

Design details for <Backlog Item B>
```

## Implementation notes

Implementations notes is owned by the Implementor and is stored in `sprint_<id>_implementation.md` file for each Sprint.

Product Owner exceptionally may insert slight changes. Product owner owns `Status` line under phase chapter inserting here design state according to design's state machine defined in `rules/GitHub_DEV_RULES_v3.md`. Implementor NEVER touches the status, but his actions are driven by the status.

General template for the file:

```markdown
# Sprint <id> - Implementation Notes

## <Backlog Item A>

Status: Progress

Design details for <Backlog Item A>

## <Backlog Item B>

Status: Progress

Design details for <Backlog Item B>
```

## Feedback from the Implementor

Feedback from the Implementor is owned by the Implementor and is stored in `sprint_<id>_feedback.md` and `sprint_<id>_openquestions.md` files for each Sprint.

The file `sprint_<id>_feedback.md` is owned by the Implementor and contains proposed changes to the initial plan. Use subchapter following the Backlog Items's name. The Product Owner, after accepting the feedback, moves proposals to the implementation plan trough Backlog list. You can only append to this chapter. Never edit already existing paragraphs.

Template of the file is following:

```markdown
# Sprint <id> - Feedback

## <Proposal A>
Status: None
```

The file `sprint_<id>_openquestions.md` contains clarification requests from the Implementor. Use subchapter following the problem's name. The Product Owner, after accepting the question, answers here. You can append to this chapter. Never edit already existing paragraphs.

Template of the file is following:

```markdown
# Sprint <id> - More information needed

## <Question A>
Status: None
Problem to clarify: None
Answer: None
```

## Appendix A. Git rules

Refer to GIT_RULES_v1.md for git repository rules.
