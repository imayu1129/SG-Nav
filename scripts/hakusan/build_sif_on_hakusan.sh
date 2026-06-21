#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:-sg-nav_hakusan_readme.tar.gz}"
TAR_FILE="${ARCHIVE%.gz}"
SIF_FILE="${SIF_FILE:-sg-nav_hakusan_readme.sif}"

if [[ "${ARCHIVE}" == *.gz && ! -f "${TAR_FILE}" ]]; then
  gzip -dk "${ARCHIVE}"
fi

if [[ -r /etc/profile.d/modules.sh ]]; then
  # Some Hakusan compute nodes expose container tools only after module init.
  # This does not change the SG-Nav environment inside the container.
  # shellcheck disable=SC1091
  source /etc/profile.d/modules.sh
fi

if ! command -v singularity >/dev/null 2>&1 && ! command -v apptainer >/dev/null 2>&1; then
  module load singularity 2>/dev/null || module load apptainer 2>/dev/null || true
fi

CONTAINER_BIN="$(command -v singularity || command -v apptainer || true)"
if [[ -z "${CONTAINER_BIN}" ]]; then
  echo "ERROR: neither singularity nor apptainer was found on this node." >&2
  echo "Run 'module avail singularity apptainer' on Hakusan to confirm the module name." >&2
  exit 127
fi

"${CONTAINER_BIN}" build "${SIF_FILE}" "docker-archive://${TAR_FILE}"
echo "Built Singularity image: ${SIF_FILE}"
