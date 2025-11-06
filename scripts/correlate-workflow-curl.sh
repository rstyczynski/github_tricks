#!/usr/bin/env bash
set -euo pipefail

# Correlate workflow runs using REST API with curl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "$SCRIPT_DIR/lib/run-utils.sh"

# Defaults
TOKEN_FILE="./secrets/github_token"
REPO=""
CORRELATION_ID=""
WORKFLOW=""
REF=""
TIMEOUT=60
INTERVAL=3
STORE_DIR=""
JSON_ONLY=false

show_help() {
  cat <<'EOF'
Usage: correlate-workflow-curl.sh --correlation-id <uuid> [OPTIONS]

Correlate workflow runs using REST API (curl).

REQUIRED:
  --correlation-id <uuid>   Correlation UUID

OPTIONS:
  --workflow <file>          Workflow file path or ID (optional, filters by workflow)
  --ref <branch>             Branch/ref filter (default: current branch or main)
  --timeout <seconds>        Maximum time to wait (default: 60)
  --interval <seconds>       Polling interval (default: 3)
  --store-dir <dir>          Directory to store metadata (optional)
  --repo <owner/repo>        Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>        GitHub token file (default: ./secrets/github_token)
  --json-only                Output only JSON (no progress messages)
  --help                     Show this help message

EXAMPLES:
  correlate-workflow-curl.sh --correlation-id <uuid> --workflow dispatch-webhook.yml
  correlate-workflow-curl.sh --correlation-id <uuid> --timeout 120 --json-only
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

resolve_workflow_id() {
  local owner_repo="$1"
  local workflow="$2"
  local token="$3"

  if [[ -z "$workflow" ]]; then
    printf ''
    return 0
  fi

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  # Try as file path first
  local response http_code
  response=$(curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflow" 2>/dev/null || printf '\n000')

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$response_body" | jq -r '.id'
    return 0
  fi

  # If file path fails, try as numeric ID
  if [[ "$workflow" =~ ^[0-9]+$ ]]; then
    echo "$workflow"
    return 0
  fi

  # Workflow filter is optional, return empty if not found
  printf ''
  return 0
}

poll_workflow_runs() {
  local owner_repo="$1"
  local workflow_id="$2"
  local branch="$3"
  local token="$4"
  local correlation_id="$5"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local query="status=queued,in_progress&per_page=30"
  [[ -n "$workflow_id" ]] && query+="&workflow_id=$workflow_id"
  [[ -n "$branch" ]] && query+="&head_branch=$branch"

  local response http_code
  response=$(curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs?$query" 2>/dev/null || printf '\n000')

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    return 1
  fi

  # Filter by correlation_id in run name
  echo "$response_body" | jq -r --arg corr_id "$correlation_id" \
    '.workflow_runs[]? | select(.name | contains($corr_id)) | .id' | head -n1
}

correlate_workflow() {
  local owner_repo="$1"
  local workflow_id="$2"
  local branch="$3"
  local token="$4"
  local correlation_id="$5"
  local timeout="$6"
  local interval="$7"
  local json_only="$8"

  local start_time
  start_time=$(date +%s)
  local elapsed=0
  local checked=0

  if [[ "$json_only" != "true" ]]; then
    printf 'Searching for workflow run with correlation ID: %s\n' "$correlation_id" >&2
  fi

  while [[ $elapsed -lt $timeout ]]; do
    local run_id
    run_id=$(poll_workflow_runs "$owner_repo" "$workflow_id" "$branch" "$token" "$correlation_id" || true)
    checked=$((checked + 1))

    if [[ -n "$run_id" ]]; then
      if [[ "$json_only" != "true" ]]; then
        printf 'Found run ID: %s\n' "$run_id" >&2
      fi
      printf '%s' "$run_id"
      return 0
    fi

    elapsed=$(($(date +%s) - start_time))
    if [[ "$json_only" != "true" ]]; then
      printf '\rPolling... (elapsed: %ds, checked: %d runs)' "$elapsed" "$checked" >&2
    fi

    sleep "$interval"
  done

  printf 'Error: Timeout waiting for workflow run with correlation ID: %s\n' "$correlation_id" >&2
  return 1
}

store_metadata() {
  local store_dir="$1"
  local correlation_id="$2"
  local run_id="$3"
  local owner_repo="$4"
  local workflow="$5"

  if [[ -z "$store_dir" ]]; then
    return 0
  fi

  mkdir -p "$store_dir"
  local metadata_file
  metadata_file="$store_dir/${correlation_id}.json"

  jq -n \
    --arg run_id "$run_id" \
    --arg correlation_id "$correlation_id" \
    --arg owner_repo "$owner_repo" \
    --arg workflow "$workflow" \
    '{
      run_id: $run_id,
      correlation_id: $correlation_id,
      owner_repo: $owner_repo,
      workflow: $workflow
    }' > "$metadata_file"
}

format_output_json() {
  local run_id="$1"
  local correlation_id="$2"
  local workflow="$3"
  local status="$4"
  jq -n \
    --arg run_id "$run_id" \
    --arg correlation_id "$correlation_id" \
    --arg workflow "$workflow" \
    --arg status "$status" \
    '{
      run_id: ($run_id | tonumber),
      correlation_id: $correlation_id,
      workflow: $workflow,
      status: $status
    }'
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --correlation-id)
        CORRELATION_ID="$2"
        shift 2
        ;;
      --workflow)
        WORKFLOW="$2"
        shift 2
        ;;
      --ref)
        REF="$2"
        shift 2
        ;;
      --timeout)
        TIMEOUT="$2"
        shift 2
        ;;
      --interval)
        INTERVAL="$2"
        shift 2
        ;;
      --store-dir)
        STORE_DIR="$2"
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
      --json-only)
        JSON_ONLY=true
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

  # Validate required parameters
  if [[ -z "$CORRELATION_ID" ]]; then
    printf 'Error: --correlation-id is required\n' >&2
    show_help >&2
    exit 2
  fi

  # Load token
  local token
  token="$(load_token "$TOKEN_FILE")"

  # Resolve repository
  local owner_repo
  owner_repo="$(resolve_repository)"

  # Resolve workflow ID (optional)
  local workflow_id
  workflow_id="$(resolve_workflow_id "$owner_repo" "$WORKFLOW" "$token")"

  # Resolve ref (default to current branch or main)
  if [[ -z "$REF" ]]; then
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
    else
      REF="main"
    fi
  fi

  # Correlate workflow
  local run_id
  if ! run_id="$(correlate_workflow "$owner_repo" "$workflow_id" "$REF" "$token" "$CORRELATION_ID" "$TIMEOUT" "$INTERVAL" "$JSON_ONLY")"; then
    exit 1
  fi

  # Store metadata if requested
  store_metadata "$STORE_DIR" "$CORRELATION_ID" "$run_id" "$owner_repo" "$WORKFLOW"

  # Get run status for JSON output
  local run_status="in_progress"
  if [[ "$JSON_ONLY" == "true" ]]; then
    # Fetch run details to get status
    local owner repo
    IFS='/' read -r owner repo <<< "$owner_repo"
    local response http_code
    response=$(curl -sS -w '\n%{http_code}' \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id" 2>/dev/null || printf '\n000')
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" == "200" ]]; then
      local response_body
      response_body=$(echo "$response" | sed '$d')
      run_status=$(echo "$response_body" | jq -r '.status // "in_progress"')
    fi
  fi

  # Output result
  if [[ "$JSON_ONLY" == "true" ]]; then
    format_output_json "$run_id" "$CORRELATION_ID" "$WORKFLOW" "$run_status"
  else
    printf '%s\n' "$run_id"
  fi
}

main "$@"

