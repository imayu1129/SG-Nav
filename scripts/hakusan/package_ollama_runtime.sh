#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT}/dist/hakusan}"
OLLAMA_VERSION="$("${ROOT}/.local/ollama/bin/ollama" --version | awk '{print $NF}')"
OUT="${OUT_DIR}/sg-nav_ollama_runtime_${OLLAMA_VERSION}.tar.gz"

mkdir -p "${OUT_DIR}"
tar --exclude='ollama.pid' -czf "${OUT}" -C "${ROOT}/.local" ollama
(cd "${OUT_DIR}" && sha256sum "$(basename "${OUT}")" > "$(basename "${OUT}").sha256")

ls -lh "${OUT}" "${OUT}.sha256"
