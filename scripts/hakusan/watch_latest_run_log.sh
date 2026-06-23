#!/usr/bin/env bash
set -euo pipefail

cd "${SG_NAV_REPO_DIR:-$PWD}"

run_log="${1:-}"
if [[ -z "${run_log}" ]]; then
  run_log="$(ls -t sg-nav-a40-*.log 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${run_log}" || ! -f "${run_log}" ]]; then
  echo "ERROR: no sg-nav-a40-*.log file found in $PWD" >&2
  exit 1
fi

echo "Watching ${run_log}"
tail -n 80 -f "${run_log}"
