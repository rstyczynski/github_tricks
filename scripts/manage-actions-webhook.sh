#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: manage-actions-webhook.sh <command> [options]

Commands:
  register    Create a repository webhook listening on workflow_run events.
  status      Show details for the stored webhook id.
  unregister  Delete the stored webhook and clean cached metadata.

Options:
  --webhook-url <url>  Explicit webhook URL (otherwise use WEBHOOK_URL env var)
  --store-dir <dir>    Directory for cached metadata (default: runs)
  -h, --help           Show help
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

command="${1:-}"
if [[ -z "${command}" ]]; then
  usage
  exit 1
fi
shift || true

webhook_url="${WEBHOOK_URL:-}"
store_dir="runs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook-url)
      webhook_url="$2"
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

require_command gh
require_command jq

store_dir="${store_dir%/}"
mkdir -p "${store_dir}"
hook_file="${store_dir}/_webhook_hook.json"

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

case "${command}" in
  register)
    if [[ -z "${webhook_url}" ]]; then
      read -rp "Enter webhook URL: " webhook_url
    fi
    if [[ -z "${webhook_url}" ]]; then
      log "Webhook URL is required."
      exit 1
    fi

    log "Registering workflow_run webhook for ${repo}"
    hook_response="$(
      gh api "repos/${repo}/hooks" \
        -X POST \
        -f name=web \
        -F active=true \
        -F events[]=workflow_run \
        -F config.url="${webhook_url}" \
        -F config.content_type=json
    )"

    printf '%s\n' "${hook_response}" | jq '.' >"${hook_file}"
    hook_id="$(printf '%s\n' "${hook_response}" | jq -r '.id')"

    log "Webhook created with id ${hook_id}."
    log "Metadata stored at ${hook_file} (inside ignored runs/ directory)."
    ;;

  status)
    if [[ ! -f "${hook_file}" ]]; then
      log "No cached webhook metadata found at ${hook_file}."
      exit 1
    fi
    hook_id="$(jq -r '.id' "${hook_file}")"
    if [[ -z "${hook_id}" || "${hook_id}" == "null" ]]; then
      log "Cached metadata missing id field."
      exit 1
    fi
    log "Checking webhook ${hook_id} for ${repo}"
    gh api "repos/${repo}/hooks/${hook_id}"
    ;;

  unregister)
    if [[ ! -f "${hook_file}" ]]; then
      log "No webhook metadata found; nothing to unregister."
      exit 0
    fi
    hook_id="$(jq -r '.id' "${hook_file}")"
    if [[ -z "${hook_id}" || "${hook_id}" == "null" ]]; then
      log "Cached metadata missing id field; deleting local cache."
      rm -f "${hook_file}"
      exit 0
    fi
    log "Deleting webhook ${hook_id} from ${repo}"
    gh api "repos/${repo}/hooks/${hook_id}" -X DELETE >/dev/null
    rm -f "${hook_file}"
    log "Webhook removed and local cache deleted."
    ;;

  *)
    log "Unknown command: ${command}"
    usage
    exit 1
    ;;
esac
