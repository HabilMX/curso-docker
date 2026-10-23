#!/usr/bin/env bash
# fig04_07.sh — Solución 3: qué dice `go build` cuando el go.mod llega después
# del RUN. Compila un paquete main mínimo, SIN go.mod, dentro de la imagen de Go
# de la lección. No construye imágenes; el contenedor se borra solo (--rm).
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
docker run --rm --name "${PREFIJO}fig04-sin-gomod" golang:1.27.3-trixie sh -c '
  mkdir -p /src/cmd/revisor && cd /src
  printf "package main\n\nfunc main() {}\n" > cmd/revisor/main.go
  go build -o /tmp/revisor ./cmd/revisor; echo "código: $?"'
