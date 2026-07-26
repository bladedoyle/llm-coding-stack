#!/bin/sh
set -eu

if [ "${1:-}" = "--chutes-profile" ] || [ "${1:-}" = "--openrouter-profile" ]; then
  config_file="${2:?usage: configure-codex-provider.sh --<provider>-profile /path/to/config.toml}"
  if [ "$1" = "--chutes-profile" ]; then
    context_window="${CHUTES_CONTEXT_WINDOW:-65536}"
    context_variable="CHUTES_CONTEXT_WINDOW"
  else
    context_window="${OPENROUTER_CONTEXT_WINDOW:-98304}"
    context_variable="OPENROUTER_CONTEXT_WINDOW"
  fi

  case "$context_window" in
    ''|*[!0-9]*)
      echo "$context_variable must be a positive integer" >&2
      exit 1
      ;;
  esac
  if [ "$context_window" -lt 1 ]; then
    echo "$context_variable must be greater than zero" >&2
    exit 1
  fi

  sed -i -E "s|^model_context_window = [0-9]+$|model_context_window = $context_window|" "$config_file"
  exit 0
fi

config_file="${1:?usage: configure-codex-provider.sh /path/to/config.toml}"
provider="${LLM_PROVIDER:-chutes}"

case "$provider" in
  chutes)
    model="chutes/model-responses"
    model_provider="chutes"
    context_window="${CHUTES_CONTEXT_WINDOW:-98304}"
    ;;
  local)
    model="openai/gpt-oss-20b"
    model_provider="local-lm-studio"
    context_window="${LOCAL_CONTEXT_WINDOW:-65536}"
    ;;
  openrouter)
    # Keep the Codex-facing route stable. LiteLLM resolves this alias to the
    # exact provider model selected by OPENROUTER_MODEL.
    model="openrouter/model"
    model_provider="openrouter"
    context_window="${OPENROUTER_CONTEXT_WINDOW:-98304}"
    ;;
  *)
    echo "LLM_PROVIDER must be 'chutes', 'local', or 'openrouter', got: $provider" >&2
    exit 1
    ;;
esac

case "$context_window" in
  ''|*[!0-9]*)
    echo "The selected provider context window must be a positive integer" >&2
    exit 1
    ;;
esac

if [ "$context_window" -lt 1 ]; then
  echo "The selected provider context window must be greater than zero" >&2
  exit 1
fi

sed -i -E \
  -e "s|^model_provider = .*|model_provider = \"$model_provider\"|" \
  -e "s|^model = .*|model = \"$model\"|" \
  -e "s|^model_context_window = [0-9]+$|model_context_window = $context_window|" \
  "$config_file"
