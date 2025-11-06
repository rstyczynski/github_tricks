# Elaboration Sprint 13 - Chat 1

**Date**: 2025-01-15
**Sprint**: 13
**Status**: Elaboration Phase Complete
**Backlog Items**: GH-17, GH-18, GH-19

## Design Summary

This elaboration phase completes the design for Sprint 13, which implements Pull Request management capabilities through GitHub REST API. The design builds upon the analysis from the inception phase and provides comprehensive specifications for implementation.

## Design Process

### 1. Review of Analysis Document

Reviewed `progress/sprint_13_analysis.md` to understand:
- Feasibility assessment (all three backlog items confirmed feasible)
- Established patterns from previous sprints
- Technical approach selection (curl-based REST API)
- Integration points and risks

### 2. Design Document Creation

Created comprehensive design document: `progress/sprint_13_design.md`

**Structure**:
- Overview and key design decisions
- Feasibility analysis summary
- Detailed design for each backlog item:
  - GH-17: Create Pull Request
  - GH-18: List Pull Requests
  - GH-19: Update Pull Request
- Architecture diagram
- Script designs with CLI interfaces
- Implementation details with code examples
- Error handling specifications
- Integration patterns
- Testing strategy
- Risks and mitigations

### 3. Design Decisions Made

**Technical Approach**:
- Selected curl-based REST API approach (following Sprint 9 pattern)
- Token authentication from `.secrets/token` file
- Repository auto-detection from git config (with fallbacks)

**Design Principles**:
- Assume branches exist (Unix philosophy - scripts don't create branches)
- Support both human-readable and JSON output formats
- Follow established input method priority order
- Comprehensive error handling for all HTTP status codes

**Pagination Strategy** (GH-18):
- Default: Single page mode (faster, explicit control)
- Optional: `--all` flag for automatic pagination (may be slow for many PRs)

**Update Strategy** (GH-19):
- Only include provided fields in update payload
- At least one update field required
- Special handling for merge conflicts when changing base branch

## Design Details by Backlog Item

### GH-17. Create Pull Request

**Script**: `scripts/create-pr.sh`

**Key Features**:
- Required parameters: `--head`, `--title`
- Optional parameters: `--base` (default: `main`), `--body`, `--reviewers`, `--labels`, `--issue`, `--draft`
- Repository auto-detection from git config
- Token authentication from `.secrets/token`
- Dual output formats: human-readable (default) and JSON (`--json`)

**API Endpoint**: `POST /repos/{owner}/{repo}/pulls`

**Error Handling**:
- HTTP 201: Success (output PR details)
- HTTP 422: Validation error (duplicate PR, invalid branch, invalid label)
- HTTP 404: Repository or branch not found
- HTTP 403: Insufficient permissions
- HTTP 401: Authentication failed

**Implementation Highlights**:
- Request body built dynamically (only include provided fields)
- Repository resolution with multiple fallback options
- Comprehensive error messages with field-specific details

### GH-18. List Pull Requests

**Script**: `scripts/list-prs.sh`

**Key Features**:
- All parameters optional (sensible defaults: state=open, sort=created, direction=desc)
- Filtering: `--state`, `--head`, `--base`
- Sorting: `--sort` (created, updated, popularity), `--direction` (asc, desc)
- Pagination: `--page`, `--per-page`, `--all` (fetch all pages)
- Dual output formats: table (default) and JSON (`--json`)

**API Endpoint**: `GET /repos/{owner}/{repo}/pulls`

**Pagination Implementation**:
- Single page mode (default): Fetch only requested page
- All pages mode (`--all`): Follow Link headers or iterate pages
- Max per_page: 100 (for efficiency when fetching all)

**Output Formats**:
- Human-readable: Formatted table with columns (number, title, state, head, base)
- JSON: Array of PR objects with full details

**Error Handling**:
- HTTP 200: Success (output PR list)
- HTTP 404: Repository not found
- HTTP 403: Insufficient permissions
- HTTP 401: Authentication failed

### GH-19. Update Pull Request

**Script**: `scripts/update-pr.sh`

**Key Features**:
- Required parameter: `--pr-number`
- Optional parameters: `--title`, `--body`, `--state`, `--base`
- At least one update field required
- Dual output formats: human-readable (default) and JSON (`--json`)

**API Endpoint**: `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`

**Update Payload**:
- Only include provided fields in request body
- Dynamic payload building based on provided parameters

**Special Handling**:
- Base branch changes: Merge conflict detection, status check re-triggering
- State changes: Close/reopen PRs via state field
- Validation: At least one update field required

**Error Handling**:
- HTTP 200: Success (output updated PR details)
- HTTP 422: Validation error (merge conflicts, invalid fields)
- HTTP 404: PR not found
- HTTP 403: Insufficient permissions
- HTTP 401: Authentication failed

**Merge Conflict Details**:
- Parse HTTP 422 response for conflict information
- Provide actionable error messages
- Document that status checks re-trigger automatically

## Architecture Diagram

Created ASCII architecture diagram showing:
- Three main components (GH-17, GH-18, GH-19)
- Shared components (Token Auth, Repo Resolve, Error Handle)
- Data flow and API endpoints
- Integration points

## Integration Patterns

**Pattern 1: Create → Update PR**:
- Create PR with `create-pr.sh`, capture PR number
- Update PR later with `update-pr.sh` using PR number

**Pattern 2: List → Update Multiple PRs**:
- List PRs with `list-prs.sh` (JSON output)
- Pipe PR numbers to `update-pr.sh` for batch updates

**Pattern 3: Create PR with Auto-detection**:
- Auto-detect repository from git context
- Auto-detect current branch as head branch
- Use git log for PR title suggestion

## Testing Strategy

**GH-17 Test Cases** (10 scenarios):
- Minimal fields, all metadata, draft PRs
- Duplicate PRs, invalid branches, invalid labels
- Missing required fields, JSON output, auto-detect repository

**GH-18 Test Cases** (10 scenarios):
- Default filters, all PRs, filter by head/base
- Sorting, pagination (single page and all pages)
- JSON output, empty results, auto-detect repository

**GH-19 Test Cases** (10 scenarios):
- Update individual fields (title, body, state, base)
- Update multiple fields, merge conflicts
- Invalid PR number, missing update fields, JSON output

**Integration Tests**:
- Create → List → Update workflow
- Verify PR appears in list after creation
- Verify updates are reflected correctly

## Compatibility with Previous Sprints

**Sprint 9 (API Access Pattern)**:
- ✅ Reuse token file authentication pattern
- ✅ Follow curl-based REST API approach
- ✅ Consistent error handling patterns
- ✅ Repository auto-detection from git config

**Sprint 11 (Script Structure)**:
- ✅ Follow script structure patterns (`set -euo pipefail`)
- ✅ Reuse input method priority order
- ✅ Dual output formats (human-readable and JSON)
- ✅ Comprehensive help documentation

**Sprint 8 (Input Methods)**:
- ✅ Multiple input methods support (where applicable)
- ✅ JSON stdin/stdout for pipeline composition
- ✅ Consistent CLI interface

## Risks and Mitigations

**Risk 1: Branch Management Complexity**
- Mitigation: Assume branches exist, document requirement clearly

**Risk 2: Pagination Performance**
- Mitigation: Default to single page, require explicit `--all` flag

**Risk 3: Merge Conflict Handling**
- Mitigation: Parse HTTP 422 response, provide clear error messages

**Risk 4: Authentication Token Permissions**
- Mitigation: Document required permissions, provide clear error messages

**Risk 5: API Rate Limiting**
- Mitigation: Document rate limits, handle 403 responses gracefully

## Design Decisions Rationale

**Why curl-based REST API?**
- Full control over API parameters (matches requirement)
- Consistent with Sprint 9 approach
- More flexible for automation
- Better error handling and validation

**Why assume branches exist?**
- Follows Unix philosophy (do one thing well)
- Reduces complexity and dependencies
- Clear separation of concerns (git operations vs PR operations)

**Why default to single page pagination?**
- Faster response times
- Explicit control for users
- Avoids unexpected long-running operations
- `--all` flag available when needed

**Why require at least one update field?**
- Prevents accidental no-op updates
- Clearer API contract
- Better error messages

## Progress Board Updates

Updated `PROGRESS_BOARD.md`:
- Sprint 13 status: `under_design` (unchanged, as per rules)
- GH-17 status: `under_design` → `designed`
- GH-18 status: `under_design` → `designed`
- GH-19 status: `under_design` → `designed`

## Source Documents Referenced

**Primary Requirements**:
- `BACKLOG.md` lines 93-103 - GH-17, GH-18, GH-19 specifications
- `PLAN.md` lines 129-137 - Sprint 13 definition

**Analysis Document**:
- `progress/sprint_13_analysis.md` - Comprehensive analysis (inception phase)

**Design Document**:
- `progress/sprint_13_design.md` - Comprehensive design (elaboration phase)

**Process Rules**:
- `rules/GENERAL_RULES_v3.md` - Sprint lifecycle, ownership, feedback channels
- `rules/GitHub_DEV_RULES_v4.md` - GitHub-specific implementation guidelines
- `rules/PRODUCT_OWNER_GUIDE_v3.md` - Phase transitions and review procedures

**Technical References**:
- `progress/sprint_9_design.md` - API access patterns, token authentication
- `progress/sprint_11_design.md` - Script structure patterns, error handling
- `progress/sprint_11_implementation.md` - Implementation patterns, testing approach

## Design Artifacts

**Created Files**:
- `progress/sprint_13_design.md` - Comprehensive design document (1,000+ lines)

**Updated Files**:
- `PROGRESS_BOARD.md` - Updated backlog item statuses to `designed`

## Confirmation

✅ All three backlog items designed:
- GH-17: Create Pull Request - Complete design with CLI interface, API integration, error handling
- GH-18: List Pull Requests - Complete design with filtering, pagination, output formats
- GH-19: Update Pull Request - Complete design with update operations, merge conflict handling

✅ Design follows established patterns:
- Sprint 9: Token authentication, curl-based REST API, repository auto-detection
- Sprint 11: Script structure, input methods, output formats, error handling
- Sprint 8: Multiple input methods, JSON composition

✅ Comprehensive specifications:
- Architecture diagram created
- CLI interfaces specified for all scripts
- Implementation details with code examples
- Error handling for all HTTP status codes
- Integration patterns documented
- Testing strategy with 30+ test cases
- Risks identified with mitigations

✅ Ready for Product Owner review and approval

## Next Steps

1. **Product Owner Review**: Review design document (`progress/sprint_13_design.md`)
2. **Design Approval**: Wait for Product Owner approval (status change to "Accepted")
3. **Construction Phase**: Implement scripts following design specifications
4. **Testing Phase**: Execute test suite and document results

## Design Completeness Checklist

- ✅ Feasibility analysis completed
- ✅ Architecture diagram created
- ✅ Script designs for GH-17, GH-18, GH-19
- ✅ CLI interfaces specified
- ✅ Implementation details with code examples
- ✅ Error handling specifications
- ✅ Output formats (human-readable and JSON)
- ✅ Integration patterns documented
- ✅ Testing strategy with test cases
- ✅ Risks and mitigations identified
- ✅ Compatibility with previous sprints verified
- ✅ Progress board updated
- ✅ Design document ready for review

