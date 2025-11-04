# Inception Review – Sprint 9 (Chat 1)

## Context

Product Owner initiated Sprint 9 inception. Sprint 9 is in Progress status and aims to reimplement GH-12 using a different technical approach than Sprint 8.

## Sprint Status Review

From SRS.md Implementation Plan:
- **Sprint 0**: Done (Prerequisites - GH-1)
- **Sprint 1**: Done (Trigger & Correlation - GH-2, GH-3)
- **Sprint 2**: Failed (Real-time logs - GH-4)
- **Sprint 3**: Done (Post-run logs - GH-5)
- **Sprint 4**: Done (Benchmarks - GH-3.1, GH-5.1)
- **Sprint 5**: Implemented (Project review & ecosystem analysis)
- **Sprint 6**: Failed (Job-level logs API - GH-10)
- **Sprint 7**: Failed (Webhook correlation - GH-11)
- **Sprint 8**: Done (Job phases with status using gh CLI - GH-12)
- **Sprint 9**: Progress (Job phases with status using curl API - GH-12)

## Project History Summary

### Successful Deliverables (Sprints 0-8)

**Sprint 0** - Prerequisites and tooling setup:
- Comprehensive operator guide
- Tools: GitHub CLI (gh), Go, Java, Podman, act, actionlint, jq
- Library recommendations: hub4j/github-api (Java), google/go-github (Go)

**Sprint 1** - Workflow triggering and correlation:
- `.github/workflows/dispatch-webhook.yml` - reusable workflow
- `scripts/trigger-and-track.sh` - UUID-based correlation (2-5s latency)
- `scripts/notify-webhook.sh` - webhook POST with retry
- Storage: `runs/<correlation_id>/metadata.json`

**Sprint 3** - Post-run log retrieval:
- `scripts/fetch-run-logs.sh` - download/extract logs to ZIP
- `scripts/lib/run-utils.sh` - shared metadata utilities
- Storage: `runs/<correlation_id>/logs/` with combined.log and logs.json

**Sprint 4** - Performance benchmarking:
- `scripts/benchmark-correlation.sh` - measures run_id retrieval timing
- `scripts/benchmark-log-retrieval.sh` - measures log download timing
- Statistical analysis with mean/min/max/median

**Sprint 5** - Project review (research sprint, 1,900+ lines):
- Complete retrospective of Sprints 0-4
- GitHub CLI capabilities inventory
- GitHub API comprehensive analysis
- Major libraries survey (Java, Go, Python)

**Sprint 8** - Job phases with status using gh CLI (GH-12):
- `scripts/view-run-jobs.sh` (399 lines) - uses `gh run view --json`
- Multiple input methods: `--run-id`, `--correlation-id`, stdin JSON, interactive prompt
- Four output formats: table, verbose, JSON, watch mode
- Integration with Sprint 1 correlation and Sprint 3 utilities
- Features: retry logic, error handling, duration calculation, GitHub URL display

### Failed Sprints - Root Causes

**Sprint 2 (GH-4)** - Real-time log streaming:
- **Failure reason**: GitHub platform limitation - no streaming API exists
- Evidence: REST API returns 404 for in-progress runs, Web UI uses polling
- Status: Impossible to implement (confirmed by Sprint 5 research)

**Sprint 6 (GH-10)** - Job-level logs API validation:
- **Failure reason**: Requires public webhook endpoint for testing
- Status: Hypothesis untested

**Sprint 7 (GH-11)** - Webhook-based correlation:
- **Failure reason**: Requires public endpoint unavailable in test environment
- Delivered tooling: `scripts/manage-actions-webhook.sh`, `scripts/process-workflow-webhook.sh`
- Status: Tooling exists but unvalidated

## Sprint 9 (GH-12) Understanding

### Backlog Item: GH-12 (Alternative Implementation)

**Requirement** (from SRS.md):
> Use GitHub API to get workflow job phases with status mimicking `gh run view <run_id>`. Use API or gh utility. Prefer browser based authentication for simplicity.

**Sprint 9 Specific Requirement**:
> Implement GH-12 using API calls with curl. Use token file from ./secrets directory

**Goal**: Reimplement the same functionality as Sprint 8 but using direct `curl` API calls instead of `gh` CLI, and authenticate using a token file from `./secrets` directory.

### Sprint 8 vs Sprint 9 Comparison

| Aspect | Sprint 8 (Done) | Sprint 9 (Progress) |
|--------|-----------------|---------------------|
| **Tool** | `gh` CLI | `curl` with REST API |
| **Authentication** | Browser-based (gh auth) | Token file (`./secrets/`) |
| **Implementation** | `scripts/view-run-jobs.sh` | New script (curl-based) |
| **Backlog Item** | GH-12 | GH-12 (same requirement) |
| **Output formats** | Table, verbose, JSON, watch | Same expected |
| **Integration** | Sprint 1/3 patterns | Same expected |

### Why Alternative Implementation?

**Rationale for Sprint 9**:
1. **Direct API access**: Demonstrates raw GitHub REST API usage without CLI wrapper
2. **Token-based auth**: Shows enterprise authentication pattern (token files)
3. **Independence from gh CLI**: Reduces dependency on external tools
4. **Educational value**: Shows both CLI and API approaches for same problem
5. **Flexibility**: Token file approach works in environments where browser auth unavailable

### Technical Requirements for Sprint 9

**GitHub REST API endpoints** (from Sprint 5 research):
- `GET /repos/:owner/:repo/actions/runs/:run_id` - Get run details
- `GET /repos/:owner/:repo/actions/runs/:run_id/jobs` - List jobs for run

**Authentication**:
- Token file location: `./secrets/` directory
- Header format: `Authorization: Bearer <token>`
- Token should be GitHub Personal Access Token (PAT) or fine-grained token

**Expected functionality** (parity with Sprint 8):
- Input methods: `--run-id`, `--correlation-id`, stdin JSON
- Output formats: table, verbose, JSON, watch mode
- Error handling: network errors, invalid run_id, missing token
- Integration: read Sprint 1 correlation metadata

**Differences from Sprint 8**:
- No `gh` CLI dependency
- Token file authentication instead of browser-based
- Direct `curl` REST API calls
- May need to handle pagination manually (jobs array)
- May need to handle JSON parsing with `jq` directly

### Available Building Blocks from Previous Sprints

**Sprint 1** (correlation & metadata):
- `runs/<correlation_id>/metadata.json` format
- Correlation ID to run_id mapping pattern

**Sprint 3** (shared utilities):
- `scripts/lib/run-utils.sh` - metadata loading functions
- Error handling patterns

**Sprint 5** (API research):
- GitHub REST API endpoint documentation
- Authentication methods analysis
- Rate limiting information (5,000 requests/hour authenticated)

**Sprint 8** (reference implementation):
- `scripts/view-run-jobs.sh` - functional reference
- Output format examples (table, verbose, JSON)
- Error messages and user experience patterns

### Design Considerations for Sprint 9

1. **Token file handling**:
   - Read token from `./secrets/github_token` (or similar)
   - Validate token file exists and readable
   - Handle missing token with clear error message
   - Mask token in error messages (security)

2. **curl vs gh CLI differences**:
   - Manual HTTP header construction
   - Manual JSON response parsing with `jq`
   - Manual pagination if jobs array exceeds page size
   - Manual retry logic for network errors
   - User-Agent header for API best practices

3. **API endpoint construction**:
   - Need repository owner/name (from context or metadata)
   - Need to resolve run_id (reuse Sprint 1 correlation)
   - Construct full URLs: `https://api.github.com/repos/:owner/:repo/actions/runs/:run_id`

4. **Output format compatibility**:
   - Should produce same output formats as Sprint 8 for consistency
   - Table, verbose, JSON, watch mode
   - GitHub URL display (same as Sprint 8 enhancement)

5. **Error handling**:
   - HTTP status codes (401 unauthorized, 404 not found, 403 rate limited, 500 server error)
   - Network errors (timeout, DNS resolution)
   - Token file errors (missing, invalid, expired)
   - JSON parsing errors

### Repository/Owner Resolution

**Challenge**: `curl` needs explicit owner/repo in URL, while `gh` CLI auto-detects from git context.

**Options**:
1. Auto-detect from `.git/config` (parse remote URL)
2. Accept `--repo owner/repo` CLI flag
3. Store in metadata from Sprint 1 trigger
4. Use environment variable `GITHUB_REPOSITORY`

### Compatibility Requirements

Must maintain compatibility with:
- Sprint 1: Read `runs/<correlation_id>/metadata.json`
- Sprint 3: Use `scripts/lib/run-utils.sh` if applicable
- Sprint 8: Same CLI interface and output formats for user experience consistency

### Use Cases (Same as Sprint 8)

1. **Monitor workflow progress**: `script.sh --run-id 123 --watch`
2. **Quick status check**: `script.sh --run-id 123`
3. **Programmatic querying**: `script.sh --run-id 123 --json | jq '.jobs[].status'`
4. **Integration with trigger-and-track**: `trigger-and-track.sh | script.sh`

### Success Criteria (Expected)

Sprint 9 will be successful when:

1. ✅ New script exists using `curl` for API calls (not `gh` CLI)
2. ✅ Token authentication from `./secrets/` directory
3. ✅ Same output formats as Sprint 8 (table, verbose, JSON, watch)
4. ✅ Same input methods as Sprint 8 (run-id, correlation-id, stdin)
5. ✅ Integration with Sprint 1 correlation metadata
6. ✅ Error handling for token issues, network errors, API errors
7. ✅ Passes shellcheck validation
8. ✅ Manual tests pass with real GitHub repository
9. ✅ Documentation complete (inline help, implementation notes)
10. ✅ Functional parity with Sprint 8 output

## Implementor Confirmation

Understanding confirmed:
- Sprint 9 (GH-12) aims to reimplement Sprint 8 functionality using `curl` API calls instead of `gh` CLI
- Authentication via token file in `./secrets/` directory (not browser-based)
- Must maintain output format compatibility with Sprint 8 for user experience
- Same integration points with Sprint 1/3 tooling
- Additional complexity: manual HTTP handling, token management, repository resolution

**Key differences from Sprint 8**:
1. No dependency on `gh` CLI (pure bash + curl + jq)
2. Token file authentication (enterprise pattern)
3. Manual API endpoint construction
4. Manual pagination handling if needed
5. Manual retry logic implementation

**Reusable from Sprint 8**:
1. Output format specifications (table, verbose, JSON layout)
2. CLI interface patterns (flags, arguments)
3. Integration with correlation metadata
4. Duration calculation logic
5. Error message patterns

Ready to proceed with Sprint 9 elaboration phase to design the curl-based implementation.
