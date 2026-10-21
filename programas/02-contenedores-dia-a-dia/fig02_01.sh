#!/usr/bin/env bash
# fig02_01.sh — Correr una imagen que todavía no existe, y después construirla.
# Primero el error (la imagen no está en tu equipo ni en Docker Hub); luego el
# único comando que necesitas para construir el servicio de prueba.
set -uo pipefail
cd "$(dirname "$0")/.."          # la carpeta programas/, donde está servicio-prueba/
IMAGEN=curso-docker-prueba:1.0.0
# Si la imagen ya existía, el bloque 1 no falla y SÍ crea un contenedor: se borra al salir.
trap 'docker rm -f curso-docker-prueba >/dev/null 2>&1 || true' EXIT

echo "== 1. Correr la imagen antes de construirla"
docker run -d --name curso-docker-prueba "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Construirla: un solo comando"
docker build -t "$IMAGEN" servicio-prueba
echo "código de salida: $?"

echo
echo "== 3. La imagen ya está en tu equipo"
docker image ls "$IMAGEN"

echo
echo "== 4. Y el intento fallido no dejó contenedores"
docker ps -a --filter name=curso-docker-prueba --format '{{.Names}} {{.Status}}' | wc -l
