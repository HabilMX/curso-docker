#!/usr/bin/env bash
# fig02_01.sh — Correr una imagen que todavía no existe, y después construirla.
# Primero el error (la imagen no está en tu equipo ni en Docker Hub); luego el
# único comando que necesitas para construir el servicio de prueba.
set -uo pipefail
cd "$(dirname "$0")/.."          # la carpeta programas/, donde está servicio-prueba/
# Nombres por omisión: los del curso. Se pueden cambiar para no chocar con otra
# corrida en el mismo equipo (PREFIJO=... ./fig02_01.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
# SIN_CACHE=1 ./fig02_01.sh construye sin reusar capas, como la primera vez en un equipo nuevo.
NOMBRE="${PREFIJO}prueba"
IMAGEN="${PREFIJO}prueba:1.0.0"
# Si la imagen ya existía, el bloque 1 no falla y SÍ crea un contenedor: se borra al salir.
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== 1. Correr la imagen antes de construirla"
docker run -d --name "$NOMBRE" "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Construirla: un solo comando"
docker build ${SIN_CACHE:+--no-cache} -t "$IMAGEN" servicio-prueba
echo "código de salida: $?"

echo
echo "== 3. La imagen ya está en tu equipo"
docker image ls "$IMAGEN"

echo
echo "== 4. Y el intento fallido no dejó contenedores"
docker ps -a --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}' | wc -l

echo
echo "== 5. El tamaño, con un formato propio"
docker image ls "$IMAGEN" --format '{{.Repository}}:{{.Tag}} {{.Size}}'
