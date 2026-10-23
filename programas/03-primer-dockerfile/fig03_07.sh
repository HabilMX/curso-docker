#!/usr/bin/env bash
# fig03_07.sh — La MISMA imagen con CMD en forma shell: quién es el PID 1,
# cuánto tarda docker stop y con qué código muere. Borra lo que crea al salir.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
LIMITES="--memory 64m --cpus 0.5 --pids-limit 50"   # los tres límites de la Lección 2
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
cd "$TRABAJO/revisor"

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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'docker rm -f ${PREFIJO}revisor-shell >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0-shell >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "docker stop con forma shell"
docker build -q -t ${PREFIJO}revisor:1.0.0-shell -f Dockerfile.forma-shell . >/dev/null
docker run -d --name ${PREFIJO}revisor-shell ${LIMITES} -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0-shell >/dev/null
sleep 1
muestra "docker top ${PREFIJO}revisor-shell -o pid,user,args"
inicio=$(t); docker stop ${PREFIJO}revisor-shell >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${PREFIJO}revisor-shell"
muestra "docker logs ${PREFIJO}revisor-shell"
