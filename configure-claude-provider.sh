#!/bin/sh
set -eu

settings_file="${1:?usage: configure-claude-provider.sh /path/to/settings.json}"
provider="${LLM_PROVIDER:-chutes}"
context_window=

case "$provider" in
  chutes)
    model="chutes/model"
    base_url="http://litellm:4000"
    ;;
  local)
    model="local/model"
    base_url="http://lmstudio:1234"
    context_window="${LOCAL_CONTEXT_WINDOW:-65536}"
    ;;
  openrouter)
    model="openrouter/model"
    base_url="http://litellm:4000"
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
  --arg base_url "$base_url" \
  --arg context_window "$context_window" \
  '.env = ((.env // {}) + {
    "ANTHROPIC_BASE_URL": $base_url,
    "ANTHROPIC_AUTH_TOKEN": "lm-studio",
    "ANTHROPIC_MODEL": $model,
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": $model,
    "ANTHROPIC_DEFAULT_SONNET_MODEL": $model,
    "ANTHROPIC_DEFAULT_OPUS_MODEL": $model,
    "ENABLE_TOOL_SEARCH": "false",
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  })
  | if $context_window == "" then
      del(.env.CLAUDE_CODE_MAX_CONTEXT_TOKENS)
    else
      .env.CLAUDE_CODE_MAX_CONTEXT_TOKENS = $context_window
    end' \
  "$settings_file" > "$temporary_file"
mv "$temporary_file" "$settings_file"
