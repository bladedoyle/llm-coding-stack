#!/bin/sh
set -eu

require_exact_setting() {
  expected_setting="$1"
  match_count=$(grep -Fxc "$expected_setting" "$config_file" || true)
  if [ "$match_count" -ne 1 ]; then
    echo "Failed to apply Codex setting in $config_file: $expected_setting" >&2
    exit 1
  fi
}

config_file="${1:?usage: configure-codex-provider.sh /path/to/config.toml}"
provider="${LLM_PROVIDER:-chutes}"
context_window=

case "$provider" in
  chutes)
    model="chutes/model-responses"
    model_provider="chutes"
    ;;
  local)
    model="local/model"
    model_provider="local-lm-studio"
    context_window="${LOCAL_CONTEXT_WINDOW:-65536}"
    ;;
  openrouter)
    # Keep the Codex-facing route stable. LiteLLM resolves this alias to the
    # exact provider model selected by OPENROUTER_MODEL.
    model="openrouter/model"
    model_provider="openrouter"
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

sed -i -E \
  -e "s|^model_provider = .*|model_provider = \"$model_provider\"|" \
  -e "s|^model = .*|model = \"$model\"|" \
  -e "/^model_context_window = /d" \
  "$config_file"

if [ -n "$context_window" ]; then
  sed -i -E "/^model = /a model_context_window = $context_window" "$config_file"
fi

require_exact_setting "model_provider = \"$model_provider\""
require_exact_setting "model = \"$model\""
if [ -n "$context_window" ]; then
  require_exact_setting "model_context_window = $context_window"
elif grep -q '^model_context_window = ' "$config_file"; then
  echo "Failed to remove the cloud-provider context override in $config_file" >&2
  exit 1
fi
