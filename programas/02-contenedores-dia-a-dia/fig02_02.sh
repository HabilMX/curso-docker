#!/usr/bin/env bash
# fig02_02.sh — El servicio de prueba corriendo: arrancar, listar, consultar y leer su bitácora.
# Puerto publicado solo en 127.0.0.1 y con límites de memoria, CPU y procesos.
set -euo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== 1. Arrancar en segundo plano"
docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
# Esperar a que conteste (máximo 10 s), en vez de dormir un número fijo.
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo
echo "== 2. Lo que está corriendo"
docker ps --filter name="$NOMBRE" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== 3. Consultarlo en sus tres modos"
curl -s http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/caido
curl -s -w 'código HTTP: %{http_code}\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/lento
curl -s -w 'código HTTP: %{http_code} en %{time_total} s\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/sano
curl -s http://127.0.0.1:9000/modo

echo
echo "== 4. Su bitácora completa"
docker logs "$NOMBRE"

echo
echo "== 5. Solo los dos últimos renglones"
docker logs --tail 2 "$NOMBRE"
