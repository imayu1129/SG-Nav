#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT}/dist/hakusan}"
OLLAMA_VERSION="${OLLAMA_VERSION:-0.4.2}"
URL="${OLLAMA_RELEASE_URL:-https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tgz}"
TMP="${TMPDIR:-/tmp}/sg-nav-ollama-v${OLLAMA_VERSION}"
OUT="${OUT_DIR}/sg-nav_ollama_runtime_${OLLAMA_VERSION}.tar.gz"

rm -rf "${TMP}"
mkdir -p "${TMP}/download" "${TMP}/extract" "${TMP}/pkg" "${OUT_DIR}"

curl -L --fail --show-error --progress-bar \
  -o "${TMP}/download/ollama-linux-amd64.tgz" \
  "${URL}"

tar -xzf "${TMP}/download/ollama-linux-amd64.tgz" -C "${TMP}/extract"

test -x "${TMP}/extract/bin/ollama"
test -d "${TMP}/extract/lib/ollama"

mkdir -p "${TMP}/pkg/ollama"
cp -a "${TMP}/extract/bin" "${TMP}/pkg/ollama/"
cp -a "${TMP}/extract/lib" "${TMP}/pkg/ollama/"

tar -czf "${OUT}" -C "${TMP}/pkg" ollama
(cd "${OUT_DIR}" && sha256sum "$(basename "${OUT}")" > "$(basename "${OUT}").sha256")

ls -lh "${OUT}" "${OUT}.sha256"
