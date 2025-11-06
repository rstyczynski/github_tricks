#!/bin/bash
set -e

# Step 1: Generate correlation ID
CORRELATION_ID=$(uuidgen)
echo "=== Step 1: Correlation ID ==="
echo "Correlation ID: $CORRELATION_ID"
echo ""

# Step 2: Trigger workflow
echo "=== Step 2: Triggering workflow ==="
TRIGGER_RESULT=$(scripts/trigger-workflow-curl.sh \
  --workflow artifact-producer.yml \
  --input correlation_id="$CORRELATION_ID" \
  --token-file .secrets/token \
  --json)
echo "$TRIGGER_RESULT" | jq .
echo ""

# Step 3: Wait and correlate
echo "=== Step 3: Waiting for workflow to appear (5 seconds) ==="
sleep 5

echo "=== Step 4: Getting run_id ==="
CORRELATE_RESULT=$(scripts/correlate-workflow-curl.sh \
  --correlation-id "$CORRELATION_ID" \
  --workflow artifact-producer.yml \
  --token-file .secrets/token \
  --json-only)

RUN_ID=$(echo "$CORRELATE_RESULT" | jq -r '.run_id // empty' | tr -d '\n\r' | xargs)

if [[ -z "$RUN_ID" ]] || [[ ! "$RUN_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: Failed to get valid run_id. Correlation may have failed." >&2
  echo "Correlation result: $CORRELATE_RESULT" >&2
  echo "Extracted RUN_ID: '$RUN_ID'" >&2
  exit 1
fi

echo "Run ID: $RUN_ID"
echo ""

# Step 5: Wait for completion
echo "=== Step 5: Waiting for workflow completion ==="
scripts/wait-workflow-completion-curl.sh --run-id "$RUN_ID" --token-file .secrets/token
echo ""

# Step 6: List artifacts
echo "=== Step 6: Listing artifacts ==="
ARTIFACTS_JSON=$(scripts/list-artifacts-curl.sh --run-id "$RUN_ID" --token-file .secrets/token --json)
echo "$ARTIFACTS_JSON" | jq -r '.artifacts[] | "  \(.id) - \(.name) (\(.size_in_bytes) bytes)"'
echo ""

# Step 7: Get artifact ID
ARTIFACT_ID=$(echo "$ARTIFACTS_JSON" | jq -r '.artifacts[0].id')
echo "Selected artifact ID: $ARTIFACT_ID"
echo ""

# Step 8: Download artifact
echo "=== Step 7: Downloading artifact ==="
scripts/download-artifact-curl.sh --artifact-id "$ARTIFACT_ID" --token-file .secrets/token
echo ""

# Step 9: Verify download
echo "=== Step 8: Verifying download ==="
ls -lh artifacts/test-artifact.zip
echo ""
echo "Artifact contents:"
unzip -l artifacts/test-artifact.zip
echo ""
echo "✓ Example completed successfully!"
echo "Downloaded artifact: artifacts/test-artifact.zip"

