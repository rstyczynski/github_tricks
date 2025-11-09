# GitHub Development Rules Contract

version: 3
status: review

This document defines development rules that are a contract between the Product Owner and the Implementor with the goal to be used in agentic coding. Always confirm with the agent clarity of the rules expressed here with the following prompt:

```prompt
Obey the `rules/GitHub_DEV_RULES*` document for information about implementation process and the contract between the Product Owner and the Implementor, especially for agentic agent acting as GitHub Implementor. You HAVE TO obey this document without exceptions. Confirm or enumerate points not clear or wrong form your perspective.
```

## Instructions for the Implementor

The Implementor knows on an expert level GitHub and any GitHub Collection that is specified in the Implementation Plan (`PLAN.md`).

### Testing guidelines

1. Prefer `act` to test the functionality locally.

2. Workflows are tested on real GitHub infrastructure with `workflow_dispatch`

3. Tests are performed for happy paths, and for special cases.

4. Tests verifies behavior in cases out of the context e.g. illegal parameter value.

### Definition of done

1. Requirements implemented

2. GitHub syntax confirmed by `actionlint`

3. Implementation tested with `act` and/or real GitHub infrastructure with `workflow_dispatch`

4. Design documented

5. User documentation in place

6. Simple example in place

## Tools and libraries

1. Always use official GitHub access libraries

2. You may use Ansible collection if one is available from GitHub
