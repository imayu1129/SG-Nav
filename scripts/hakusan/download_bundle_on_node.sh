#!/usr/bin/env bash
set -euo pipefail

BUNDLE_URL="${BUNDLE_URL:-https://jstorage.app.box.com/index.php?rm=box_download_shared_file&shared_name=semgxoruxgg1psnha4dzrlv4e7699p0b&file_id=f_2303493332796}"
EXPECTED_SHA256="${EXPECTED_SHA256:-d253d9ddc2c16b6d5f7b339968e8f0d2bcb3fa0dd1de1370d5bc045deae68607}"
BUNDLE_FILE="${BUNDLE_FILE:-sg-nav_reproduction_bundle.tar.gz}"

check_bundle() {
  [[ -f "${BUNDLE_FILE}" ]] &&
    printf '%s  %s\n' "${EXPECTED_SHA256}" "${BUNDLE_FILE}" | sha256sum -c -
}

download_bundle() {
  curl -fL -C - --retry 10 --retry-delay 10 \
    "${BUNDLE_URL}" -o "${BUNDLE_FILE}"
}

if check_bundle; then
  echo "Bundle already exists and passed SHA256. Skipping download."
  exit 0
fi

if [[ -f "${BUNDLE_FILE}" ]]; then
  echo "Found an incomplete or corrupted bundle. Trying to resume download."
  ls -lh "${BUNDLE_FILE}"
else
  echo "Downloading reproduction bundle."
fi

download_bundle
ls -lh "${BUNDLE_FILE}"

if check_bundle; then
  exit 0
fi

echo "Resume did not produce a valid bundle. Removing it and downloading from scratch." >&2
rm -f "${BUNDLE_FILE}"
download_bundle
ls -lh "${BUNDLE_FILE}"
check_bundle
