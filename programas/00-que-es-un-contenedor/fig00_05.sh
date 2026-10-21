#!/usr/bin/env bash
# fig00_05.sh — El error de esta lección: el núcleo mata al proceso que pasa su límite.
# El contenedor intenta llenar la memoria; tiene un tope de 32 MiB y sin swap.
set -uo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-gloton
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run --name "$NOMBRE" --memory 32m --memory-swap 32m \
  "$IMAGEN" sh -c 'echo "voy a comer memoria..."; tail /dev/zero'
echo "código de salida: $?"

echo
echo "== Lo que Docker anotó"
docker inspect --format 'OOMKilled={{.State.OOMKilled}}  ExitCode={{.State.ExitCode}}' "$NOMBRE"
