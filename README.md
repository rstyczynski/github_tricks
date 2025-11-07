# GitHub Workflow Experimentation

Tools and techniques for interacting with GitHub Actions workflows via API and CLI.

## Features

### Workflow Management

- **Trigger & Track**: Dispatch workflows and correlate run IDs (UUID-based, median 17s, see `tests/correlation-timings.json`)
  - `gh` CLI version: `trigger-and-track.sh`
  - REST API version: `trigger-workflow-curl.sh` + `correlate-workflow-curl.sh` (Sprint 15)
- **Post-Run Log Retrieval**: Fetch and aggregate workflow logs after completion
  - `gh` CLI version: `fetch-run-logs.sh`
  - REST API version: `fetch-logs-curl.sh` (Sprint 15)
- **Artifact Management**: Complete lifecycle management for workflow artifacts (list, download, delete)
  - List artifacts: `list-artifacts-curl.sh` (Sprint 16)
  - Download artifacts: `download-artifact-curl.sh` (Sprint 17)
  - Delete artifacts: `delete-artifact-curl.sh` (Sprint 18)
- **Workflow Status Monitoring**: Wait for workflow completion with polling
  - Wait for completion: `wait-workflow-completion-curl.sh` (Sprint 17)
- **Job Monitoring**: View workflow job phases and status (gh CLI or curl-based)
- **Workflow Cancellation**: Cancel workflows in requested or running states with support for force-cancel and wait-for-completion
- **Benchmarking**: Measure timing for correlation and log retrieval

### Pull Request Management

- **Create Pull Requests**: Programmatically create PRs with full metadata control (title, body, reviewers, labels, issue linking)
- **List Pull Requests**: Query PRs with filters (state, branch, sort order) and pagination support
- **Update Pull Requests**: Modify PR properties (title, body, state, base branch)
- **Merge Pull Requests**: Merge PRs with multiple strategies (merge, squash, rebase) and mergeable state checking
- **PR Comments**: Add, update, delete, and list comments on pull requests (general and inline code review comments)

### Known Limitations (GitHub API)

- **No real-time log streaming**: Logs only available after job completion (Sprint 2, 6 - FAILED)
- **Webhooks require public endpoints**: Local webhook-based correlation not feasible (Sprint 7 - FAILED)
- **No native workflow scheduling**: GitHub does not support scheduling `workflow_dispatch` events (Sprint 12 - FAILED)
- **PR comment reactions require additional scopes**: Adding reactions to PR comments requires extended token permissions

## Quick Start

### Workflow Management

```bash
# Set up GitHub token and webhook URL
export GITHUB_TOKEN="your_token"
export WEBHOOK_URL="https://webhook.site/your-endpoint"

# Trigger workflow and track execution
./scripts/trigger-and-track.sh --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/dispatch-webhook.yml

# View job status
./scripts/view-run-jobs.sh --run-id <run_id>

# Fetch logs after completion
./scripts/fetch-run-logs.sh --run-id <run_id>

# List artifacts from a workflow run
./scripts/list-artifacts-curl.sh --run-id <run_id>

# List artifacts with name filter
./scripts/list-artifacts-curl.sh --run-id <run_id> --name-filter "build-"

# Download single artifact
./scripts/download-artifact-curl.sh --artifact-id <artifact_id>

# Download and extract single artifact
./scripts/download-artifact-curl.sh --artifact-id <artifact_id> --extract

# Download all artifacts from a run
./scripts/download-artifact-curl.sh --run-id <run_id> --all

# Download all artifacts from a run and extract
./scripts/download-artifact-curl.sh --run-id <run_id> --all --extract

# Download filtered artifacts using correlation ID
./scripts/download-artifact-curl.sh --correlation-id <uuid> --all --name-filter "build-" --extract

# Delete single artifact (with confirmation)
./scripts/delete-artifact-curl.sh --artifact-id <artifact_id>

# Delete single artifact (skip confirmation)
./scripts/delete-artifact-curl.sh --artifact-id <artifact_id> --confirm

# Preview deletions (dry-run)
./scripts/delete-artifact-curl.sh --run-id <run_id> --all --dry-run

# Delete all artifacts for a run
./scripts/delete-artifact-curl.sh --run-id <run_id> --all --confirm

# Delete filtered artifacts
./scripts/delete-artifact-curl.sh --run-id <run_id> --all --name-filter "test-" --confirm

# Wait for workflow completion
./scripts/wait-workflow-completion-curl.sh --run-id <run_id>

# Wait for workflow completion with custom timeout
./scripts/wait-workflow-completion-curl.sh --run-id <run_id> --max-wait 600 --interval 5

# Cancel a running workflow
./scripts/cancel-run.sh --run-id <run_id>

# Cancel and wait for completion
./scripts/cancel-run.sh --run-id <run_id> --wait

# Cancel using correlation ID
./scripts/cancel-run.sh --correlation-id <uuid> --runs-dir runs

# Force cancel (bypasses always() conditions)
./scripts/cancel-run.sh --run-id <run_id> --force --wait
```

### Pull Request Management

```bash
# Create a pull request
./scripts/create-pr.sh --head feature-branch --title "New Feature" \
  --body "Description" --base main

# List pull requests
./scripts/list-prs.sh --state open --json

# Update a pull request
./scripts/update-pr.sh --pr-number 123 --title "Updated Title" --state open

# Merge a pull request
./scripts/merge-pr.sh --pr-number 123 --method squash \
  --commit-message "Merge feature"

# Add a comment to a pull request
./scripts/pr-comments.sh --pr-number 123 --operation add \
  --body "Great work!"

# Add an inline code review comment
./scripts/pr-comments.sh --pr-number 123 --operation add-inline \
  --body "Consider refactoring" --file src/main.js --line 42 --side right
```

## Key Scripts

### Workflow Management Scripts

**Core Tools:**

- `trigger-and-track.sh` - Trigger workflow and retrieve run ID via UUID correlation (gh CLI)
- `trigger-workflow-curl.sh` - Trigger workflow using REST API (curl, Sprint 15)
- `correlate-workflow-curl.sh` - Correlate workflow runs using REST API (curl, Sprint 15)
- `fetch-run-logs.sh` - Download and aggregate logs after run completion (gh CLI)
- `fetch-logs-curl.sh` - Fetch logs using REST API (curl, Sprint 15)
- `list-artifacts-curl.sh` - List workflow artifacts with filtering and pagination (curl, Sprint 16)
- `download-artifact-curl.sh` - Download workflow artifacts with optional extraction (curl, Sprint 17)
- `delete-artifact-curl.sh` - Delete workflow artifacts with safety features (curl, Sprint 18)
- `wait-workflow-completion-curl.sh` - Wait for workflow completion with polling (curl, Sprint 17)
- `view-run-jobs.sh` - Display job phases and status (gh CLI with browser auth)
- `view-run-jobs-curl.sh` - Display job phases and status (curl with token auth)
- `cancel-run.sh` - Cancel workflows with options for force-cancel, wait-for-completion, and correlation ID support (Sprint 11)

**Benchmarking:**

- `benchmark-correlation.sh` - Measure run ID retrieval timing
- `benchmark-log-retrieval.sh` - Measure log retrieval timing

**Diagnostic/Failed Feature Scripts:**

- `stream-run-logs.sh` - Stub demonstrating real-time streaming is not supported
- `probe-job-logs.sh` - Proves job logs API only works after completion
- `manage-actions-webhook.sh` - Webhook management (requires public endpoint)

### Pull Request Management Scripts

**Core Tools:**

- `create-pr.sh` - Create pull requests with full metadata control
- `list-prs.sh` - List and filter pull requests with pagination
- `update-pr.sh` - Update pull request properties (title, body, state, base branch)
- `merge-pr.sh` - Merge pull requests with multiple strategies
- `pr-comments.sh` - Manage PR comments (add, update, delete, list, react)

## Requirements

- GitHub CLI (`gh`) - Required for some workflow operations
- `jq` - JSON processing utility
- `curl` - HTTP client for API calls
- Valid GitHub token with appropriate permissions:
  - Workflow permissions for workflow management features
  - Repository permissions (read/write) for pull request management features
  - Token stored in `.secrets/token` file for PR management scripts

## Contributing

### Adding New Features

1. Add feature request to `BACKLOG.md` (following GH-N numbering)
2. Define scope, requirements, and acceptance criteria
3. Update `PLAN.md` to schedule for iteration

### Working with AI Agents

To trigger an AI agent to implement features:

1. Provide agent with `AGENTS.md` instructions
2. Agent reads `BACKLOG.md` (scope), `PLAN.md` (iterations), and `rules/` (process)
3. Agent follows the full development lifecycle per `rules/GENERAL_RULES*`

**For Operators**: See `HUMANS.md` and `rules/PRODUCT_OWNER_GUIDE*` for managing the project through iterations.

## AI-Driven Development Process

This project uses agentic programming where AI agents collaborate with a Product Owner through structured phases with built-in feedback loops:

![Agentic Cooperation Workflow](rules/images/agentic_cooperation_v2.png)

**Development Phases:**

- **Contracting** (Gray): Establish collaboration rules and agent cooperation specification
- **Inception** (Green): Define requirements in Backlog
- **Elaboration** (Yellow): Create and review design with iterative refinement
- **Construction** (Blue): Implement, test, and refine code with continuous feedback

Each phase includes review loops ensuring quality and alignment. See [Product Owner Guide](rules/PRODUCT_OWNER_GUIDE_v3.md) for detailed process documentation.

## Documentation

**Core Documentation:**

- `BACKLOG.md` - Project backlog with features and requirements
- `PLAN.md` - Sprint iteration plans and status
- `rules/` - Development process guidelines and rules

**Sprint Progress Tracking:**

- `progress/` - Complete audit trail of all sprints:
  - `sprint_N_design.md` - Design documents for each sprint
  - `sprint_N_implementation.md` - Implementation notes and summaries
  - `sprint_N_analysis.md` - Analysis documents for complex sprints
  - `inception_sprint_N_*.md` - Requirements definition phase logs
  - `elaboration_sprint_N_*.md` - Design phase chat logs
  - `construction_sprint_N_*.md` - Implementation phase chat logs
  - `*_review_*.md` - Product Owner review feedback

**Current Status:**

- Sprint 18: ✅ Done (Artifact Deletion - GH-25)
- Sprint 17: ✅ Done (Artifact Download - GH-24)
- Sprint 16: ✅ Done (Artifact Listing - GH-23)
- Sprint 15: ✅ Done (REST API Validation - GH-14, GH-15, GH-16)
- Sprint 14: ✅ Done (PR Merge & Comments)
- Sprint 13: ✅ Done (PR Management)
- Sprint 11: ✅ Done (Workflow Cancellation)
- See `PLAN.md` and `PROGRESS_BOARD.md` for detailed status
