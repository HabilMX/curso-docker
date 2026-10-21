#!/usr/bin/env bash
# fig05_08.sh — El error de esta lección: el binario que no es estático.
# Construye la imagen de fig05_07.Dockerfile (sin CGO_ENABLED=0), la corre, y
# después mira los dos binarios del revisor por dentro, el de esa imagen y el
# de la lección. Borra lo que crea al salir.
set -uo pipefail
# PREFIJO cambia el principio de todos los nombres (imágenes, contenedores y la
# caché de compilación). Con el valor por omisión, el guion usa los nombres del
# curso; otro valor sirve para que dos corridas en la misma máquina no choquen.
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig05_07.Dockerfile" "$TRABAJO/revisor/Dockerfile.dinamico"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.dinamico && rm -f ./*.bak

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
DINAMICO="${PREFIJO}revisor:dinamico"
B_DIN="${PREFIJO}revisor:binario-dinamico"
B_EST="${PREFIJO}revisor:binario-estatico"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$DINAMICO" "$B_DIN" "$B_EST" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construye sin error... y no arranca"
muestra "docker build -q -t $DINAMICO -f Dockerfile.dinamico . >/dev/null; echo \"construcción: código \$?\""
muestra "docker run --rm --name ${PREFIJO}dinamico $DINAMICO version"

titulo "Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)"
docker build -q --target binario -t "$B_DIN" -f Dockerfile.dinamico . >/dev/null
docker build -q --target binario -t "$B_EST" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mirar $B_DIN sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'"
muestra "docker run --rm --name ${PREFIJO}mirar $B_EST sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo \"(sin intérprete)\"'"

titulo "¿Está ese intérprete en la imagen final?"
docker create --name "${PREFIJO}mirar" "$DINAMICO" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -E 'ld-linux|libc\\.so' || echo '(no está)'"
