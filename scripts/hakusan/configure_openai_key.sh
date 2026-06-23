#!/usr/bin/env bash
set -euo pipefail

SECRET_DIR="${SECRET_DIR:-$HOME/.config/sg-nav}"
SECRET_ENV="${SECRET_ENV:-${SECRET_DIR}/openai.env}"
LLM_MODEL="${LLM_MODEL:-gpt-4o}"
VLM_MODEL="${VLM_MODEL:-gpt-4o}"

mkdir -p "${SECRET_DIR}"
chmod 700 "${SECRET_DIR}"

read -rsp "OPENAI_API_KEY: " OPENAI_API_KEY
echo

if [[ -z "${OPENAI_API_KEY}" ]]; then
  echo "ERROR: OPENAI_API_KEY was empty." >&2
  exit 1
fi

umask 077
{
  printf 'export OPENAI_API_KEY=%q\n' "${OPENAI_API_KEY}"
  printf 'export LLM_BACKEND=openai\n'
  printf 'export LLM_MODEL=%q\n' "${LLM_MODEL}"
  printf 'export VLM_MODEL=%q\n' "${VLM_MODEL}"
} > "${SECRET_ENV}"
chmod 600 "${SECRET_ENV}"
unset OPENAI_API_KEY

echo "OK: wrote OpenAI settings to ${SECRET_ENV}"
