#!/usr/bin/env bash
set -euo pipefail

srun \
  -p GPU-1 \
  --gres=gpu:nvidia_a40:1 \
  --cpus-per-task=1 \
  --mem=128G \
  --time=12:00:00 \
  --pty bash -l
