# Future Backlog Items - Enumeration

Status: Draft for Product Owner Review

Date: 2025-11-05

## Context

This document enumerates potential future Backlog Items based on:
1. Validating all completed workflow features using pure REST API (curl)
2. Expanding into Pull Request operations
3. Exploring other GitHub API capabilities

## Category 1: REST API Validation of Existing Features

### GH-13. Trigger workflow with REST API

Validate GH-2 (Trigger GitHub workflow) using pure REST API with curl instead of `gh` CLI. Use GitHub's `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` endpoint.

**Validation Focus:**
- Trigger workflow with inputs
- Handle authentication with token
- Error handling and response codes

### GH-14. Workflow correlation with REST API

Validate GH-3 (Workflow correlation) using pure REST API with curl. Use `GET /repos/{owner}/{repo}/actions/runs` with filtering.

**Validation Focus:**
- List workflow runs with filters
- UUID-based correlation
- Pagination handling

### ~~GH-15. Workflow job phases with REST API~~

**REMOVED**: Already completed by GH-12 in Sprint 8 and Sprint 9.

### GH-16. Fetch logs with REST API

Validate GH-5 (Workflow log access after run) using pure REST API endpoints.

**Validation Focus:**
- `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`
- Log streaming and aggregation
- Multiple jobs handling

## Category 2: Pull Request Operations

### GH-17. Create Pull Request

Create a pull request from a feature branch to main branch using REST API.

**Requirements:**
- Create PR with title and body
- Assign reviewers
- Add labels
- Link to issues
- API: `POST /repos/{owner}/{repo}/pulls`

### GH-18. List Pull Requests

List pull requests with various filters (state, head, base, sort, direction).

**Requirements:**
- Filter by state (open, closed, all)
- Filter by branch
- Pagination
- API: `GET /repos/{owner}/{repo}/pulls`

### GH-19. Update Pull Request

Update pull request properties (title, body, state, base branch).

**Requirements:**
- Update title and description
- Change base branch
- Close/reopen PR
- API: `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`

### GH-20. Merge Pull Request

Merge pull request with different merge strategies.

**Requirements:**
- Merge commit
- Squash and merge
- Rebase and merge
- Check mergeable state before merge
- API: `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge`

### GH-21. Pull Request Reviews

Request reviews, submit reviews, and manage review comments.

**Requirements:**
- Request reviewers
- Submit review (approve, request changes, comment)
- Dismiss reviews
- API: `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews`

### GH-22. Pull Request Comments

Add, update, and delete comments on pull requests.

**Requirements:**
- Add general PR comments
- Add inline code review comments
- Update and delete comments
- React to comments
- API: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`

### GH-23. Pull Request Status Checks

Query and manage status checks for pull requests.

**Requirements:**
- List status checks
- Get combined status
- Create commit status
- Handle required status checks
- API: `GET /repos/{owner}/{repo}/commits/{ref}/status`

## Category 3: Issue Operations

### GH-24. Create and Manage Issues

Create, update, and close issues using REST API.

**Requirements:**
- Create issue with title, body, labels, assignees
- Update issue properties
- Close/reopen issues
- Add comments
- API: `POST /repos/{owner}/{repo}/issues`

### GH-25. Issue Labels and Milestones

Manage labels and milestones for issues.

**Requirements:**
- Create/update/delete labels
- Assign labels to issues
- Create/manage milestones
- API: `POST /repos/{owner}/{repo}/labels`

## Category 4: Branch and Commit Operations

### GH-26. Branch Management

Create, list, and delete branches using REST API.

**Requirements:**
- Create branch from ref
- List branches with protection status
- Delete branch
- API: `GET /repos/{owner}/{repo}/branches`

### GH-27. Branch Protection

Configure and manage branch protection rules.

**Requirements:**
- Set required reviews
- Set required status checks
- Enforce restrictions
- API: `PUT /repos/{owner}/{repo}/branches/{branch}/protection`

### GH-28. Commit Status

Create and query commit statuses.

**Requirements:**
- Create commit status (pending, success, failure, error)
- Get commit status
- List statuses for reference
- API: `POST /repos/{owner}/{repo}/statuses/{sha}`

### GH-29. Compare Commits

Compare two commits or branches.

**Requirements:**
- Compare commits
- Get diff information
- List changed files
- API: `GET /repos/{owner}/{repo}/compare/{basehead}`

## Category 5: Repository Operations

### GH-30. Repository Information

Query repository metadata and settings.

**Requirements:**
- Get repository details
- List contributors
- Get repository statistics
- API: `GET /repos/{owner}/{repo}`

### GH-31. Repository Content

Read and write repository files via API.

**Requirements:**
- Get file contents
- Create/update files
- Delete files
- API: `GET /repos/{owner}/{repo}/contents/{path}`

### GH-32. Releases

Create and manage releases.

**Requirements:**
- Create release
- Upload release assets
- Update release
- List releases
- API: `POST /repos/{owner}/{repo}/releases`

## Category 6: Webhook and Event Management

### GH-33. Webhook Management (Enhanced)

Expand on GH-11 failure. Manage webhooks via REST API.

**Requirements:**
- Create repository webhook
- List webhooks
- Update webhook configuration
- Delete webhook
- Test webhook delivery
- API: `POST /repos/{owner}/{repo}/hooks`

### GH-34. Webhook Event Handling

Handle and parse webhook payloads for different events.

**Requirements:**
- Handle workflow_run events
- Handle pull_request events
- Handle push events
- Validate webhook signatures
- Event filtering

## Category 7: Advanced Workflow Operations

### GH-35. Cancel Running Workflow

Cancel a running workflow execution.

**Requirements:**
- Cancel workflow run by run_id
- Check cancellation status
- API: `POST /repos/{owner}/{repo}/actions/runs/{run_id}/cancel`

### GH-36. Re-run Workflow

Re-run failed or completed workflows.

**Requirements:**
- Re-run entire workflow
- Re-run failed jobs only
- API: `POST /repos/{owner}/{repo}/actions/runs/{run_id}/rerun`

### GH-37. Workflow Usage and Billing

Query workflow usage and billing information.

**Requirements:**
- Get workflow usage
- Get billing information
- List runner usage
- API: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/timing`

### GH-38. Self-hosted Runners

Manage self-hosted runners.

**Requirements:**
- List self-hosted runners
- Get runner details
- Remove runner
- API: `GET /repos/{owner}/{repo}/actions/runners`

### GH-39. Workflow Artifacts

Download and manage workflow artifacts.

**Requirements:**
- List artifacts for run
- Download artifact
- Delete artifact
- API: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`

### GH-40. Repository Secrets

Manage repository secrets for workflows.

**Requirements:**
- List secrets
- Create/update secret (with encryption)
- Delete secret
- API: `GET /repos/{owner}/{repo}/actions/secrets`

## Category 8: Integration and Composite Operations

### GH-41. PR-to-Workflow Integration

Create PR that triggers workflow, monitor workflow status, and update PR status.

**Requirements:**
- Create PR on feature branch
- Workflow triggers automatically
- Monitor workflow execution
- Report status back to PR
- Composite operation

### GH-42. Issue-to-Release Workflow

Track issues through commits, PRs, and into releases.

**Requirements:**
- Link issues to commits
- Track in PRs
- Include in release notes
- Query issue lifecycle
- Composite operation

### GH-43. Parallel Workflow Execution

Trigger multiple workflows in parallel and correlate results.

**Requirements:**
- Trigger N workflows simultaneously
- Correlate all run IDs
- Aggregate results
- Performance benchmarking

## Category 9: Testing and Quality

### GH-44. API Rate Limiting

Test and handle GitHub API rate limits.

**Requirements:**
- Check rate limit status
- Handle rate limit errors
- Implement backoff strategies
- API: `GET /rate_limit`

### GH-45. Error Handling Patterns

Systematically test error scenarios.

**Requirements:**
- Invalid authentication
- Resource not found
- Permission denied
- Validation errors
- Network errors

### GH-46. Pagination Handling

Test pagination across different endpoints.

**Requirements:**
- Handle Link headers
- Iterate through pages
- Aggregate results
- Performance considerations

## Recommendations for Next Sprints

**High Priority (REST API Validation):**
- GH-13: Trigger workflow with REST API
- GH-14: Workflow correlation with REST API
- GH-16: Fetch logs with REST API

**High Priority (Pull Requests):**
- GH-17: Create Pull Request
- GH-18: List Pull Requests
- GH-21: Pull Request Reviews

**Medium Priority:**
- GH-26: Branch Management
- GH-35: Cancel Running Workflow
- GH-39: Workflow Artifacts

**Low Priority (Advanced):**
- GH-40: Repository Secrets
- GH-41: PR-to-Workflow Integration
- GH-44: API Rate Limiting

## Notes

1. All REST API items should use curl with token authentication stored in `./secrets` directory
2. Each item should include comprehensive error handling
3. Testing should cover happy paths and error scenarios
4. Documentation should include API reference links
5. Scripts should follow existing patterns from completed sprints
