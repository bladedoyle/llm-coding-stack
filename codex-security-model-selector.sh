#!/bin/sh
set -eu

real_binary="${CODEX_SECURITY_REAL_BIN:-/usr/local/bin/codex-security.real}"
provider="${LLM_PROVIDER:-chutes}"
catalog="${CODEX_SECURITY_MODEL_CATALOG_JSON:-${HOME}/.codex/model-catalogs/local.json}"
context_window=

command_name=
for argument in "$@"; do
  case "$argument" in
    scan|bulk-scan|export|info|install-hook|login|logout|patch|scans|validate)
      command_name="$argument"
      break
      ;;
  esac
done

if [ "$command_name" != "scan" ]; then
  exec "$real_binary" "$@"
fi

case "$provider" in
  local)
    model="local/model"
    provider_id="local-lm-studio"
    provider_name="Local LM Studio"
    base_url="http://lmstudio:1234/v1"
    env_key="CODEX_LM_STUDIO_API_KEY"
    context_window="${LOCAL_CONTEXT_WINDOW:-65536}"
    ;;
  chutes)
    model="chutes/model-responses"
    provider_id="chutes"
    provider_name="Chutes via LiteLLM"
    base_url="http://litellm:4000/v1"
    env_key="CODEX_LITELLM_API_KEY"
    ;;
  openrouter)
    model="openrouter/model"
    provider_id="openrouter"
    provider_name="OpenRouter via LiteLLM"
    base_url="http://litellm:4000/v1"
    env_key="CODEX_LITELLM_API_KEY"
    ;;
  *)
    echo "LLM_PROVIDER must be 'chutes', 'local', or 'openrouter', got: $provider" >&2
    exit 1
    ;;
esac

if [ -n "$context_window" ]; then
  case "$context_window" in
    *[!0-9]*)
      echo "LOCAL_CONTEXT_WINDOW must be a positive integer" >&2
      exit 1
      ;;
  esac

  if [ "$context_window" -lt 1 ]; then
    echo "LOCAL_CONTEXT_WINDOW must be greater than zero" >&2
    exit 1
  fi
fi

if [ ! -r "$catalog" ]; then
  echo "Codex Security model catalog is not readable: $catalog" >&2
  exit 1
fi

has_model=false
has_provider=false
has_provider_definition=false
has_context_window=false
has_catalog=false
expect_codex_value=false

inspect_codex_override() {
  case "$1" in
    model=*)
      has_model=true
      ;;
    model_provider=*)
      has_provider=true
      ;;
    model_providers.*=*)
      has_provider_definition=true
      ;;
    model_context_window=*)
      has_context_window=true
      ;;
    model_catalog_json=*)
      has_catalog=true
      ;;
  esac
}

for argument in "$@"; do
  if [ "$expect_codex_value" = true ]; then
    inspect_codex_override "$argument"
    expect_codex_value=false
    continue
  fi

  case "$argument" in
    --model|--model=*)
      has_model=true
      ;;
    --codex)
      expect_codex_value=true
      ;;
    --codex=*)
      inspect_codex_override "${argument#--codex=}"
      ;;
  esac
done

if [ "$has_model" = false ]; then
  set -- "$@" --model "$model"
fi
if [ "$has_provider" = false ]; then
  set -- "$@" --codex "model_provider=\"$provider_id\""
fi
if [ "$has_provider_definition" = false ]; then
  set -- "$@" --codex "model_providers.$provider_id={name=\"$provider_name\",base_url=\"$base_url\",env_key=\"$env_key\",wire_api=\"responses\",stream_max_retries=50}"
fi
if [ -n "$context_window" ] && [ "$has_context_window" = false ]; then
  set -- "$@" --codex "model_context_window=$context_window"
fi
if [ "$has_catalog" = false ]; then
  set -- "$@" --codex "model_catalog_json=\"$catalog\""
fi

exec "$real_binary" "$@"
