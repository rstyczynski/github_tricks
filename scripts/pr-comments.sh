#!/usr/bin/env bash
set -euo pipefail

# Default values
TOKEN_FILE=".secrets/token"
REPO=""
PR_NUMBER=""
OPERATION=""
BODY=""
COMMENT_ID=""
FILE_PATH=""
LINE_NUMBER=""
SIDE=""
COMMIT_ID=""
REACTION=""
JSON_OUTPUT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Manage pull request comments using GitHub REST API.

REQUIRED:
  --pr-number <number>    Pull request number
  --operation <op>       Operation: add, add-inline, update, delete, react, list

OPERATION-SPECIFIC PARAMETERS:
  add:                   --body <text>
  add-inline:            --body <text> --file <path> --line <number> --side <left|right> [--commit-id <sha>]
  update:                --comment-id <id> --body <text>
  delete:                --comment-id <id>
  react:                 --comment-id <id> --reaction <emoji>
  list:                  (no additional parameters)

OPTIONAL:
  --repo <owner/repo>    Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>    Path to token file (default: .secrets/token)
  --json                 Output JSON format
  --help                 Show this help message

REACTIONS:
  Valid emoji reactions: +1, -1, laugh, confused, heart, hooray, rocket, eyes

EXAMPLES:
  # Add general comment
  $(basename "$0") --pr-number 123 --operation add --body "Great work!"

  # Add inline comment (commit ID auto-detected)
  $(basename "$0") --pr-number 123 --operation add-inline \\
    --body "Consider refactoring" --file src/main.go --line 42 --side right

  # Update comment
  $(basename "$0") --pr-number 123 --operation update \\
    --comment-id 456789 --body "Updated comment"

  # Delete comment
  $(basename "$0") --pr-number 123 --operation delete --comment-id 456789

  # Add reaction
  $(basename "$0") --pr-number 123 --operation react \\
    --comment-id 456789 --reaction +1

  # List comments
  $(basename "$0") --pr-number 123 --operation list --json
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

get_pr_head_commit() {
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
    return 1
  fi

  echo "$response_body" | jq -r '.head.sha'
}

add_general_comment() {
  local owner_repo="$1"
  local pr_number="$2"
  local token="$3"
  local body="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local body_json
  body_json=$(jq -n --arg body "$body" '{body: $body}')

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body_json" \
    "https://api.github.com/repos/$owner/$repo/issues/$pr_number/comments")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    201)
      echo "$response_body"
      return 0
      ;;
    404)
      printf 'Error: Pull request #%s not found\n' "$pr_number" >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to add comment\n' >&2
      return 1
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      printf 'Error: Validation failed - %s\n' "$error_msg" >&2
      return 1
      ;;
    *)
      printf 'Error: API request failed (HTTP %s)\n' "$http_code" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2 || true
      return 1
      ;;
  esac
}

add_inline_comment() {
  local owner_repo="$1"
  local pr_number="$2"
  local token="$3"
  local body="$4"
  local file_path="$5"
  local line_number="$6"
  local side="$7"
  local commit_id="$8"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  # Convert side to uppercase
  local side_upper
  side_upper=$(echo "$side" | tr '[:lower:]' '[:upper:]')

  local body_json
  body_json=$(jq -n \
    --arg body "$body" \
    --arg path "$file_path" \
    --argjson line "$line_number" \
    --arg side "$side_upper" \
    --arg commit_id "$commit_id" \
    '{
      body: $body,
      path: $path,
      line: $line,
      side: $side,
      commit_id: $commit_id
    }')

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body_json" \
    "https://api.github.com/repos/$owner/$repo/pulls/$pr_number/comments")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    201)
      echo "$response_body"
      return 0
      ;;
    404)
      printf 'Error: Pull request #%s not found\n' "$pr_number" >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to add inline comment\n' >&2
      return 1
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      printf 'Error: Validation failed - %s\n' "$error_msg" >&2
      printf '  Check that file path, line number, and commit ID are correct\n' >&2
      return 1
      ;;
    *)
      printf 'Error: API request failed (HTTP %s)\n' "$http_code" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2 || true
      return 1
      ;;
  esac
}

update_comment() {
  local owner_repo="$1"
  local comment_id="$2"
  local token="$3"
  local body="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local body_json
  body_json=$(jq -n --arg body "$body" '{body: $body}')

  # Try pulls/comments endpoint first (for review comments)
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body_json" \
    "https://api.github.com/repos/$owner/$repo/pulls/comments/$comment_id")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  # If 404, try issues/comments endpoint (for issue comments)
  if [[ "$http_code" == "404" ]]; then
    response=$(curl -s -w "\n%{http_code}" \
      -X PATCH \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      -d "$body_json" \
      "https://api.github.com/repos/$owner/$repo/issues/comments/$comment_id")
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
  fi

  case "$http_code" in
    200)
      echo "$response_body"
      return 0
      ;;
    404)
      printf 'Error: Comment #%s not found\n' "$comment_id" >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to update comment\n' >&2
      return 1
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      printf 'Error: Validation failed - %s\n' "$error_msg" >&2
      return 1
      ;;
    *)
      printf 'Error: API request failed (HTTP %s)\n' "$http_code" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2 || true
      return 1
      ;;
  esac
}

delete_comment() {
  local owner_repo="$1"
  local comment_id="$2"
  local token="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  # Try pulls/comments endpoint first (for review comments)
  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X DELETE \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/pulls/comments/$comment_id")

  http_code=$(echo "$response" | tail -n1)

  # If 404, try issues/comments endpoint (for issue comments)
  if [[ "$http_code" == "404" ]]; then
    response=$(curl -s -w "\n%{http_code}" \
      -X DELETE \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$owner/$repo/issues/comments/$comment_id")
    
    http_code=$(echo "$response" | tail -n1)
  fi

  case "$http_code" in
    204)
      return 0
      ;;
    404)
      printf 'Error: Comment #%s not found\n' "$comment_id" >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to delete comment\n' >&2
      return 1
      ;;
    *)
      printf 'Error: API request failed (HTTP %s)\n' "$http_code" >&2
      return 1
      ;;
  esac
}

add_reaction() {
  local owner_repo="$1"
  local comment_id="$2"
  local token="$3"
  local reaction="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local body_json
  body_json=$(jq -n --arg content "$reaction" '{content: $content}')

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body_json" \
    "https://api.github.com/repos/$owner/$repo/pulls/comments/$comment_id/reactions")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    200|201)
      echo "$response_body"
      return 0
      ;;
    404)
      printf 'Error: Comment #%s not found\n' "$comment_id" >&2
      return 1
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Invalid reaction"')
      printf 'Error: Invalid reaction - %s\n' "$error_msg" >&2
      printf '  Valid reactions: +1, -1, laugh, confused, heart, hooray, rocket, eyes\n' >&2
      return 1
      ;;
    *)
      printf 'Error: API request failed (HTTP %s)\n' "$http_code" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2 || true
      return 1
      ;;
  esac
}

list_comments() {
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
    "https://api.github.com/repos/$owner/$repo/pulls/$pr_number/comments")

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    200)
      echo "$response_body"
      return 0
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
  local comment_json="$1"
  local op="$2"

  case "$op" in
    add|add-inline|update)
      local comment_id url body created_at
      comment_id=$(echo "$comment_json" | jq -r '.id // .database_id // "unknown"')
      url=$(echo "$comment_json" | jq -r '.html_url // "unknown"')
      body=$(echo "$comment_json" | jq -r '.body // "unknown"')
      created_at=$(echo "$comment_json" | jq -r '.created_at // "unknown"')

      if [[ "$op" == "add" ]]; then
        printf 'Comment added successfully\n'
      elif [[ "$op" == "add-inline" ]]; then
        printf 'Inline comment added successfully\n'
      else
        printf 'Comment updated successfully\n'
      fi
      printf 'Comment ID: %s\n' "$comment_id"
      printf 'URL: %s\n' "$url"
      ;;
    delete)
      printf 'Comment deleted successfully\n'
      ;;
    react)
      local reaction_id content
      reaction_id=$(echo "$comment_json" | jq -r '.id // "unknown"')
      content=$(echo "$comment_json" | jq -r '.content // "unknown"')
      printf 'Reaction added successfully\n'
      printf 'Reaction ID: %s\n' "$reaction_id"
      printf 'Content: %s\n' "$content"
      ;;
    list)
      local total
      total=$(echo "$comment_json" | jq 'length')
      if [[ "$total" -eq 0 ]]; then
        printf 'No comments found on PR #%s\n' "$PR_NUMBER"
      else
        printf 'Found %s comment(s) on PR #%s:\n' "$total" "$PR_NUMBER"
        echo "$comment_json" | jq -r '.[] | "  - ID: \(.id // .database_id) | \(.body[0:50] // "no body")"'
      fi
      ;;
  esac
}

format_output_json() {
  local comment_json="$1"
  local op="$2"

  case "$op" in
    add|add-inline|update)
      local comment_id url body created_at
      comment_id=$(echo "$comment_json" | jq -r '.id // .database_id')
      url=$(echo "$comment_json" | jq -r '.html_url')
      body=$(echo "$comment_json" | jq -r '.body')
      created_at=$(echo "$comment_json" | jq -r '.created_at')

      jq -n \
        --argjson comment_id "$comment_id" \
        --arg url "$url" \
        --arg body "$body" \
        --arg created_at "$created_at" \
        '{
          comment_id: $comment_id,
          url: $url,
          body: $body,
          created_at: $created_at
        }'
      ;;
    delete)
      jq -n \
        --argjson pr_number "$PR_NUMBER" \
        --argjson comment_id "$COMMENT_ID" \
        '{
          pr_number: $pr_number,
          comment_id: $comment_id,
          deleted: true
        }'
      ;;
    react)
      local reaction_id content
      reaction_id=$(echo "$comment_json" | jq -r '.id')
      content=$(echo "$comment_json" | jq -r '.content')

      jq -n \
        --argjson reaction_id "$reaction_id" \
        --arg content "$content" \
        '{
          reaction_id: $reaction_id,
          content: $content
        }'
      ;;
    list)
      echo "$comment_json" | jq '[.[] | {
        id: (.id // .database_id),
        body: .body,
        created_at: .created_at,
        html_url: .html_url,
        user: .user.login
      }]'
      ;;
  esac
}

validate_operation_params() {
  case "$OPERATION" in
    add)
      if [[ -z "$BODY" ]]; then
        printf 'Error: --body is required for add operation\n' >&2
        return 1
      fi
      ;;
    add-inline)
      if [[ -z "$BODY" ]]; then
        printf 'Error: --body is required for add-inline operation\n' >&2
        return 1
      fi
      if [[ -z "$FILE_PATH" ]]; then
        printf 'Error: --file is required for add-inline operation\n' >&2
        return 1
      fi
      if [[ -z "$LINE_NUMBER" ]]; then
        printf 'Error: --line is required for add-inline operation\n' >&2
        return 1
      fi
      if [[ -z "$SIDE" ]]; then
        printf 'Error: --side is required for add-inline operation\n' >&2
        return 1
      fi
      if [[ "$SIDE" != "left" && "$SIDE" != "right" ]]; then
        printf 'Error: --side must be "left" or "right"\n' >&2
        return 1
      fi
      ;;
    update)
      if [[ -z "$COMMENT_ID" ]]; then
        printf 'Error: --comment-id is required for update operation\n' >&2
        return 1
      fi
      if [[ -z "$BODY" ]]; then
        printf 'Error: --body is required for update operation\n' >&2
        return 1
      fi
      ;;
    delete)
      if [[ -z "$COMMENT_ID" ]]; then
        printf 'Error: --comment-id is required for delete operation\n' >&2
        return 1
      fi
      ;;
    react)
      if [[ -z "$COMMENT_ID" ]]; then
        printf 'Error: --comment-id is required for react operation\n' >&2
        return 1
      fi
      if [[ -z "$REACTION" ]]; then
        printf 'Error: --reaction is required for react operation\n' >&2
        return 1
      fi
      ;;
    list)
      # No additional parameters needed
      ;;
    *)
      printf 'Error: Invalid operation: %s\n' "$OPERATION" >&2
      printf '  Valid operations: add, add-inline, update, delete, react, list\n' >&2
      return 1
      ;;
  esac
  return 0
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pr-number)
        PR_NUMBER="$2"
        shift 2
        ;;
      --operation)
        OPERATION="$2"
        shift 2
        ;;
      --body)
        BODY="$2"
        shift 2
        ;;
      --comment-id)
        COMMENT_ID="$2"
        shift 2
        ;;
      --file)
        FILE_PATH="$2"
        shift 2
        ;;
      --line)
        LINE_NUMBER="$2"
        shift 2
        ;;
      --side)
        SIDE="$2"
        shift 2
        ;;
      --commit-id)
        COMMIT_ID="$2"
        shift 2
        ;;
      --reaction)
        REACTION="$2"
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

  if [[ -z "$OPERATION" ]]; then
    printf 'Error: --operation is required\n' >&2
    usage >&2
    exit 2
  fi

  # Validate operation-specific parameters
  if ! validate_operation_params; then
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

  # Auto-detect commit ID for inline comments if not provided
  if [[ "$OPERATION" == "add-inline" && -z "$COMMIT_ID" ]]; then
    if ! COMMIT_ID=$(get_pr_head_commit "$owner_repo" "$PR_NUMBER" "$token"); then
      printf 'Error: Failed to get PR head commit. Provide --commit-id explicitly.\n' >&2
      exit 1
    fi
  fi

  # Execute operation
  local result
  case "$OPERATION" in
    add)
      if ! result=$(add_general_comment "$owner_repo" "$PR_NUMBER" "$token" "$BODY"); then
        exit 1
      fi
      ;;
    add-inline)
      if ! result=$(add_inline_comment "$owner_repo" "$PR_NUMBER" "$token" "$BODY" "$FILE_PATH" "$LINE_NUMBER" "$SIDE" "$COMMIT_ID"); then
        exit 1
      fi
      ;;
    update)
      if ! result=$(update_comment "$owner_repo" "$COMMENT_ID" "$token" "$BODY"); then
        exit 1
      fi
      ;;
    delete)
      if ! delete_comment "$owner_repo" "$COMMENT_ID" "$token"; then
        exit 1
      fi
      # For delete, create a simple result for output formatting
      result="{\"deleted\": true}"
      ;;
    react)
      if ! result=$(add_reaction "$owner_repo" "$COMMENT_ID" "$token" "$REACTION"); then
        exit 1
      fi
      ;;
    list)
      if ! result=$(list_comments "$owner_repo" "$PR_NUMBER" "$token"); then
        exit 1
      fi
      ;;
  esac

  # Format output
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    format_output_json "$result" "$OPERATION"
  else
    format_output_human "$result" "$OPERATION"
  fi
}

main "$@"

