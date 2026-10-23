#!/usr/bin/env bash
# fig02_10.sh — docker update: cambiar los límites de un contenedor sin recrearlo.
# El puerto publicado y la imagen, en cambio, sí exigen un contenedor nuevo.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
IMAGEN="${PREFIJO}prueba:1.0.0"
NOMBRE="${PREFIJO}prueba"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT
FORMATO='memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} puertos={{json .HostConfig.PortBindings}}'

docker run -d --name "$NOMBRE" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null

echo "== 1. Antes"
docker inspect --format "$FORMATO" "$NOMBRE"

echo
echo "== 2. docker update de los tres límites, con el contenedor corriendo"
docker update --memory 128m --memory-swap 128m --cpus 1 --pids-limit 100 "$NOMBRE"
echo "código de salida: $?"

echo
echo "== 3. Después (mismo contenedor, sin reiniciar)"
docker inspect --format "$FORMATO" "$NOMBRE"
docker inspect --format 'sigue corriendo: {{.State.Running}}, reinicios: {{.RestartCount}}' "$NOMBRE"

echo
echo "== 4. El puerto publicado no tiene opción en update"
docker update -p 127.0.0.1:9002:9000 "$NOMBRE" 2>&1 | head -2
