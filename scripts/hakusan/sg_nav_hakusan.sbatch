#!/bin/bash -l
#SBATCH --job-name=sg-nav
#SBATCH -p GPU-1
#SBATCH --gres=gpu:nvidia_a40:1
#SBATCH --cpus-per-task=1
#SBATCH --mem=128G
#SBATCH --time=12:00:00
#SBATCH --output=sg-nav-%j.out
#SBATCH --error=sg-nav-%j.err

set -euo pipefail

IMAGE="${IMAGE:-sg-nav_hakusan_readme.sif}"
ARGS="${ARGS:---split_l 0 --split_r 1}"
ASSETS_DIR="${ASSETS_DIR:-$PWD/assets}"
OLLAMA_PORT="${OLLAMA_PORT:-$((12000 + (${SLURM_JOB_ID:-0} % 20000)))}"
RUNTIME_DIR="${RUNTIME_DIR:-$PWD/runtime/${SLURM_JOB_ID:-manual}}"
LLM_BACKEND="${LLM_BACKEND:-${SG_NAV_LLM_BACKEND:-ollama}}"
LLM_MODEL="${LLM_MODEL:-${SG_NAV_LLM_MODEL:-}}"
VLM_MODEL="${VLM_MODEL:-${SG_NAV_VLM_MODEL:-}}"
SG_NAV_SECRET_ENV="${SG_NAV_SECRET_ENV:-$HOME/.config/sg-nav/openai.env}"

if [[ -r "${SG_NAV_SECRET_ENV}" ]]; then
  # Keep API keys outside the repository and Slurm command history.
  # shellcheck disable=SC1090
  source "${SG_NAV_SECRET_ENV}"
fi

if [[ -r /etc/profile.d/modules.sh ]]; then
  # Some Hakusan compute nodes expose container tools only after module init.
  # This does not change the SG-Nav environment inside the container.
  # shellcheck disable=SC1091
  source /etc/profile.d/modules.sh
fi

if ! command -v singularity >/dev/null 2>&1 && ! command -v apptainer >/dev/null 2>&1; then
  module load singularity 2>/dev/null || module load apptainer 2>/dev/null || true
fi

CONTAINER_BIN="$(command -v singularity || command -v apptainer || true)"
if [[ -z "${CONTAINER_BIN}" ]]; then
  echo "ERROR: neither singularity nor apptainer was found on this node." >&2
  echo "Run 'module avail singularity apptainer' on Hakusan to confirm the module name." >&2
  exit 127
fi

cd "${SLURM_SUBMIT_DIR:-$PWD}"

# Habitat-Sim creates a headless EGL context. Keep legacy --nv because it is
# the mode that exposed CUDA on Hakusan, then explicitly bind host NVIDIA EGL
# libraries for headless rendering.
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

HOST_EGL_LIB="$(ldconfig -p 2>/dev/null | awk '/libEGL_nvidia\.so\.0/ {print $NF; exit}')"
if [[ -z "${HOST_EGL_LIB}" ]]; then
  HOST_EGL_LIB="$(find /usr /lib64 /lib -name 'libEGL_nvidia.so.0' 2>/dev/null | head -n 1 || true)"
fi

if [[ -n "${HOST_EGL_JSON}" ]]; then
  EXTRA_BINDS+=(--bind "${HOST_EGL_JSON}:/usr/share/glvnd/egl_vendor.d/10_nvidia.json:ro")
fi
if [[ -n "${HOST_EGL_LIB}" ]]; then
  EXTRA_BINDS+=(--bind "$(dirname "${HOST_EGL_LIB}"):/host-nvidia-libs:ro")
fi
if [[ -d "${ASSETS_DIR}/.local/ollama" ]]; then
  EXTRA_BINDS+=(--bind "${ASSETS_DIR}/.local/ollama:/opt/sg-nav/.local/ollama")
fi
for source_file in SG_Nav.py scenegraph.py run_sg_nav.sh; do
  if [[ -f "$PWD/${source_file}" ]]; then
    EXTRA_BINDS+=(--bind "$PWD/${source_file}:/opt/sg-nav/${source_file}:ro")
  fi
done
if [[ -f "$PWD/GLIP/maskrcnn_benchmark/engine/predictor_glip.py" ]]; then
  EXTRA_BINDS+=(--bind "$PWD/GLIP/maskrcnn_benchmark/engine/predictor_glip.py:/opt/sg-nav/GLIP/maskrcnn_benchmark/engine/predictor_glip.py:ro")
fi
if [[ -f "$PWD/habitat-lab/habitat/core/benchmark.py" ]]; then
  EXTRA_BINDS+=(--bind "$PWD/habitat-lab/habitat/core/benchmark.py:/opt/sg-nav/habitat-lab/habitat/core/benchmark.py:ro")
fi
if [[ -f "$PWD/habitat-lab/habitat/core/challenge.py" ]]; then
  EXTRA_BINDS+=(--bind "$PWD/habitat-lab/habitat/core/challenge.py:/opt/sg-nav/habitat-lab/habitat/core/challenge.py:ro")
fi
mkdir -p "${RUNTIME_DIR}"
EXTRA_BINDS+=(--bind "${RUNTIME_DIR}:/runtime")

CONTAINER_ENV_ARGS=(
  --env NVIDIA_DRIVER_CAPABILITIES=all
  --env __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
  --env EGL_PLATFORM=surfaceless
  --env LD_LIBRARY_PATH=/opt/sg-nav/.local/ollama/lib/ollama:/host-nvidia-libs
  --env OLLAMA_HOST=127.0.0.1:${OLLAMA_PORT}
  --env OLLAMA_LIBRARY_PATH=/opt/sg-nav/.local/ollama/lib/ollama
  --env SG_NAV_LLM_BACKEND=${LLM_BACKEND}
  --env SG_NAV_RUNTIME_DIR=/runtime
  --env SG_NAV_VERBOSE_WARNINGS=${SG_NAV_VERBOSE_WARNINGS:-0}
  --env SG_NAV_COMPACT_METRICS=${SG_NAV_COMPACT_METRICS:-1}
  --env GYM_DISABLE_WARNINGS=${GYM_DISABLE_WARNINGS:-1}
  --env TOKENIZERS_PARALLELISM=${TOKENIZERS_PARALLELISM:-false}
  --env TRANSFORMERS_VERBOSITY=${TRANSFORMERS_VERBOSITY:-error}
)

if [[ -n "${LLM_MODEL}" ]]; then
  CONTAINER_ENV_ARGS+=(--env SG_NAV_LLM_MODEL="${LLM_MODEL}")
fi
if [[ -n "${VLM_MODEL}" ]]; then
  CONTAINER_ENV_ARGS+=(--env SG_NAV_VLM_MODEL="${VLM_MODEL}")
fi
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  CONTAINER_ENV_ARGS+=(--env OPENAI_API_KEY="${OPENAI_API_KEY}")
fi
if [[ -n "${OPENAI_BASE_URL:-}" ]]; then
  CONTAINER_ENV_ARGS+=(--env OPENAI_BASE_URL="${OPENAI_BASE_URL}")
fi
if [[ -n "${OPENAI_TIMEOUT:-}" ]]; then
  CONTAINER_ENV_ARGS+=(--env OPENAI_TIMEOUT="${OPENAI_TIMEOUT}")
fi

echo "CONTAINER_BIN=${CONTAINER_BIN}"
echo "GPU_ARGS=${GPU_ARGS[*]}"
echo "HOST_EGL_JSON=${HOST_EGL_JSON:-missing}"
echo "HOST_EGL_LIB=${HOST_EGL_LIB:-missing}"
echo "LLM_BACKEND=${LLM_BACKEND}"
echo "LLM_MODEL=${LLM_MODEL:-default}"
echo "VLM_MODEL=${VLM_MODEL:-default}"

"${CONTAINER_BIN}" exec "${GPU_ARGS[@]}" "${EXTRA_BINDS[@]}" "${CONTAINER_ENV_ARGS[@]}" \
  --bind "${ASSETS_DIR}/data:/opt/sg-nav/data" \
  --bind "${ASSETS_DIR}/GLIP/MODEL:/opt/sg-nav/GLIP/MODEL" \
  --bind "${ASSETS_DIR}/.local/ollama-models:/opt/sg-nav/.local/ollama-models" \
  "${IMAGE}" bash -lc "
    set -euo pipefail
    cd /opt/sg-nav
    export PATH=/opt/sg-nav/.local/ollama/bin:\$PATH
    export OLLAMA_HOST=127.0.0.1:${OLLAMA_PORT}
    export OLLAMA_MODELS=/opt/sg-nav/.local/ollama-models
    export OLLAMA_LIBRARY_PATH=/opt/sg-nav/.local/ollama/lib/ollama
    export LD_LIBRARY_PATH=/opt/sg-nav/.local/ollama/lib/ollama:/host-nvidia-libs:\${LD_LIBRARY_PATH:-}
    export SG_NAV_RUNTIME_DIR=/runtime
    export SG_NAV_LLM_BACKEND=${LLM_BACKEND}
    export SG_NAV_COMPACT_METRICS=${SG_NAV_COMPACT_METRICS:-1}
    export SG_NAV_VERBOSE_WARNINGS=${SG_NAV_VERBOSE_WARNINGS:-0}
    if [[ -n \"${LLM_MODEL}\" ]]; then export SG_NAV_LLM_MODEL=${LLM_MODEL}; fi
    if [[ -n \"${VLM_MODEL}\" ]]; then export SG_NAV_VLM_MODEL=${VLM_MODEL}; fi

    echo \"SG_NAV_LLM_BACKEND=\${SG_NAV_LLM_BACKEND}\"
    echo \"SG_NAV_LLM_MODEL=\${SG_NAV_LLM_MODEL:-default}\"
    echo \"SG_NAV_VLM_MODEL=\${SG_NAV_VLM_MODEL:-default}\"
    echo \"LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}\"

    if [[ \"\${SG_NAV_LLM_BACKEND}\" == \"ollama\" ]]; then
      echo \"OLLAMA_HOST=\${OLLAMA_HOST}\"
      echo \"OLLAMA_MODELS=\${OLLAMA_MODELS}\"
      echo \"OLLAMA_LIBRARY_PATH=\${OLLAMA_LIBRARY_PATH}\"
      command -v ollama
      ollama --version || true
      ls -lh /opt/sg-nav/.local/ollama/bin/ollama /opt/sg-nav/.local/ollama/lib/ollama/llama-server /opt/sg-nav/.local/ollama/lib/ollama/libllama.so.0.0.1 || true

      mkdir -p \"\${SG_NAV_RUNTIME_DIR}/logs\" \"\${SG_NAV_RUNTIME_DIR}/ollama\"
      if ! curl -fsS \"http://\${OLLAMA_HOST}/api/tags\" >/dev/null 2>&1; then
        nohup /opt/sg-nav/.local/ollama/bin/ollama serve > \"\${SG_NAV_RUNTIME_DIR}/logs/ollama-\${SLURM_JOB_ID:-manual}.log\" 2>&1 &
        echo \$! > \"\${SG_NAV_RUNTIME_DIR}/ollama/ollama.pid\"
        sleep 5
      fi

      echo '--- ollama /api/version ---'
      curl -fsS \"http://\${OLLAMA_HOST}/api/version\" || true
      echo
      echo '--- ollama /api/tags ---'
      curl -fsS \"http://\${OLLAMA_HOST}/api/tags\" || true
      echo
      echo '--- ollama server log head ---'
      head -n 120 \"\${SG_NAV_RUNTIME_DIR}/logs/ollama-\${SLURM_JOB_ID:-manual}.log\" 2>/dev/null || true
    else
      echo 'Skipping Ollama startup for OpenAI/GPT backend.'
    fi

    if [[ \"\${SG_NAV_LLM_BACKEND}\" == \"openai\" ]]; then
      echo '--- checking OpenAI backend source bind ---'
      grep -n \"llm_backend\" SG_Nav.py
      grep -n \"num_episodes\" SG_Nav.py
      grep -n \"episode_start\" SG_Nav.py
      grep -n \"get_openai_text_response\" scenegraph.py
      grep -n \"total_episodes\" habitat-lab/habitat/core/benchmark.py
      grep -n \"num_episodes\" habitat-lab/habitat/core/challenge.py
    fi

    ./run_sg_nav.sh ${ARGS} --llm_backend ${LLM_BACKEND}
  "
