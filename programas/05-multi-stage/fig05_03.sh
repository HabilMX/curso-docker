#!/usr/bin/env bash
# fig05_03.sh — Construir el revisor en cuatro etapas y medir lo que se entrega.
# Construye la imagen de la Lección 4 (para comparar) y la de esta lección,
# muestra qué etapas corrieron, compara tamaños, lee las capas y lista los
# archivos de la imagen final. Borra lo que crea al salir.
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
cp "$AQUI/inicio/Dockerfile" "$TRABAJO/revisor/Dockerfile.leccion4"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.leccion4 && rm -f ./*.bak

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
VIEJA="${PREFIJO}revisor:1.1.0"
NUEVA="${PREFIJO}revisor:1.2.0"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$VIEJA" "$NUEVA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

docker build -q -t "$VIEJA" -f Dockerfile.leccion4 . >/dev/null

titulo "Construir: qué pasos de qué etapa corrieron"
muestra "docker build --progress=plain -t $NUEVA . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[\$0]++'"

titulo "Antes y después"
muestra "docker image ls --filter reference='${PREFIJO}revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Las capas de la imagen nueva"
muestra "docker history $NUEVA --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90"

titulo "De dónde salen los 16.1 MB"
muestra "docker history $NUEVA --format '{{.Size}}' --human=false | awk '{s+=\$1} END {print \"suma de las capas desempacadas:\", s, \"bytes\"}'"
muestra "docker image inspect $NUEVA --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'"

titulo "Todos los archivos de la imagen nueva"
docker create --name "${PREFIJO}mirar" "$NUEVA" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -v '/\$' | wc -l"
muestra "docker export ${PREFIJO}mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo"
muestra "docker export ${PREFIJO}mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |\$)|/?(revisor|passwd)\$' || echo '(nada más)'"
muestra "docker export ${PREFIJO}mirar | tar -xO etc/passwd"
