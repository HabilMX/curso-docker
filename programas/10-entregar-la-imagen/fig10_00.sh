#!/usr/bin/env bash
# fig10_00.sh — Los preparativos de la lección: qué almacén de imágenes usa tu Docker
# (sección 10.1.4) y la secuencia de descarga y verificación de kind y kubectl
# (sección 10.11.2). Se corre donde corre tu Docker (en tu Mint, el mismo comando).
#
# No instala nada en el sistema: descarga a una carpeta temporal propia, comprueba y
# borra la carpeta al salir. Sin `sudo`, sin tocar /usr/local/bin.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
trap 'rm -rf "$TRABAJO"' EXIT
cd "$TRABAJO"

muestra() {
  printf '$ %s\n' "$*"
  eval "$@" 2>&1
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

echo "== 1. El almacén de imágenes de este Docker"
muestra "docker info -f '{{ .DriverStatus }}'"

echo
echo "== 2. kind v0.33.0 (la línea de tu procesador)"
[ "$(uname -m)" = x86_64 ]  && curl -sSLo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
[ "$(uname -m)" = aarch64 ] && curl -sSLo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-arm64
chmod +x ./kind
muestra "./kind version"

echo
echo "== 3. kubectl v1.37.1, con la comprobación de su suma sha256"
ARQ=amd64; [ "$(uname -m)" = aarch64 ] && ARQ=arm64
curl -sSLO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl"
curl -sSLO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl.sha256"
muestra "echo \"\$(cat kubectl.sha256)  kubectl\" | sha256sum --check"
chmod +x ./kubectl
muestra "./kubectl version --client"
