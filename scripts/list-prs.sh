#!/usr/bin/env bash
set -euo pipefail

# Default values
TOKEN_FILE=".secrets/token"
REPO=""
STATE="open"
HEAD=""
BASE=""
SORT="created"
DIRECTION="desc"
PAGE=1
PER_PAGE=30
ALL_PAGES=false
JSON_OUTPUT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

List pull requests using GitHub REST API.

OPTIONAL:
  --state <state>         Filter by state: open, closed, or all (default: open)
  --head <branch>         Filter by source branch
  --base <branch>         Filter by target branch
  --sort <sort>           Sort by: created, updated, popularity (default: created)
  --direction <direction> Sort direction: asc or desc (default: desc)
  --page <n>              Page number (default: 1)
  --per-page <n>          Items per page (default: 30, max: 100)
  --all                   Fetch all pages automatically (ignores --page)
  --repo <owner/repo>     Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>     Path to token file (default: .secrets/token)
  --json                  Output JSON format
  --help                  Show this help message

EXAMPLES:
  # List open PRs (default)
  $(basename "$0")

  # List all PRs
  $(basename "$0") --state all

  # List PRs from specific branch
  $(basename "$0") --head feature-branch

  # List all PRs with pagination
  $(basename "$0") --state all --all

  # JSON output
  $(basename "$0") --json
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

build_query_string() {
  local query=""

  if [[ -n "$STATE" ]]; then
    query+="state=$STATE"
  fi

  if [[ -n "$HEAD" ]]; then
    [[ -n "$query" ]] && query+="&"
    query+="head=$HEAD"
  fi

  if [[ -n "$BASE" ]]; then
    [[ -n "$query" ]] && query+="&"
    query+="base=$BASE"
  fi

  if [[ -n "$SORT" ]]; then
    [[ -n "$query" ]] && query+="&"
    query+="sort=$SORT"
  fi

  if [[ -n "$DIRECTION" ]]; then
    [[ -n "$query" ]] && query+="&"
    query+="direction=$DIRECTION"
  fi

  if [[ "$ALL_PAGES" == "true" ]]; then
    [[ -n "$query" ]] && query+="&"
    query+="per_page=100"
  else
    [[ -n "$query" ]] && query+="&"
    query+="page=$PAGE&per_page=$PER_PAGE"
  fi

  echo "$query"
}

parse_link_header() {
  local link_header="$1"
  local rel="$2"

  # Link: <url1>; rel="next", <url2>; rel="last"
  echo "$link_header" | grep -oP "<[^>]+>; rel=\"$rel\"" | grep -oP "<[^>]+>" | tr -d '<>' || echo ""
}

fetch_prs() {
  local owner_repo="$1"
  local token="$2"
  local query="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local all_prs="[]"
  local page=1
  local per_page=100

  while true; do
    local current_query="${query}"
    if [[ "$ALL_PAGES" == "true" ]]; then
      # Replace page/per_page in query
      current_query=$(echo "$query" | sed "s/&page=[0-9]*&per_page=[0-9]*//; s/per_page=[0-9]*//")
      [[ -n "$current_query" ]] && current_query+="&"
      current_query+="page=$page&per_page=$per_page"
    fi

    local response headers http_code response_body
    response=$(curl -s -w "\n%{http_code}" -D /tmp/curl_headers_$$ \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$owner/$repo/pulls?$current_query" 2>/dev/null)

    http_code=$(echo "$response" | tail -n1)
    headers=$(grep -i "^link:" /tmp/curl_headers_$$ 2>/dev/null || echo "")
    response_body=$(echo "$response" | sed '$d')
    rm -f /tmp/curl_headers_$$

    if [[ "$http_code" != "200" ]]; then
      handle_api_error "$http_code" "$response_body"
      return 1
    fi

    # Merge with previous results
    if [[ "$ALL_PAGES" == "true" ]]; then
      all_prs=$(echo "$all_prs" "$response_body" | jq -s 'add')
    else
      all_prs="$response_body"
      break
    fi

    # Check if more pages
    local next_url
    next_url=$(parse_link_header "$headers" "next")
    if [[ -z "$next_url" ]]; then
      break
    fi
    page=$((page + 1))
  done

  echo "$all_prs"
}

handle_api_error() {
  local http_code="$1"
  local response_body="$2"

  case "$http_code" in
    404)
      printf 'Error: Repository not found\n' >&2
      ;;
    403)
      printf 'Error: Insufficient permissions to list pull requests\n' >&2
      ;;
    401)
      printf 'Error: Authentication failed. Check token permissions.\n' >&2
      ;;
    *)
      printf 'Error: API request failed (HTTP %s)\n' "$http_code" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2 || true
      ;;
  esac
}

format_table() {
  local prs_json="$1"
  local total
  total=$(echo "$prs_json" | jq 'length')

  if [[ "$total" -eq 0 ]]; then
    printf 'No pull requests found matching criteria.\n'
    return
  fi

  printf 'Pull Requests:\n'
  printf '┌──────┬─────────────────────────────────────┬──────────┬─────────────┬─────────────┐\n'
  printf '│  #   │ Title                               │ State    │ Head        │ Base        │\n'
  printf '├──────┼─────────────────────────────────────┼──────────┼─────────────┼─────────────┤\n'

  echo "$prs_json" | jq -r '.[] | "│ \(.number) │ \(.title | .[0:35] | "\(.)" + " " * (35 - length)) │ \(.state) │ \(.head.ref | .[0:11] | "\(.)" + " " * (11 - length)) │ \(.base.ref | .[0:11] | "\(.)" + " " * (11 - length)) │"'

  printf '└──────┴─────────────────────────────────────┴──────────┴─────────────┴─────────────┘\n'
  printf 'Showing %s pull request(s)\n' "$total"
}

format_output_json() {
  local prs_json="$1"
  echo "$prs_json" | jq '[.[] | {
    number: .number,
    title: .title,
    state: .state,
    head: {ref: .head.ref, sha: .head.sha},
    base: {ref: .base.ref, sha: .base.sha},
    url: .html_url,
    created_at: .created_at,
    updated_at: .updated_at
  }]'
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --state)
        STATE="$2"
        shift 2
        ;;
      --head)
        HEAD="$2"
        shift 2
        ;;
      --base)
        BASE="$2"
        shift 2
        ;;
      --sort)
        SORT="$2"
        shift 2
        ;;
      --direction)
        DIRECTION="$2"
        shift 2
        ;;
      --page)
        PAGE="$2"
        shift 2
        ;;
      --per-page)
        PER_PAGE="$2"
        shift 2
        ;;
      --all)
        ALL_PAGES=true
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

  # Build query string
  local query
  query=$(build_query_string)

  # Fetch PRs
  local prs_json
  if ! prs_json=$(fetch_prs "$owner_repo" "$token" "$query"); then
    exit 1
  fi

  # Format output
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    format_output_json "$prs_json"
  else
    format_table "$prs_json"
  fi
}

main "$@"

