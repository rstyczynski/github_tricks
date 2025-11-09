# Rules Directory Structure

This directory contains all governance rules for the RUP Strikes Back methodology and technology-specific implementations.

## Directory Organization

### `generic/`
Universal rules that apply to all projects regardless of technology stack:

- **GENERAL_RULES.md** - Core cooperation rules, state machines, workflow, and file ownership policies
- **GIT_RULES.md** - Git repository conventions and semantic commit message requirements
- **PRODUCT_OWNER_GUIDE.md** - Complete Product Owner workflow guide and phase transition procedures
- **images/** - Visual assets for generic methodology (state machine diagrams, workflow visualizations)

### `github_actions/`
GitHub Actions specific rules and development standards:

- **GitHub_DEV_RULES.md** - GitHub-specific implementation guidelines, API usage, and testing standards
- **images/** - GitHub Actions specific visual assets (future)

## Usage

When starting work on a project:

1. **Always read generic rules first** - These establish the foundation for all work
2. **Read technology-specific rules** - Based on your project's technology stack
3. **Comply with all rules without exceptions** - If anything is unclear, ask immediately

## Adding New Technology Stacks

To add rules for a new technology (e.g., Ansible, Terraform, Kubernetes):

1. Create a new subdirectory: `rules/<technology>/`
2. Add technology-specific rules that complement the generic rules
3. Create `rules/<technology>/images/` for technology-specific visual assets if needed
4. Update this README to document the new directory
5. Ensure generic rules remain technology-agnostic

## Version History

- **v1** (Initial) - Flat structure with all rules in root directory
- **v2** (RSB Sprint 1) - Organized structure with generic and technology-specific subdirectories

