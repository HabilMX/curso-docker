#!/usr/bin/env bash
# fig05_09.sh — Etiqueta contra digest: qué hay detrás de las dos bases.
# Solo consulta el registro y la copia local; no construye ni crea nada.
set -euo pipefail

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

titulo "La base de compilación: la etiqueta y el digest que hoy le corresponde"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'"
muestra "docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie"

titulo "La base final: distroless no publica versiones, solo nombres"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'"
