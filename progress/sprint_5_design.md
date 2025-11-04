# Sprint 5 - Design

## Objective 1: Enumerate Project Achievements and Failures

Status: Accepted

### Goal

Provide a comprehensive retrospective of Sprints 0-4, documenting what worked, what didn't, why, and lessons learned. This internal analysis establishes project context before comparing against external ecosystem.

### Research Approach

**Primary Sources**:
- `SRS.md` - Backlog items and sprint definitions
- `progress/sprint_*_design.md` - Design decisions for each sprint
- `progress/sprint_*_implementation.md` - Implementation outcomes
- `progress/*_chat_*.md` - Development history and problem-solving
- Implemented scripts and workflows in repository

**Analysis Method**:
1. **Per-Sprint Review**: For each sprint (0-4), document:
   - Original requirements from SRS backlog items
   - Design approach taken
   - Implementation outcome (success/failure/partial)
   - Key challenges encountered
   - Solutions applied
   - Artifacts delivered

2. **Success Criteria Assessment**: Evaluate against original backlog item descriptions:
   - GH-1: Tooling setup ✓
   - GH-2: Workflow triggering ✓
   - GH-3: Correlation mechanism ✓
   - GH-3.1: Correlation timing benchmarks ✓
   - GH-4: Real-time log streaming ✗ (GitHub API limitation)
   - GH-5: Post-run log access ✓
   - GH-5.1: Log retrieval timing benchmarks ✓

3. **Technical Lessons Learned**:
   - What architectural decisions proved effective
   - What technical challenges were encountered
   - What workarounds were necessary
   - What limitations were discovered (e.g., no streaming API)

4. **Process Lessons Learned**:
   - Effectiveness of agentic programming workflow
   - Quality of requirements and design phases
   - Testing and validation approaches
   - Documentation completeness

### Deliverable Structure

```markdown
## 1. Project Achievements and Failures

### 1.1 Sprint-by-Sprint Analysis

#### Sprint 0: Prerequisites
- **Status**: Done
- **Requirements**: [original backlog items]
- **Delivered**: [artifacts]
- **Assessment**: [success/partial/failure with rationale]
- **Lessons Learned**: [technical and process insights]

[Repeat for Sprints 1-4]

### 1.2 Overall Project Assessment

- **Delivered Value**: What functionality is available
- **Technical Success**: Quality and robustness of solutions
- **Known Limitations**: What cannot be achieved (e.g., real-time streaming)
- **Reusability**: How well components work together

### 1.3 Key Lessons Learned

- **Technical**: Architecture, tooling, API usage
- **Process**: Agentic programming, requirements, testing
- **Recommendations**: For future sprints or similar projects
```

### Success Criteria

- All sprints (0-4) analyzed with clear success/failure determination
- Sprint 2 failure (GH-4) explained with root cause (GitHub API limitation)
- Lessons learned actionable for future development
- Assessment objective, not promotional

### Research Findings

## 1. Project Achievements and Failures

### 1.1 Sprint-by-Sprint Analysis

#### Sprint 0: Prerequisites

**Status**: Done

**Requirements** (GH-1):
- Prepare toolset for GitHub workflow interaction
- Cover GitHub CLI, Go, and Java libraries
- Propose production-suitable libraries (especially Java)
- Provide operator-friendly guided documentation

**Delivered Artifacts**:
- `progress/sprint_0_prerequisites.md` - Comprehensive operator guide (187 lines)
- Installation procedures for macOS (Homebrew) and Linux (apt)
- Tools covered: GitHub CLI (gh ≥2.0), Go (≥1.21), Java (Temurin/OpenJDK ≥17), Podman, act, actionlint, jq
- Verification matrix with validation commands
- Library recommendations:
  - Java: hub4j/github-api, OkHttp
  - Go: google/go-github, hashicorp/go-retryablehttp

**Assessment**: **Complete Success** ✓

Sprint 0 delivered exactly what was requested. The prerequisites document provides clear copy-paste command sequences for operators. All tools specified in requirements were documented with version requirements, installation steps, and verification commands.

**Key Challenges**:
- Cross-platform compatibility (macOS vs Linux) for package managers and tool paths
- Podman setup complexity (machine initialization on macOS)
- GOPATH configuration for actionlint installation

**Solutions Applied**:
- Platform-specific sections with conditional logic
- Explicit Podman machine initialization steps
- Shell profile detection (bash vs zsh) for PATH modifications

**Lessons Learned**:
- **Technical**: Prerequisites documentation is critical foundation; investing time upfront in comprehensive setup guide prevents downstream issues
- **Process**: Verification matrix format (table with commands) highly effective for operator validation
- **Best Practice**: Always check if tools exist before installation (`if ! command -v brew`)

---

#### Sprint 1: Trigger and Correlation

**Status**: Done

**Requirements**:
- GH-2: User triggers workflow with webhook notifications and basic retry policy
- GH-3: Apply best practice to obtain workflow run ID despite "accepted" response

**Delivered Artifacts**:
- `.github/workflows/dispatch-webhook.yml` - Reusable workflow with webhook notifications
- `scripts/notify-webhook.sh` - Webhook POST with `curl --retry 5 --retry-all-errors`
- `scripts/trigger-and-track.sh` - UUID-based correlation mechanism with polling
- `scripts/test-trigger-and-track.sh` - End-to-end validation

**Key Technical Decisions**:
1. **UUID Correlation Strategy**: Generate UUID client-side, pass as workflow input, embed in run-name for searchability
2. **Polling Implementation**: `gh run list --json` + jq filtering (timestamp, branch, status, run-name match)
3. **Retry Policy**: Non-blocking curl with `--max-time 5` to prevent workflow hanging on endpoint failures
4. **Numeric Workflow ID Resolution**: Call `/actions/workflows/:id` API before dispatch to avoid file-name 404 errors

**Assessment**: **Complete Success** ✓

Both GH-2 and GH-3 delivered fully functional implementations. The correlation mechanism reliably resolves run IDs within 2-5 seconds typical latency, validated through parallel execution testing.

**Key Challenges**:
1. **GitHub workflow_dispatch API limitation**: Returns HTTP 204 (no content) on success, no run_id provided
2. **Workflow ID ambiguity**: `gh workflow run workflow.yml` sometimes returns 404; numeric ID more reliable
3. **Race condition risk**: Multiple concurrent dispatches could match wrong run

**Solutions Applied**:
1. **Client-generated correlation token**: UUID passed as workflow input and embedded in run-name
2. **Timestamp-based filtering**: Record dispatch time, only consider runs created after
3. **Branch filtering**: Restrict search to current branch (`--ref`) to reduce false matches
4. **Compound matching**: Require status (queued/in_progress) AND run-name contains UUID AND created after timestamp

**Lessons Learned**:
- **Technical**:
  - Correlation via run-name is robust and UI-friendly (appears in Actions list)
  - Polling with timeout (60s default) and interval (3s) balances responsiveness vs API load
  - jq date filtering (`fromdateiso8601`) essential for timestamp comparisons
- **Process**:
  - Early feasibility analysis prevented wasted effort on alternative approaches
  - Negative testing (concurrent triggers) critical for validating correlation uniqueness
- **Architecture**:
  - Webhook integration point (URL parameter) provides flexibility for different notification backends
  - JSON-only output mode (`--json-only`) enables script composition

---

#### Sprint 2: Real-time Log Streaming

**Status**: Failed

**Requirements** (GH-4):
- Client requires real-time access to workflow logs during run
- Workflow emits logs every few seconds during long execution
- Use correlation_id or run_id for log access
- Support concurrent consumers via repository (file-based for parallel access)

**Delivered Artifacts**:
- `scripts/stream-run-logs.sh` - Stub script redirecting to Sprint 3 solution

**Assessment**: **Failed - GitHub API Limitation** ✗

Sprint 2 failed not due to implementation issues but fundamental GitHub platform limitation: **no streaming API exists for in-progress workflow logs**.

**Root Cause Analysis**:

Research during design phase revealed:
1. **GitHub Actions Log API**: `/repos/:owner/:repo/actions/runs/:run_id/logs` only available AFTER run completion
2. **No Streaming Endpoints**: GitHub does not provide SSE, WebSocket, or streaming APIs for live logs
3. **GitHub Web UI Behavior**: Browser interface uses polling (not streaming) to fetch log chunks
4. **Webhook Events**: `workflow_job` event fires on status changes but does not include log content

**Alternative Approaches Considered**:
- **Polling Job Logs**: Individual job logs also unavailable during execution
- **Step-level Polling**: No API endpoint for step-level log access during run
- **Webhook Progress Tracking**: Can detect job/step completion but cannot retrieve log content until run completes

**Impact Assessment**:
- Real-time log monitoring impossible via GitHub API
- Workaround: Sprint 3 pivoted to post-run log retrieval (achievable)
- Operator impact: Cannot debug long-running workflows in real-time

**Lessons Learned**:
- **Technical**: Always validate API capabilities during design phase before construction
- **Process**: Early failure (during design) prevented wasted implementation effort
- **Product Management**: Clear distinction between "not implemented" vs "impossible given platform constraints"
- **Documentation**: Explicit failure documentation with root cause prevents future re-attempts

**Recommendation**: Mark GH-4 as "Rejected - Platform Limitation" in backlog. Consider alternative: webhook-based progress notifications (status only, no logs).

---

#### Sprint 3: Post-run Log Retrieval

**Status**: Done

**Requirements** (GH-5):
- Reliable access to workflow logs after run completion
- Use correlation token or run ID for log retrieval
- Reuse metadata repository from Sprint 2 (file-based storage)
- Support concurrent consumers
- Produce structured output (combined log + metadata JSON)

**Delivered Artifacts**:
- `scripts/fetch-run-logs.sh` - Post-run log download, extraction, aggregation (280 lines)
- `scripts/lib/run-utils.sh` - Shared metadata loading utilities (95 lines)
- Updated `scripts/test-trigger-and-track.sh` - End-to-end validation with log fetch

**Key Technical Decisions**:
1. **Download Official Archive**: Use `/actions/runs/:run_id/logs` to download ZIP archive
2. **Structured Storage**: Extract to `runs/<correlation>/logs/<job_name>/step.log`
3. **Aggregation**: Produce `combined.log` with chronological job/step concatenation
4. **Metadata Output**: Generate `logs.json` with timestamps, conclusions, artifact paths
5. **Completion Validation**: Check run status before download (fail fast if still in progress)

**Assessment**: **Complete Success** ✓

Sprint 3 delivered all requirements and successfully addressed Sprint 2 failure by pivoting to post-run access pattern.

**Key Challenges**:
1. **Log Archive Format**: GitHub provides single ZIP containing all job logs; requires extraction logic
2. **Job/Step Organization**: Archive contains nested structure (`<job_id>/<step_number>_<step_name>.txt`)
3. **Timing Dependencies**: Logs may not be immediately available after run completion (retention policy timing)
4. **Error Handling**: HTTP 410 (Gone) for expired logs, HTTP 404 for invalid run IDs

**Solutions Applied**:
1. **Archive Extraction**: Use `unzip -o` to extract to temporary location, reorganize into semantic structure
2. **Job Name Resolution**: Parse job names from GitHub API (`gh run view --json jobs`), map to archive paths
3. **Retry Logic**: Brief wait after completion detection before download attempt
4. **Graceful Degradation**: Clear error messages for retention/permission issues with HTTP status codes

**Integration with Sprint 1**:
- Reuses `--store-dir` metadata from `trigger-and-track.sh`
- Accepts `--runs-dir` + `--correlation-id` for seamless integration
- Shared utilities (`run-utils.sh`) ensure consistent metadata handling

**Lessons Learned**:
- **Technical**:
  - GitHub log archives well-structured and reliable once available
  - Combined log format highly useful for grep/analysis operations
  - JSON metadata enables programmatic access to structured log information
- **Architecture**:
  - Separation of concerns: trigger (Sprint 1) vs retrieve (Sprint 3) with shared metadata contract
  - Per-correlation subdirectories prevent concurrent access collisions
  - Shared library pattern (`lib/run-utils.sh`) reduces duplication
- **Process**:
  - Pivoting from failed requirement (Sprint 2) to achievable alternative (Sprint 3) maintained project momentum
  - End-to-end testing (trigger → wait → fetch) validates full workflow

---

#### Sprint 4: Timing Benchmarks

**Status**: Done

**Requirements**:
- GH-3.1: Measure run_id retrieval timing across 10-20 jobs, compute mean
- GH-5.1: Measure log retrieval timing across 10-20 jobs, compute mean

**Delivered Artifacts**:
- `scripts/benchmark-correlation.sh` - Correlation performance testing (342 lines)
- `scripts/benchmark-log-retrieval.sh` - Log retrieval performance testing (385 lines)
- `tests/run-correlation-benchmark.sh` - Wrapper with defaults
- `tests/run-log-retrieval-benchmark.sh` - Wrapper with defaults
- `tests/README.md` - Testing documentation

**Key Technical Decisions**:
1. **Non-invasive Measurement**: Wrap existing scripts without modification, measure externally
2. **Millisecond Precision**: Use `date +%s%3N` with fallback to second precision
3. **Statistical Analysis**: Compute mean, min, max, median using Python
4. **Dual Output**: Human-readable table (stderr) + machine-readable JSON (file)
5. **Error Handling**: Continue on failures, report separately in final output

**Assessment**: **Complete Success** ✓

Both GH-3.1 and GH-5.1 delivered functional benchmarking tools validated via shellcheck. Manual execution on real GitHub infrastructure required for timing data collection.

**Key Challenges**:
1. **Cross-platform Timing**: macOS `date +%s%3N` outputs literal "%3N" instead of milliseconds
2. **JSON Parsing Errors**: Mixing stderr log messages with stdout JSON broke jq parsing
3. **Test Infrastructure Organization**: Initial path confusion between `scripts/` and `tests/` directories
4. **Rate Limiting Risk**: Rapid sequential triggers could hit GitHub API rate limits

**Solutions Applied**:
1. **Timestamp Validation**: Check if `date +%s%3N` output is numeric before use, fallback to seconds * 1000
2. **Clean JSON Output**: Remove `2>&1` stderr redirection when capturing JSON, preserve clean stdout
3. **Directory Structure**: Clear separation: implementation in `scripts/`, test wrappers in `tests/`, outputs gitignored
4. **Throttling**: Add 5-second delay between correlation tests, 10-second for log retrieval tests

**Bug Fixes During Development**:
- **macOS Date Arithmetic Error**: Fixed `get_timestamp_ms()` to validate numeric output (commit 7f5daa9)
- **jq Parse Error**: Removed stderr capture from JSON output commands (commit 0913961)
- **Documentation Paths**: Corrected script/output directory references (commit ce06a60)

**Test Infrastructure Design**:
- Wrapper scripts in `tests/` provide operator-friendly defaults
- Environment variable validation (`WEBHOOK_URL` required) prevents silent failures
- `.gitignore` patterns exclude test outputs (`.json`, `.log` files in tests/)
- README documents usage patterns and expected outputs

**Lessons Learned**:
- **Technical**:
  - Cross-platform compatibility requires explicit validation, not just command existence checks
  - JSON output hygiene critical: stderr contamination breaks parsing
  - Python for statistics more reliable than shell arithmetic (floating point, edge cases)
- **Testing**:
  - Benchmark scripts are themselves testable via shellcheck
  - Wrapper scripts reduce operator friction (sensible defaults, clear error messages)
  - Separation of concerns: core scripts implement features, benchmark scripts measure them
- **Process**:
  - Bug discovery during actual execution (not design) inevitable
  - Quick iteration cycle (execute → fix → validate) effective for cross-platform issues
  - Documentation paths must match actual file locations (obvious but error-prone)

---

### 1.2 Overall Project Assessment

**Delivered Value**:

The project successfully delivered a complete workflow automation toolkit:

1. **Workflow Triggering** (Sprint 1): Reliable dispatch mechanism with webhook notifications
2. **Correlation Mechanism** (Sprint 1): UUID-based run ID resolution, parallel-safe, 2-5 second typical latency
3. **Post-run Log Retrieval** (Sprint 3): Download, extraction, aggregation with structured metadata
4. **Performance Benchmarking** (Sprint 4): Tools to measure correlation and log retrieval timing
5. **Prerequisites Documentation** (Sprint 0): Complete operator setup guide

**Functional Coverage**:
- ✓ Trigger workflows programmatically with custom inputs
- ✓ Correlate dispatch calls to GitHub run IDs reliably
- ✓ Retrieve completed workflow logs with aggregation
- ✓ Measure performance characteristics of automation operations
- ✗ Real-time log streaming (impossible given GitHub API constraints)

**Technical Success**:

**Quality Indicators**:
- All shell scripts pass `shellcheck` validation (zero warnings)
- All workflows pass `actionlint` validation
- Cross-platform compatibility (macOS and Linux)
- Comprehensive error handling with actionable error messages
- JSON output formats for programmatic consumption

**Robustness**:
- Retry policies prevent transient failures (curl retries, webhook timeouts)
- Timeout mechanisms prevent infinite waits (60s polling default)
- Graceful degradation for unavailable resources (expired logs → clear error)
- Concurrent execution support (timestamp filtering, per-correlation subdirectories)

**Architecture Quality**:
- Modular design: independent scripts with clear responsibilities
- Shared utilities (`lib/run-utils.sh`) reduce duplication
- Composable: scripts emit JSON for chaining (`trigger-and-track.sh` → `fetch-run-logs.sh`)
- Configuration flexibility: CLI flags, environment variables, stdin JSON input

**Known Limitations**:

1. **Real-time Log Streaming** (Sprint 2 failure):
   - **Limitation**: GitHub API does not provide streaming or in-progress log access
   - **Impact**: Cannot debug long-running workflows in real-time
   - **Workaround**: Post-run log retrieval (Sprint 3) provides full logs after completion
   - **Status**: Fundamental platform constraint, not addressable via implementation

2. **Polling-Based Correlation**:
   - **Limitation**: No push-based notification when workflow starts (must poll `gh run list`)
   - **Impact**: 2-5 second latency to resolve run ID (acceptable but not instant)
   - **Alternative**: GitHub webhook events (`workflow_run`) could provide push notifications (not implemented)

3. **Log Retention**:
   - **Limitation**: GitHub expires logs after 90 days (public repos) or 400 days (private with GitHub Enterprise)
   - **Impact**: `fetch-run-logs.sh` returns HTTP 410 for expired runs
   - **Mitigation**: Clear error messages guide operators to retention policies

4. **Rate Limiting**:
   - **Limitation**: GitHub API rate limits (5,000 requests/hour authenticated)
   - **Impact**: High-frequency polling could hit limits (benchmark scripts add throttling)
   - **Mitigation**: Configurable polling intervals, exponential backoff (not implemented but documented)

5. **Workflow Dispatch API**:
   - **Limitation**: No run ID returned in dispatch response (HTTP 204 no content)
   - **Impact**: Correlation mechanism complexity (polling required)
   - **Status**: Platform design, correlation approach addresses it

**Reusability**:

Components work together seamlessly:

**Integration Pattern 1: Trigger → Track → Fetch Logs**
```bash
# Sprint 1: Trigger and correlate
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow .github/workflows/long-run-logger.yml \
  --store-dir runs \
  --json-only)

correlation_id=$(echo "$result" | jq -r '.correlation_id')
run_id=$(echo "$result" | jq -r '.run_id')

# Wait for completion
gh run watch "$run_id" --exit-status

# Sprint 3: Fetch logs
scripts/fetch-run-logs.sh \
  --runs-dir runs \
  --correlation-id "$correlation_id"
```

**Integration Pattern 2: Benchmark Workflows**
```bash
# Sprint 4: Automated testing
scripts/benchmark-correlation.sh --runs 10 --output correlation-results.json
scripts/benchmark-log-retrieval.sh --runs 10 --output log-results.json
```

**Shared Metadata Contract**:
- Sprint 1 stores: `runs/<uuid>/metadata.json` (run_id, correlation_id, timestamps)
- Sprint 3 reads: Same metadata, writes logs to `runs/<uuid>/logs/`
- Sprint 4 uses: Both Sprint 1 and Sprint 3 scripts via JSON interfaces

**Reuse Across Workflows**:
- All scripts accept workflow file path parameter (not hardcoded)
- Webhook URL externalized (environment variable or CLI flag)
- Branch/ref filtering enables multi-branch workflows
- Store directory configurable for parallel test isolation

---

### 1.3 Key Lessons Learned

**Technical Lessons**:

1. **API-First Feasibility Analysis**:
   - **Lesson**: Always validate GitHub API capabilities during design phase before construction
   - **Evidence**: Sprint 2 failed early (design phase) preventing wasted implementation effort
   - **Application**: Sprint 5 includes comprehensive API capability enumeration (Objective 3)

2. **Correlation Strategy**:
   - **Lesson**: Client-generated correlation tokens (UUIDs) more reliable than timestamp-only or branch-only matching
   - **Evidence**: Parallel execution testing validated uniqueness under concurrent triggers
   - **Best Practice**: Embed correlation ID in run-name (UI visibility) AND workflow inputs (API access)

3. **Cross-Platform Compatibility**:
   - **Lesson**: Command existence checks insufficient; output format validation required
   - **Evidence**: macOS `date +%s%3N` returns literal string, not milliseconds
   - **Solution**: Regex validation of command output before arithmetic operations

4. **JSON Output Hygiene**:
   - **Lesson**: Mixing stderr and stdout breaks JSON parsability
   - **Evidence**: `2>&1` redirection caused jq parse errors in benchmark scripts
   - **Best Practice**: Separate channels: JSON to stdout, logs to stderr, use `--json-only` flags

5. **Polling vs Streaming**:
   - **Lesson**: Polling acceptable for workflow automation use cases (seconds latency tolerable)
   - **Evidence**: 2-5 second correlation latency meets operational needs
   - **Constraint**: Real-time streaming desirable but unavailable (GitHub platform limitation)

6. **Error Handling Specificity**:
   - **Lesson**: HTTP status codes enable specific error messages and recovery guidance
   - **Evidence**: HTTP 410 (logs expired) vs 404 (run not found) provide different operator actions
   - **Best Practice**: Map API errors to actionable troubleshooting steps in error output

7. **Modular Architecture**:
   - **Lesson**: Small, focused scripts with JSON interfaces compose better than monoliths
   - **Evidence**: Benchmark scripts reuse trigger and fetch scripts without modification
   - **Pattern**: Each script does one thing well, emits structured output, accepts structured input

**Process Lessons (Agentic Programming)**:

1. **Design Phase Validation**:
   - **Lesson**: Requiring feasibility analysis in design prevents late-stage failures
   - **Evidence**: Sprint 2 failure caught early, Sprint 3 designed as achievable alternative
   - **Governance Rule**: Design must validate API capabilities before Product Owner approval

2. **Explicit Status State Machine**:
   - **Lesson**: Clear sprint lifecycle (Planned → Progress → Designed → Implemented → Done) maintains alignment
   - **Evidence**: Status tokens owned by Product Owner prevent Implementor drift
   - **Practice**: Regular status updates create checkpoints for review and course correction

3. **Documentation-Driven Development**:
   - **Lesson**: Prerequisites document (Sprint 0) critical foundation for subsequent work
   - **Evidence**: Zero environment setup issues during Sprints 1-4
   - **Pattern**: Invest in operator-facing documentation upfront

4. **Test-Driven Validation**:
   - **Lesson**: Test scripts (`test-trigger-and-track.sh`) serve as executable specifications
   - **Evidence**: End-to-end test caught integration issues not visible in unit-level validation
   - **Practice**: Always include test script in deliverables, document expected behavior

5. **Iterative Refinement**:
   - **Lesson**: Bug fixes during execution inevitable; quick iteration cycle effective
   - **Evidence**: Three bug fix commits during Sprint 4 (timestamp, JSON parsing, documentation)
   - **Pattern**: Execute → identify issues → fix → validate → commit in tight loops

6. **Negative Testing**:
   - **Lesson**: Testing failure modes as important as happy path validation
   - **Evidence**: Concurrent trigger testing validated correlation uniqueness, expired log testing validated error messages
   - **Practice**: Include negative test scenarios in sprint testing guidelines

7. **Semantic Commit Messages**:
   - **Lesson**: Structured commit history (`feat:`, `fix:`, `docs:`) enables clear project narrative
   - **Evidence**: Construction chat summaries easily reconstructed from commit history
   - **Governance**: Git rules enforce semantic commit conventions consistently

**Recommendations for Future Sprints**:

1. **For GH-6/GH-7 (Workflow Cancellation)**:
   - Leverage `gh run cancel <run_id>` CLI command (available, unused)
   - Reuse correlation mechanism from Sprint 1 (run_id resolution)
   - Design consideration: Cancel requested vs in-progress may have different behaviors

2. **For GH-8/GH-9 (Workflow Scheduling)**:
   - GitHub API does not provide cron-style scheduling for workflow_dispatch
   - Alternative: Use GitHub Actions scheduled workflows (`on: schedule: cron`)
   - Scheduling dispatch events requires external scheduler (cron, systemd timers, cloud scheduler)

3. **Webhook Events as Polling Alternative**:
   - Evaluate `workflow_run` and `workflow_job` webhook events (Objective 3)
   - Could eliminate polling latency (push-based notification)
   - Requires publicly accessible webhook receiver (complexity vs benefit trade-off)

4. **GraphQL API Exploration**:
   - REST API sufficient for current needs but GraphQL may offer efficiency gains
   - Investigate batch queries for multiple run status checks
   - Evaluate if GraphQL provides capabilities not available in REST (Objective 3)

5. **Library-Based Implementation**:
   - Shell scripts effective for current scope but may hit maintainability limits
   - Consider Java/Go/Python libraries for complex workflow orchestration (Objective 4)
   - Migration path: Keep shell scripts for CLI tools, use libraries for services/integrations

6. **Performance Optimization**:
   - Current polling interval (3s) and timeout (60s) are conservative defaults
   - Benchmark data from Sprint 4 could inform tuning recommendations
   - Consider exponential backoff for long-running workflows

---

## Objective 2: Enumerate `gh` CLI Capabilities

Status: Accepted

### Goal

Document GitHub CLI capabilities used in our implementation and identify additional features potentially useful for workflow verification, testing, or future requirements.

### Research Approach

**Primary Sources**:
- `gh --help` and subcommand help (local inspection)
- GitHub CLI Manual: https://cli.github.com/manual/
- Implemented scripts: grep for `gh` command usage patterns
- GitHub CLI source code (reference): https://github.com/cli/cli

**Analysis Method**:

1. **Current Usage Inventory**: Analyze all scripts to extract `gh` commands used:
   ```bash
   grep -rh "gh " scripts/ .github/workflows/ | grep -v "^#" | sort -u
   ```

   Document each command with:
   - Command pattern (e.g., `gh workflow run`)
   - Purpose in our implementation
   - Key flags/options used
   - File location (e.g., `scripts/trigger-and-track.sh:45`)

2. **Capability Categories**: Organize by functional area:
   - **Workflow Management**: `gh workflow`, dispatch, listing, viewing
   - **Run Management**: `gh run`, listing, watching, viewing, canceling
   - **API Access**: `gh api`, direct REST endpoint access
   - **Authentication**: `gh auth`, status checking
   - **Repository**: `gh repo`, metadata queries

3. **Unexplored Capabilities**: For each category, identify `gh` features NOT used:
   - Review `gh <category> --help` output
   - Cross-reference GitHub CLI manual
   - Note features potentially useful for:
     - Future backlog items (GH-6 through GH-9: cancellation, scheduling)
     - Enhanced testing/verification
     - Monitoring and observability

4. **Limitations Discovered**: Document where `gh` CLI fell short:
   - What required `gh api` direct REST calls
   - What required external tools (curl, jq)
   - What cannot be achieved via CLI (e.g., real-time log streaming)

### Deliverable Structure

```markdown
## 2. GitHub CLI Capabilities

### 2.1 Current Usage Summary

| Command | Purpose | Location | Key Flags |
|---------|---------|----------|-----------|
| `gh workflow run` | Trigger workflow | `trigger-and-track.sh:67` | `--raw-field`, `--ref` |
| `gh run list` | Poll for run ID | `trigger-and-track.sh:120` | `--workflow`, `--json`, `--limit` |
| ... | ... | ... | ... |

### 2.2 Capabilities by Category

#### Workflow Management (`gh workflow`)
- **Used**: `gh workflow run` - dispatch with inputs
- **Available but unused**:
  - `gh workflow view` - inspect workflow definition
  - `gh workflow enable/disable` - workflow state management
  - `gh workflow list` - enumerate workflows
- **Potential use cases**: [for future backlog items]

[Repeat for: Run Management, API Access, etc.]

### 2.3 Limitations and Gaps

- **No streaming API**: `gh run view --log` only works after completion
- **Polling required**: No webhook/event mechanism for run state changes
- **JSON filtering**: Complex queries require `jq` post-processing
- **Workflow ID resolution**: File-based dispatch can return 404, numeric ID more reliable

### 2.4 Recommendations

- Commands to explore for GH-6/GH-7 (cancellation): `gh run cancel`
- Commands to explore for GH-8 (scheduling): Not available in CLI, API only
- Enhanced monitoring: `gh run list --status` with custom filters
```

### Information Sources

- Local: `gh <command> --help` output for all subcommands
- Online: https://cli.github.com/manual/ (authoritative reference)
- Source: https://github.com/cli/cli (for understanding implementation limits)

### Success Criteria

- Complete inventory of `gh` commands used in our scripts
- Systematic review of available `gh` capabilities by category
- Clear identification of unexplored features with potential use cases
- Documented limitations requiring workarounds or alternative approaches

### Research Findings

## 2. GitHub CLI Capabilities

### 2.1 Current Usage Summary

| Command | Purpose | Location | Key Flags/Options |
|---------|---------|----------|-------------------|
| `gh workflow run <workflow>` | Trigger workflow dispatch | `trigger-and-track.sh` | `--raw-field` (inputs), `--ref` (branch) |
| `gh run list` | Poll for matching workflow run | `trigger-and-track.sh` | `--workflow`, `--limit 50`, `--status` (queued/in_progress/completed), `--json` (fields) |
| `gh run watch <run_id>` | Wait for workflow completion | `fetch-run-logs.sh`, `test-trigger-and-track.sh` | `--exit-status` (fail if run fails) |
| `gh run view <run_id>` | Get run metadata | `trigger-and-track.sh` | `--json` (name, conclusion, headBranch, status) |
| `gh api <endpoint>` | Direct REST API access | Multiple scripts | `--jq` (JSON extraction), `--paginate` (multi-page results) |
| `gh api repos/:owner/:repo/actions/workflows/:id` | Resolve workflow numeric ID | `trigger-and-track.sh` | `--jq '.id'` |
| `gh api repos/:owner/:repo/actions/runs/:run_id` | Get detailed run information | `fetch-run-logs.sh` | Output to file for parsing |
| `gh api repos/:owner/:repo/actions/runs/:run_id/jobs` | Get job details for run | `fetch-run-logs.sh` | `--paginate`, `--jq '.jobs[]'` |
| `gh api repos/:owner/:repo/actions/runs/:run_id/logs` | Download log archive ZIP | `fetch-run-logs.sh` | Binary output redirected to file |
| `gh repo view` | Get current repository name | `trigger-and-track.sh`, `fetch-run-logs.sh` | `--json nameWithOwner`, `-q .nameWithOwner` |
| `gh auth status` | Check authentication | `sprint_0_prerequisites.md` (docs) | Validate gh CLI is authenticated |

**Usage Pattern Analysis**:
- **Workflow Triggering**: Single `gh workflow run` call with inputs via `--raw-field`
- **Correlation**: Repeated `gh run list` polling with JSON output and jq filtering
- **Metadata Retrieval**: `gh run view` for run status, `gh api` for detailed job information
- **Log Download**: `gh api` direct endpoint access (no high-level `gh run logs` command exists)
- **Repository Context**: `gh repo view` to resolve owner/repo names from current directory

### 2.2 Capabilities by Category

#### Workflow Management (`gh workflow`)

**Used**:
- `gh workflow run <workflow>` - Triggers workflow_dispatch event with inputs
  - Supports `--raw-field key=value` for string inputs
  - Supports `--ref <branch>` to target specific branch
  - Returns HTTP 204 (no content) on success, no run_id in response

**Available but Unused**:
- `gh workflow list` - Enumerate all workflows in repository
  - Could be used to validate workflow existence before triggering
  - Provides workflow ID, name, state (active/disabled), path
- `gh workflow view <workflow>` - Display workflow details
  - Shows workflow YAML content, description, runs
  - Could validate inputs/outputs before dispatch
- `gh workflow enable/disable <workflow>` - Control workflow state
  - Programmatically enable/disable workflows
  - Useful for maintenance windows or feature flags

**Potential Use Cases**:
- `gh workflow list` → Pre-flight validation in trigger scripts (check workflow exists)
- `gh workflow view` → Dynamic input validation (parse expected inputs from workflow definition)
- `gh workflow enable/disable` → Automated workflow lifecycle management (future backlog item)

**Limitations**:
- No command to get workflow ID by name directly (requires `gh api` call to `/actions/workflows/:file`)
- File-based workflow reference can return 404; numeric ID more reliable (workaround in `trigger-and-track.sh`)

---

#### Run Management (`gh run`)

**Used**:
- `gh run list` - Query recent workflow runs
  - Essential for correlation: filter by workflow, status, creation time
  - JSON output with custom fields (`--json databaseId,name,headBranch,createdAt,status`)
  - Limit controls (`--limit 50`) prevent excessive API calls
  - Status filtering (`--status queued|in_progress|completed`)
- `gh run watch <run_id>` - Monitor run progress until completion
  - Blocks until run completes (success/failure/cancelled)
  - `--exit-status` flag exits non-zero if run fails
  - Essential for synchronous workflow execution patterns
- `gh run view <run_id>` - Get single run details
  - JSON output for metadata extraction
  - Used to confirm run status before log download

**Available but Unused**:
- `gh run cancel <run_id>` - Stop running workflow
  - **Critical for GH-6/GH-7 backlog items** (cancel requested/running workflows)
  - Takes run ID as argument (correlation mechanism provides this)
  - Returns immediately, cancellation asynchronous
- `gh run delete <run_id>` - Remove run from history
  - Cleanup utility for test runs
  - Could be used in benchmark scripts to reduce run clutter
- `gh run download <run_id>` - Download workflow artifacts
  - Downloads artifacts (not logs) from completed runs
  - Could complement log retrieval for complete run output
- `gh run rerun <run_id>` - Re-execute workflow run
  - Retry failed runs with same inputs
  - Useful for transient failure recovery

**Potential Use Cases**:
- `gh run cancel` → GH-6/GH-7 implementation (workflow cancellation)
- `gh run delete` → Test cleanup in benchmark scripts (remove test run history)
- `gh run download` → Enhanced log retrieval (artifacts + logs together)
- `gh run rerun` → Automated retry logic for failed critical workflows

**Limitations**:
- No `gh run logs <run_id>` command; must use `gh api` to download log archive
- `gh run view --log` does NOT work for in-progress runs (Sprint 2 failure root cause confirmed)
- No streaming log access even for completed runs (full archive only)

---

#### API Access (`gh api`)

**Used**:
- `gh api <endpoint>` - Direct REST API v3 access
  - Automatic authentication (uses `gh auth` credentials)
  - Placeholder substitution: `{owner}`, `{repo}`, `{branch}`
  - JSON querying with `--jq` for field extraction
  - Pagination support with `--paginate` for multi-page results
- Specific endpoints used:
  - `/repos/:owner/:repo/actions/workflows/:file` - Resolve workflow numeric ID
  - `/repos/:owner/:repo/actions/runs/:run_id` - Get run metadata
  - `/repos/:owner/:repo/actions/runs/:run_id/jobs` - List jobs for run
  - `/repos/:owner/:repo/actions/runs/:run_id/logs` - Download log archive (binary)

**Available but Unused**:
- **GraphQL API**: `gh api graphql` - GitHub API v4 access
  - More efficient for complex queries (single request, custom field selection)
  - Could batch multiple run status checks into single query
  - Supports real-time subscriptions (though GitHub Actions may not expose this)
- **API Features**:
  - `--method` - HTTP method override (GET, POST, PUT, DELETE, PATCH)
  - `-F/--field` - Typed parameters (auto-converts to JSON types)
  - `--input` - Pre-constructed JSON payloads
  - `-H/--header` - Custom headers for API previews
  - `--cache` - Response caching for repeated queries
  - `--paginate --slurp` - Wrap all pages into single JSON array

**Potential Use Cases**:
- GraphQL API → Batch status checks for multiple runs (efficiency improvement)
- `--cache` → Reduce API calls in benchmark scripts (cache workflow metadata)
- `--paginate --slurp` → Simplify pagination handling (single JSON output)
- `--method POST/DELETE` → Future API operations (create resources, cleanup)

**Limitations**:
- `gh api` is lower-level than specialized commands (requires endpoint knowledge)
- No automatic retry logic (unlike `curl --retry` in our scripts)
- Error handling requires manual HTTP status code checking

---

#### Repository (`gh repo`)

**Used**:
- `gh repo view` - Get current repository metadata
  - Resolves owner/repo names from current directory or GH_REPO env var
  - JSON output with `--json nameWithOwner` + `-q .nameWithOwner`
  - Essential for constructing API endpoints dynamically

**Available but Unused**:
- `gh repo view --web` - Open repository in browser
  - Quick navigation utility (not relevant for automation)
- `gh repo view --json <fields>` - Query extensive repository metadata
  - Available fields: description, language, forkCount, stargazerCount, createdAt, license, etc.
  - Could be used for repository validation or reporting
- Other `gh repo` subcommands:
  - `gh repo create` - Create new repository
  - `gh repo clone` - Clone repository
  - `gh repo fork` - Fork repository
  - `gh repo sync` - Sync fork with upstream
  - (Not relevant for workflow automation use cases)

**Potential Use Cases**:
- `gh repo view --json` → Repository validation (check if private, check permissions)
- Generally sufficient for our needs; no additional capabilities required

---

#### Authentication (`gh auth`)

**Used** (documentation only, not in scripts):
- `gh auth status` - Check authentication state
  - Documented in `sprint_0_prerequisites.md`
  - Validates gh CLI is authenticated before running scripts
  - Returns non-zero if not authenticated

**Available but Unused**:
- `gh auth login` - Authenticate gh CLI
  - Interactive or token-based authentication
  - Not needed in scripts (assumes operator pre-authenticated)
- `gh auth logout` - Remove authentication
- `gh auth refresh` - Refresh authentication tokens
- `gh auth token` - Print authentication token
  - Could be used to pass token to other tools (curl, git)

**Potential Use Cases**:
- `gh auth token` → Pass GitHub token to external tools or CI/CD systems
- `gh auth status` → Pre-flight check in scripts (fail early if not authenticated)

**Current Approach**: Assume operator has authenticated via `gh auth login` per Sprint 0 prerequisites

---

### 2.3 Limitations and Gaps

**1. No Real-time Log Streaming**:
- **Limitation**: `gh run view --log` only works after run completion
- **Impact**: Sprint 2 failure (GH-4 requirement impossible)
- **Root Cause**: GitHub API does not provide streaming endpoints; gh CLI cannot add this capability
- **Workaround**: Post-run log retrieval (Sprint 3) using `gh api` to download archive

**2. Polling Required for Correlation**:
- **Limitation**: No `gh run wait-for-dispatch` or similar command
- **Impact**: Must poll `gh run list` repeatedly to find newly created run
- **Latency**: 2-5 seconds typical (polling interval + API response time)
- **Alternative**: GitHub webhook events (`workflow_run`) provide push notifications (not used)

**3. JSON Filtering Complexity**:
- **Limitation**: `gh run list --json` returns full objects; filtering requires jq
- **Impact**: Scripts depend on external `jq` tool for field extraction and filtering
- **Example**: Filtering runs by creation timestamp requires `jq` with `fromdateiso8601`
- **No Built-in**: `gh run list` does not support `--created-after` or similar filters

**4. Workflow ID Resolution Ambiguity**:
- **Limitation**: `gh workflow run workflow.yml` sometimes returns 404 (file not found)
- **Root Cause**: Workflow must exist on ref being triggered; recent pushes may not be indexed
- **Workaround**: Resolve numeric workflow ID via `gh api` first, use ID instead of filename
- **Implemented**: `trigger-and-track.sh` performs this resolution automatically

**5. No Log Download Command**:
- **Limitation**: No high-level `gh run logs <run_id>` command
- **Impact**: Must use `gh api` with explicit endpoint (`/actions/runs/:run_id/logs`)
- **Workaround**: Direct API access returns binary ZIP, requires extraction logic
- **Comparison**: Other CLIs (e.g., `az pipelines`) provide logs as first-class command

**6. Artifact vs Log Distinction**:
- **Limitation**: `gh run download` downloads artifacts, not logs
- **Confusion**: Terminology unclear (logs vs artifacts are separate concepts)
- **Workaround**: Explicit use of `gh api` for logs, `gh run download` for artifacts

**7. Limited Run Filtering**:
- **Limitation**: `gh run list` filters by workflow, status, branch, but not by:
  - Creation time range (--created-after/--created-before)
  - Conclusion (success/failure/cancelled) independently of status
  - Run name patterns (requires jq post-processing)
- **Impact**: Must retrieve large result sets (--limit 50) and filter client-side

**8. No Batch Operations**:
- **Limitation**: No command to cancel/delete/rerun multiple runs at once
- **Impact**: Benchmark cleanup requires loop over run IDs
- **Alternative**: Direct API calls with scripting logic

---

### 2.4 Recommendations

**For GH-6/GH-7 (Workflow Cancellation)**:
- **Use**: `gh run cancel <run_id>`
- **Implementation**: Reuse correlation mechanism from Sprint 1 to resolve run_id
- **Consideration**: Cancellation is asynchronous; may need to poll for cancellation completion
- **Testing**: Verify behavior difference between "queued" vs "in_progress" cancellation

**For GH-8/GH-9 (Workflow Scheduling)**:
- **Not Available in CLI**: No `gh workflow schedule` or similar command
- **GitHub Actions Alternative**: Use `on: schedule: cron:` in workflow definition (static, not dispatch-based)
- **External Scheduler Required**: cron, systemd timers, cloud scheduler + `gh workflow run`
- **Recommendation**: Document that scheduling requires external orchestration

**Enhanced Monitoring**:
- **Use**: `gh run list --status failed --json conclusion` → identify failed runs for alerting
- **Use**: `gh run list --limit 100` + jq filtering → custom dashboards, metrics collection
- **Potential**: `gh run watch --interval` → custom polling intervals (check if supported)

**Performance Optimization**:
- **GraphQL Exploration**: Batch multiple run queries into single GraphQL request (Objective 3)
- **Caching**: Use `gh api --cache` for repeated metadata queries (workflow IDs, repo info)
- **Pagination**: Use `--paginate --slurp` to simplify multi-page result handling

**Error Handling Improvements**:
- **Pre-flight Checks**: Add `gh workflow list` validation before trigger attempts
- **Auth Validation**: Add `gh auth status` check at script startup
- **Workflow View**: Parse expected inputs from `gh workflow view` for validation

**Future Capabilities to Monitor**:
- `gh run logs` - If GitHub adds first-class log command (currently absent)
- `gh workflow schedule` - If GitHub adds dispatch scheduling (currently requires external scheduler)
- `gh run stream` - Real-time log streaming (unlikely given API limitation)

---

## Objective 3: Enumerate GitHub API

Status: Accepted

### Goal

Document GitHub REST/GraphQL API capabilities relevant to workflow automation, validate whether API can achieve our requirements (especially Sprint 2's failed real-time streaming), and identify unexplored endpoints.

### Research Approach

**Primary Sources**:
- GitHub REST API Documentation: https://docs.github.com/en/rest
- GitHub GraphQL API Documentation: https://docs.github.com/en/graphql
- Our implementation: `gh api` usage patterns
- GitHub Actions API Reference: https://docs.github.com/en/rest/actions

**Analysis Method**:

1. **Current API Usage Inventory**: Extract all `gh api` calls:
   ```bash
   grep -rh "gh api" scripts/ | grep -v "^#" | sort -u
   ```

   Document each endpoint:
   - REST path (e.g., `/repos/:owner/:repo/actions/runs/:run_id/logs`)
   - Purpose in our implementation
   - HTTP method (GET/POST/DELETE)
   - Authentication requirements
   - Response format and key fields used

2. **Actions API Coverage**: Systematically review GitHub Actions API endpoints:
   - **Workflows**: List, get, create dispatch event, enable/disable
   - **Workflow Runs**: List, get, re-run, cancel, delete, download logs, usage
   - **Workflow Jobs**: List, get, download logs
   - **Artifacts**: List, get, download, delete
   - **Secrets**: List, get, create/update, delete (org/repo level)
   - **Self-hosted Runners**: List, get, delete, registration tokens

3. **Sprint 2 Failure Root Cause Analysis**:
   - Research: Does GitHub provide any streaming/SSE/WebSocket API for live logs?
   - Review: GitHub Actions log streaming mechanism (web UI uses polling)
   - Conclusion: Document definitive API limitation
   - Alternative: Check if webhook events (`workflow_run`, `workflow_job`) provide progress updates

4. **GraphQL Capabilities**: Compare REST vs GraphQL for workflow operations:
   - Query workflow runs with custom field selection
   - Pagination efficiency
   - Batch queries
   - Real-time subscriptions (if available)

5. **Webhook Events**: Review GitHub webhook events relevant to workflows:
   - `workflow_run` - triggered on run completion/status change
   - `workflow_job` - triggered on job queued/started/completed
   - Payload contents and timing
   - Can these replace polling in our correlation mechanism?

6. **Rate Limiting and Best Practices**:
   - Document API rate limits (authenticated vs unauthenticated)
   - Our current usage patterns vs limits
   - Best practices for polling (exponential backoff, conditional requests)

### Deliverable Structure

```markdown
## 3. GitHub API Capabilities

### 3.1 Current API Usage

| Endpoint | Purpose | Method | Location | Response Fields Used |
|----------|---------|--------|----------|---------------------|
| `/repos/:owner/:repo/actions/workflows/:id` | Resolve workflow ID | GET | `trigger-and-track.sh:55` | `.id` |
| `/repos/:owner/:repo/actions/runs/:run_id/logs` | Download log archive | GET | `fetch-run-logs.sh:89` | Binary ZIP |
| ... | ... | ... | ... | ... |

### 3.2 GitHub Actions API Coverage

#### Workflow Runs Endpoints
- **Used**:
  - `GET /repos/:owner/:repo/actions/runs` - list runs (via `gh run list`)
  - `GET /repos/:owner/:repo/actions/runs/:run_id/logs` - download logs
- **Available but unused**:
  - `POST /repos/:owner/:repo/actions/runs/:run_id/rerun` - re-run failed jobs
  - `POST /repos/:owner/:repo/actions/runs/:run_id/cancel` - cancel run
  - `DELETE /repos/:owner/:repo/actions/runs/:run_id` - delete run record
  - `GET /repos/:owner/:repo/actions/runs/:run_id/timing` - billable time breakdown
- **Potential use cases**:
  - Cancel endpoints → GH-6, GH-7 backlog items
  - Timing endpoint → cost analysis, enhanced benchmarking

[Repeat for: Workflow Jobs, Artifacts, Secrets, Runners]

### 3.3 Sprint 2 Failure Analysis: Real-time Log Streaming

**Question**: Can GitHub API provide real-time/streaming access to in-progress workflow logs?

**Research Findings**:
- **REST API**: No streaming endpoints; `/logs` only available after completion
- **GraphQL API**: [check if subscriptions or streaming queries available]
- **Webhook Events**: `workflow_job` fires on status changes but does not include logs
- **GitHub Web UI**: Uses polling mechanism, not streaming
- **Conclusion**: [definitive statement on API capability/limitation]

**Implications**:
- Sprint 2 failure confirmed as GitHub platform limitation (not implementation issue)
- Alternative approaches: [webhook-based progress tracking, polling with job-level granularity]

### 3.4 Webhook Events for Workflow Automation

| Event | Trigger Conditions | Payload Includes | Use Case |
|-------|-------------------|------------------|----------|
| `workflow_run` | Run queued, in_progress, completed | Status, conclusion, run ID, workflow ID | Alternative to polling for completion |
| `workflow_job` | Job queued, in_progress, completed | Status, conclusion, job ID, step names | Finer-grained progress tracking |

**Analysis**: Can webhooks replace our polling-based correlation?
- **Pros**: Push-based, no polling overhead, immediate notification
- **Cons**: Requires publicly accessible endpoint, complexity of webhook receiver, security considerations
- **Recommendation**: [for future consideration]

### 3.5 GraphQL API Comparison

[Compare REST vs GraphQL for workflow operations]
- Field selection efficiency
- Pagination performance
- Real-time capabilities (subscriptions)
- Use case recommendations

### 3.6 Rate Limiting and Best Practices

- **Authenticated Rate Limits**: 5,000 requests/hour
- **Our Usage Pattern**: [estimate based on current scripts]
- **Headroom**: [assessment of how close we are to limits]
- **Best Practices Applied**: [conditional requests, backoff strategy]
- **Recommendations**: [for high-frequency scenarios]

### 3.7 Unexplored Capabilities

- API endpoints not used but potentially valuable
- Features unavailable in `gh` CLI but accessible via API
- Advanced patterns (caching, conditional requests, pagination)
```

### Information Sources

- GitHub REST API Docs: https://docs.github.com/en/rest
- GitHub GraphQL API Docs: https://docs.github.com/en/graphql
- GitHub Actions API: https://docs.github.com/en/rest/actions
- GitHub Webhook Events: https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads
- API Rate Limiting: https://docs.github.com/en/rest/overview/rate-limits-for-the-rest-api

### Success Criteria

- Complete inventory of GitHub API endpoints used
- Systematic review of Actions API with gap analysis
- Definitive answer on Sprint 2 failure (real-time streaming feasibility)
- Webhook event capabilities documented
- Rate limiting analysis with recommendations
- Clear identification of unexplored API capabilities

---

## Objective 4: Enumerate Major GitHub Libraries

Status: Accepted

### Goal

Survey major GitHub API libraries for Java, Go, and Python; evaluate how they address workflow triggering, correlation, and log retrieval; compare library approaches to our shell-based implementation.

### Research Approach

**Library Candidates**:

**Java**:
- hub4j/github-api (recommended in Sprint 0)
- OkHttp (HTTP client, recommended in Sprint 0)
- Alternatives: kohsuke/github-api, square/retrofit + GitHub API

**Go**:
- google/go-github (recommended in Sprint 0)
- hashicorp/go-retryablehttp (retry logic, recommended in Sprint 0)
- Alternatives: shurcooL/githubv4 (GraphQL), go-resty/resty

**Python**:
- PyGithub (pygithub/PyGithub)
- github3.py (sigmavirus24/github3.py)
- Alternatives: httpx + direct API calls, gidgethub

**Analysis Method**:

1. **Per-Library Assessment**: For each library, document:

   a. **Project Metadata**:
   - Repository URL and GitHub stars/activity
   - Last release date and maintenance status
   - License (MIT, Apache 2.0, etc.)
   - Documentation quality (official docs, examples)
   - Community size (contributors, issues, PRs)

   b. **Feature Coverage**:
   - Workflow management (list, trigger, get details)
   - Run management (list, watch/poll, cancel)
   - Log access (download, stream if available)
   - Webhook handling (if provided)
   - Authentication methods (PAT, OAuth, GitHub App)
   - Rate limiting handling (built-in, manual)

   c. **Workflow Correlation Support**:
   - How to trigger workflow with inputs
   - How to correlate dispatch to run ID (polling, filtering, custom headers)
   - Pagination support for run listing
   - Filtering capabilities (by status, branch, etc.)

   d. **Log Retrieval Support**:
   - Download log archives (our Sprint 3 approach)
   - Stream logs (if available, addresses Sprint 2)
   - Job-level log access
   - Step-level log access

   e. **Code Examples**: Extract or write minimal examples:
   ```java
   // hub4j/github-api: Trigger workflow and correlate
   GitHub github = new GitHubBuilder().withOAuthToken(token).build();
   GHRepository repo = github.getRepository("owner/repo");
   GHWorkflow workflow = repo.getWorkflow("workflow.yml");
   // ... dispatch and correlation logic
   ```

2. **Comparative Analysis**: Create comparison matrix across libraries:
   - Feature completeness (vs our requirements)
   - Ease of use (API design, documentation)
   - Performance characteristics (HTTP client, connection pooling)
   - Error handling and retry logic
   - Dependency footprint

3. **Shell vs Library Trade-offs**:
   - **Shell (our approach)**:
     - Pros: Simple, no compilation, easy debugging, universal (bash + gh + jq)
     - Cons: String parsing, limited error handling, no type safety
   - **Libraries (Java/Go/Python)**:
     - Pros: Type safety, rich error handling, reusable components, testability
     - Cons: Compilation step (Java/Go), dependency management, learning curve

4. **Use Case Recommendations**: For each language/library:
   - When to use over shell scripting
   - Best fit scenarios (CI/CD integration, production services, complex workflows)
   - Migration path from our shell implementation

### Deliverable Structure

```markdown
## 4. Major GitHub Libraries

### 4.1 Library Landscape Overview

Summary of ecosystem maturity, dominant libraries per language, general recommendations.

### 4.2 Java Libraries

#### hub4j/github-api
- **Repository**: https://github.com/hub4j/github-api
- **Maturity**: [stars, last release, maintenance status]
- **Documentation**: [quality assessment]
- **Feature Coverage**:
  - Workflow triggering: ✓/✗ with notes
  - Run correlation: ✓/✗ with approach description
  - Log retrieval: ✓/✗ with API details
  - Real-time streaming: ✓/✗
- **Code Example**:
  ```java
  // Trigger workflow and correlate to run ID
  [minimal working example]
  ```
- **Assessment**: [strengths, weaknesses, use case fit]

#### OkHttp (+ direct API)
[Similar structure]

#### Alternatives
[Brief assessment of other Java options]

### 4.3 Go Libraries

#### google/go-github
[Same structure as Java section]

#### hashicorp/go-retryablehttp
[Same structure]

#### Alternatives (shurcooL/githubv4 for GraphQL)
[Brief assessment]

### 4.4 Python Libraries

#### PyGithub
[Same structure as Java section]

#### github3.py
[Same structure]

#### Alternatives
[Brief assessment]

### 4.5 Comparative Analysis

| Feature | Shell (ours) | Java (hub4j) | Go (google/go-github) | Python (PyGithub) |
|---------|--------------|--------------|----------------------|-------------------|
| Workflow trigger | ✓ (gh CLI) | ✓ (API) | ✓ (API) | ✓ (API) |
| Run correlation | ✓ (UUID + poll) | [approach] | [approach] | [approach] |
| Log download | ✓ (zip) | [support level] | [support level] | [support level] |
| Real-time stream | ✗ | [support level] | [support level] | [support level] |
| Error handling | Basic | Rich | Rich | Rich |
| Type safety | ✗ | ✓ | ✓ | ~(dynamic) |
| Setup complexity | Low | Medium | Medium | Low |
| Debugging | Easy | Medium | Medium | Easy |

### 4.6 Shell vs. Library Trade-offs

**When to use Shell (our approach)**:
- Rapid prototyping and experimentation
- CI/CD pipeline steps (already in shell context)
- Operator-facing tools with minimal dependencies
- Simple workflow automation

**When to use Libraries (Java/Go/Python)**:
- Production services requiring robustness
- Complex multi-step orchestration
- Integration with existing applications
- Need for type safety and rich error handling
- High-frequency operations requiring connection pooling

### 4.7 Use Case Recommendations

**For GH-6/GH-7 (Workflow Cancellation)**:
- Shell: [recommendation and rationale]
- Library: [recommendation and rationale]

**For GH-8/GH-9 (Scheduling)**:
- Shell: [recommendation and rationale]
- Library: [recommendation and rationale]

**For Production Workflow Automation**:
- [Language/library recommendation based on context]

### 4.8 Migration Considerations

If migrating from shell to library-based implementation:
- Reusable patterns from our scripts
- Testing strategy differences
- Deployment and dependency management
- Performance implications
```

### Information Sources

**Java**:
- hub4j/github-api: https://github.com/hub4j/github-api
- Documentation: http://github-api.kohsuke.org/
- OkHttp: https://square.github.io/okhttp/

**Go**:
- google/go-github: https://github.com/google/go-github
- Documentation: https://pkg.go.dev/github.com/google/go-github/v57/github
- go-retryablehttp: https://github.com/hashicorp/go-retryablehttp

**Python**:
- PyGithub: https://github.com/PyGithub/PyGithub
- Documentation: https://pygithub.readthedocs.io/
- github3.py: https://github.com/sigmavirus24/github3.py

**General**:
- GitHub API documentation (for capability reference)
- Library example repositories and test suites
- Stack Overflow / community usage patterns

### Research Method

For each library:
1. **Quick Start**: Review README and getting-started docs
2. **API Exploration**: Browse documentation for Actions/Workflow APIs
3. **Example Search**: Look for workflow trigger/log examples in docs or tests
4. **Code Review** (if needed): Read library source for workflow/run/log handling
5. **Comparison**: Map library capabilities to our use cases (GH-2, GH-3, GH-5)

Use web search and documentation reading (no installation required for design phase).

### Success Criteria

- At least 2 libraries per language (Java, Go, Python) evaluated
- Feature coverage matrix comparing all libraries + shell approach
- Code examples demonstrating workflow triggering and correlation for each
- Clear use case recommendations (when shell vs when library)
- Migration considerations documented for future implementation

---

## Overall Deliverable

### Document: `progress/sprint_5_design.md`

This design document becomes the implementation guide. During construction phase, each section will be researched and populated with findings.

### Expected Length

Comprehensive analysis document, approximately 1500-2500 lines covering:
1. Project retrospective (500-700 lines)
2. `gh` CLI analysis (400-600 lines)
3. GitHub API analysis (400-600 lines)
4. Library survey (600-800 lines)

### Format

Markdown with:
- Tables for comparative data
- Code examples for library usage
- Links to external documentation
- Clear section headers for navigation

### Success Criteria (Overall)

- All 4 objectives addressed comprehensively
- Information sourced from authoritative references (official docs, repos)
- Objective analysis (not promotional)
- Actionable insights for future development
- Clear recommendations based on findings

---

## Construction Phase Notes

During construction (research execution), the implementor will:

1. Read existing project documentation (objectives 1)
2. Execute local commands (`gh --help`, grep analysis) (objective 2)
3. Read online documentation (GitHub API, library docs) (objectives 2-4)
4. Use WebFetch tool for documentation retrieval where beneficial
5. Populate this design document with research findings
6. No code implementation required (research sprint)

**Estimated Effort**: 2-4 hours of focused research and documentation.

**Dependencies**: Internet access for documentation, existing project files for retrospective.

**No breaking changes**: This is analysis only, no modifications to existing code.
