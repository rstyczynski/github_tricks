#!/usr/bin/env bash
#
# parse-implementation.sh - Parse Sprint implementation file to extract structured data
#
# Usage: ./scripts/parse-implementation.sh <sprint_implementation_file>
#
# Output: JSON with Sprint number, status, backlog items, features
#

set -euo pipefail

SPRINT_FILE="${1:-}"

if [[ -z "$SPRINT_FILE" ]]; then
  echo "Error: Sprint implementation file required" >&2
  echo "Usage: $0 <sprint_implementation_file>" >&2
  exit 1
fi

if [[ ! -f "$SPRINT_FILE" ]]; then
  echo "Error: File not found: $SPRINT_FILE" >&2
  exit 1
fi

# Extract Sprint number from filename (macOS compatible)
SPRINT_NO=$(echo "$SPRINT_FILE" | sed -E 's/.*sprint_([0-9]+).*/\1/' || echo "unknown")

# Extract status (look for "## Status:" line)
STATUS=$(grep -m1 "^## Status:" "$SPRINT_FILE" | sed 's/^## Status: //' | sed 's/ ✅//' | tr -d '\n' || echo "unknown")

# Extract Backlog Items (GH-* pattern) - unique sorted (macOS compatible)
BACKLOG_ITEMS=$(grep -oE 'GH-[0-9]+(\.[0-9]+)*' "$SPRINT_FILE" | sort -u | tr '\n' ',' | sed 's/,$//')

# Extract key features from implementation summary
# Look for bullet points under "Key Features:" or similar sections
FEATURES=$(grep -A 10 "^\*\*Key Features\*\*:" "$SPRINT_FILE" | grep "^- " | sed 's/^- //' | head -5 | jq -R -s -c 'split("\n") | map(select(length > 0))' || echo '[]')

# Count tests (look for test status tables or PASS/FAIL markers)
TEST_COUNT=$(grep -c "✅ Tested" "$SPRINT_FILE" || echo "0")

# Output JSON
cat <<EOF
{
  "sprint": $SPRINT_NO,
  "status": "$STATUS",
  "backlog_items": "$(echo "$BACKLOG_ITEMS" | sed 's/"/\\"/g')",
  "features": $FEATURES,
  "test_count": $TEST_COUNT,
  "file": "$SPRINT_FILE"
}
EOF
