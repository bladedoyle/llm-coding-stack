#!/bin/sh
set -eu

. /etc/os-release

case "$ID" in
  debian|ubuntu) ;;
  *)
    echo "Unsupported distribution for Docker Engine: $ID" >&2
    exit 1
    ;;
esac

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get remove -y \
  docker.io \
  docker-compose \
  docker-compose-v2 \
  docker-doc \
  docker-buildx \
  podman-docker \
  containerd \
  runc || true
apt-get install -y --no-install-recommends ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

architecture=$(dpkg --print-architecture)
printf '%s\n' \
  'Types: deb' \
  "URIs: https://download.docker.com/linux/$ID" \
  "Suites: $VERSION_CODENAME" \
  'Components: stable' \
  "Architectures: $architecture" \
  'Signed-By: /etc/apt/keyrings/docker.asc' \
  > /etc/apt/sources.list.d/docker.sources

apt-get update
apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
rm -rf /var/lib/apt/lists/*
