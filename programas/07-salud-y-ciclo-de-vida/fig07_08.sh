#!/usr/bin/env bash
# fig07_08.sh — Las soluciones de los Ejercicios 2 y 4, con el servicio de prueba:
# cuánto tarda en enfermarse con otros tiempos de salud, y cómo corre con las
# opciones endurecidas de la lección.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}

for arranque in 0s 1ms; do
  echo "== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period $arranque"
  inicio=$(t)
  docker run -d --name "$NOMBRE" -e PRUEBA_MODO=caido \
    --health-interval 2s --health-retries 5 --health-start-period "$arranque" "$IMAGEN" >/dev/null
  esperar_salud unhealthy; fin=$(t)
  echo "pasó a unhealthy a los $(( (fin - inicio) / 100 ))00 ms de arrancar"
  docker inspect --format 'racha={{.State.Health.FailingStreak}} StartPeriod={{.Config.Healthcheck.StartPeriod}}' "$NOMBRE"
  docker rm -f "$NOMBRE" >/dev/null
  echo
done

echo "== Ejercicio 4: el servicio de prueba con las opciones endurecidas"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
docker top "$NOMBRE" -o pid,user,args | sed -E 's/^ *[0-9]+ /<pid> /'
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1
