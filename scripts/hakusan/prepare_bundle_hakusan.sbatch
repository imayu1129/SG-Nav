#!/bin/bash -l
#SBATCH --job-name=sg-nav-prepare
#SBATCH -p GPU-1
#SBATCH --gres=gpu:nvidia_a40:1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --time=03:00:00
#SBATCH --output=prepare-bundle-%j.out
#SBATCH --error=prepare-bundle-%j.err

set -euo pipefail

cd "${SLURM_SUBMIT_DIR:-$HOME/sg-nav}"

EXPECTED_SHA256="d253d9ddc2c16b6d5f7b339968e8f0d2bcb3fa0dd1de1370d5bc045deae68607"

echo "[1/7] Checking reproduction bundle."
if [[ ! -f sg-nav_reproduction_bundle.tar.gz ]]; then
  echo "ERROR: sg-nav_reproduction_bundle.tar.gz is missing in $PWD" >&2
  exit 1
fi
ls -lh sg-nav_reproduction_bundle.tar.gz
printf '%s  sg-nav_reproduction_bundle.tar.gz\n' "$EXPECTED_SHA256" | sha256sum -c -

echo "[2/7] Extracting the 30G reproduction bundle on a Slurm compute node."
tar --checkpoint=200000 --checkpoint-action=dot -xzf sg-nav_reproduction_bundle.tar.gz
echo

echo "[3/7] Checking extracted archive checksums."
sha256sum --ignore-missing -c SHA256SUMS

echo "[4/7] Extracting helper files."
tar -xzf sg-nav_hakusan_readme_submit_files.tar.gz

echo "[5/7] Extracting assets on a Slurm compute node."
mkdir -p assets
tar --checkpoint=200000 --checkpoint-action=dot -xzf sg-nav_hakusan_readme_assets.tar.gz -C assets
echo

echo "[6/7] Building the Singularity image from the Docker archive."
./scripts/hakusan/build_sif_on_hakusan.sh sg-nav_hakusan_readme.tar.gz

echo "[7/7] Checking the SIF image."
ls -lh sg-nav_hakusan_readme.sif

echo "OK: bundle extraction and SIF build completed."
