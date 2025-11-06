#!/usr/bin/env bash
set -euo pipefail

# View workflow job phases using GitHub REST API via curl, mirroring view-run-jobs.sh output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "$SCRIPT_DIR/lib/run-utils.sh"

# Defaults
TOKEN_FILE=".secrets/token"
RUNS_DIR="runs"
OUTPUT_FORMAT="table"
VERBOSE=false
WATCH=false
RUN_ID=""
CORRELATION_ID=""
REPO=""

show_help() {
  cat <<'EOF'
Usage: view-run-jobs-curl.sh [OPTIONS]

Retrieve workflow job phases with status using GitHub REST API (curl).

INPUT (first match wins):
  --run-id <id>           Workflow run ID (numeric)
  --correlation-id <uuid> Load run_id from stored metadata
  stdin                   JSON from trigger-and-track.sh

OPTIONS:
  --runs-dir <dir>        Base directory for metadata (default: runs)
  --repo <owner/repo>     Repository (auto-detected if omitted)
  --token-file <path>     GitHub token file (default: .secrets/token)
  --json                  Output JSON format
  --verbose               Include step-level details
  --watch                 Poll for updates until completion (3s interval)
  --help                  Show this help message

EXAMPLES:
  view-run-jobs-curl.sh --run-id 1234567890
  view-run-jobs-curl.sh --correlation-id <uuid> --runs-dir runs --watch
  trigger-and-track.sh ... --json-only | view-run-jobs-curl.sh --json
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
  elif [[ -t 0 ]]; then
    printf 'Enter run ID: ' >&2
    read -r resolved_id
    if [[ -z "${resolved_id}" ]]; then
      printf 'Error: Run ID is required\n' >&2
      exit 1
    fi
  else
    printf 'Error: No run ID provided (use --run-id, --correlation-id, or pipe JSON via stdin)\n' >&2
    exit 1
  fi

  printf '%s' "${resolved_id}"
}

api_request() {
  local url="$1"
  local token="$2"
  curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$url" || printf '\n000'
}

handle_http_error() {
  local http_code="$1"
  local body="$2"
  local context="$3"
  case "$http_code" in
    401)
      printf 'Error: Unauthorized when accessing %s. Check token permissions.\n' "$context" >&2
      ;;
    403)
      local message
      message="$(echo "$body" | jq -r '.message // empty' 2>/dev/null || true)"
      if [[ "$message" == *"rate limit"* ]]; then
        printf 'Error: Rate limit exceeded when accessing %s.\n' "$context" >&2
      else
        printf 'Error: Forbidden when accessing %s.\n' "$context" >&2
      fi
      ;;
    404)
      printf 'Error: Resource not found: %s\n' "$context" >&2
      ;;
    000)
      printf 'Error: Network failure when accessing %s\n' "$context" >&2
      ;;
    *)
      local message
      message="$(echo "$body" | jq -r '.message // empty' 2>/dev/null || true)"
      if [[ -n "$message" ]]; then
        printf 'Error: HTTP %s when accessing %s: %s\n' "$http_code" "$context" "$message" >&2
      else
        printf 'Error: HTTP %s when accessing %s\n' "$http_code" "$context" >&2
      fi
      ;;
  esac
  exit 1
}

fetch_run_json() {
  local owner="$1"
  local repo="$2"
  local run_id="$3"
  local token="$4"
  local url="https://api.github.com/repos/${owner}/${repo}/actions/runs/${run_id}"
  local max_retries=3
  local attempt=0
  local backoff=1

  while [[ $attempt -lt $max_retries ]]; do
    local response
    response="$(api_request "$url" "$token")"
    local http_code
    http_code="$(echo "$response" | tail -n1)"
    local body
    body="$(echo "$response" | sed '$d')"

    if [[ "$http_code" == "200" ]]; then
      printf '%s' "$body"
      return 0
    fi

    case "$http_code" in
      500|502|503|504|000)
        attempt=$((attempt + 1))
        if [[ $attempt -lt $max_retries ]]; then
          sleep "$backoff"
          backoff=$((backoff * 2))
          continue
        fi
        ;;
      *)
        handle_http_error "$http_code" "$body" "run ${run_id} in ${owner}/${repo}"
        ;;
    esac
  done

  printf 'Error: Failed to fetch run %s from %s/%s after %d attempts\n' "$run_id" "$owner" "$repo" "$max_retries" >&2
  exit 1
}

fetch_jobs_json() {
  local owner="$1"
  local repo="$2"
  local run_id="$3"
  local token="$4"
  local url="https://api.github.com/repos/${owner}/${repo}/actions/runs/${run_id}/jobs?per_page=100"
  local response
  response="$(api_request "$url" "$token")"
  local http_code
  http_code="$(echo "$response" | tail -n1)"
  local body
  body="$(echo "$response" | sed '$d')"

  if [[ "$http_code" == "200" ]]; then
    printf '%s' "$body"
    return 0
  fi

  handle_http_error "$http_code" "$body" "jobs for run ${run_id} in ${owner}/${repo}"
}

merge_run_and_jobs() {
  local run_data="$1"
  local jobs_data="$2"
  jq -s '{
    databaseId: .[0].id,
    status: .[0].status,
    conclusion: .[0].conclusion,
    name: .[0].name,
    createdAt: (.[0].run_started_at // .[0].created_at),
    url: .[0].html_url,
    jobs: (.[1].jobs // [] | map({
      databaseId: .id,
      name: .name,
      status: .status,
      conclusion: .conclusion,
      startedAt: .started_at,
      completedAt: .completed_at,
      steps: (.steps // [] | map({
        name: .name,
        status: .status,
        conclusion: .conclusion,
        number: .number,
        startedAt: .started_at,
        completedAt: .completed_at
      }))
    }))
  }' <(printf '%s' "$run_data") <(printf '%s' "$jobs_data")
}

fetch_job_data() {
  local owner="$1"
  local repo="$2"
  local run_id="$3"
  local token="$4"
  local run_json
  run_json="$(fetch_run_json "$owner" "$repo" "$run_id" "$token")"
  local jobs_json
  jobs_json="$(fetch_jobs_json "$owner" "$repo" "$run_id" "$token")"
  merge_run_and_jobs "$run_json" "$jobs_json"
}

calculate_duration() {
  local started="$1"
  local completed="$2"

  if [[ -z "${completed}" || "${completed}" == "null" ]]; then
    printf -- '-'
    return
  fi

  if [[ -z "${started}" || "${started}" == "null" ]]; then
    printf -- '-'
    return
  fi

  local start_epoch completed_epoch duration_sec

  if date --version >/dev/null 2>&1; then
    start_epoch=$(date -d "$started" +%s 2>/dev/null || echo "0")
    completed_epoch=$(date -d "$completed" +%s 2>/dev/null || echo "0")
  else
    start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${started%.*}Z" +%s 2>/dev/null || echo "0")
    completed_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${completed%.*}Z" +%s 2>/dev/null || echo "0")
  fi

  if [[ "$start_epoch" -eq 0 || "$completed_epoch" -eq 0 ]]; then
    printf -- '-'
    return
  fi

  duration_sec=$((completed_epoch - start_epoch))
  printf '%ds' "$duration_sec"
}

format_table() {
  local data="$1"
  local run_id run_name status started url

  run_id=$(echo "$data" | jq -r '.databaseId // "unknown"')
  run_name=$(echo "$data" | jq -r '.name // "unknown"')
  status=$(echo "$data" | jq -r '.status // "unknown"')
  started=$(echo "$data" | jq -r '.createdAt // "-"')
  url=$(echo "$data" | jq -r '.url // "-"')

  printf 'Run: %s (%s)\n' "$run_id" "$run_name"
  printf 'Status: %s\n' "$status"
  printf 'Started: %s\n' "$started"
  printf 'URL: %s\n' "$url"
  printf '\n'

  printf 'Job\tStatus\tConclusion\tStarted\tCompleted\n'
  echo "$data" | jq -r '.jobs[] | [
    .name,
    .status // "-",
    .conclusion // "-",
    .startedAt // "-",
    .completedAt // "-"
  ] | @tsv' | column -t -s $'\t'
}

format_verbose() {
  local data="$1"
  local run_id run_name status started url

  run_id=$(echo "$data" | jq -r '.databaseId // "unknown"')
  run_name=$(echo "$data" | jq -r '.name // "unknown"')
  status=$(echo "$data" | jq -r '.status // "unknown"')
  started=$(echo "$data" | jq -r '.createdAt // "-"')
  url=$(echo "$data" | jq -r '.url // "-"')

  printf 'Run: %s (%s)\n' "$run_id" "$run_name"
  printf 'Status: %s\n' "$status"
  printf 'Started: %s\n' "$started"
  printf 'URL: %s\n' "$url"
  printf '\n'

  echo "$data" | jq -c '.jobs[]' | while IFS= read -r job; do
    local job_name job_status job_started
    job_name=$(echo "$job" | jq -r '.name')
    job_status=$(echo "$job" | jq -r '.status // "-"')
    job_started=$(echo "$job" | jq -r '.startedAt // "-"')

    printf 'Job: %s\n' "$job_name"
    printf '  Status: %s\n' "$job_status"
    printf '  Started: %s\n' "$job_started"
    printf '\n'

    local step_count
    step_count=$(echo "$job" | jq '.steps | length')
    if [[ "$step_count" -gt 0 ]]; then
      printf '  Step\tStatus\tConclusion\tDuration\n'
      echo "$job" | jq -r '.steps[] | [
        (.number|tostring) + ". " + .name,
        .status // "-",
        .conclusion // "-",
        .startedAt // "null",
        .completedAt // "null"
      ] | @tsv' | while IFS=$'\t' read -r step_name step_status step_conclusion step_started step_completed; do
        local duration
        duration=$(calculate_duration "$step_started" "$step_completed")
        printf '  %s\t%s\t%s\t%s\n' "$step_name" "$step_status" "$step_conclusion" "$duration"
      done | column -t -s $'\t'
      printf '\n'
    fi
  done
}

format_json() {
  local data="$1"
  echo "$data" | jq '{
    run_id: (.databaseId // null),
    run_name: .name,
    status: .status,
    conclusion: .conclusion,
    started_at: .createdAt,
    completed_at: null,
    url: .url,
    jobs: [.jobs[] | {
      id: .databaseId,
      name: .name,
      status: .status,
      conclusion: .conclusion,
      started_at: .startedAt,
      completed_at: .completedAt,
      steps: [.steps[]? | {
        name: .name,
        status: .status,
        conclusion: .conclusion,
        number: .number,
        started_at: .startedAt,
        completed_at: .completedAt
      }]
    }]
  }'
}

display_data() {
  local data="$1"
  if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
    format_json "$data"
  elif [[ "${VERBOSE}" == true ]]; then
    format_verbose "$data"
  else
    format_table "$data"
  fi
}

watch_loop() {
  local owner="$1"
  local repo="$2"
  local run_id="$3"
  local token="$4"

  while true; do
    local data
    data="$(fetch_job_data "$owner" "$repo" "$run_id" "$token")"
    local run_status
    run_status=$(echo "$data" | jq -r '.status // "unknown"')

    if [[ -t 1 ]]; then
      clear
    fi

    display_data "$data"

    if [[ "$run_status" == "completed" ]]; then
      break
    fi

    sleep 3
  done
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --run-id)
      if [[ $# -lt 2 ]]; then
        printf 'Error: --run-id requires a value\n' >&2
        exit 1
      fi
      RUN_ID="$2"
      shift 2
      ;;
    --correlation-id)
      if [[ $# -lt 2 ]]; then
        printf 'Error: --correlation-id requires a value\n' >&2
        exit 1
      fi
      CORRELATION_ID="$2"
      shift 2
      ;;
    --runs-dir)
      if [[ $# -lt 2 ]]; then
        printf 'Error: --runs-dir requires a value\n' >&2
        exit 1
      fi
      RUNS_DIR="$2"
      shift 2
      ;;
    --repo)
      if [[ $# -lt 2 ]]; then
        printf 'Error: --repo requires a value in owner/repo format\n' >&2
        exit 1
      fi
      REPO="$2"
      shift 2
      ;;
    --token-file)
      if [[ $# -lt 2 ]]; then
        printf 'Error: --token-file requires a value\n' >&2
        exit 1
      fi
      TOKEN_FILE="$2"
      shift 2
      ;;
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      printf 'Use --help for usage information\n' >&2
      exit 1
      ;;
  esac
done

# Require dependencies
ru_require_command jq
ru_require_command curl

main() {
  local token
  token="$(load_token "$TOKEN_FILE")"
  local repository
  repository="$(resolve_repository)"
  local owner="${repository%%/*}"
  local repo_name="${repository#*/}"
  local run_id
  run_id="$(resolve_run_id)"

  if [[ "${WATCH}" == true ]]; then
    watch_loop "$owner" "$repo_name" "$run_id" "$token"
  else
    local data
    data="$(fetch_job_data "$owner" "$repo_name" "$run_id" "$token")"
    display_data "$data"
  fi
}

main
