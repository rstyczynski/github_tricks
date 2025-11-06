# Sprint 14 - Analysis

**Date**: 2025-11-06
**Sprint**: 14
**Status**: Analysis Complete
**Backlog Items**: GH-20, GH-22

## Executive Summary

Sprint 14 extends the Pull Request management capabilities from Sprint 13 by adding merge operations and comment management. This sprint builds upon the established PR management patterns from Sprint 13 (create, list, update) to deliver two additional PR operations: merging with different strategies and managing PR comments.

## Backlog Items Analysis

### GH-20. Merge Pull Request

**Requirement**: Merge pull request with different merge strategies including merge commit, squash and merge, and rebase and merge. The implementation should validate merge eligibility, support all three merge strategies, and provide detailed feedback about merge results or failures.

**API Endpoint**: `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge`

**Key Capabilities Required**:
- Check mergeable state before attempting merge
- Support three merge strategies: merge commit, squash and merge, rebase and merge
- Handle various merge scenarios: conflicts, required status checks, branch protection rules
- Validate merge eligibility
- Provide detailed feedback about merge results or failures
- Error handling: merge conflicts, status check failures, branch protection violations

**Integration Points**:
- Reuse authentication patterns from Sprint 13 (token file)
- Use PR number from GH-17 (create-pr.sh) output
- Follow established script patterns (input methods, JSON output)
- May need to check PR status before merge attempt

**Technical Considerations**:
- GitHub API supports all three merge strategies via `merge_method` parameter
- Merge eligibility can be checked via PR details endpoint (`mergeable` field)
- Merge conflicts return HTTP 405 (Method Not Allowed) or HTTP 409 (Conflict)
- Required status checks return HTTP 403 or HTTP 422 with details
- Branch protection rules may prevent merge (HTTP 403)
- Commit message can be customized for squash and merge

**Open Questions**:
- Should script check mergeable state before attempting merge?
- How to handle merge conflicts? (error message vs attempt resolution)
- Should script support custom commit messages for squash/merge?
- How to handle required status checks? (wait vs error)
- Should script support force merge (bypassing checks)?

### GH-22. Pull Request Comments

**Requirement**: Add, update, and delete comments on pull requests including both general PR comments and inline code review comments. Support adding comments at specific line positions for code reviews, updating existing comments, deleting comments, and reacting to comments with emojis.

**API Endpoint**: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` (for inline comments)
**API Endpoint**: `POST /repos/{owner}/{repo}/issues/{issue_number}/comments` (for general PR comments)
**API Endpoint**: `PATCH /repos/{owner}/{repo}/pulls/comments/{comment_id}` (for updating)
**API Endpoint**: `DELETE /repos/{owner}/{repo}/pulls/comments/{comment_id}` (for deleting)

**Key Capabilities Required**:
- Add general PR comments (issue-level comments)
- Add inline code review comments (at specific line positions)
- Update existing comments
- Delete comments
- React to comments with emojis
- Handle authentication and permissions
- Error handling: invalid PR numbers, permission issues, invalid line positions

**Integration Points**:
- Reuse authentication patterns from Sprint 13
- Use PR number from GH-17 (create-pr.sh) output
- Follow established script patterns
- May need to list comments before updating/deleting

**Technical Considerations**:
- General PR comments use issues API endpoint (PRs are issues)
- Inline comments require file path, line number, and side (left/right)
- Inline comments require `commit_id` or `pull_number` with `side`
- Comments can be updated via PATCH endpoint
- Comments can be deleted via DELETE endpoint
- Reactions use different endpoint: `POST /repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions`
- Multiple endpoints needed for different operations

**Open Questions**:
- Should script support both general and inline comments in one script or separate?
- How to specify line position for inline comments? (file path, line number, side)
- How to handle commit_id requirement for inline comments?
- Should script support listing comments?
- Format for reactions? (emoji names or codes)

## Project History Context

### Completed Sprints (Relevant Patterns)

**Sprint 13 - Pull Request Management** (Most Relevant):
- GH-17: Create Pull Request (`scripts/create-pr.sh`)
- GH-18: List Pull Requests (`scripts/list-prs.sh`)
- GH-19: Update Pull Request (`scripts/update-pr.sh`)
- **Key Deliverables**:
  - Token authentication from `./secrets/github_token`
  - Repository auto-detection from git config
  - curl-based REST API approach
  - Dual output formats (human-readable and JSON)
  - Comprehensive error handling
  - PR number as primary identifier

**Sprint 9 - API Access Pattern**:
- Token file authentication: `./secrets/github_token`
- curl-based REST API calls
- Direct API calls with full control
- Consistent error handling and JSON parsing

**Sprint 11 - Script Structure**:
- Comprehensive script structure patterns
- Input resolution priority: explicit flags → stdin JSON → interactive
- Dual output formats: human-readable and JSON
- Comprehensive help documentation

### Failed Sprints (Lessons Learned)

**Sprint 2 - Real-time Log Access**: Failed due to GitHub API limitations
**Sprint 6 - Job Logs API Validation**: Failed to validate incremental log retrieval
**Sprint 7 - Webhook-based Correlation**: Failed due to complexity vs benefit trade-off
**Sprint 10 - Workflow Output Data**: Failed due to GitHub REST API limitations
**Sprint 12 - Workflow Scheduling**: Failed due to GitHub API limitations (no native scheduling)

## Established Patterns to Reuse

### 1. Script Structure Pattern (Sprint 13)

**Key Elements**:
- `set -euo pipefail` for error handling
- Token file authentication: `./secrets/github_token`
- Repository auto-detection from git config
- Consistent variable naming
- Comprehensive error messages
- Help documentation with examples

### 2. Authentication Pattern (Sprint 13)

**Token File Approach**:
```bash
TOKEN_FILE="./secrets/github_token"
if [[ ! -f "$TOKEN_FILE" ]]; then
  printf 'Error: Token file not found: %s\n' "$TOKEN_FILE" >&2
  exit 1
fi
TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')
```

**curl Usage**:
```bash
curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $token" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_ENDPOINT"
```

### 3. Repository Resolution Pattern (Sprint 13)

**Auto-detection from git context**:
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
```

### 4. Output Format Pattern (Sprint 13)

**Human-readable (default)**:
```
Pull Request #123 merged successfully
Merge method: squash
Merged commit: abc123...
```

**JSON output (`--json` flag)**:
```json
{
  "pr_number": 123,
  "merged": true,
  "merge_method": "squash",
  "sha": "abc123...",
  "message": "Pull request merged successfully"
}
```

### 5. Error Handling Pattern (Sprint 13)

**HTTP Status Codes**:
- `200 OK`: Merge successful
- `405 Method Not Allowed`: PR not mergeable (conflicts, etc.)
- `409 Conflict`: Merge conflict or other conflict
- `403 Forbidden`: Insufficient permissions or branch protection
- `422 Unprocessable Entity`: Validation error
- `404 Not Found`: PR not found

## Technical Approach Analysis

### Option 1: REST API with curl (Sprint 13 Pattern) - Recommended

**Approach**: Use curl with token from `./secrets` directory

**Pros**:
- Full control over API parameters
- Consistent with Sprint 13 approach
- More flexible for automation
- Better error handling and validation
- Direct access to merge method selection

**Cons**:
- More complex implementation
- More API-specific error codes to handle
- Need to handle mergeable state checking

**Verdict**: **Recommended** - Follows established Sprint 13 pattern

## Feasibility Assessment

### GitHub API Capabilities

**GH-20 (Merge PR)** - `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge`:
- ✅ API endpoint available and documented
- ✅ All three merge strategies supported: merge, squash, rebase
- ✅ Mergeable state can be checked via PR details endpoint
- ✅ Commit message customization for squash/merge
- ✅ Error codes well-documented
- Documentation: https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request

**GH-22 (PR Comments)**:
- ✅ General comments: `POST /repos/{owner}/{repo}/issues/{issue_number}/comments`
- ✅ Inline comments: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`
- ✅ Update comments: `PATCH /repos/{owner}/{repo}/pulls/comments/{comment_id}`
- ✅ Delete comments: `DELETE /repos/{owner}/{repo}/pulls/comments/{comment_id}`
- ✅ Reactions: `POST /repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions`
- ✅ All endpoints documented
- Documentation: https://docs.github.com/en/rest/pulls/comments

### Conclusion

**Both backlog items are fully feasible** - GitHub API provides comprehensive support for all required operations. No platform limitations identified.

## Expected Deliverables

### Scripts

1. **`scripts/merge-pr.sh`** (GH-20)
   - Merge pull request with strategy selection
   - Mergeable state checking
   - Error handling for conflicts, status checks, branch protection
   - JSON and human-readable output

2. **`scripts/pr-comments.sh`** (GH-22)
   - Add general PR comments
   - Add inline code review comments
   - Update existing comments
   - Delete comments
   - React to comments with emojis
   - JSON and human-readable output

### Documentation

1. **`progress/sprint_14_design.md`**
   - Feasibility analysis (this document serves as foundation)
   - Detailed design for each backlog item
   - API endpoint specifications
   - Error handling strategies
   - Integration patterns

2. **`progress/sprint_14_implementation.md`**
   - Implementation notes
   - Test execution results
   - Usage examples
   - Troubleshooting guide

### Test Results

- PR merging with different strategies
- Merge conflict handling
- Status check and branch protection handling
- Comment operations (add, update, delete, react)
- Inline comment positioning
- Error handling validation

## Integration Points

### With Sprint 13

**GH-17 (Create PR)**:
- Merge script will use PR number from create-pr.sh output
- Comments script will use PR number from create-pr.sh output
- Integration via JSON output/input

**GH-18 (List PRs)**:
- Can list PRs before merging
- Can list PRs to find PR numbers for comments

**GH-19 (Update PR)**:
- May need to update PR before merging (e.g., resolve conflicts)
- Comments can be added to updated PRs

### Integration Pattern Example

```bash
# Create PR
pr_result=$(scripts/create-pr.sh --head feature-branch --base main --title "Feature" --json)
pr_number=$(echo "$pr_result" | jq -r '.pr_number')

# Add comment
scripts/pr-comments.sh --pr-number "$pr_number" --body "Great work!" --json

# Merge PR
scripts/merge-pr.sh --pr-number "$pr_number" --method squash --json
```

## Risks and Mitigations

### Risk 1: Merge Conflict Handling

**Risk**: PRs may have merge conflicts preventing merge
**Impact**: Merge fails, unclear error messages
**Mitigation**: Check mergeable state before merge attempt, provide clear error messages with conflict details

### Risk 2: Required Status Checks

**Risk**: Status checks may be pending, preventing merge
**Impact**: Merge fails with HTTP 403/422
**Mitigation**: Check PR status before merge, provide clear error messages, document status check requirements

### Risk 3: Branch Protection Rules

**Risk**: Branch protection may prevent merge
**Impact**: Merge fails with HTTP 403
**Mitigation**: Provide clear error messages explaining branch protection violations

### Risk 4: Inline Comment Complexity

**Risk**: Inline comments require commit_id, file path, line number, side
**Impact**: Complex API usage, potential errors
**Mitigation**: Provide clear examples, validate inputs, handle errors gracefully

### Risk 5: Comment Endpoint Confusion

**Risk**: General comments use issues API, inline comments use pulls API
**Impact**: Using wrong endpoint
**Mitigation**: Document endpoint differences clearly, provide separate flags or subcommands

## Success Criteria

Sprint 14 analysis is successful when:

1. ✅ Both backlog items analyzed for feasibility
2. ✅ GitHub API capabilities verified
3. ✅ Established patterns from Sprint 13 identified for reuse
4. ✅ Integration points documented
5. ✅ Technical approach selected (curl-based REST API)
6. ✅ Expected deliverables enumerated
7. ✅ Risks identified with mitigation strategies
8. ✅ Open questions documented for Product Owner clarification

## Next Steps

1. **Product Owner Review**: Review this analysis and address open questions
2. **Design Phase**: Create detailed design document (`progress/sprint_14_design.md`)
3. **Implementation Phase**: Implement scripts following established patterns
4. **Testing Phase**: Execute test suite and document results

## Source Documents

**Primary Requirements**:
- `BACKLOG.md` lines 105-111 - GH-20, GH-22 specifications
- `PLAN.md` lines 139-146 - Sprint 14 definition

**Process Rules**:
- `rules/GENERAL_RULES_v3.md` - Sprint lifecycle, ownership, feedback channels
- `rules/GitHub_DEV_RULES_v4.md` - GitHub-specific implementation guidelines
- `rules/PRODUCT_OWNER_GUIDE_v3.md` - Phase transitions and review procedures

**Technical References**:
- `progress/sprint_13_analysis.md` - Sprint 13 analysis and patterns
- `progress/sprint_13_design.md` - Sprint 13 design patterns
- `progress/sprint_13_implementation.md` - Sprint 13 implementation patterns
- `scripts/create-pr.sh` - PR creation script (for integration patterns)
- `scripts/update-pr.sh` - PR update script (for integration patterns)

