#!/usr/bin/env bash
# fig00_04.sh — Los grupos de control (cgroups): lo que el núcleo deja gastar.
# Primero sin límites, después con límites de memoria, CPU y procesos.
set -euo pipefail
IMAGEN=alpine:3.24.2
LEER='for f in memory.max cpu.max pids.max; do printf "%-11s %s\n" "$f" "$(cat /sys/fs/cgroup/$f)"; done'

echo "== Sin límites (lo que Docker hace si no le pides nada)"
docker run --rm --name curso-docker-sin-limites "$IMAGEN" sh -c "$LEER"

echo
echo "== Con --memory 64m --cpus 0.5 --pids-limit 50"
docker run --rm --name curso-docker-con-limites \
  --memory 64m --cpus 0.5 --pids-limit 50 \
  "$IMAGEN" sh -c "$LEER"
