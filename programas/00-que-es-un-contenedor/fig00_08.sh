#!/usr/bin/env bash
# fig00_08.sh — Lo que el contenedor comparte con el anfitrión: el usuario y el núcleo.
set -euo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-quien
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== Dentro del contenedor, ¿quién soy?"
docker run --rm --name curso-docker-id "$IMAGEN" id

echo
echo "== Y desde el anfitrión, ¿de quién es ese proceso?"
docker run -d --name "$NOMBRE" "$IMAGEN" sleep 300 >/dev/null
PID=$(docker inspect --format '{{.State.Pid}}' "$NOMBRE")
ps -o uid,user,args -p "$PID"

echo
echo "== Las capacidades efectivas de ese root (máscara en hexadecimal)"
echo "$(docker run --rm --name curso-docker-cap1 "$IMAGEN" grep CapEff /proc/self/status | cut -f2)  contenedor, por omisión"
echo "$(docker run --rm --name curso-docker-cap2 --cap-drop ALL "$IMAGEN" grep CapEff /proc/self/status | cut -f2)  contenedor, con --cap-drop ALL"
echo "$(grep CapEff /proc/1/status | cut -f2)  proceso 1 del anfitrión (root)"
