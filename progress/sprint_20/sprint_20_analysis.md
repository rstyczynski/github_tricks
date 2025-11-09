# Sprint 20 - Analysis

Status: Complete

## Sprint Overview

Sprint 20 focuses on **end-to-end workflow orchestration** using existing scripts developed in Sprints 0-19. This Sprint represents the culmination of all workflow management capabilities by creating a complete workflow execution sequence that demonstrates parameter processing, log retrieval, and artifact downloading.

**Sprint Goal**: Orchestrate existing scripts to:
1. Trigger a workflow via REST API with input parameters (string and number)
2. Correlate the triggered workflow to obtain its run_id
3. Monitor workflow execution
4. Retrieve workflow logs after completion
5. Download workflow artifacts after completion
6. Return processed results (array of strings with specified length)

**Nature**: This is an **integration and orchestration sprint**, not a new feature implementation. The focus is on composing existing REST API scripts into a cohesive end-to-end workflow sequence that demonstrates the full capabilities of the GitHub workflow management system.

## Backlog Items Analysis

### GH-27. Trigger long running workflow via REST API to download logs, and artifacts after completion

**Requirement Summary:**
Use already existing scripts to establish a sequence of script invocations. The workflow should:
- Accept input parameters: string parameter and number parameter
- Trigger a GitHub workflow via REST API (using existing `scripts/trigger-workflow-curl.sh`)
- Correlate the workflow to obtain run_id (using existing `scripts/correlate-workflow-curl.sh`)
- Wait for workflow completion
- Retrieve logs after completion (using existing `scripts/fetch-logs-curl.sh`)
- Download artifacts after completion (using existing `scripts/list-artifacts-curl.sh` and `scripts/download-artifact-curl.sh`)
- Return in artifacts: array of strings with the provided length

**Technical Approach:**

**1. Script Orchestration Layer**
Create an orchestrator script (`scripts/orchestrate-workflow.sh`) that sequences existing scripts:
```
trigger-workflow-curl.sh → correlate-workflow-curl.sh →
wait-for-completion → fetch-logs-curl.sh →
list-artifacts-curl.sh → download-artifact-curl.sh
```

**2. Workflow Creation**
Create a new workflow (`.github/workflows/process-and-return.yml`) that:
- Accepts inputs: `input_string` (string), `array_length` (number)
- Runs for sufficient time to test log/artifact retrieval
- Generates array of strings with specified length
- Uploads artifact containing the processed array
- Emits progress logs during execution

**3. Script Integration Points**
- **Trigger**: `scripts/trigger-workflow-curl.sh` - dispatch with inputs
- **Correlation**: `scripts/correlate-workflow-curl.sh` - get run_id by correlation_id
- **Status Monitoring**: New function to poll run status via GitHub API
- **Log Retrieval**: `scripts/fetch-logs-curl.sh` - download logs after completion
- **Artifact Discovery**: `scripts/list-artifacts-curl.sh` - find artifact_id
- **Artifact Download**: `scripts/download-artifact-curl.sh` - download artifact zip
- **Result Extraction**: Extract array from downloaded artifact

**4. Timing Considerations**
Based on Sprint 3.1 and 5.1 benchmarks:
- run_id correlation: ~2-5 seconds typical delay
- Log availability: ~5-15 seconds after job completion
- Artifact availability: immediately after job completion
- Polling strategy: exponential backoff (1s, 2s, 4s, 8s max)

**Dependencies:**
- Sprint 15 (GH-14, GH-15, GH-16) - Trigger, correlate, fetch logs - **Complete**
- Sprint 16 (GH-23) - List artifacts - **Complete**
- Sprint 17 (GH-24) - Download artifacts - **Complete**
- Existing scripts in `scripts/` directory
- Token authentication from `./secrets` directory
- GitHub Actions workflow capability

**Testing Strategy:**

**Test 1: Basic Orchestration**
- Trigger workflow with test parameters
- Verify run_id correlation succeeds
- Confirm workflow completion detection
- Validate log retrieval after completion
- Verify artifact discovery and download
- Confirm result extraction

**Test 2: Parameter Processing**
Test with various inputs:
- Short array (length=3, string="test")
- Medium array (length=10, string="example")
- Long array (length=50, string="data")
- Verify array length matches input
- Verify string content in array elements

**Test 3: Error Handling**
- Invalid workflow name
- Correlation timeout
- Workflow failure during execution
- Missing artifacts
- Download failures

**Test 4: Timing Validation**
- Measure correlation delay
- Measure log availability delay
- Measure artifact availability delay
- Compare against Sprint 3.1 and 5.1 benchmarks

**Test 5: Copy-Paste Execution**
- Document complete command sequence
- Verify all commands are copy-paste-able
- Test on clean environment
- Validate expected outputs

**Risks/Concerns:**

1. **Timing Dependencies**: Orchestration depends on proper timing for correlation, log availability, and artifact availability
2. **Error Propagation**: Failures in any step must be properly detected and reported
3. **Workflow Duration**: Workflow must run long enough to test async operations but not waste GitHub Actions minutes
4. **Artifact Size**: Generated arrays should be reasonable size for testing
5. **Token Expiration**: Long-running orchestration might encounter token expiry

**Mitigation Strategies:**
- Implement robust polling with timeouts
- Add comprehensive error checking at each step
- Use workflow with ~30-60 second duration
- Limit array generation to reasonable sizes (<1000 elements)
- Token already validated in previous Sprints

**Compatibility Notes:**

**Integration with Existing Scripts:**
- Uses established patterns from Sprints 15-18
- Maintains consistent error handling approach
- Follows token authentication pattern from `./secrets`
- Compatible with existing workflow structure

**Code Reuse:**
- Leverages `scripts/trigger-workflow-curl.sh` (Sprint 15)
- Leverages `scripts/correlate-workflow-curl.sh` (Sprint 15)
- Leverages `scripts/fetch-logs-curl.sh` (Sprint 15)
- Leverages `scripts/list-artifacts-curl.sh` (Sprint 16)
- Leverages `scripts/download-artifact-curl.sh` (Sprint 17)
- No modifications to existing scripts required

**New Components:**
- Orchestrator script: `scripts/orchestrate-workflow.sh`
- Workflow definition: `.github/workflows/process-and-return.yml`
- Status polling helper functions
- Result extraction utilities

---

## Overall Sprint Assessment

**Feasibility:** **High**

This Sprint is highly feasible because:
1. All required scripts already exist and are tested (Sprints 15-18)
2. GitHub Actions workflow capability is proven (used in previous Sprints)
3. Timing characteristics are known from Sprint 3.1 and 5.1 benchmarks
4. Token authentication pattern is established
5. No new API endpoints required - pure orchestration work
6. Pattern similar to `scripts/trigger-and-track.sh` already exists as reference

**Estimated Complexity:** **Moderate**

Complexity assessment:
- **Script Orchestration**: **Moderate** - Requires proper sequencing, error handling, timeout management
- **Workflow Creation**: **Simple** - Straightforward workflow with input processing
- **Testing**: **Moderate** - Must validate timing, error scenarios, parameter processing

Overall moderate due to:
- Orchestration logic requires careful timing management
- Error handling must be robust across multiple script invocations
- State management between script calls
- Polling logic for completion detection
- Result extraction from artifacts

Not complex because:
- All individual components already tested and working
- No new API integrations required
- Pattern exists in `trigger-and-track.sh` as reference
- Well-defined input/output contract

**Prerequisites Met:** **Yes**

All prerequisites are satisfied:
- ✅ Sprint 15 complete (trigger, correlate, fetch logs with REST API)
- ✅ Sprint 16 complete (list artifacts)
- ✅ Sprint 17 complete (download artifacts)
- ✅ All required scripts exist in `scripts/` directory
- ✅ Token authentication pattern established (`./secrets` directory)
- ✅ GitHub Actions workflow capability available
- ✅ Timing benchmarks available (Sprints 3.1, 5.1)
- ✅ Reference implementation exists (`scripts/trigger-and-track.sh`)

**Open Questions:**

**None** - All requirements are clear. The Sprint has well-defined scope:
- Use existing scripts (no new API scripts needed)
- Create orchestration layer (new: `scripts/orchestrate-workflow.sh`)
- Create processing workflow (new: `.github/workflows/process-and-return.yml`)
- Inputs: string and number
- Output: artifact containing array of strings with specified length
- Test end-to-end execution

## Recommended Design Focus Areas

1. **Orchestration Architecture**
   - Design clean script sequencing logic
   - Define state management between script calls
   - Plan error handling and recovery strategy
   - Design timeout and retry mechanisms
   - Create clear logging for debugging

2. **Workflow Design**
   - Input parameter definition and validation
   - Array generation logic (string + length)
   - Artifact creation and upload
   - Progress logging during execution
   - Execution duration for testing (30-60 seconds)

3. **Polling Strategy**
   - Completion detection mechanism
   - Exponential backoff algorithm
   - Maximum wait timeouts
   - Status check frequency
   - Early termination on failure

4. **Error Handling**
   - Script failure detection at each step
   - Clear error messages for each failure mode
   - Cleanup on partial failure
   - Graceful degradation where possible
   - Exit codes for automated processing

5. **Result Extraction**
   - Artifact location strategy
   - Zip file extraction
   - Array parsing from artifact
   - Result validation
   - Output formatting

6. **Testing Infrastructure**
   - Copy-paste-able test commands
   - Test data generation
   - Expected output documentation
   - Timing measurement instrumentation
   - Comparison with benchmarks

7. **Documentation**
   - Complete usage examples
   - Parameter descriptions
   - Expected outputs at each step
   - Troubleshooting guide
   - Integration with existing scripts

## Readiness for Design Phase

**Confirmed Ready**

All prerequisites met:
- ✅ Sprint 20 identified and active (Status: Progress in PLAN.md)
- ✅ Backlog Item GH-27 analyzed and understood
- ✅ Previous Sprint context reviewed (Sprints 0-19)
- ✅ Existing scripts identified and their capabilities understood
- ✅ No technical blockers identified
- ✅ Feasibility confirmed (High)
- ✅ Complexity assessed (Moderate)
- ✅ Dependencies verified (all complete)
- ✅ Reference implementation exists (`trigger-and-track.sh`)
- ✅ No open questions requiring clarification

**Integration Context Understood:**
- Sprint 15: REST API trigger, correlation, log retrieval
- Sprint 16: Artifact listing
- Sprint 17: Artifact downloading
- Sprint 3.1: Correlation timing benchmarks
- Sprint 5.1: Log retrieval timing benchmarks
- Existing `scripts/trigger-and-track.sh` as orchestration pattern reference

**Ready to proceed to Elaboration Phase** for detailed design of:
1. Orchestration script architecture and flow
2. Workflow definition with input processing
3. Status polling and completion detection logic
4. Error handling strategy across all steps
5. Result extraction and validation approach
6. Testing strategy with copy-paste-able examples
7. Documentation structure and content

---

**Next Step**: Create `progress/sprint_20_design.md` with detailed technical specifications for:
- Orchestrator script (`scripts/orchestrate-workflow.sh`) design
- Processing workflow (`.github/workflows/process-and-return.yml`) specification
- Polling and status checking mechanisms
- Error handling and recovery procedures
- Testing approach with timing validation
- Integration patterns with existing scripts
