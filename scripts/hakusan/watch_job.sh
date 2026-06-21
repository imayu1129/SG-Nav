#!/usr/bin/env bash
set -euo pipefail

JOB_ID="${1:?usage: $0 JOB_ID [log-prefix]}"
LOG_PREFIX="${2:-}"
COMPACT="${COMPACT:-0}"
PATTERN="${PATTERN:-\\[SG-Nav\\]|Navigate Step|distance_to_goal|success|spl|Traceback|ERROR|OpenAI}"

while true; do
  date
  squeue -j "${JOB_ID}" || true
  sacct -j "${JOB_ID}" --format=JobID,JobName,Partition,State,ExitCode,Elapsed -X 2>/dev/null || true

  if [[ -n "${LOG_PREFIX}" ]]; then
    files=("${LOG_PREFIX}-${JOB_ID}.out" "${LOG_PREFIX}-${JOB_ID}.err")
  else
    shopt -s nullglob
    files=(*-"${JOB_ID}".out *-"${JOB_ID}".err)
    shopt -u nullglob
  fi

  if ((${#files[@]} == 0)); then
    echo "[logs] not created yet"
  else
    ls -lh "${files[@]}" 2>/dev/null || true
    for file in "${files[@]}"; do
      if [[ ! -e "${file}" ]]; then
        echo "[${file}] not created yet"
      elif [[ ! -s "${file}" ]]; then
        echo "[${file}] empty"
      elif [[ "${COMPACT}" == "1" ]]; then
        echo "----- compact: ${file} -----"
        grep -E "${PATTERN}" "${file}" 2>/dev/null | tail -n 80 || true
      else
        echo "----- tail: ${file} -----"
        tail -n 60 "${file}"
      fi
    done
  fi

  sleep 10
done
