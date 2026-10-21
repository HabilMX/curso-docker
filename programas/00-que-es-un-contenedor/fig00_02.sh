#!/usr/bin/env bash
# fig00_02.sh — Dos imágenes de dos distribuciones distintas, un solo núcleo.
set -euo pipefail
ALPINE=alpine:3.24.2
DEBIAN=debian:13.7-slim

distro() { grep '^PRETTY_NAME=' "$1" | cut -d= -f2 | tr -d '"'; }

echo "== El anfitrión"
echo "distribución: $(distro /etc/os-release)"
echo "núcleo:       $(uname -r)"

for IMAGEN in "$ALPINE" "$DEBIAN"; do
  echo
  echo "== Un contenedor de $IMAGEN"
  docker run --rm --name curso-docker-distro "$IMAGEN" sh -c '
    echo "distribución: $(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d "\"")"
    echo "núcleo:       $(uname -r)"'
done
