#!/usr/bin/env bash
set -euo pipefail

EXPECTED_SHA256="${EXPECTED_SHA256:-d253d9ddc2c16b6d5f7b339968e8f0d2bcb3fa0dd1de1370d5bc045deae68607}"

if [[ -z "${SLURM_JOB_ID:-}" ]]; then
  echo "ERROR: run this after entering an A40 compute node with scripts/hakusan/enter_a40_node.sh." >&2
  exit 1
fi

echo "hostname=$(hostname)"
echo "SLURM_JOB_ID=${SLURM_JOB_ID}"
nvidia-smi -L

if [[ ! -f sg-nav_reproduction_bundle.tar.gz ]]; then
  echo "ERROR: sg-nav_reproduction_bundle.tar.gz is missing in $PWD" >&2
  exit 1
fi

echo "[1/7] Checking reproduction bundle."
ls -lh sg-nav_reproduction_bundle.tar.gz
printf '%s  sg-nav_reproduction_bundle.tar.gz\n' "$EXPECTED_SHA256" | sha256sum -c -

echo "[2/7] Extracting the 30G reproduction bundle on this A40 compute node."
if [[ -f SHA256SUMS && -f sg-nav_hakusan_readme.tar.gz && -f sg-nav_hakusan_readme_assets.tar.gz && -f sg-nav_hakusan_readme_submit_files.tar.gz ]]; then
  echo "Archive files already exist. Skipping bundle extraction."
else
  tar --checkpoint=200000 --checkpoint-action=dot -xzf sg-nav_reproduction_bundle.tar.gz
  echo
fi

echo "[3/7] Checking extracted archive checksums."
sha256sum --ignore-missing -c SHA256SUMS

echo "[4/7] Keeping helper files from the GitHub checkout."
echo "The helper archive checksum was verified in [3/7]; it is not extracted here."
echo "This avoids overwriting newer scripts pulled from GitHub."

echo "[5/7] Extracting assets on this A40 compute node."
if [[ -d assets/data/MatterPort3D/mp3d && -d assets/GLIP/MODEL ]]; then
  echo "Assets already exist. Skipping assets extraction."
else
  mkdir -p assets
  tar --checkpoint=200000 --checkpoint-action=dot -xzf sg-nav_hakusan_readme_assets.tar.gz -C assets
  echo
fi

echo "[6/7] Building the Singularity image from the Docker archive."
./scripts/hakusan/build_sif_on_hakusan.sh sg-nav_hakusan_readme.tar.gz

echo "[7/7] Checking the SIF image."
ls -lh sg-nav_hakusan_readme.sif

echo "OK: bundle extraction and SIF build completed on the A40 compute node."
