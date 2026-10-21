#!/usr/bin/env bash
# fig03_04.sh — Lo que viaja en el contexto acaba dentro de la imagen.
# Construye el revisor con un archivo .env de mentira en la carpeta: primero SIN
# .dockerignore y después CON el de fig03_03. Mira qué quedó en /src cada vez.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
SIN="${PREFIJO}revisor:1.0.0-sin-ignore"
CON="${PREFIJO}revisor:1.0.0-con-ignore"
trap 'docker rmi -f "$SIN" "$CON" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + el Dockerfile de la lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/fig03_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
# Un secreto DE MENTIRA, como el que cualquiera deja en la carpeta del proyecto.
echo 'REVISOR_TOKEN=curso-docker-env-de-mentira-3c1d' > .env

echo "== 1. SIN .dockerignore: lo que hay en /src dentro de la imagen"
docker build -q -t "$SIN" . >/dev/null
docker run --rm --name "${PREFIJO}mira" "$SIN" ls -A /src
echo "-- y el .env, leído desde la imagen:"
docker run --rm --name "${PREFIJO}mira" "$SIN" cat /src/.env

echo
echo "== 2. CON .dockerignore: lo que hay en /src dentro de la imagen"
cp "$AQUI/fig03_03.dockerignore" .dockerignore
docker build -q -t "$CON" . >/dev/null
docker run --rm --name "${PREFIJO}mira" "$CON" ls -A /src
