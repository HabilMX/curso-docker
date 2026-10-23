#!/usr/bin/env bash
# fig10_08.sh — Las soluciones medidas de los Ejercicios 1 y 4:
#  1. dos etiquetas para el MISMO digest (docker buildx imagetools create);
#  4. renovar el digest de la base y volver a escanear: ¿desaparece el hallazgo?
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
P_REG="${P_REG:-5000}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
REGISTRO="${PREFIJO}registro-fig10"
REPO="localhost:${P_REG}/${PREFIJO}revisor"
IMG="${PREFIJO}revisor:fig10"
CACHE="${PREFIJO}trivy-cache-fig10"
trap 'docker rm -f -v "$REGISTRO" >/dev/null 2>&1
      docker images --digests --format "{{.Repository}}@{{.Digest}}" | grep "^$REPO@" | xargs -r docker rmi >/dev/null 2>&1
      docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$REPO:" | xargs -r docker rmi >/dev/null 2>&1
      docker rmi "$IMG" >/dev/null 2>&1
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
    build) command docker build --label curso-docker.figura=fig10_08 "${@:2}" ;;
    *) command docker "$@" ;;
  esac
}
ocupado() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
ocupado "$P_REG" && { echo "El puerto $P_REG ya está en uso (¿tu registro?). Corre con otro: P_REG=…" >&2; exit 1; }
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g" -e "s/localhost:${P_REG}\//localhost:5000\//g" \
                -e "s/127.0.0.1:${P_REG}/127.0.0.1:5000/g"; }
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
esperar_http() { for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done; echo "(no respondió $1)"; }
sin_fechas() { grep -vE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'; }
PLATAFORMA="linux/$(uname -m | sed 's/aarch64/arm64/; s/x86_64/amd64/')"

echo "== Ejercicio 1. Dos etiquetas, un digest"
docker run -d --name "$REGISTRO" -p "127.0.0.1:${P_REG}:5000" registry:3.1.2 >/dev/null
esperar_http "http://127.0.0.1:${P_REG}/v2/"
docker buildx build -q --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 -t "$REPO:1.6.0" --push . >/dev/null 2>&1
muestra "docker buildx imagetools create -t $REPO:1.6 $REPO:1.6.0 >/dev/null 2>&1 && echo 'etiqueta 1.6 creada'"
muestra "curl -s http://127.0.0.1:${P_REG}/v2/${PREFIJO}revisor/tags/list"
muestra "for t in 1.6.0 1.6; do docker buildx imagetools inspect $REPO:\$t --format '{{json .Manifest.Digest}}'; echo; done"

echo
echo "== Ejercicio 4. Renovar el digest de la base y volver a escanear"
NUEVO="$(docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot --format '{{json .Manifest.Digest}}' | tr -d '"')"
cp Dockerfile Dockerfile.viejo
sed -i -E "s#(static-debian13:nonroot@)sha256:[0-9a-f]{64}#\1$NUEVO#" Dockerfile
muestra "diff Dockerfile.viejo Dockerfile | cut -c1-120 | sed -E 's/sha256:([0-9a-f]{12})[0-9a-f]+/sha256:\1…/'; true"
muestra "docker build -q --build-arg VERSION=1.6.0 -t $IMG . >/dev/null && docker run --rm $IMG version"
muestra "docker save --platform $PLATAFORMA -o revisor-1.6.0.tar $IMG && du -h revisor-1.6.0.tar | cut -f1"
docker volume create "$CACHE" >/dev/null
muestra "{ docker run --rm -v $CACHE:/root/.cache -v \"\$PWD\":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo \"código de Trivy: \$?\"; } | sin_fechas | grep -E '^Total|^código|tar \\(' | sed 's#/trabajo/#./#'"
