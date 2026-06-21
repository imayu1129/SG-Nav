#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-sg-nav:hakusan-readme}"
OUT_DIR="${OUT_DIR:-${ROOT}/dist/hakusan}"
OUT_BASENAME="${OUT_BASENAME:-sg-nav_hakusan_readme}"

mkdir -p "${OUT_DIR}"

IMAGE_TAR="${OUT_DIR}/${OUT_BASENAME}.tar"
IMAGE_ARCHIVE="${IMAGE_TAR}.gz"
rm -f "${IMAGE_TAR}" "${IMAGE_ARCHIVE}"

set +e
(docker save -o "${IMAGE_TAR}" "${IMAGE_NAME}") &
save_pid=$!
set -e

while kill -0 "${save_pid}" >/dev/null 2>&1; do
  if [[ -f "${IMAGE_TAR}" ]]; then
    ls -lh "${IMAGE_TAR}"
  elif compgen -G "${OUT_DIR}/.docker_temp_*" >/dev/null; then
    ls -lh "${OUT_DIR}"/.docker_temp_*
  else
    echo "waiting for ${IMAGE_TAR}"
  fi
  sleep 10
done

wait "${save_pid}"
ls -lh "${IMAGE_TAR}"
gzip -vf "${IMAGE_TAR}"
ls -lh "${IMAGE_ARCHIVE}"

tar -C "${ROOT}" -czf "${OUT_DIR}/${OUT_BASENAME}_submit_files.tar.gz" \
  scripts/hakusan

echo "Saved image archive: ${OUT_DIR}/${OUT_BASENAME}.tar.gz"
echo "Saved submit helper archive: ${OUT_DIR}/${OUT_BASENAME}_submit_files.tar.gz"
