#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: process-workflow-webhook.sh [--file <payload.json>] [--runs-dir <dir>]

Reads a workflow_run webhook payload (from file or stdin), extracts the run_id,
infers the correlation UUID from the run name, and stores the event under runs/.

Options:
  --file <path>    Read payload from file instead of stdin
  --runs-dir <dir> Directory for run metadata (default: runs)
  -h, --help       Show help
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

payload_path=""
runs_dir="runs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      payload_path="$2"
      shift 2
      ;;
    --runs-dir)
      runs_dir="$2"
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

require_command jq
require_command python3

payload=""
if [[ -n "${payload_path}" ]]; then
  if [[ ! -f "${payload_path}" ]]; then
    log "Payload file not found: ${payload_path}"
    exit 1
  fi
  payload="$(cat "${payload_path}")"
else
  if [[ -t 0 ]]; then
    log "No payload provided. Use --file or pipe JSON via stdin."
    exit 1
  fi
  payload="$(cat)"
fi

if [[ -z "${payload}" ]]; then
  log "Payload is empty."
  exit 1
fi

if ! jq -e '.workflow_run' >/dev/null 2>&1 <<<"${payload}"; then
  log "Payload does not appear to be a workflow_run event."
  exit 1
fi

run_id="$(jq -r '.workflow_run.id' <<<"${payload}")"
run_name="$(jq -r '.workflow_run.name // ""' <<<"${payload}")"
workflow_path="$(jq -r '.workflow_run.path // ""' <<<"${payload}")"
status="$(jq -r '.workflow_run.status // ""' <<<"${payload}")"
run_attempt="$(jq -r '.workflow_run.run_attempt // 1' <<<"${payload}")"
repo_fullname="$(jq -r '.repository.full_name // ""' <<<"${payload}")"
received_at="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"

correlation_id="$(
  python3 - "$run_name" <<'PY'
import re
import sys

name = sys.argv[1]
match = re.search(r'([0-9a-fA-F-]{36})', name)
if match:
    print(match.group(1).upper())
PY
)"

if [[ -z "${correlation_id}" ]]; then
  correlation_id="unknown-${run_id}"
fi

runs_dir="${runs_dir%/}"
base_dir="${runs_dir}/${correlation_id}"
event_dir="${base_dir}/webhook"
mkdir -p "${event_dir}"

event_file="${event_dir}/${received_at}.json"
printf '%s\n' "${payload}" >"${event_file}"

metadata_file="${base_dir}.json"
if [[ -f "${metadata_file}" ]]; then
  updated="$(
    jq \
      --arg run_id "${run_id}" \
      --arg status "${status}" \
      --arg attempt "${run_attempt}" \
      --arg received "${received_at}" \
      --arg workflow "${workflow_path}" \
      --arg repo "${repo_fullname}" \
      '
      .run_id = (if .run_id == null or .run_id == "" then $run_id else .run_id end) |
      .webhook_run_id = $run_id |
      .webhook_status = $status |
      .webhook_attempt = $attempt |
      .webhook_received_at = $received |
      (if has("workflow") then . else . + {workflow: $workflow} end) |
      (if has("repo") then . else . + {repo: $repo} end)
      ' "${metadata_file}"
  )"
else
  mkdir -p "${runs_dir}"
  updated="$(jq -n \
    --arg run_id "${run_id}" \
    --arg correlation_id "${correlation_id}" \
    --arg status "${status}" \
    --arg attempt "${run_attempt}" \
    --arg received "${received_at}" \
    --arg workflow "${workflow_path}" \
    --arg repo "${repo_fullname}" \
    '{
      run_id: $run_id,
      correlation_id: $correlation_id,
      workflow: $workflow,
      repo: $repo,
      webhook_run_id: $run_id,
      webhook_status: $status,
      webhook_attempt: $attempt,
      webhook_received_at: $received
    }')"
fi

printf '%s\n' "${updated}" >"${metadata_file}"

summary="$(jq -n \
  --arg run_id "${run_id}" \
  --arg correlation_id "${correlation_id}" \
  --arg status "${status}" \
  '{run_id: $run_id, correlation_id: $correlation_id, status: $status}')"

printf '%s\n' "${summary}"
