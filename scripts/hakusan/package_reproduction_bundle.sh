#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT}/dist/hakusan}"
BUNDLE="${BUNDLE:-${OUT_DIR}/sg-nav_reproduction_bundle.tar.gz}"

required_files=(
  sg-nav_hakusan_readme.tar.gz
  sg-nav_hakusan_readme_submit_files.tar.gz
  sg-nav_hakusan_readme_assets.tar.gz
  SHA256SUMS
)

missing=()
for file in "${required_files[@]}"; do
  if [[ ! -f "${OUT_DIR}/${file}" ]]; then
    missing+=("${OUT_DIR}/${file}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required bundle file(s):\n' >&2
  printf '  %s\n' "${missing[@]}" >&2
  printf 'Create/copy these files into %s before packaging the reproduction bundle.\n' "${OUT_DIR}" >&2
  exit 1
fi

rm -f "${BUNDLE}"
tar -C "${OUT_DIR}" -czf "${BUNDLE}" "${required_files[@]}"
ls -lh "${BUNDLE}"
sha256sum "${BUNDLE}" > "${BUNDLE}.sha256"
cat "${BUNDLE}.sha256"
