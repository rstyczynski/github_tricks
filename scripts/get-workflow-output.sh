#!/usr/bin/env bash
# get-workflow-output.sh - Retrieve workflow output data via GitHub REST API
#
# Usage:
#   scripts/get-workflow-output.sh --run-id <run_id>
#   scripts/get-workflow-output.sh --correlation-id <uuid> --runs-dir <dir>
#   echo '{"run_id": 123}' | scripts/get-workflow-output.sh
#   scripts/get-workflow-output.sh --run-id <run_id> --json

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "${SCRIPT_DIR}/lib/run-utils.sh"

# Defaults
RUN_ID=""
CORRELATION_ID=""
RUNS_DIR="runs"
OUTPUT_FORMAT="human"
MAX_WAIT_SECONDS=0
POLL_INTERVAL=3

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Retrieve workflow output data via GitHub REST API.

Input methods (priority order):
  --run-id <id>              Use explicit run ID
  --correlation-id <uuid>    Load run ID from correlation metadata
  stdin                      Read JSON with run_id field

Options:
  --runs-dir <dir>           Directory for correlation metadata (default: runs)
  --json                     Output JSON format
  --wait <seconds>           Wait up to N seconds for workflow completion (default: 0)
  --poll-interval <seconds>  Polling interval in watch mode (default: 3)
  --help                     Show this help

Examples:
  # Direct run ID
  $(basename "$0") --run-id 1234567890

  # Via correlation ID
  $(basename "$0") --correlation-id <uuid> --runs-dir runs

  # From pipeline
  trigger-and-track.sh --json-only | $(basename "$0")

  # JSON output
  $(basename "$0") --run-id 1234567890 --json

  # Wait for completion
  $(basename "$0") --run-id 1234567890 --wait 300

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --correlation-id)
      CORRELATION_ID="$2"
      shift 2
      ;;
    --runs-dir)
      RUNS_DIR="$2"
      shift 2
      ;;
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --wait)
      MAX_WAIT_SECONDS="$2"
      shift 2
      ;;
    --poll-interval)
      POLL_INTERVAL="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Resolve run_id
if [[ -n "$RUN_ID" ]]; then
  resolved_run_id="$RUN_ID"
elif [[ -n "$CORRELATION_ID" ]]; then
  resolved_run_id=$(ru_read_run_id_from_runs_dir "$CORRELATION_ID" "$RUNS_DIR") || {
    echo "Error: No metadata found for correlation ID $CORRELATION_ID" >&2
    echo "Expected file: $(ru_metadata_path_for_correlation "$CORRELATION_ID" "$RUNS_DIR")" >&2
    exit 1
  }
elif [[ ! -t 0 ]]; then
  resolved_run_id=$(ru_read_run_id_from_stdin) || {
    echo "Error: Could not extract run_id from stdin JSON" >&2
    exit 1
  }
else
  echo "Error: No run_id provided. Use --run-id, --correlation-id, or pipe JSON to stdin" >&2
  echo "Use --help for usage information" >&2
  exit 1
fi

# Validate run_id
if [[ ! "$resolved_run_id" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid run_id: $resolved_run_id" >&2
  exit 1
fi

# Wait for completion if requested
if [[ "$MAX_WAIT_SECONDS" -gt 0 ]]; then
  elapsed=0
  while [[ $elapsed -lt $MAX_WAIT_SECONDS ]]; do
    run_status=$(gh run view "$resolved_run_id" --json status --jq '.status' 2>/dev/null || echo "unknown")

    if [[ "$run_status" == "completed" ]]; then
      break
    fi

    if [[ "$OUTPUT_FORMAT" == "human" ]]; then
      echo "Waiting for workflow completion... (${elapsed}s elapsed, status: $run_status)" >&2
    fi

    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  if [[ "$run_status" != "completed" ]]; then
    echo "Warning: Workflow not completed after ${MAX_WAIT_SECONDS}s (status: $run_status)" >&2
  fi
fi

# Fetch job data with retry
max_attempts=3
attempt=1
job_data=""

while [[ $attempt -le $max_attempts ]]; do
  if job_data=$(gh run view "$resolved_run_id" --json jobs 2>&1); then
    break
  else
    if [[ $attempt -lt $max_attempts ]]; then
      sleep $((attempt * 2))
      attempt=$((attempt + 1))
    else
      echo "Error: Failed to fetch run data for run_id $resolved_run_id after $max_attempts attempts" >&2
      echo "Error details: $job_data" >&2
      exit 1
    fi
  fi
done

# Extract first job (assuming single-job workflow)
job_count=$(echo "$job_data" | jq '.jobs | length')

if [[ "$job_count" -eq 0 ]]; then
  echo "Error: No jobs found for run_id $resolved_run_id" >&2
  exit 1
fi

# Get first job details
job=$(echo "$job_data" | jq '.jobs[0]')
job_status=$(echo "$job" | jq -r '.status')
job_conclusion=$(echo "$job" | jq -r '.conclusion // "none"')
job_name=$(echo "$job" | jq -r '.name')

# Check if workflow completed
if [[ "$job_status" != "completed" ]]; then
  echo "Error: Workflow job '$job_name' is not completed (status: $job_status)" >&2
  echo "Use --wait <seconds> to wait for completion" >&2
  exit 1
fi

# Check if workflow succeeded
if [[ "$job_conclusion" != "success" ]]; then
  echo "Error: Workflow job '$job_name' did not succeed (conclusion: $job_conclusion)" >&2
  exit 1
fi

# Extract outputs
outputs=$(echo "$job" | jq '.outputs // {}')
output_count=$(echo "$outputs" | jq 'length')

if [[ "$output_count" -eq 0 ]]; then
  echo "Error: No outputs found for run_id $resolved_run_id" >&2
  echo "Workflow may not have set any job outputs" >&2
  exit 1
fi

# Check for result_data output
if ! echo "$outputs" | jq -e '.result_data' >/dev/null 2>&1; then
  echo "Error: Expected output 'result_data' not found" >&2
  echo "Available outputs:" >&2
  echo "$outputs" | jq 'keys' >&2
  exit 1
fi

result_data=$(echo "$outputs" | jq -r '.result_data')

# Output
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  echo "$result_data"
else
  echo "Workflow Output for Run ID: $resolved_run_id"
  echo "Job: $job_name"
  echo "Status: $job_status"
  echo "Conclusion: $job_conclusion"
  echo ""
  echo "Result Data:"
  echo "$result_data" | jq .
fi
