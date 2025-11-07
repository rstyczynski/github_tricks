#!/usr/bin/env bash
#
# scan-sprint-artifacts.sh - Scan progress/ for Sprint implementation files
#
# Usage: ./scripts/scan-sprint-artifacts.sh
#
# Output: List of sprint_*_implementation.md files with Sprint numbers, sorted by Sprint number
#

set -euo pipefail

# Find all Sprint implementation files and sort by Sprint number
find progress/ -name "sprint_*_implementation.md" 2>/dev/null | \
  sort -V | \
  while read -r file; do
    # Extract Sprint number (macOS compatible)
    sprint_no=$(echo "$file" | sed -E 's/.*sprint_([0-9]+).*/\1/')
    echo "$sprint_no:$file"
  done
