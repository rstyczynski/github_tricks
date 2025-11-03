#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: stream-run-logs.sh [--run-id <id>] [--run-id-file <path>] [--runs-dir <dir> --correlation-id <id>] [--interval <seconds>] [--summary] [--once]

Streams live GitHub Actions logs for a workflow run. If --run-id is not supplied,
the script expects JSON on stdin with a top-level "run_id" field (e.g. output
from scripts/trigger-and-track.sh).

Options:
  --run-id <id>     Workflow run identifier to monitor.
  --run-id-file     File containing a run_id (raw or JSON with run_id field).
  --runs-dir <dir>  Directory containing stored run metadata (from --store-dir).
  --correlation-id  Correlation token used with --runs-dir to locate run metadata.
  --interval <sec>  Polling interval in seconds (default: 3).
  --summary         Print run / job status snapshot without fetching logs.
  --once            Perform a single poll (useful with --summary) and exit.
  -h, --help        Show this help message.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

read_run_id_from_stdin() {
  if [[ -t 0 ]]; then
    echo ""
    return
  fi

  local input
  input="$(cat)"
  if [[ -z "${input}" ]]; then
    echo ""
    return
  fi

  if echo "${input}" | jq -e '.' >/dev/null 2>&1; then
    echo "${input}" | jq -r '.run_id // empty'
    return
  fi

  echo "${input}" | jq -R 'fromjson? | select(.run_id != null) | .run_id' | head -n1
}

print_summary() {
  local run_json="$1"
  local jobs_json="$2"

  local run_status run_conclusion run_url
  run_status="$(jq -r '.status // "unknown"' <<<"${run_json}")"
  run_conclusion="$(jq -r '.conclusion // "pending"' <<<"${run_json}")"
  run_url="$(jq -r '.html_url // ""' <<<"${run_json}")"

  printf "Run %s – status: %s, conclusion: %s\n" "${run_id}" "${run_status}" "${run_conclusion}"
  if [[ -n "${run_url}" ]]; then
    printf "URL: %s\n" "${run_url}"
  fi

  jq -r '.[] | "- " + (.name // "job") + ": " + (.status // "unknown")' <<<"${jobs_json}"
}

stream_job_logs() {
  local job_json="$1"
  local tmp_dir="$2"

  local job_id job_name job_status
  job_id="$(jq -r '.id' <<<"${job_json}")"
  job_name="$(jq -r '.name // ("job-" + (.id|tostring))' <<<"${job_json}")"
  job_status="$(jq -r '.status // "unknown"' <<<"${job_json}")"

  local log_gz log_plain offset_file header_flag
  log_gz="${tmp_dir}/${job_id}.gz"
  log_plain="${tmp_dir}/${job_id}.log"
  offset_file="${tmp_dir}/${job_id}.offset"
  header_flag="${tmp_dir}/${job_id}.header"

  if ! gh api "repos/${repo}/actions/jobs/${job_id}/logs" --silent >"${log_gz}" 2>/dev/null; then
    return
  fi

  if ! gzip -dc "${log_gz}" >"${log_plain}" 2>/dev/null; then
    return
  fi

  local current_size previous_size
  current_size="$(wc -c <"${log_plain}")"
  previous_size=0
  if [[ -f "${offset_file}" ]]; then
    previous_size="$(cat "${offset_file}")"
  fi

  if (( current_size == 0 || current_size == previous_size )); then
    return
  fi

  if [[ ! -f "${header_flag}" ]]; then
    printf "\n=== %s (status: %s) ===\n" "${job_name}" "${job_status}"
    touch "${header_flag}"
  fi

  tail -c +"$((previous_size + 1))" "${log_plain}" | sed "s/^/[${job_name}] /"
  echo "${current_size}" >"${offset_file}"
}

run_id=""
interval=3
summary_mode=false
once=false
run_id_file=""
runs_dir=""
correlation_lookup=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="$2"
      shift 2
      ;;
    --interval)
      interval="$2"
      shift 2
      ;;
    --summary)
      summary_mode=true
      shift
      ;;
    --once)
      once=true
      shift
      ;;
    --run-id-file)
      run_id_file="$2"
      shift 2
      ;;
    --runs-dir)
      runs_dir="$2"
      shift 2
      ;;
    --correlation-id)
      correlation_lookup="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_command gh
require_command jq
require_command gzip
require_command tail

if [[ -n "${runs_dir}" && -z "${correlation_lookup}" && -z "${run_id}" && -z "${run_id_file}" ]]; then
  echo "Provide --correlation-id when using --runs-dir (or specify --run-id/--run-id-file)." >&2
  exit 1
fi

read_run_id_from_file() {
  local file_path="$1"
  if [[ ! -f "${file_path}" ]]; then
    echo ""
    return
  fi
  if jq -e '.run_id' "${file_path}" >/dev/null 2>&1; then
    jq -r '.run_id // empty' "${file_path}"
  else
    head -n1 "${file_path}" | tr -d '[:space:]'
  fi
}

if [[ -z "${run_id}" && -n "${run_id_file}" ]]; then
  run_id="$(read_run_id_from_file "${run_id_file}")"
fi

if [[ -z "${run_id}" && -n "${runs_dir}" && -n "${correlation_lookup}" ]]; then
  candidate_file="${runs_dir%/}/${correlation_lookup}.json"
  run_id="$(read_run_id_from_file "${candidate_file}")"
  if [[ -z "${run_id}" ]]; then
    echo "No run record for correlation ${correlation_lookup} in ${runs_dir}" >&2
    exit 1
  fi
fi

if [[ -z "${run_id}" ]]; then
  run_id="$(read_run_id_from_stdin)"
fi

if [[ -z "${run_id}" ]]; then
  echo "Run ID not provided. Use --run-id or pipe JSON with run_id." >&2
  exit 1
fi

if ! [[ "${interval}" =~ ^[0-9]+$ ]]; then
  echo "Interval must be an integer number of seconds." >&2
  exit 1
fi

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

echo "Streaming logs for run ${run_id} in ${repo}"

start_time=$SECONDS
spinner_chars=$'|/-\\'
spinner_index=0
progress_message="Polling run ${run_id}"

show_spinner() {
  local elapsed=$(( SECONDS - start_time ))
  local char=${spinner_chars:spinner_index:1}
  printf '\r%s %s (elapsed %ss)' "${char}" "${progress_message}" "${elapsed}"
  spinner_index=$(( (spinner_index + 1) % ${#spinner_chars} ))
}

while :; do
  show_spinner
  run_json="$(gh api "repos/${repo}/actions/runs/${run_id}" 2>/dev/null || true)"
  if [[ -z "${run_json}" ]]; then
    echo "Unable to fetch run ${run_id}. Ensure it exists and you have access." >&2
    exit 1
  fi

  run_status="$(jq -r '.status // "unknown"' <<<"${run_json}")"
  run_conclusion="$(jq -r '.conclusion // ""' <<<"${run_json}")"

  jobs_json="$(gh api "repos/${repo}/actions/runs/${run_id}/jobs" --paginate --jq '.jobs[] | {id: .id, name: .name, status: .status, started_at: .started_at}' 2>/dev/null | jq -s '.' )"
  if [[ -z "${jobs_json}" || "${jobs_json}" == "null" ]]; then
    jobs_json="[]"
  fi

  job_count=$(jq 'length' <<<"${jobs_json}" 2>/dev/null || echo 0)
  progress_message="Polling run ${run_id} (jobs: ${job_count})"

  if [[ "${summary_mode}" == true ]]; then
    print_summary "${run_json}" "${jobs_json}"
  else
    jq -c '.[]' <<<"${jobs_json}" | while read -r job; do
      [[ -z "${job}" ]] && continue
      stream_job_logs "${job}" "${tmp_dir}"
    done
  fi

  if [[ "${run_status}" == "completed" || "${run_status}" == "completed" && -n "${run_conclusion}" ]]; then
    printf '\r'
    if [[ "${summary_mode}" == false ]]; then
      printf "\nRun completed with conclusion: %s\n" "${run_conclusion:-unknown}"
    fi
    break
  fi

  if [[ "${once}" == true ]]; then
    printf '\r'
    break
  fi

  sleep "${interval}"
done

printf '\r'
