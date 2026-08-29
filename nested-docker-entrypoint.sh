#!/bin/bash
set -Eeuo pipefail

log_file=${DOCKERD_LOG_FILE:-/var/log/dockerd.log}
startup_timeout=${DOCKERD_START_TIMEOUT:-60}
daemon_pid=
child_pid=

cleanup() {
  trap - EXIT INT TERM HUP

  if [[ -n "$child_pid" ]] && kill -0 "$child_pid" 2>/dev/null; then
    kill -TERM "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi

  if [[ -n "$daemon_pid" ]] && kill -0 "$daemon_pid" 2>/dev/null; then
    kill -TERM "$daemon_pid" 2>/dev/null || true
    wait "$daemon_pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM HUP

install -d /run/docker "$(dirname "$log_file")"

if [[ -d /run/docker/containerd ]]; then
  find /run/docker/containerd -xdev -depth -delete
fi

for stale_path in /run/docker.sock /run/docker.pid; do
  if [[ -e "$stale_path" || -S "$stale_path" ]]; then
    unlink "$stale_path"
  fi
done

: > "$log_file"
dockerd \
  --host=unix:///run/docker.sock \
  --storage-driver=vfs \
  > "$log_file" 2>&1 &
daemon_pid=$!

for ((attempt = 0; attempt < startup_timeout; attempt++)); do
  if docker info >/dev/null 2>&1; then
    break
  fi

  if ! kill -0 "$daemon_pid" 2>/dev/null; then
    cat "$log_file" >&2
    wait "$daemon_pid"
  fi

  sleep 1
done

if ! docker info >/dev/null 2>&1; then
  cat "$log_file" >&2
  exit 1
fi

"$@" &
child_pid=$!
wait "$child_pid"
status=$?
child_pid=
exit "$status"
