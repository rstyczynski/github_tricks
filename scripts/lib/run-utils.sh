#!/usr/bin/env bash

# Shared helper functions for GitHub workflow tooling scripts.
# shellcheck disable=SC2317 # functions are sourced and used elsewhere

ru_require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

ru_read_run_id_from_file() {
  local file_path="$1"
  if [[ ! -f "${file_path}" ]]; then
    return 1
  fi
  if command -v jq >/dev/null 2>&1 && jq -e '.run_id' "${file_path}" >/dev/null 2>&1; then
    jq -r '.run_id // empty' "${file_path}"
  else
    head -n1 "${file_path}" | tr -d '[:space:]'
  fi
}

ru_read_run_id_from_stdin() {
  if [[ -t 0 ]]; then
    return 1
  fi

  local input
  input="$(cat)"
  if [[ -z "${input}" ]]; then
    return 1
  fi

  if command -v jq >/dev/null 2>&1 && jq -e '.' <<<"${input}" >/dev/null 2>&1; then
    jq -r '.run_id // empty' <<<"${input}"
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -R 'fromjson? | select(.run_id != null) | .run_id' <<<"${input}" | head -n1
    return 0
  fi

  printf '%s\n' "${input}" | head -n1 | tr -d '[:space:]'
}

ru_metadata_path_for_correlation() {
  local runs_dir="$1"
  local correlation_id="$2"
  printf '%s/%s.json\n' "${runs_dir%/}" "${correlation_id}"
}

ru_read_run_id_from_runs_dir() {
  local runs_dir="$1"
  local correlation_id="$2"
  local metadata_file
  metadata_file="$(ru_metadata_path_for_correlation "${runs_dir}" "${correlation_id}")"
  ru_read_run_id_from_file "${metadata_file}"
}

ru_sanitize_name() {
  local value="$1"
  printf '%s\n' "${value//[^A-Za-z0-9_.-]/_}"
}

ru_file_size_bytes() {
  local path="$1"
  if [[ ! -e "${path}" ]]; then
    printf '0\n'
    return
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f%z "${path}"
  else
    stat -c%s "${path}"
  fi
}
