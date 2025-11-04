# Elaboration – Sprint 8 (Chat 1)

## Design Summary

Completed comprehensive design for GH-12: Use GitHub API to get workflow job phases with status.

### Design Document Created

**File**: `progress/sprint_8_design.md`

**Key Design Decisions**:

1. **Script**: `scripts/view-run-jobs.sh`
   - Retrieves workflow job phases using `gh run view <run_id> --json jobs`
   - Multiple input methods: `--run-id`, `--correlation-id`, stdin JSON, interactive prompt
   - Multiple output formats: human-readable table, verbose with steps, JSON, watch mode

2. **Output Formats**:
   - **Table** (default): Concise job-level view (name, status, conclusion, timestamps)
   - **Verbose** (`--verbose`): Includes step-level details
   - **JSON** (`--json`): Structured data for programmatic consumption
   - **Watch** (`--watch`): Real-time polling every 3s until completion

3. **Integration with Previous Sprints**:
   - Sprint 1: Accepts `--correlation-id`, reads `runs/<uuid>/metadata.json`
   - Sprint 1: Accepts stdin JSON from `trigger-and-track.sh --json-only`
   - Sprint 3: Uses `scripts/lib/run-utils.sh` shared utilities
   - Compatible with existing metadata storage structure

4. **Use Cases Addressed**:
   - Monitor workflow progress during execution (watch mode)
   - Quick status check (one-time snapshot)
   - Programmatic querying (JSON + jq filtering)
   - CI/CD integration (wait for completion, check for failures)
   - Debugging (verbose mode shows step-level failures)

5. **Feasibility**:
   - Fully achievable using existing tools (`gh run view`, `jq`)
   - No new dependencies required (all from Sprint 0)
   - Browser-based authentication already configured
   - API endpoints proven working in Sprint 5 research

### Validation Strategy

**Static checks**: `shellcheck scripts/view-run-jobs.sh`, `actionlint`

**Manual tests** (7 test cases):
1. Basic job status retrieval
2. Verbose output with steps
3. JSON output for programmatic use
4. Integration with correlation metadata
5. Watch mode (real-time monitoring)
6. Error handling (invalid inputs)
7. Piping from trigger-and-track

### Risks Identified and Mitigated

1. **API rate limiting**: 3s polling interval well within limits (5,000 req/hour)
2. **Large job count**: JSON format available for programmatic processing
3. **In-progress incomplete data**: Display `-` for null values
4. **Terminal width**: Use `column -t` for auto-adjustment, JSON always available
5. **Long job names**: Truncate with ellipsis in table format

### Success Criteria

12 criteria defined covering:
- Script validation (shellcheck)
- Core functionality (retrieve, parse, display job data)
- All output formats working (table, verbose, JSON, watch)
- Integration with Sprint 1 and 3 tooling
- Error handling
- All manual tests passing
- Complete documentation

## Next Actions

- Await Product Owner review of design document
- Product Owner will update design status from "Proposed" to "Accepted" if approved
- Proceed to construction phase only after design acceptance
- If design requires changes, incorporate feedback and re-submit for review

## Design Quality Checklist

✅ Feasibility analysis complete (all APIs/tools available)
✅ Compatibility with previous sprints verified
✅ Multiple output formats for different use cases
✅ Integration patterns documented with examples
✅ Error handling specified with clear messages
✅ Validation strategy with concrete test cases
✅ Risks identified with mitigations
✅ Success criteria measurable and specific
✅ Documentation plan (inline help + implementation notes)
✅ Future enhancements noted (out of scope)

## Design Completeness

The design document is comprehensive and ready for Product Owner review:
- **Lines**: ~620 lines of detailed design
- **Sections**: Feasibility, Design, Integration, Use Cases, Validation, Risks, Documentation
- **Clarity**: Step-by-step implementation guidance with code examples
- **Testability**: 7 concrete test cases with expected outputs

Ready for Product Owner decision.
