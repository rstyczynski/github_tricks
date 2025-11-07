#!/bin/bash

# Script: orchestrate-workflow.sh
# Purpose: Orchestrate end-to-end workflow execution with log and artifact retrieval
# Sprint: 20
# Backlog Item: GH-27

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="/tmp/orchestrate_$(date +%s).state"

DEFAULT_WORKFLOW=".github/workflows/process-and-return.yml"
DEFAULT_MAX_WAIT=600
DEFAULT_INTERVAL=5

# === GLOBAL VARIABLES ===
INPUT_STRING=""
ARRAY_LENGTH=0
WORKFLOW_FILE="${DEFAULT_WORKFLOW}"
MAX_WAIT="${DEFAULT_MAX_WAIT}"
INTERVAL="${DEFAULT_INTERVAL}"
KEEP_STATE=false

# === FUNCTIONS ===

usage() {
    cat << EOF
Usage: ${0##*/} --string <value> --length <num> [options]

Orchestrate end-to-end workflow execution from trigger to artifact retrieval.

Required Parameters:
  --string <value>      String to include in array elements
  --length <number>     Number of array elements to generate (1-1000)

Optional Parameters:
  --workflow <file>     Workflow file path (default: ${DEFAULT_WORKFLOW})
  --max-wait <seconds>  Maximum wait time for completion (default: ${DEFAULT_MAX_WAIT})
  --interval <seconds>  Polling interval (default: ${DEFAULT_INTERVAL})
  --keep-state          Don't delete state file after completion
  --help                Show this help message

Exit Codes:
  0  : Success - workflow completed, logs and artifacts retrieved
  1  : Invalid arguments or missing prerequisites
  2  : Workflow trigger failed
  3  : Correlation failed (could not get run_id)
  4  : Workflow execution failed
  5  : Log retrieval failed
  6  : Artifact retrieval failed
  7  : Result extraction failed

Examples:
  # Basic orchestration
  ${0##*/} --string "test" --length 10
  
  # With custom workflow and timeout
  ${0##*/} --string "data" --length 50 --workflow custom.yml --max-wait 1200
  
  # Preserve state for debugging
  ${0##*/} --string "debug" --length 5 --keep-state

EOF
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

save_state() {
    local key="$1"
    local value="$2"
    echo "${key}=${value}" >> "${STATE_FILE}"
}

load_state() {
    [[ -f "${STATE_FILE}" ]] && source "${STATE_FILE}"
}

cleanup() {
    if [[ "${KEEP_STATE:-false}" == "false" ]]; then
        rm -f "${STATE_FILE}"
    else
        log_info "State file preserved at: ${STATE_FILE}"
    fi
}

validate_prerequisites() {
    log_info "Validating prerequisites..."
    
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
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq not found (required for JSON processing)"
        return 1
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl not found (required for API calls)"
        return 1
    fi
    
    if ! command -v uuidgen >/dev/null 2>&1; then
        log_error "uuidgen not found (required for correlation ID generation)"
        return 1
    fi
    
    # Check for token
    if [[ ! -f "${PROJECT_ROOT}/secrets/token" ]]; then
        log_error "Token file not found at ${PROJECT_ROOT}/secrets/token"
        return 1
    fi
    
    # Check workflow file exists
    if [[ ! -f "${PROJECT_ROOT}/${WORKFLOW_FILE}" ]]; then
        log_error "Workflow file not found: ${PROJECT_ROOT}/${WORKFLOW_FILE}"
        return 1
    fi
    
    log_info "Prerequisites validated successfully"
    return 0
}

step_1_trigger_workflow() {
    log_info "Step 1: Triggering workflow..."
    
    local workflow_file="$1"
    local input_string="$2"
    local array_length="$3"
    
    # Generate correlation ID
    local correlation_id
    correlation_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
    save_state "CORRELATION_ID" "${correlation_id}"
    
    log_info "Correlation ID: ${correlation_id}"
    log_info "Workflow: ${workflow_file}"
    log_info "Parameters: string='${input_string}', length=${array_length}"
    
    # Trigger workflow
    if ! "${SCRIPT_DIR}/trigger-workflow-curl.sh" \
        --workflow "${workflow_file}" \
        --correlation-id "${correlation_id}" \
        --input "input_string=${input_string}" \
        --input "array_length=${array_length}" \
        --input "correlation_id=${correlation_id}"; then
        log_error "Failed to trigger workflow"
        return 2
    fi
    
    log_info "Workflow triggered successfully"
    return 0
}

step_2_correlate_workflow() {
    log_info "Step 2: Correlating workflow to get run_id..."
    
    load_state
    if [[ -z "${CORRELATION_ID:-}" ]]; then
        log_error "CORRELATION_ID not found in state"
        return 3
    fi
    
    # Use exponential backoff for correlation
    local max_attempts=5
    local attempt=1
    local wait_time=2
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Correlation attempt ${attempt}/${max_attempts} (waiting ${wait_time}s)..."
        sleep ${wait_time}
        
        # Attempt correlation
        local run_id
        if run_id=$("${SCRIPT_DIR}/correlate-workflow-curl.sh" \
            --correlation-id "${CORRELATION_ID}" 2>/dev/null | tail -n 1); then
            
            if [[ -n "${run_id}" && "${run_id}" != "null" && "${run_id}" =~ ^[0-9]+$ ]]; then
                save_state "RUN_ID" "${run_id}"
                log_info "Run ID obtained: ${run_id}"
                return 0
            fi
        fi
        
        # Exponential backoff (cap at 16 seconds)
        wait_time=$((wait_time * 2))
        if [[ ${wait_time} -gt 16 ]]; then
            wait_time=16
        fi
        attempt=$((attempt + 1))
    done
    
    log_error "Failed to correlate workflow after ${max_attempts} attempts"
    return 3
}

step_3_wait_for_completion() {
    log_info "Step 3: Waiting for workflow completion..."
    
    load_state
    if [[ -z "${RUN_ID:-}" ]]; then
        log_error "RUN_ID not found in state"
        return 4
    fi
    
    local max_wait="$1"
    local interval="$2"
    
    log_info "Max wait: ${max_wait}s, Polling interval: ${interval}s"
    
    if ! "${SCRIPT_DIR}/wait-workflow-completion-curl.sh" \
        --run-id "${RUN_ID}" \
        --max-wait "${max_wait}" \
        --interval "${interval}"; then
        log_error "Workflow did not complete successfully"
        return 4
    fi
    
    save_state "WORKFLOW_STATUS" "completed"
    log_info "Workflow completed successfully"
    return 0
}

step_4_fetch_logs() {
    log_info "Step 4: Fetching workflow logs..."
    
    load_state
    if [[ -z "${RUN_ID:-}" ]]; then
        log_error "RUN_ID not found in state"
        return 5
    fi
    
    if ! "${SCRIPT_DIR}/fetch-logs-curl.sh" --run-id "${RUN_ID}"; then
        log_error "Failed to fetch logs"
        return 5
    fi
    
    local logs_dir="${PROJECT_ROOT}/runs/${RUN_ID}/logs"
    save_state "LOGS_DIR" "${logs_dir}"
    log_info "Logs fetched successfully to ${logs_dir}"
    return 0
}

step_5_list_artifacts() {
    log_info "Step 5: Listing artifacts..."
    
    load_state
    if [[ -z "${RUN_ID:-}" ]]; then
        log_error "RUN_ID not found in state"
        return 6
    fi
    
    # List artifacts and get artifact information
    local artifact_output
    artifact_output=$("${SCRIPT_DIR}/list-artifacts-curl.sh" --run-id "${RUN_ID}" --json)
    
    if [[ -z "${artifact_output}" ]]; then
        log_error "No artifacts found or failed to list artifacts"
        return 6
    fi
    
    # Extract first artifact ID
    local artifact_id
    artifact_id=$(echo "${artifact_output}" | jq -r '.artifacts[0].id // empty')
    
    if [[ -z "${artifact_id}" || "${artifact_id}" == "null" ]]; then
        log_error "Could not extract artifact ID from response"
        return 6
    fi
    
    save_state "ARTIFACT_ID" "${artifact_id}"
    
    # Also save artifact name for reference
    local artifact_name
    artifact_name=$(echo "${artifact_output}" | jq -r '.artifacts[0].name // "unknown"')
    save_state "ARTIFACT_NAME" "${artifact_name}"
    
    log_info "Found artifact: ${artifact_name} (ID: ${artifact_id})"
    return 0
}

step_6_download_artifact() {
    log_info "Step 6: Downloading artifact..."
    
    load_state
    if [[ -z "${ARTIFACT_ID:-}" ]]; then
        log_error "ARTIFACT_ID not found in state"
        return 6
    fi
    
    # Download and extract artifact
    if ! "${SCRIPT_DIR}/download-artifact-curl.sh" \
        --artifact-id "${ARTIFACT_ID}" \
        --extract; then
        log_error "Failed to download artifact"
        return 6
    fi
    
    log_info "Artifact downloaded and extracted successfully"
    return 0
}

step_7_extract_results() {
    log_info "Step 7: Extracting and validating results..."
    
    load_state
    
    # Find the result JSON file in artifacts directory
    local result_file
    result_file=$(find "${PROJECT_ROOT}/artifacts" -name "result.json" -type f 2>/dev/null | head -n 1)
    
    if [[ ! -f "${result_file}" ]]; then
        log_error "Result file (result.json) not found in artifacts directory"
        return 7
    fi
    
    save_state "RESULT_FILE" "${result_file}"
    
    # Validate result format
    if ! jq empty "${result_file}" 2>/dev/null; then
        log_error "Invalid JSON format in result file"
        return 7
    fi
    
    if ! jq -e '.generated_array' "${result_file}" >/dev/null 2>&1; then
        log_error "Result file missing 'generated_array' field"
        return 7
    fi
    
    # Extract metadata
    local actual_length
    actual_length=$(jq '.generated_array | length' "${result_file}")
    
    local input_string_from_result
    input_string_from_result=$(jq -r '.input_string' "${result_file}")
    
    local correlation_id_from_result
    correlation_id_from_result=$(jq -r '.correlation_id' "${result_file}")
    
    # Display results
    log_info "Results extracted and validated successfully"
    echo ""
    echo "=========================================="
    echo "           WORKFLOW RESULTS"
    echo "=========================================="
    echo ""
    echo "Correlation ID: ${correlation_id_from_result}"
    echo "Input String:   ${input_string_from_result}"
    echo "Array Length:   ${actual_length}"
    echo ""
    echo "Generated Array:"
    jq -r '.generated_array[]' "${result_file}" | head -n 10
    if [[ ${actual_length} -gt 10 ]]; then
        echo "... (showing first 10 of ${actual_length} elements)"
    fi
    echo ""
    echo "=========================================="
    echo ""
    
    # Verify array length matches request
    if [[ ${actual_length} -eq ${ARRAY_LENGTH} ]]; then
        log_info "✓ Array length validation: PASS (${actual_length} == ${ARRAY_LENGTH})"
    else
        log_error "✗ Array length validation: FAIL (${actual_length} != ${ARRAY_LENGTH})"
        return 7
    fi
    
    # Verify correlation ID matches
    if [[ "${correlation_id_from_result}" == "${CORRELATION_ID}" ]]; then
        log_info "✓ Correlation ID validation: PASS"
    else
        log_error "✗ Correlation ID validation: FAIL"
        return 7
    fi
    
    return 0
}

# === ARGUMENT PARSING ===

parse_arguments() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --string)
                INPUT_STRING="$2"
                shift 2
                ;;
            --length)
                ARRAY_LENGTH="$2"
                shift 2
                ;;
            --workflow)
                WORKFLOW_FILE="$2"
                shift 2
                ;;
            --max-wait)
                MAX_WAIT="$2"
                shift 2
                ;;
            --interval)
                INTERVAL="$2"
                shift 2
                ;;
            --keep-state)
                KEEP_STATE=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "${INPUT_STRING}" ]]; then
        log_error "Missing required parameter: --string"
        exit 1
    fi
    
    if [[ ${ARRAY_LENGTH} -eq 0 ]]; then
        log_error "Missing required parameter: --length"
        exit 1
    fi
    
    # Validate array length
    if ! [[ "${ARRAY_LENGTH}" =~ ^[0-9]+$ ]]; then
        log_error "Array length must be a positive integer"
        exit 1
    fi
    
    if [[ ${ARRAY_LENGTH} -lt 1 ]]; then
        log_error "Array length must be at least 1"
        exit 1
    fi
    
    if [[ ${ARRAY_LENGTH} -gt 1000 ]]; then
        log_error "Array length must not exceed 1000"
        exit 1
    fi
    
    # Validate numeric parameters
    if ! [[ "${MAX_WAIT}" =~ ^[0-9]+$ ]]; then
        log_error "Max wait must be a positive integer"
        exit 1
    fi
    
    if ! [[ "${INTERVAL}" =~ ^[0-9]+$ ]]; then
        log_error "Interval must be a positive integer"
        exit 1
    fi
}

# === MAIN EXECUTION ===

main() {
    trap cleanup EXIT
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate prerequisites
    if ! validate_prerequisites; then
        exit 1
    fi
    
    # Execute orchestration pipeline
    echo ""
    log_info "=========================================="
    log_info "  WORKFLOW ORCHESTRATION STARTING"
    log_info "=========================================="
    log_info "Input String: ${INPUT_STRING}"
    log_info "Array Length: ${ARRAY_LENGTH}"
    log_info "Workflow: ${WORKFLOW_FILE}"
    log_info "Max Wait: ${MAX_WAIT}s"
    log_info "Polling Interval: ${INTERVAL}s"
    echo ""
    
    # Step 1: Trigger
    step_1_trigger_workflow "${WORKFLOW_FILE}" "${INPUT_STRING}" "${ARRAY_LENGTH}" || exit $?
    echo ""
    
    # Step 2: Correlate
    step_2_correlate_workflow || exit $?
    echo ""
    
    # Step 3: Wait
    step_3_wait_for_completion "${MAX_WAIT}" "${INTERVAL}" || exit $?
    echo ""
    
    # Step 4: Fetch logs
    step_4_fetch_logs || exit $?
    echo ""
    
    # Step 5: List artifacts
    step_5_list_artifacts || exit $?
    echo ""
    
    # Step 6: Download artifacts
    step_6_download_artifact || exit $?
    echo ""
    
    # Step 7: Extract results
    step_7_extract_results || exit $?
    
    # Final summary
    echo ""
    log_info "=========================================="
    log_info "  ORCHESTRATION COMPLETED SUCCESSFULLY"
    log_info "=========================================="
    
    load_state
    echo ""
    echo "Summary:"
    echo "  Correlation ID:  ${CORRELATION_ID}"
    echo "  Run ID:          ${RUN_ID}"
    echo "  Workflow Status: ${WORKFLOW_STATUS}"
    echo "  Logs Directory:  ${LOGS_DIR}"
    echo "  Result File:     ${RESULT_FILE}"
    echo "  Artifact Name:   ${ARTIFACT_NAME}"
    echo ""
    
    if [[ "${KEEP_STATE}" == "true" ]]; then
        echo "State file: ${STATE_FILE}"
        echo ""
    fi
    
    exit 0
}

main "$@"

