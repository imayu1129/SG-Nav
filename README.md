# SG-Nav-GPT MP3D Reproduction

Use the provided reproduction bundle. Do **not** create a host-side `SG_Nav`
conda environment.

Reference result:

```text
Setting: SG-Nav-GPT, MP3D ObjectNav validation, first 10 episodes
Result:  SR 40.0%, SPL 17.3%, distance-to-goal 2.467
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
The OpenAI API key is not needed for Steps 1-4. It is needed from Step 5.
You do not need write access to this GitHub repository. `git clone` and
`git pull --ff-only` only download files into your own Hakusan home directory.

Do not upload this bundle to a public GitHub Release if it contains MP3D data.

## 1. Login and Set Up Hakusan

Run this on your local machine. Replace `s2YOUR_ID` with your JAIST ID.

```bash
ssh s2YOUR_ID@hakusan1.jaist.ac.jp
```

Input your password.

If `hakusan1` closes the connection after password input, try `hakusan2`:

```bash
ssh s2YOUR_ID@hakusan2.jaist.ac.jp
```

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

## 2. Enter an A40 Compute Node

Do not extract the 30G bundle on the login node. Enter an A40 node first:

```bash
cd "$HOME/sg-nav"
./scripts/hakusan/enter_a40_node.sh
```

After the prompt returns on the compute node, run:

```bash
hostname
nvidia-smi -L
cd "$HOME/sg-nav"
```

All remaining steps should be run inside this A40 session.

## 3. Download and Prepare the Bundle

Run this inside the A40 session:

```bash
cd "$HOME/sg-nav"
./scripts/hakusan/download_bundle_on_node.sh
```

The download is successful if you see:

```text
sg-nav_reproduction_bundle.tar.gz: OK
```

If `curl` returns `404` or `403`, open the Box link in a browser and check that
download permission is enabled.
If the download speed is extremely slow, press `Ctrl-C` and run the same block
again later. The script resumes an incomplete download.

Prepare the bundle on the same A40 node:

```bash
cd "$HOME/sg-nav"
./scripts/hakusan/prepare_bundle_on_node.sh
```

If this stops during SIF build or you press `Ctrl-C`, run
`./scripts/hakusan/prepare_bundle_on_node.sh` again. Completed extraction steps
are skipped, and an incomplete SIF is removed automatically.

Rootless Singularity can print many harmless `warn rootless ... EPERM on
setxattr` messages during SIF build. The script hides those warnings by
default. To show them for debugging, run:

```bash
SHOW_ROOTLESS_WARNINGS=1 ./scripts/hakusan/prepare_bundle_on_node.sh
```

During `INFO: Creating SIF file...`, the final `.sif` file may not appear until
the build completes. This can take a long time and may look stuck. Do not press
`Ctrl-C` unless the job has clearly failed. From another Hakusan login terminal,
check that the interactive A40 job is still running:

```bash
squeue -j "$SLURM_JOB_ID"
squeue -u "$USER"
```

This step is successful if you see:

```text
sg-nav_reproduction_bundle.tar.gz: OK
sg-nav_hakusan_readme.tar.gz: OK
sg-nav_hakusan_readme_assets.tar.gz: OK
sg-nav_hakusan_readme_submit_files.tar.gz: OK
OK: bundle extraction and SIF build completed on the A40 compute node.
```

Do not run Step 4 before this succeeds.

## 4. Check Container and Assets

Run this inside the A40 session:

```bash
cd "$HOME/sg-nav"
./scripts/hakusan/check_env_on_node.sh
```

This step is successful if you see:

```text
OK: container and assets check passed on the A40 compute node.
```

Do not start evaluation until this check passes.

## 5. Configure OpenAI

Run this inside the A40 session:

```bash
cd "$HOME/sg-nav"
./scripts/hakusan/configure_openai_key.sh
```

When the terminal shows `OPENAI_API_KEY:`, paste your own OpenAI API key and
press Enter. The key is saved outside the repository at
`$HOME/.config/sg-nav/openai.env`.

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

The `output=` field may be empty. If the line starts with `OK:`, the API check
passed.

If this returns `HTTP 500` or another transient server error, wait a minute and
run the same check command again. The checker retries transient errors
automatically.

## 6. Run 10 Episodes

Run this inside the A40 session:

```bash
cd "$HOME/sg-nav"
git pull --ff-only
./scripts/hakusan/run_10_episodes_on_node.sh
```

The run log is saved as `sg-nav-a40-${SLURM_JOB_ID}.log`.

To watch the run from another Hakusan terminal:

```bash
cd "$HOME/sg-nav"
./scripts/hakusan/watch_latest_run_log.sh
```

To check that the A40 session is still alive:

```bash
squeue -j "$SLURM_JOB_ID"
squeue -u "$USER"
```

If the run immediately exits with status `141`, pull the latest scripts and run
again:

```bash
git pull --ff-only
./scripts/hakusan/run_10_episodes_on_node.sh
```

These messages are expected and are not fatal errors:

```text
libtinfo.so.6: no version information available
Gym has been unmaintained since 2022
EARLY FUSION ON, USING MHA-B
```

If the command has not returned to the shell prompt, the run is still active.
Fatal errors usually include `Traceback`, `RuntimeError`, or
`ERROR: SG-Nav run failed`.

The run has started correctly when you see lines like these:

```text
Successfully loaded stage named : data/MatterPort3D/mp3d/...
reconstruct navmesh successful
Initializing task ObjectNav-v1
[SG-Nav] episode_start=0 total_episodes=10
[SG-Nav] episode 1/10 (1/10) start goal=...
Navigate Step: 0
```

The run is progressing correctly when episode result and average lines appear:

```text
[SG-Nav] episode 1/10 (1/10) result distance_to_goal=..., success=..., spl=...
[SG-Nav] average 1/10: distance_to_goal=..., success=..., spl=...
[SG-Nav] episode 2/10 (2/10) start goal=...
```

The run is complete when `run_10_episodes_on_node.sh` prints:

```text
OK: SG-Nav run completed.
```

## 7. Aggregate Results

Run this after the job completes. This is a lightweight command and can be run
on the login node after the A40 session ends:

```bash
cd "$HOME/sg-nav"
git pull --ff-only
scripts/hakusan/aggregate_episode_runs.py 'assets/data/results/experiment_0/[0:1]/episodes_0_10/results.txt'
```

Submitted output:

```text
[assets/data/results/experiment_0/[0:1]/episodes_0_10/results.txt] episodes=10

total_episodes=10
weighted_average:
  distance_to_goal: 2.466671
  softspl: 0.248937 (24.89%)
  spl: 0.172725 (17.27%)
  success: 0.400000 (40.00%)

report:
  SR: 40.0%
  SPL: 17.3%
  Distance-to-goal: 2.467
```

## Optional Clean Re-run

Do not delete the successful run until the report is finished. To test the
README from scratch, keep the successful directory as evidence and clone again:

```bash
cd "$HOME"
mv sg-nav "sg-nav-success-$(date +%Y%m%d-%H%M)"
git clone https://github.com/imayu1129/SG-Nav.git "$HOME/sg-nav"
cd "$HOME/sg-nav"
```

## Troubleshooting

- `Matterport3D scenes directory is missing`: the bundle was not extracted into
  `~/sg-nav/assets`.
- `sg-nav_hakusan_readme.sif: no such file`: run Step 3 before Step 4.
- `ObjectNav val episode file is missing`: the bundle was not extracted into
  `~/sg-nav/assets`.
- `model checkpoint is missing`: the bundle was not extracted into
  `~/sg-nav/assets`.
- `OpenAI API HTTP 429 ... insufficient_quota`: fix OpenAI billing/quota.
- `WARNING: Could not find any nv files on this host`: you are probably not
  inside the A40 compute node. Run Step 2 first.
- `EGL_NOT_INITIALIZED`: use `scripts/hakusan/sg_nav_hakusan.sbatch`.
- `singularity: command not found`: run `git pull --ff-only` and rerun the same
  step. The scripts search both modules and Hakusan absolute install paths.
- `Connection closed by ... port 22`: try `hakusan2`, then retry later if both
  login nodes reject the session.
- `Permission denied` when running `aggregate_episode_runs.py`: run
  `git pull --ff-only` and retry, or run it with `python3`.
- `No such file or directory ... [0:1]/results.txt`: use the
  `episodes_0_10/results.txt` path shown in Step 7.
- `git pull --ff-only` says local changes would be overwritten: this only means
  your Hakusan copy has local edits. It does not affect GitHub. Restore the
  local scripts and pull again:

```bash
git fetch origin
git restore scripts/hakusan/build_sif_on_hakusan.sh scripts/hakusan/sg_nav_hakusan.sbatch
git pull --ff-only
```

## Author: Create the Bundle

This is only for the person preparing the reproduction artifact:

```bash
./scripts/hakusan/package_reproduction_bundle.sh
```

Upload `dist/hakusan/sg-nav_reproduction_bundle.tar.gz` to a private or
institutional file host, then put that URL in Step 3.

The current tested bundle is:

```text
Size:   30G
SHA256: d253d9ddc2c16b6d5f7b339968e8f0d2bcb3fa0dd1de1370d5bc045deae68607
```
