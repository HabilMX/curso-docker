#!/usr/bin/env bash
# fig07_04.sh — Corriendo no es sano. El servicio de prueba, con su propio
# HEALTHCHECK (cada 5 s, 2 reintentos), pasa a modo caído y a modo lento sin
# reiniciarse: el proceso sigue vivo y Docker lo marca unhealthy. Y una política
# de reinicio NO reinicia a un contenedor por estar unhealthy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-9000}"
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
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
resumen() {
  docker inspect --format '{{.State.Status}} / {{.State.Health.Status}} / racha={{.State.Health.FailingStreak}} / reinicios={{.RestartCount}}' "$NOMBRE"
}
ultima_revision() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{.Output}}{{end}}' "$NOMBRE" | sed '/^$/d' | tail -1
}

echo "== 1. Arranca sano, con --restart always"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:9000" --restart always "$IMAGEN" >/dev/null
esperar_salud healthy
estado

echo
echo "== 2. Modo caído: el proceso sigue vivo, pero responde 503"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/caido"
inicio=$(t); esperar_salud unhealthy; fin=$(t)
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
estado
resumen
ultima_revision

echo
echo "== 3. Diez segundos después, sigue unhealthy y nadie lo reinició"
sleep 10
resumen

echo
echo "== 4. De vuelta a sano, sin reiniciar nada"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/sano"
inicio=$(t); esperar_salud healthy; fin=$(t)
echo "volvió a healthy en $(( (fin - inicio + 500) / 1000 )) s"
resumen

echo
echo "== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/lento"
esperar_salud unhealthy
resumen
ultima_revision
echo "-- y sin embargo, contesta 200:"
curl -s -o /dev/null -w '%{http_code} en %{time_total}s\n' "http://127.0.0.1:$PUERTO/"
