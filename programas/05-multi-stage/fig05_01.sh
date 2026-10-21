#!/usr/bin/env bash
# fig05_01.sh — Qué hay dentro de la imagen con la que termina la Lección 4.
# La construye desde inicio/ (el Dockerfile y el .dockerignore de la Lección 4),
# mide su tamaño y busca adentro lo que el revisor necesita para correr y lo que
# no. Borra lo que crea al salir.
set -euo pipefail
# PREFIJO cambia el principio de todos los nombres (imágenes, contenedores y la
# caché de compilación). Con el valor por omisión, el guion usa los nombres del
# curso; otro valor sirve para que dos corridas en la misma máquina no choquen.
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/inicio/Dockerfile" "$AQUI/inicio/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

titulo() { printf '\n## %s\n' "$*"; }
# muestra: imprime el comando con «$ » y lo ejecuta (salida y error juntos)
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
IMAGEN="${PREFIJO}revisor:1.1.0"
MIRAR="docker run --rm --name ${PREFIJO}mirar $IMAGEN"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "La imagen de la Lección 4"
muestra "docker build -q -t $IMAGEN . >/dev/null && docker image ls $IMAGEN --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Lo único que el revisor necesita para correr"
muestra "$MIRAR ls -lh /usr/local/bin/revisor"

titulo "Lo demás que viaja con él"
muestra "$MIRAR sh -c 'for p in sh bash apt-get gcc go git curl; do printf \"%-8s %s\n\" \$p \"\$(command -v \$p || echo no-esta)\"; done'"
muestra "$MIRAR du -sh /usr/local/go /usr/lib /usr/bin /usr/share"
muestra "$MIRAR sh -c 'dpkg-query -W | wc -l'"
muestra "$MIRAR id"
