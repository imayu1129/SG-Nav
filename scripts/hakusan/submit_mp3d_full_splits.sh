#!/usr/bin/env bash
set -euo pipefail

SBATCH_FILE="${SBATCH_FILE:-sg_nav_hakusan.sbatch}"
START_SPLIT="${START_SPLIT:-0}"
END_SPLIT="${END_SPLIT:-11}"
SUBMIT_MODE="${SUBMIT_MODE:-serial}" # serial, limited, or parallel
MAX_PARALLEL="${MAX_PARALLEL:-4}"     # used only when SUBMIT_MODE=limited
JOB_RECORD="${JOB_RECORD:-mp3d_full_jobs.tsv}"
LLM_BACKEND="${LLM_BACKEND:-openai}"
LLM_MODEL="${LLM_MODEL:-gpt-4o}"
VLM_MODEL="${VLM_MODEL:-gpt-4o}"
SG_NAV_COMPACT_METRICS="${SG_NAV_COMPACT_METRICS:-1}"
SG_NAV_VERBOSE_WARNINGS="${SG_NAV_VERBOSE_WARNINGS:-0}"

if [[ ! -f "${SBATCH_FILE}" ]]; then
  echo "ERROR: ${SBATCH_FILE} was not found in $(pwd)" >&2
  exit 1
fi

case "${SUBMIT_MODE}" in
  serial|limited|parallel) ;;
  *)
    echo "ERROR: SUBMIT_MODE must be serial, limited, or parallel, got '${SUBMIT_MODE}'" >&2
    exit 1
    ;;
esac
if [[ "${SUBMIT_MODE}" == "limited" && "${MAX_PARALLEL}" -lt 1 ]]; then
  echo "ERROR: MAX_PARALLEL must be >= 1" >&2
  exit 1
fi

printf "split_l\tsplit_r\tjob_id\tmode\targs\n" > "${JOB_RECORD}"

previous_job_id=""
declare -a lane_job_ids=()
for split_l in $(seq "${START_SPLIT}" $((END_SPLIT - 1))); do
  split_r=$((split_l + 1))
  args="--split_l ${split_l} --split_r ${split_r}"
  export_vars="ALL,ARGS=${args},LLM_BACKEND=${LLM_BACKEND},LLM_MODEL=${LLM_MODEL},VLM_MODEL=${VLM_MODEL},SG_NAV_COMPACT_METRICS=${SG_NAV_COMPACT_METRICS},SG_NAV_VERBOSE_WARNINGS=${SG_NAV_VERBOSE_WARNINGS}"

  dependency_args=()
  if [[ "${SUBMIT_MODE}" == "serial" && -n "${previous_job_id}" ]]; then
    dependency_args=(--dependency="afterany:${previous_job_id}")
  elif [[ "${SUBMIT_MODE}" == "limited" ]]; then
    lane=$(((split_l - START_SPLIT) % MAX_PARALLEL))
    if [[ -n "${lane_job_ids[$lane]:-}" ]]; then
      dependency_args=(--dependency="afterany:${lane_job_ids[$lane]}")
    fi
  fi

  job_id="$(sbatch "${dependency_args[@]}" --export="${export_vars}" "${SBATCH_FILE}" | awk '{print $4}')"
  printf "%s\t%s\t%s\t%s\t%s\n" "${split_l}" "${split_r}" "${job_id}" "${SUBMIT_MODE}" "${args}" | tee -a "${JOB_RECORD}"
  previous_job_id="${job_id}"
  if [[ "${SUBMIT_MODE}" == "limited" ]]; then
    lane_job_ids[$lane]="${job_id}"
  fi
done

echo
echo "Recorded jobs in ${JOB_RECORD}"
echo "Monitor all submitted jobs with:"
echo "  JOBIDS=\$(awk 'NR>1 {print \$3}' ${JOB_RECORD} | paste -sd, -)"
echo "  squeue -j \"\$JOBIDS\""
