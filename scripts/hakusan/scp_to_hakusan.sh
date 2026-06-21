#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE="${REMOTE:-}"
REMOTE_DIR="${REMOTE_DIR:-~/sg-nav-work}"

FILES=(
  "dist/hakusan/sg-nav_hakusan_readme.tar.gz"
  "dist/hakusan/sg-nav_hakusan_readme_assets.tar.gz"
  "dist/hakusan/sg-nav_hakusan_readme_submit_files.tar.gz"
  "dist/hakusan/SHA256SUMS"
)

for file in "${FILES[@]}"; do
  if [[ ! -f "${ROOT}/${file}" ]]; then
    echo "missing file: ${ROOT}/${file}" >&2
    exit 1
  fi
done

if [[ -z "${REMOTE}" ]]; then
  echo "Set REMOTE first, for example: export REMOTE='<your-jaist-id>@hakusan1'" >&2
  exit 1
fi

ssh "${REMOTE}" "mkdir -p ${REMOTE_DIR}"

for file in "${FILES[@]}"; do
  scp "${ROOT}/${file}" "${REMOTE}:${REMOTE_DIR}/"
done

echo "Copied SG-Nav Hakusan files to ${REMOTE}:${REMOTE_DIR}/"
