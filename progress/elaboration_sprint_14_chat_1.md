# Elaboration Sprint 14 - Chat 1

**Date**: 2025-11-06
**Sprint**: 14
**Status**: Elaboration Phase Complete
**Backlog Items**: GH-20, GH-22

## Design Summary

This elaboration phase completes the design for Sprint 14, which extends Pull Request management capabilities from Sprint 13 by adding merge operations and comment management. The design builds upon the analysis from the inception phase and provides comprehensive specifications for implementation.

## Design Process

### 1. Review of Analysis Document

Reviewed `progress/sprint_14_analysis.md` to understand:
- Feasibility assessment (both backlog items confirmed feasible)
- Established patterns from Sprint 13
- Technical approach selection (curl-based REST API)
- Integration points and risks
- Open questions for Product Owner

### 2. Design Decisions Made

**GH-20 (Merge Pull Request)**:
- **Mergeable State Check**: Optional `--check-mergeable` flag (recommended but not required)
- **Merge Conflicts**: Error message with details (no automatic resolution)
- **Status Checks**: Error immediately (do not wait, user handles separately)
- **Custom Commit Messages**: Supported via `--commit-message` flag
- **Force Merge**: Not supported (security risk, not recommended)

**GH-22 (Pull Request Comments)**:
- **Script Structure**: Single script with `--operation` flag (simpler than separate scripts)
- **Inline Comment Positioning**: Separate flags: `--file`, `--line`, `--side`
- **Commit ID**: Auto-detect from PR head if not provided (with `--commit-id` override)
- **List Comments**: Supported via `--operation list` (useful for finding comment IDs)
- **Reactions Format**: Emoji names: `+1`, `-1`, `laugh`, `confused`, `heart`, `hooray`, `rocket`, `eyes`

### 3. Design Document Creation

Created comprehensive design document: `progress/sprint_14_design.md`

**Structure**:
- Overview and key design decisions
- Feasibility analysis summary
- Detailed design for each backlog item:
  - GH-20: Merge Pull Request
  - GH-22: Pull Request Comments
- Architecture diagram
- Script designs with CLI interfaces
- Implementation details with code examples
- Error handling specifications
- Integration patterns
- Testing strategy
- Risks and mitigations

## Design Details by Backlog Item

### GH-20. Merge Pull Request

**Script**: `scripts/merge-pr.sh`

**Key Features**:
- Required parameters: `--pr-number`, `--method` (merge, squash, rebase)
- Optional parameters: `--commit-message` (for squash/merge), `--check-mergeable`
- Repository auto-detection from git config
- Token authentication from `.secrets/token`
- Dual output formats: human-readable (default) and JSON (`--json`)

**API Endpoint**: `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge`

**Mergeable State Check**:
- Optional pre-check via PR details endpoint
- Checks `mergeable` field: `true` (can merge), `false` (conflicts), `null` (unknown)
- Provides informative error messages before merge attempt

**Error Handling**:
- HTTP 200: Success (output merge details)
- HTTP 405: Not mergeable (already merged, conflicts, etc.)
- HTTP 409: Merge conflict detected
- HTTP 403: Insufficient permissions or branch protection
- HTTP 422: Validation error
- HTTP 404: PR not found

**Implementation Highlights**:
- Merge request body built dynamically (only include provided fields)
- Optional mergeable state checking before merge attempt
- Comprehensive error messages with actionable information

### GH-22. Pull Request Comments

**Script**: `scripts/pr-comments.sh`

**Key Features**:
- Required parameters: `--pr-number`, `--operation` (add, add-inline, update, delete, react, list)
- Operation-specific parameters (validated per operation)
- Repository auto-detection from git config
- Token authentication from `.secrets/token`
- Dual output formats: human-readable (default) and JSON (`--json`)

**Operations**:
1. **`add`**: Add general PR comment (issues API)
2. **`add-inline`**: Add inline code review comment (pulls API)
3. **`update`**: Update existing comment
4. **`delete`**: Delete comment
5. **`react`**: Add reaction to comment
6. **`list`**: List comments on PR

**Inline Comment Handling**:
- Auto-detect commit_id from PR head if not provided
- Validate file path, line number, side (left/right)
- Clear error messages for invalid inputs

**Error Handling**:
- Operation-specific error handling
- HTTP 201/200: Success (output comment details)
- HTTP 404: PR/Comment not found
- HTTP 403: Insufficient permissions
- HTTP 422: Validation error (invalid reaction, invalid line, etc.)

**Implementation Highlights**:
- Single script with operation flag (simpler than separate scripts)
- Commit ID auto-detection for inline comments
- Operation-specific validation and error handling
- List operation for finding comment IDs

## Architecture Diagram

Created ASCII architecture diagram showing:
- Two main components (GH-20, GH-22)
- GH-22 operations breakdown (add, update, delete, react, list)
- Shared components (Token Auth, Repo Resolve, Error Handle)
- Data flow and API endpoints
- Integration points with Sprint 13

## Integration Patterns

**Pattern 1: Create → Comment → Merge PR**:
- Create PR with `create-pr.sh`, capture PR number
- Add comment with `pr-comments.sh` using PR number
- Merge PR with `merge-pr.sh` using PR number

**Pattern 2: Add Inline Comment**:
- Auto-detect commit ID from PR head
- Specify file path, line number, and side
- Add inline comment at specific code location

**Pattern 3: Update Comment**:
- List comments to find comment ID
- Update comment using comment ID

## Testing Strategy

**GH-20 Test Cases** (12 scenarios):
- Merge with different strategies (merge, squash, rebase)
- Custom commit messages, mergeable state checking
- Merge conflicts, status checks, branch protection
- Already merged PRs, invalid PR numbers, JSON output

**GH-22 Test Cases** (12 scenarios):
- All operations (add, add-inline, update, delete, react, list)
- Commit ID auto-detection, invalid inputs
- Invalid file paths, line numbers, reactions
- Invalid comment IDs, JSON output

## Compatibility with Previous Sprints

**Sprint 13 (PR Management)**: ✅ Verified
- Token file authentication pattern reused
- curl-based REST API approach followed
- Repository auto-detection pattern reused
- Error handling patterns consistent
- Dual output formats maintained
- PR number as primary identifier

**Sprint 9 (API Access Pattern)**: ✅ Verified
- Token file authentication pattern reused
- curl-based REST API calls
- Consistent error handling patterns

**Sprint 11 (Script Structure)**: ✅ Verified
- Script structure patterns followed
- Help documentation format consistent
- Error handling and exit codes consistent
- Output format patterns consistent

## Risks and Mitigations

**Risk 1: Merge Conflict Handling**
- Mitigation: Optional mergeable state checking, clear error messages

**Risk 2: Required Status Checks**
- Mitigation: Error immediately (do not wait), clear error messages

**Risk 3: Branch Protection Rules**
- Mitigation: Clear error messages explaining violations

**Risk 4: Inline Comment Complexity**
- Mitigation: Auto-detect commit_id, validate inputs, clear examples

**Risk 5: Comment Endpoint Confusion**
- Mitigation: Operation flag distinguishes endpoints, clear documentation

**Risk 6: Commit ID Auto-detection Failure**
- Mitigation: Allow explicit `--commit-id` flag, fallback to auto-detection

## Design Decisions Rationale

**Why optional mergeable state check?**
- Provides informative feedback before merge attempt
- Optional to allow direct merge attempts (faster)
- User can choose based on their workflow

**Why single script for comments?**
- Simpler than separate scripts
- Consistent CLI interface
- Operation flag clearly distinguishes operations
- Easier to maintain

**Why auto-detect commit_id?**
- Reduces complexity for users
- Most common use case (comment on PR head)
- Can be overridden if needed

**Why error immediately for status checks?**
- Status checks are external dependencies
- Waiting could be indefinite
- User should handle status checks separately
- Clear error message guides user

## Progress Board Updates

Updated `PROGRESS_BOARD.md`:
- Sprint 14 status: `under_design` (unchanged, as per rules)
- GH-20 status: `under_design` → `designed`
- GH-22 status: `under_design` → `designed`

## Source Documents Referenced

**Primary Requirements**:
- `BACKLOG.md` lines 105-111 - GH-20, GH-22 specifications
- `PLAN.md` lines 139-146 - Sprint 14 definition

**Analysis Document**:
- `progress/sprint_14_analysis.md` - Comprehensive analysis (inception phase)

**Design Document**:
- `progress/sprint_14_design.md` - Comprehensive design (elaboration phase)

**Process Rules**:
- `rules/GENERAL_RULES_v3.md` - Sprint lifecycle, ownership, feedback channels
- `rules/GitHub_DEV_RULES_v4.md` - GitHub-specific implementation guidelines
- `rules/PRODUCT_OWNER_GUIDE_v3.md` - Phase transitions and review procedures

**Technical References**:
- `progress/sprint_13_design.md` - Sprint 13 design patterns
- `progress/sprint_13_implementation.md` - Sprint 13 implementation patterns
- `scripts/create-pr.sh` - PR creation script (for integration patterns)
- `scripts/update-pr.sh` - PR update script (for integration patterns)

## Design Artifacts

**Created Files**:
- `progress/sprint_14_design.md` - Comprehensive design document (1,200+ lines)

**Updated Files**:
- `PROGRESS_BOARD.md` - Updated backlog item statuses to `designed`

## Confirmation

✅ Both backlog items designed:
- GH-20: Merge Pull Request - Complete design with merge strategies, mergeable state checking, error handling
- GH-22: Pull Request Comments - Complete design with all operations (add, update, delete, react, list)

✅ Design follows established patterns:
- Sprint 13: Token authentication, curl-based REST API, repository auto-detection
- Sprint 11: Script structure, input methods, output formats, error handling
- Sprint 9: API access patterns

✅ Comprehensive specifications:
- Architecture diagram created
- CLI interfaces specified for both scripts
- Implementation details with code examples
- Error handling for all HTTP status codes
- Integration patterns documented
- Testing strategy with 24+ test cases
- Risks identified with mitigations

✅ Ready for Product Owner review and approval

## Next Steps

1. **Product Owner Review**: Review design document (`progress/sprint_14_design.md`)
2. **Design Approval**: Wait for Product Owner approval (status change to "Accepted")
3. **Construction Phase**: Implement scripts following design specifications
4. **Testing Phase**: Execute test suite and document results

## Design Completeness Checklist

- ✅ Feasibility analysis completed
- ✅ Architecture diagram created
- ✅ Script designs for GH-20, GH-22
- ✅ CLI interfaces specified
- ✅ Implementation details with code examples
- ✅ Error handling specifications
- ✅ Output formats (human-readable and JSON)
- ✅ Integration patterns documented
- ✅ Testing strategy with test cases
- ✅ Risks and mitigations identified
- ✅ Compatibility with Sprint 13 verified
- ✅ Progress board updated
- ✅ Design document ready for review

