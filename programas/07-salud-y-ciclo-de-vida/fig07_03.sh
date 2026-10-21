#!/usr/bin/env bash
# fig07_03.sh — HEALTHCHECK sin curl. Construye el revisor con fig07_01.Dockerfile,
# provoca primero el error de vigilarlo con curl (la imagen no tiene ni shell ni
# curl), lo corre con su propia revisión de salud y lo detiene midiendo el tiempo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

t() { date +%s%3N; }
# esperar_salud ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
# estado: lo que dice docker ps, sin el nombre
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
# bitacora_salud: las revisiones guardadas, una por renglón: código y salida
bitacora_salud() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{printf "%q" .Output}}{{println}}{{end}}' "$NOMBRE" | sed '/^$/d'
}
SERVICIOS='propio http://127.0.0.1:8080/salud'

echo "== 1. Construir y leer la revisión de salud que trae la imagen"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null
docker image inspect --format '{{json .Config.Healthcheck}}' "$IMAGEN"
docker image inspect --format 'StopSignal={{.Config.StopSignal}}' "$IMAGEN"

echo
echo "== 2. El error: vigilarlo con curl, como en los tutoriales"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  --health-cmd 'curl -fs http://127.0.0.1:8080/salud || exit 1' \
  --health-interval 2s --health-retries 2 --health-start-period 1ms "$IMAGEN" >/dev/null
inicio=$(t); esperar_salud unhealthy; fin=$(t)
estado
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud | tail -1
echo "-- y sin embargo, el servicio contesta:"
docker exec "$NOMBRE" /revisor healthcheck
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Con la revisión de la imagen: el propio binario se pregunta"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
estado
inicio=$(t); esperar_salud healthy; fin=$(t)
estado
echo "pasó a healthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud
docker inspect --format 'Status={{.State.Status}} Health={{.State.Health.Status}} FailingStreak={{.State.Health.FailingStreak}}' "$NOMBRE"

echo
echo "== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
