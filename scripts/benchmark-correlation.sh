#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRIGGER_SCRIPT="${SCRIPT_DIR}/trigger-and-track.sh"

usage() {
  cat <<'EOF'
Usage: benchmark-correlation.sh [--runs <count>] [--workflow <file>] [--webhook-url <url>] [--output <file>]

Measures run_id retrieval timing by repeatedly invoking trigger-and-track.sh.
Reports individual measurements and statistics (mean, min, max, median).

Options:
  --runs <count>        Number of test iterations (default: 10, min: 10, max: 30)
  --workflow <file>     Target workflow (default: .github/workflows/dispatch-webhook.yml)
  --webhook-url <url>   Webhook endpoint (or set WEBHOOK_URL env var)
  --output <file>       Write JSON results to file (in addition to stdout)
  -h, --help            Show this help message
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

get_timestamp_ms() {
  local ts
  ts=$(date +%s%3N 2>/dev/null)
  if [[ "${ts}" =~ ^[0-9]+$ ]]; then
    echo "${ts}"
  else
    echo $(($(date +%s) * 1000))
  fi
}

compute_stats() {
  local -n values=$1
  if [[ ${#values[@]} -eq 0 ]]; then
    echo '{"mean_ms": 0, "min_ms": 0, "max_ms": 0, "median_ms": 0}'
    return
  fi

  python3 - "${values[@]}" <<'PY'
import sys
import json
import statistics

values = [int(v) for v in sys.argv[1:]]
result = {
    "mean_ms": int(statistics.mean(values)),
    "min_ms": min(values),
    "max_ms": max(values),
    "median_ms": int(statistics.median(values))
}
print(json.dumps(result))
PY
}

# Defaults
runs=10
workflow=".github/workflows/dispatch-webhook.yml"
webhook_url="${WEBHOOK_URL:-}"
output_file=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      runs="$2"
      shift 2
      ;;
    --workflow)
      workflow="$2"
      shift 2
      ;;
    --webhook-url)
      webhook_url="$2"
      shift 2
      ;;
    --output)
      output_file="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Validation
require_command jq
require_command python3

if [[ ! -x "${TRIGGER_SCRIPT}" ]]; then
  log "Missing executable trigger script at ${TRIGGER_SCRIPT}"
  exit 1
fi

if [[ -z "${webhook_url}" ]]; then
  log "Error: webhook URL is required (use --webhook-url or set WEBHOOK_URL)"
  exit 1
fi

if [[ ${runs} -lt 10 || ${runs} -gt 30 ]]; then
  log "Error: runs must be between 10 and 30"
  exit 1
fi

# Banner
log ""
log "Benchmark: run_id retrieval timing (${runs} runs)"
log "Workflow: ${workflow}"
log "Webhook: ${webhook_url}"
log ""

# Storage
declare -a measurements=()
declare -a elapsed_times=()
failed_count=0
benchmark_start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Run iterations
for ((i=1; i<=runs; i++)); do
  log "Run ${i}/${runs}..."

  start_ms=$(get_timestamp_ms)

  if result_json=$("${TRIGGER_SCRIPT}" --webhook-url "${webhook_url}" --workflow "${workflow}" --json-only); then
    end_ms=$(get_timestamp_ms)
    elapsed=$((end_ms - start_ms))

    run_id=$(jq -r '.run_id // empty' <<<"${result_json}")
    correlation_id=$(jq -r '.correlation_id // empty' <<<"${result_json}")

    if [[ -n "${run_id}" && -n "${correlation_id}" ]]; then
      elapsed_times+=("${elapsed}")
      measurement=$(jq -n \
        --arg iter "${i}" \
        --arg cid "${correlation_id}" \
        --arg rid "${run_id}" \
        --arg elapsed "${elapsed}" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{iteration: ($iter|tonumber), correlation_id: $cid, run_id: $rid, elapsed_ms: ($elapsed|tonumber), timestamp: $ts}')
      measurements+=("${measurement}")
      log "  ✓ Completed in ${elapsed} ms (run_id: ${run_id})"
    else
      log "  ✗ Failed to parse run_id/correlation_id from output"
      ((failed_count++))
    fi
  else
    log "  ✗ trigger-and-track.sh failed"
    ((failed_count++))
  fi

  # Delay between iterations (except after last run)
  if [[ ${i} -lt ${runs} ]]; then
    sleep 5
  fi
done

# Compute statistics
stats_json=$(compute_stats elapsed_times)

# Human-readable output
log ""
log "Results:"
log ""
printf "%-5s %-38s %-12s %-12s\n" "Run" "Correlation ID" "Run ID" "Elapsed (ms)"
printf "%-5s %-38s %-12s %-12s\n" "---" "--------------------------------------" "----------" "------------"

for measurement in "${measurements[@]}"; do
  iter=$(jq -r '.iteration' <<<"${measurement}")
  cid=$(jq -r '.correlation_id' <<<"${measurement}")
  rid=$(jq -r '.run_id' <<<"${measurement}")
  elapsed=$(jq -r '.elapsed_ms' <<<"${measurement}")
  printf "%-5s %-38s %-12s %-12s\n" "${iter}" "${cid}" "${rid}" "${elapsed}"
done

log ""
log "Statistics:"
log "  Mean:     $(jq -r '.mean_ms' <<<"${stats_json}") ms"
log "  Min:      $(jq -r '.min_ms' <<<"${stats_json}") ms"
log "  Max:      $(jq -r '.max_ms' <<<"${stats_json}") ms"
log "  Median:   $(jq -r '.median_ms' <<<"${stats_json}") ms"

if [[ ${failed_count} -gt 0 ]]; then
  log ""
  log "Failed runs: ${failed_count}"
fi

# JSON output
measurements_json=$(printf '%s\n' "${measurements[@]}" | jq -s '.')

final_json=$(jq -n \
  --arg bench "run_id_retrieval" \
  --arg wf "${workflow}" \
  --arg webhook "${webhook_url}" \
  --argjson runs "${runs}" \
  --arg ts "${benchmark_start}" \
  --argjson measurements "${measurements_json}" \
  --argjson stats "${stats_json}" \
  --argjson failed "${failed_count}" \
  '{
    benchmark: $bench,
    workflow: $wf,
    webhook_url: $webhook,
    runs: $runs,
    timestamp: $ts,
    measurements: $measurements,
    statistics: $stats,
    failed_runs: $failed
  }')

if [[ -n "${output_file}" ]]; then
  echo "${final_json}" > "${output_file}"
  log ""
  log "JSON results written to: ${output_file}"
fi
