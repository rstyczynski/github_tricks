#!/usr/bin/env bash
set -euo pipefail

# Wait for GitHub workflow run to complete using REST API with curl

# Defaults
TOKEN_FILE=".secrets/token"
REPO=""
RUN_ID=""
MAX_WAIT=300
INTERVAL=10
JSON_OUTPUT=false
QUIET=false

show_help() {
  cat <<'EOF'
Usage: wait-workflow-completion-curl.sh --run-id <id> [OPTIONS]

Wait for GitHub workflow run to complete using REST API (curl).

REQUIRED:
  --run-id <id>            Workflow run ID to wait for

OPTIONS:
  --repo <owner/repo>       Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>       GitHub token file (default: .secrets/token)
  --max-wait <seconds>      Maximum time to wait in seconds (default: 300)
  --interval <seconds>      Polling interval in seconds (default: 10)
  --json                    Output JSON format for programmatic use
  --quiet                   Suppress progress output (only show completion/errors)
  --help                    Show this help message

EXAMPLES:
  wait-workflow-completion-curl.sh --run-id 1234567890
  wait-workflow-completion-curl.sh --run-id 1234567890 --max-wait 600 --interval 5
  wait-workflow-completion-curl.sh --run-id 1234567890 --json
EOF
}

warn_token_permissions() {
  local token_file="$1"
  local perms=""
  if stat --version >/dev/null 2>&1; then
    perms=$(stat -c '%a' "$token_file" 2>/dev/null || true)
  else
    perms=$(stat -f '%OLp' "$token_file" 2>/dev/null || true)
  fi
  if [[ -n "$perms" && "$perms" != "600" && "$perms" -gt 600 ]]; then
    printf 'Warning: token file %s has permissions %s (recommended 600)\n' "$token_file" "$perms" >&2
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --token-file)
      TOKEN_FILE="$2"
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
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      show_help
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$RUN_ID" ]]; then
  echo "Error: --run-id is required" >&2
  show_help
  exit 1
fi

# Validate RUN_ID format
if [[ ! "$RUN_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid run-id format: '$RUN_ID' (must be numeric)" >&2
  exit 1
fi

# Validate token file
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Error: Token file not found: $TOKEN_FILE" >&2
  exit 1
fi

warn_token_permissions "$TOKEN_FILE"

# Read token
TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r' | xargs)

# Auto-detect repository if not provided
if [[ -z "$REPO" ]]; then
  REPO=$(git config --get remote.origin.url 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+)/([^/]+)(\.git)?$|\1/\2|' | sed 's|\.git$||' | tr -d '\n\r' | xargs || true)
fi

# Validate repository format
if [[ -z "$REPO" ]] || [[ "$REPO" == *".git"* ]] || [[ ! "$REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
  echo "Error: Could not determine repository. Use --repo <owner/repo>" >&2
  exit 1
fi

# Validate max-wait and interval
if [[ ! "$MAX_WAIT" =~ ^[0-9]+$ ]] || [[ "$MAX_WAIT" -le 0 ]]; then
  echo "Error: Invalid --max-wait: '$MAX_WAIT' (must be positive integer)" >&2
  exit 1
fi

if [[ ! "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -le 0 ]]; then
  echo "Error: Invalid --interval: '$INTERVAL' (must be positive integer)" >&2
  exit 1
fi

# Poll for completion
ELAPSED=0
RUN_STATUS="unknown"
CONCLUSION=""

API_URL="https://api.github.com/repos/$REPO/actions/runs/$RUN_ID"

while [ $ELAPSED -lt $MAX_WAIT ]; do
  CURL_OUTPUT=$(curl -sS \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API_URL" 2>&1)
  CURL_EXIT=$?
  
  if [ $CURL_EXIT -ne 0 ]; then
    if [[ "$JSON_OUTPUT" == "false" ]]; then
      echo "Error: curl failed with exit code $CURL_EXIT" >&2
      echo "URL: $API_URL" >&2
      echo "Output: $CURL_OUTPUT" >&2
    fi
    RUN_STATUS="error"
    break
  fi
  
  RUN_STATUS=$(echo "$CURL_OUTPUT" | jq -r '.status // "unknown"')
  CONCLUSION=$(echo "$CURL_OUTPUT" | jq -r '.conclusion // ""')
  
  if [ "$RUN_STATUS" = "completed" ]; then
    break
  fi
  
  if [[ "$QUIET" == "false" ]]; then
    printf "\rWaiting... (status: %s, elapsed: %ds)" "$RUN_STATUS" "$ELAPSED"
  fi
  
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

# Clear progress line
if [[ "$QUIET" == "false" ]]; then
  printf "\r"
fi

# Output results
if [[ "$JSON_OUTPUT" == "true" ]]; then
  if [ "$RUN_STATUS" = "completed" ]; then
    jq -n \
      --arg run_id "$RUN_ID" \
      --arg status "$RUN_STATUS" \
      --arg conclusion "$CONCLUSION" \
      --arg elapsed "$ELAPSED" \
      '{
        run_id: $run_id,
        status: $status,
        conclusion: $conclusion,
        elapsed_seconds: ($elapsed | tonumber)
      }'
  else
    jq -n \
      --arg run_id "$RUN_ID" \
      --arg status "$RUN_STATUS" \
      --arg elapsed "$ELAPSED" \
      --arg max_wait "$MAX_WAIT" \
      '{
        run_id: $run_id,
        status: $status,
        elapsed_seconds: ($elapsed | tonumber),
        max_wait_seconds: ($max_wait | tonumber),
        error: "Workflow did not complete within timeout"
      }'
    exit 1
  fi
else
  if [ "$RUN_STATUS" = "completed" ]; then
    if [[ "$QUIET" == "false" ]]; then
      echo "✓ Workflow completed! (conclusion: ${CONCLUSION:-unknown}, elapsed: ${ELAPSED}s)"
    fi
    exit 0
  else
    echo "Error: Workflow did not complete within ${MAX_WAIT} seconds (status: $RUN_STATUS)" >&2
    exit 1
  fi
fi

