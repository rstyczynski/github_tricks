#!/usr/bin/env bash
set -euo pipefail

# Download workflow artifacts using REST API with curl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "$SCRIPT_DIR/lib/run-utils.sh"

# Defaults
TOKEN_FILE="./secrets/github_token"
REPO=""
ARTIFACT_ID=""
RUN_ID=""
CORRELATION_ID=""
RUNS_DIR="runs"
OUTPUT_DIR="artifacts"
NAME_FILTER=""
EXTRACT=false
DOWNLOAD_ALL=false

show_help() {
  cat <<'EOF'
Usage: download-artifact-curl.sh --artifact-id <id> [OPTIONS]
       download-artifact-curl.sh --run-id <id> --all [OPTIONS]
       download-artifact-curl.sh --correlation-id <uuid> --all [OPTIONS]

Download workflow artifacts using REST API (curl).

SINGLE ARTIFACT MODE:
  --artifact-id <id>        Download single artifact by artifact ID (numeric)

BULK DOWNLOAD MODE:
  --run-id <id> --all       Download all artifacts for workflow run
  --correlation-id <uuid> --all  Load run_id from metadata, download all artifacts

OPTIONS:
  --extract                 Extract ZIP archives after download (default: keep as ZIP)
  --output-dir <dir>        Output directory for downloads (default: artifacts)
  --name-filter <pattern>   Filter artifacts by name when using --all (partial match, case-sensitive)
  --runs-dir <dir>          Base directory for metadata (default: runs)
  --repo <owner/repo>       Repository in owner/repo format (auto-detected if omitted)
  --token-file <path>       GitHub token file (default: ./secrets/github_token)
  --help                    Show this help message

EXAMPLES:
  # Download single artifact
  download-artifact-curl.sh --artifact-id 123456

  # Download single artifact and extract
  download-artifact-curl.sh --artifact-id 123456 --extract

  # Download all artifacts for run
  download-artifact-curl.sh --run-id 1234567890 --all

  # Download all artifacts for run and extract
  download-artifact-curl.sh --run-id 1234567890 --all --extract

  # Download filtered artifacts
  download-artifact-curl.sh --run-id 1234567890 --all --name-filter "build-"

  # Download artifacts using correlation ID
  download-artifact-curl.sh --correlation-id <uuid> --all --extract
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
  else
    printf 'Error: No run ID provided (use --run-id or --correlation-id with --all)\n' >&2
    exit 1
  fi

  printf '%s' "${resolved_id}"
}

get_artifact_metadata() {
  local owner_repo="$1"
  local artifact_id="$2"
  local token="$3"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  local response http_code
  response=$(curl -sS -w '\n%{http_code}' -L \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/artifacts/$artifact_id" 2>/dev/null || printf '\n000')

  http_code=$(echo "$response" | tail -n1)
  local response_body
  response_body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    return 1
  fi

  printf '%s' "$response_body"
  return 0
}

download_artifact() {
  local owner_repo="$1"
  local artifact_id="$2"
  local output_file="$3"
  local token="$4"

  local owner repo
  IFS='/' read -r owner repo <<< "$owner_repo"

  # Download with redirect following
  local http_code
  http_code=$(curl -sS -L -w '%{http_code}' -o "$output_file" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner/$repo/actions/artifacts/$artifact_id/zip" 2>/dev/null || printf '000')

  case "$http_code" in
    200)
      # Success
      ;;
    404)
      printf 'Error: Artifact %s not found\n' "$artifact_id" >&2
      return 1
      ;;
    410)
      printf 'Error: Artifact %s expired\n' "$artifact_id" >&2
      return 1
      ;;
    401)
      printf 'Error: Authentication failed. Check token permissions.\n' >&2
      return 1
      ;;
    403)
      printf 'Error: Insufficient permissions to download artifact\n' >&2
      return 1
      ;;
    *)
      printf 'Error: Download failed (HTTP %s)\n' "$http_code" >&2
      return 1
      ;;
  esac

  # Validate ZIP file
  if ! command -v unzip >/dev/null 2>&1; then
    printf 'Warning: unzip not available, skipping ZIP validation\n' >&2
    return 0
  fi

  if ! unzip -t "$output_file" >/dev/null 2>&1; then
    printf 'Error: Downloaded file is not a valid ZIP archive\n' >&2
    rm -f "$output_file"
    return 1
  fi

  return 0
}

extract_artifact() {
  local zip_file="$1"
  local output_dir="$2"

  if [[ ! -f "$zip_file" ]]; then
    printf 'Error: ZIP file not found: %s\n' "$zip_file" >&2
    return 1
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    printf 'Error: unzip command not available\n' >&2
    return 1
  fi

  # Create output directory
  mkdir -p "$output_dir"

  # Extract ZIP
  if ! unzip -q -o "$zip_file" -d "$output_dir" 2>&1; then
    printf 'Error: Failed to extract ZIP archive: %s\n' "$zip_file" >&2
    return 1
  fi

  return 0
}

save_artifact_metadata() {
  local artifact_metadata="$1"
  local output_dir="$2"
  local extracted="$3"

  mkdir -p "$output_dir"
  local metadata_file="$output_dir/metadata.json"

  # Add download timestamp and extraction status
  local downloaded_at
  downloaded_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "unknown")"

  echo "$artifact_metadata" | jq \
    --arg downloaded_at "$downloaded_at" \
    --argjson extracted "$extracted" \
    '. + {downloaded_at: $downloaded_at, extracted: $extracted}' \
    > "$metadata_file"
}

download_single_artifact() {
  local owner_repo="$1"
  local artifact_id="$2"
  local token="$3"
  local output_dir="$4"
  local extract="$5"

  # Get artifact metadata
  local metadata
  if ! metadata="$(get_artifact_metadata "$owner_repo" "$artifact_id" "$token")"; then
    printf 'Error: Failed to get metadata for artifact %s\n' "$artifact_id" >&2
    return 1
  fi

  local artifact_name
  artifact_name=$(echo "$metadata" | jq -r '.name // "artifact"')

  printf 'Downloading artifact: %s (ID: %s)\n' "$artifact_name" "$artifact_id"

  # Download artifact
  local artifact_zip="$output_dir/$artifact_name.zip"
  local artifact_dir="$output_dir/$artifact_name"

  if ! download_artifact "$owner_repo" "$artifact_id" "$artifact_zip" "$token"; then
    return 1
  fi

  printf '  Downloaded to: %s\n' "$artifact_zip"

  # Extract if requested
  if [[ "$extract" == "true" ]]; then
    if extract_artifact "$artifact_zip" "$artifact_dir"; then
      printf '  Extracted to: %s\n' "$artifact_dir"
      save_artifact_metadata "$metadata" "$artifact_dir" "true"
    else
      printf '  Warning: Extraction failed, keeping ZIP file\n' >&2
      save_artifact_metadata "$metadata" "$artifact_dir" "false"
      return 1
    fi
  else
    save_artifact_metadata "$metadata" "$artifact_dir" "false"
  fi

  return 0
}

download_all_artifacts() {
  local owner_repo="$1"
  local run_id="$2"
  local token="$3"
  local output_dir="$4"
  local extract="$5"
  local name_filter="$6"

  # Call Sprint 16's list-artifacts-curl.sh to get artifact list
  local list_cmd=("$SCRIPT_DIR/list-artifacts-curl.sh" "--run-id" "$run_id" "--repo" "$owner_repo" "--token-file" "$TOKEN_FILE" "--json")

  if [[ -n "$name_filter" ]]; then
    list_cmd+=("--name-filter" "$name_filter")
  fi

  local artifacts_json
  if ! artifacts_json=$("${list_cmd[@]}" 2>/dev/null); then
    printf 'Error: Failed to list artifacts for run %s\n' "$run_id" >&2
    return 1
  fi

  # Extract artifact count
  local artifact_count
  artifact_count=$(echo "$artifacts_json" | jq -r '.total_count // 0')

  if [[ "$artifact_count" -eq 0 ]]; then
    printf 'No artifacts found for run %s\n' "$run_id"
    return 0
  fi

  printf 'Downloading %d artifact(s)...\n\n' "$artifact_count"

  # Download each artifact
  local i=0
  local failed_count=0
  while [[ $i -lt $artifact_count ]]; do
    local artifact_id artifact_name
    artifact_id=$(echo "$artifacts_json" | jq -r ".artifacts[$i].id")
    artifact_name=$(echo "$artifacts_json" | jq -r ".artifacts[$i].name")

    printf '[%d/%d] Downloading artifact: %s (ID: %s)\n' \
      $((i + 1)) "$artifact_count" "$artifact_name" "$artifact_id"

    # Download single artifact
    local artifact_dir="$output_dir/$artifact_name"
    local artifact_zip="$output_dir/$artifact_name.zip"

    if ! download_artifact "$owner_repo" "$artifact_id" "$artifact_zip" "$token"; then
      printf '  Warning: Failed to download artifact %s\n\n' "$artifact_name" >&2
      failed_count=$((failed_count + 1))
      i=$((i + 1))
      continue
    fi

    printf '  Downloaded to: %s\n' "$artifact_zip"

    # Get metadata for this artifact
    local metadata
    metadata=$(echo "$artifacts_json" | jq -r ".artifacts[$i]")

    # Extract if requested
    if [[ "$extract" == "true" ]]; then
      if extract_artifact "$artifact_zip" "$artifact_dir"; then
        printf '  Extracted to: %s\n' "$artifact_dir"
        save_artifact_metadata "$metadata" "$artifact_dir" "true"
      else
        printf '  Warning: Extraction failed, keeping ZIP file\n' >&2
        save_artifact_metadata "$metadata" "$artifact_dir" "false"
      fi
    else
      save_artifact_metadata "$metadata" "$artifact_dir" "false"
    fi

    printf '\n'
    i=$((i + 1))
  done

  local success_count=$((artifact_count - failed_count))
  printf 'Downloaded %d of %d artifact(s) to: %s\n' "$success_count" "$artifact_count" "$output_dir"

  if [[ $failed_count -gt 0 ]]; then
    printf 'Warning: %d artifact(s) failed to download\n' "$failed_count" >&2
    return 1
  fi

  return 0
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --artifact-id)
        ARTIFACT_ID="$2"
        shift 2
        ;;
      --run-id)
        RUN_ID="$2"
        shift 2
        ;;
      --correlation-id)
        CORRELATION_ID="$2"
        shift 2
        ;;
      --all)
        DOWNLOAD_ALL=true
        shift
        ;;
      --extract)
        EXTRACT=true
        shift
        ;;
      --output-dir)
        OUTPUT_DIR="$2"
        shift 2
        ;;
      --name-filter)
        NAME_FILTER="$2"
        shift 2
        ;;
      --runs-dir)
        RUNS_DIR="$2"
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

  # Validate input mode
  if [[ -z "$ARTIFACT_ID" && "$DOWNLOAD_ALL" != "true" ]]; then
    printf 'Error: Must specify --artifact-id or --run-id/--correlation-id with --all\n' >&2
    show_help >&2
    exit 2
  fi

  if [[ -n "$ARTIFACT_ID" && "$DOWNLOAD_ALL" == "true" ]]; then
    printf 'Error: Cannot use --artifact-id with --all\n' >&2
    show_help >&2
    exit 2
  fi

  # Load token
  local token
  token="$(load_token "$TOKEN_FILE")"

  # Resolve repository
  local owner_repo
  owner_repo="$(resolve_repository)"

  # Create output directory
  mkdir -p "$OUTPUT_DIR"

  # Download artifacts
  if [[ -n "$ARTIFACT_ID" ]]; then
    # Single artifact mode
    if ! download_single_artifact "$owner_repo" "$ARTIFACT_ID" "$token" "$OUTPUT_DIR" "$EXTRACT"; then
      exit 1
    fi
  else
    # Bulk download mode
    local run_id
    run_id="$(resolve_run_id)"
    run_id="$(printf '%s' "${run_id}" | tr -d '[:space:]')"

    if ! download_all_artifacts "$owner_repo" "$run_id" "$token" "$OUTPUT_DIR" "$EXTRACT" "$NAME_FILTER"; then
      exit 1
    fi
  fi
}

main "$@"
