# Sprint 13 - Analysis

**Date**: 2025-01-15
**Sprint**: 13
**Status**: Analysis Complete
**Backlog Items**: GH-17, GH-18, GH-19

## Executive Summary

Sprint 13 focuses on implementing Pull Request management capabilities through GitHub REST API. This sprint builds upon established patterns from previous sprints (Sprint 8/9 for API access, Sprint 11 for script structure) to deliver three core PR operations: creation, listing, and updating.

## Backlog Items Analysis

### GH-17. Create Pull Request

**Requirement**: Create a pull request from a feature branch to main branch using REST API with full control over PR metadata.

**API Endpoint**: `POST /repos/{owner}/{repo}/pulls`

**Key Capabilities Required**:
- Authentication handling (token from `./secrets` directory, following Sprint 9 pattern)
- Branch existence validation
- PR metadata support: title, body, reviewers, labels, issue linking
- Error handling: duplicate PRs, invalid branch references, authentication failures

**Integration Points**:
- May require git operations to create feature branches (if not assuming branch exists)
- Reuse authentication patterns from Sprint 9 (token file)
- Follow established script patterns (input methods, JSON output from Sprint 8/11)

**Technical Considerations**:
- GitHub API supports all required metadata fields
- Reviewers can be specified as usernames or team names
- Labels must exist in repository (cannot create via PR API)
- Issue linking via `issue` parameter in request body
- Draft PRs supported via `draft` boolean field

**Open Questions** (from inception chat 1):
- Should script create feature branch if missing, or assume it exists?
- Format for reviewers (usernames, team names, or both)?
- Should script support draft PRs?
- Integration with git repository state (auto-detect current branch)?

### GH-18. List Pull Requests

**Requirement**: List pull requests with various filters including state, head branch, base branch, sort order, and direction, with pagination support.

**API Endpoint**: `GET /repos/{owner}/{repo}/pulls`

**Key Capabilities Required**:
- Filter by state (open, closed, all)
- Filter by head branch (source branch)
- Filter by base branch (target branch)
- Sort order and direction (created, updated, popularity)
- Pagination handling using Link headers
- Clean filtering interface
- JSON output for automation (`--json` flag)

**Integration Points**:
- Follow Sprint 8/9 patterns for API calls
- Reuse authentication patterns
- Human-readable table output (default) and JSON output

**Technical Considerations**:
- GitHub API supports all required filter parameters
- Pagination via Link headers (RFC 5988) or `page`/`per_page` query params
- Default sort: created date (descending)
- Supports filtering by author, assignee, labels (not in requirement but useful)

**Open Questions** (from inception chat 1):
- Default filters (all PRs vs open only)?
- Pagination strategy (auto-fetch all pages vs single page with controls)?
- Default sort order?
- Should script support additional filters (author, assignee, labels)?

### GH-19. Update Pull Request

**Requirement**: Update pull request properties including title, body, state, and base branch with proper validation and error handling.

**API Endpoint**: `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`

**Key Capabilities Required**:
- Update title and body
- Change base branch (with merge conflict handling)
- Close/reopen PRs (via state field)
- Validate changes before applying
- Handle merge conflicts when changing base branch
- Clear error messages for invalid operations

**Integration Points**:
- Reuse authentication patterns
- May need to check mergeable state before base branch changes
- Follow established error handling patterns

**Technical Considerations**:
- GitHub API supports all required update operations
- Base branch changes trigger re-evaluation of mergeability
- Status checks re-run when base branch changes
- Merge conflicts return HTTP 422 with details
- State can be "open" or "closed" (reopening via state change)

**Open Questions** (from inception chat 1):
- Should script check mergeable state before base branch change?
- How to handle merge conflicts (error message vs attempt merge)?
- Should script support updating reviewers and labels? (different endpoints)

## Project History Context

### Completed Sprints (Relevant Patterns)

**Sprint 0 - Prerequisites**:
- Established tooling: GitHub CLI, Go, Java libraries
- GitHub CLI authentication with browser-based auth
- Token file pattern: `.secrets/token`

**Sprint 1 - Workflow Triggering and Correlation**:
- UUID-based correlation mechanism
- Metadata storage: `runs/<correlation_id>/metadata.json`
- Shared utilities: `lib/run-utils.sh`

**Sprint 3 - Post-Run Log Access**:
- Metadata-based run ID lookup
- Log archive download and extraction

**Sprint 4 - Timing Benchmarks**:
- Benchmark scripts and timing reports
- Statistical analysis patterns

**Sprint 5 - Market Research**:
- Comprehensive GitHub API capabilities documentation
- GitHub CLI capabilities inventory
- Library research (Java, Go, Python)

**Sprint 8 - Job Status Monitoring**:
- GitHub CLI-based implementation
- Multiple input methods: `--run-id`, `--correlation-id`, stdin JSON
- JSON output format (`--json` flag)
- Human-readable default output

**Sprint 9 - Job Status Monitoring (API Variant)**:
- curl-based REST API implementation
- Token file authentication: `.secrets/token`
- Direct API calls with full control
- Consistent error handling and JSON parsing

**Sprint 11 - Workflow Cancellation**:
- Comprehensive script structure patterns
- Input resolution priority: `--run-id` → `--correlation-id` → stdin JSON → interactive
- Dual output formats: human-readable and JSON
- Comprehensive error handling
- Help documentation with examples

### Failed Sprints (Lessons Learned)

**Sprint 2 - Real-time Log Access**: Failed due to GitHub API limitations
**Sprint 6 - Job Logs API Validation**: Failed to validate incremental log retrieval
**Sprint 7 - Webhook-based Correlation**: Failed due to complexity vs benefit trade-off
**Sprint 10 - Workflow Output Data**: Failed due to GitHub REST API limitations
**Sprint 12 - Workflow Scheduling**: Failed due to GitHub API limitations (no native scheduling)

## Established Patterns to Reuse

### 1. Script Structure Pattern (Sprint 11)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/run-utils.sh"  # If needed

# Default values
# Function declarations
# Main execution flow
```

**Key Elements**:
- `set -euo pipefail` for error handling
- Source shared utilities when needed
- Consistent variable naming
- Comprehensive error messages
- Help documentation with examples

### 2. Input Methods Pattern (Sprint 8, 11)

**Priority Order**:
1. Explicit flags (`--pr-number`, `--head-branch`, etc.)
2. stdin JSON (from previous script output)
3. Interactive prompt (if terminal and no other input)

**Example**:
```bash
# Priority 1: Explicit flag
scripts/create-pr.sh --head feature-branch --base main

# Priority 2: stdin JSON
echo '{"head": "feature-branch", "base": "main"}' | scripts/create-pr.sh

# Priority 3: Interactive (if terminal)
scripts/create-pr.sh  # Prompts for input
```

### 3. Authentication Pattern (Sprint 9)

**Token File Approach**:
```bash
TOKEN_FILE=".secrets/token"
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Error: Token file not found: $TOKEN_FILE" >&2
  exit 1
fi
TOKEN=$(cat "$TOKEN_FILE")
```

**curl Usage**:
```bash
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_ENDPOINT"
```

**Alternative: GitHub CLI**:
```bash
gh api "$API_ENDPOINT" --method POST --field key=value
```

### 4. Output Format Pattern (Sprint 8, 11)

**Human-readable (default)**:
```
Pull Request #123 created successfully
Title: Feature: Add new functionality
URL: https://github.com/owner/repo/pull/123
Status: open
```

**JSON output (`--json` flag)**:
```json
{
  "pr_number": 123,
  "title": "Feature: Add new functionality",
  "url": "https://github.com/owner/repo/pull/123",
  "status": "open",
  "head": "feature-branch",
  "base": "main"
}
```

### 5. Error Handling Pattern (Sprint 11)

**HTTP Status Codes**:
- `201 Created`: PR created successfully
- `422 Unprocessable Entity`: Validation error (duplicate PR, invalid branch)
- `404 Not Found`: Repository or branch not found
- `403 Forbidden`: Insufficient permissions
- `401 Unauthorized`: Authentication failed

**Error Messages**:
```bash
case "$http_code" in
  422)
    echo "Error: Validation failed - duplicate PR or invalid branch" >&2
    ;;
  404)
    echo "Error: Repository or branch not found" >&2
    ;;
  403)
    echo "Error: Insufficient permissions" >&2
    ;;
  *)
    echo "Error: API request failed (HTTP $http_code)" >&2
    ;;
esac
```

### 6. Pagination Pattern (Sprint 9, for GH-18)

**Link Header Parsing**:
```bash
# Extract next page URL from Link header
link_header=$(curl -s -I "$API_ENDPOINT" | grep -i "^link:" | head -1)
next_url=$(echo "$link_header" | grep -oP '<[^>]+>; rel="next"' | grep -oP '<[^>]+>' | tr -d '<>')
```

**Page Parameter Approach**:
```bash
page=1
per_page=30
while true; do
  response=$(curl ... "$API_ENDPOINT?page=$page&per_page=$per_page")
  # Process response
  if [[ $(echo "$response" | jq 'length') -lt $per_page ]]; then
    break  # Last page
  fi
  page=$((page + 1))
done
```

## Technical Approach Analysis

### Option 1: GitHub CLI-based Implementation

**Approach**: Use `gh pr create`, `gh pr list`, `gh pr edit` commands

**Pros**:
- Simpler implementation
- Reuses existing authentication
- Less API-specific error handling

**Cons**:
- Less control over API parameters
- May not support all features (reviewers, labels in single command)
- Less flexibility for automation

**Verdict**: Not recommended for full control requirement

### Option 2: REST API with curl (Sprint 9 Pattern)

**Approach**: Use curl with token from `./secrets` directory

**Pros**:
- Full control over API parameters
- Consistent with Sprint 9 approach
- More flexible for automation
- Better error handling and validation

**Cons**:
- More complex implementation
- Need to handle pagination manually
- More API-specific error codes to handle

**Verdict**: **Recommended** - Follows established Sprint 9 pattern

### Option 3: Hybrid Approach (gh api)

**Approach**: Use `gh api` command for REST API access

**Pros**:
- Best of both worlds: CLI convenience + API flexibility
- Consistent authentication (GitHub CLI)
- Easier JSON parsing (gh handles it)

**Cons**:
- Still requires understanding API endpoints
- May need curl fallback for advanced features

**Verdict**: Alternative option, but curl approach preferred for consistency

## Feasibility Assessment

### GitHub API Capabilities

**GH-17 (Create PR)**:
- ✅ API endpoint available: `POST /repos/{owner}/{repo}/pulls`
- ✅ All metadata fields supported: title, body, head, base, reviewers, labels, issue
- ✅ Draft PRs supported
- ✅ Branch validation handled by API
- ✅ Error codes well-documented

**GH-18 (List PRs)**:
- ✅ API endpoint available: `GET /repos/{owner}/{repo}/pulls`
- ✅ All filter parameters supported: state, head, base, sort, direction
- ✅ Pagination via Link headers or page/per_page params
- ✅ Additional filters available: author, assignee, labels

**GH-19 (Update PR)**:
- ✅ API endpoint available: `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`
- ✅ All update fields supported: title, body, state, base
- ✅ Merge conflict detection
- ✅ Status check re-triggering on base branch change

### Conclusion

**All three backlog items are fully feasible** - GitHub API provides comprehensive support for all required operations. No platform limitations identified.

## Expected Deliverables

### Scripts

1. **`scripts/create-pr.sh`** (GH-17)
   - Create pull request with full metadata control
   - Branch validation
   - Error handling for duplicates and invalid branches
   - JSON and human-readable output

2. **`scripts/list-prs.sh`** (GH-18)
   - List PRs with filtering (state, head, base, sort, direction)
   - Pagination handling
   - JSON and human-readable output
   - Table format for human-readable output

3. **`scripts/update-pr.sh`** (GH-19)
   - Update PR properties (title, body, state, base)
   - Merge conflict detection
   - Error handling for invalid operations
   - JSON and human-readable output

### Documentation

1. **`progress/sprint_13_design.md`**
   - Feasibility analysis (this document serves as foundation)
   - Detailed design for each backlog item
   - API endpoint specifications
   - Error handling strategies
   - Integration patterns

2. **`progress/sprint_13_implementation.md`**
   - Implementation notes
   - Test execution results
   - Usage examples
   - Troubleshooting guide

### Test Results

- PR creation with various metadata combinations
- PR listing with different filters
- PR updates (title, body, state, base branch)
- Error handling validation (duplicate PRs, invalid branches, merge conflicts)
- Pagination testing (for GH-18)

## Integration Points

### With Previous Sprints

**Sprint 9 (API Access Pattern)**:
- Reuse token file authentication: `.secrets/token`
- Follow curl-based REST API approach
- Consistent error handling patterns

**Sprint 11 (Script Structure)**:
- Follow script structure patterns
- Reuse input method priority order
- Dual output formats (human-readable and JSON)
- Comprehensive help documentation

**Sprint 8 (Input Methods)**:
- Multiple input methods support
- JSON stdin/stdout for pipeline composition
- Consistent CLI interface

### With Future Sprints

**Sprint 14 (GH-20, GH-22)**:
- GH-20 (Merge Pull Request) will use PR number from GH-17
- GH-22 (Pull Request Comments) will use PR number from GH-17
- Integration via JSON output/input

## Risks and Mitigations

### Risk 1: Branch Management Complexity

**Risk**: Scripts may need to handle git operations if branches don't exist
**Impact**: Increased complexity, potential git dependency
**Mitigation**: Assume branches exist (Unix philosophy), document requirement clearly

### Risk 2: Pagination Performance

**Risk**: Auto-fetching all pages may be slow for repositories with many PRs
**Impact**: Poor user experience
**Mitigation**: Provide pagination controls, default to single page with option to fetch all

### Risk 3: Merge Conflict Handling

**Risk**: Base branch changes may cause merge conflicts
**Impact**: Unclear error messages
**Mitigation**: Parse HTTP 422 response for conflict details, provide clear error messages

### Risk 4: Authentication Token Permissions

**Risk**: Token may lack required PR permissions
**Impact**: HTTP 403 errors
**Mitigation**: Document required permissions, provide clear error messages

### Risk 5: API Rate Limiting

**Risk**: High-frequency operations may hit rate limits
**Impact**: HTTP 403 errors
**Mitigation**: Document rate limits, handle 403 responses gracefully

## Success Criteria

Sprint 13 analysis is successful when:

1. ✅ All three backlog items analyzed for feasibility
2. ✅ GitHub API capabilities verified
3. ✅ Established patterns identified for reuse
4. ✅ Integration points documented
5. ✅ Technical approach selected (curl-based REST API)
6. ✅ Expected deliverables enumerated
7. ✅ Risks identified with mitigation strategies
8. ✅ Open questions documented for Product Owner clarification

## Next Steps

1. **Product Owner Review**: Review this analysis and address open questions
2. **Design Phase**: Create detailed design document (`progress/sprint_13_design.md`)
3. **Implementation Phase**: Implement scripts following established patterns
4. **Testing Phase**: Execute test suite and document results

## Source Documents

**Primary Requirements**:
- `BACKLOG.md` lines 93-103 - GH-17, GH-18, GH-19 specifications
- `PLAN.md` lines 129-137 - Sprint 13 definition

**Process Rules**:
- `rules/generic/GENERAL_RULES.md` - Sprint lifecycle, ownership, feedback channels
- `rules/github_actions/GitHub_DEV_RULES.md` - GitHub-specific implementation guidelines
- `rules/generic/PRODUCT_OWNER_GUIDE.md` - Phase transitions and review procedures

**Technical References**:
- `progress/sprint_9_design.md` - API access patterns, token authentication
- `progress/sprint_11_design.md` - Script structure patterns, error handling
- `progress/sprint_11_implementation.md` - Implementation patterns, testing approach
- `progress/inception_sprint_13_chat_1.md` - Initial inception analysis

