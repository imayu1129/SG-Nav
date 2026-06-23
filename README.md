# SG-Nav-GPT MP3D Reproduction

Use the provided Docker/Singularity image. Do not create a host-side `SG_Nav`
conda environment.

Reference run:

```text
Setting: SG-Nav-GPT, MP3D ObjectNav validation, first 10 episodes
Result:  SR 30.0%, SPL 14.0%, distance-to-goal 3.194
Paper:   SR 40.2%, SPL 16.0% on full validation
```

Exact reruns are not guaranteed because GPT responses, OpenAI model serving, GPU
numerics, and the 10-episode subset can introduce small variation.

## Required Files

Put these under `~/sg-nav-work` on Hakusan:

```text
sg-nav_hakusan_readme.sif
sg-nav_hakusan_readme_submit_files.tar.gz
SHA256SUMS
```

If only the Docker archive is provided, use this instead of the SIF:

```text
sg-nav_hakusan_readme.tar.gz
```

Assets are either provided as:

```text
sg-nav_hakusan_readme_assets.tar.gz
```

or manually placed as:

```text
assets/data/MatterPort3D/mp3d/<scene_id>/<scene_id>.glb
assets/data/MatterPort3D/objectnav/mp3d/v1/val/val.json.gz
assets/data/MatterPort3D/objectnav/mp3d/v1/val/content/*.json.gz
assets/data/models/sam_vit_h_4b8939.pth
assets/data/models/groundingdino_swint_ogc.pth
assets/GLIP/MODEL/glip_large_model.pth
```

## 1. Prepare Runtime

```bash
cd ~/sg-nav-work
sha256sum -c SHA256SUMS
tar -xzf sg-nav_hakusan_readme_submit_files.tar.gz
mkdir -p assets
if [[ -f sg-nav_hakusan_readme_assets.tar.gz ]]; then
  tar -xzf sg-nav_hakusan_readme_assets.tar.gz -C assets
fi
```

If assets are placed manually and no asset archive is provided, verify only the
files that are actually present.

If `sg-nav_hakusan_readme.sif` is not provided:

```bash
./scripts/hakusan/build_sif_on_hakusan.sh sg-nav_hakusan_readme.tar.gz
```

## 2. Check Container and Assets

```bash
sbatch scripts/hakusan/check_env_hakusan.sbatch
```

Fix any missing path reported by the check before running evaluation.

## 3. Configure OpenAI

```bash
mkdir -p "$HOME/.config/sg-nav"
chmod 700 "$HOME/.config/sg-nav"
read -rsp "OPENAI_API_KEY: " OPENAI_API_KEY; echo
umask 077
printf 'export OPENAI_API_KEY=%q\nexport LLM_BACKEND=openai\nexport LLM_MODEL=gpt-4o\nexport VLM_MODEL=gpt-4o\n' "$OPENAI_API_KEY" > "$HOME/.config/sg-nav/openai.env"
chmod 600 "$HOME/.config/sg-nav/openai.env"
unset OPENAI_API_KEY
```

Check API access:

```bash
source "$HOME/.config/sg-nav/openai.env"
LLM_MODEL=gpt-4o scripts/hakusan/check_openai_quota.py
```

Expected:

```text
OK: OpenAI Responses API is reachable for model=gpt-4o.
```

## 4. Run 10 Episodes

```bash
source "$HOME/.config/sg-nav/openai.env"
ARGS="--split_l 0 --split_r 1 --num_episodes 10" \
  LLM_BACKEND=openai LLM_MODEL=gpt-4o VLM_MODEL=gpt-4o \
  sbatch scripts/hakusan/sg_nav_hakusan.sbatch
```

Monitor:

```bash
COMPACT=1 scripts/hakusan/watch_job.sh <JOBID> sg-nav
```

Cancel if needed:

```bash
scancel <JOBID>
```

## 5. Aggregate

```bash
scripts/hakusan/aggregate_episode_runs.py assets/data/results/experiment_0/[0:1]/results.txt
```

Submitted output:

```text
total_episodes=10
distance_to_goal=3.194012809393462
success=0.300000
spl=0.139923
softspl=0.216574
```

## Troubleshooting

- `Matterport3D scenes directory is missing`: check
  `assets/data/MatterPort3D/mp3d`.
- `ObjectNav val episode file is missing`: check
  `assets/data/MatterPort3D/objectnav/mp3d/v1/val/val.json.gz`.
- `model checkpoint is missing`: check the SAM, GroundingDINO, and GLIP weights.
- `OpenAI API HTTP 429 ... insufficient_quota`: fix OpenAI billing/quota.
- `WARNING: Could not find any nv files on this host`: submit a Slurm GPU job.
- `EGL_NOT_INITIALIZED`: use `scripts/hakusan/sg_nav_hakusan.sbatch`.
- `singularity: command not found`: load Singularity/Apptainer on Hakusan.
