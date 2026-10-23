#!/usr/bin/env bash
# fig02_04.sh — inspect y stats: lo que Docker sabe de un contenedor, con y sin límites.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
CON="${PREFIJO}prueba"
SIN="${PREFIJO}sin-limites"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "$CON" "$SIN" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CON" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
docker run -d --name "$SIN" "$IMAGEN" >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && break; sleep 0.5; done

FORMATO='{{.Name}}: memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}'

echo "== 1. inspect, con una plantilla: solo los campos que me importan"
docker inspect --format "$FORMATO" "$CON" "$SIN"

echo
echo "== 2. inspect: estado, puerto publicado y comando principal"
docker inspect --format 'estado={{.State.Status}} pid1={{.Config.Entrypoint}} puertos={{json .HostConfig.PortBindings}}' "$CON"

echo
echo "== 3. stats: lo que gastan ahora mismo, contra su límite"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.PIDs}}' "$CON" "$SIN"

echo
echo "== 4. Cuántos renglones trae inspect completo"
docker inspect "$CON" | wc -l
