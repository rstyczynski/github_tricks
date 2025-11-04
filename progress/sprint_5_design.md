# Sprint 5 - Design

## Objective 1: Enumerate Project Achievements and Failures

Status: Progress

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

---

## Objective 2: Enumerate `gh` CLI Capabilities

Status: Progress

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

---

## Objective 3: Enumerate GitHub API

Status: Progress

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

Status: Progress

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
