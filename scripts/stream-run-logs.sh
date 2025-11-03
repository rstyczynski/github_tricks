#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: stream-run-logs.sh [--run-id <id>] [--run-id-file <path>] [--runs-dir <dir> --correlation-id <id>] [--summary]

Streams live GitHub Actions logs for a workflow run. If --run-id is not supplied,
the script expects JSON on stdin with a top-level "run_id" field (e.g. output
from scripts/trigger-and-track.sh).

Options:
  --run-id <id>     Workflow run identifier to monitor.
  --run-id-file     File containing a run_id (raw or JSON with run_id field).
  --runs-dir <dir>  Directory containing stored run metadata (from --store-dir).
  --correlation-id  Correlation token used with --runs-dir to locate run metadata.
  --summary         Print run / job status snapshot without streaming logs.
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

  jq -r '.[] | "- " + (.name // "job") + ": " + (.status // "unknown") + ((.conclusion // "") | select(length > 0) | ", conclusion: " + .)' <<<"${jobs_json}"
}

run_id=""
summary_mode=false
run_id_file=""
runs_dir=""
correlation_lookup=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="$2"
      shift 2
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
    --summary)
      summary_mode=true
      shift
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

if [[ -n "${runs_dir}" && -z "${correlation_lookup}" && -z "${run_id}" && -z "${run_id_file}" ]]; then
  echo "Provide --correlation-id when using --runs-dir (or specify --run-id/--run-id-file)." >&2
  exit 1
fi

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

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

if [[ "${summary_mode}" == false ]]; then
  gh run watch "${run_id}" --exit-status --log
  exit $?
fi

run_json="$(gh api "repos/${repo}/actions/runs/${run_id}" 2>/dev/null || true)"
if [[ -z "${run_json}" ]]; then
  echo "Unable to fetch run ${run_id}. Ensure it exists and you have access." >&2
  exit 1
fi

jobs_json="$(gh api "repos/${repo}/actions/runs/${run_id}/jobs" --paginate --jq '.jobs[] | {id: .id, name: .name, status: .status, conclusion: .conclusion, started_at: .started_at}' 2>/dev/null | jq -s '.' )"
if [[ -z "${jobs_json}" || "${jobs_json}" == "null" ]]; then
  jobs_json="[]"
fi

print_summary "${run_json}" "${jobs_json}"
