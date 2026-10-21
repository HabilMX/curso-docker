#!/usr/bin/env bash
# fig00_01.sh — Un contenedor es un proceso del equipo anfitrión.
# Arranca un contenedor que solo duerme, lo mira desde dentro y desde fuera,
# y lo borra al final.
set -euo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-dormilon
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" "$IMAGEN" sleep 300 >/dev/null

echo "== 1. Desde DENTRO del contenedor: todos sus procesos"
docker exec "$NOMBRE" ps -o pid,user,args

echo
echo "== 2. Desde FUERA: el mismo proceso, visto por Docker"
PID_ANFITRION=$(docker inspect --format '{{.State.Pid}}' "$NOMBRE")
echo "PID en el anfitrión: $PID_ANFITRION"

echo
echo "== 3. Desde FUERA: el mismo proceso, visto por el sistema operativo"
ps -o pid,ppid,user,args -p "$PID_ANFITRION"

echo
echo "== 4. Quién es su padre en el anfitrión"
PPID_ANFITRION=$(ps -o ppid= -p "$PID_ANFITRION" | tr -d ' ')
ps -o pid,user,comm -p "$PPID_ANFITRION"
