# Sprint 14 - Design

## GH-20. Merge Pull Request

Status: Progress

## GH-22. Pull Request Comments

Status: Progress

## Overview

Sprint 14 extends Pull Request management capabilities from Sprint 13 by adding merge operations and comment management. This sprint builds upon established patterns from Sprint 13 (create, list, update PRs) to deliver two additional PR operations: merging with different strategies and managing PR comments.

**Key Design Decisions**:
- Use curl-based REST API approach (following Sprint 13 pattern)
- Token authentication from `.secrets/token` file
- Check mergeable state before merge attempt (informative, prevents unnecessary API calls)
- Support all three merge strategies with optional commit message customization
- Single script for PR comments with operation flags (add, update, delete, react)
- Support both general and inline comments in one script
- Follow established input method priority order
- Comprehensive error handling for all HTTP status codes

## Feasibility Analysis

### GitHub API Capabilities

**GH-20 (Merge PR)** - `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge`:
- ✅ API endpoint available and documented
- ✅ All three merge strategies supported: merge, squash, rebase
- ✅ Mergeable state checkable via PR details endpoint (`mergeable` field)
- ✅ Commit message customization for squash/merge (`commit_message` parameter)
- ✅ Error codes well-documented (200, 405, 409, 403, 422, 404)
- Documentation: https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request

**GH-22 (PR Comments)**:
- ✅ General comments: `POST /repos/{owner}/{repo}/issues/{issue_number}/comments`
- ✅ Inline comments: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`
- ✅ Update comments: `PATCH /repos/{owner}/{repo}/pulls/comments/{comment_id}`
- ✅ Delete comments: `DELETE /repos/{owner}/{repo}/pulls/comments/{comment_id}`
- ✅ Reactions: `POST /repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions`
- ✅ List comments: `GET /repos/{owner}/{repo}/pulls/{pull_number}/comments` (for finding comment IDs)
- ✅ All endpoints documented
- Documentation: https://docs.github.com/en/rest/pulls/comments

### Authentication

**Token File Pattern** (from Sprint 13):
- Token stored in: `.secrets/token`
- Header format: `Authorization: Bearer <token>`
- Required permissions: `repo` scope (classic token) or `Pull requests: Write` (fine-grained token)

### Repository Resolution

**Auto-detection from git context** (following Sprint 13 pattern):
```bash
git config --get remote.origin.url
# Parse: https://github.com/owner/repo.git or git@github.com:owner/repo.git
```

**Fallback options**:
1. `--repo owner/repo` CLI flag
2. `GITHUB_REPOSITORY` environment variable
3. Error if cannot resolve

### Feasibility Conclusion

**Fully achievable** - Both backlog items can be implemented:
- ✅ GitHub API provides comprehensive merge and comments endpoints
- ✅ All required operations supported
- ✅ Authentication pattern established (Sprint 13)
- ✅ No platform limitations identified

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│          Sprint 14: PR Merge & Comments Management              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-20: Merge Pull Request                                │ │
│  │                                                            │ │
│  │  Input: --pr-number, --method, [--commit-message],        │ │
│  │         [--check-mergeable]                                │ │
│  │         ↓                                                  │ │
│  │  Optional: Check mergeable state                          │ │
│  │         ↓                                                  │ │
│  │  PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge     │ │
│  │         ↓                                                  │ │
│  │  Output: Merge result (merged commit SHA, message)        │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-22: Pull Request Comments                             │ │
│  │                                                            │ │
│  │  Operations:                                               │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │ │
│  │  │   Add    │  │  Update  │  │  Delete  │  │  React   │ │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │ │
│  │       │            │            │            │           │ │
│  │       └────────────┴────────────┴────────────┘           │ │
│  │                            │                              │ │
│  │  Input: --pr-number, --operation, [--body],               │ │
│  │         [--comment-id], [--file], [--line], [--side],    │ │
│  │         [--commit-id], [--reaction]                       │ │
│  │         ↓                                                  │ │
│  │  POST/PATCH/DELETE /repos/{owner}/{repo}/...             │ │
│  │         ↓                                                  │ │
│  │  Output: Comment details or operation result              │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Shared Components:                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Token Auth  │  │  Repo Resolve │  │  Error Handle│       │
│  │  (Sprint 13) │  │  (Sprint 13)  │  │  (Sprint 13) │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### GH-20. Merge Pull Request

#### Script Design: `scripts/merge-pr.sh`

**Command-line Interface**:

```bash
scripts/merge-pr.sh --pr-number <number> --method <method> [--commit-message <message>] 
                     [--check-mergeable] [--repo <owner/repo>] [--token-file <path>] 
                     [--json] [--help]
```

**Parameters**:
- `--pr-number <number>` - Pull request number (required)
- `--method <method>` - Merge method: merge, squash, or rebase (required)
- `--commit-message <message>` - Custom commit message for squash/merge (optional)
- `--check-mergeable` - Check mergeable state before attempting merge (optional, recommended)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `.secrets/token`)
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Input Resolution**:
- Required parameters: `--pr-number`, `--method` (error if missing)
- Optional parameters: `--commit-message` (only used for squash/merge), `--check-mergeable`
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var

**API Request Body**:

```json
{
  "commit_message": "Custom merge message",
  "merge_method": "squash"
}
```

**Note**: `commit_message` only used for squash and merge methods. Rebase uses commit messages from individual commits.

**Mergeable State Check** (if `--check-mergeable` specified):

Before attempting merge, check PR details:
```bash
GET /repos/{owner}/{repo}/pulls/{pull_number}
```

Check `mergeable` field:
- `true`: PR can be merged
- `false`: PR has conflicts or other issues
- `null`: Mergeability not yet determined (may need to wait)

**Output Formats**:

**Human-readable (default)**:
```
Pull Request #123 merged successfully
Merge method: squash
Merged commit: abc123def456...
Commit message: Custom merge message
```

**JSON output (--json)**:
```json
{
  "pr_number": 123,
  "merged": true,
  "merge_method": "squash",
  "sha": "abc123def456...",
  "message": "Pull request merged successfully",
  "commit_message": "Custom merge message"
}
```

**Implementation Details**:

**1. Check mergeable state** (if `--check-mergeable`):
```bash
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
```

**2. Build merge request body**:
```bash
build_merge_request_body() {
  local body_json="{"
  body_json+="\"merge_method\":$(jq -n --arg method "$MERGE_METHOD" '$method')"

  if [[ -n "$COMMIT_MESSAGE" ]]; then
    body_json+=",\"commit_message\":$(jq -n --arg msg "$COMMIT_MESSAGE" '$msg')"
  fi

  body_json+="}"
  echo "$body_json"
}
```

**3. Merge PR via API**:
```bash
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
```

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 200 | Success | N/A (output merge details) |
| 405 | Not mergeable | "Cannot be merged (Method Not Allowed)" + reasons |
| 409 | Merge conflict | "Merge conflict detected" + details |
| 403 | Permission/branch protection | "Insufficient permissions or branch protection" |
| 422 | Validation error | "Validation failed - {message}" + field errors |
| 404 | PR not found | "Pull request #{number} not found" |
| Other | Unknown error | "API request failed (HTTP {code})" |

**Exit Codes**:
- `0`: PR merged successfully
- `1`: Error (API error, merge conflict, validation failure, missing parameters)
- `2`: Invalid arguments or missing required parameters

### GH-22. Pull Request Comments

#### Script Design: `scripts/pr-comments.sh`

**Command-line Interface**:

```bash
scripts/pr-comments.sh --pr-number <number> --operation <operation> [--body <body>] 
                        [--comment-id <id>] [--file <path>] [--line <number>] 
                        [--side <left|right>] [--commit-id <sha>] [--reaction <emoji>] 
                        [--repo <owner/repo>] [--token-file <path>] [--json] [--help]
```

**Parameters**:
- `--pr-number <number>` - Pull request number (required)
- `--operation <operation>` - Operation: add, add-inline, update, delete, react, list (required)
- `--body <body>` - Comment body/text (required for add, add-inline, update)
- `--comment-id <id>` - Comment ID (required for update, delete, react)
- `--file <path>` - File path for inline comments (required for add-inline)
- `--line <number>` - Line number for inline comments (required for add-inline)
- `--side <left|right>` - Side for inline comments: left (deleted) or right (added) (required for add-inline)
- `--commit-id <sha>` - Commit SHA for inline comments (optional, auto-detected if omitted)
- `--reaction <emoji>` - Emoji reaction: +1, -1, laugh, confused, heart, hooray, rocket, eyes (required for react)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `.secrets/token`)
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Operations**:

1. **`add`** - Add general PR comment (issue-level)
   - Required: `--pr-number`, `--body`
   - Endpoint: `POST /repos/{owner}/{repo}/issues/{issue_number}/comments`

2. **`add-inline`** - Add inline code review comment
   - Required: `--pr-number`, `--body`, `--file`, `--line`, `--side`
   - Optional: `--commit-id` (auto-detected from PR head if omitted)
   - Endpoint: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`

3. **`update`** - Update existing comment
   - Required: `--pr-number`, `--comment-id`, `--body`
   - Endpoint: `PATCH /repos/{owner}/{repo}/pulls/comments/{comment_id}`

4. **`delete`** - Delete comment
   - Required: `--pr-number`, `--comment-id`
   - Endpoint: `DELETE /repos/{owner}/{repo}/pulls/comments/{comment_id}`

5. **`react`** - Add reaction to comment
   - Required: `--pr-number`, `--comment-id`, `--reaction`
   - Endpoint: `POST /repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions`

6. **`list`** - List comments on PR
   - Required: `--pr-number`
   - Endpoint: `GET /repos/{owner}/{repo}/pulls/{pull_number}/comments`

**Input Resolution**:
- Required parameters depend on operation (validated per operation)
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var

**API Request Bodies**:

**Add general comment**:
```json
{
  "body": "Great work on this PR!"
}
```

**Add inline comment**:
```json
{
  "body": "Consider refactoring this function",
  "path": "src/main.go",
  "line": 42,
  "side": "RIGHT",
  "commit_id": "abc123..."
}
```

**Update comment**:
```json
{
  "body": "Updated comment text"
}
```

**Add reaction**:
```json
{
  "content": "+1"
}
```

**Output Formats**:

**Human-readable (default)**:
```
Comment added successfully
Comment ID: 123456
URL: https://github.com/owner/repo/pull/123#discussion_r123456
```

**JSON output (--json)**:
```json
{
  "comment_id": 123456,
  "url": "https://github.com/owner/repo/pull/123#discussion_r123456",
  "body": "Great work!",
  "created_at": "2025-11-06T19:30:00Z"
}
```

**Implementation Details**:

**1. Auto-detect commit ID for inline comments**:
```bash
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
```

**2. Add general comment**:
```bash
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
```

**3. Add inline comment**:
```bash
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

  local body_json
  body_json=$(jq -n \
    --arg body "$body" \
    --arg path "$file_path" \
    --argjson line "$line_number" \
    --arg side "$side" \
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
```

**4. Update comment**:
```bash
update_comment() {
  local owner_repo="$1"
  local comment_id="$2"
  local token="$3"
  local body="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local body_json
  body_json=$(jq -n --arg body "$body" '{body: $body}')

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
```

**5. Delete comment**:
```bash
delete_comment() {
  local owner_repo="$1"
  local comment_id="$2"
  local token="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X DELETE \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/pulls/comments/$comment_id")

  http_code=$(echo "$response" | tail -n1)

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
```

**6. Add reaction**:
```bash
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
```

**7. List comments**:
```bash
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
```

**Error Handling**:

| Operation | HTTP Code | Scenario | Error Message |
|-----------|-----------|----------|---------------|
| All | 201/200 | Success | N/A (output comment details) |
| All | 404 | PR/Comment not found | "Pull request #{number} not found" or "Comment #{id} not found" |
| All | 403 | Insufficient permissions | "Insufficient permissions to {operation} comment" |
| Add/Update | 422 | Validation error | "Validation failed - {message}" |
| React | 422 | Invalid reaction | "Invalid reaction - {message}" + valid reactions list |
| All | Other | Unknown error | "API request failed (HTTP {code})" |

**Exit Codes**:
- `0`: Operation successful
- `1`: Error (API error, validation failure, missing parameters)
- `2`: Invalid arguments or missing required parameters

## Integration Patterns

### Pattern 1: Create → Comment → Merge PR

```bash
# Create PR
pr_result=$(scripts/create-pr.sh \
  --head feature-branch \
  --base main \
  --title "Feature: Add new functionality" \
  --json)

pr_number=$(echo "$pr_result" | jq -r '.pr_number')

# Add general comment
scripts/pr-comments.sh \
  --pr-number "$pr_number" \
  --operation add \
  --body "Great work! Ready to merge." \
  --json

# Merge PR
scripts/merge-pr.sh \
  --pr-number "$pr_number" \
  --method squash \
  --check-mergeable \
  --json
```

### Pattern 2: Add Inline Comment

```bash
# Add inline comment (commit ID auto-detected)
scripts/pr-comments.sh \
  --pr-number 123 \
  --operation add-inline \
  --body "Consider refactoring this function" \
  --file src/main.go \
  --line 42 \
  --side right \
  --json
```

### Pattern 3: Update Comment

```bash
# List comments to find comment ID
comments=$(scripts/pr-comments.sh --pr-number 123 --operation list --json)
comment_id=$(echo "$comments" | jq -r '.[0].id')

# Update comment
scripts/pr-comments.sh \
  --pr-number 123 \
  --operation update \
  --comment-id "$comment_id" \
  --body "Updated comment text" \
  --json
```

## Testing Strategy

### GH-20 (Merge Pull Request)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-20-1 | Merge with merge method | PR merged, merge commit created |
| GH-20-2 | Merge with squash method | PR merged, single commit created |
| GH-20-3 | Merge with rebase method | PR merged, commits rebased |
| GH-20-4 | Merge with custom commit message | Custom message used for squash/merge |
| GH-20-5 | Check mergeable state (mergeable) | Merge proceeds |
| GH-20-6 | Check mergeable state (not mergeable) | Error before merge attempt |
| GH-20-7 | Merge conflict | HTTP 405/409, error message |
| GH-20-8 | Required status checks pending | HTTP 403/422, error message |
| GH-20-9 | Branch protection | HTTP 403, error message |
| GH-20-10 | Already merged PR | HTTP 405, error message |
| GH-20-11 | Invalid PR number | HTTP 404, error message |
| GH-20-12 | JSON output format | Valid JSON with merge details |

### GH-22 (Pull Request Comments)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-22-1 | Add general comment | Comment added, returns comment ID |
| GH-22-2 | Add inline comment | Inline comment added at specified line |
| GH-22-3 | Add inline comment (auto-detect commit) | Commit ID auto-detected from PR head |
| GH-22-4 | Update comment | Comment body updated |
| GH-22-5 | Delete comment | Comment deleted (HTTP 204) |
| GH-22-6 | Add reaction | Reaction added to comment |
| GH-22-7 | List comments | Returns array of comments |
| GH-22-8 | Invalid file path for inline | HTTP 422, error message |
| GH-22-9 | Invalid line number | HTTP 422, error message |
| GH-22-10 | Invalid reaction | HTTP 422, error message with valid list |
| GH-22-11 | Invalid comment ID | HTTP 404, error message |
| GH-22-12 | JSON output format | Valid JSON with comment details |

## Compatibility with Previous Sprints

**Sprint 13 (PR Management)**:
- ✅ Reuse token file authentication pattern
- ✅ Follow curl-based REST API approach
- ✅ Repository auto-detection from git config
- ✅ Consistent error handling patterns
- ✅ Dual output formats (human-readable and JSON)
- ✅ Integration via PR number from create-pr.sh output

**Sprint 9 (API Access Pattern)**:
- ✅ Token file authentication: `.secrets/token`
- ✅ curl-based REST API calls
- ✅ Consistent error handling and JSON parsing

**Sprint 11 (Script Structure)**:
- ✅ Follow script structure patterns (`set -euo pipefail`)
- ✅ Comprehensive help documentation
- ✅ Consistent CLI interface patterns

## Risks and Mitigations

### Risk 1: Merge Conflict Handling

**Risk**: PRs may have merge conflicts preventing merge
**Impact**: Merge fails, unclear error messages
**Mitigation**: Check mergeable state before merge attempt (optional `--check-mergeable` flag), provide clear error messages with conflict details

### Risk 2: Required Status Checks

**Risk**: Status checks may be pending, preventing merge
**Impact**: Merge fails with HTTP 403/422
**Mitigation**: Check PR status before merge, provide clear error messages, document status check requirements. Do not wait automatically (user should handle status checks separately).

### Risk 3: Branch Protection Rules

**Risk**: Branch protection may prevent merge
**Impact**: Merge fails with HTTP 403
**Mitigation**: Provide clear error messages explaining branch protection violations

### Risk 4: Inline Comment Complexity

**Risk**: Inline comments require commit_id, file path, line number, side
**Impact**: Complex API usage, potential errors
**Mitigation**: Auto-detect commit_id from PR head if not provided, provide clear examples, validate inputs, handle errors gracefully

### Risk 5: Comment Endpoint Confusion

**Risk**: General comments use issues API, inline comments use pulls API
**Impact**: Using wrong endpoint
**Mitigation**: Use `--operation` flag to distinguish, document endpoint differences clearly in help text

### Risk 6: Commit ID Auto-detection Failure

**Risk**: Auto-detection of commit_id may fail or be slow
**Impact**: Inline comment fails or delays
**Mitigation**: Allow explicit `--commit-id` flag, fallback to auto-detection, provide clear error if both fail

## Success Criteria

Sprint 14 design is successful when:

1. ✅ Feasibility analysis confirms GitHub API supports all operations
2. ✅ Script designs cover all required functionality for GH-20, GH-22
3. ✅ CLI interfaces follow established patterns
4. ✅ Error handling addresses all HTTP status codes
5. ✅ Output formats (human-readable and JSON) specified
6. ✅ Integration patterns documented
7. ✅ Test strategy covers all scenarios
8. ✅ Risks identified with mitigation strategies
9. ✅ Compatibility with Sprint 13 maintained

## Documentation

**Implementation Notes** (to be created in construction phase):
- `progress/sprint_14_implementation.md`
- Usage examples for each script
- Test execution results
- Troubleshooting guide

**Script Help** (inline in each script):
- `scripts/merge-pr.sh --help`
- `scripts/pr-comments.sh --help`

## Design Approval

**Status**: Awaiting Product Owner review

This design document is ready for Product Owner review. Implementation will proceed after approval (status change to "Accepted").

**Design addresses**:
- ✅ GH-20: Merge Pull Request with all three strategies and mergeable state checking
- ✅ GH-22: Pull Request Comments with all operations (add, update, delete, react, list)
- ✅ Integration with existing Sprint 13 tooling
- ✅ Comprehensive test strategy
- ✅ Error handling and risk mitigation

