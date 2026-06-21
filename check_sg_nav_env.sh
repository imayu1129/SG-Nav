#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDA_ENV="${CONDA_ENV:-SG_Nav}"
if [[ -z "${CONDA_PREFIX:-}" ]]; then
  if [[ -d "/opt/conda/envs/${CONDA_ENV}" ]]; then
    CONDA_PREFIX="/opt/conda/envs/${CONDA_ENV}"
  else
    CONDA_PREFIX="/home/robot/anaconda3/envs/${CONDA_ENV}"
  fi
fi

export PYTHONPATH="${ROOT}/habitat-lab:${ROOT}/segment_anything:${ROOT}/GLIP:${ROOT}/GroundingDINO:${ROOT}:${PYTHONPATH:-}"
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${CONDA_PREFIX}/lib/python3.9/site-packages/torch/lib:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
export PATH="${ROOT}/.local/ollama/bin:${PATH}"
export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
export OLLAMA_MODELS="${OLLAMA_MODELS:-${ROOT}/.local/ollama-models}"

cd "${ROOT}"
conda run -n "${CONDA_ENV}" python tools/check_sg_nav_env.py
