#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: trigger-and-track.sh --webhook-url <url> [--timeout <seconds>] [--interval <seconds>] [--ref <branch>]

Triggers the dispatch-webhook workflow and waits for the GitHub run that emits the provided correlation token.
Outputs JSON containing the run_id and correlation_id.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
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
  echo "Missing webhook URL; provide --webhook-url or set WEBHOOK_URL." >&2
  usage
  exit 1
fi

echo "Using webhook URL: ${webhook_url}"

require_command gh
require_command jq
require_command python3

if [[ -z "${ref}" ]]; then
  ref="$(git rev-parse --abbrev-ref HEAD)"
fi

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
correlation_id="$(generate_uuid)"

dispatch_epoch="$(date -u +%s)"

echo "Triggering workflow dispatch-webhook.yml on ${repo} (ref: ${ref})"
echo "Generated correlation ID: ${correlation_id}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "::warning::GITHUB_TOKEN is not set; gh CLI must already be authenticated."
fi

dispatch_output="$(CORRELATION_ID="${correlation_id}" gh workflow run dispatch-webhook.yml --ref "${ref}" --raw-field webhook_url="${webhook_url}")"
echo "${dispatch_output}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

start_time=$SECONDS
found_run=""

while (( SECONDS - start_time < timeout )); do
  mapfile -t candidates < <(
    gh api "repos/${repo}/actions/workflows/dispatch-webhook.yml/runs" \
      -F per_page=20 \
      --jq '.workflow_runs[] | "\(.id) \(.head_branch) \(.created_at)"'
  )

  for candidate in "${candidates[@]}"; do
    read -r run_id head_branch created_at <<<"${candidate}"

    if [[ -z "${run_id}" ]]; then
      continue
    fi

    created_epoch="$(parse_iso8601_to_epoch "${created_at}")"
    if (( created_epoch < dispatch_epoch )); then
      continue
    fi

    if [[ "${head_branch}" != "${ref}" ]]; then
      continue
    fi

    log_file="${tmp_dir}/${run_id}.log"
    if gh run view "${run_id}" --log >"${log_file}" 2>/dev/null; then
      if grep -q "${correlation_id}" "${log_file}"; then
        found_run="${run_id}"
        break 2
      fi
    fi
  done

  sleep "${interval}"
done

if [[ -z "${found_run}" ]]; then
  echo "Failed to correlate workflow run within ${timeout} seconds." >&2
  exit 1
fi

jq -n --arg run_id "${found_run}" --arg correlation_id "${correlation_id}" \
  '{run_id: $run_id, correlation_id: $correlation_id}'
