#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_SCRIPT="${SCRIPT_DIR}/../scripts/benchmark-log-retrieval.sh"
OUTPUT_FILE="${SCRIPT_DIR}/log-results.json"

if [[ ! -x "${BENCHMARK_SCRIPT}" ]]; then
  echo "Error: benchmark script not found at ${BENCHMARK_SCRIPT}" >&2
  exit 1
fi

if [[ -z "${WEBHOOK_URL:-}" ]]; then
  echo "Error: WEBHOOK_URL environment variable is required" >&2
  echo "Get a webhook endpoint from https://webhook.site and run:" >&2
  echo "  export WEBHOOK_URL=https://webhook.site/<your-id>" >&2
  exit 1
fi

echo "Running GH-5.1: Log retrieval timing benchmark"
echo "Output will be written to: ${OUTPUT_FILE}"
echo ""
echo "Note: This benchmark takes approximately 15-20 minutes to complete (10 workflow runs)"
echo ""

"${BENCHMARK_SCRIPT}" \
  --runs 10 \
  --webhook-url "${WEBHOOK_URL}" \
  --output "${OUTPUT_FILE}"

echo ""
echo "Benchmark complete. Results saved to: ${OUTPUT_FILE}"
echo "View statistics with: jq '.statistics' ${OUTPUT_FILE}"
