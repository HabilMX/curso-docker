#!/usr/bin/env bash
# fig02_05.sh — Publicar en 127.0.0.1 contra publicar en todas las interfaces.
# Se corre en el anfitrión (tu Mint): ss lista los puertos en los que escucha el equipo.
set -euo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-abierto >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name curso-docker-abierto -p 9001:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for p in 9000 9001; do
  for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:$p/" && break; sleep 0.5; done
done

echo "== 1. Lo que dice docker port"
echo "-- curso-docker-prueba:"; docker port curso-docker-prueba
echo "-- curso-docker-abierto:"; docker port curso-docker-abierto

echo
echo "== 2. Lo que dice el sistema operativo: dónde escucha el equipo"
ss -ltn | grep -E ':900[01] ' | awk '{print $4}' | sort
