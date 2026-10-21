#!/usr/bin/env bash
# fig04_06.sh — Revisar el Dockerfile de la lección antes de construir, como en
# la Lección 3. No construye nada ni crea contenedores.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
docker build --check . 2>&1 | tail -1
