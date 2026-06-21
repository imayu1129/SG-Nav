#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT}/dist/hakusan}"
OUT_BASENAME="${OUT_BASENAME:-sg-nav_hakusan_readme_assets}"
ASSET_ARCHIVE="${OUT_DIR}/${OUT_BASENAME}.tar.gz"

mkdir -p "${OUT_DIR}"
rm -f "${ASSET_ARCHIVE}"

set +e
(
  tar -C "${ROOT}" -czf "${ASSET_ARCHIVE}" \
    data \
    GLIP/MODEL \
    .local/ollama-models
) &
pack_pid=$!
set -e

while kill -0 "${pack_pid}" >/dev/null 2>&1; do
  if [[ -f "${ASSET_ARCHIVE}" ]]; then
    ls -lh "${ASSET_ARCHIVE}"
  else
    echo "waiting for ${ASSET_ARCHIVE}"
  fi
  sleep 10
done

wait "${pack_pid}"
ls -lh "${ASSET_ARCHIVE}"
echo "Saved assets archive: ${ASSET_ARCHIVE}"
