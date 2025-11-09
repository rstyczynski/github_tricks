# Product Owner Guide

version: 3
status: review

## Introduction

The Product Owner in agentic programming is the visionary who defines what should be built and ensures the AI Agent delivers it correctly. Unlike traditional software development where the Product Owner primarily manages human teams, agentic programming requires a unique skillset: the ability to guide AI agents through structured processes while maintaining control over quality and direction.

AI agents need clear, unambiguous instructions—explicit is always better. As Product Owner, you should review and validate work after each phase rather than waiting until the end, allowing for early detection and correction of issues. It is essential to maintain a complete audit trail of all decisions and changes, ensuring that every step of the development process is documented. Be prepared to refine requirements and designs iteratively through ongoing dialogue with the Agent. Finally, give agents autonomy, but only within well-defined boundaries that you set and control.

The Product Owner is responsible for:

| Responsibility         | Description                                                                                   |
|------------------------|-----------------------------------------------------------------------------------------------|
| Vision Management      | Defining clear, achievable objectives that AI agents can implement                            |
| Process Control        | Guiding agents through structured development phases (Inception → Elaboration → Construction) |
| Quality Assurance      | Ensuring compliance with technical standards and best practices                               |
| Intervention           | Recognizing when agents deviate and correcting course promptly                                |
| Documentation          | Maintaining requirements, design decisions, and implementation records                        |

Success in the agentic programming depends on understanding the capabilities and limitations of AI agents. They are powerful implementors but require explicit guidance, clear boundaries, and systematic oversight.

## How to Use This Document

This cheat sheet provides ready-to-use prompts and procedures for each development phase. It follows a Rational Unified Process (RUP) inspired approach adapted for AI collaboration:

| Phase           | Purpose                                           |
|-----------------|--------------------------------------------------|
| Contracting     | Establish rules and scope before work begins      |
| Inception       | Define requirements and validate understanding    |
| Elaboration     | Design the solution architecture and approach     |
| Construction    | Implement, test, and verify the code             |

Each phase handles exceptions, when Product Owner handles deviations and maintains alignment.

Each section contains prompt templates you can use directly with your AI Agent. Think of this as your operational playbook for managing AI-driven development projects.

Cooperation workflow is presented on the following diagram:

![Agentic Cooperation Workflow](images/agentic_cooperation_v2.png)

## Contracting

Before starting any technical work, inform the Agent about the project scope and applicable cooperation rules.

```prompt
# Contracting phase (1/4)

We are now in contracting phase. Your staring point is described in `AGENTS.md` file. Project scope is defined in `BACKLOG.md`, and the implementation plan is at `PLAN.md`. Already performed work is documented in 'progress' directory.

Before next steps, read BACKLOG/PLAN files and follow documents in `rules` directory for details about technology and cooperation rules. You MUST comply with all the documents without exceptions. Confirm your understanding or list any unclear or incorrect points.

Enumerate required changes as instructed.

Ask questions in case of clarifications needed as instructed.

Summarize what have to be done.

Confirm when all is clear and you are ready to proceed.

## Any questions?

If anything is not clear raise it now, and stop here.

## Ready to go? 

If all is clear summarize this conversation in `contracting_review_${cnt}.md`, where `cnt` is the sequential number of the review file; look into the directory for recent contracting review file to deduct next cnt value. Commit the change to the repository following semantic commit message conventions. 
```

Once the contracting phase is finished:

1. Summarize review loop, and commit

```prompt
# Contracting - confirmation of understating 

Summarize your understanding of the contract. Enumerate your responsibilities, project rules and source documents.

Summarize this conversation in `contracting_review_${cnt}.md`, where `cnt` is the sequential number of the review file; look into the directory for recent contracting review file to deduct next cnt value. Commit the change to the repository following semantic commit message conventions.
```

## Inception

The Product Owner leads the design and implementation process. The Agent is treated as a real Implementor, collaborating through inception, design, implementation, testing, and documentation phases. Refer to files in `rules` directory for detailed rules shaping the project.

Once the BACKLOG document is ready, the Product Owner commands agent to read the document. This is a **starting point** of any subsequent sprints to be executed after execution break, having other sprint ready.

```prompt
# Inception phase (2/4)

We are now in inception phase. It assumed that you went trough Contracting phase and confirmed your readiness. Look into the `BACKLOG.md` document – focus on Sprints in status `Progress`. Read all documentation and products from Sprint in `Done` state to understand project history and achievements. Reuse all we did previously, and make current work compatible. Summarize your understanding of their goals and deliverables. 

## Any questions?

If anything is not clear raise it now, and stop here.

## Ready to go? 

If all is clear summarize your understanding in `progress/inception_sprint_${no}_chat_${cnt}.md`, where `cnt` is the sequential number of the review file; look into the directory for recent inception review file to deduct next cnt value. Commit the change to the repository following semantic commit message convention.
```

When the BACKLOG is updated during this phase, the agent is asked to read it again.

```prompt
The document has been updated. Confirm whether everything is now clear or specify any remaining uncertainties.
```

Once the plan is satisfactory:

1. Summarize review loop, and commit

```prompt
# Inception - confirmation of understating 

Summarize your understanding of the project. Enumerate requirements, plan and source documents.

## Any questions?

If anything is not clear raise it now, and stop here.

## Ready to go? 

If all is clear, summarize this conversation in `progress/inception_sprint_${no}_chat_${cnt}.md`, where `cnt` is the sequential number of the review file; look into the directory for recent inception review file to deduct next cnt value. Commit Sprint related changes to the repository following semantic commit message convention. Do not change any other documents / file in the local file system!
```

## Elaboration

Request design activities and confirm that the Agent is aware of and will comply with all applicable rules and best practices.

```prompt
# Elaboration phase (2/4)

We are now in elaboration phase. Look into the BACKLOG document – focus on Sprints in status `Progress`.

Document the design. Once completed, wait for review and further instructions.
```

Once the design is delivered by the Agent, the Product Owner reviews it. If changes are required, the Product Owner updates the design section to inform the Agent about the requested modifications.

```prompt
The design section has been updated. Confirm whether all requested changes are now clear.
```

Once the design is ok:

1. Change the Phase's elaboration (design) status token to `Accepted`.
2. Change the Phase's inception (implementation plan) status token to `Designed`.
3. Summarize review loop, and commit

```prompt
# Elaboration - confirmation of completness

Summarize your understanding of the designed elements. Enumerate requirements, plan, major design decissions, source and producted documents.

## Any questions?

If anything is not clear raise it now, and stop here.

## Ready to go?

If all is clear, confirm completion of the design, and summarize the discussion in `progress/elaboration_sprint_${no}_chat_${cnt}.md`, where `cnt` is the sequence number of the review file; look into the directory for recent elaboration review file to deduct next cnt value. Commit the Sprint related changes to the repository following semantic commit message convention. Do not change any other documents / file in the local file system!
```

## Construction

Request implementation activities and confirm that the Agent understands and will comply with all applicable rules and best practices.

Proceed to implementation for all accepted phases. Ensure that the Agent follows the defined standards and confirms rule awareness before coding begins.

```prompt
Design accepted. Proceed with implementation for accepted phases.

Before next steps, read and confirm the following:

1. Follow documents in `rules` directory for details about technology and cooperation rules. You MUST comply with all the documents without exceptions. Confirm your understanding or list any unclear or incorrect points.

Enumerate required changes as instructed.

Ask questions in case of clarifications needed as instructed.

Summarize what have to be done following Sprint's design document.

Confirm when all is clear and you are ready to proceed.
```

Once confirmed:

```prompt
# Construction phase (4/4)

Proceed with implementation for accepted sprints. 

Run test for each software product to confirm proper execution before passing to the Product Owner. Run test loops for me. Report to me success or failure once you test loops are finished.

Break functional test loop after 10 attempts to remove obstacles, and raise red flag.
```

Here is an implementation review loop. Verify all the agent did by executing implemented tests. Request new tests to cover all cases. To automate tests ask the agent to loop by themselves.

```prompt
Run test loops for me. Report to me success or failure once you test loos are finished.
```

During test phase challenge the agent to explain and validate failures. Goal is to eliminate al bugs from the developed product.

Once implementation is complete and verified through review:

1. Change the Phase's construction status token to `Implemented` or `Failed`
2. Change the Phase's elaboration status token to `Done`
3. Change the Phase's inception status token to `Done`
4. Summarize review loop, and commit

```prompt
# Construction - certificate of completion

Confirm completion of the implementation, and summarize the discussion in `progress/construction_sprint_${no}_chat_${cnt}.md`, where `cnt` is the sequence number of the review file; look into the directory for recent construction review file to deduct next cnt value. Commit all the Sprint related changes to the repository following semantic commit message conventions. Do not change any other documents / file in the local file system!
```

## Interventions

Agent cooperation is not flawless. The Agent may over-engineer, ignore certain agreements, or introduce unexpected behavior. While this may seem like a limitation of current technology, it also reflects the Agent’s quasi-human creative tendencies. Occasionally, these deviations bring valuable new ideas to the project. The key is to recognize them early and channel them productively.

| Category                | Typical Cause                     | Remedy                     |
|-------------------------|---------------------------------|----------------------------|
| Session Limit Reached   | Context/token limit exceeded      | Continue with new Agent    |
| Technical Noncompliance  | Code deviates from best practices | Enforce BP compliance      |
| Procedural Violation    | Rules ignored or modified         | Restate limits, correct    |
| Conceptual Defect       | Wrong technical assumptions       | Update design              |
| Late Change             | Scope or need changed             | Add or revise              |
| Systemic Failure        | Spec or rules unclear             | Amend rules or postpone    |

When problems appear, inform the Agent directly. Communication should resemble that with a human collaborator, but empathy is unnecessary — the Agent is a machine. Use clear commands and explicit requirements rather than suggestions or explanations. Clearly identify what is wrong without unnecessary ceremony. Within an agentic ecosystem, you can combine the strengths of both systematic management and leadership-style guidance to achieve optimal results.

Interventions are not failures but control points that maintain alignment between human intent and AI execution. Each correction strengthens mutual understanding and improves the next collaboration cycle.

### Session limit reached

You can flawlessly switch between Agents when session limit is reached.

```prompt
Look into the project. I'm in Sprint implementation review. I'd like you to continue work on this Sprint. Look at documents and summarize your readiness to continue Sprint.
```

### Technical Noncompliance

When the Product Owner detects deviations from Ansible Best Practices in the Agent’s output.

```prompt
I see the `collections` keyword used in the code, which is forbidden according to `rules/ANSIBLE_BP*`. Review all code and documentation for any violations of `rules/ANSIBLE_BP*` and correct them.
```

### Procedural Violation

When the Agent violates collaboration rules or modifies restricted content, issue a direct corrective command.

```prompt
You updated the `Implementation Plan` (PLAN.md) status from `Designed` to `Planned`. NEVER update documents outside of `Design`, `Implementation notes`, `Proposed changes`, or `More information needed`. Even within these sections, do not modify paragraphs marked with `status`, as done in `Implementation notes`.
```

### Conceptual Defect

When design flaws or inconsistencies are found, request corrective action.

```prompt
Update phase's `Design` to eliminate the problem.
```

### Late Change

When the Product Owner discovers a required change in any late phase of the project, it's ok to add. When it's under an already existing phase (backlog item), describe the need. If it’s a new feature, the Product Owner should create a new item in the Backlog.

```prompt
Add it to the implementation.
```

### Systemic Failure

It may happen that after several rounds of corrections, the agent still misbehaves, drifting from the Product Owner's vision. This indicates that rules or requirements are wrongly specified. In the former case, amend the rules to make them more specific; try to add contradicting examples.

In case of functional implementation issues, verify if the requirement is clear enough and if it does not mismatch agent capabilities. Return to the Design phase to review the chosen approach. In the worst case mark requirement as `Postponed` or even `Rejected`. Commit the conversation keeping commit rules, and keep the misbehaving branch for your records.
