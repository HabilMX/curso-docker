#!/usr/bin/env bash
# fig05_06.sh — Correr la imagen mínima: su versión, su salud, su reporte, que
# no tiene shell, que no es root y cuánto tarda en detenerse. Borra lo que crea.
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
# PUERTO: el puerto del equipo donde se publica el revisor, siempre en 127.0.0.1.
PUERTO="${PUERTO:-8080}"

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
IMAGEN="${PREFIJO}revisor:1.2.0"
NOMBRE="${PREFIJO}revisor"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1; docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT
docker build -q -t "$IMAGEN" . >/dev/null

titulo "Un subcomando, sin servidor"
muestra "docker run --rm --name ${PREFIJO}version $IMAGEN version"

titulo "Como servicio"
muestra "docker run -d --name $NOMBRE -p 127.0.0.1:$PUERTO:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' $IMAGEN >/dev/null"
esperar_http "http://127.0.0.1:$PUERTO/salud"
muestra "curl -s http://127.0.0.1:$PUERTO/salud; echo"
muestra "curl -s 'http://127.0.0.1:$PUERTO/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'"

titulo "Sin shell y sin root"
muestra "docker exec $NOMBRE sh"
muestra "docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' $NOMBRE"
muestra "docker top $NOMBRE -o pid,user,args"

titulo "Detenerlo"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' $NOMBRE"
muestra "docker logs $NOMBRE"
