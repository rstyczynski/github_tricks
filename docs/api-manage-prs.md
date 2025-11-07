# Manage GitHub Pull Requests via REST API

**API Operation Summary** | Sprints 13-14 Implementation (GH-17, GH-18, GH-19, GH-20, GH-22)

## Purpose

Complete pull request lifecycle management: creating, listing, updating, merging, and commenting. Enables automated PR workflows and code review automation.

## API Endpoints

### Create Pull Request
```
POST /repos/{owner}/{repo}/pulls
```

### List Pull Requests
```
GET /repos/{owner}/{repo}/pulls
```

### Update Pull Request
```
PATCH /repos/{owner}/{repo}/pulls/{pull_number}
```

### Merge Pull Request
```
PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge
```

### Add PR Comment
```
POST /repos/{owner}/{repo}/pulls/{pull_number}/comments
```

**Documentation**: [GitHub REST API - Pull Requests](https://docs.github.com/en/rest/pulls)

## Complete PR Lifecycle Example

```bash
# Step 1: Create PR
PR_NUMBER=$(./scripts/create-pr.sh \
  --head feature-branch \
  --base main \
  --title "Add new feature" \
  --json | jq -r '.number')

# Step 2: List PRs to verify
./scripts/list-prs.sh --state open

# Step 3: Add comment
./scripts/add-pr-comment.sh \
  --pr $PR_NUMBER \
  --body "LGTM! Ready to merge"

# Step 4: Update PR (if needed)
./scripts/update-pr.sh \
  --pr $PR_NUMBER \
  --title "Updated: Add new feature"

# Step 5: Merge PR
./scripts/merge-pr.sh \
  --pr $PR_NUMBER \
  --method squash
```

## Merge Strategies

- **merge**: Create merge commit
- **squash**: Squash and merge
- **rebase**: Rebase and merge

## Implementation References

- **Sprint 13** (GH-17, 18, 19): Create, List, Update PRs
- **Sprint 14** (GH-20, 22): Merge PRs, PR Comments
- See: `progress/sprint_13_implementation.md`, `progress/sprint_14_implementation.md`
