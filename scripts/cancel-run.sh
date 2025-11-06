#!/usr/bin/env bash
set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "$SCRIPT_DIR/lib/run-utils.sh"

# Default values
RUNS_DIR="runs"
FORCE=false
WAIT=false
JSON_OUTPUT=false
RUN_ID=""
CORRELATION_ID=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Cancel GitHub Actions workflow run.

INPUT (first match wins):
  --run-id <id>           Workflow run ID (numeric)
  --correlation-id <uuid> Load run_id from stored metadata
  stdin                   JSON from trigger-and-track.sh

OPTIONS:
  --runs-dir <dir>        Base directory for metadata (default: runs)
  --force                 Use force-cancel (bypasses always() conditions)
  --wait                  Poll until cancellation completes
  --json                  Output JSON format
  --help                  Show this help message

EXAMPLES:
  # Cancel by run ID
  $(basename "$0") --run-id 1234567890

  # Cancel using correlation ID
  $(basename "$0") --correlation-id <uuid> --runs-dir runs

  # Cancel and wait for completion
  $(basename "$0") --run-id 1234567890 --wait

  # Force cancel stuck workflow
  $(basename "$0") --run-id 1234567890 --force

  # Pipeline integration
  scripts/trigger-and-track.sh --webhook-url "\$URL" --json-only \\
    | $(basename "$0") --json
EOF
}

resolve_run_id_input() {
  local run_id=""
  
  # Priority 1: --run-id flag
  if [[ -n "$RUN_ID" ]]; then
    run_id="$RUN_ID"
  # Priority 2: --correlation-id flag
  elif [[ -n "$CORRELATION_ID" ]]; then
    run_id=$(ru_read_run_id_from_runs_dir "$RUNS_DIR" "$CORRELATION_ID")
    if [[ -z "$run_id" ]]; then
      printf 'Error: No metadata found for correlation ID %s in %s/\n' \
        "$CORRELATION_ID" "$RUNS_DIR" >&2
      exit 1
    fi
  # Priority 3: stdin JSON
  elif [[ ! -t 0 ]]; then
    run_id=$(ru_read_run_id_from_stdin)
    if [[ -z "$run_id" ]]; then
      printf 'Error: Could not extract run_id from stdin JSON\n' >&2
      exit 1
    fi
  # Priority 4: Interactive prompt
  elif [[ -t 0 ]]; then
    printf 'Enter workflow run ID: ' >&2
    read -r run_id
  fi
  
  if [[ -z "$run_id" ]]; then
    printf 'Error: No run ID provided\n' >&2
    usage >&2
    exit 2
  fi
  
  printf '%s' "$run_id"
}

get_run_status() {
  local run_id="$1"
  local status conclusion url
  
  # Query current status and URL before cancellation
  if ! read -r status conclusion url < <(gh run view "$run_id" \
    --json status,conclusion,url \
    --jq '[.status, (.conclusion // "null"), .url] | join(" ")' 2>/dev/null); then
    printf 'Error: Failed to get status for run ID %s\n' "$run_id" >&2
    return 1
  fi
  
  printf '%s %s %s' "$status" "$conclusion" "$url"
}

cancel_run_gh() {
  local run_id="$1"
  local force="${2:-false}"
  
  if [[ "$force" == "true" ]]; then
    # Use force-cancel endpoint via gh api
    local http_code
    http_code=$(gh api -X POST \
      "/repos/{owner}/{repo}/actions/runs/$run_id/force-cancel" \
      --silent \
      -i 2>&1 | grep -i "^HTTP/" | awk '{print $2}' || echo "000")
    
    if [[ "$http_code" == "202" ]]; then
      return 0
    else
      printf 'Error: Failed to force-cancel run %s (HTTP %s)\n' "$run_id" "$http_code" >&2
      return 1
    fi
  else
    # Use standard gh run cancel
    if gh run cancel "$run_id" 2>/dev/null; then
      return 0
    else
      local exit_code=$?
      # Try to get more specific error
      if gh run view "$run_id" --json status,conclusion -q '.status' 2>/dev/null | grep -q "completed"; then
        printf 'Error: Cannot cancel run %s - workflow already completed\n' "$run_id" >&2
      else
        printf 'Error: Failed to cancel run %s\n' "$run_id" >&2
      fi
      return "$exit_code"
    fi
  fi
}

wait_for_cancellation() {
  local run_id="$1"
  local max_wait=60  # 60 seconds max
  local interval=2   # Check every 2 seconds
  local elapsed=0
  local start_time
  start_time=$(date +%s)
  
  [[ "$JSON_OUTPUT" != "true" ]] && printf 'Waiting for cancellation to complete...\n' >&2
  
  while [[ $elapsed -lt $max_wait ]]; do
    local status conclusion
    
    # Query run status
    if read -r status conclusion < <(gh run view "$run_id" --json status,conclusion \
      --jq '[.status, (.conclusion // "null")] | join(" ")' 2>/dev/null); then
      
      if [[ "$status" == "completed" ]] && [[ "$conclusion" == "cancelled" ]]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        [[ "$JSON_OUTPUT" != "true" ]] && \
          printf 'Cancellation completed in %d seconds\n' "$duration" >&2
        printf '%d' "$duration"
        return 0
      fi
    fi
    
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  
  [[ "$JSON_OUTPUT" != "true" ]] && \
    printf 'Warning: Cancellation did not complete within %d seconds\n' "$max_wait" >&2
  return 1
}

format_output_human() {
  local run_id="$1"
  local status_before="$2"
  local url="$3"
  local waited="$4"
  local final_status="${5:-}"
  local final_conclusion="${6:-}"
  local duration="${7:-}"
  
  printf 'Cancelling workflow run: %s\n' "$run_id"
  printf 'Status before cancellation: %s\n' "$status_before"
  printf 'Cancellation requested (HTTP 202 Accepted)\n'
  printf 'Run URL: %s\n' "$url"
  
  if [[ "$waited" == "true" ]]; then
    printf '\nFinal status: %s\n' "$final_status"
    printf 'Final conclusion: %s\n' "$final_conclusion"
    if [[ -n "$duration" ]]; then
      printf 'Cancellation completed in %s seconds\n' "$duration"
    fi
  fi
}

format_output_json() {
  local run_id="$1"
  local status_before="$2"
  local url="$3"
  local waited="$4"
  local force="$5"
  local final_status="${6:-null}"
  local final_conclusion="${7:-null}"
  local duration="${8:-null}"
  
  # Build JSON output
  cat <<EOF
{
  "run_id": $run_id,
  "status_before": "$status_before",
  "cancellation_requested": true,
  "force": $force,
  "url": "$url",
  "waited": $waited,
  "final_status": $(if [[ "$final_status" != "null" ]]; then printf '"%s"' "$final_status"; else printf 'null'; fi),
  "final_conclusion": $(if [[ "$final_conclusion" != "null" ]]; then printf '"%s"' "$final_conclusion"; else printf 'null'; fi),
  "cancellation_duration_seconds": $(if [[ "$duration" != "null" ]]; then printf '%s' "$duration"; else printf 'null'; fi)
}
EOF
}

main() {
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
      --force)
        FORCE=true
        shift
        ;;
      --wait)
        WAIT=true
        shift
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        printf 'Error: Unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
  
  # Resolve run ID from various input sources
  local run_id
  run_id=$(resolve_run_id_input)
  
  # Get status before cancellation
  local status_before url
  if ! read -r status_before _ url < <(get_run_status "$run_id"); then
    exit 1
  fi
  
  # Cancel the run
  if ! cancel_run_gh "$run_id" "$FORCE"; then
    exit 1
  fi
  
  # Wait for cancellation if requested
  local final_status="" final_conclusion="" duration=""
  if [[ "$WAIT" == "true" ]]; then
    if duration=$(wait_for_cancellation "$run_id"); then
      # Get final status
      read -r final_status final_conclusion < <(gh run view "$run_id" \
        --json status,conclusion \
        --jq '[.status, (.conclusion // "null")] | join(" ")' 2>/dev/null)
    fi
  fi
  
  # Format output
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    format_output_json "$run_id" "$status_before" "$url" "$WAIT" "$FORCE" \
      "$final_status" "$final_conclusion" "$duration"
  else
    format_output_human "$run_id" "$status_before" "$url" "$WAIT" \
      "$final_status" "$final_conclusion" "$duration"
  fi
}

main "$@"
