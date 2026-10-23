#!/usr/bin/env bash
# fig10_05.sh — Escanear lo que se entrega con Trivy, SIN darle el socket de
# Docker: primero el error de pedirle la imagen por nombre, después la imagen
# guardada con docker save, con el umbral HIGH,CRITICAL y con todas las severidades.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig10»: la imagen curso-docker-revisor:fig10 y el volumen
# de la base de datos de Trivy curso-docker-trivy-cache-fig10. Nunca toca tu
# curso-docker-revisor:1.6.0 ni tu volumen curso-docker-trivy-cache.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
IMG="${PREFIJO}revisor:fig10"
CACHE="${PREFIJO}trivy-cache-fig10"
trap 'docker rmi "$IMG" >/dev/null 2>&1
      docker volume rm "$CACHE" >/dev/null 2>&1
      rm -rf "$TRABAJO"' EXIT

mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp "$AQUI/fig10_01.Dockerfile" "$TRABAJO/revisor/Dockerfile"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"

# Etiqueta propia al CONSTRUIR (no cambia el comando que se muestra). Una imagen con
# exactamente el mismo contenido que otra tiene el mismo identificador, y quien borra
# por identificador (docker rmi -f <id>) se lleva todos sus nombres. Con la etiqueta, el
# identificador de lo que construye este guion es solo suyo, y al salir se borra POR NOMBRE.
docker() {
  case "${1:-}" in
    build) command docker build --label curso-docker.figura=fig10_05 "${@:2}" ;;
    *) command docker "$@" ;;
  esac
}
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g"; }
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# Trivy imprime sus avisos con fecha y hora al principio del renglón; se quitan
# a la vista para que la salida se pueda comparar.
sin_fechas() { grep -vE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'; }
PLATAFORMA="linux/$(uname -m | sed 's/aarch64/arm64/; s/x86_64/amd64/')"

echo "== 1. La imagen, para la plataforma de este equipo ($PLATAFORMA)"
muestra "docker build -q --build-arg VERSION=1.6.0 -t $IMG . >/dev/null && docker image ls $IMG --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
docker volume create "$CACHE" >/dev/null

echo
echo "== 2. El error: pedirle a Trivy la imagen por su nombre, sin socket"
muestra "docker run --rm -v $CACHE:/root/.cache aquasec/trivy:0.76.0 image --quiet $IMG 2>&1 | grep -oE 'unable to find the specified image.*|^\s+\* [a-z]+ error: .*' | cut -c1-120"

echo
echo "== 3. Guardar la imagen en un archivo y escanear el archivo"
muestra "docker save --platform $PLATAFORMA -o revisor-1.6.0.tar $IMG && du -h revisor-1.6.0.tar | cut -f1"
muestra "docker run --rm -v $CACHE:/root/.cache -v \"\$PWD\":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --severity HIGH,CRITICAL --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#'"

echo
echo "== 4. El mismo archivo, con todas las severidades y el mismo --exit-code 1"
muestra "docker run --rm -v $CACHE:/root/.cache -v \"\$PWD\":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#' | grep -E 'Total|│' "

echo
echo "== 4b. Lo mismo, sin --exit-code: ¿con qué código sale Trivy por omisión?"
muestra "{ docker run --rm -v $CACHE:/root/.cache -v \"\$PWD\":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar 2>&1; echo \"código de Trivy: \$?\"; } | sin_fechas | grep -E '^Total|^código'"

echo
echo "== 5. ¿Y si se ignora lo que no tiene arreglo?"
muestra "docker run --rm -v $CACHE:/root/.cache -v \"\$PWD\":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignore-unfixed --exit-code 1 2>&1 | sin_fechas | grep -E '^Total'"

echo
echo "== 6. ¿De cuándo es la base de datos de vulnerabilidades?"
muestra "docker run --rm -v $CACHE:/root/.cache aquasec/trivy:0.76.0 version 2>&1 | sin_fechas"
