#!/usr/bin/env bash
# fig02_03.sh — exec: ejecutar un programa dentro de un contenedor que ya corre.
# La imagen del servicio de prueba no trae shell: se ve el error y lo que sí funciona.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo "== 1. Pedir un shell"
docker exec "$NOMBRE" sh
echo "código de salida: $?"

echo
echo "== 2. Ejecutar un programa que la imagen SÍ trae"
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 3. Lo mismo, con el servicio en modo caído"
curl -s -X POST http://127.0.0.1:9000/modo/caido >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 4. exec en un contenedor detenido"
docker stop "$NOMBRE" >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"
