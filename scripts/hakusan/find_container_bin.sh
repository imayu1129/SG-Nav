#!/usr/bin/env bash
set -euo pipefail

if [[ -r /etc/profile.d/modules.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/modules.sh
fi

if ! command -v singularity >/dev/null 2>&1 && ! command -v apptainer >/dev/null 2>&1; then
  module load singularity 2>/dev/null || module load apptainer 2>/dev/null || true
fi

if command -v singularity >/dev/null 2>&1; then
  command -v singularity
  exit 0
fi

if command -v apptainer >/dev/null 2>&1; then
  command -v apptainer
  exit 0
fi

for candidate in \
  /app/singularity/*/bin/singularity \
  /app/apptainer/*/bin/apptainer \
  /usr/local/bin/singularity \
  /usr/local/bin/apptainer \
  /usr/bin/singularity \
  /usr/bin/apptainer; do
  if [[ -x "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    exit 0
  fi
done

echo "ERROR: neither singularity nor apptainer was found on this node." >&2
echo "Run 'module avail singularity apptainer' on Hakusan to confirm the module name." >&2
exit 127
