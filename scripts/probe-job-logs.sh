#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="${SCRIPT_DIR}/lib/run-utils.sh"
if [[ ! -f "${LIB_PATH}" ]]; then
  printf 'Unable to locate run utilities at %s\n' "${LIB_PATH}" >&2
  exit 1
fi

# shellcheck source=./lib/run-utils.sh
# shellcheck disable=SC1091
source "${LIB_PATH}"

usage() {
  cat <<'EOF'
Usage: probe-job-logs.sh [options]

Download successive snapshots of a GitHub Actions job's logs while it is running.

Options:
  --webhook-url <url>      Webhook passed to trigger-and-track.sh when launching a new run.
  --workflow <file>        Workflow file to trigger (default: .github/workflows/long-run-logger.yml).
  --ref <branch>           Git ref used when triggering the workflow.
  --runs-dir <dir>         Directory for stored run metadata (default: runs).
  --correlation-id <id>    Existing correlation ID to reuse from runs-dir metadata.
  --run-id <id>            Specific run ID to probe (skips triggering when provided).
  --interval <seconds>     Polling interval between samples (default: 5).
  --max-samples <count>    Maximum number of samples to capture (default: 12).
  --input key=value        Extra workflow inputs forwarded to trigger-and-track.sh (may repeat).
  --json                   Emit machine-readable JSON summary instead of a table.
  -h, --help               Show this help text.
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

ensure_requirements() {
  ru_require_command gh
  ru_require_command jq
  ru_require_command python3
  ru_require_command unzip
}

file_basename() {
  local path="$1"
  printf '%s\n' "$(basename "${path}")"
}

numeric_arg() {
  local value="$1"
  if [[ "${value}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "${value}"
  else
    printf 'Invalid numeric argument: %s\n' "${value}" >&2
    exit 1
  fi
}

collect_inputs=()
webhook_url="${WEBHOOK_URL:-}"
runs_dir="runs"
workflow_file=".github/workflows/long-run-logger.yml"
ref=""
correlation_id=""
run_id=""
interval=5
max_samples=12
output_json=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook-url)
      webhook_url="$2"
      shift 2
      ;;
    --workflow)
      workflow_file="$2"
      shift 2
      ;;
    --ref)
      ref="$2"
      shift 2
      ;;
    --runs-dir)
      runs_dir="$2"
      shift 2
      ;;
    --correlation-id)
      correlation_id="$2"
      shift 2
      ;;
    --run-id)
      run_id="$2"
      shift 2
      ;;
    --interval)
      interval="$(numeric_arg "$2")"
      shift 2
      ;;
    --max-samples)
      max_samples="$(numeric_arg "$2")"
      shift 2
      ;;
    --input)
      collect_inputs+=("$2")
      shift 2
      ;;
    --json)
      output_json=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

ensure_requirements

if [[ -z "${ref}" ]]; then
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    ref="$(git rev-parse --abbrev-ref HEAD)"
  else
    ref="main"
  fi
fi

mkdir -p "${runs_dir}"

metadata_file=""
metadata_json=""

if [[ -z "${run_id}" && -n "${correlation_id}" ]]; then
  metadata_file="$(ru_metadata_path_for_correlation "${runs_dir}" "${correlation_id}")"
  if [[ -f "${metadata_file}" ]]; then
    metadata_json="$(cat "${metadata_file}")"
    run_id="$(jq -r '.run_id // empty' <<<"${metadata_json}")"
  else
    log "Warning: metadata file not found for correlation ${correlation_id} in ${runs_dir}"
  fi
fi

triggered_run=false

if [[ -z "${run_id}" ]]; then
  if [[ -z "${webhook_url}" ]]; then
    webhook_url="https://example.invalid/probe"
    log "::warning::No webhook URL supplied; using placeholder ${webhook_url}"
  fi

  trigger_cmd=("${SCRIPT_DIR}/trigger-and-track.sh" "--webhook-url" "${webhook_url}" "--workflow" "${workflow_file}" "--store-dir" "${runs_dir}" "--json-only")
  [[ -n "${ref}" ]] && trigger_cmd+=("--ref" "${ref}")
  for input_pair in "${collect_inputs[@]}"; do
    trigger_cmd+=("--input" "${input_pair}")
  done

  log "Triggering workflow ${workflow_file} via trigger-and-track.sh"
  trigger_output="$("${trigger_cmd[@]}")"
  run_id="$(jq -r '.run_id' <<<"${trigger_output}")"
  correlation_id="$(jq -r '.correlation_id' <<<"${trigger_output}")"
  metadata_file="$(ru_metadata_path_for_correlation "${runs_dir}" "${correlation_id}")"
  if [[ -f "${metadata_file}" ]]; then
    metadata_json="$(cat "${metadata_file}")"
  fi
  triggered_run=true
fi

if [[ -z "${correlation_id}" ]]; then
  if [[ -n "${metadata_json}" ]]; then
    correlation_id="$(jq -r '.correlation_id // empty' <<<"${metadata_json}")"
  fi
fi

if [[ -z "${correlation_id}" ]]; then
  correlation_id="run-${run_id}"
fi

repo=""
if [[ -n "${metadata_json}" ]]; then
  repo="$(jq -r '.repo // empty' <<<"${metadata_json}")"
fi
if [[ -z "${repo}" ]]; then
  repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

log "Monitoring run ${run_id} (repo ${repo}, correlation ${correlation_id})"

safe_corr="$(ru_sanitize_name "${correlation_id}")"
samples_dir="${runs_dir%/}/${safe_corr}/job-logs"
mkdir -p "${samples_dir}"
samples_json='[]'
prev_checksum=""
sample_index=1
job_id=""

download_job_logs() {
  local job_identifier="$1"
  local destination="$2"
  if gh api "repos/${repo}/actions/jobs/${job_identifier}/logs" --method GET > "${destination}.tmp"; then
    mv "${destination}.tmp" "${destination}"
    return 0
  fi
  rm -f "${destination}.tmp"
  return 1
}

python_process_log() {
  local source_path="$1"
  local extract_root="$2"
  python3 - "${source_path}" "${extract_root}" <<'PY'
import hashlib
import io
import pathlib
import sys
import zipfile
import gzip

source = pathlib.Path(sys.argv[1])
extract_root = pathlib.Path(sys.argv[2])
extract_root.mkdir(parents=True, exist_ok=True)

data = source.read_bytes()
digest = hashlib.sha256()
total_bytes = 0
total_lines = 0
mode = "text"

def process_bytes(name: str, payload: bytes) -> None:
    global total_bytes, total_lines
    target = extract_root / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(payload)
    digest.update(name.encode("utf-8", "ignore"))
    digest.update(b"\0")
    digest.update(payload)
    total_bytes += len(payload)
    try:
        total_lines += payload.decode("utf-8", errors="ignore").count("\n")
    except Exception:
        pass

if data.startswith(b"PK\x03\x04"):
    mode = "zip"
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for member in archive.infolist():
            if member.is_dir():
                continue
            payload = archive.read(member)
            process_bytes(member.filename, payload)
elif data.startswith(b"\x1f\x8b"):
    mode = "gzip"
    payload = gzip.decompress(data)
    process_bytes("log.txt", payload)
else:
    process_bytes("log.txt", data)

print(mode, digest.hexdigest(), total_bytes, total_lines)
PY
}

while (( sample_index <= max_samples )); do
  jobs_payload_raw="$(gh api "repos/${repo}/actions/runs/${run_id}/jobs?per_page=20" --method GET --paginate 2>/dev/null || true)"
  if [[ -z "${jobs_payload_raw}" ]]; then
    jobs_payload='[]'
  else
    jobs_payload="$(printf '%s\n' "${jobs_payload_raw}" | jq -s '[.[].jobs] | add' 2>/dev/null || printf '[]')"
  fi
  if [[ -z "${jobs_payload}" || "${jobs_payload}" == "null" ]]; then
    jobs_payload='[]'
  fi

  if jq -e '.message? // empty' <<<"${jobs_payload_raw}" >/dev/null 2>&1; then
    error_message="$(jq -r '.message' <<<"${jobs_payload_raw}")"
    log "GitHub API responded with error: ${error_message}"
    break
  fi

  job_count=$(jq 'length' <<<"${jobs_payload}")

  if (( job_count == 0 )); then
    run_state="$(gh run view "${run_id}" --json status,conclusion --jq '{status, conclusion}' 2>/dev/null || echo '{}')"
    run_status="$(jq -r '.status // empty' <<<"${run_state}")"
    run_conclusion="$(jq -r '.conclusion // empty' <<<"${run_state}")"
    if [[ "${run_status}" == "completed" ]]; then
      log "Run ${run_id} is completed (conclusion: ${run_conclusion:-unknown}) but no jobs were returned by the API."
      break
    fi
    log "No jobs reported yet, waiting..."
    sleep "${interval}"
    continue
  fi

  job_info="$(jq '.[0]' <<<"${jobs_payload}")"
  job_id="$(jq -r '.id // empty' <<<"${job_info}")"
  job_status="$(jq -r '.status // empty' <<<"${job_info}")"
  job_conclusion="$(jq -r '.conclusion // empty' <<<"${job_info}")"
  job_started="$(jq -r '.started_at // empty' <<<"${job_info}")"
  job_completed="$(jq -r '.completed_at // empty' <<<"${job_info}")"

  if [[ -z "${job_id}" ]]; then
    log "Job ID not yet available; retrying..."
    sleep "${interval}"
    continue
  fi

  sample_label="$(printf 'sample_%02d' "${sample_index}")"
  artifact_path="${samples_dir}/${sample_label}.log"
  extract_dir="${samples_dir}/${sample_label}"
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  if ! download_job_logs "${job_id}" "${artifact_path}"; then
    log "Warning: failed to download logs for job ${job_id}; retrying after interval."
    sleep "${interval}"
    continue
  fi

  artifact_size="$(ru_file_size_bytes "${artifact_path}")"
  rm -rf "${extract_dir}"
  mkdir -p "${extract_dir}"

  format="text"
  checksum=""
  log_bytes=0
  log_lines=0

  if (( artifact_size > 0 )); then
    analysis="$(python_process_log "${artifact_path}" "${extract_dir}")" || analysis=""
    if [[ -n "${analysis}" ]]; then
      format="$(awk '{print $1}' <<<"${analysis}")"
      checksum="$(awk '{print $2}' <<<"${analysis}")"
      log_bytes="$(awk '{print $3}' <<<"${analysis}")"
      log_lines="$(awk '{print $4}' <<<"${analysis}")"
    fi
  fi

  new_content=false
  if [[ -n "${checksum}" && "${checksum}" != "${prev_checksum}" ]]; then
    new_content=true
  fi
  prev_checksum="${checksum}"

  sample_json=$(jq -n \
    --argjson sample "${sample_index}" \
    --arg timestamp "${timestamp}" \
    --arg job_id_str "${job_id}" \
    --arg status "${job_status}" \
    --arg conclusion "${job_conclusion}" \
    --arg started "${job_started}" \
    --arg completed "${job_completed}" \
    --arg artifact "$(file_basename "${artifact_path}")" \
    --arg artifact_size_str "${artifact_size}" \
    --arg log_bytes_str "${log_bytes}" \
    --arg log_lines_str "${log_lines}" \
    --arg checksum "${checksum}" \
    --arg format "${format}" \
    --argjson new_content "${new_content}" \
    '{
       sample: $sample,
       timestamp: $timestamp,
       job_id: (if $job_id_str != "" then ($job_id_str | tonumber) else null end),
       status: (if $status != "" then $status else null end),
       conclusion: (if $conclusion != "" then $conclusion else null end),
       started_at: (if $started != "" then $started else null end),
       completed_at: (if $completed != "" then $completed else null end),
       artifact_path: $artifact,
       artifact_size_bytes: ($artifact_size_str | tonumber),
       log_bytes: ($log_bytes_str | tonumber),
       log_lines: ($log_lines_str | tonumber),
       checksum: (if $checksum != "" then $checksum else null end),
        format: $format,
       new_content: $new_content
     }')

  samples_json="$(jq -s '.[0] + [.[1]]' <(printf '%s\n' "${samples_json}") <(printf '%s\n' "${sample_json}"))"

  if [[ "${output_json}" != true ]]; then
    printf 'Sample %-2d | status=%-11s | artifact=%6s bytes | log=%6s bytes | new=%s\n' \
      "${sample_index}" "${job_status:-unknown}" "${artifact_size}" "${log_bytes}" "${new_content}" >&2
  fi

  sample_index=$((sample_index + 1))

  if [[ "${job_status}" == "completed" ]]; then
    break
  fi

  sleep "${interval}"
done

samples_file="${samples_dir}/samples.json"
printf '%s\n' "${samples_json}" >"${samples_file}"

summary_json=$(jq -n \
  --arg run_id "${run_id}" \
  --arg correlation_id "${correlation_id}" \
  --arg repo "${repo}" \
  --arg workflow "${workflow_file}" \
  --argjson triggered "${triggered_run}" \
  --argjson samples "${samples_json}" \
  'def first_index(stream):
     reduce stream as $i (null; if . == null then $i else . end);
   def bool(x): if x then true else false end;
   def metrics($samples):
     {
       total: ($samples | length),
       first_log_sample: (
         first_index([range(0; ($samples|length))][] | select($samples[.] .log_bytes > 0)) as $idx
         | if $idx == null then null else ($idx + 1) end
       ),
       first_new_content_sample: (
         first_index([range(0; ($samples|length))][] | select($samples[.] .new_content == true)) as $idx
         | if $idx == null then null else ($idx + 1) end
       )
     };
   {
     run_id: $run_id,
     correlation_id: $correlation_id,
     repo: $repo,
     workflow: $workflow,
     triggered_run: bool($triggered),
     last_sample: (if ($samples|length) > 0 then $samples[-1] else null end),
     metrics: metrics($samples),
     samples: $samples
   }')

if [[ "${output_json}" == true ]]; then
  printf '%s\n' "${summary_json}"
else
  printf '\n%-6s %-12s %-15s %-12s %-5s %s\n' "Sample" "Status" "Artifact(bytes)" "Log(bytes)" "New?" "Timestamp"
  printf '%-6s %-12s %-15s %-12s %-5s %s\n' "-----" "------------" "---------------" "------------" "-----" "-------------------------"
  jq -r '.samples[] | "\( .sample )\t\( .status // "-" )\t\( .artifact_size_bytes )\t\( .log_bytes )\t\( .new_content )\t\( .timestamp )"' <<<"${summary_json}" |
    while IFS=$'\t' read -r sample status artifact_bytes log_bytes new_flag ts; do
      printf '%-6s %-12s %-15s %-12s %-5s %s\n' "${sample}" "${status}" "${artifact_bytes}" "${log_bytes}" "${new_flag}" "${ts}"
    done
  printf '\nStored samples under %s\n' "${samples_dir}" >&2
  printf 'Summary written to %s\n' "${samples_file}" >&2
fi
