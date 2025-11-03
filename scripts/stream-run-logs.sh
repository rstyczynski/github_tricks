#!/usr/bin/env bash

set -euo pipefail

cat <<'EOF' >&2
Realtime streaming of GitHub Actions logs is not supported by the API.
Use scripts/fetch-run-logs.sh after the run completes to download logs.
EOF
exit 1
