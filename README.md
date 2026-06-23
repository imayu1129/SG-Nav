# SG-Nav-GPT MP3D Reproduction

Use the provided reproduction bundle. Do **not** create a host-side `SG_Nav`
conda environment.

Reference result:

```text
Setting: SG-Nav-GPT, MP3D ObjectNav validation, first 10 episodes
Result:  SR 30.0%, SPL 14.0%, distance-to-goal 3.194
Paper:   SR 40.2%, SPL 16.0% on full validation
```

Exact reruns can differ slightly because GPT responses, OpenAI model serving,
GPU numerics, and the 10-episode subset are not bitwise deterministic.

## What You Need

The author provides this file separately through Box or another private
institutional download URL:

```text
sg-nav_reproduction_bundle.tar.gz
```

Box browser page:

```text
https://jstorage.box.com/s/semgxoruxgg1psnha4dzrlv4e7699p0b
```

Expected bundle:

```text
Size:   30G
SHA256: d253d9ddc2c16b6d5f7b339968e8f0d2bcb3fa0dd1de1370d5bc045deae68607
```

The bundle contains the Docker image archive, helper files, MP3D ObjectNav data,
and model checkpoints. You only need to prepare your own OpenAI API key.
The OpenAI API key is not needed for Steps 1-3. It is needed from Step 4.

Do not upload this bundle to a public GitHub Release if it contains MP3D data.

## 1. Login and Set Up Hakusan

Run this on your local machine. Replace `s2YOUR_ID` with your JAIST ID.

```bash
ssh s2YOUR_ID@hakusan1.jaist.ac.jp
```

Input your password.

Then run this on Hakusan:

```bash
if [[ ! -d "$HOME/sg-nav/.git" ]]; then
  git clone https://github.com/imayu1129/SG-Nav.git "$HOME/sg-nav"
else
  cd "$HOME/sg-nav" && git pull --ff-only
fi

cd "$HOME/sg-nav"
pwd
```

Download the reproduction bundle on Hakusan:

```bash
BUNDLE_URL="https://jstorage.app.box.com/index.php?rm=box_download_shared_file&shared_name=semgxoruxgg1psnha4dzrlv4e7699p0b&file_id=f_2303493332796"
curl -fL "$BUNDLE_URL" -o sg-nav_reproduction_bundle.tar.gz
ls -lh sg-nav_reproduction_bundle.tar.gz
printf 'd253d9ddc2c16b6d5f7b339968e8f0d2bcb3fa0dd1de1370d5bc045deae68607  sg-nav_reproduction_bundle.tar.gz\n' | sha256sum -c -
```

Expected:

```text
sg-nav_reproduction_bundle.tar.gz: OK
```

If `curl` returns `404` or `403`, open the Box link in a browser and check that
download permission is enabled.

## 2. Extract the Bundle

Run this on Hakusan:

```bash
cd "$HOME/sg-nav"

echo "[1/6] Extracting the 30G reproduction bundle. This can take several minutes."
tar --checkpoint=200000 --checkpoint-action=dot -xzf sg-nav_reproduction_bundle.tar.gz
echo

echo "[2/6] Checking the extracted archive checksums."
sha256sum --ignore-missing -c SHA256SUMS

echo "[3/6] Extracting helper files."
tar -xzf sg-nav_hakusan_readme_submit_files.tar.gz

echo "[4/6] Extracting assets. This can also take several minutes."
mkdir -p assets
tar --checkpoint=200000 --checkpoint-action=dot -xzf sg-nav_hakusan_readme_assets.tar.gz -C assets
echo

echo "[5/6] Building the Singularity image from the Docker archive."
./scripts/hakusan/build_sif_on_hakusan.sh sg-nav_hakusan_readme.tar.gz

echo "[6/6] Checking the SIF image."
ls -lh sg-nav_hakusan_readme.sif
```

This step is successful if you see all of these:

```text
sg-nav_hakusan_readme.tar.gz: OK
sg-nav_hakusan_readme_assets.tar.gz: OK
sg-nav_hakusan_readme_submit_files.tar.gz: OK
```

and `ls -lh sg-nav_hakusan_readme.sif` shows a SIF file. Do not run Step 3
before this succeeds.

## 3. Check Container and Assets

Run this on Hakusan:

```bash
cd "$HOME/sg-nav"
JOBID=$(sbatch scripts/hakusan/check_env_hakusan.sbatch | awk '{print $4}')
echo "$JOBID"
```

Check the job:

```bash
squeue -j "$JOBID"
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
cd "$HOME/sg-nav"
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
cd "$HOME/sg-nav"
source "$HOME/.config/sg-nav/openai.env"
JOBID=$(ARGS="--split_l 0 --split_r 1 --num_episodes 10" \
  LLM_BACKEND=openai LLM_MODEL=gpt-4o VLM_MODEL=gpt-4o \
  sbatch scripts/hakusan/sg_nav_hakusan.sbatch | awk '{print $4}')
echo "$JOBID"
```

Monitor the job:

```bash
cd "$HOME/sg-nav"
COMPACT=1 scripts/hakusan/watch_job.sh "$JOBID" sg-nav
```

Cancel the job if needed:

```bash
scancel "$JOBID"
```

## 6. Aggregate Results

Run this on Hakusan after the job completes:

```bash
cd "$HOME/sg-nav"
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

- `Matterport3D scenes directory is missing`: the bundle was not extracted into
  `~/sg-nav/assets`.
- `sg-nav_hakusan_readme.sif: no such file`: run Step 2 before Step 3.
- `ObjectNav val episode file is missing`: the bundle was not extracted into
  `~/sg-nav/assets`.
- `model checkpoint is missing`: the bundle was not extracted into
  `~/sg-nav/assets`.
- `OpenAI API HTTP 429 ... insufficient_quota`: fix OpenAI billing/quota.
- `WARNING: Could not find any nv files on this host`: submit a Slurm GPU job.
- `EGL_NOT_INITIALIZED`: use `scripts/hakusan/sg_nav_hakusan.sbatch`.
- `singularity: command not found`: load Singularity/Apptainer on Hakusan.

## Author: Create the Bundle

This is only for the person preparing the reproduction artifact:

```bash
./scripts/hakusan/package_reproduction_bundle.sh
```

Upload `dist/hakusan/sg-nav_reproduction_bundle.tar.gz` to a private or
institutional file host, then put that URL in Step 1.

The current tested bundle is:

```text
Size:   30G
SHA256: d253d9ddc2c16b6d5f7b339968e8f0d2bcb3fa0dd1de1370d5bc045deae68607
```
