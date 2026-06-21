# SG-Nav-GPT MP3D Reproduction on Hakusan

This repository is a course reproduction of **SG-Nav: Online 3D Scene Graph
Prompting for LLM-based Zero-shot Object Navigation**.

The goal of this repository is not to be a project landing page. It is a
step-by-step implementation and reproduction package that another reviewer can
clone, prepare on Hakusan, run, monitor, and verify.

- Paper: [arXiv:2410.08189](https://arxiv.org/abs/2410.08189)
- Original project page: <https://bagh2178.github.io/SG-Nav/>
- Reproduced setting: **SG-Nav-GPT on Matterport3D (MP3D) ObjectNav**
- Frameworks: Python, PyTorch, Habitat-Sim, Habitat-Lab, GLIP, SAM-related
  perception modules, OpenAI Responses API
- Submitted run: first `10` MP3D validation episodes
- Paper full-validation result: SR `40.2%`, SPL `16.0%`
- This partial reproduction: SR `30.0%`, SPL `14.0%`,
  distance-to-goal `3.194`

The original SG-Nav codebase is kept as the core architecture. The additions in
this fork are reproducibility controls: OpenAI/GPT backend support, deterministic
episode subset selection, compact progress logs, Hakusan Slurm/Singularity
scripts, and result aggregation utilities.

## What Is Being Reproduced?

SG-Nav is a zero-shot object-goal navigation method. In one ObjectNav episode,
the agent starts from one pose in an indoor scene and must find one target object
category such as `cabinet` or `chair`. A run succeeds if the agent stops close
enough to a target instance.

The reproduced pipeline follows the paper's SG-Nav-GPT setup:

1. Habitat provides RGB-D observations and ObjectNav episodes.
2. GLIP/SAM-style perception modules detect and segment objects.
3. Observations are projected into an online 3D scene graph.
4. A GPT backend reasons over the scene graph and selects navigation targets.
5. Habitat computes ObjectNav metrics such as SR, SPL, SoftSPL, and
   distance-to-goal.

This repository reports SR and SPL as the primary reproduction metrics. SoftSPL
is still saved in the raw result file, but SR and SPL are emphasized because
they are the clearest comparison to the paper table.

## Repository Layout

```text
SG_Nav.py                         Main SG-Nav entry point
scenegraph.py                     Online scene graph and LLM/VLM calls
habitat-lab/habitat/core/         Local Habitat evaluation hooks
GLIP/                             GLIP detector code
segment_anything/                 SAM-related segmentation code
GroundingDINO/                    GroundingDINO dependency
docker/hakusan/Dockerfile         Docker image used before Singularity conversion
scripts/hakusan/                  Hakusan build, transfer, run, monitor scripts
run_sg_nav.sh                     Runtime wrapper inside the container
check_sg_nav_env.sh               Environment sanity check wrapper
tools/check_sg_nav_env.py         Python environment sanity check
```

Large assets are intentionally not committed:

- Matterport3D scenes and ObjectNav episodes
- GLIP/SAM/GroundingDINO checkpoints
- Docker image tar files
- Singularity image files
- logs and temporary runtime directories

## Prerequisites

The tested workflow uses two machines:

- Local machine with Docker and the SG-Nav conda environment
- Hakusan GPU node with Slurm and Singularity/Apptainer

The local environment should already follow the upstream SG-Nav setup as much as
possible:

- conda env: `SG_Nav`
- Python: `3.9`
- PyTorch stack compatible with the public SG-Nav repository
- Habitat-Sim/Habitat-Lab
- GLIP build
- Matterport3D ObjectNav data
- required checkpoints

Expected local asset layout:

```text
data/MatterPort3D/
├── mp3d/
│   └── <scene_id>/<scene_id>.glb
└── objectnav/mp3d/v1/val/
    ├── content/*.json.gz
    └── val.json.gz
GLIP/MODEL/glip_large_model.pth
.local/ollama-models/              Optional; not needed for SG-Nav-GPT
```

## Step 1: Clone the Repository Locally

Use recursive clone because SG-Nav depends on subdirectories/submodules in the
public codebase.

```bash
git clone --recursive https://github.com/imayu1129/SG-Nav.git
cd SG-Nav
```

If the repository was cloned without submodules:

```bash
git submodule update --init --recursive
```

## Step 2: Check the Local Environment

Activate the local conda environment and run the sanity check:

```bash
conda activate SG_Nav
./check_sg_nav_env.sh
```

This verifies key Python modules and paths before packaging. Local execution on
a small GPU may still run out of memory because SG-Nav loads several large
perception modules together. The submitted reproduction therefore runs on
Hakusan.

## Step 3: Build the Local Docker Image

Build a Docker image from the current conda environment and source tree.

```bash
INCLUDE_ASSETS=0 ./scripts/hakusan/build_local_image.sh
```

`INCLUDE_ASSETS=0` keeps the Docker image smaller. Dataset/checkpoint assets are
packed separately in Step 5.

## Step 4: Save the Docker Image as a Tar Archive

```bash
./scripts/hakusan/save_image.sh
```

This creates:

```text
dist/hakusan/sg-nav_hakusan_readme.tar.gz
dist/hakusan/sg-nav_hakusan_readme_submit_files.tar.gz
```

## Step 5: Package External Assets

```bash
./scripts/hakusan/package_assets.sh
```

This creates:

```text
dist/hakusan/sg-nav_hakusan_readme_assets.tar.gz
```

Create checksums:

```bash
cd dist/hakusan && sha256sum sg-nav_hakusan_readme.tar.gz sg-nav_hakusan_readme_assets.tar.gz sg-nav_hakusan_readme_submit_files.tar.gz > SHA256SUMS && cd ../..
```

## Step 6: Transfer Files to Hakusan

Set your own Hakusan login and transfer directory. Do not hard-code API keys or
passwords into scripts.

```bash
export REMOTE="<your-jaist-id>@hakusan1"
export REMOTE_DIR="~/sg-nav-work"
./scripts/hakusan/scp_to_hakusan.sh
```

The script copies the image archive, asset archive, helper scripts, and
checksums.

## Step 7: Build the Singularity Image on Hakusan

SSH into Hakusan:

```bash
ssh <your-jaist-id>@hakusan1.jaist.ac.jp
cd ~/sg-nav-work
```

Verify checksums and extract helper/assets archives:

```bash
sha256sum -c SHA256SUMS
tar -xzf sg-nav_hakusan_readme_submit_files.tar.gz
mkdir -p assets
tar -xzf sg-nav_hakusan_readme_assets.tar.gz -C assets
```

Build the SIF image:

```bash
./scripts/hakusan/build_sif_on_hakusan.sh sg-nav_hakusan_readme.tar.gz
```

For large builds, submit the SIF build through Slurm instead of running it on the
login node.

## Step 8: Store the OpenAI API Key on Hakusan

The key must stay outside the repository.

```bash
mkdir -p "$HOME/.config/sg-nav" && chmod 700 "$HOME/.config/sg-nav" && read -rsp "OPENAI_API_KEY: " OPENAI_API_KEY; echo; umask 077; printf 'export OPENAI_API_KEY=%q\nexport LLM_BACKEND=openai\nexport LLM_MODEL=gpt-4o\nexport VLM_MODEL=gpt-4o\n' "$OPENAI_API_KEY" > "$HOME/.config/sg-nav/openai.env"; chmod 600 "$HOME/.config/sg-nav/openai.env"; unset OPENAI_API_KEY
```

Check that the API and quota work:

```bash
cd ~/sg-nav-work && source "$HOME/.config/sg-nav/openai.env" && LLM_MODEL=gpt-4o scripts/hakusan/check_openai_quota.py
```

Expected output:

```text
OK: OpenAI Responses API is reachable for model=gpt-4o.
```

If the output says `insufficient_quota`, fix billing/credit/project limits before
running SG-Nav.

## Step 9: Submit the 10-Episode SG-Nav-GPT Run

```bash
cd ~/sg-nav-work && source "$HOME/.config/sg-nav/openai.env" && LLM_MODEL=gpt-4o scripts/hakusan/check_openai_quota.py && ARGS="--split_l 0 --split_r 1 --num_episodes 10" LLM_BACKEND=openai LLM_MODEL=gpt-4o VLM_MODEL=gpt-4o sbatch scripts/hakusan/sg_nav_hakusan.sbatch
```

Slurm prints a job id:

```text
Submitted batch job <JOBID>
```

## Step 10: Monitor Progress

Use the compact watcher:

```bash
cd ~/sg-nav-work && COMPACT=1 scripts/hakusan/watch_job.sh <JOBID> sg-nav
```

The important progress lines look like this:

```text
[SG-Nav] episode_start=0 total_episodes=10
[SG-Nav] episode 1/10 (1/10) start goal=cabinet
[SG-Nav] episode 1/10 (1/10) result distance_to_goal=..., success=..., spl=...
[SG-Nav] average 10/10: distance_to_goal=..., success=..., spl=...
```

If you prefer a single command without the helper script:

```bash
JOBID=<JOBID>; while true; do date; squeue -j "$JOBID"; sacct -j "$JOBID" --format=JobID,JobName,State,ExitCode,Elapsed -X 2>/dev/null || true; grep -E "\\[SG-Nav\\]|Navigate Step|distance_to_goal|success|spl|Traceback|ERROR|OpenAI" "sg-nav-${JOBID}.out" "sg-nav-${JOBID}.err" 2>/dev/null | tail -n 80; sleep 60; done
```

## Step 11: Aggregate the Result

After the job completes:

```bash
cd ~/sg-nav-work
scripts/hakusan/aggregate_episode_runs.py assets/data/results/experiment_0/[0:1]/results.txt
```

Submitted reproduction result:

```text
total_episodes=10
distance_to_goal=3.194012809393462
success=0.300000
spl=0.139923
softspl=0.216574
```

Report these as:

- SR: `30.0%`
- SPL: `14.0%`
- Distance-to-goal: `3.194`

## Optional: Run a Different Episode Window

To run ten episodes starting from episode 10:

```bash
ARGS="--split_l 0 --split_r 1 --episode_start 10 --num_episodes 10" LLM_BACKEND=openai LLM_MODEL=gpt-4o VLM_MODEL=gpt-4o sbatch scripts/hakusan/sg_nav_hakusan.sbatch
```

This writes to a separate result directory such as:

```text
assets/data/results/experiment_0/[0:1]/episodes_10_20/results.txt
```

Aggregate multiple windows:

```bash
scripts/hakusan/aggregate_episode_runs.py \
  assets/data/results/experiment_0/[0:1]/results.txt \
  assets/data/results/experiment_0/[0:1]/episodes_10_20/results.txt
```

## Troubleshooting

- `OpenAI API HTTP 429 ... insufficient_quota`:
  billing/quota issue, not a GPU or SG-Nav code failure.
- `SG_Nav.py: error: unrecognized arguments: --num_episodes`:
  Hakusan has an old source file. Re-copy the repository or rebuild the SIF.
- `WARNING: Could not find any nv files on this host`:
  likely running on a login node. Submit a Slurm GPU job.
- `EGL_NOT_INITIALIZED`:
  use `scripts/hakusan/sg_nav_hakusan.sbatch`, which binds NVIDIA EGL libraries.
- `singularity: command not found`:
  run through `#!/bin/bash -l` and load `singularity` or `apptainer`.
- Gym, `libtinfo`, PyTorch deprecation, and Transformer future warnings:
  noisy but not fatal. The reproduction scripts suppress most non-critical
  warnings for readability.

## What Changed for Reproducibility?

- Added `--llm_backend openai` for SG-Nav-GPT.
- Added `--num_episodes` and `--episode_start` for controlled subset evaluation.
- Added compact per-episode logs for SR/SPL progress.
- Added OpenAI quota checking before Slurm submission.
- Added Hakusan Docker-to-Singularity packaging scripts.
- Added comments around the reproduction-specific code paths.

These changes are for reproducibility and clarity. They do not replace the core
SG-Nav architecture.

## Citation

```bibtex
@article{yin2024sgnav,
  title={SG-Nav: Online 3D Scene Graph Prompting for LLM-based Zero-shot Object Navigation},
  author={Hang Yin and Xiuwei Xu and Zhenyu Wu and Jie Zhou and Jiwen Lu},
  journal={arXiv preprint arXiv:2410.08189},
  year={2024}
}
```
