#!/usr/bin/env bash
# fig07_09.sh — La solución del Ejercicio 3: el revisor con otra señal de apagado.
# SIGINT, que el revisor atiende, y SIGHUP, que no pidió, sin y con --init.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

t() { date +%s%3N; }
SERVICIOS='propio http://127.0.0.1:8080/salud'

for prueba in "SIGINT" "SIGHUP" "SIGHUP --init"; do
  set -- $prueba
  echo "== --stop-signal $1 ${2:-sin --init}"
  docker run -d --name "$NOMBRE" --stop-signal "$1" ${2:-} -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
  sleep 1
  inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop tardó $(( fin - inicio )) ms"
  docker inspect --format 'ExitCode={{.State.ExitCode}} StopSignal={{.Config.StopSignal}}' "$NOMBRE"
  docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
  docker rm -f "$NOMBRE" >/dev/null
  echo
done
