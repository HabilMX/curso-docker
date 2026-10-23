#!/usr/bin/env bash
# fig02_05.sh — Publicar en 127.0.0.1 contra publicar en todas las interfaces.
# Se corre en el anfitrión (tu Mint): ss lista los puertos en los que escucha el equipo.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
ABIERTO=$((PUERTO + 1))        # el segundo puerto, el que se abre a propósito
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "${PREFIJO}prueba" "${PREFIJO}abierto" >/dev/null 2>&1 || true' EXIT

docker run -d --name "${PREFIJO}prueba" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
docker run -d --name "${PREFIJO}abierto" -p "${ABIERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
for p in "$PUERTO" "$ABIERTO"; do
  for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:$p/" && break; sleep 0.5; done
done

echo "== 1. Lo que dice docker port"
echo "-- ${PREFIJO}prueba:"; docker port "${PREFIJO}prueba"
echo "-- ${PREFIJO}abierto:"; docker port "${PREFIJO}abierto"

echo
echo "== 2. Lo que dice el sistema operativo: dónde escucha el equipo"
ss -ltn | grep -E ":(${PUERTO}|${ABIERTO}) " | awk '{print $4}' | sort
