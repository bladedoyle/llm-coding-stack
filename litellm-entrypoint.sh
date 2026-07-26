#!/bin/sh
set -eu

set -- --config /app/config.yaml --port 4000 --host 0.0.0.0

case "${LITELLM_DEBUG_MODE:-detailed}" in
  off)
    ;;
  debug)
    set -- "$@" --debug
    ;;
  detailed)
    set -- "$@" --detailed_debug
    ;;
  *)
    echo "LITELLM_DEBUG_MODE must be 'off', 'debug', or 'detailed'" >&2
    exit 1
    ;;
esac

if [ "${USE_DDTRACE:-false}" = "true" ]; then
  exec ddtrace-run litellm "$@"
fi

exec litellm "$@"
