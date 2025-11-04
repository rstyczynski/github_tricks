# GitHub Workflow Experimentation

Tools and techniques for interacting with GitHub Actions workflows via API and CLI.

## Features

- **Trigger & Track**: Dispatch workflows and correlate run IDs
- **Log Retrieval**: Stream logs in real-time or fetch after completion
- **Job Monitoring**: View workflow job phases and status
- **Benchmarking**: Measure timing for correlation and log retrieval

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

# Stream logs in real-time
./scripts/stream-run-logs.sh <run_id>
```

## Key Scripts

- `trigger-and-track.sh` - Trigger workflow and retrieve run ID
- `view-run-jobs.sh` - Display job phases and status
- `stream-run-logs.sh` - Stream workflow logs during execution
- `benchmark-correlation.sh` - Measure run ID retrieval timing
- `benchmark-log-retrieval.sh` - Measure log retrieval timing

## Requirements

- GitHub CLI (`gh`)
- `jq` for JSON processing
- Valid GitHub token with workflow permissions

## Contributing

### Adding New Features

1. Add feature request to `SRS.md` Backlog section (following GH-N numbering)
2. Define scope, requirements, and acceptance criteria
3. Update `PLAN.md` to schedule for iteration

### Working with AI Agents

To trigger an AI agent to implement features:

1. Provide agent with `AGENTS.md` instructions
2. Agent reads `SRS.md` (scope), `PLAN.md` (iterations), and `rules/` (process)
3. Agent follows the full development lifecycle per `rules/GENERAL_RULES*`

**For Operators**: See `HUMANS.md` and `rules/PRODUCT_OWNER_GUIDE*` for managing the project through iterations.

## Documentation

See `SRS.md` for full specification and `rules/` for development guidelines.
