#!/usr/bin/env bash
set -euo pipefail

# List workflow artifacts using REST API with curl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "$SCRIPT_DIR/lib/run-utils.sh"

# Defaults
TOKEN_FILE="./secrets/github_token"
REPO=""
RUN_ID=""
CORRELATION_ID=""
RUNS_DIR="runs"
NAME_FILTER=""
PAGINATE=false
JSON_OUTPUT=false

show_help() {
  cat <<'EOF'
Usage: list-artifacts-curl.sh [--run-id <id>] [--correlation-id <uuid>] [OPTIONS]

List workflow artifacts using REST API (curl).

INPUT (first match wins):
  --run-id <id>             Workflow run ID (numeric)
  --correlation-id <uuid>   Load run_id from stored metadata
  stdin                     JSON from trigger-and-track.sh or correlate-workflow-curl.sh

OPTIONS:
  --name-filter <pattern>   Filter artifacts by name (partial match, case-sensitive)
  --paginate                Fetch all pages (default: first page only, 30 items)
  --runs-dir <dir>          Base directory for metadata (default: runs)
  --repo <owner/repo>       Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>       GitHub token file (default: ./secrets/github_token)
  --json                    Output JSON format for programmatic use
  --help                    Show this help message

EXAMPLES:
  list-artifacts-curl.sh --run-id 1234567890
  list-artifacts-curl.sh --correlation-id <uuid> --name-filter "build-"
  list-artifacts-curl.sh --run-id 1234567890 --paginate --json
EOF
}

warn_token_permissions() {
  local token_file="$1"
  local perms=""
  if stat --version >/dev/null 2>&1; then
    perms=$(stat -c '%a' "$token_file" 2>/dev/null || true)
  else
    perms=$(stat -f '%OLp' "$token_file" 2>/dev/null || true)
  fi
  if [[ -n "$perms" && "$perms" != "600" && "$perms" -gt 600 ]]; then
    printf 'Warning: token file %s has permissions %s (recommended 600)\n' "$token_file" "$perms" >&2
  fi
}

load_token() {
  local token_file="$1"
  if [[ ! -f "$token_file" ]]; then
    printf 'Error: Token file not found: %s\n' "$token_file" >&2
    exit 1
  fi
  if [[ ! -r "$token_file" ]]; then
    printf 'Error: Token file not readable: %s\n' "$token_file" >&2
    exit 1
  fi
  warn_token_permissions "$token_file"
  local token
  token="$(tr -d '[:space:]' <"$token_file")"
  if [[ -z "$token" ]]; then
    printf 'Error: Token file is empty: %s\n' "$token_file" >&2
    exit 1
  fi
  printf '%s' "$token"
}

normalize_repo() {
  local value="$1"
  value="${value%.git}"
  printf '%s' "$value"
}

parse_github_url() {
  local url="$1"
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    printf '%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]%.git}"
  else
    printf 'Error: Cannot parse GitHub remote URL: %s\n' "$url" >&2
    exit 1
  fi
}

validate_repo_format() {
  local repo_value="$1"
  if [[ ! "$repo_value" =~ ^[^/]+/[^/]+$ ]]; then
    printf 'Error: Repository must be in owner/repo format (got: %s)\n' "$repo_value" >&2
    exit 1
  fi
}

resolve_repository() {
  if [[ -n "$REPO" ]]; then
    local cleaned
    cleaned="$(normalize_repo "$REPO")"
    validate_repo_format "$cleaned"
    printf '%s' "$cleaned"
    return 0
  fi

  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    local cleaned_env
    cleaned_env="$(normalize_repo "$GITHUB_REPOSITORY")"
    validate_repo_format "$cleaned_env"
    printf '%s' "$cleaned_env"
    return 0
  fi

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local remote_url
    remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"
    if [[ -n "$remote_url" ]]; then
      local parsed
      parsed="$(parse_github_url "$remote_url")"
      validate_repo_format "$parsed"
      printf '%s' "$parsed"
      return 0
    fi
  fi

  printf 'Error: Unable to determine repository. Use --repo owner/repo or set GITHUB_REPOSITORY.\n' >&2
  exit 1
}

resolve_run_id() {
  local resolved_id=""

  if [[ -n "${RUN_ID}" ]]; then
    resolved_id="${RUN_ID}"
  elif [[ -n "${CORRELATION_ID}" ]]; then
    resolved_id="$(ru_read_run_id_from_runs_dir "${RUNS_DIR}" "${CORRELATION_ID}")"
    if [[ -z "${resolved_id}" ]]; then
      printf 'Error: No metadata found for correlation ID %s\n' "${CORRELATION_ID}" >&2
      printf 'Expected file: %s\n' "$(ru_metadata_path_for_correlation "${RUNS_DIR}" "${CORRELATION_ID}")" >&2
      exit 1
    fi
  elif ! [[ -t 0 ]]; then
    resolved_id="$(ru_read_run_id_from_stdin)"
    if [[ -z "${resolved_id}" ]]; then
      printf 'Error: Could not extract run_id from stdin JSON\n' >&2
      exit 1
    fi
  else
    printf 'Error: No run ID provided (use --run-id, --correlation-id, or pipe JSON via stdin)\n' >&2
    exit 1
  fi

  printf '%s' "${resolved_id}"
}

list_artifacts_page() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  local page="${4:-1}"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/artifacts?per_page=30&page=$page" 2>/dev/null || printf '\n000')

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    case "$http_code" in
      404)
        printf 'Error: Run %s not found\n' "$run_id" >&2
        ;;
      410)
        printf 'Error: Artifacts expired for run %s\n' "$run_id" >&2
        ;;
      401)
        printf 'Error: Authentication failed. Check token permissions.\n' >&2
        ;;
      403)
        printf 'Error: Insufficient permissions to list artifacts\n' >&2
        ;;
      *)
        printf 'Error: Failed to list artifacts (HTTP %s)\n' "$http_code" >&2
        if command -v jq >/dev/null 2>&1; then
          local error_msg
          error_msg=$(echo "$response_body" | jq -r '.message // "Unknown error"' 2>/dev/null || true)
          if [[ -n "$error_msg" ]]; then
            printf '%s\n' "$error_msg" >&2
          fi
        fi
        ;;
    esac
    return 1
  fi

  printf '%s' "$response_body"
  return 0
}

fetch_all_artifacts() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"

  local page=1
  local all_artifacts="[]"
  local total_count=0

  while true; do
    local response
    if ! response="$(list_artifacts_page "$owner_repo" "$run_id" "$token" "$page")"; then
      return 1
    fi

    local artifacts
    artifacts=$(echo "$response" | jq -c '.artifacts // []')
    local page_total
    page_total=$(echo "$response" | jq -r '.total_count // 0')
    total_count=$page_total

    all_artifacts=$(echo "$all_artifacts" "$artifacts" | jq -s 'add')

    local artifacts_count
    artifacts_count=$(echo "$artifacts" | jq 'length')
    if [[ "$artifacts_count" -lt 30 ]] || [[ "$PAGINATE" != "true" ]]; then
      break
    fi

    local current_count
    current_count=$(echo "$all_artifacts" | jq 'length')
    if [[ $current_count -ge $total_count ]]; then
      break
    fi

    page=$((page + 1))
  done

  echo "$all_artifacts"
}

filter_artifacts_by_name() {
  local artifacts_json="$1"
  local name_filter="$2"

  if [[ -z "$name_filter" ]]; then
    echo "$artifacts_json"
    return 0
  fi

  echo "$artifacts_json" | jq --arg filter "$name_filter" \
    '[.[] | select(.name | contains($filter))]'
}

format_human_size() {
  local bytes="$1"
  if [[ $bytes -lt 1024 ]]; then
    printf '%d B' "$bytes"
  elif [[ $bytes -lt 1048576 ]]; then
    local kb=$((bytes / 1024))
    local remainder=$((bytes % 1024))
    if [[ $remainder -gt 0 ]]; then
      printf '%d.%d KB' "$kb" "$((remainder * 10 / 1024))"
    else
      printf '%d KB' "$kb"
    fi
  elif [[ $bytes -lt 1073741824 ]]; then
    local mb=$((bytes / 1048576))
    local remainder=$((bytes % 1048576))
    if [[ $remainder -gt 0 ]]; then
      printf '%d.%d MB' "$mb" "$((remainder * 10 / 1048576))"
    else
      printf '%d MB' "$mb"
    fi
  else
    local gb=$((bytes / 1073741824))
    local remainder=$((bytes % 1073741824))
    if [[ $remainder -gt 0 ]]; then
      printf '%d.%d GB' "$gb" "$((remainder * 10 / 1073741824))"
    else
      printf '%d GB' "$gb"
    fi
  fi
}

format_artifact_table() {
  local artifacts_json="$1"
  local run_id="$2"

  local count
  count=$(echo "$artifacts_json" | jq 'length')

  if [[ $count -eq 0 ]]; then
    printf 'No artifacts found for run %s\n' "$run_id"
    return 0
  fi

  printf 'Artifacts for run %s:\n' "$run_id"
  printf '  %-10s %-30s %-12s %-20s %-20s\n' "ID" "Name" "Size" "Created" "Expires"
  printf '  %s\n' "$(printf '=%.0s' {1..92})"

  echo "$artifacts_json" | jq -r '.[] | 
    "  \(.id)\t\(.name)\t\(.size_in_bytes)\t\(.created_at)\t\(.expires_at)"
  ' | while IFS=$'\t' read -r id name size_bytes created expires; do
    local size_human
    size_human="$(format_human_size "$size_bytes")"
    local created_short
    created_short="${created%%T*}"
    local expires_short
    expires_short="${expires%%T*}"
    printf '  %-10s %-30s %-12s %-20s %-20s\n' "$id" "$name" "$size_human" "$created_short" "$expires_short"
  done

  printf '\nTotal: %d artifact(s)\n' "$count"
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
      --name-filter)
        NAME_FILTER="$2"
        shift 2
        ;;
      --paginate)
        PAGINATE=true
        shift
        ;;
      --runs-dir)
        RUNS_DIR="$2"
        shift 2
        ;;
      --repo)
        REPO="$2"
        shift 2
        ;;
      --token-file)
        TOKEN_FILE="$2"
        shift 2
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        printf 'Error: Unknown option: %s\n' "$1" >&2
        show_help >&2
        exit 2
        ;;
    esac
  done

  ru_require_command jq

  # Resolve run ID
  local run_id
  run_id="$(resolve_run_id)"
  run_id="$(printf '%s' "${run_id}" | tr -d '[:space:]')"

  # Load token
  local token
  token="$(load_token "$TOKEN_FILE")"

  # Resolve repository
  local owner_repo
  owner_repo="$(resolve_repository)"

  # Fetch artifacts
  local artifacts_json
  if ! artifacts_json="$(fetch_all_artifacts "$owner_repo" "$run_id" "$token")"; then
    exit 1
  fi

  # Filter by name if specified
  if [[ -n "$NAME_FILTER" ]]; then
    artifacts_json="$(filter_artifacts_by_name "$artifacts_json" "$NAME_FILTER")"
  fi

  # Output result
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    local count
    count=$(echo "$artifacts_json" | jq 'length')
    jq -n \
      --argjson artifacts "$artifacts_json" \
      --arg run_id "$run_id" \
      --arg count "$count" \
      '{
        run_id: $run_id,
        total_count: ($count | tonumber),
        artifacts: $artifacts | map({
          id: .id,
          name: .name,
          size_in_bytes: .size_in_bytes,
          size_human: (if .size_in_bytes < 1024 then "\(.size_in_bytes) B" elif .size_in_bytes < 1048576 then "\(.size_in_bytes / 1024 | floor) KB" elif .size_in_bytes < 1073741824 then "\(.size_in_bytes / 1048576 | floor) MB" else "\(.size_in_bytes / 1073741824 | floor) GB" end),
          created_at: .created_at,
          expires_at: .expires_at,
          archive_download_url: .archive_download_url
        })
      }'
  else
    format_artifact_table "$artifacts_json" "$run_id"
  fi
}

main "$@"

