# SG-Nav-GPT MP3D Reproduction

Use the provided Docker/Singularity image. Do **not** create a host-side
`SG_Nav` conda environment.

Reference result:

```text
Setting: SG-Nav-GPT, MP3D ObjectNav validation, first 10 episodes
Result:  SR 30.0%, SPL 14.0%, distance-to-goal 3.194
Paper:   SR 40.2%, SPL 16.0% on full validation
```

Exact reruns can differ slightly because GPT responses, OpenAI model serving,
GPU numerics, and the 10-episode subset are not bitwise deterministic.

## 0. Upload Files to Hakusan

Run this on your local machine. Replace `s2YOUR_ID` with your JAIST ID.

```bash
cd /path/to/SG-Nav
export JAIST_ID=s2YOUR_ID
export REMOTE="${JAIST_ID}@hakusan1.jaist.ac.jp"
export REMOTE_DIR="~/sg-nav"

ssh "${REMOTE}" "mkdir -p ${REMOTE_DIR}"
```

If you have the SIF file, upload these:

```bash
scp dist/hakusan/sg-nav_hakusan_readme.sif \
    dist/hakusan/sg-nav_hakusan_readme_submit_files.tar.gz \
    dist/hakusan/SHA256SUMS \
    "${REMOTE}:${REMOTE_DIR}/"
```

If you have the Docker archive instead of the SIF, upload these:

```bash
scp dist/hakusan/sg-nav_hakusan_readme.tar.gz \
    dist/hakusan/sg-nav_hakusan_readme_submit_files.tar.gz \
    dist/hakusan/SHA256SUMS \
    "${REMOTE}:${REMOTE_DIR}/"
```

If the asset archive is available, upload it:

```bash
scp dist/hakusan/sg-nav_hakusan_readme_assets.tar.gz "${REMOTE}:${REMOTE_DIR}/"
```

If the asset archive is not available, prepare these paths manually on Hakusan:

```text
~/sg-nav/assets/data/MatterPort3D/mp3d/<scene_id>/<scene_id>.glb
~/sg-nav/assets/data/MatterPort3D/objectnav/mp3d/v1/val/val.json.gz
~/sg-nav/assets/data/MatterPort3D/objectnav/mp3d/v1/val/content/*.json.gz
~/sg-nav/assets/data/models/sam_vit_h_4b8939.pth
~/sg-nav/assets/data/models/groundingdino_swint_ogc.pth
~/sg-nav/assets/GLIP/MODEL/glip_large_model.pth
```

## 1. Log in to Hakusan

Run this on your local machine. Replace `s2YOUR_ID` with your JAIST ID.

```bash
ssh s2YOUR_ID@hakusan1.jaist.ac.jp
```

Input your password when prompted.

Then run this on Hakusan:

```bash
mkdir -p ~/sg-nav
cd ~/sg-nav
ls -lh
```

You should see at least:

```text
sg-nav_hakusan_readme.sif
sg-nav_hakusan_readme_submit_files.tar.gz
SHA256SUMS
```

## 2. Prepare Runtime

Run this on Hakusan:

```bash
cd ~/sg-nav
sha256sum --ignore-missing -c SHA256SUMS
tar -xzf sg-nav_hakusan_readme_submit_files.tar.gz
mkdir -p assets
if [[ -f sg-nav_hakusan_readme_assets.tar.gz ]]; then
  tar -xzf sg-nav_hakusan_readme_assets.tar.gz -C assets
fi
```

If `sg-nav_hakusan_readme.sif` is missing but
`sg-nav_hakusan_readme.tar.gz` exists, build the SIF:

```bash
cd ~/sg-nav
./scripts/hakusan/build_sif_on_hakusan.sh sg-nav_hakusan_readme.tar.gz
```

## 3. Check Container and Assets

Run this on Hakusan:

```bash
cd ~/sg-nav
sbatch scripts/hakusan/check_env_hakusan.sbatch
```

Check the job:

```bash
squeue -u "$USER"
ls -lh check-env-*.out check-env-*.err 2>/dev/null || true
tail -n 80 check-env-*.out check-env-*.err 2>/dev/null
```

Do not start evaluation until this check passes.

## 4. Configure OpenAI

Run this on Hakusan:

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
cd ~/sg-nav
source "$HOME/.config/sg-nav/openai.env"
LLM_MODEL=gpt-4o scripts/hakusan/check_openai_quota.py
```

Expected:

```text
OK: OpenAI Responses API is reachable for model=gpt-4o.
```

## 5. Run 10 Episodes

Run this on Hakusan:

```bash
cd ~/sg-nav
source "$HOME/.config/sg-nav/openai.env"
ARGS="--split_l 0 --split_r 1 --num_episodes 10" \
  LLM_BACKEND=openai LLM_MODEL=gpt-4o VLM_MODEL=gpt-4o \
  sbatch scripts/hakusan/sg_nav_hakusan.sbatch
```

Slurm prints a job ID:

```text
Submitted batch job <JOBID>
```

Monitor the job. Replace `<JOBID>` with the printed job ID:

```bash
cd ~/sg-nav
COMPACT=1 scripts/hakusan/watch_job.sh <JOBID> sg-nav
```

Cancel the job if needed:

```bash
scancel <JOBID>
```

## 6. Aggregate Results

Run this on Hakusan after the job completes:

```bash
cd ~/sg-nav
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

Report:

```text
SR: 30.0%
SPL: 14.0%
Distance-to-goal: 3.194
```

## Troubleshooting

- `Matterport3D scenes directory is missing`: check
  `~/sg-nav/assets/data/MatterPort3D/mp3d`.
- `ObjectNav val episode file is missing`: check
  `~/sg-nav/assets/data/MatterPort3D/objectnav/mp3d/v1/val/val.json.gz`.
- `model checkpoint is missing`: check the SAM, GroundingDINO, and GLIP weights.
- `OpenAI API HTTP 429 ... insufficient_quota`: fix OpenAI billing/quota.
- `WARNING: Could not find any nv files on this host`: submit a Slurm GPU job.
- `EGL_NOT_INITIALIZED`: use `scripts/hakusan/sg_nav_hakusan.sbatch`.
- `singularity: command not found`: load Singularity/Apptainer on Hakusan.
