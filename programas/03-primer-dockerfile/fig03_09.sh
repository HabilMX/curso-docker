#!/usr/bin/env bash
# fig03_09.sh — «En tu carpeta»: armar la carpeta del revisor y construir la imagen
# que se queda. Aquí se hace en una carpeta temporal y con la etiqueta 1.0.0-carpeta,
# para no tocar tu ~/curso-docker ni tu curso-docker-revisor:1.0.0. Borra lo que crea.
set -euo pipefail
# Nombres por omisión: los del curso. Se pueden cambiar para no chocar con otra
# corrida en el mismo equipo (PREFIJO=... ./fig03_09.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:1.0.0-carpeta"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# muestra: imprime el comando con «$ » y lo ejecuta (salida y error juntos)
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

# Los comandos del bloque de la lección, desde la raíz del repositorio del curso;
# la carpeta ~/curso-docker es aquí una carpeta temporal.
cd "$AQUI/../.."
mkdir -p "$TRABAJO/curso-docker/revisor"
cp -R programas/revisor/. "$TRABAJO/curso-docker/revisor/"
cp programas/03-primer-dockerfile/estado/Dockerfile \
   programas/03-primer-dockerfile/estado/.dockerignore "$TRABAJO/curso-docker/revisor/"
cd "$TRABAJO/curso-docker/revisor"

muestra "ls -A"
muestra "docker build -q -t $IMAGEN ."
muestra "docker image ls ${PREFIJO}revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
