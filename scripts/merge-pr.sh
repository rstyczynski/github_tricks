#!/usr/bin/env bash
set -euo pipefail

# Default values
TOKEN_FILE=".secrets/token"
REPO=""
PR_NUMBER=""
MERGE_METHOD=""
COMMIT_MESSAGE=""
CHECK_MERGEABLE=false
JSON_OUTPUT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Merge a pull request using GitHub REST API.

REQUIRED:
  --pr-number <number>    Pull request number
  --method <method>       Merge method: merge, squash, or rebase

OPTIONAL:
  --commit-message <msg>  Custom commit message for squash/merge (optional)
  --check-mergeable      Check mergeable state before attempting merge (recommended)
  --repo <owner/repo>    Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>    Path to token file (default: .secrets/token)
  --json                 Output JSON format
  --help                 Show this help message

EXAMPLES:
  # Merge PR with squash method
  $(basename "$0") --pr-number 123 --method squash

  # Merge with custom commit message
  $(basename "$0") --pr-number 123 --method squash --commit-message "Custom message"

  # Merge with mergeable state check
  $(basename "$0") --pr-number 123 --method merge --check-mergeable

  # JSON output
  $(basename "$0") --pr-number 123 --method rebase --json
EOF
}

resolve_repository() {
  if [[ -n "$REPO" ]]; then
    echo "$REPO"
    return
  fi

  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    echo "$GITHUB_REPOSITORY"
    return
  fi

  # Auto-detect from git
  local git_url
  git_url=$(git config --get remote.origin.url 2>/dev/null || echo "")

  if [[ -z "$git_url" ]]; then
    printf 'Error: Cannot resolve repository. Use --repo flag or set GITHUB_REPOSITORY env var\n' >&2
    exit 1
  fi

  # Parse GitHub URL
  if [[ "$git_url" =~ github.com[:/]([^/]+)/([^/]+)\.git?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    printf 'Error: Cannot parse repository from git URL: %s\n' "$git_url" >&2
    exit 1
  fi
}

check_mergeable_state() {
  local owner_repo="$1"
  local pr_number="$2"
  local token="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/pulls/$pr_number")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    printf 'Error: Failed to check PR status (HTTP %s)\n' "$http_code" >&2
    return 1
  fi

  local mergeable state
  mergeable=$(echo "$response_body" | jq -r '.mergeable // "null"')
  state=$(echo "$response_body" | jq -r '.state')

  if [[ "$state" != "open" ]]; then
    printf 'Error: Pull request #%s is not open (state: %s)\n' "$pr_number" "$state" >&2
    return 1
  fi

  if [[ "$mergeable" == "false" ]]; then
    printf 'Error: Pull request #%s cannot be merged (has conflicts or other issues)\n' "$pr_number" >&2
    return 1
  fi

  if [[ "$mergeable" == "null" ]]; then
    printf 'Warning: Mergeability not yet determined for PR #%s\n' "$pr_number" >&2
    printf 'Proceeding with merge attempt...\n' >&2
  fi

  return 0
}

build_merge_request_body() {
  local body_json="{"
  body_json+="\"merge_method\":$(jq -n --arg method "$MERGE_METHOD" '$method')"

  if [[ -n "$COMMIT_MESSAGE" ]]; then
    body_json+=",\"commit_message\":$(jq -n --arg msg "$COMMIT_MESSAGE" '$msg')"
  fi

  body_json+="}"
  echo "$body_json"
}

merge_pr() {
  local owner_repo="$1"
  local pr_number="$2"
  local token="$3"
  local body_json="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X PUT \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body_json" \
    "https://api.github.com/repos/$owner/$repo/pulls/$pr_number/merge")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    200)
      echo "$response_body"
      return 0
      ;;
    405)
      printf 'Error: Pull request #%s cannot be merged (Method Not Allowed)\n' "$pr_number" >&2
      printf '  Possible reasons: PR already merged, conflicts, or branch protection\n' >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2 || true
      return 1
      ;;
    409)
      printf 'Error: Merge conflict detected for PR #%s\n' "$pr_number" >&2
      echo "$response_body" | jq -r '.message // "Conflict details unavailable"' >&2 || true
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions or branch protection prevents merge\n' >&2
      echo "$response_body" | jq -r '.message // "Permission denied"' >&2 || true
      return 1
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      printf 'Error: Validation failed - %s\n' "$error_msg" >&2
      
      # Check for specific error details
      echo "$response_body" | jq -r '.errors[]? | "  - \(.field // "unknown"): \(.message // "error")" | .' >&2 || true
      return 1
      ;;
    404)
      printf 'Error: Pull request #%s not found\n' "$pr_number" >&2
      return 1
      ;;
    *)
      printf 'Error: API request failed (HTTP %s)\n' "$http_code" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2 || true
      return 1
      ;;
  esac
}

format_output_human() {
  local merge_json="$1"
  local merged sha message
  merged=$(echo "$merge_json" | jq -r '.merged // false')
  sha=$(echo "$merge_json" | jq -r '.sha // "unknown"')
  message=$(echo "$merge_json" | jq -r '.message // "Pull request merged successfully"')

  if [[ "$merged" == "true" ]]; then
    printf 'Pull Request #%s merged successfully\n' "$PR_NUMBER"
    printf 'Merge method: %s\n' "$MERGE_METHOD"
    printf 'Merged commit: %s\n' "$sha"
    if [[ -n "$COMMIT_MESSAGE" ]]; then
      printf 'Commit message: %s\n' "$COMMIT_MESSAGE"
    fi
  else
    printf 'Merge failed: %s\n' "$message"
  fi
}

format_output_json() {
  local merge_json="$1"
  local merged sha message
  merged=$(echo "$merge_json" | jq -r '.merged // false')
  sha=$(echo "$merge_json" | jq -r '.sha // ""')
  message=$(echo "$merge_json" | jq -r '.message // "Pull request merged successfully"')

  jq -n \
    --argjson pr_number "$PR_NUMBER" \
    --argjson merged "$merged" \
    --arg method "$MERGE_METHOD" \
    --arg sha "$sha" \
    --arg message "$message" \
    --arg commit_message "$COMMIT_MESSAGE" \
    '{
      pr_number: $pr_number,
      merged: $merged,
      merge_method: $method,
      sha: $sha,
      message: $message,
      commit_message: (if $commit_message != "" then $commit_message else null end)
    }'
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pr-number)
        PR_NUMBER="$2"
        shift 2
        ;;
      --method)
        MERGE_METHOD="$2"
        shift 2
        ;;
      --commit-message)
        COMMIT_MESSAGE="$2"
        shift 2
        ;;
      --check-mergeable)
        CHECK_MERGEABLE=true
        shift
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
      --help)
        usage
        exit 0
        ;;
      *)
        printf 'Error: Unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$PR_NUMBER" ]]; then
    printf 'Error: --pr-number is required\n' >&2
    usage >&2
    exit 2
  fi

  if [[ -z "$MERGE_METHOD" ]]; then
    printf 'Error: --method is required\n' >&2
    usage >&2
    exit 2
  fi

  # Validate merge method
  if [[ "$MERGE_METHOD" != "merge" && "$MERGE_METHOD" != "squash" && "$MERGE_METHOD" != "rebase" ]]; then
    printf 'Error: Invalid merge method: %s\n' "$MERGE_METHOD" >&2
    printf '  Valid methods: merge, squash, rebase\n' >&2
    exit 2
  fi

  # Load token
  if [[ ! -f "$TOKEN_FILE" ]]; then
    printf 'Error: Token file not found: %s\n' "$TOKEN_FILE" >&2
    exit 1
  fi
  local token
  token=$(cat "$TOKEN_FILE" | tr -d '\n\r ')

  # Resolve repository
  local owner_repo
  owner_repo=$(resolve_repository)

  # Check mergeable state if requested
  if [[ "$CHECK_MERGEABLE" == "true" ]]; then
    if ! check_mergeable_state "$owner_repo" "$PR_NUMBER" "$token"; then
      exit 1
    fi
  fi

  # Build merge request body
  local body_json
  body_json=$(build_merge_request_body)

  # Merge PR
  local merge_json
  if ! merge_json=$(merge_pr "$owner_repo" "$PR_NUMBER" "$token" "$body_json"); then
    exit 1
  fi

  # Format output
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    format_output_json "$merge_json"
  else
    format_output_human "$merge_json"
  fi
}

main "$@"

