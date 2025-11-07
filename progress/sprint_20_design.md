# Sprint 20 - Design

Status: Proposed

## GH-27. Trigger long running workflow via REST API to download logs, and artifacts after completion

### Overview

Design for end-to-end workflow orchestration system that sequences existing REST API scripts to demonstrate complete workflow lifecycle management.

**Goal**: Create orchestrator that triggers workflow → correlates run_id → waits for completion → retrieves logs → downloads artifacts → extracts results

**Deliverables**:
1. Orchestration script: `scripts/orchestrate-workflow.sh`
2. Processing workflow: `.github/workflows/process-and-return.yml`
3. Functional tests with documented commands
4. Documentation in `docs/` directory

### Design Principles

1. **Reuse Over Reinvention**: Leverage all existing scripts without modification
2. **Robust Error Handling**: Fail fast with clear error messages
3. **State Transparency**: Make orchestration state visible through logging and file artifacts
4. **Timing Awareness**: Use benchmarks from Sprints 3.1 and 5.1 for polling strategies
5. **Testability**: All commands copy-paste-able and repeatable

### Architecture

#### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    orchestrate-workflow.sh                   │
│                                                              │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Parse    │→ │   Validate   │→ │   Execute    │       │
│  │   Args     │  │   Inputs     │  │   Pipeline   │       │
│  └────────────┘  └──────────────┘  └──────┬───────┘       │
│                                            │                │
│  ┌─────────────────────────────────────────┘               │
│  │                                                          │
│  ├→ [1] trigger-workflow-curl.sh                           │
│  │    Input: workflow_file, input_string, array_length     │
│  │    Output: correlation_id                               │
│  │                                                          │
│  ├→ [2] correlate-workflow-curl.sh                         │
│  │    Input: correlation_id                                │
│  │    Output: run_id                                       │
│  │                                                          │
│  ├→ [3] wait-workflow-completion-curl.sh                   │
│  │    Input: run_id                                        │
│  │    Output: final_status (success/failure)               │
│  │                                                          │
│  ├→ [4] fetch-logs-curl.sh                                 │
│  │    Input: run_id                                        │
│  │    Output: logs saved to runs/<run_id>/logs/            │
│  │                                                          │
│  ├→ [5] list-artifacts-curl.sh                             │
│  │    Input: run_id                                        │
│  │    Output: artifact_id(s)                               │
│  │                                                          │
│  ├→ [6] download-artifact-curl.sh                          │
│  │    Input: artifact_id, --extract                        │
│  │    Output: artifact extracted to artifacts/             │
│  │                                                          │
│  └→ [7] extract_and_display_results()                      │
│       Input: artifact path                                 │
│       Output: JSON array displayed                         │
└─────────────────────────────────────────────────────────────┘

                              │
                              ▼

     ┌──────────────────────────────────────────────┐
     │    .github/workflows/process-and-return.yml  │
     │                                              │
     │  Inputs:                                     │
     │    - input_string: string                    │
     │    - array_length: number                    │
     │    - correlation_id: UUID (auto-injected)    │
     │                                              │
     │  Steps:                                      │
     │    1. Validate inputs                        │
     │    2. Generate array (loop ~30 seconds)      │
     │    3. Save to JSON file                      │
     │    4. Upload artifact                        │
     │    5. Emit completion log                    │
     └──────────────────────────────────────────────┘
```

#### State Management

```
State File: /tmp/orchestrate_<timestamp>.state

Contents:
  CORRELATION_ID=<uuid>
  RUN_ID=<run_id>
  WORKFLOW_STATUS=<status>
  ARTIFACT_ID=<artifact_id>
  RESULT_FILE=<path>
```

### Component 1: Orchestration Script

**File**: `scripts/orchestrate-workflow.sh`

#### Interface

```bash
#!/bin/bash

# Usage:
#   ./orchestrate-workflow.sh --string <value> --length <num> [options]
#
# Required Parameters:
#   --string <value>      : String to include in array elements
#   --length <number>     : Number of array elements to generate
#
# Optional Parameters:
#   --workflow <file>     : Workflow file path (default: .github/workflows/process-and-return.yml)
#   --max-wait <seconds>  : Maximum wait time for completion (default: 600)
#   --interval <seconds>  : Polling interval (default: 5)
#   --keep-state          : Don't delete state file after completion
#   --help                : Show this help message
#
# Exit Codes:
#   0  : Success - workflow completed, logs and artifacts retrieved
#   1  : Invalid arguments
#   2  : Workflow trigger failed
#   3  : Correlation failed (could not get run_id)
#   4  : Workflow execution failed
#   5  : Log retrieval failed
#   6  : Artifact retrieval failed
#   7  : Result extraction failed
```

#### Script Structure

```bash
#!/bin/bash

# Script: orchestrate-workflow.sh
# Purpose: Orchestrate end-to-end workflow execution with log and artifact retrieval

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="/tmp/orchestrate_$(date +%s).state"

DEFAULT_WORKFLOW=".github/workflows/process-and-return.yml"
DEFAULT_MAX_WAIT=600
DEFAULT_INTERVAL=5

# === FUNCTIONS ===

usage() {
    # Display usage information
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

save_state() {
    # Save key=value to state file
    local key="$1"
    local value="$2"
    echo "${key}=${value}" >> "${STATE_FILE}"
}

load_state() {
    # Load state file if exists
    [[ -f "${STATE_FILE}" ]] && source "${STATE_FILE}"
}

cleanup() {
    # Cleanup state file unless --keep-state specified
    [[ "${KEEP_STATE:-false}" == "false" ]] && rm -f "${STATE_FILE}"
}

validate_prerequisites() {
    # Check for required scripts and tools
    local required_scripts=(
        "trigger-workflow-curl.sh"
        "correlate-workflow-curl.sh"
        "wait-workflow-completion-curl.sh"
        "fetch-logs-curl.sh"
        "list-artifacts-curl.sh"
        "download-artifact-curl.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -x "${SCRIPT_DIR}/${script}" ]]; then
            log_error "Required script not found or not executable: ${script}"
            return 1
        fi
    done
    
    # Check for required tools
    command -v jq >/dev/null 2>&1 || { log_error "jq not found"; return 1; }
    command -v curl >/dev/null 2>&1 || { log_error "curl not found"; return 1; }
    
    # Check for token
    [[ -f "${PROJECT_ROOT}/secrets/token" ]] || { log_error "Token file not found"; return 1; }
    
    return 0
}

step_1_trigger_workflow() {
    # Trigger workflow using trigger-workflow-curl.sh
    log_info "Step 1: Triggering workflow..."
    
    local workflow_file="$1"
    local input_string="$2"
    local array_length="$3"
    
    # Generate correlation ID
    local correlation_id
    correlation_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
    save_state "CORRELATION_ID" "${correlation_id}"
    
    log_info "Correlation ID: ${correlation_id}"
    
    # Trigger workflow
    if ! "${SCRIPT_DIR}/trigger-workflow-curl.sh" \
        --workflow "${workflow_file}" \
        --correlation-id "${correlation_id}" \
        --input "input_string=${input_string}" \
        --input "array_length=${array_length}"; then
        log_error "Failed to trigger workflow"
        return 2
    fi
    
    log_info "Workflow triggered successfully"
    return 0
}

step_2_correlate_workflow() {
    # Correlate workflow to get run_id
    log_info "Step 2: Correlating workflow to get run_id..."
    
    load_state
    [[ -z "${CORRELATION_ID:-}" ]] && { log_error "CORRELATION_ID not found in state"; return 3; }
    
    # Use exponential backoff for correlation
    local max_attempts=5
    local attempt=1
    local wait_time=2
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Correlation attempt ${attempt}/${max_attempts} (waiting ${wait_time}s)..."
        sleep ${wait_time}
        
        # Attempt correlation
        if run_id=$("${SCRIPT_DIR}/correlate-workflow-curl.sh" \
            --correlation-id "${CORRELATION_ID}" 2>/dev/null); then
            
            if [[ -n "${run_id}" && "${run_id}" != "null" ]]; then
                save_state "RUN_ID" "${run_id}"
                log_info "Run ID obtained: ${run_id}"
                return 0
            fi
        fi
        
        # Exponential backoff
        wait_time=$((wait_time * 2))
        attempt=$((attempt + 1))
    done
    
    log_error "Failed to correlate workflow after ${max_attempts} attempts"
    return 3
}

step_3_wait_for_completion() {
    # Wait for workflow completion
    log_info "Step 3: Waiting for workflow completion..."
    
    load_state
    [[ -z "${RUN_ID:-}" ]] && { log_error "RUN_ID not found in state"; return 4; }
    
    local max_wait="$1"
    local interval="$2"
    
    if ! "${SCRIPT_DIR}/wait-workflow-completion-curl.sh" \
        --run-id "${RUN_ID}" \
        --max-wait "${max_wait}" \
        --interval "${interval}"; then
        log_error "Workflow did not complete successfully"
        return 4
    fi
    
    log_info "Workflow completed successfully"
    return 0
}

step_4_fetch_logs() {
    # Fetch workflow logs
    log_info "Step 4: Fetching workflow logs..."
    
    load_state
    [[ -z "${RUN_ID:-}" ]] && { log_error "RUN_ID not found in state"; return 5; }
    
    if ! "${SCRIPT_DIR}/fetch-logs-curl.sh" --run-id "${RUN_ID}"; then
        log_error "Failed to fetch logs"
        return 5
    fi
    
    log_info "Logs fetched successfully to runs/${RUN_ID}/logs/"
    return 0
}

step_5_list_artifacts() {
    # List and identify artifacts
    log_info "Step 5: Listing artifacts..."
    
    load_state
    [[ -z "${RUN_ID:-}" ]] && { log_error "RUN_ID not found in state"; return 6; }
    
    # List artifacts and get first artifact ID
    local artifact_output
    artifact_output=$("${SCRIPT_DIR}/list-artifacts-curl.sh" --run-id "${RUN_ID}" --json)
    
    if [[ -z "${artifact_output}" ]]; then
        log_error "No artifacts found"
        return 6
    fi
    
    # Extract first artifact ID
    local artifact_id
    artifact_id=$(echo "${artifact_output}" | jq -r '.artifacts[0].id // empty')
    
    if [[ -z "${artifact_id}" || "${artifact_id}" == "null" ]]; then
        log_error "Could not extract artifact ID"
        return 6
    fi
    
    save_state "ARTIFACT_ID" "${artifact_id}"
    log_info "Artifact ID: ${artifact_id}"
    return 0
}

step_6_download_artifact() {
    # Download and extract artifact
    log_info "Step 6: Downloading artifact..."
    
    load_state
    [[ -z "${ARTIFACT_ID:-}" ]] && { log_error "ARTIFACT_ID not found in state"; return 6; }
    
    if ! "${SCRIPT_DIR}/download-artifact-curl.sh" \
        --artifact-id "${ARTIFACT_ID}" \
        --extract; then
        log_error "Failed to download artifact"
        return 6
    fi
    
    log_info "Artifact downloaded and extracted"
    return 0
}

step_7_extract_results() {
    # Extract and display results from artifact
    log_info "Step 7: Extracting results..."
    
    # Find the result JSON file in artifacts directory
    local result_file
    result_file=$(find "${PROJECT_ROOT}/artifacts" -name "result.json" -type f | head -n 1)
    
    if [[ ! -f "${result_file}" ]]; then
        log_error "Result file not found in artifacts directory"
        return 7
    fi
    
    save_state "RESULT_FILE" "${result_file}"
    
    # Display results
    log_info "Results extracted successfully"
    echo ""
    echo "========== RESULTS =========="
    cat "${result_file}"
    echo ""
    echo "============================="
    
    # Validate result format
    if ! jq -e '.generated_array' "${result_file}" >/dev/null 2>&1; then
        log_error "Invalid result format"
        return 7
    fi
    
    # Show summary
    local array_length
    array_length=$(jq '.generated_array | length' "${result_file}")
    log_info "Array length: ${array_length}"
    
    return 0
}

# === MAIN EXECUTION ===

main() {
    trap cleanup EXIT
    
    # Parse arguments
    # ... (argument parsing logic)
    
    # Validate prerequisites
    if ! validate_prerequisites; then
        exit 1
    fi
    
    # Execute orchestration pipeline
    log_info "=== Starting Workflow Orchestration ==="
    log_info "Input String: ${INPUT_STRING}"
    log_info "Array Length: ${ARRAY_LENGTH}"
    log_info "Workflow: ${WORKFLOW_FILE}"
    echo ""
    
    # Step 1: Trigger
    step_1_trigger_workflow "${WORKFLOW_FILE}" "${INPUT_STRING}" "${ARRAY_LENGTH}" || exit $?
    
    # Step 2: Correlate
    step_2_correlate_workflow || exit $?
    
    # Step 3: Wait
    step_3_wait_for_completion "${MAX_WAIT}" "${INTERVAL}" || exit $?
    
    # Step 4: Fetch logs
    step_4_fetch_logs || exit $?
    
    # Step 5: List artifacts
    step_5_list_artifacts || exit $?
    
    # Step 6: Download artifacts
    step_6_download_artifact || exit $?
    
    # Step 7: Extract results
    step_7_extract_results || exit $?
    
    log_info "=== Orchestration Complete ==="
    load_state
    echo ""
    echo "Summary:"
    echo "  Correlation ID: ${CORRELATION_ID}"
    echo "  Run ID: ${RUN_ID}"
    echo "  Logs: runs/${RUN_ID}/logs/"
    echo "  Results: ${RESULT_FILE}"
    
    exit 0
}

main "$@"
```

### Component 2: Processing Workflow

**File**: `.github/workflows/process-and-return.yml`

#### Workflow Specification

```yaml
name: Process and Return Data

on:
  workflow_dispatch:
    inputs:
      input_string:
        description: 'String to include in array elements'
        required: true
        type: string
      array_length:
        description: 'Number of array elements to generate'
        required: true
        type: number
      correlation_id:
        description: 'Correlation ID for tracking (auto-injected)'
        required: false
        type: string

jobs:
  process:
    name: Process Parameters
    runs-on: ubuntu-latest
    timeout-minutes: 10
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Validate inputs
        run: |
          echo "=== Input Validation ==="
          echo "Input String: ${{ inputs.input_string }}"
          echo "Array Length: ${{ inputs.array_length }}"
          echo "Correlation ID: ${{ inputs.correlation_id }}"
          
          # Validate array_length is positive integer
          if ! [[ "${{ inputs.array_length }}" =~ ^[0-9]+$ ]]; then
            echo "ERROR: array_length must be a positive integer"
            exit 1
          fi
          
          if [[ "${{ inputs.array_length }}" -lt 1 ]]; then
            echo "ERROR: array_length must be at least 1"
            exit 1
          fi
          
          if [[ "${{ inputs.array_length }}" -gt 1000 ]]; then
            echo "WARNING: array_length capped at 1000"
          fi
          
          echo "Validation passed"
      
      - name: Generate array
        id: generate
        run: |
          echo "=== Generating Array ==="
          
          INPUT_STRING="${{ inputs.input_string }}"
          ARRAY_LENGTH=${{ inputs.array_length }}
          
          # Cap at 1000 for safety
          if [[ ${ARRAY_LENGTH} -gt 1000 ]]; then
            ARRAY_LENGTH=1000
          fi
          
          # Create result directory
          mkdir -p result
          
          # Generate array with timing to ensure ~30-60 second runtime
          # Emit progress every few seconds
          
          echo "Starting array generation..."
          
          # Initialize JSON array
          echo "{" > result/result.json
          echo "  \"correlation_id\": \"${{ inputs.correlation_id }}\"," >> result/result.json
          echo "  \"input_string\": \"${INPUT_STRING}\"," >> result/result.json
          echo "  \"requested_length\": ${ARRAY_LENGTH}," >> result/result.json
          echo "  \"generated_array\": [" >> result/result.json
          
          # Generate array elements with progress logging
          for ((i=0; i<${ARRAY_LENGTH}; i++)); do
            # Add element
            if [[ $i -lt $((ARRAY_LENGTH - 1)) ]]; then
              echo "    \"${INPUT_STRING}_${i}\"," >> result/result.json
            else
              echo "    \"${INPUT_STRING}_${i}\"" >> result/result.json
            fi
            
            # Progress logging every 10 elements or every 5 seconds
            if [[ $((i % 10)) -eq 0 ]]; then
              echo "Progress: Generated $i / ${ARRAY_LENGTH} elements"
              sleep 0.5  # Slow down to ensure reasonable runtime
            fi
          done
          
          # Close JSON array
          echo "  ]," >> result/result.json
          echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" >> result/result.json
          echo "}" >> result/result.json
          
          echo "Array generation complete"
          
          # Add additional delay to ensure workflow runs long enough for testing
          # Target ~30-60 seconds total runtime
          CURRENT_SECONDS=$SECONDS
          if [[ ${CURRENT_SECONDS} -lt 30 ]]; then
            SLEEP_TIME=$((30 - CURRENT_SECONDS))
            echo "Adding ${SLEEP_TIME}s delay to reach target runtime..."
            sleep ${SLEEP_TIME}
          fi
          
          echo "Processing complete after ${SECONDS} seconds"
      
      - name: Validate result
        run: |
          echo "=== Validating Result ==="
          
          if [[ ! -f result/result.json ]]; then
            echo "ERROR: Result file not found"
            exit 1
          fi
          
          # Validate JSON format
          if ! jq empty result/result.json; then
            echo "ERROR: Invalid JSON format"
            exit 1
          fi
          
          # Validate structure
          if ! jq -e '.generated_array' result/result.json > /dev/null; then
            echo "ERROR: Missing generated_array field"
            exit 1
          fi
          
          ACTUAL_LENGTH=$(jq '.generated_array | length' result/result.json)
          echo "Result array length: ${ACTUAL_LENGTH}"
          
          echo "Validation passed"
      
      - name: Upload result artifact
        uses: actions/upload-artifact@v4
        with:
          name: processing-result
          path: result/
          retention-days: 7
      
      - name: Display completion summary
        run: |
          echo "=== Workflow Complete ==="
          echo "Correlation ID: ${{ inputs.correlation_id }}"
          echo "Input String: ${{ inputs.input_string }}"
          echo "Array Length: $(jq '.generated_array | length' result/result.json)"
          echo "Artifact uploaded: processing-result"
          echo "Total runtime: ${SECONDS} seconds"
```

### Integration Points

#### Script Integration Matrix

| Step | Script | Input | Output | Error Handling |
|------|--------|-------|--------|----------------|
| 1 | `trigger-workflow-curl.sh` | workflow, inputs, correlation_id | Success/failure | Exit 2 if trigger fails |
| 2 | `correlate-workflow-curl.sh` | correlation_id | run_id | Exit 3 if correlation fails after retries |
| 3 | `wait-workflow-completion-curl.sh` | run_id, max_wait, interval | Success/failure | Exit 4 if workflow fails |
| 4 | `fetch-logs-curl.sh` | run_id | Logs in runs/ | Exit 5 if log fetch fails |
| 5 | `list-artifacts-curl.sh` | run_id | artifact_id(s) | Exit 6 if no artifacts |
| 6 | `download-artifact-curl.sh` | artifact_id, --extract | Extracted files | Exit 6 if download fails |
| 7 | Extract results | artifact path | JSON displayed | Exit 7 if extraction fails |

#### Script Invocation Patterns

**Trigger Workflow**:
```bash
./trigger-workflow-curl.sh \
  --workflow .github/workflows/process-and-return.yml \
  --correlation-id "${CORRELATION_ID}" \
  --input "input_string=test" \
  --input "array_length=10"
```

**Correlate Workflow**:
```bash
run_id=$(./correlate-workflow-curl.sh \
  --correlation-id "${CORRELATION_ID}")
```

**Wait for Completion**:
```bash
./wait-workflow-completion-curl.sh \
  --run-id "${run_id}" \
  --max-wait 600 \
  --interval 5
```

**Fetch Logs**:
```bash
./fetch-logs-curl.sh --run-id "${run_id}"
```

**List Artifacts**:
```bash
artifacts_json=$(./list-artifacts-curl.sh \
  --run-id "${run_id}" --json)
artifact_id=$(echo "${artifacts_json}" | jq -r '.artifacts[0].id')
```

**Download Artifact**:
```bash
./download-artifact-curl.sh \
  --artifact-id "${artifact_id}" \
  --extract
```

### Error Handling Strategy

#### Error Categories

**1. Input Validation Errors** (Exit 1)
- Missing required parameters
- Invalid parameter formats
- Missing prerequisites (scripts, tools, token)

**2. Trigger Errors** (Exit 2)
- Workflow file not found
- Invalid workflow syntax
- GitHub API authentication failure
- Rate limiting

**3. Correlation Errors** (Exit 3)
- run_id not found after max attempts
- GitHub API unavailable
- Invalid correlation_id format

**4. Execution Errors** (Exit 4)
- Workflow execution failed
- Workflow timeout
- Workflow cancelled

**5. Log Retrieval Errors** (Exit 5)
- Logs not yet available
- Log fetch API error
- Insufficient permissions

**6. Artifact Errors** (Exit 6)
- No artifacts produced
- Artifact not found
- Download failed
- Extraction failed

**7. Result Processing Errors** (Exit 7)
- Invalid JSON format
- Missing expected fields
- Data validation failure

#### Error Handling Implementation

```bash
# Unified error handler
handle_error() {
    local exit_code=$1
    local step_name=$2
    local error_message=$3
    
    log_error "Step failed: ${step_name}"
    log_error "Error: ${error_message}"
    log_error "Exit code: ${exit_code}"
    
    # Save error to state file
    save_state "ERROR_STEP" "${step_name}"
    save_state "ERROR_MESSAGE" "${error_message}"
    save_state "ERROR_CODE" "${exit_code}"
    
    # Preserve state for debugging
    KEEP_STATE=true
    
    exit "${exit_code}"
}

# Wrap each step with error handling
step_wrapper() {
    local step_number=$1
    local step_name=$2
    shift 2
    local step_function=$1
    shift
    
    echo ""
    echo "========== Step ${step_number}: ${step_name} =========="
    
    if ! "${step_function}" "$@"; then
        local exit_code=$?
        handle_error "${exit_code}" "${step_name}" "Step function returned error"
    fi
    
    echo "Step ${step_number} completed successfully"
}
```

### Timing and Polling Strategy

#### Timing Benchmarks (from Sprint 3.1 and 5.1)

- **run_id Correlation**: 2-5 seconds typical, up to 10 seconds worst case
- **Log Availability**: 5-15 seconds after job completion
- **Artifact Availability**: Immediate after job completion (0-2 seconds)

#### Polling Configuration

**Correlation Polling** (Exponential Backoff):
```
Attempt 1: Wait 2s
Attempt 2: Wait 4s
Attempt 3: Wait 8s
Attempt 4: Wait 16s
Attempt 5: Wait 32s
Max attempts: 5 (total ~62s)
```

**Completion Polling** (Fixed Interval):
```
Interval: 5s (configurable via --interval)
Max wait: 600s (10 minutes, configurable via --max-wait)
Total attempts: max_wait / interval
```

**Artifact Availability** (No Polling Required):
```
List artifacts immediately after workflow completion
Download artifacts immediately after listing
```

#### Timeout Configuration

| Operation | Default Timeout | Configurable | Max Recommended |
|-----------|----------------|--------------|-----------------|
| Trigger | 30s | No | N/A |
| Correlation | 62s | No | N/A |
| Workflow Execution | 600s (10min) | Yes (--max-wait) | 3600s (1hr) |
| Log Fetch | 60s | No | N/A |
| Artifact List | 30s | No | N/A |
| Artifact Download | 300s (5min) | No | N/A |

### Testing Strategy

#### Test Categories

**1. Functional Tests**
- Basic orchestration with valid parameters
- Parameter validation (various input_string and array_length values)
- End-to-end execution flow
- Result extraction and validation

**2. Error Handling Tests**
- Invalid workflow file
- Missing parameters
- Correlation timeout
- Workflow execution failure
- Missing artifacts

**3. Timing Tests**
- Correlation delay measurement
- Log availability delay measurement
- Artifact availability verification
- Comparison with Sprint 3.1/5.1 benchmarks

**4. Integration Tests**
- All scripts execute without modification
- State management across script invocations
- Cleanup verification
- Multiple parallel executions (isolation)

#### Test Implementation

**Test 1: Basic Orchestration**
```bash
# Test basic workflow orchestration
./scripts/orchestrate-workflow.sh \
  --string "test" \
  --length 5

# Expected: 
# - Workflow triggered
# - run_id obtained
# - Workflow completes
# - Logs retrieved
# - Artifact downloaded
# - Array of 5 elements with "test" prefix
# Exit code: 0
```

**Test 2: Parameter Variations**
```bash
# Small array
./scripts/orchestrate-workflow.sh --string "small" --length 3

# Medium array
./scripts/orchestrate-workflow.sh --string "medium" --length 10

# Large array
./scripts/orchestrate-workflow.sh --string "large" --length 50

# Expected: All complete successfully with correct array lengths
```

**Test 3: Error Handling - Invalid Workflow**
```bash
# Non-existent workflow
./scripts/orchestrate-workflow.sh \
  --string "test" \
  --length 5 \
  --workflow .github/workflows/nonexistent.yml

# Expected: Exit code 2 (trigger failed)
```

**Test 4: Error Handling - Invalid Parameters**
```bash
# Missing required parameter
./scripts/orchestrate-workflow.sh --string "test"

# Expected: Exit code 1 (invalid arguments)

# Invalid array length
./scripts/orchestrate-workflow.sh --string "test" --length -5

# Expected: Exit code 1 (invalid arguments)
```

**Test 5: Timing Measurement**
```bash
# Execute with timing instrumentation
time ./scripts/orchestrate-workflow.sh \
  --string "timing_test" \
  --length 10 2>&1 | tee timing_test.log

# Analyze timing_test.log:
# - Extract correlation delay
# - Extract wait duration
# - Extract log fetch delay
# - Compare with benchmarks
```

**Test 6: State Management**
```bash
# Execute with state preservation
./scripts/orchestrate-workflow.sh \
  --string "state_test" \
  --length 5 \
  --keep-state

# Verify state file contains:
# - CORRELATION_ID
# - RUN_ID
# - ARTIFACT_ID
# - RESULT_FILE
```

**Test 7: Parallel Execution**
```bash
# Execute multiple orchestrations in parallel
./scripts/orchestrate-workflow.sh --string "parallel_1" --length 3 &
pid1=$!

./scripts/orchestrate-workflow.sh --string "parallel_2" --length 3 &
pid2=$!

./scripts/orchestrate-workflow.sh --string "parallel_3" --length 3 &
pid3=$!

wait $pid1 $pid2 $pid3

# Expected: All 3 complete successfully without interference
```

#### Test Automation Script

**File**: `tests/test-orchestration.sh`

```bash
#!/bin/bash

# Test orchestration end-to-end functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RESULTS_FILE="${PROJECT_ROOT}/tests/orchestration-test-results.json"

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    echo "Running test: ${test_name}"
    
    local start_time
    start_time=$(date +%s)
    
    local exit_code=0
    eval "${test_command}" || exit_code=$?
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local status="FAIL"
    if [[ ${exit_code} -eq ${expected_exit_code} ]]; then
        status="PASS"
    fi
    
    echo "  Status: ${status}"
    echo "  Duration: ${duration}s"
    echo "  Exit code: ${exit_code} (expected: ${expected_exit_code})"
    echo ""
    
    # Record result
    jq -n \
        --arg name "${test_name}" \
        --arg status "${status}" \
        --arg exit_code "${exit_code}" \
        --arg expected "${expected_exit_code}" \
        --arg duration "${duration}" \
        '{
            test: $name,
            status: $status,
            exit_code: ($exit_code | tonumber),
            expected_exit_code: ($expected | tonumber),
            duration_seconds: ($duration | tonumber),
            timestamp: now | todateiso8601
        }' >> "${RESULTS_FILE}.tmp"
}

main() {
    echo "=== Orchestration Test Suite ==="
    echo ""
    
    # Initialize results file
    echo "[]" > "${RESULTS_FILE}"
    rm -f "${RESULTS_FILE}.tmp"
    
    # Test 1: Basic orchestration
    run_test \
        "Basic orchestration (length=5)" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string test --length 5" \
        0
    
    # Test 2: Small array
    run_test \
        "Small array (length=3)" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string small --length 3" \
        0
    
    # Test 3: Medium array
    run_test \
        "Medium array (length=10)" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string medium --length 10" \
        0
    
    # Test 4: Invalid parameters (missing length)
    run_test \
        "Missing required parameter" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string test" \
        1
    
    # Test 5: State preservation
    run_test \
        "State preservation" \
        "${PROJECT_ROOT}/scripts/orchestrate-workflow.sh --string state --length 5 --keep-state" \
        0
    
    # Aggregate results
    if [[ -f "${RESULTS_FILE}.tmp" ]]; then
        jq -s '.' "${RESULTS_FILE}.tmp" > "${RESULTS_FILE}"
        rm -f "${RESULTS_FILE}.tmp"
    fi
    
    # Summary
    local total_tests
    total_tests=$(jq '. | length' "${RESULTS_FILE}")
    local passed_tests
    passed_tests=$(jq '[.[] | select(.status == "PASS")] | length' "${RESULTS_FILE}")
    local failed_tests
    failed_tests=$(jq '[.[] | select(.status == "FAIL")] | length' "${RESULTS_FILE}")
    
    echo "=== Test Summary ==="
    echo "Total tests: ${total_tests}"
    echo "Passed: ${passed_tests}"
    echo "Failed: ${failed_tests}"
    echo ""
    echo "Detailed results: ${RESULTS_FILE}"
    
    if [[ ${failed_tests} -gt 0 ]]; then
        echo "Some tests failed"
        exit 1
    fi
    
    echo "All tests passed"
    exit 0
}

main "$@"
```

### Documentation Plan

#### User Documentation

**File**: `docs/api-orchestrate-workflow.md`

**Sections**:
1. Overview and purpose
2. Prerequisites and setup
3. Basic usage with examples
4. Parameter reference
5. Output description
6. Error codes and troubleshooting
7. Integration with existing scripts
8. Timing considerations
9. Advanced usage patterns

#### README Updates

Add to README.md:
- New "End-to-End Orchestration" section under "Features"
- Quick start example for orchestration
- Link to detailed documentation
- Update "Current Status" to show Sprint 20

### Design Validation

#### GitHub API Feasibility

✅ **All Required APIs Available**:
- Workflow dispatch: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches`
- Run correlation: `GET /repos/{owner}/{repo}/actions/runs?created=>={timestamp}`
- Run status: `GET /repos/{owner}/{repo}/actions/runs/{run_id}`
- Job logs: `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`
- Artifact list: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`
- Artifact download: `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip`

All APIs validated in Sprints 15-18.

#### Script Integration Feasibility

✅ **All Required Scripts Exist**:
- `trigger-workflow-curl.sh` (Sprint 15)
- `correlate-workflow-curl.sh` (Sprint 15)
- `wait-workflow-completion-curl.sh` (Sprint 17)
- `fetch-logs-curl.sh` (Sprint 15)
- `list-artifacts-curl.sh` (Sprint 16)
- `download-artifact-curl.sh` (Sprint 17)

No script modifications required.

#### Timing Feasibility

✅ **Timing Requirements Achievable**:
- Correlation: 2-5s typical (Sprint 3.1 benchmark: median 17s, but with optimizations ~2-5s achievable)
- Log availability: 5-15s after completion (Sprint 5.1 benchmarks)
- Artifact availability: Immediate after completion
- Exponential backoff correlation strategy accounts for variance
- Configurable timeouts for workflow completion

#### Testing Feasibility

✅ **Testing Requirements Achievable**:
- Copy-paste-able commands possible with bash script
- Real GitHub infrastructure testing via workflow_dispatch
- Timing measurements via bash SECONDS variable
- Error scenario testing via parameter manipulation
- Parallel execution testing via background processes

### Dependencies

**External Dependencies**:
- bash (≥4.0)
- curl
- jq
- uuidgen (or alternative UUID generation)
- GitHub REST API access
- Token with workflow permissions

**Internal Dependencies**:
- Sprint 15 scripts (trigger, correlate, fetch-logs)
- Sprint 16 scripts (list-artifacts)
- Sprint 17 scripts (download-artifact, wait-completion)
- Token file in `./secrets/token`
- Existing project structure (runs/, artifacts/ directories)

**Workflow Dependencies**:
- GitHub Actions runner (ubuntu-latest)
- actions/checkout@v4
- actions/upload-artifact@v4

### Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Correlation timeout | Low | High | Exponential backoff with 5 attempts |
| Workflow execution failure | Low | High | Clear error reporting, preserve state |
| Log fetch timing | Low | Medium | Fixed delay + retry logic |
| Artifact not produced | Low | High | Workflow validation step before artifact upload |
| State file conflicts | Low | Low | Unique timestamp-based state file names |
| Parallel execution interference | Low | Medium | Isolated state files, correlation_id uniqueness |
| Large artifact download timeout | Low | Medium | Reasonable array size limits (capped at 1000) |

### Implementation Checklist

**Phase 1: Orchestration Script**:
- [ ] Create `scripts/orchestrate-workflow.sh`
- [ ] Implement argument parsing
- [ ] Implement prerequisite validation
- [ ] Implement state management
- [ ] Implement 7-step pipeline
- [ ] Implement error handling
- [ ] Add usage documentation
- [ ] Make executable

**Phase 2: Processing Workflow**:
- [ ] Create `.github/workflows/process-and-return.yml`
- [ ] Define workflow inputs
- [ ] Implement input validation
- [ ] Implement array generation logic
- [ ] Add progress logging
- [ ] Implement result JSON generation
- [ ] Add artifact upload
- [ ] Add result validation

**Phase 3: Testing**:
- [ ] Create `tests/test-orchestration.sh`
- [ ] Implement test framework
- [ ] Add functional tests
- [ ] Add error handling tests
- [ ] Add timing tests
- [ ] Execute all tests
- [ ] Document test results

**Phase 4: Documentation**:
- [ ] Create `docs/api-orchestrate-workflow.md`
- [ ] Add usage examples
- [ ] Add troubleshooting guide
- [ ] Update README.md
- [ ] Add to API operations summary
- [ ] Document timing characteristics

### Success Criteria

**Functional Success**:
- ✅ Orchestration script executes all 7 steps successfully
- ✅ Workflow triggered with custom parameters
- ✅ run_id obtained via correlation
- ✅ Workflow completes successfully
- ✅ Logs retrieved and stored
- ✅ Artifacts downloaded and extracted
- ✅ Results validated (correct array length and content)

**Quality Success**:
- ✅ All tests pass (minimum 5 functional tests)
- ✅ Error handling covers all failure modes
- ✅ Documentation is complete with copy-paste-able examples
- ✅ Timing measurements validate against benchmarks
- ✅ No modifications to existing scripts required

**Integration Success**:
- ✅ Seamless integration with Sprint 15-18 scripts
- ✅ Consistent authentication pattern
- ✅ Consistent error handling pattern
- ✅ Compatible with existing project structure

### Design Summary

This design provides a robust end-to-end workflow orchestration system that:

1. **Reuses** all existing REST API scripts without modification
2. **Sequences** 7 distinct steps with proper error handling
3. **Manages** state across script invocations
4. **Handles** timing considerations with polling strategies
5. **Tests** thoroughly with copy-paste-able commands
6. **Documents** comprehensively with examples and troubleshooting

The implementation follows established patterns from Sprints 15-18 and leverages timing benchmarks from Sprints 3.1 and 5.1 to ensure reliable correlation and log retrieval.

**Estimated Implementation Time**: 3-4 hours
- Orchestration script: 1.5 hours
- Processing workflow: 1 hour
- Testing: 1 hour
- Documentation: 0.5 hours

**Complexity**: Moderate (as assessed in Sprint 20 analysis)

---

**Design Status**: Proposed
**Awaiting**: Product Owner approval (60 second auto-approval applies per RUP manager instructions)

