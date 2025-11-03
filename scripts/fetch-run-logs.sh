#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/run-utils.sh
source "${SCRIPT_DIR}/lib/run-utils.sh"

usage() {
  cat <<'EOF'
Usage: fetch-run-logs.sh [--run-id <id>] [--run-id-file <path>] [--runs-dir <dir> --correlation-id <id>]
                          [--output-dir <dir>] [--json]

Downloads and prepares Actions logs for a completed workflow run.
If no run identifier flags are provided, the script reads JSON on stdin with a top-level "run_id".
EOF
}

run_id=""
run_id_file=""
runs_dir=""
correlation_id=""
output_dir=""
json_output=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="$2"
      shift 2
      ;;
    --run-id-file)
      run_id_file="$2"
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
    --output-dir)
      output_dir="$2"
      shift 2
      ;;
    --json)
      json_output=true
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

ru_require_command gh
ru_require_command jq
ru_require_command unzip

if [[ -z "${run_id}" && -n "${run_id_file}" ]]; then
  if ! run_id="$(ru_read_run_id_from_file "${run_id_file}")"; then
    printf 'Unable to read run_id from %s\n' "${run_id_file}" >&2
    exit 1
  fi
fi

if [[ -z "${run_id}" && -n "${runs_dir}" && -n "${correlation_id}" ]]; then
  if ! run_id="$(ru_read_run_id_from_runs_dir "${runs_dir}" "${correlation_id}")"; then
    printf 'No record for correlation %s in %s\n' "${correlation_id}" "${runs_dir}" >&2
    exit 1
  fi
fi

if [[ -z "${run_id}" ]]; then
  if run_id="$(ru_read_run_id_from_stdin)"; then
    :
  fi
fi

run_id="$(printf '%s' "${run_id}" | tr -d '[:space:]')"

if [[ -z "${run_id}" ]]; then
  printf 'Run ID not provided. Use --run-id or supply metadata.\n' >&2
  exit 1
fi

if [[ -n "${runs_dir}" && -n "${correlation_id}" ]]; then
  base_dir="${runs_dir%/}/${correlation_id}"
else
  base_dir="${output_dir:-runs/${run_id}}"
fi

mkdir -p "${base_dir}"
logs_dir="${base_dir}/logs"
mkdir -p "${logs_dir}"

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

run_json_file="$(mktemp)"
if ! gh api "repos/${repo}/actions/runs/${run_id}" >"${run_json_file}" 2>/dev/null; then
  printf 'Unable to fetch run %s. Confirm access rights.\n' "${run_id}" >&2
  exit 1
fi

run_status="$(jq -r '.status // ""' "${run_json_file}")"
if [[ "${run_status}" != "completed" ]]; then
  printf 'Run %s is still %s. Wait for completion before fetching logs.\n' "${run_id}" "${run_status:-unknown}" >&2
  printf "Tip: run 'gh run watch %s --exit-status' to wait for completion.\n" "${run_id}" >&2
  exit 1
fi

dispatch_run_name="$(jq -r '.name // ""' "${run_json_file}")"

archive_path="${logs_dir}/${run_id}.zip"
tmp_zip="$(mktemp)"
tmp_err="$(mktemp)"
if ! gh api "repos/${repo}/actions/runs/${run_id}/logs" >"${tmp_zip}" 2>"${tmp_err}"; then
  err_output="$(cat "${tmp_err}")"
  if grep -q "HTTP 404" "${tmp_err}"; then
    printf 'Failed to download logs: HTTP 404. Logs may be expired or you lack permission.\n' >&2
  elif grep -q "HTTP 410" "${tmp_err}"; then
    printf 'Failed to download logs: HTTP 410. GitHub already deleted the log archive (retention elapsed).\n' >&2
  else
    printf 'Failed to download logs for run %s.\n' "${run_id}" >&2
  fi
  printf '%s\n' "${err_output}" >&2
  rm -f "${tmp_zip}" "${tmp_err}"
  exit 1
fi
mv "${tmp_zip}" "${archive_path}"
rm -f "${tmp_err}"

tmp_extract="$(mktemp -d)"
if ! unzip -q "${archive_path}" -d "${tmp_extract}"; then
  printf 'Failed to unzip log archive %s\n' "${archive_path}" >&2
  rm -rf "${tmp_extract}"
  exit 1
fi

# Refresh extracted log directories, keep archive if requested.
find "${logs_dir}" -mindepth 1 -maxdepth 1 ! -name "$(basename "${archive_path}")" -exec rm -rf {} +

combined_path="${logs_dir}/combined.log"
: >"${combined_path}"
manifest_file="$(mktemp)"

while IFS= read -r file_path; do
  relative="${file_path#"${tmp_extract}/"}"
  IFS='/' read -r -a parts <<<"${relative}"
  sanitized_parts=()
  for part in "${parts[@]}"; do
    sanitized_parts+=("$(ru_sanitize_name "${part}")")
  done
  sanitized_relative="$(IFS=/; printf '%s' "${sanitized_parts[*]}")"
  dest_path="${logs_dir}/${sanitized_relative}"
  mkdir -p "$(dirname "${dest_path}")"
  cp "${file_path}" "${dest_path}"

  {
    printf '===== %s =====\n' "${sanitized_relative}"
    cat "${file_path}"
    printf '\n'
  } >>"${combined_path}"

  job_key="${sanitized_parts[0]:-root}"
  file_size="$(wc -c <"${file_path}" | tr -d '[:space:]')"
  printf '{"job":"%s","relative_path":"%s","size":%s}\n' "${job_key}" "${sanitized_relative}" "${file_size}" >>"${manifest_file}"
done < <(find "${tmp_extract}" -type f | sort)

rm -rf "${tmp_extract}"

jobs_json_file="$(mktemp)"
gh api "repos/${repo}/actions/runs/${run_id}/jobs" --paginate --jq '.jobs[]' 2>/dev/null | jq -s '.' >"${jobs_json_file}"

summary_path="${logs_dir}/logs.json"

python3 - "${run_json_file}" "${jobs_json_file}" "${manifest_file}" "${summary_path}" "${combined_path}" "${archive_path}" "${base_dir}" "${correlation_id}" "${run_id}" <<'PY'
import datetime
import json
import os
import re
import sys

run_path, jobs_path, manifest_path, summary_path, combined_path, archive_path, base_dir, correlation, run_id = sys.argv[1:]

summary_path = os.path.abspath(summary_path)
combined_path = os.path.abspath(combined_path)
archive_path = os.path.abspath(archive_path)
base_dir = os.path.abspath(base_dir)

with open(run_path, "r", encoding="utf-8") as f:
    run_data = json.load(f)

try:
    with open(jobs_path, "r", encoding="utf-8") as f:
        jobs_data = json.load(f)
except json.JSONDecodeError:
    jobs_data = []

manifest_entries = []
with open(manifest_path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        manifest_entries.append(json.loads(line))

def sanitize(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", value)

files_by_job = {}
for entry in manifest_entries:
    files_by_job.setdefault(entry["job"], []).append(entry)

for entries in files_by_job.values():
    entries.sort(key=lambda item: item["relative_path"])

def rel(path: str) -> str:
    try:
        return os.path.relpath(path, start=base_dir)
    except ValueError:
        return path

jobs_summary = []
if isinstance(jobs_data, list):
    for job in jobs_data:
        job_name = job.get("name") or "job"
        job_key = sanitize(job_name)
        job_entry = {
            "id": job.get("id"),
            "name": job_name,
            "status": job.get("status"),
            "conclusion": job.get("conclusion"),
            "started_at": job.get("started_at"),
            "completed_at": job.get("completed_at"),
            "html_url": job.get("html_url"),
            "log_paths": [entry["relative_path"] for entry in files_by_job.get(job_key, [])],
            "steps": []
        }
        for step in job.get("steps") or []:
            job_entry["steps"].append({
                "number": step.get("number"),
                "name": step.get("name"),
                "status": step.get("status"),
                "conclusion": step.get("conclusion"),
                "completed_at": step.get("completed_at")
            })
        jobs_summary.append(job_entry)

summary = {
    "run_id": str(run_data.get("id", run_id)),
    "workflow_id": run_data.get("workflow_id"),
    "run_name": run_data.get("name"),
    "status": run_data.get("status"),
    "conclusion": run_data.get("conclusion"),
    "event": run_data.get("event"),
    "run_started_at": run_data.get("run_started_at"),
    "updated_at": run_data.get("updated_at"),
    "html_url": run_data.get("html_url"),
    "correlation_id": correlation or None,
    "downloaded_at": datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
    "paths": {
        "archive": rel(archive_path),
        "combined_log": rel(combined_path),
        "summary": rel(summary_path)
    },
    "jobs": jobs_summary,
    "files": manifest_entries
}

with open(summary_path, "w", encoding="utf-8") as f:
    json.dump(summary, f, indent=2)
PY

rm -f "${run_json_file}" "${jobs_json_file}" "${manifest_file}"

summary_rel="$(python3 - "${summary_path}" "$(pwd)" <<'PY'
import os
import sys
summary_path = os.path.abspath(sys.argv[1])
cwd = os.path.abspath(sys.argv[2])
try:
    print(os.path.relpath(summary_path, start=cwd))
except ValueError:
    print(summary_path)
PY
)"

combined_rel="$(python3 - "${combined_path}" "$(pwd)" <<'PY'
import os
import sys
combined_path = os.path.abspath(sys.argv[1])
cwd = os.path.abspath(sys.argv[2])
try:
    print(os.path.relpath(combined_path, start=cwd))
except ValueError:
    print(combined_path)
PY
)"

archive_rel="$(python3 - "${archive_path}" "$(pwd)" <<'PY'
import os
import sys
archive_path = os.path.abspath(sys.argv[1])
cwd = os.path.abspath(sys.argv[2])
try:
    print(os.path.relpath(archive_path, start=cwd))
except ValueError:
    print(archive_path)
PY
)"

if [[ "${json_output}" == true ]]; then
  jq -n \
    --arg run_id "${run_id}" \
    --arg summary "${summary_rel}" \
    --arg combined "${combined_rel}" \
    --arg archive "${archive_rel}" \
    '{
      run_id: $run_id,
      summary_path: $summary,
      combined_log: $combined,
      archive_path: $archive
    }'
else
  printf 'Downloaded logs for run %s (%s).\n' "${run_id}" "${dispatch_run_name}"
  printf 'Summary: %s\n' "${summary_rel}"
  printf 'Combined log: %s\n' "${combined_rel}"
  printf 'Archive: %s\n' "${archive_rel}"
fi
