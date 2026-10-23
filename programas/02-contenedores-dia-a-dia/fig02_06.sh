#!/usr/bin/env bash
# fig02_06.sh — Los dos errores de todos los días: nombre repetido y puerto ocupado.
# Ojo con el segundo: el contenedor que falla SÍ queda creado.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "${PREFIJO}prueba" "${PREFIJO}otro" "viejo-${PREFIJO}x" >/dev/null 2>&1 || true' EXIT

docker run -d --name "${PREFIJO}prueba" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null

echo "== 1. Otro contenedor con el MISMO nombre"
docker run -d --name "${PREFIJO}prueba" "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Otro contenedor en el MISMO puerto"
docker run -d --name "${PREFIJO}otro" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" | cut -c1-12
echo "código de salida: ${PIPESTATUS[0]}"

echo
echo "== 3. ¿Qué quedó?"
docker ps -a --filter name="^${PREFIJO}" --format 'table {{.Names}}\t{{.Status}}'

echo
echo "== 4. El filtro name y el ancla ^ (cuántos contenedores encuentra cada uno)"
docker create --name "viejo-${PREFIJO}x" "$IMAGEN" >/dev/null     # un nombre que lleva el prefijo en medio
echo "name=prueba           : $(docker ps -aq --filter name=prueba | wc -l)"
echo "name='^prueba'        : $(docker ps -aq --filter name='^prueba' | wc -l)"
echo "name=${PREFIJO}      : $(docker ps -aq --filter name="${PREFIJO}" | wc -l)"
echo "name='^${PREFIJO}'   : $(docker ps -aq --filter name="^${PREFIJO}" | wc -l)"
