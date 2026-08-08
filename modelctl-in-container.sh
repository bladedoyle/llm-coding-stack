#!/bin/sh
set -eu

app="${MODELCTL_APP:?MODELCTL_APP must be codex or claude}"
state_file="${MODEL_STATE_FILE:-/var/lib/local-llm-stack/selected.env}"
default_provider="${DEFAULT_MODEL_PROVIDER:-chutes}"
default_model="${DEFAULT_MODEL:-deepseek-ai/DeepSeek-V3.2-TEE}"

usage() {
  cat >&2 <<'EOF'
Usage:
  modelctl use <chutes|openrouter|local> <model-id>
  modelctl apply
  modelctl current
EOF
  exit 2
}

validate_provider() {
  case "$1" in
    chutes|openrouter|local) ;;
    *) echo "Unknown provider: $1" >&2; exit 2 ;;
  esac
}

validate_model() {
  case "$1" in
    ''|*[!A-Za-z0-9._:/@+-]*)
      echo "Model IDs may only contain letters, digits, '.', '_', ':', '/', '@', '+', and '-'." >&2
      exit 2
      ;;
  esac
}

write_state() {
  provider="$1"
  model="$2"
  state_dir=$(dirname "$state_file")
  temporary_file=

  if [ ! -d "$state_dir" ]; then
    install -d -m 0755 "$state_dir"
  fi
  temporary_file=$(mktemp "$state_dir/.selected.env.XXXXXX")
  printf 'MODEL_PROVIDER=%s\nMODEL_ID=%s\n' "$provider" "$model" > "$temporary_file"
  chmod 0644 "$temporary_file"
  mv "$temporary_file" "$state_file"
}

read_state() {
  if [ -r "$state_file" ]; then
    provider=$(sed -n -E 's/^MODEL_PROVIDER=//p' "$state_file" | tail -n 1)
    model=$(sed -n -E 's/^MODEL_ID=//p' "$state_file" | tail -n 1)
  else
    provider="$default_provider"
    model="$default_model"
  fi
  validate_provider "$provider"
  validate_model "$model"
}

preserve_owner() {
  source_file="$1"
  temporary_file="$2"
  if [ -e "$source_file" ]; then
    chown --reference="$source_file" "$temporary_file"
  fi
}

route_for() {
  provider="$1"
  model="$2"

  case "$provider" in
    chutes)
      if [ "$app" = codex ]; then
        route="chutes-responses/$model"
      else
        route="chutes/$model"
      fi
      ;;
    openrouter) route="openrouter/$model" ;;
    local) route="local/model" ;;
  esac
}

configure_codex() {
  config_file="${CODEX_CONFIG_FILE:-$HOME/.codex/config.toml}"
  catalog_file="${CODEX_MODEL_CATALOG_JSON:-$HOME/.codex/model-catalogs/local.json}"
  temporary_file="${config_file}.tmp"

  sed \
    -e 's|^model_provider = .*|model_provider = "litellm"|' \
    -e "s|^model = .*|model = \"$route\"|" \
    "$config_file" > "$temporary_file"
  preserve_owner "$config_file" "$temporary_file"
  mv "$temporary_file" "$config_file"

  if [ -r "$catalog_file" ]; then
    temporary_file="${catalog_file}.tmp"
    jq --arg model "$route" \
      '.models[0].slug = $model
       | .models[0].display_name = $model
       | .models[0].description = "Selected with modelctl"' \
      "$catalog_file" > "$temporary_file"
    preserve_owner "$catalog_file" "$temporary_file"
    mv "$temporary_file" "$catalog_file"
  fi
}

configure_claude() {
  settings_file="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
  settings_dir=$(dirname "$settings_file")
  temporary_file="${settings_file}.tmp"

  mkdir -p "$settings_dir"
  if [ ! -s "$settings_file" ]; then
    printf '{}\n' > "$settings_file"
  fi

  jq --arg model "$route" \
    '.env = ((.env // {}) + {
      "ANTHROPIC_BASE_URL": "http://litellm:4000",
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
    | del(.env.CLAUDE_CODE_MAX_CONTEXT_TOKENS)' \
    "$settings_file" > "$temporary_file"
  preserve_owner "$settings_file" "$temporary_file"
  mv "$temporary_file" "$settings_file"
}

apply() {
  read_state
  route_for "$provider" "$model"
  case "$app" in
    codex) configure_codex ;;
    claude) configure_claude ;;
    *) echo "MODELCTL_APP must be codex or claude" >&2; exit 2 ;;
  esac
}

case "${1:-}" in
  use)
    [ "$#" -eq 3 ] || usage
    validate_provider "$2"
    validate_model "$3"
    write_state "$2" "$3"
    apply
    ;;
  apply) [ "$#" -eq 1 ] || usage; apply ;;
  current)
    [ "$#" -eq 1 ] || usage
    read_state
    printf '%s/%s\n' "$provider" "$model"
    ;;
  *) usage ;;
esac
