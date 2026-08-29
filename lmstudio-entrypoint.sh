#!/usr/bin/env bash
set -euo pipefail

state_file=${LMSTUDIO_STARTUP_STATE_FILE:-/var/lib/local-llm-stack/lmstudio-startup.env}
backend=/root/.lmstudio/extensions/backends/llama.cpp-linux-x86_64-nvidia-cuda-avx2-2.30.0/llama-server
quality_model_path=/root/.lmstudio/models/ggml-org/gpt-oss-120b-GGUF/gpt-oss-120b-MXFP4.gguf
quality_vendor_path=/root/.lmstudio/models/.runtime/linux-llama-cuda-vendor-v1

state_value() {
  local key=$1
  sed -n "s/^${key}=//p" "$state_file" | tail -n 1
}

preset=none
model_id=
download_spec=
load_key=
model_path=
context_window=${LOCAL_CONTEXT_WINDOW:-65536}
gpu_offload=${LOCAL_GPU_OFFLOAD:-}

if [[ -r "$state_file" ]]; then
  preset=$(state_value PRESET)
  model_id=$(state_value MODEL_ID)
  download_spec=$(state_value DOWNLOAD_SPEC)
  load_key=$(state_value LOAD_KEY)
  model_path=$(state_value MODEL_PATH)
  context_window=$(state_value CONTEXT_WINDOW)
  gpu_offload=$(state_value GPU_OFFLOAD)
fi

case "$preset" in
  none|managed|quality) ;;
  *) echo "Invalid LM Studio startup preset: $preset" >&2; exit 2 ;;
esac
case "$context_window" in
  ''|*[!0-9]*) echo "Invalid LM Studio context window: $context_window" >&2; exit 2 ;;
esac

lms daemon up

if [[ "$preset" == quality ]]; then
  if ! awk 'NR > 1 && $1 ~ /\.modelctl\.swap$/ { found = 1 } END { exit !found }' /proc/swaps; then
    echo "The project-managed swap must be active before loading the quality model." >&2
    exit 1
  fi
  lms server start --bind "$LMS_SERVER_HOST" --port "$LMS_SERVER_PORT"
  if [[ ! -f "$quality_model_path" ]]; then
    lms get "$download_spec" --yes
  fi
  lms server stop
  if [[ ! -f "$quality_vendor_path/libcudart.so.11.0" ]]; then
    vendor=
    for attempt in $(seq 1 120); do
      vendor=$(find /root/.lmstudio/llmster -type f -name libcudart.so.11.0 -printf '%h\n' -quit 2>/dev/null)
      if [[ -x "$backend" && -n "$vendor" ]]; then
        break
      fi
      sleep 1
    done
    [[ -n "$vendor" ]]
    mkdir -p "$(dirname "$quality_vendor_path")"
    cp -a "$vendor" "$quality_vendor_path"
  fi
  [[ -x "$backend" ]]
  [[ -f "$quality_model_path" ]]
  export LD_LIBRARY_PATH="$quality_vendor_path"
  exec > >(tee -a /tmp/gpt-oss-120b-quality.log) 2>&1
  printf '\nLM Studio quality runtime starting at %s\n' "$(date -Iseconds)"
  "$backend" \
    --model "$quality_model_path" \
    --alias local/model \
    --host 0.0.0.0 \
    --port 1234 \
    --ctx-size 32768 \
    --gpu-layers 6 \
    --fit off \
    --split-mode layer \
    --tensor-split 6,13 \
    --batch-size 256 \
    --ubatch-size 256 \
    --threads 10 \
    --parallel 1 \
    --flash-attn on \
    --cache-type-k f16 \
    --cache-type-v f16 \
    --kv-offload \
    --kv-unified \
    --load-mode mmap \
    --jinja \
    --no-mmproj \
    --verbosity 3 &
  server_pid=$!
  trap 'kill -TERM "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; exit 0' TERM INT
  set +e
  wait "$server_pid"
  status=$?
  set -e
  exit "$status"
fi

lms server start --bind "$LMS_SERVER_HOST" --port "$LMS_SERVER_PORT"

if [[ "$preset" == managed ]]; then
  if [[ -z "$model_path" || ! -f "$model_path" ]]; then
    lms get "$download_spec" --yes
  fi
  load_command=(
    lms load "$load_key"
    --identifier local/model
    --context-length "$context_window"
    --parallel 1
    --yes
  )
  if [[ -n "$gpu_offload" ]]; then
    load_command+=(--gpu "$gpu_offload")
  fi
  "${load_command[@]}"
fi

exec lms log stream
