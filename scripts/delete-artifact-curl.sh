#!/usr/bin/env bash
set -euo pipefail

# Delete workflow artifacts using REST API with curl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "$SCRIPT_DIR/lib/run-utils.sh"

# Defaults
TOKEN_FILE=".secrets/token"
REPO=""
ARTIFACT_ID=""
RUN_ID=""
CORRELATION_ID=""
RUNS_DIR="runs"
NAME_FILTER=""
CONFIRM=false
DRY_RUN=false
DELETE_ALL=false

show_help() {
  cat <<'EOF'
Usage: delete-artifact-curl.sh --artifact-id <id> [OPTIONS]
       delete-artifact-curl.sh --run-id <id> --all [OPTIONS]
       delete-artifact-curl.sh --correlation-id <uuid> --all [OPTIONS]

Delete workflow artifacts using REST API (curl).

SINGLE ARTIFACT MODE:
  --artifact-id <id>        Delete single artifact by artifact ID (numeric)

BULK DELETION MODE:
  --run-id <id> --all       Delete all artifacts for workflow run
  --correlation-id <uuid> --all  Load run_id from metadata, delete all artifacts

OPTIONS:
  --confirm                 Skip confirmation prompt (default: require confirmation)
  --dry-run                 Preview deletions without executing
  --name-filter <pattern>   Filter artifacts by name when using --all (partial match, case-sensitive)
  --runs-dir <dir>          Base directory for metadata (default: runs)
  --repo <owner/repo>       Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>       GitHub token file (default: .secrets/token)
  --help                    Show this help message

EXAMPLES:
  # Delete single artifact (with confirmation)
  delete-artifact-curl.sh --artifact-id 123456

  # Delete single artifact (skip confirmation)
  delete-artifact-curl.sh --artifact-id 123456 --confirm

  # Preview deletions (dry-run)
  delete-artifact-curl.sh --run-id 1234567890 --all --dry-run

  # Delete all artifacts for run
  delete-artifact-curl.sh --run-id 1234567890 --all --confirm

  # Delete filtered artifacts
  delete-artifact-curl.sh --run-id 1234567890 --all --name-filter "test-" --confirm

  # Delete artifacts using correlation ID
  delete-artifact-curl.sh --correlation-id <uuid> --all --confirm
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
  else
    printf 'Error: No run ID provided (use --run-id or --correlation-id with --all)\n' >&2
    exit 1
  fi

  printf '%s' "${resolved_id}"
}

format_human_size() {
  local bytes="$1"
  if [[ "$bytes" -lt 1024 ]]; then
    printf '%d B' "$bytes"
  elif [[ "$bytes" -lt 1048576 ]]; then
    printf '%.1f KB' "$(echo "scale=1; $bytes / 1024" | bc)"
  elif [[ "$bytes" -lt 1073741824 ]]; then
    printf '%.1f MB' "$(echo "scale=1; $bytes / 1048576" | bc)"
  else
    printf '%.1f GB' "$(echo "scale=1; $bytes / 1073741824" | bc)"
  fi
}

get_artifact_metadata() {
  local owner_repo="$1"
  local artifact_id="$2"
  local token="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -sS -w '\n%{http_code}' -L \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/artifacts/$artifact_id" 2>/dev/null || printf '\n000')

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    return 1
  fi

  printf '%s' "$response_body"
  return 0
}

delete_artifact() {
  local owner_repo="$1"
  local artifact_id="$2"
  local token="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local api_url="https://api.github.com/repos/$owner/$repo/actions/artifacts/$artifact_id"

  local http_code
  http_code=$(curl -sS -w '%{http_code}' -o /dev/null \
    -X DELETE \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$api_url" 2>/dev/null || printf '000')

  case "$http_code" in
    204)
      printf '  ✓ Deleted artifact %s\n' "$artifact_id"
      return 0
      ;;
    404)
      printf '  ✓ Artifact %s already deleted (idempotent)\n' "$artifact_id"
      return 0
      ;;
    401)
      printf '  ✗ Failed to delete artifact %s: Authentication failed\n' "$artifact_id" >&2
      return 1
      ;;
    403)
      printf '  ✗ Failed to delete artifact %s: Insufficient permissions\n' "$artifact_id" >&2
      return 1
      ;;
    *)
      printf '  ✗ Failed to delete artifact %s: Unexpected HTTP status %s\n' "$artifact_id" "$http_code" >&2
      return 1
      ;;
  esac
}

confirm_deletion() {
  local artifact_count="$1"
  local artifact_info="$2"

  if [[ "$DRY_RUN" == true ]]; then
    return 0  # Skip confirmation in dry-run mode
  fi

  if [[ "$CONFIRM" == true ]]; then
    return 0  # Skip confirmation if --confirm flag set
  fi

  if [[ "$artifact_count" -eq 1 ]]; then
    printf 'Are you sure you want to delete artifact %s? [y/N]: ' "$artifact_info" >&2
  else
    printf 'Found %d artifacts. Delete all? [y/N]: ' "$artifact_count" >&2
  fi

  local response
  read -r response
  case "$response" in
    [yY]|[yY][eE][sS])
      return 0
      ;;
    *)
      printf 'Deletion cancelled\n' >&2
      return 1
      ;;
  esac
}

dry_run_deletion() {
  local owner_repo="$1"
  local token="$2"
  shift 2
  local artifact_ids=("$@")

  printf 'Dry-run: Would delete %d artifact(s):\n' "${#artifact_ids[@]}"

  for artifact_id in "${artifact_ids[@]}"; do
    # Fetch artifact metadata
    local metadata
    if metadata="$(get_artifact_metadata "$owner_repo" "$artifact_id" "$token")"; then
      local name size
      name=$(echo "$metadata" | jq -r '.name // "unknown"')
      size=$(echo "$metadata" | jq -r '.size_in_bytes // 0')
      local size_human
      if command -v bc >/dev/null 2>&1; then
        size_human="$(format_human_size "$size")"
      else
        size_human="${size} bytes"
      fi
      printf '  - Artifact %s (%s, %s)\n' "$artifact_id" "$name" "$size_human"
    else
      printf '  - Artifact %s (metadata unavailable)\n' "$artifact_id"
    fi
  done
}

list_artifacts_for_deletion() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  local name_filter="$4"

  # Call Sprint 16's list-artifacts-curl.sh to get artifact list
  local list_cmd=("$SCRIPT_DIR/list-artifacts-curl.sh" "--run-id" "$run_id" "--repo" "$owner_repo" "--token-file" "$TOKEN_FILE" "--json")

  if [[ -n "$name_filter" ]]; then
    list_cmd+=("--name-filter" "$name_filter")
  fi

  local artifacts_json
  if ! artifacts_json=$("${list_cmd[@]}" 2>/dev/null); then
    printf 'Error: Failed to list artifacts for run %s\n' "$run_id" >&2
    return 1
  fi

  printf '%s' "$artifacts_json"
  return 0
}

delete_single_artifact() {
  local owner_repo="$1"
  local artifact_id="$2"
  local token="$3"

  # Validate artifact ID format
  if [[ ! "$artifact_id" =~ ^[0-9]+$ ]]; then
    printf 'Error: Invalid artifact ID format: %s\n' "$artifact_id" >&2
    return 1
  fi

  # Get artifact metadata for confirmation/dry-run
  local metadata artifact_name artifact_info
  if metadata="$(get_artifact_metadata "$owner_repo" "$artifact_id" "$token")"; then
    artifact_name=$(echo "$metadata" | jq -r '.name // "unknown"')
    artifact_info="$artifact_id ($artifact_name)"
  else
    artifact_info="$artifact_id"
  fi

  # Dry-run mode
  if [[ "$DRY_RUN" == true ]]; then
    local size size_human
    if [[ -n "${metadata:-}" ]]; then
      size=$(echo "$metadata" | jq -r '.size_in_bytes // 0')
      if command -v bc >/dev/null 2>&1; then
        size_human="$(format_human_size "$size")"
      else
        size_human="${size} bytes"
      fi
      printf 'Dry-run: Would delete artifact %s (%s, %s)\n' "$artifact_id" "$artifact_name" "$size_human"
    else
      printf 'Dry-run: Would delete artifact %s\n' "$artifact_id"
    fi
    return 0
  fi

  # Confirmation
  if ! confirm_deletion 1 "$artifact_info"; then
    return 1
  fi

  # Delete artifact
  printf 'Deleting artifact %s...\n' "$artifact_id"
  if delete_artifact "$owner_repo" "$artifact_id" "$token"; then
    return 0
  else
    return 1
  fi
}

delete_all_artifacts() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  local name_filter="$4"

  # List artifacts
  local artifacts_json
  if ! artifacts_json="$(list_artifacts_for_deletion "$owner_repo" "$run_id" "$token" "$name_filter")"; then
    return 1
  fi

  # Extract artifact IDs
  local artifact_ids
  mapfile -t artifact_ids < <(echo "$artifacts_json" | jq -r '.artifacts[].id // empty')

  if [[ ${#artifact_ids[@]} -eq 0 ]]; then
    printf 'No artifacts found to delete\n'
    return 0
  fi

  local artifact_count=${#artifact_ids[@]}

  # Dry-run mode
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_deletion "$owner_repo" "$token" "${artifact_ids[@]}"
    return 0
  fi

  # Confirmation
  if ! confirm_deletion "$artifact_count" ""; then
    return 1
  fi

  # Delete each artifact
  printf 'Found %d artifact(s) for run %s\n' "$artifact_count" "$run_id"
  printf 'Deleting artifacts...\n'

  local success_count=0
  local fail_count=0

  for artifact_id in "${artifact_ids[@]}"; do
    if delete_artifact "$owner_repo" "$artifact_id" "$token"; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  done

  # Summary
  printf '\nSummary: %d deleted, %d failed\n' "$success_count" "$fail_count"

  if [[ $fail_count -gt 0 ]]; then
    return 1
  fi
  return 0
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --artifact-id)
        ARTIFACT_ID="$2"
        shift 2
        ;;
      --run-id)
        RUN_ID="$2"
        shift 2
        ;;
      --correlation-id)
        CORRELATION_ID="$2"
        shift 2
        ;;
      --all)
        DELETE_ALL=true
        shift
        ;;
      --confirm)
        CONFIRM=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --name-filter)
        NAME_FILTER="$2"
        shift 2
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

  # Validate input mode
  if [[ -z "$ARTIFACT_ID" && "$DELETE_ALL" != "true" ]]; then
    printf 'Error: Must specify --artifact-id or --run-id/--correlation-id with --all\n' >&2
    show_help >&2
    exit 2
  fi

  if [[ -n "$ARTIFACT_ID" && "$DELETE_ALL" == "true" ]]; then
    printf 'Error: Cannot use --artifact-id with --all\n' >&2
    show_help >&2
    exit 2
  fi

  if [[ "$DELETE_ALL" == true && -z "$RUN_ID" && -z "$CORRELATION_ID" ]]; then
    printf 'Error: Must specify --run-id or --correlation-id with --all\n' >&2
    show_help >&2
    exit 2
  fi

  # Load token
  local token
  token="$(load_token "$TOKEN_FILE")"

  # Resolve repository
  local owner_repo
  owner_repo="$(resolve_repository)"

  # Delete artifacts
  if [[ -n "$ARTIFACT_ID" ]]; then
    # Single artifact mode
    if ! delete_single_artifact "$owner_repo" "$ARTIFACT_ID" "$token"; then
      exit 1
    fi
  else
    # Bulk deletion mode
    local run_id
    run_id="$(resolve_run_id)"
    run_id="$(printf '%s' "${run_id}" | tr -d '[:space:]')"

    if ! delete_all_artifacts "$owner_repo" "$run_id" "$token" "$NAME_FILTER"; then
      exit 1
    fi
  fi
}

main "$@"

