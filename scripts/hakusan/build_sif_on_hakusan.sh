#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:-sg-nav_hakusan_readme.tar.gz}"
TAR_FILE="${ARCHIVE%.gz}"
SIF_FILE="${SIF_FILE:-sg-nav_hakusan_readme.sif}"
TMP_SIF="${SIF_FILE}.tmp.$$"

if [[ "${ARCHIVE}" == *.gz && ! -f "${TAR_FILE}" ]]; then
  gzip -dk "${ARCHIVE}"
fi

CONTAINER_BIN="$(./scripts/hakusan/find_container_bin.sh)"

echo "CONTAINER_BIN=${CONTAINER_BIN}"

if [[ -f "${SIF_FILE}" ]]; then
  if "${CONTAINER_BIN}" inspect "${SIF_FILE}" >/dev/null 2>&1; then
    echo "Existing SIF looks valid. Skipping build: ${SIF_FILE}"
    exit 0
  fi
  echo "Removing incomplete or invalid SIF: ${SIF_FILE}"
  rm -f "${SIF_FILE}"
fi

cleanup() {
  rm -f "${TMP_SIF}"
}
trap cleanup EXIT

if [[ "${SHOW_ROOTLESS_WARNINGS:-0}" == "1" ]]; then
  "${CONTAINER_BIN}" build "${TMP_SIF}" "docker-archive://${TAR_FILE}"
else
  "${CONTAINER_BIN}" build "${TMP_SIF}" "docker-archive://${TAR_FILE}" 2>&1 |
    sed '/warn rootless.*EPERM on setxattr "user.rootlesscontainers"/d'
fi

mv "${TMP_SIF}" "${SIF_FILE}"
trap - EXIT
echo "Built Singularity image: ${SIF_FILE}"
