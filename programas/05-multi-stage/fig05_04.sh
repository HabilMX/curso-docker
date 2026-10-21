#!/usr/bin/env bash
# fig05_04.sh — La etapa de pruebas, sola: construye solo hasta «pruebas»,
# obligándola a correr de nuevo, y mide la imagen intermedia que queda.
# Borra lo que crea al salir.
set -euo pipefail
# PREFIJO cambia el principio de todos los nombres (imágenes, contenedores y la
# caché de compilación). Con el valor por omisión, el guion usa los nombres del
# curso; otro valor sirve para que dos corridas en la misma máquina no choquen.
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
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
PRUEBAS="${PREFIJO}revisor:pruebas"
trap 'docker rmi -f "$PRUEBAS" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Solo hasta la etapa de pruebas"
muestra "docker build --target pruebas --no-cache-filter pruebas --progress=plain -t $PRUEBAS . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[\$0]++'"

titulo "La imagen intermedia: sirve para probar, no para entregar"
muestra "docker image ls $PRUEBAS --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
