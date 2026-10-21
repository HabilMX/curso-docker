#!/usr/bin/env bash
# fig00_06.sh — Imagen contra contenedor: una plantilla, dos copias vivas.
set -euo pipefail
IMAGEN=alpine:3.24.2
A=curso-docker-uno
B=curso-docker-dos
trap 'docker rm -f "$A" "$B" >/dev/null 2>&1 || true' EXIT

echo "== La imagen antes de empezar"
docker image inspect --format 'id={{.Id}}' "$IMAGEN" | cut -c1-22

docker run -d --name "$A" "$IMAGEN" sleep 300 >/dev/null
docker run -d --name "$B" "$IMAGEN" sleep 300 >/dev/null

echo
echo "== Escribo un archivo en el contenedor uno"
docker exec "$A" sh -c 'echo "hola desde uno" > /tmp/nota.txt && cat /tmp/nota.txt'

echo
echo "== ¿Lo ve el contenedor dos?"
docker exec "$B" cat /tmp/nota.txt || echo "(el contenedor dos no tiene ese archivo)"

echo
echo "== Lo que cambió en cada contenedor respecto de su imagen (docker diff)"
echo "-- uno:"; docker diff "$A"
echo "-- dos:"; docker diff "$B"; echo "(nada)"

echo
echo "== Borro el contenedor uno y miro la imagen otra vez"
docker rm -f "$A" >/dev/null
docker image inspect --format 'id={{.Id}}' "$IMAGEN" | cut -c1-22
docker run --rm --name curso-docker-tres "$IMAGEN" sh -c 'cat /tmp/nota.txt 2>&1 || true'
