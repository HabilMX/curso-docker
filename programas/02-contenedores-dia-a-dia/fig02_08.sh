#!/usr/bin/env bash
# fig02_08.sh — Ejercicio 1: la secuencia de cuatro comandos y qué queda en docker ps -a.
# Muestra el contenedor fantasma del puerto ocupado y qué pasa si lo rescatas con start.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "${PREFIJO}a" "${PREFIJO}b" "${PREFIJO}c" >/dev/null 2>&1 || true' EXIT
LIMITES="--memory 64m --cpus 0.5 --pids-limit 50"

echo "== 1. docker run -d --name a -p 127.0.0.1:PUERTO:9000"
docker run -d --name "${PREFIJO}a" -p "127.0.0.1:${PUERTO}:9000" $LIMITES "$IMAGEN" >/dev/null
echo "código de salida: $?"
for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && break; sleep 0.5; done

echo
echo "== 2. docker run -d --name b -p 127.0.0.1:PUERTO:9000 (el mismo puerto)"
docker run -d --name "${PREFIJO}b" -p "127.0.0.1:${PUERTO}:9000" $LIMITES "$IMAGEN" | cut -c1-12
echo "código de salida: ${PIPESTATUS[0]}"

echo
echo "== 3. docker stop a"
docker stop "${PREFIJO}a" >/dev/null
echo "código de salida: $?"

echo
echo "== 4. docker run --rm --name c … healthcheck"
docker run --rm --name "${PREFIJO}c" $LIMITES "$IMAGEN" healthcheck
echo "código de salida: $?"

echo
echo "== 5. ¿Qué quedó?"
docker ps -a --filter name="^${PREFIJO}" --format 'table {{.Names}}\t{{.Status}}'

echo
echo "== 6. Con el puerto ya libre, docker start b"
docker start "${PREFIJO}b"
echo "código de salida: $?"
sleep 1
docker ps --filter name="${PREFIJO}b" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo "docker port: [$(docker port "${PREFIJO}b")]"
curl -s -o /dev/null --max-time 3 -w 'curl al puerto: código HTTP %{http_code}\n' "http://127.0.0.1:${PUERTO}/"
echo "pedido:   $(docker inspect --format '{{json .HostConfig.PortBindings}}' "${PREFIJO}b")"
echo "conectado: $(docker inspect --format '{{json .NetworkSettings.Ports}}' "${PREFIJO}b")"

echo
echo "== 7. Dejar el equipo limpio"
docker ps -aq --filter name="^${PREFIJO}" | xargs -r docker rm -f >/dev/null
docker ps -a --filter name="^${PREFIJO}" --format '{{.Names}}' | wc -l
