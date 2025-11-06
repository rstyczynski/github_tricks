#!/usr/bin/env bash
set -euo pipefail

# Trigger GitHub workflow using REST API with curl

# Defaults
TOKEN_FILE=".secrets/token"
REPO=""
WORKFLOW=""
REF=""
CORRELATION_ID=""
JSON_OUTPUT=false
declare -a INPUTS=()

show_help() {
  cat <<'EOF'
Usage: trigger-workflow-curl.sh --workflow <file> [OPTIONS]

Trigger GitHub workflow using REST API (curl).

REQUIRED:
  --workflow <file>        Workflow file path (e.g., dispatch-webhook.yml) or workflow ID

OPTIONS:
  --ref <branch>           Branch/ref to trigger workflow on (default: current branch or main)
  --input key=value        Workflow input (can be specified multiple times)
  --correlation-id <uuid>  Correlation UUID (auto-generated if omitted)
  --repo <owner/repo>      Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>      GitHub token file (default: .secrets/token)
  --json                   Output JSON format for programmatic use
  --help                   Show this help message

EXAMPLES:
  trigger-workflow-curl.sh --workflow dispatch-webhook.yml --input webhook_url=https://webhook.site/your-id
  trigger-workflow-curl.sh --workflow dispatch-webhook.yml --ref main --input webhook_url=$WEBHOOK_URL --json
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

resolve_workflow_id() {
  local owner_repo="$1"
  local workflow="$2"
  local token="$3"

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

  printf 'Error: Workflow not found: %s\n' "$workflow" >&2
  return 1
}

build_dispatch_body() {
  local ref="$1"
  local correlation_id="$2"
  shift 2
  local inputs=("$@")

  local body_json="{"
  body_json+="\"ref\":$(jq -n --arg ref "$ref" '$ref')"

  if [[ ${#inputs[@]} -gt 0 ]] || [[ -n "$correlation_id" ]]; then
    body_json+=",\"inputs\":{"
    local first=true

    if [[ -n "$correlation_id" ]]; then
      body_json+="\"correlation_id\":$(jq -n --arg id "$correlation_id" '$id')"
      first=false
    fi

    for input in "${inputs[@]}"; do
      if [[ "$input" =~ ^([^=]+)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        [[ "$first" == "false" ]] && body_json+=","
        body_json+="\"$key\":$(jq -n --arg val "$value" '$val')"
        first=false
      fi
    done

    body_json+="}"
  fi

  body_json+="}"
  echo "$body_json"
}

dispatch_workflow() {
  local owner_repo="$1"
  local workflow_id="$2"
  local token="$3"
  local body_json="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -sS -w '\n%{http_code}' \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body_json" \
    "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflow_id/dispatches" 2>/dev/null || printf '\n000')

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    204)
      return 0
      ;;
    404)
      printf 'Error: Workflow not found (ID: %s)\n' "$workflow_id" >&2
      return 1
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"' 2>/dev/null || echo "Validation failed")
      printf 'Error: Validation failed - %s\n' "$error_msg" >&2
      echo "$response_body" | jq -r '.errors[]? | "  - \(.field // "unknown"): \(.message // "error")" | .' >&2 2>/dev/null || true
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to trigger workflow\n' >&2
      return 1
      ;;
    401)
      printf 'Error: Authentication failed. Check token permissions.\n' >&2
      return 1
      ;;
    *)
      printf 'Error: API request failed (HTTP %s)\n' "$http_code" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2 2>/dev/null || true
      return 1
      ;;
  esac
}

format_output_human() {
  local workflow="$1"
  local workflow_id="$2"
  local ref="$3"
  local correlation_id="$4"
  printf 'Workflow triggered successfully\n'
  printf 'Workflow: %s (ID: %s)\n' "$workflow" "$workflow_id"
  printf 'Branch: %s\n' "$ref"
  printf 'Correlation ID: %s\n' "$correlation_id"
}

format_output_json() {
  local workflow="$1"
  local workflow_id="$2"
  local ref="$3"
  local correlation_id="$4"
  jq -n \
    --arg workflow "$workflow" \
    --arg workflow_id "$workflow_id" \
    --arg ref "$ref" \
    --arg correlation_id "$correlation_id" \
    --arg status "dispatched" \
    '{
      workflow: $workflow,
      workflow_id: ($workflow_id | tonumber),
      ref: $ref,
      correlation_id: $correlation_id,
      status: $status
    }'
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --workflow)
        WORKFLOW="$2"
        shift 2
        ;;
      --ref)
        REF="$2"
        shift 2
        ;;
      --input)
        INPUTS+=("$2")
        shift 2
        ;;
      --correlation-id)
        CORRELATION_ID="$2"
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

  # Validate required parameters
  if [[ -z "$WORKFLOW" ]]; then
    printf 'Error: --workflow is required\n' >&2
    show_help >&2
    exit 2
  fi

  # Load token
  local token
  token="$(load_token "$TOKEN_FILE")"

  # Resolve repository
  local owner_repo
  owner_repo="$(resolve_repository)"

  # Resolve workflow ID
  local workflow_id
  workflow_id="$(resolve_workflow_id "$owner_repo" "$WORKFLOW" "$token")"

  # Generate correlation ID if not provided
  if [[ -z "$CORRELATION_ID" ]]; then
    CORRELATION_ID="$(generate_uuid)"
  fi

  # Resolve ref (default to current branch or main)
  if [[ -z "$REF" ]]; then
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
    else
      REF="main"
    fi
  fi

  # Build dispatch body
  local body_json
  body_json="$(build_dispatch_body "$REF" "$CORRELATION_ID" "${INPUTS[@]}")"

  # Dispatch workflow
  if ! dispatch_workflow "$owner_repo" "$workflow_id" "$token" "$body_json"; then
    exit 1
  fi

  # Output result
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    format_output_json "$WORKFLOW" "$workflow_id" "$REF" "$CORRELATION_ID"
  else
    format_output_human "$WORKFLOW" "$workflow_id" "$REF" "$CORRELATION_ID"
  fi
}

main "$@"

