#!/usr/bin/env bash
# fig03_12.sh — Los dos Dockerfile con defectos de la lección: el del Ejercicio 4,
# revisado con docker build --check, y el de la Solución 1 (USER antes del RUN),
# que falla al compilar. No deja imágenes ni contenedores.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los dos Dockerfile con defectos.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_10.Dockerfile" "$TRABAJO/revisor/Dockerfile.ajeno"
cp "$AQUI/fig03_11.Dockerfile" "$TRABAJO/revisor/Dockerfile.user-antes"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

titulo "Ejercicio 4: el Dockerfile ajeno, revisado antes de construir"
muestra "docker build --check -f Dockerfile.ajeno ."

titulo "Solución 1: USER antes del RUN, la compilación falla"
muestra "docker build --progress=plain -f Dockerfile.user-antes ."
