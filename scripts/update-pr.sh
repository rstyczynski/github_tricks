#!/usr/bin/env bash
set -euo pipefail

# Default values
TOKEN_FILE=".secrets/token"
REPO=""
PR_NUMBER=""
TITLE=""
BODY=""
STATE=""
BASE=""
JSON_OUTPUT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Update pull request properties using GitHub REST API.

REQUIRED:
  --pr-number <number>    Pull request number

OPTIONAL (at least one required):
  --title <title>         New PR title
  --body <body>           New PR description/body
  --state <state>         PR state: open or closed
  --base <branch>         New target branch
  --repo <owner/repo>     Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>     Path to token file (default: .secrets/token)
  --json                  Output JSON format
  --help                  Show this help message

EXAMPLES:
  # Update title only
  $(basename "$0") --pr-number 123 --title "Updated title"

  # Update multiple fields
  $(basename "$0") --pr-number 123 --title "New title" --body "New body" --state open

  # Change base branch
  $(basename "$0") --pr-number 123 --base main

  # Close PR
  $(basename "$0") --pr-number 123 --state closed

  # JSON output
  $(basename "$0") --pr-number 123 --title "Updated" --json
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

build_update_payload() {
  local payload="{"
  local has_fields=false

  if [[ -n "$TITLE" ]]; then
    payload+="\"title\":$(jq -n --arg title "$TITLE" '$title')"
    has_fields=true
  fi

  if [[ -n "$BODY" ]]; then
    [[ "$has_fields" == "true" ]] && payload+=","
    payload+="\"body\":$(jq -n --arg body "$BODY" '$body')"
    has_fields=true
  fi

  if [[ -n "$STATE" ]]; then
    [[ "$has_fields" == "true" ]] && payload+=","
    payload+="\"state\":$(jq -n --arg state "$STATE" '$state')"
    has_fields=true
  fi

  if [[ -n "$BASE" ]]; then
    [[ "$has_fields" == "true" ]] && payload+=","
    payload+="\"base\":$(jq -n --arg base "$BASE" '$base')"
    has_fields=true
  fi

  if [[ "$has_fields" == "false" ]]; then
    printf 'Error: At least one update field required (--title, --body, --state, or --base)\n' >&2
    return 1
  fi

  payload+="}"
  echo "$payload"
}

update_pr() {
  local owner_repo="$1"
  local pr_number="$2"
  local token="$3"
  local payload="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "https://api.github.com/repos/$owner/$repo/pulls/$pr_number")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    200)
      echo "$response_body"
      return 0
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      printf 'Error: Validation failed - %s\n' "$error_msg" >&2

      # Check for merge conflict
      if echo "$response_body" | jq -e '.errors[]? | select(.field == "base")' >/dev/null 2>&1; then
        printf '  Merge conflict detected when changing base branch.\n' >&2
        printf '  The PR cannot be merged into the new base branch.\n' >&2
      fi

      # Show field errors
      echo "$response_body" | jq -r '.errors[]? | "  - \(.field // "unknown"): \(.message // "error")" | .' >&2 || true
      return 1
      ;;
    404)
      printf 'Error: Pull request #%s not found\n' "$pr_number" >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to update pull request\n' >&2
      return 1
      ;;
    401)
      printf 'Error: Authentication failed. Check token permissions.\n' >&2
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
  local pr_json="$1"
  local pr_number title url state base
  pr_number=$(echo "$pr_json" | jq -r '.number')
  title=$(echo "$pr_json" | jq -r '.title')
  url=$(echo "$pr_json" | jq -r '.html_url')
  state=$(echo "$pr_json" | jq -r '.state')
  base=$(echo "$pr_json" | jq -r '.base.ref')

  printf 'Pull Request #%s updated successfully\n' "$pr_number"
  printf 'Title: %s\n' "$title"
  printf 'URL: %s\n' "$url"
  printf 'Status: %s\n' "$state"
  printf 'Base: %s\n' "$base"
}

format_output_json() {
  local pr_json="$1"
  local pr_number title url state base updated_at
  pr_number=$(echo "$pr_json" | jq -r '.number')
  title=$(echo "$pr_json" | jq -r '.title')
  url=$(echo "$pr_json" | jq -r '.html_url')
  state=$(echo "$pr_json" | jq -r '.state')
  base=$(echo "$pr_json" | jq -r '.base.ref')
  updated_at=$(echo "$pr_json" | jq -r '.updated_at')

  jq -n \
    --argjson pr_number "$pr_number" \
    --arg title "$title" \
    --arg url "$url" \
    --arg state "$state" \
    --arg base "$base" \
    --arg updated_at "$updated_at" \
    '{
      pr_number: $pr_number,
      title: $title,
      url: $url,
      status: $state,
      base: $base,
      updated_at: $updated_at
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
      --title)
        TITLE="$2"
        shift 2
        ;;
      --body)
        BODY="$2"
        shift 2
        ;;
      --state)
        STATE="$2"
        shift 2
        ;;
      --base)
        BASE="$2"
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

  # Build update payload (validates at least one field)
  local payload
  if ! payload=$(build_update_payload); then
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

  # Update PR
  local pr_json
  if ! pr_json=$(update_pr "$owner_repo" "$PR_NUMBER" "$token" "$payload"); then
    exit 1
  fi

  # Format output
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    format_output_json "$pr_json"
  else
    format_output_human "$pr_json"
  fi
}

main "$@"

