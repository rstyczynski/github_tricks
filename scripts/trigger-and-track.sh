#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: trigger-and-track.sh --webhook-url <url> [--timeout <seconds>] [--interval <seconds>] [--ref <branch>] [--workflow <file>] [--store-dir <dir>] [--input key=value] [--json-only] [--webhook-only]

Triggers the dispatch-webhook workflow and waits for the GitHub run that emits the provided correlation token.
Outputs JSON containing the run_id and correlation_id.
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

generate_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
  fi
}

parse_iso8601_to_epoch() {
  python3 - "$1" <<'PY'
import datetime
import sys

value = sys.argv[1]
try:
    dt = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    print(int(dt.timestamp()))
except Exception:
    print(0)
PY
}

webhook_url=""
timeout=60
interval=3
ref=""
workflow_file="dispatch-webhook.yml"
workflow_name=""
store_dir=""
json_only=false
webhook_only=false
declare -a extra_inputs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook-url)
      webhook_url="$2"
      shift 2
      ;;
    --timeout)
      timeout="$2"
      shift 2
      ;;
    --interval)
      interval="$2"
      shift 2
      ;;
    --ref)
      ref="$2"
      shift 2
      ;;
    --workflow)
      workflow_file="$2"
      shift 2
      ;;
    --store-dir)
      store_dir="$2"
      shift 2
      ;;
    --input)
      extra_inputs+=("$2")
      shift 2
      ;;
    --json-only)
      json_only=true
      shift
      ;;
    --webhook-only)
      webhook_only=true
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

if [[ -z "${webhook_url}" && -n "${WEBHOOK_URL:-}" ]]; then
  webhook_url="${WEBHOOK_URL}"
fi

if [[ -z "${webhook_url}" ]]; then
  read -rp "Enter webhook URL (e.g., https://webhook.site/your-id): " webhook_url
fi

if [[ -z "${webhook_url}" ]]; then
  log "Missing webhook URL; provide --webhook-url or set WEBHOOK_URL."
  usage
  exit 1
fi

log "Using webhook URL: ${webhook_url}"

require_command gh
require_command jq
require_command python3

if [[ -z "${ref}" ]]; then
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    ref="$(git rev-parse --abbrev-ref HEAD)"
  else
    ref="main"
  fi
fi

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
correlation_id="$(generate_uuid)"

dispatch_epoch="$(date -u +%s)"

if [[ -n "${store_dir}" ]]; then
  mkdir -p "${store_dir}"
fi

workflow_name="$(basename "${workflow_file}")"
workflow_id="$(gh api "repos/${repo}/actions/workflows/${workflow_name}" --jq '.id' 2>/dev/null || true)"
if [[ -z "${workflow_id}" ]]; then
  log "Failed to resolve workflow id for ${workflow_name}"
  exit 1
fi

log "Triggering workflow ${workflow_name} on ${repo} (ref: ${ref})"
log "Generated correlation ID: ${correlation_id}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  log "::warning::GITHUB_TOKEN is not set; gh CLI must already be authenticated."
fi

dispatch_output=""
declare -a workflow_args=()
workflow_args+=(--ref "${ref}")
workflow_args+=(--raw-field "correlation_id=${correlation_id}")
if [[ "${workflow_name}" == "dispatch-webhook.yml" ]]; then
  workflow_args+=(--raw-field "webhook_url=${webhook_url}")
fi
for input in "${extra_inputs[@]}"; do
  workflow_args+=(--raw-field "${input}")
done

if dispatch_output="$(gh workflow run "${workflow_name}" "${workflow_args[@]}" 2>&1)"; then
  [[ "${json_only}" == true ]] || log "${dispatch_output}"
else
  if echo "${dispatch_output}" | grep -qi "not found"; then
    log "Filename dispatch failed (404). Retrying with workflow ID ${workflow_id}."
    dispatch_output="$(gh workflow run "${workflow_id}" "${workflow_args[@]}" 2>&1)"
    [[ "${json_only}" == true ]] || log "${dispatch_output}"
  else
    printf '%s\n' "${dispatch_output}" >&2
    exit 1
  fi
fi

if [[ "${webhook_only}" == true ]]; then
  log "Webhook-only mode: waiting for incoming webhook payload."
  if [[ -n "${store_dir}" ]]; then
    mkdir -p "${store_dir}"
    output_file="${store_dir}/${correlation_id}.json"
    stored_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    jq -n \
      --arg correlation_id "${correlation_id}" \
      --arg branch "${ref}" \
      --arg workflow "${workflow_file}" \
      --arg repo "${repo}" \
      --arg stored_at "${stored_at}" \
      '{
        run_id: null,
        correlation_id: $correlation_id,
        branch: $branch,
        workflow: $workflow,
        repo: $repo,
        stored_at: $stored_at,
        webhook_pending: true
      }' >"${output_file}"
    log "Stored placeholder metadata at ${output_file}"
  fi

  result_json="$(jq -n --arg correlation_id "${correlation_id}" '{run_id: null, correlation_id: $correlation_id}')"
  if [[ "${json_only}" == true ]]; then
    printf '%s\n' "${result_json}"
  else
    printf '%s\n' "${result_json}"
    log "Use process-workflow-webhook.sh after receiving the webhook to resolve run_id."
  fi
  exit 0
fi

found_run=""
start_time=$SECONDS

spinner_chars=$'|/-\\'
spinner_index=0
progress_message="Polling for workflow run"

show_spinner() {
  [[ "${json_only}" == true ]] && return
  local elapsed=$(( SECONDS - start_time ))
  local char=${spinner_chars:spinner_index:1}
  printf '\r%s %s (elapsed %ss)' "${char}" "${progress_message}" "${elapsed}" >&2
  spinner_index=$(( (spinner_index + 1) % ${#spinner_chars} ))
}

while (( SECONDS - start_time < timeout )); do
  show_spinner

  queued_json="$(gh run list --workflow "${workflow_name}" --limit 50 --status queued --json databaseId,name,headBranch,createdAt 2>/dev/null || echo '[]')"
  in_progress_json="$(gh run list --workflow "${workflow_name}" --limit 50 --status in_progress --json databaseId,name,headBranch,createdAt 2>/dev/null || echo '[]')"

  [[ -z "${queued_json}" ]] && queued_json='[]'
  [[ -z "${in_progress_json}" ]] && in_progress_json='[]'

  runs_json="$(printf '%s\n%s\n' "${queued_json}" "${in_progress_json}" | jq -s 'add' 2>/dev/null || echo '[]')"

  candidate_run_id="$(jq -r \
    --arg cid "${correlation_id}" \
    --arg branch "${ref}" \
    --argjson dispatch "${dispatch_epoch}" \
    'map(select(.headBranch == $branch) |
         select((.createdAt | fromdateiso8601) >= $dispatch) |
         select((.name // "") | contains($cid)))
     | first | (.databaseId // empty)' <<<"${runs_json}" )"

  run_count=$(jq 'length' <<<"${runs_json}" 2>/dev/null || echo 0)
  [[ -z "${run_count}" ]] && run_count=0

  completed_count=0
  if [[ -z "${candidate_run_id}" ]]; then
    completed_json="$(gh run list --workflow "${workflow_name}" --limit 50 --status completed --json databaseId,name,headBranch,createdAt 2>/dev/null || echo '[]')"
    [[ -z "${completed_json}" ]] && completed_json='[]'
    completed_count=$(jq 'length' <<<"${completed_json}" 2>/dev/null || echo 0)
    candidate_run_id="$(jq -r \
      --arg cid "${correlation_id}" \
      --arg branch "${ref}" \
      --argjson dispatch "${dispatch_epoch}" \
      'map(select(.headBranch == $branch) |
           select((.createdAt | fromdateiso8601) >= $dispatch) |
           select((.name // "") | contains($cid)))
       | first | (.databaseId // empty)' <<<"${completed_json}" )"
  fi

  progress_message="Polling for workflow run (active: ${run_count}, completed: ${completed_count})"

  if [[ -n "${candidate_run_id}" ]]; then
    found_run="${candidate_run_id}"
    break
  fi

  sleep "${interval}"
done

[[ "${json_only}" == true ]] || printf '\r' >&2

if [[ -n "${found_run}" ]]; then
  log "Found workflow run ${found_run}"
fi

if [[ -z "${found_run}" ]]; then
  log "Failed to correlate workflow run within ${timeout} seconds."
  exit 1
fi

if [[ -n "${store_dir}" ]]; then
  output_file="${store_dir}/${correlation_id}.json"
  stored_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq -n \
    --arg run_id "${found_run}" \
    --arg correlation_id "${correlation_id}" \
    --arg branch "${ref}" \
    --arg workflow "${workflow_file}" \
    --arg repo "${repo}" \
    --arg stored_at "${stored_at}" \
    '{run_id: $run_id, correlation_id: $correlation_id, branch: $branch, workflow: $workflow, repo: $repo, stored_at: $stored_at}' \
    >"${output_file}"
  log "Stored run metadata at ${output_file}"
fi

result_json="$(jq -n --arg run_id "${found_run}" --arg correlation_id "${correlation_id}" \
  '{run_id: $run_id, correlation_id: $correlation_id}')"

if [[ "${json_only}" == true ]]; then
  printf '%s\n' "${result_json}"
  exit 0
fi

printf '%s\n' "${result_json}"
