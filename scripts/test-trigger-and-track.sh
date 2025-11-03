#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRIGGER_SCRIPT="${SCRIPT_DIR}/trigger-and-track.sh"

if [[ ! -x "${TRIGGER_SCRIPT}" ]]; then
  echo "Missing executable trigger script at ${TRIGGER_SCRIPT}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to parse JSON output" >&2
  exit 1
fi

RESULT="$("${TRIGGER_SCRIPT}" "$@")"
echo "${RESULT}"

run_id="$(jq -r '.run_id // empty' <<<"${RESULT}")"
correlation_id="$(jq -r '.correlation_id // empty' <<<"${RESULT}")"

if [[ -z "${run_id}" || -z "${correlation_id}" ]]; then
  echo "Failed to parse run_id/correlation_id from trigger output" >&2
  exit 1
fi

echo "Watching workflow run ${run_id} until completion..."
gh run watch "${run_id}" --exit-status >/dev/null

run_info="$(gh run view "${run_id}" --json name,conclusion,headBranch,status)"
run_name="$(jq -r '.name // ""' <<<"${run_info}")"
run_status="$(jq -r '.status // ""' <<<"${run_info}")"
run_conclusion="$(jq -r '.conclusion // ""' <<<"${run_info}")"

if [[ "${run_name}" != *"${correlation_id}"* ]]; then
  echo "Run name '${run_name}' does not contain correlation id '${correlation_id}'" >&2
  exit 1
fi

echo "Run status: ${run_status}, conclusion: ${run_conclusion}"
if [[ "${run_conclusion}" != "success" ]]; then
  echo "Workflow run did not succeed (conclusion: ${run_conclusion})" >&2
  exit 1
fi

echo "Correlation verified successfully."
