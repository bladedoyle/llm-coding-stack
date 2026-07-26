#!/bin/sh
set -eu

settings_file="${1:?usage: configure-claude-provider.sh /path/to/settings.json}"
provider="${LLM_PROVIDER:-chutes}"

case "$provider" in
  chutes)
    model="chutes/model"
    context_window="${CHUTES_CONTEXT_WINDOW:-65536}"
    context_variable="CHUTES_CONTEXT_WINDOW"
    ;;
  local)
    model="openai/gpt-oss-20b"
    context_window="${LOCAL_CONTEXT_WINDOW:-65536}"
    context_variable="LOCAL_CONTEXT_WINDOW"
    ;;
  openrouter)
    model="openrouter/model"
    context_window="${OPENROUTER_CONTEXT_WINDOW:-98304}"
    context_variable="OPENROUTER_CONTEXT_WINDOW"
    ;;
  *)
    echo "LLM_PROVIDER must be 'chutes', 'local', or 'openrouter', got: $provider" >&2
    exit 1
    ;;
esac

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

settings_dir=$(dirname "$settings_file")
mkdir -p "$settings_dir"

if [ -s "$settings_file" ]; then
  jq empty "$settings_file"
else
  printf '{}\n' > "$settings_file"
fi

temporary_file="${settings_file}.tmp"
jq \
  --arg model "$model" \
  --arg context_window "$context_window" \
  '.env = ((.env // {}) + {
    "ANTHROPIC_BASE_URL": "http://litellm:4000",
    "ANTHROPIC_AUTH_TOKEN": "lm-studio",
    "ANTHROPIC_MODEL": $model,
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": $model,
    "ANTHROPIC_DEFAULT_SONNET_MODEL": $model,
    "ANTHROPIC_DEFAULT_OPUS_MODEL": $model,
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": $context_window,
    "ENABLE_TOOL_SEARCH": "false",
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  })' \
  "$settings_file" > "$temporary_file"
mv "$temporary_file" "$settings_file"
