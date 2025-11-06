# Sprint 10 - Design

## GH-13. Caller gets data produced by a workflow

Status: Proposed

### Requirement Analysis

**Requirement:** Caller uses GitHub REST API to get data produced by a workflow. The workflow returns simple data structure derived from parameters passed by a caller.

**Constraints:**
- NOT about artifacts
- Simple data structures only
- Synchronous interfaces (from caller perspective)
- GitHub REST API exclusively

### Feasibility Analysis

**GitHub API Capability:**
✓ Job outputs are supported via workflow syntax and REST API
✓ Proven in Sprint 8/9: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs` returns job outputs
✓ Job outputs can contain JSON strings

**Technical Approach:**
The solution leverages GitHub Actions job outputs mechanism:
1. Workflow accepts typed inputs via `workflow_dispatch`
2. Job steps process inputs and set outputs via `$GITHUB_OUTPUT`
3. Job outputs are exposed via GitHub REST API
4. Client retrieves outputs after workflow completion

### Design

#### 1. Workflow: `data-processor.yml`

**Purpose:** Accept input parameters, process them, and return derived data structure

**Inputs:**
- `operation` (required, string): Operation to perform (add, multiply, concat)
- `value1` (required, string): First operand
- `value2` (required, string): Second operand
- `correlation_id` (optional, string): Correlation tracking ID

**Processing Logic:**
- Parse input values
- Perform specified operation
- Generate result structure with metadata
- Set as job output

**Output Structure:**
```json
{
  "operation": "add",
  "inputs": {
    "value1": "10",
    "value2": "20"
  },
  "result": 30,
  "timestamp": "2025-11-06T12:00:00Z",
  "run_id": "1234567890"
}
```

**Workflow YAML:**
```yaml
name: Data Processor

run-name: Data Processor${{ inputs.correlation_id != '' && format(' ({0})', inputs.correlation_id) || '' }}

on:
  workflow_dispatch:
    inputs:
      operation:
        description: "Operation: add, multiply, concat"
        required: true
        type: string
      value1:
        description: "First operand"
        required: true
        type: string
      value2:
        description: "Second operand"
        required: true
        type: string
      correlation_id:
        description: "Optional correlation token"
        required: false
        default: ""
        type: string

jobs:
  process:
    runs-on: ubuntu-latest
    outputs:
      result_data: ${{ steps.compute.outputs.result_data }}
    steps:
      - name: Process inputs
        id: compute
        run: |
          # Process based on operation
          operation="${{ inputs.operation }}"
          value1="${{ inputs.value1 }}"
          value2="${{ inputs.value2 }}"
          timestamp=$(date --iso-8601=seconds)

          case "$operation" in
            add)
              result=$((value1 + value2))
              ;;
            multiply)
              result=$((value1 * value2))
              ;;
            concat)
              result="${value1}${value2}"
              ;;
            *)
              echo "Error: Unknown operation $operation"
              exit 1
              ;;
          esac

          # Build JSON output
          result_json=$(jq -n \
            --arg op "$operation" \
            --arg v1 "$value1" \
            --arg v2 "$value2" \
            --arg res "$result" \
            --arg ts "$timestamp" \
            --arg rid "$GITHUB_RUN_ID" \
            '{
              operation: $op,
              inputs: {value1: $v1, value2: $v2},
              result: $res,
              timestamp: $ts,
              run_id: $rid
            }')

          echo "result_data=$result_json" >> "$GITHUB_OUTPUT"
          echo "Result: $result_json"
```

#### 2. Client Script: `get-workflow-output.sh`

**Purpose:** Retrieve workflow output data via GitHub REST API

**Features:**
- Multiple input methods: `--run-id`, `--correlation-id`, stdin JSON
- JSON and human-readable output formats
- Integration with existing Sprint 1 correlation metadata
- Reuses `scripts/lib/run-utils.sh` utilities
- Error handling for incomplete/failed workflows

**Usage:**
```bash
# Direct run ID
scripts/get-workflow-output.sh --run-id 1234567890

# Via correlation ID
scripts/get-workflow-output.sh --correlation-id <uuid> --runs-dir runs

# From stdin (pipeline)
scripts/trigger-and-track.sh --workflow data-processor.yml --json-only | \
  scripts/get-workflow-output.sh

# JSON output
scripts/get-workflow-output.sh --run-id 1234567890 --json
```

**Implementation approach:**
- Source `scripts/lib/run-utils.sh` for run_id resolution
- Call `gh api /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`
- Extract `.jobs[0].outputs.result_data` field
- Parse and format output
- Handle errors (run not found, workflow failed, no outputs)

#### 3. Integration Testing Script: `test-workflow-output.sh`

**Purpose:** Automated E2E testing

**Test cases:**
1. Add operation: 10 + 20 = 30
2. Multiply operation: 5 * 7 = 35
3. Concat operation: "hello" + "world" = "helloworld"
4. Invalid operation (expect failure)
5. Correlation ID tracking
6. Pipeline composition

**Test flow:**
1. Trigger workflow with test inputs
2. Wait for completion
3. Retrieve output
4. Validate result structure and correctness
5. Report pass/fail

### Success Criteria

1. ✓ Workflow accepts typed inputs (operation, value1, value2, correlation_id)
2. ✓ Workflow processes inputs and produces JSON output
3. ✓ Output available via GitHub REST API without artifacts
4. ✓ Client script retrieves output reliably
5. ✓ Solution reuses Sprint 1 correlation patterns
6. ✓ Solution reuses Sprint 8/9 job data retrieval patterns
7. ✓ actionlint validation passes
8. ✓ E2E tests pass on real GitHub infrastructure
9. ✓ Documentation includes usage examples
10. ✓ Error handling for edge cases

### Compatibility

**Sprint 1 patterns:**
- `correlation_id` input parameter
- Run-name format: `Data Processor (<correlation_id>)`
- Metadata storage in `runs/<correlation_id>/metadata.json`

**Sprint 8/9 patterns:**
- Job outputs via GitHub API
- Multiple input methods (run_id, correlation_id, stdin)
- JSON output for pipeline composition
- Shared utilities from `scripts/lib/run-utils.sh`

**Sprint 3 patterns:**
- Wait for completion before data retrieval
- Error handling for failed/incomplete runs

### Testing Plan

**Static validation:**
```bash
actionlint .github/workflows/data-processor.yml
shellcheck scripts/get-workflow-output.sh
```

**E2E tests (real GitHub):**
```bash
# Test 1: Add operation
scripts/test-workflow-output.sh --operation add --value1 10 --value2 20

# Test 2: Multiply operation
scripts/test-workflow-output.sh --operation multiply --value1 5 --value2 7

# Test 3: String concatenation
scripts/test-workflow-output.sh --operation concat --value1 hello --value2 world

# Test 4: Invalid operation (expect failure)
scripts/test-workflow-output.sh --operation invalid --value1 1 --value2 2

# Test 5: Full pipeline with correlation
export WEBHOOK_URL=https://webhook.site/test
result=$(scripts/trigger-and-track.sh \
  --webhook-url "$WEBHOOK_URL" \
  --workflow data-processor.yml \
  --input operation=add \
  --input value1=15 \
  --input value2=25 \
  --store-dir runs \
  --json-only)
echo "$result" | scripts/get-workflow-output.sh --json
```

### Error Handling

**Workflow errors:**
- Invalid operation: Exit 1, job fails, no output
- Non-numeric values for add/multiply: Bash arithmetic error
- Missing required inputs: GitHub prevents dispatch

**Client errors:**
- Run not found: Clear error message
- Workflow still running: Wait or inform user
- Workflow failed: Report failure, no output
- No outputs: Inform user (workflow may not support outputs)

### Documentation

**User README sections:**
1. Overview: What the workflow does
2. Usage: How to trigger and retrieve data
3. Examples: Common use cases
4. Output format: JSON structure specification
5. Error handling: Common issues and solutions
6. Integration: How to use with existing scripts

### Open Questions

None. Design is complete and ready for implementation.
