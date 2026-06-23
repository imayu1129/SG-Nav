#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SLURM_JOB_ID:-}" ]]; then
  echo "ERROR: run this inside the A40 session created by enter_a40_node.sh." >&2
  exit 1
fi

cd "${SG_NAV_REPO_DIR:-$PWD}"

SECRET_ENV="${SG_NAV_SECRET_ENV:-$HOME/.config/sg-nav/openai.env}"
if [[ -r "${SECRET_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${SECRET_ENV}"
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "ERROR: OPENAI_API_KEY is not set. Run configure_openai_key.sh first." >&2
  exit 1
fi

RUN_LOG="${RUN_LOG:-sg-nav-a40-${SLURM_JOB_ID}.log}"
echo "Run log: ${RUN_LOG}"

set +e
ARGS="${ARGS:---split_l 0 --split_r 1 --num_episodes 10}" \
  LLM_BACKEND="${LLM_BACKEND:-openai}" \
  LLM_MODEL="${LLM_MODEL:-gpt-4o}" \
  VLM_MODEL="${VLM_MODEL:-gpt-4o}" \
  bash scripts/hakusan/sg_nav_hakusan.sbatch 2>&1 | tee "${RUN_LOG}"
status=${PIPESTATUS[0]}
set -e

if [[ "${status}" -eq 0 ]]; then
  echo "OK: SG-Nav run completed. Log: ${RUN_LOG}"
else
  echo "ERROR: SG-Nav run failed with exit status ${status}. Log: ${RUN_LOG}" >&2
fi

exit "${status}"
