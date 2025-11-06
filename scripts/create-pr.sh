#!/usr/bin/env bash
set -euo pipefail

# Default values
TOKEN_FILE="./secrets/github_token"
REPO=""
HEAD=""
BASE="main"
TITLE=""
BODY=""
REVIEWERS=""
LABELS=""
ISSUE=""
DRAFT=false
JSON_OUTPUT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create a pull request using GitHub REST API.

REQUIRED:
  --head <branch>         Source branch name
  --title <title>         PR title

OPTIONAL:
  --base <branch>         Target branch name (default: main)
  --body <body>           PR description/body
  --reviewers <users>     Comma-separated list of reviewer usernames
  --labels <labels>       Comma-separated list of label names (must exist)
  --issue <number>        Issue number to link
  --draft                 Create as draft PR
  --repo <owner/repo>     Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>     Path to token file (default: ./secrets/github_token)
  --json                  Output JSON format
  --help                  Show this help message

EXAMPLES:
  # Create PR with minimal fields
  $(basename "$0") --head feature-branch --title "Feature: Add new functionality"

  # Create PR with all metadata
  $(basename "$0") --head feature-branch --base main --title "Feature" \\
    --body "Description" --reviewers user1,user2 --labels enhancement,bug \\
    --issue 123 --draft

  # Create PR with auto-detected repository
  $(basename "$0") --head feature-branch --title "Feature" --json
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

build_request_body() {
  local body_json="{"
  body_json+="\"title\":$(jq -n --arg title "$TITLE" '$title'),"
  body_json+="\"head\":$(jq -n --arg head "$HEAD" '$head'),"
  body_json+="\"base\":$(jq -n --arg base "$BASE" '$base')"

  if [[ -n "$BODY" ]]; then
    body_json+=",\"body\":$(jq -n --arg body "$BODY" '$body')"
  fi

  if [[ "$DRAFT" == "true" ]]; then
    body_json+=",\"draft\":true"
  fi

  if [[ -n "$REVIEWERS" ]]; then
    local reviewers_array
    reviewers_array=$(echo "$REVIEWERS" | tr ',' '\n' | jq -R . | jq -s .)
    body_json+=",\"reviewers\":$reviewers_array"
  fi

  if [[ -n "$LABELS" ]]; then
    local labels_array
    labels_array=$(echo "$LABELS" | tr ',' '\n' | jq -R . | jq -s .)
    body_json+=",\"labels\":$labels_array"
  fi

  if [[ -n "$ISSUE" ]]; then
    body_json+=",\"issue\":$ISSUE"
  fi

  body_json+="}"
  echo "$body_json"
}

create_pr() {
  local owner_repo="$1"
  local token="$2"
  local body_json="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body_json" \
    "https://api.github.com/repos/$owner/$repo/pulls")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    201)
      echo "$response_body"
      return 0
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      printf 'Error: Validation failed - %s\n' "$error_msg" >&2
      # Try to extract specific errors
      echo "$response_body" | jq -r '.errors[]? | "  - \(.field // "unknown"): \(.message // "error")" | .' >&2 || true
      return 1
      ;;
    404)
      printf 'Error: Repository or branch not found\n' >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to create pull request\n' >&2
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
  local pr_number title url state head base draft
  pr_number=$(echo "$pr_json" | jq -r '.number')
  title=$(echo "$pr_json" | jq -r '.title')
  url=$(echo "$pr_json" | jq -r '.html_url')
  state=$(echo "$pr_json" | jq -r '.state')
  head=$(echo "$pr_json" | jq -r '.head.ref')
  base=$(echo "$pr_json" | jq -r '.base.ref')
  draft=$(echo "$pr_json" | jq -r '.draft // false')

  printf 'Pull Request #%s created successfully\n' "$pr_number"
  printf 'Title: %s\n' "$title"
  printf 'URL: %s\n' "$url"
  printf 'Status: %s\n' "$state"
  printf 'Head: %s\n' "$head"
  printf 'Base: %s\n' "$base"
  if [[ "$draft" == "true" ]]; then
    printf 'Draft: yes\n'
  fi
}

format_output_json() {
  local pr_json="$1"
  local pr_number title url state head base draft created_at
  pr_number=$(echo "$pr_json" | jq -r '.number')
  title=$(echo "$pr_json" | jq -r '.title')
  url=$(echo "$pr_json" | jq -r '.html_url')
  state=$(echo "$pr_json" | jq -r '.state')
  head=$(echo "$pr_json" | jq -r '.head.ref')
  base=$(echo "$pr_json" | jq -r '.base.ref')
  draft=$(echo "$pr_json" | jq -r '.draft // false')
  created_at=$(echo "$pr_json" | jq -r '.created_at')

  jq -n \
    --argjson pr_number "$pr_number" \
    --arg title "$title" \
    --arg url "$url" \
    --arg state "$state" \
    --arg head "$head" \
    --arg base "$base" \
    --argjson draft "$draft" \
    --arg created_at "$created_at" \
    '{
      pr_number: $pr_number,
      title: $title,
      url: $url,
      status: $state,
      head: $head,
      base: $base,
      draft: $draft,
      created_at: $created_at
    }'
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --head)
        HEAD="$2"
        shift 2
        ;;
      --base)
        BASE="$2"
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
      --reviewers)
        REVIEWERS="$2"
        shift 2
        ;;
      --labels)
        LABELS="$2"
        shift 2
        ;;
      --issue)
        ISSUE="$2"
        shift 2
        ;;
      --draft)
        DRAFT=true
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
  if [[ -z "$HEAD" ]]; then
    printf 'Error: --head is required\n' >&2
    usage >&2
    exit 2
  fi

  if [[ -z "$TITLE" ]]; then
    printf 'Error: --title is required\n' >&2
    usage >&2
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

  # Build request body
  local body_json
  body_json=$(build_request_body)

  # Create PR
  local pr_json
  if ! pr_json=$(create_pr "$owner_repo" "$token" "$body_json"); then
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

