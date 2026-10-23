#!/usr/bin/env bash
# fig03_13.sh — Dónde alcanza un patrón de .dockerignore: «*.tar» contra «**/*.tar».
# Construye una imagen mínima con un .tar en la raíz y otro en una subcarpeta, y
# lista los .tar que llegaron adentro. Borra lo que crea.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}ctx:1.0.0-tar"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT
cd "$TRABAJO"
mkdir respaldos
touch raiz.tar respaldos/enero.tar
printf 'FROM golang:1.27.3-trixie\nCOPY . /ctx\n' > Dockerfile

muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

echo '*.tar' > .dockerignore
echo "## .dockerignore con: *.tar"
docker build -q -t "$IMAGEN" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mira $IMAGEN find /ctx -name '*.tar'"

echo
echo '**/*.tar' > .dockerignore
echo "## .dockerignore con: **/*.tar"
docker build -q -t "$IMAGEN" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mira $IMAGEN find /ctx -name '*.tar'"
