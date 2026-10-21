#!/usr/bin/env bash
# fig00_09.sh — Cuánto tarda en nacer, trabajar y morir un contenedor.
# Cinco veces seguidas, con una imagen que ya está descargada.
set -euo pipefail
IMAGEN=alpine:3.24.2
for i in 1 2 3 4 5; do
  inicio=$(date +%s%N)
  docker run --rm --name curso-docker-rapido "$IMAGEN" true
  fin=$(date +%s%N)
  echo "corrida $i: $(( (fin - inicio) / 1000000 )) ms"
done
