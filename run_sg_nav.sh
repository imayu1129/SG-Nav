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
export PYTHONUNBUFFERED=1
export SG_NAV_VERBOSE_WARNINGS="${SG_NAV_VERBOSE_WARNINGS:-0}"
export GYM_DISABLE_WARNINGS="${GYM_DISABLE_WARNINGS:-1}"
export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"
export TRANSFORMERS_VERBOSITY="${TRANSFORMERS_VERBOSITY:-error}"
export SG_NAV_COMPACT_METRICS="${SG_NAV_COMPACT_METRICS:-1}"
LLM_BACKEND="${SG_NAV_LLM_BACKEND:-ollama}"

if [[ -w "${ROOT}" ]]; then
  RUNTIME_DIR="${SG_NAV_RUNTIME_DIR:-${ROOT}}"
else
  RUNTIME_DIR="${SG_NAV_RUNTIME_DIR:-${TMPDIR:-/tmp}/sg-nav-runtime}"
fi

if ! command -v conda >/dev/null 2>&1; then
  echo "conda command was not found. Please initialize conda before running SG-Nav." >&2
  exit 1
fi

if [[ "${LLM_BACKEND}" == "ollama" ]] && ! curl -fsS "http://${OLLAMA_HOST}/api/tags" >/dev/null 2>&1; then
  mkdir -p "${RUNTIME_DIR}/logs" "${OLLAMA_MODELS}" "${RUNTIME_DIR}/ollama"
  OLLAMA_HOST="${OLLAMA_HOST}" OLLAMA_MODELS="${OLLAMA_MODELS}" \
    nohup "${ROOT}/.local/ollama/bin/ollama" serve > "${RUNTIME_DIR}/logs/ollama.log" 2>&1 &
  echo "$!" > "${RUNTIME_DIR}/ollama/ollama.pid"
  sleep 3
elif [[ "${LLM_BACKEND}" != "ollama" ]]; then
  echo "Skipping local Ollama startup because SG_NAV_LLM_BACKEND=${LLM_BACKEND}."
fi

cd "${ROOT}"
echo "Launching SG-Nav with SG_NAV_LLM_BACKEND=${LLM_BACKEND}"
exec conda run --no-capture-output -n "${CONDA_ENV}" python -u SG_Nav.py "$@"
