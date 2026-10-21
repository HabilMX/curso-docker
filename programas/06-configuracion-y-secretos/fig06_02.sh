#!/usr/bin/env bash
# fig06_02.sh — Construir el revisor con su versión como ARG y mirar dónde quedó.
# Construye curso-docker-revisor:1.3.0 con fig06_01.Dockerfile y pregunta a la
# imagen qué trae: la versión, las etiquetas, el entorno y el historial.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

echo "== 1. Construir, pasando la versión como argumento de construcción"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
docker image ls "$IMAGEN" --format 'tamaño: {{.Size}}'

echo
echo "== 2. La versión, grabada dentro del binario"
docker run --rm --name "${PREFIJO}revisor-fig06-version" "$IMAGEN" version

echo
echo "== 3. Las etiquetas OCI de la imagen"
docker image inspect --format '{{range $k, $v := .Config.Labels}}{{$k}} = {{$v}}{{println}}{{end}}' "$IMAGEN"

echo "== 4. El entorno que la imagen entrega a cada contenedor (ENV)"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGEN"

echo "== 5. El historial de la imagen final, de arriba (lo último) hacia abajo"
docker history --format '{{.Size}}	{{.CreatedBy}}' "$IMAGEN" | head -8
