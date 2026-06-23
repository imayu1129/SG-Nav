#!/bin/bash -l
#SBATCH --job-name=sg-nav-check
#SBATCH -p GPU-1
#SBATCH --gres=gpu:nvidia_a40:1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=00:30:00
#SBATCH --output=check-env-%j.out
#SBATCH --error=check-env-%j.err

set -euo pipefail

cd "${SLURM_SUBMIT_DIR:-$HOME/sg-nav-work}"

CONTAINER_BIN="$(./scripts/hakusan/find_container_bin.sh)"

export SINGULARITYENV_NVIDIA_DRIVER_CAPABILITIES=all
export SINGULARITYENV___EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
export SINGULARITYENV_EGL_PLATFORM=surfaceless
export APPTAINERENV_NVIDIA_DRIVER_CAPABILITIES="${SINGULARITYENV_NVIDIA_DRIVER_CAPABILITIES}"
export APPTAINERENV___EGL_VENDOR_LIBRARY_FILENAMES="${SINGULARITYENV___EGL_VENDOR_LIBRARY_FILENAMES}"
export APPTAINERENV_EGL_PLATFORM="${SINGULARITYENV_EGL_PLATFORM}"

GPU_ARGS=(--nv)
EXTRA_BINDS=()
HOST_EGL_JSON=""
for candidate in /usr/share/glvnd/egl_vendor.d/10_nvidia.json /etc/glvnd/egl_vendor.d/10_nvidia.json; do
  if [[ -r "${candidate}" ]]; then
    HOST_EGL_JSON="${candidate}"
    break
  fi
done

HOST_EGL_LIB="$(
  set +o pipefail
  ldconfig -p 2>/dev/null | awk '/libEGL_nvidia\.so\.0/ {print $NF; exit}'
)"
if [[ -z "${HOST_EGL_LIB}" ]]; then
  HOST_EGL_LIB="$(find /usr /lib64 /lib -name 'libEGL_nvidia.so.0' -print -quit 2>/dev/null || true)"
fi

if [[ -n "${HOST_EGL_JSON}" ]]; then
  EXTRA_BINDS+=(--bind "${HOST_EGL_JSON}:/usr/share/glvnd/egl_vendor.d/10_nvidia.json:ro")
fi
if [[ -n "${HOST_EGL_LIB}" ]]; then
  EXTRA_BINDS+=(--bind "$(dirname "${HOST_EGL_LIB}"):/host-nvidia-libs:ro")
fi
if [[ -d "$PWD/assets/.local/ollama" ]]; then
  EXTRA_BINDS+=(--bind "$PWD/assets/.local/ollama:/opt/sg-nav/.local/ollama")
fi
if [[ -d "$PWD/assets/.local/ollama-models" ]]; then
  EXTRA_BINDS+=(--bind "$PWD/assets/.local/ollama-models:/opt/sg-nav/.local/ollama-models")
fi
mkdir -p "$PWD/runtime/check-env-${SLURM_JOB_ID:-manual}"
EXTRA_BINDS+=(--bind "$PWD/runtime/check-env-${SLURM_JOB_ID:-manual}:/runtime")

CONTAINER_ENV_ARGS=(
  --env NVIDIA_DRIVER_CAPABILITIES=all
  --env __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
  --env EGL_PLATFORM=surfaceless
  --env LD_LIBRARY_PATH=/opt/sg-nav/.local/ollama/lib/ollama:/host-nvidia-libs
  --env OLLAMA_LIBRARY_PATH=/opt/sg-nav/.local/ollama/lib/ollama
  --env SG_NAV_RUNTIME_DIR=/runtime
)

"${CONTAINER_BIN}" exec "${GPU_ARGS[@]}" "${EXTRA_BINDS[@]}" "${CONTAINER_ENV_ARGS[@]}" \
  --bind "$PWD/assets/data:/opt/sg-nav/data" \
  --bind "$PWD/assets/GLIP/MODEL:/opt/sg-nav/GLIP/MODEL" \
  sg-nav_hakusan_readme.sif bash -lc 'cd /opt/sg-nav && ./check_sg_nav_env.sh'
