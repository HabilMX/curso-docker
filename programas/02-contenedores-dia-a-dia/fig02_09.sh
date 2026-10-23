#!/usr/bin/env bash
# fig02_09.sh — Ejercicios 2 y 3: las comprobaciones de sus soluciones, con salida guardada.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
IMAGEN="${PREFIJO}prueba:1.0.0"
EJ="${PREFIJO}ejercicio"
BIT="${PREFIJO}bitacora"
trap 'docker rm -f "$EJ" "$BIT" >/dev/null 2>&1 || true' EXIT
esperar() { for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && return; sleep 0.5; done; }

echo "== Ejercicio 2: 32 MiB, un cuarto de CPU, 20 procesos"
docker run -d --name "$EJ" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 32m --cpus 0.25 --pids-limit 20 "$IMAGEN" >/dev/null
esperar
curl -s "http://127.0.0.1:${PUERTO}/"
docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}}' "$EJ"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' "$EJ"
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/caido"
docker ps --filter name="$EJ" --format '{{.Names}} {{.Status}}'
sleep 12
docker ps --filter name="$EJ" --format '{{.Names}} {{.Status}}'
docker rm -f "$EJ" >/dev/null

echo
echo "== Ejercicio 3: la bitácora como evidencia"
docker run -d --name "$BIT" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
esperar
for i in 1 2 3; do curl -s "http://127.0.0.1:${PUERTO}/"; done
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/caido"
for i in 1 2; do curl -s "http://127.0.0.1:${PUERTO}/"; done
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/sano"
echo "-- 1. docker logs --tail 3"
docker logs --tail 3 "$BIT"
echo "-- 2. docker logs --timestamps"
docker logs --timestamps "$BIT"
echo "-- 3. docker logs --since 1m (renglones)"
docker logs --since 1m "$BIT" | wc -l
echo "-- 4. detenido: la bitácora sigue"
docker stop "$BIT" >/dev/null
docker logs --tail 3 "$BIT"
echo "-- 4. borrado: ya no"
docker rm "$BIT" >/dev/null
docker logs "$BIT"
echo "código de salida: $?"
