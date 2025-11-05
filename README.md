# GitHub Workflow Experimentation

Tools and techniques for interacting with GitHub Actions workflows via API and CLI.

## Features

- **Trigger & Track**: Dispatch workflows and correlate run IDs (UUID-based, median 17s, see `tests/correlation-timings.json`)
- **Post-Run Log Retrieval**: Fetch and aggregate workflow logs after completion
- **Job Monitoring**: View workflow job phases and status (gh CLI or curl-based)
- **Benchmarking**: Measure timing for correlation and log retrieval

### Known Limitations (GitHub API)

- **No real-time log streaming**: Logs only available after job completion (Sprint 2, 6 - FAILED)
- **Webhooks require public endpoints**: Local webhook-based correlation not feasible (Sprint 7 - FAILED)

## Quick Start

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
```

## Key Scripts

**Working Tools:**
- `trigger-and-track.sh` - Trigger workflow and retrieve run ID via UUID correlation
- `fetch-run-logs.sh` - Download and aggregate logs after run completion
- `view-run-jobs.sh` - Display job phases and status (gh CLI with browser auth)
- `view-run-jobs-curl.sh` - Display job phases and status (curl with token auth)
- `benchmark-correlation.sh` - Measure run ID retrieval timing
- `benchmark-log-retrieval.sh` - Measure log retrieval timing

**Diagnostic/Failed Feature Scripts:**
- `stream-run-logs.sh` - Stub demonstrating real-time streaming is not supported
- `probe-job-logs.sh` - Proves job logs API only works after completion
- `manage-actions-webhook.sh` - Webhook management (requires public endpoint)

## Requirements

- GitHub CLI (`gh`)
- `jq` for JSON processing
- Valid GitHub token with workflow permissions

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

![Agentic Cooperation Workflow](rules/images/agentic_cooperation_v1.png)

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
- `progress/` - Complete audit trail of all sprints (52 documents):
  - `sprint_N_design.md` - Design documents for each sprint
  - `sprint_N_implementation.md` - Implementation notes and summaries
  - `inception_sprint_N_*.md` - Requirements definition phase logs
  - `elaboration_sprint_N_*.md` - Design phase chat logs
  - `construction_sprint_N_*.md` - Implementation phase chat logs
  - `*_review_*.md` - Product Owner review feedback
