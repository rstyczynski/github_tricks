#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRIGGER_SCRIPT="${SCRIPT_DIR}/trigger-and-track.sh"
FETCH_SCRIPT="${SCRIPT_DIR}/fetch-run-logs.sh"

usage() {
  cat <<'EOF'
Usage: benchmark-log-retrieval.sh [--runs <count>] [--webhook-url <url>] [--output <file>] [--store-dir <dir>]

Measures log retrieval timing by triggering workflows to completion, then measuring
fetch-run-logs.sh execution time. Reports individual measurements and statistics.

Options:
  --runs <count>        Number of test iterations (default: 10, min: 10, max: 30)
  --webhook-url <url>   Webhook endpoint (or set WEBHOOK_URL env var)
  --output <file>       Write JSON results to file (in addition to stdout)
  --store-dir <dir>     Directory for metadata/logs (default: runs)
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
webhook_url="${WEBHOOK_URL:-}"
output_file=""
store_dir="runs"
workflow=".github/workflows/long-run-logger.yml"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      runs="$2"
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
    --store-dir)
      store_dir="$2"
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
require_command gh
require_command python3

if [[ ! -x "${TRIGGER_SCRIPT}" ]]; then
  log "Missing executable trigger script at ${TRIGGER_SCRIPT}"
  exit 1
fi

if [[ ! -x "${FETCH_SCRIPT}" ]]; then
  log "Missing executable fetch script at ${FETCH_SCRIPT}"
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
log "Benchmark: Log retrieval timing (${runs} runs)"
log "Workflow: ${workflow}"
log "Webhook: ${webhook_url}"
log "Store Directory: ${store_dir}"
log ""

# Storage
declare -a measurements=()
declare -a elapsed_times=()
failed_count=0
benchmark_start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Run iterations
for ((i=1; i<=runs; i++)); do
  log "Run ${i}/${runs}..."

  # Setup phase (not measured): trigger workflow and wait for completion
  log "  Triggering workflow..."
  if ! trigger_result=$("${TRIGGER_SCRIPT}" \
    --webhook-url "${webhook_url}" \
    --workflow "${workflow}" \
    --input iterations=3 \
    --input sleep_seconds=2 \
    --store-dir "${store_dir}" \
    --json-only); then
    log "  ✗ Failed to trigger workflow"
    ((failed_count++))
    continue
  fi

  run_id=$(jq -r '.run_id // empty' <<<"${trigger_result}")
  correlation_id=$(jq -r '.correlation_id // empty' <<<"${trigger_result}")

  if [[ -z "${run_id}" || -z "${correlation_id}" ]]; then
    log "  ✗ Failed to parse run_id/correlation_id"
    ((failed_count++))
    continue
  fi

  log "  Waiting for completion (run_id: ${run_id})..."
  if ! gh run watch "${run_id}" --exit-status >/dev/null 2>&1; then
    log "  ✗ Workflow run failed"
    ((failed_count++))
    continue
  fi

  # Measurement phase: measure log retrieval time
  log "  Measuring log retrieval..."
  start_ms=$(get_timestamp_ms)

  if "${FETCH_SCRIPT}" --runs-dir "${store_dir}" --correlation-id "${correlation_id}" --json >/dev/null 2>&1; then
    end_ms=$(get_timestamp_ms)
    elapsed=$((end_ms - start_ms))

    # Get log archive size if available
    log_archive="${store_dir}/${correlation_id}/logs.zip"
    log_size_kb=0
    if [[ -f "${log_archive}" ]]; then
      log_size_kb=$(du -k "${log_archive}" | cut -f1)
    fi

    elapsed_times+=("${elapsed}")
    measurement=$(jq -n \
      --arg iter "${i}" \
      --arg cid "${correlation_id}" \
      --arg rid "${run_id}" \
      --arg elapsed "${elapsed}" \
      --arg size "${log_size_kb}" \
      --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '{iteration: ($iter|tonumber), correlation_id: $cid, run_id: $rid, elapsed_ms: ($elapsed|tonumber), log_size_kb: ($size|tonumber), timestamp: $ts}')
    measurements+=("${measurement}")
    log "  ✓ Completed in ${elapsed} ms (log size: ${log_size_kb} KB)"
  else
    log "  ✗ Failed to fetch logs"
    ((failed_count++))
  fi

  # Delay between iterations (except after last run)
  if [[ ${i} -lt ${runs} ]]; then
    sleep 10
  fi
done

# Compute statistics
stats_json=$(compute_stats elapsed_times)

# Human-readable output
log ""
log "Results:"
log ""
printf "%-5s %-38s %-12s %-12s %-13s\n" "Run" "Correlation ID" "Run ID" "Elapsed (ms)" "Log Size (KB)"
printf "%-5s %-38s %-12s %-12s %-13s\n" "---" "--------------------------------------" "----------" "------------" "-------------"

for measurement in "${measurements[@]}"; do
  iter=$(jq -r '.iteration' <<<"${measurement}")
  cid=$(jq -r '.correlation_id' <<<"${measurement}")
  rid=$(jq -r '.run_id' <<<"${measurement}")
  elapsed=$(jq -r '.elapsed_ms' <<<"${measurement}")
  size=$(jq -r '.log_size_kb' <<<"${measurement}")
  printf "%-5s %-38s %-12s %-12s %-13s\n" "${iter}" "${cid}" "${rid}" "${elapsed}" "${size}"
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
  --arg bench "log_retrieval" \
  --arg wf "${workflow}" \
  --arg webhook "${webhook_url}" \
  --arg dir "${store_dir}" \
  --argjson runs "${runs}" \
  --arg ts "${benchmark_start}" \
  --argjson measurements "${measurements_json}" \
  --argjson stats "${stats_json}" \
  --argjson failed "${failed_count}" \
  '{
    benchmark: $bench,
    workflow: $wf,
    webhook_url: $webhook,
    store_dir: $dir,
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
