#!/usr/bin/env bash

set -uo pipefail

if [[ -z "${WEBHOOK_URL:-}" ]]; then
  echo "WEBHOOK_URL is required" >&2
  exit 1
fi

if [[ -z "${RUN_ID:-}" ]]; then
  echo "RUN_ID is required" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

message="Hello from ${RUN_ID}.notify"
payload_file="${tmp_dir}/payload.json"
response_body="${tmp_dir}/response.json"
curl_log="${tmp_dir}/curl.log"

if [[ -n "${CORRELATION_ID:-}" ]]; then
  echo "Using correlation ID: ${CORRELATION_ID}"
  cat > "${payload_file}" <<EOF
{
  "message": "${message}",
  "correlationId": "${CORRELATION_ID}"
}
EOF
else
  cat > "${payload_file}" <<EOF
{
  "message": "${message}"
}
EOF
fi

echo "Invoking webhook ${WEBHOOK_URL}"

http_code=$(
  curl \
    --request POST \
    --header "Content-Type: application/json" \
    --data @"${payload_file}" \
    --retry 5 \
    --retry-all-errors \
    --max-time 5 \
    --connect-timeout 5 \
    --silent \
    --show-error \
    --write-out "%{http_code}" \
    --output "${response_body}" \
    "${WEBHOOK_URL}" 2>"${curl_log}"
)
curl_exit=$?

if [[ ${curl_exit} -ne 0 ]]; then
  echo "::warning::Webhook invocation exited with status ${curl_exit}. See log output below."
  cat "${curl_log}"
fi

if [[ -z "${http_code}" ]]; then
  http_code="000"
fi

summary_file="notification-summary.md"
{
  echo "### Webhook notification"
  echo ""
  echo "- Webhook URL: ${WEBHOOK_URL}"
  echo "- Message: ${message}"
  if [[ -n "${CORRELATION_ID:-}" ]]; then
    echo "- Correlation ID: ${CORRELATION_ID}"
  else
    echo "- Correlation ID: (not provided)"
  fi
  echo "- HTTP status: ${http_code}"
  if [[ -s "${response_body}" ]]; then
    echo ""
    echo "Response body:"
    echo ""
    sed 's/^/    /' "${response_body}"
  fi
} > "${summary_file}"

echo "Webhook HTTP status: ${http_code}"
echo "Summary written to ${summary_file}"

exit 0
