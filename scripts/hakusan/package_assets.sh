#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT}/dist/hakusan}"
OUT_BASENAME="${OUT_BASENAME:-sg-nav_hakusan_readme_assets}"
ASSET_ARCHIVE="${OUT_DIR}/${OUT_BASENAME}.tar.gz"

mkdir -p "${OUT_DIR}"
rm -f "${ASSET_ARCHIVE}"

required_paths=(
  data/MatterPort3D/mp3d
  data/MatterPort3D/objectnav/mp3d/v1/val/val.json.gz
  data/models/sam_vit_h_4b8939.pth
  data/models/groundingdino_swint_ogc.pth
  GLIP/MODEL/glip_large_model.pth
)

missing=()
for path in "${required_paths[@]}"; do
  if [[ ! -e "${ROOT}/${path}" ]]; then
    missing+=("${path}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required asset path(s):\n' >&2
  printf '  %s\n' "${missing[@]}" >&2
  printf 'Place the assets in the expected layout or symlink them before packaging.\n' >&2
  exit 1
fi

asset_paths=(
  data
  GLIP/MODEL
)

if [[ -e "${ROOT}/.local/ollama-models" ]]; then
  asset_paths+=(.local/ollama-models)
else
  echo "Skipping optional .local/ollama-models; SG-Nav-GPT/OpenAI runs do not need it."
fi

set +e
(
  tar -C "${ROOT}" -czf "${ASSET_ARCHIVE}" "${asset_paths[@]}"
) &
pack_pid=$!
set -e

while kill -0 "${pack_pid}" >/dev/null 2>&1; do
  if [[ -f "${ASSET_ARCHIVE}" ]]; then
    ls -lh "${ASSET_ARCHIVE}"
  else
    echo "waiting for ${ASSET_ARCHIVE}"
  fi
  sleep 10
done

wait "${pack_pid}"
ls -lh "${ASSET_ARCHIVE}"
echo "Saved assets archive: ${ASSET_ARCHIVE}"
