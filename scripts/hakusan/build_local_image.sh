#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONDA_ENV="${CONDA_ENV:-SG_Nav}"
IMAGE_NAME="${IMAGE_NAME:-sg-nav:hakusan-readme}"
CONTEXT_DIR="${CONTEXT_DIR:-${ROOT}/.docker_build/hakusan/context}"
INCLUDE_ASSETS="${INCLUDE_ASSETS:-1}"
BASE_PYTHON="${BASE_PYTHON:-/home/robot/anaconda3/bin/python}"
SKIP_PACK="${SKIP_PACK:-0}"
SKIP_ENV_PACK="${SKIP_ENV_PACK:-${SKIP_PACK}}"
SKIP_SOURCE_PACK="${SKIP_SOURCE_PACK:-${SKIP_PACK}}"

mkdir -p "${CONTEXT_DIR}"
cp "${ROOT}/docker/hakusan/Dockerfile" "${CONTEXT_DIR}/Dockerfile"

if [[ "${SKIP_ENV_PACK}" != "1" ]]; then
  if ! "${BASE_PYTHON}" -c "import conda_pack" >/dev/null 2>&1; then
    "${BASE_PYTHON}" -m pip install --user conda-pack
  fi

  "${BASE_PYTHON}" - <<PY
import conda_pack
conda_pack.pack(
    name="${CONDA_ENV}",
    output="${CONTEXT_DIR}/sg_nav_env.tar.gz",
    force=True,
    ignore_editable_packages=True,
)
PY
fi

if [[ "${SKIP_SOURCE_PACK}" != "1" ]]; then
  tar_args=(
    --exclude=.git
    --exclude=.docker_build
    --exclude='**/__pycache__'
    --exclude='*.pyc'
    --exclude=logs
    --exclude=GLIP/build
    --exclude=GLIP/maskrcnn_benchmark.egg-info
    --exclude=segment_anything/segment_anything.egg-info
  )

  if [[ "${INCLUDE_ASSETS}" != "1" ]]; then
    tar_args+=(--exclude=./data --exclude=./.local/ollama-models --exclude=./GLIP/MODEL)
  fi

  tar -C "${ROOT}" "${tar_args[@]}" -czf "${CONTEXT_DIR}/sg-nav-source.tar.gz" .
fi

docker build \
  --build-arg CONDA_ENV="${CONDA_ENV}" \
  -t "${IMAGE_NAME}" \
  "${CONTEXT_DIR}"

echo "Built Docker image: ${IMAGE_NAME}"
