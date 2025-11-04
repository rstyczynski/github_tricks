#!/usr/bin/env bash
set -euo pipefail

# View workflow job phases with status, mimicking 'gh run view' with enhanced flexibility.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "$SCRIPT_DIR/lib/run-utils.sh"

# Default values
RUNS_DIR="runs"
OUTPUT_FORMAT="table"
VERBOSE=false
WATCH=false
RUN_ID=""
CORRELATION_ID=""

show_help() {
  cat <<'EOF'
Usage: view-run-jobs.sh [OPTIONS]

View workflow job phases with status, mimicking 'gh run view' with enhanced flexibility.

INPUT (first match wins):
  --run-id <id>           Workflow run ID (numeric)
  --correlation-id <uuid> Load run_id from stored metadata
  stdin                   JSON from trigger-and-track.sh

OPTIONS:
  --runs-dir <dir>        Base directory for metadata (default: runs)
  --json                  Output JSON format
  --verbose               Include step-level details
  --watch                 Poll for updates until completion (3s interval)
  --help                  Show this help message

EXAMPLES:
  # View jobs for specific run ID
  view-run-jobs.sh --run-id 1234567890

  # View jobs using correlation ID
  view-run-jobs.sh --correlation-id <uuid> --runs-dir runs

  # Watch job progress in real-time
  view-run-jobs.sh --run-id 1234567890 --watch

  # Verbose output with step details
  view-run-jobs.sh --run-id 1234567890 --verbose

  # JSON output for programmatic use
  view-run-jobs.sh --run-id 1234567890 --json | jq '.jobs[].name'

  # Integration with trigger-and-track
  trigger-and-track.sh --webhook-url "$WEBHOOK_URL" --store-dir runs --json-only \
    | view-run-jobs.sh --watch
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
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
    --verbose)
      VERBOSE=true
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      printf 'Use --help for usage information\n' >&2
      exit 1
      ;;
  esac
done

# Require dependencies
ru_require_command gh
ru_require_command jq

# Resolve run_id from input sources (priority order)
resolve_run_id() {
  local resolved_id=""

  # 1. Explicit --run-id
  if [[ -n "${RUN_ID}" ]]; then
    resolved_id="${RUN_ID}"
  # 2. --correlation-id from metadata
  elif [[ -n "${CORRELATION_ID}" ]]; then
    resolved_id="$(ru_read_run_id_from_runs_dir "${RUNS_DIR}" "${CORRELATION_ID}")"
    if [[ -z "${resolved_id}" ]]; then
      printf 'Error: No metadata found for correlation ID %s\n' "${CORRELATION_ID}" >&2
      printf 'Expected file: %s\n' "$(ru_metadata_path_for_correlation "${RUNS_DIR}" "${CORRELATION_ID}")" >&2
      exit 1
    fi
  # 3. stdin JSON
  elif ! [[ -t 0 ]]; then
    resolved_id="$(ru_read_run_id_from_stdin)"
    if [[ -z "${resolved_id}" ]]; then
      printf 'Error: Could not extract run_id from stdin JSON\n' >&2
      exit 1
    fi
  # 4. Interactive prompt (if terminal)
  elif [[ -t 0 ]]; then
    printf 'Enter run ID: ' >&2
    read -r resolved_id
    if [[ -z "${resolved_id}" ]]; then
      printf 'Error: Run ID is required\n' >&2
      exit 1
    fi
  else
    printf 'Error: No run ID provided (use --run-id, --correlation-id, or pipe JSON via stdin)\n' >&2
    exit 1
  fi

  printf '%s' "${resolved_id}"
}

# Fetch job data from GitHub
fetch_job_data() {
  local run_id="$1"
  local max_retries=3
  local retry_count=0
  local backoff=1

  while [[ $retry_count -lt $max_retries ]]; do
    if gh run view "$run_id" --json status,conclusion,name,createdAt,jobs 2>/dev/null; then
      return 0
    fi

    retry_count=$((retry_count + 1))
    if [[ $retry_count -lt $max_retries ]]; then
      sleep "$backoff"
      backoff=$((backoff * 2))
    fi
  done

  printf 'Error: Run ID %s not found or network error after %d attempts\n' "$run_id" "$max_retries" >&2
  exit 1
}

# Calculate duration between two timestamps
calculate_duration() {
  local started="$1"
  local completed="$2"

  if [[ -z "${completed}" || "${completed}" == "null" ]]; then
    printf -- '-'
    return
  fi

  if [[ -z "${started}" || "${started}" == "null" ]]; then
    printf -- '-'
    return
  fi

  # Convert ISO8601 to epoch seconds
  local start_epoch completed_epoch duration_sec

  if date --version >/dev/null 2>&1; then
    # GNU date
    start_epoch=$(date -d "$started" +%s 2>/dev/null || echo "0")
    completed_epoch=$(date -d "$completed" +%s 2>/dev/null || echo "0")
  else
    # BSD date (macOS)
    start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${started%.*}Z" +%s 2>/dev/null || echo "0")
    completed_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${completed%.*}Z" +%s 2>/dev/null || echo "0")
  fi

  if [[ "$start_epoch" -eq 0 || "$completed_epoch" -eq 0 ]]; then
    printf -- '-'
    return
  fi

  duration_sec=$((completed_epoch - start_epoch))
  printf '%ds' "$duration_sec"
}

# Format output as human-readable table
format_table() {
  local data="$1"
  local run_id run_name status started

  run_id=$(echo "$data" | jq -r '.jobs[0].run_id // "unknown"')
  run_name=$(echo "$data" | jq -r '.name // "unknown"')
  status=$(echo "$data" | jq -r '.status // "unknown"')
  started=$(echo "$data" | jq -r '.createdAt // "-"')

  printf 'Run: %s (%s)\n' "$run_id" "$run_name"
  printf 'Status: %s\n' "$status"
  printf 'Started: %s\n' "$started"
  printf '\n'

  # Table header
  printf 'Job\tStatus\tConclusion\tStarted\tCompleted\n'

  # Table rows
  echo "$data" | jq -r '.jobs[] | [
    .name,
    .status // "-",
    .conclusion // "-",
    .started_at // "-",
    .completed_at // "-"
  ] | @tsv' | while IFS=$'\t' read -r name status_val conclusion started_val completed; do
    # Truncate long job names
    if [[ ${#name} -gt 25 ]]; then
      name="${name:0:22}..."
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$status_val" "$conclusion" "$started_val" "$completed"
  done | column -t -s $'\t'
}

# Format output with verbose step details
format_verbose() {
  local data="$1"
  local run_id run_name status started

  run_id=$(echo "$data" | jq -r '.jobs[0].run_id // "unknown"')
  run_name=$(echo "$data" | jq -r '.name // "unknown"')
  status=$(echo "$data" | jq -r '.status // "unknown"')
  started=$(echo "$data" | jq -r '.createdAt // "-"')

  printf 'Run: %s (%s)\n' "$run_id" "$run_name"
  printf 'Status: %s\n' "$status"
  printf 'Started: %s\n' "$started"
  printf '\n'

  # Iterate through jobs
  echo "$data" | jq -c '.jobs[]' | while IFS= read -r job; do
    local job_name job_status job_started
    job_name=$(echo "$job" | jq -r '.name')
    job_status=$(echo "$job" | jq -r '.status // "-"')
    job_started=$(echo "$job" | jq -r '.started_at // "-"')

    printf 'Job: %s\n' "$job_name"
    printf '  Status: %s\n' "$job_status"
    printf '  Started: %s\n' "$job_started"
    printf '\n'

    # Check if steps exist
    local step_count
    step_count=$(echo "$job" | jq '.steps | length')
    if [[ "$step_count" -gt 0 ]]; then
      printf '  Step\tStatus\tConclusion\tDuration\n'
      echo "$job" | jq -r '.steps[] | [
        (.number|tostring) + ". " + .name,
        .status // "-",
        .conclusion // "-",
        .started_at // "null",
        .completed_at // "null"
      ] | @tsv' | while IFS=$'\t' read -r step_name step_status step_conclusion step_started step_completed; do
        local duration
        duration=$(calculate_duration "$step_started" "$step_completed")
        printf '  %s\t%s\t%s\t%s\n' "$step_name" "$step_status" "$step_conclusion" "$duration"
      done | column -t -s $'\t'
      printf '\n'
    fi
  done
}

# Format output as JSON
format_json() {
  local data="$1"

  echo "$data" | jq '{
    run_id: (.jobs[0].run_id // null),
    run_name: .name,
    status: .status,
    conclusion: .conclusion,
    started_at: .createdAt,
    completed_at: null,
    jobs: [.jobs[] | {
      id: .id,
      name: .name,
      status: .status,
      conclusion: .conclusion,
      started_at: .started_at,
      completed_at: .completed_at,
      steps: [.steps[]? | {
        name: .name,
        status: .status,
        conclusion: .conclusion,
        number: .number,
        started_at: .started_at,
        completed_at: .completed_at
      }]
    }]
  }'
}

# Watch mode: poll and refresh display
watch_loop() {
  local run_id="$1"

  while true; do
    # Fetch current data
    local data
    data=$(fetch_job_data "$run_id")

    # Check run status
    local run_status
    run_status=$(echo "$data" | jq -r '.status // "unknown"')

    # Clear screen and display
    if [[ -t 1 ]]; then
      clear
    fi

    if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
      format_json "$data"
    elif [[ "${VERBOSE}" == true ]]; then
      format_verbose "$data"
    else
      format_table "$data"
    fi

    # Exit if run completed
    if [[ "$run_status" == "completed" ]]; then
      break
    fi

    # Wait before next poll
    sleep 3
  done
}

# Main execution
main() {
  local run_id
  run_id=$(resolve_run_id)

  if [[ "${WATCH}" == true ]]; then
    watch_loop "$run_id"
  else
    local data
    data=$(fetch_job_data "$run_id")

    if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
      format_json "$data"
    elif [[ "${VERBOSE}" == true ]]; then
      format_verbose "$data"
    else
      format_table "$data"
    fi
  fi
}

main
