#!/bin/bash -l
#SBATCH --job-name=sg-nav-egl
#SBATCH -p GPU-1
#SBATCH --gres=gpu:nvidia_a40:1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=00:15:00
#SBATCH --output=check-egl-%j.out
#SBATCH --error=check-egl-%j.err

set -euo pipefail

cd "${SLURM_SUBMIT_DIR:-$HOME/sg-nav-work}"

if [[ -r /etc/profile.d/modules.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/modules.sh
fi

if ! command -v singularity >/dev/null 2>&1 && ! command -v apptainer >/dev/null 2>&1; then
  module load singularity 2>/dev/null || module load apptainer 2>/dev/null || true
fi

CONTAINER_BIN="$(command -v singularity || command -v apptainer || true)"
if [[ -z "${CONTAINER_BIN}" ]]; then
  echo "ERROR: neither singularity nor apptainer was found on this node." >&2
  exit 127
fi

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
mkdir -p "$PWD/runtime/check-egl-${SLURM_JOB_ID:-manual}"
EXTRA_BINDS+=(--bind "$PWD/runtime/check-egl-${SLURM_JOB_ID:-manual}:/runtime")

CONTAINER_ENV_ARGS=(
  --env NVIDIA_DRIVER_CAPABILITIES=all
  --env __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
  --env EGL_PLATFORM=surfaceless
  --env LD_LIBRARY_PATH=/opt/sg-nav/.local/ollama/lib/ollama:/host-nvidia-libs
  --env OLLAMA_LIBRARY_PATH=/opt/sg-nav/.local/ollama/lib/ollama
  --env SG_NAV_RUNTIME_DIR=/runtime
)

echo "CONTAINER_BIN=${CONTAINER_BIN}"
echo "GPU_ARGS=${GPU_ARGS[*]}"
echo "HOST_EGL_JSON=${HOST_EGL_JSON:-missing}"
echo "HOST_EGL_LIB=${HOST_EGL_LIB:-missing}"

"${CONTAINER_BIN}" exec "${GPU_ARGS[@]}" "${EXTRA_BINDS[@]}" "${CONTAINER_ENV_ARGS[@]}" \
  --bind "$PWD/assets/data:/opt/sg-nav/data" \
  --bind "$PWD/assets/GLIP/MODEL:/opt/sg-nav/GLIP/MODEL" \
  sg-nav_hakusan_readme.sif bash -lc '
    set -euo pipefail
    cd /opt/sg-nav
    echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-}"
    echo "__EGL_VENDOR_LIBRARY_FILENAMES=${__EGL_VENDOR_LIBRARY_FILENAMES:-}"
    echo "EGL_PLATFORM=${EGL_PLATFORM:-}"
    nvidia-smi
    ls -l /usr/share/glvnd/egl_vendor.d || true
    python - <<'"'"'PY'"'"'
import habitat
print("habitat import ok")
cfg = habitat.get_config("configs/challenge_objectnav2021.local.rgbd.yaml")
env = habitat.Env(config=cfg)
print("habitat env init ok")
env.close()
PY
  '
