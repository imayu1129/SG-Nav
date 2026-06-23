#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDA_ENV="${CONDA_ENV:-SG_Nav}"

if [[ -n "${CONDA_PREFIX:-}" && -x "${CONDA_PREFIX}/bin/python" ]]; then
  :
elif [[ -x "/opt/conda/envs/${CONDA_ENV}/bin/python" ]]; then
  CONDA_PREFIX="/opt/conda/envs/${CONDA_ENV}"
elif command -v conda >/dev/null 2>&1; then
  CONDA_PREFIX="$(conda env list | awk -v env="${CONDA_ENV}" '$1 == env {print $NF; found=1} END {if (!found) exit 1}')" || {
    echo "Conda environment '${CONDA_ENV}' was not found." >&2
    echo "Create or provide the upstream SG-Nav environment before running this check." >&2
    exit 1
  }
else
  echo "Could not find the SG-Nav Python environment." >&2
  echo "Run this check inside the submitted container, or provide the maintainer SG_Nav conda environment." >&2
  exit 1
fi

if [[ ! -x "${CONDA_PREFIX}/bin/python" ]]; then
  echo "Conda environment '${CONDA_ENV}' was not found at ${CONDA_PREFIX}." >&2
  echo "Create or provide the upstream SG-Nav environment before running this check." >&2
  exit 1
fi

export PYTHONPATH="${ROOT}/habitat-lab:${ROOT}/segment_anything:${ROOT}/GLIP:${ROOT}/GroundingDINO:${ROOT}:${PYTHONPATH:-}"
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${CONDA_PREFIX}/lib/python3.9/site-packages/torch/lib:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
export PATH="${ROOT}/.local/ollama/bin:${PATH}"
export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
export OLLAMA_MODELS="${OLLAMA_MODELS:-${ROOT}/.local/ollama-models}"

cd "${ROOT}"
"${CONDA_PREFIX}/bin/python" tools/check_sg_nav_env.py
