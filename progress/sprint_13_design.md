# Sprint 13 - Design

## GH-17. Create Pull Request

Status: Progress

## GH-18. List Pull Requests

Status: Progress

## GH-19. Update Pull Request

Status: Progress

## Overview

Sprint 13 implements Pull Request management capabilities through GitHub REST API. This sprint builds upon established patterns from previous sprints (Sprint 9 for API access with token authentication, Sprint 11 for script structure) to deliver three core PR operations: creation, listing, and updating.

**Key Design Decisions**:
- Use curl-based REST API approach (following Sprint 9 pattern)
- Token authentication from `./secrets/github_token` file
- Assume branches exist (Unix philosophy - scripts don't create branches)
- Support both human-readable and JSON output formats
- Follow established input method priority order
- Comprehensive error handling for all HTTP status codes

## Feasibility Analysis

### GitHub API Capabilities

**GH-17 (Create PR)** - `POST /repos/{owner}/{repo}/pulls`:
- ✅ API endpoint available and documented
- ✅ All metadata fields supported: title, body, head, base, reviewers, labels, issue, draft
- ✅ Branch validation handled by API (returns 422 if branch doesn't exist)
- ✅ Duplicate PR detection (returns 422 if PR already exists)
- ✅ Error codes well-documented
- Documentation: https://docs.github.com/en/rest/pulls/pulls#create-a-pull-request

**GH-18 (List PRs)** - `GET /repos/{owner}/{repo}/pulls`:
- ✅ API endpoint available and documented
- ✅ All filter parameters supported: state, head, base, sort, direction
- ✅ Pagination via Link headers (RFC 5988) or page/per_page query params
- ✅ Additional filters available: author, assignee, labels (not in requirement)
- ✅ Default sort: created date (descending)
- Documentation: https://docs.github.com/en/rest/pulls/pulls#list-pull-requests

**GH-19 (Update PR)** - `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`:
- ✅ API endpoint available and documented
- ✅ All update fields supported: title, body, state, base
- ✅ Merge conflict detection (returns 422 with details)
- ✅ Status checks re-trigger when base branch changes
- ✅ State can be "open" or "closed" (reopening via state change)
- Documentation: https://docs.github.com/en/rest/pulls/pulls#update-a-pull-request

### Authentication

**Token File Pattern** (from Sprint 9):
- Token stored in: `./secrets/github_token`
- Header format: `Authorization: Bearer <token>`
- Required permissions: `repo` scope (classic token) or `Pull requests: Write` (fine-grained token)

### Repository Resolution

**Auto-detection from git context** (following Sprint 9 pattern):
```bash
git config --get remote.origin.url
# Parse: https://github.com/owner/repo.git or git@github.com:owner/repo.git
```

**Fallback options**:
1. `--repo owner/repo` CLI flag
2. `GITHUB_REPOSITORY` environment variable
3. Error if cannot resolve

### Feasibility Conclusion

**Fully achievable** - All three backlog items can be implemented:
- ✅ GitHub API provides comprehensive PR endpoints
- ✅ All required operations supported
- ✅ Authentication pattern established (Sprint 9)
- ✅ No platform limitations identified

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              Sprint 13: Pull Request Management                  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-17: Create Pull Request                               │ │
│  │                                                            │ │
│  │  Input: --head, --base, --title, --body, [--reviewers],  │ │
│  │         [--labels], [--issue], [--draft]                  │ │
│  │         ↓                                                  │ │
│  │  POST /repos/{owner}/{repo}/pulls                         │ │
│  │         ↓                                                  │ │
│  │  Output: PR number, URL, status                            │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-18: List Pull Requests                                 │ │
│  │                                                            │ │
│  │  Input: [--state], [--head], [--base], [--sort],          │ │
│  │         [--direction], [--page], [--per-page], [--all]    │ │
│  │         ↓                                                  │ │
│  │  GET /repos/{owner}/{repo}/pulls?state=...&head=...        │ │
│  │         ↓                                                  │ │
│  │  Pagination: Link headers or page/per_page                │ │
│  │         ↓                                                  │ │
│  │  Output: Table (default) or JSON array                    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  GH-19: Update Pull Request                               │ │
│  │                                                            │ │
│  │  Input: --pr-number, [--title], [--body], [--state],      │ │
│  │         [--base]                                          │ │
│  │         ↓                                                  │ │
│  │  PATCH /repos/{owner}/{repo}/pulls/{pull_number}          │ │
│  │         ↓                                                  │ │
│  │  Output: Updated PR details                               │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Shared Components:                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Token Auth  │  │  Repo Resolve │  │  Error Handle│       │
│  │  (Sprint 9)  │  │  (Sprint 9)   │  │  (Sprint 11)  │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### GH-17. Create Pull Request

#### Script Design: `scripts/create-pr.sh`

**Command-line Interface**:

```bash
scripts/create-pr.sh --head <branch> --base <branch> --title <title> [--body <body>] 
                     [--reviewers <users>] [--labels <labels>] [--issue <number>] 
                     [--draft] [--repo <owner/repo>] [--token-file <path>] 
                     [--json] [--help]
```

**Parameters**:
- `--head <branch>` - Source branch name (required)
- `--base <branch>` - Target branch name (required, default: `main`)
- `--title <title>` - PR title (required)
- `--body <body>` - PR description/body (optional)
- `--reviewers <users>` - Comma-separated list of reviewer usernames (optional)
- `--labels <labels>` - Comma-separated list of label names (optional, must exist)
- `--issue <number>` - Issue number to link (optional)
- `--draft` - Create as draft PR (optional)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Input Resolution**:
- Required parameters: `--head`, `--title` (error if missing)
- Optional parameters: `--base` (defaults to `main`), others optional
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var

**API Request Body**:

```json
{
  "title": "Feature: Add new functionality",
  "head": "feature-branch",
  "base": "main",
  "body": "This PR adds new functionality...",
  "draft": false,
  "reviewers": ["user1", "user2"],
  "labels": ["enhancement", "bug"],
  "issue": 123
}
```

**Note**: GitHub API accepts `reviewers` as array of usernames. Team reviewers use different endpoint (out of scope).

**Output Formats**:

**Human-readable (default)**:
```
Pull Request #123 created successfully
Title: Feature: Add new functionality
URL: https://github.com/owner/repo/pull/123
Status: open
Head: feature-branch
Base: main
```

**JSON output (--json)**:
```json
{
  "pr_number": 123,
  "title": "Feature: Add new functionality",
  "url": "https://github.com/owner/repo/pull/123",
  "status": "open",
  "head": "feature-branch",
  "base": "main",
  "draft": false,
  "created_at": "2025-01-15T10:30:00Z"
}
```

**Implementation Details**:

**1. Load token**:
```bash
TOKEN_FILE="${TOKEN_FILE:-./secrets/github_token}"
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Error: Token file not found: $TOKEN_FILE" >&2
  exit 1
fi
TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')
```

**2. Resolve repository**:
```bash
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
    echo "Error: Cannot resolve repository. Use --repo flag or set GITHUB_REPOSITORY env var" >&2
    exit 1
  fi
  
  # Parse GitHub URL
  if [[ "$git_url" =~ github.com[:/]([^/]+)/([^/]+)\.git?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    echo "Error: Cannot parse repository from git URL: $git_url" >&2
    exit 1
  fi
}
```

**3. Build request body**:
```bash
build_request_body() {
  local body_json="{"
  body_json+="\"title\":$(jq -n --arg title "$TITLE" '$title'),"
  body_json+="\"head\":$(jq -n --arg head "$HEAD" '$head'),"
  body_json+="\"base\":$(jq -n --arg base "${BASE:-main}" '$base')"
  
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
```

**4. Create PR via API**:
```bash
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
  response_body=$(echo "$response" | sed '$d')
  
  case "$http_code" in
    201)
      echo "$response_body"
      return 0
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      echo "Error: Validation failed - $error_msg" >&2
      # Try to extract specific errors
      echo "$response_body" | jq -r '.errors[]? | "  - \(.field // "unknown"): \(.message // "error")" | .' >&2
      return 1
      ;;
    404)
      echo "Error: Repository or branch not found" >&2
      return 1
      ;;
    403)
      echo "Error: Insufficient permissions to create pull request" >&2
      return 1
      ;;
    401)
      echo "Error: Authentication failed. Check token permissions." >&2
      return 1
      ;;
    *)
      echo "Error: API request failed (HTTP $http_code)" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2
      return 1
      ;;
  esac
}
```

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 201 | Success | N/A (output PR details) |
| 422 | Validation error | "Validation failed - {message}" + field errors |
| 404 | Repository/branch not found | "Repository or branch not found" |
| 403 | Insufficient permissions | "Insufficient permissions to create pull request" |
| 401 | Authentication failed | "Authentication failed. Check token permissions." |
| Other | Unknown error | "API request failed (HTTP {code})" |

**Exit Codes**:
- `0`: PR created successfully
- `1`: Error (API error, validation failure, missing parameters)
- `2`: Invalid arguments or missing required parameters

### GH-18. List Pull Requests

#### Script Design: `scripts/list-prs.sh`

**Command-line Interface**:

```bash
scripts/list-prs.sh [--state <state>] [--head <branch>] [--base <branch>] 
                     [--sort <sort>] [--direction <direction>] [--page <n>] 
                     [--per-page <n>] [--all] [--repo <owner/repo>] 
                     [--token-file <path>] [--json] [--help]
```

**Parameters**:
- `--state <state>` - Filter by state: open, closed, or all (default: `open`)
- `--head <branch>` - Filter by source branch (optional)
- `--base <branch>` - Filter by target branch (optional)
- `--sort <sort>` - Sort by: created, updated, popularity (default: `created`)
- `--direction <direction>` - Sort direction: asc or desc (default: `desc`)
- `--page <n>` - Page number (default: 1)
- `--per-page <n>` - Items per page (default: 30, max: 100)
- `--all` - Fetch all pages automatically (ignores --page)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Input Resolution**:
- All parameters optional (defaults: state=open, sort=created, direction=desc, page=1, per-page=30)
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var

**API Query Parameters**:

```
GET /repos/{owner}/{repo}/pulls?state=open&head=feature-branch&base=main&sort=created&direction=desc&page=1&per_page=30
```

**Pagination Strategy**:

**Option 1: Single page (default)**:
- Fetch only requested page
- Output page number and total pages (if available from Link header)

**Option 2: All pages (`--all` flag)**:
- Follow Link headers or use page iteration
- Fetch all pages and combine results
- May be slow for repositories with many PRs

**Link Header Parsing**:
```bash
parse_link_header() {
  local link_header="$1"
  local rel="$2"  # "next", "last", etc.
  
  # Link: <url1>; rel="next", <url2>; rel="last"
  echo "$link_header" | grep -oP "<[^>]+>; rel=\"$rel\"" | grep -oP "<[^>]+>" | tr -d '<>'
}
```

**Output Formats**:

**Human-readable table (default)**:
```
Pull Requests (page 1/3):
┌──────┬─────────────────────────────────────┬──────────┬─────────────┬─────────────┐
│  #   │ Title                               │ State    │ Head        │ Base        │
├──────┼─────────────────────────────────────┼──────────┼─────────────┼─────────────┤
│ 123  │ Feature: Add new functionality     │ open     │ feature-1   │ main        │
│ 122  │ Bugfix: Fix critical issue          │ open     │ hotfix-1    │ main        │
│ 121  │ Docs: Update README                 │ closed   │ docs-update │ main        │
└──────┴─────────────────────────────────────┴──────────┴─────────────┴─────────────┘
Showing 3 of 45 pull requests
```

**JSON output (--json)**:
```json
[
  {
    "number": 123,
    "title": "Feature: Add new functionality",
    "state": "open",
    "head": {
      "ref": "feature-1",
      "sha": "abc123..."
    },
    "base": {
      "ref": "main",
      "sha": "def456..."
    },
    "url": "https://github.com/owner/repo/pull/123",
    "created_at": "2025-01-15T10:30:00Z",
    "updated_at": "2025-01-15T11:00:00Z"
  },
  ...
]
```

**Implementation Details**:

**1. Build query string**:
```bash
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
  
  if [[ -z "$ALL_PAGES" ]]; then
    [[ -n "$query" ]] && query+="&"
    query+="page=${PAGE:-1}&per_page=${PER_PAGE:-30}"
  else
    [[ -n "$query" ]] && query+="&"
    query+="per_page=100"  # Max per page for efficiency
  fi
  
  echo "$query"
}
```

**2. Fetch PRs with pagination**:
```bash
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
    local current_query="${query}&page=$page&per_page=$per_page"
    local response headers http_code
    
    response=$(curl -s -w "\n%{http_code}" -D - \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$owner/$repo/pulls?$current_query")
    
    http_code=$(echo "$response" | tail -n1)
    headers=$(echo "$response" | grep -i "^link:")
    response_body=$(echo "$response" | sed '$d' | sed '/^link:/Id')
    
    if [[ "$http_code" != "200" ]]; then
      handle_api_error "$http_code" "$response_body"
      return 1
    fi
    
    # Merge with previous results
    all_prs=$(echo "$all_prs" "$response_body" | jq -s 'add')
    
    # Check if more pages
    if [[ -n "$ALL_PAGES" ]]; then
      local next_url
      next_url=$(parse_link_header "$headers" "next")
      if [[ -z "$next_url" ]]; then
        break  # No more pages
      fi
      page=$((page + 1))
    else
      break  # Single page mode
    fi
  done
  
  echo "$all_prs"
}
```

**3. Format table output**:
```bash
format_table() {
  local prs_json="$1"
  local total=$(echo "$prs_json" | jq 'length')
  
  if [[ "$total" -eq 0 ]]; then
    echo "No pull requests found matching criteria."
    return
  fi
  
  echo "Pull Requests:"
  echo "┌──────┬─────────────────────────────────────┬──────────┬─────────────┬─────────────┐"
  echo "│  #   │ Title                               │ State    │ Head        │ Base        │"
  echo "├──────┼─────────────────────────────────────┼──────────┼─────────────┼─────────────┤"
  
  echo "$prs_json" | jq -r '.[] | "│ \(.number) │ \(.title | .[0:35] | "\(.)" + " " * (35 - length)) │ \(.state) │ \(.head.ref | .[0:11] | "\(.)" + " " * (11 - length)) │ \(.base.ref | .[0:11] | "\(.)" + " " * (11 - length)) │"'
  
  echo "└──────┴─────────────────────────────────────┴──────────┴─────────────┴─────────────┘"
  echo "Showing $total pull request(s)"
}
```

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 200 | Success | N/A (output PR list) |
| 404 | Repository not found | "Repository not found" |
| 403 | Insufficient permissions | "Insufficient permissions to list pull requests" |
| 401 | Authentication failed | "Authentication failed. Check token permissions." |
| Other | Unknown error | "API request failed (HTTP {code})" |

**Exit Codes**:
- `0`: PRs listed successfully
- `1`: Error (API error, missing repository)
- `2`: Invalid arguments

### GH-19. Update Pull Request

#### Script Design: `scripts/update-pr.sh`

**Command-line Interface**:

```bash
scripts/update-pr.sh --pr-number <number> [--title <title>] [--body <body>] 
                      [--state <state>] [--base <branch>] [--repo <owner/repo>] 
                      [--token-file <path>] [--json] [--help]
```

**Parameters**:
- `--pr-number <number>` - Pull request number (required)
- `--title <title>` - New PR title (optional)
- `--body <body>` - New PR description/body (optional)
- `--state <state>` - PR state: open or closed (optional)
- `--base <branch>` - New target branch (optional)
- `--repo <owner/repo>` - Repository in owner/repo format (auto-detected if omitted)
- `--token-file <path>` - Path to token file (default: `./secrets/github_token`)
- `--json` - Output JSON format for programmatic use
- `--help` - Display usage information

**Input Resolution**:
- Required parameter: `--pr-number` (error if missing)
- At least one update field required: `--title`, `--body`, `--state`, or `--base`
- Repository: Auto-detect from git, fallback to `--repo` flag or `GITHUB_REPOSITORY` env var

**API Request Body** (only include fields to update):

```json
{
  "title": "Updated title",
  "body": "Updated body",
  "state": "open",
  "base": "main"
}
```

**Output Formats**:

**Human-readable (default)**:
```
Pull Request #123 updated successfully
Title: Updated title
URL: https://github.com/owner/repo/pull/123
Status: open
Base: main
```

**JSON output (--json)**:
```json
{
  "pr_number": 123,
  "title": "Updated title",
  "url": "https://github.com/owner/repo/pull/123",
  "status": "open",
  "base": "main",
  "updated_at": "2025-01-15T12:00:00Z"
}
```

**Implementation Details**:

**1. Build update payload** (only include provided fields):
```bash
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
    echo "Error: At least one update field required (--title, --body, --state, or --base)" >&2
    return 1
  fi
  
  payload+="}"
  echo "$payload"
}
```

**2. Update PR via API**:
```bash
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
  response_body=$(echo "$response" | sed '$d')
  
  case "$http_code" in
    200)
      echo "$response_body"
      return 0
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response_body" | jq -r '.message // "Validation failed"')
      echo "Error: Validation failed - $error_msg" >&2
      
      # Check for merge conflict
      if echo "$response_body" | jq -e '.errors[]? | select(.field == "base")' >/dev/null 2>&1; then
        echo "  Merge conflict detected when changing base branch." >&2
        echo "  The PR cannot be merged into the new base branch." >&2
      fi
      
      # Show field errors
      echo "$response_body" | jq -r '.errors[]? | "  - \(.field // "unknown"): \(.message // "error")" | .' >&2
      return 1
      ;;
    404)
      echo "Error: Pull request #$pr_number not found" >&2
      return 1
      ;;
    403)
      echo "Error: Insufficient permissions to update pull request" >&2
      return 1
      ;;
    401)
      echo "Error: Authentication failed. Check token permissions." >&2
      return 1
      ;;
    *)
      echo "Error: API request failed (HTTP $http_code)" >&2
      echo "$response_body" | jq -r '.message // "Unknown error"' >&2
      return 1
      ;;
  esac
}
```

**Error Handling**:

| HTTP Code | Scenario | Error Message |
|-----------|----------|---------------|
| 200 | Success | N/A (output updated PR details) |
| 422 | Validation error | "Validation failed - {message}" + merge conflict details if applicable |
| 404 | PR not found | "Pull request #{number} not found" |
| 403 | Insufficient permissions | "Insufficient permissions to update pull request" |
| 401 | Authentication failed | "Authentication failed. Check token permissions." |
| Other | Unknown error | "API request failed (HTTP {code})" |

**Special Handling for Base Branch Changes**:
- GitHub API returns 422 if base branch change causes merge conflicts
- Error message includes conflict details
- Status checks are re-triggered automatically by GitHub

**Exit Codes**:
- `0`: PR updated successfully
- `1`: Error (API error, validation failure, missing parameters)
- `2`: Invalid arguments or missing required parameters

## Integration Patterns

### Pattern 1: Create → Update PR

```bash
# Create PR
result=$(scripts/create-pr.sh \
  --head feature-branch \
  --base main \
  --title "Feature: Add new functionality" \
  --body "Initial description" \
  --json)

pr_number=$(echo "$result" | jq -r '.pr_number')

# Update PR later
scripts/update-pr.sh \
  --pr-number "$pr_number" \
  --body "Updated description with more details" \
  --json
```

### Pattern 2: List → Update Multiple PRs

```bash
# List open PRs
prs=$(scripts/list-prs.sh --state open --json)

# Update each PR
echo "$prs" | jq -r '.[] | .number' | while read -r pr_number; do
  scripts/update-pr.sh --pr-number "$pr_number" --state closed --json
done
```

### Pattern 3: Create PR with Auto-detection

```bash
# Auto-detect repository from git context
# Auto-detect current branch as head
current_branch=$(git rev-parse --abbrev-ref HEAD)

scripts/create-pr.sh \
  --head "$current_branch" \
  --base main \
  --title "Feature: $(git log -1 --pretty=%s)" \
  --json
```

## Testing Strategy

### GH-17 (Create Pull Request)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-17-1 | Create PR with minimal fields | PR created, returns PR number |
| GH-17-2 | Create PR with all metadata | PR created with reviewers, labels, issue link |
| GH-17-3 | Create draft PR | PR created with draft=true |
| GH-17-4 | Duplicate PR (same head/base) | HTTP 422, error message |
| GH-17-5 | Invalid branch (head) | HTTP 422, error message |
| GH-17-6 | Invalid branch (base) | HTTP 422, error message |
| GH-17-7 | Invalid label | HTTP 422, error message |
| GH-17-8 | Missing required fields | Exit code 2, usage message |
| GH-17-9 | JSON output format | Valid JSON with PR details |
| GH-17-10 | Auto-detect repository | Uses git config |

### GH-18 (List Pull Requests)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-18-1 | List open PRs (default) | Returns open PRs only |
| GH-18-2 | List all PRs | Returns all PRs |
| GH-18-3 | Filter by head branch | Returns PRs from specific branch |
| GH-18-4 | Filter by base branch | Returns PRs targeting specific branch |
| GH-18-5 | Sort by updated | Returns PRs sorted by updated date |
| GH-18-6 | Pagination (single page) | Returns requested page only |
| GH-18-7 | Pagination (--all) | Returns all pages |
| GH-18-8 | JSON output format | Valid JSON array |
| GH-18-9 | Empty result | "No pull requests found" message |
| GH-18-10 | Auto-detect repository | Uses git config |

### GH-19 (Update Pull Request)

**Test Cases**:

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| GH-19-1 | Update title only | Title updated |
| GH-19-2 | Update body only | Body updated |
| GH-19-3 | Update state to closed | PR closed |
| GH-19-4 | Update state to open | PR reopened |
| GH-19-5 | Update base branch | Base branch changed, status checks re-triggered |
| GH-19-6 | Update base branch (merge conflict) | HTTP 422, error message with conflict details |
| GH-19-7 | Update multiple fields | All fields updated |
| GH-19-8 | Invalid PR number | HTTP 404, error message |
| GH-19-9 | Missing update fields | Exit code 2, error message |
| GH-19-10 | JSON output format | Valid JSON with updated PR details |

### Integration Tests

**Test 1: Create → List → Update**:
```bash
# Create PR
pr_result=$(scripts/create-pr.sh --head test-branch --base main --title "Test PR" --json)
pr_number=$(echo "$pr_result" | jq -r '.pr_number')

# List PRs (should include new PR)
prs=$(scripts/list-prs.sh --state open --json)
echo "$prs" | jq -e ".[] | select(.number == $pr_number)" >/dev/null || exit 1

# Update PR
update_result=$(scripts/update-pr.sh --pr-number "$pr_number" --title "Updated Test PR" --json)
echo "$update_result" | jq -e '.title == "Updated Test PR"' >/dev/null || exit 1
```

## Compatibility with Previous Sprints

**Sprint 9 (API Access Pattern)**:
- ✅ Reuse token file authentication: `./secrets/github_token`
- ✅ Follow curl-based REST API approach
- ✅ Consistent error handling patterns
- ✅ Repository auto-detection from git config

**Sprint 11 (Script Structure)**:
- ✅ Follow script structure patterns (`set -euo pipefail`)
- ✅ Reuse input method priority order (explicit flags → stdin → interactive)
- ✅ Dual output formats (human-readable and JSON)
- ✅ Comprehensive help documentation

**Sprint 8 (Input Methods)**:
- ✅ Multiple input methods support (where applicable)
- ✅ JSON stdin/stdout for pipeline composition (GH-17 → GH-19)
- ✅ Consistent CLI interface

## Risks and Mitigations

### Risk 1: Branch Management Complexity

**Risk**: Scripts may need to handle git operations if branches don't exist
**Impact**: Increased complexity, potential git dependency
**Mitigation**: Assume branches exist (Unix philosophy), document requirement clearly in help text

### Risk 2: Pagination Performance

**Risk**: Auto-fetching all pages may be slow for repositories with many PRs
**Impact**: Poor user experience
**Mitigation**: Default to single page, require explicit `--all` flag for all pages, document performance implications

### Risk 3: Merge Conflict Handling

**Risk**: Base branch changes may cause merge conflicts
**Impact**: Unclear error messages
**Mitigation**: Parse HTTP 422 response for conflict details, provide clear error messages with actionable information

### Risk 4: Authentication Token Permissions

**Risk**: Token may lack required PR permissions
**Impact**: HTTP 403 errors
**Mitigation**: Document required permissions in help text, provide clear error messages

### Risk 5: API Rate Limiting

**Risk**: High-frequency operations may hit rate limits
**Impact**: HTTP 403 errors
**Mitigation**: Document rate limits, handle 403 responses gracefully with retry suggestion

## Success Criteria

Sprint 13 design is successful when:

1. ✅ Feasibility analysis confirms GitHub API supports all operations
2. ✅ Script designs cover all required functionality for GH-17, GH-18, GH-19
3. ✅ CLI interfaces follow established patterns
4. ✅ Error handling addresses all HTTP status codes
5. ✅ Output formats (human-readable and JSON) specified
6. ✅ Integration patterns documented
7. ✅ Test strategy covers all scenarios
8. ✅ Risks identified with mitigation strategies
9. ✅ Compatibility with previous sprints maintained

## Documentation

**Implementation Notes** (to be created in construction phase):
- `progress/sprint_13_implementation.md`
- Usage examples for each script
- Test execution results
- Troubleshooting guide

**Script Help** (inline in each script):
- `scripts/create-pr.sh --help`
- `scripts/list-prs.sh --help`
- `scripts/update-pr.sh --help`

## Design Approval

**Status**: Awaiting Product Owner review

This design document is ready for Product Owner review. Implementation will proceed after approval (status change to "Accepted").

**Design addresses**:
- ✅ GH-17: Create Pull Request with full metadata control
- ✅ GH-18: List Pull Requests with filtering and pagination
- ✅ GH-19: Update Pull Request properties with validation
- ✅ Integration with existing Sprint 9, 11 tooling
- ✅ Comprehensive test strategy
- ✅ Error handling and risk mitigation

