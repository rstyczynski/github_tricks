#!/usr/bin/env bash
set -euo pipefail

# Fetch workflow logs using REST API with curl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "$SCRIPT_DIR/lib/run-utils.sh"

# Defaults
TOKEN_FILE=".secrets/token"
REPO=""
RUN_ID=""
CORRELATION_ID=""
RUNS_DIR="runs"
OUTPUT_DIR=""
JSON_OUTPUT=false

show_help() {
  cat <<'EOF'
Usage: fetch-logs-curl.sh [--run-id <id>] [--correlation-id <uuid>] [OPTIONS]

Fetch workflow logs using REST API (curl).

INPUT (first match wins):
  --run-id <id>             Workflow run ID (numeric)
  --correlation-id <uuid>   Load run_id from stored metadata
  stdin                     JSON from trigger-and-track.sh or correlate-workflow-curl.sh

OPTIONS:
  --runs-dir <dir>          Base directory for metadata (default: runs)
  --output-dir <dir>         Output directory for logs (default: runs/<correlation>/logs)
  --repo <owner/repo>       Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>       GitHub token file (default: .secrets/token)
  --json                    Output JSON format for programmatic use
  --help                    Show this help message

EXAMPLES:
  fetch-logs-curl.sh --run-id 1234567890
  fetch-logs-curl.sh --correlation-id <uuid> --runs-dir runs
  correlate-workflow-curl.sh ... --json-only | fetch-logs-curl.sh --json
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

load_token() {
  local token_file="$1"
  if [[ ! -f "$token_file" ]]; then
    printf 'Error: Token file not found: %s\n' "$token_file" >&2
    exit 1
  fi
  if [[ ! -r "$token_file" ]]; then
    printf 'Error: Token file not readable: %s\n' "$token_file" >&2
    exit 1
  fi
  warn_token_permissions "$token_file"
  local token
  token="$(tr -d '[:space:]' <"$token_file")"
  if [[ -z "$token" ]]; then
    printf 'Error: Token file is empty: %s\n' "$token_file" >&2
    exit 1
  fi
  printf '%s' "$token"
}

normalize_repo() {
  local value="$1"
  value="${value%.git}"
  printf '%s' "$value"
}

parse_github_url() {
  local url="$1"
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    printf '%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]%.git}"
  else
    printf 'Error: Cannot parse GitHub remote URL: %s\n' "$url" >&2
    exit 1
  fi
}

validate_repo_format() {
  local repo_value="$1"
  if [[ ! "$repo_value" =~ ^[^/]+/[^/]+$ ]]; then
    printf 'Error: Repository must be in owner/repo format (got: %s)\n' "$repo_value" >&2
    exit 1
  fi
}

resolve_repository() {
  if [[ -n "$REPO" ]]; then
    local cleaned
    cleaned="$(normalize_repo "$REPO")"
    validate_repo_format "$cleaned"
    printf '%s' "$cleaned"
    return 0
  fi

  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    local cleaned_env
    cleaned_env="$(normalize_repo "$GITHUB_REPOSITORY")"
    validate_repo_format "$cleaned_env"
    printf '%s' "$cleaned_env"
    return 0
  fi

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local remote_url
    remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"
    if [[ -n "$remote_url" ]]; then
      local parsed
      parsed="$(parse_github_url "$remote_url")"
      validate_repo_format "$parsed"
      printf '%s' "$parsed"
      return 0
    fi
  fi

  printf 'Error: Unable to determine repository. Use --repo owner/repo or set GITHUB_REPOSITORY.\n' >&2
  exit 1
}

resolve_run_id() {
  local resolved_id=""

  if [[ -n "${RUN_ID}" ]]; then
    resolved_id="${RUN_ID}"
  elif [[ -n "${CORRELATION_ID}" ]]; then
    resolved_id="$(ru_read_run_id_from_runs_dir "${RUNS_DIR}" "${CORRELATION_ID}")"
    if [[ -z "${resolved_id}" ]]; then
      printf 'Error: No metadata found for correlation ID %s\n' "${CORRELATION_ID}" >&2
      printf 'Expected file: %s\n' "$(ru_metadata_path_for_correlation "${RUNS_DIR}" "${CORRELATION_ID}")" >&2
      exit 1
    fi
  elif ! [[ -t 0 ]]; then
    resolved_id="$(ru_read_run_id_from_stdin)"
    if [[ -z "${resolved_id}" ]]; then
      printf 'Error: Could not extract run_id from stdin JSON\n' >&2
      exit 1
    fi
  else
    printf 'Error: No run ID provided (use --run-id, --correlation-id, or pipe JSON via stdin)\n' >&2
    exit 1
  fi

  printf '%s' "${resolved_id}"
}

check_run_completion() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id" 2>/dev/null || printf '\n000')

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    case "$http_code" in
      404)
        printf 'Error: Run %s not found\n' "$run_id" >&2
        ;;
      401)
        printf 'Error: Authentication failed. Check token permissions.\n' >&2
        ;;
      403)
        printf 'Error: Insufficient permissions to access run\n' >&2
        ;;
      *)
        printf 'Error: Failed to fetch run details (HTTP %s)\n' "$http_code" >&2
        ;;
    esac
    return 1
  fi

  local status
  status=$(echo "$response_body" | jq -r '.status // ""')

  if [[ "$status" != "completed" ]]; then
    printf 'Error: Run %s is still %s. Wait for completion before fetching logs.\n' "$run_id" "${status:-unknown}" >&2
    return 1
  fi

  printf '%s' "$response_body"
  return 0
}

download_logs() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  local output_file="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/logs" \
    -o "$output_file" 2>/dev/null || printf '\n000')

  http_code=$(echo "$response" | tail -n1)

  case "$http_code" in
    200)
      return 0
      ;;
    404)
      printf 'Error: Logs not available for run %s (may still be processing)\n' "$run_id" >&2
      return 1
      ;;
    410)
      printf 'Error: Logs expired for run %s (GitHub retention policy)\n' "$run_id" >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to download logs\n' >&2
      return 1
      ;;
    401)
      printf 'Error: Authentication failed. Check token permissions.\n' >&2
      return 1
      ;;
    *)
      printf 'Error: Failed to download logs (HTTP %s)\n' "$http_code" >&2
      return 1
      ;;
  esac
}

fetch_jobs_data() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local all_jobs="[]"
  local page=1
  local per_page=100

  while true; do
    local response http_code
    response=$(curl -sS -w '\n%{http_code}' \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$owner/$repo/actions/runs/$run_id/jobs?page=$page&per_page=$per_page" 2>/dev/null || printf '\n000')

    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
      return 1
    fi

    local jobs
    jobs=$(echo "$response_body" | jq -r '.jobs // []')
    all_jobs=$(echo "$all_jobs" "$jobs" | jq -s 'add')

    # Check if more pages
    local jobs_count
    jobs_count=$(echo "$jobs" | jq 'length')
    if [[ "$jobs_count" -lt "$per_page" ]]; then
      break
    fi
    page=$((page + 1))
  done

  echo "$all_jobs"
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id)
        RUN_ID="$2"
        shift 2
        ;;
      --correlation-id)
        CORRELATION_ID="$2"
        shift 2
        ;;
      --runs-dir)
        RUNS_DIR="$2"
        shift 2
        ;;
      --output-dir)
        OUTPUT_DIR="$2"
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
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        printf 'Error: Unknown option: %s\n' "$1" >&2
        show_help >&2
        exit 2
        ;;
    esac
  done

  ru_require_command jq
  ru_require_command unzip

  # Resolve run ID
  local run_id
  run_id="$(resolve_run_id)"
  run_id="$(printf '%s' "${run_id}" | tr -d '[:space:]')"

  # Load token
  local token
  token="$(load_token "$TOKEN_FILE")"

  # Resolve repository
  local owner_repo
  owner_repo="$(resolve_repository)"

  # Check run completion
  local run_json
  if ! run_json="$(check_run_completion "$owner_repo" "$run_id" "$token")"; then
    exit 1
  fi

  # Determine output directory
  local base_dir logs_dir
  if [[ -n "${RUNS_DIR}" && -n "${CORRELATION_ID}" ]]; then
    base_dir="${RUNS_DIR%/}/${CORRELATION_ID}"
  else
    base_dir="${OUTPUT_DIR:-runs/${run_id}}"
  fi

  mkdir -p "${base_dir}"
  logs_dir="${base_dir}/logs"
  mkdir -p "${logs_dir}"

  # Download logs
  local archive_path
  archive_path="${logs_dir}/${run_id}.zip"
  local tmp_zip
  tmp_zip="$(mktemp)"
  if ! download_logs "$owner_repo" "$run_id" "$token" "$tmp_zip"; then
    rm -f "$tmp_zip"
    exit 1
  fi
  mv "$tmp_zip" "$archive_path"

  # Extract logs (reuse logic from fetch-run-logs.sh)
  local tmp_extract
  tmp_extract="$(mktemp -d)"
  if ! unzip -q "${archive_path}" -d "${tmp_extract}"; then
    printf 'Failed to unzip log archive %s\n' "${archive_path}" >&2
    rm -rf "${tmp_extract}"
    exit 1
  fi

  # Refresh extracted log directories, keep archive
  find "${logs_dir}" -mindepth 1 -maxdepth 1 ! -name "$(basename "${archive_path}")" -exec rm -rf {} +

  local combined_path
  combined_path="${logs_dir}/combined.log"
  : >"${combined_path}"
  local manifest_file
  manifest_file="$(mktemp)"

  while IFS= read -r file_path; do
    local relative
    relative="${file_path#"${tmp_extract}/"}"
    IFS='/' read -r -a parts <<<"${relative}"
    local sanitized_parts=()
    for part in "${parts[@]}"; do
      sanitized_parts+=("$(ru_sanitize_name "${part}")")
    done
    local sanitized_relative
    sanitized_relative="$(IFS=/; printf '%s' "${sanitized_parts[*]}")"
    local dest_path
    dest_path="${logs_dir}/${sanitized_relative}"
    mkdir -p "$(dirname "${dest_path}")"
    cp "${file_path}" "${dest_path}"

    {
      printf '===== %s =====\n' "${sanitized_relative}"
      cat "${file_path}"
      printf '\n'
    } >>"${combined_path}"

    local job_key
    job_key="${sanitized_parts[0]:-root}"
    local file_size
    file_size="$(ru_file_size_bytes "${file_path}")"
    printf '{"job":"%s","relative_path":"%s","size":%s}\n' "${job_key}" "${sanitized_relative}" "${file_size}" >>"${manifest_file}"
  done < <(find "${tmp_extract}" -type f | sort)

  rm -rf "${tmp_extract}"

  # Fetch jobs data
  local jobs_json
  jobs_json="$(fetch_jobs_data "$owner_repo" "$run_id" "$token" || echo "[]")"

  local summary_path
  summary_path="${logs_dir}/logs.json"

  # Generate logs.json (reuse logic from fetch-run-logs.sh)
  python3 - "${manifest_file}" "${summary_path}" "${combined_path}" "${archive_path}" "${base_dir}" "${CORRELATION_ID}" "${run_id}" "${run_json}" "${jobs_json}" <<'PY'
import datetime
import json
import os
import sys

manifest_path, summary_path, combined_path, archive_path, base_dir, correlation, run_id, run_json_str, jobs_json_str = sys.argv[1:]

summary_path = os.path.abspath(summary_path)
combined_path = os.path.abspath(combined_path)
archive_path = os.path.abspath(archive_path)
base_dir = os.path.abspath(base_dir)

run_data = json.loads(run_json_str)
jobs_data = json.loads(jobs_json_str) if jobs_json_str else []

with open(manifest_path, "r", encoding="utf-8") as f:
    manifest_lines = f.readlines()

manifest = [json.loads(line) for line in manifest_lines if line.strip()]

summary = {
    "run_id": run_id,
    "correlation_id": correlation if correlation else None,
    "run_name": run_data.get("name", ""),
    "status": run_data.get("status", ""),
    "conclusion": run_data.get("conclusion"),
    "created_at": run_data.get("created_at", ""),
    "updated_at": run_data.get("updated_at", ""),
    "completed_at": run_data.get("updated_at", ""),
    "combined_log": combined_path,
    "archive": archive_path,
    "base_dir": base_dir,
    "jobs": []
}

for job in jobs_data:
    job_summary = {
        "id": str(job.get("id", "")),
        "name": job.get("name", ""),
        "status": job.get("status", ""),
        "conclusion": job.get("conclusion"),
        "started_at": job.get("started_at", ""),
        "completed_at": job.get("completed_at"),
        "steps": []
    }
    for step in job.get("steps", []):
        step_summary = {
            "name": step.get("name", ""),
            "status": step.get("status", ""),
            "conclusion": step.get("conclusion"),
            "number": step.get("number", 0),
            "started_at": step.get("started_at"),
            "completed_at": step.get("completed_at")
        }
        job_summary["steps"].append(step_summary)
    summary["jobs"].append(job_summary)

summary["manifest"] = manifest

with open(summary_path, "w", encoding="utf-8") as f:
    json.dump(summary, f, indent=2)

print(json.dumps(summary, indent=2))
PY

  rm -f "${manifest_file}"

  # Output result
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    cat "${summary_path}"
  else
    printf 'Logs downloaded successfully\n'
    printf 'Run ID: %s\n' "$run_id"
    printf 'Combined log: %s\n' "$combined_path"
    printf 'Logs directory: %s\n' "$logs_dir"
    printf 'Metadata: %s\n' "$summary_path"
  fi
}

main "$@"

