#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:-sg-nav_hakusan_readme.tar.gz}"
TAR_FILE="${ARCHIVE%.gz}"
SIF_FILE="${SIF_FILE:-sg-nav_hakusan_readme.sif}"

if [[ "${ARCHIVE}" == *.gz && ! -f "${TAR_FILE}" ]]; then
  gzip -dk "${ARCHIVE}"
fi

CONTAINER_BIN="$(./scripts/hakusan/find_container_bin.sh)"

echo "CONTAINER_BIN=${CONTAINER_BIN}"
"${CONTAINER_BIN}" build "${SIF_FILE}" "docker-archive://${TAR_FILE}"
echo "Built Singularity image: ${SIF_FILE}"
