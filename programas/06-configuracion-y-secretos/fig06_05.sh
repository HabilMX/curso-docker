#!/usr/bin/env bash
# fig06_05.sh — ASÍ NO: dos secretos (de mentira) que quedan dentro de la imagen.
# Construye fig06_04.Dockerfile y busca los secretos donde cualquiera que tenga
# la imagen los puede buscar: el historial y la configuración.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
MALO="${PREFIJO}revisor:fig06-malo"
CADENA="${PREFIJO}revisor:fig06-cadena"
trap 'docker rmi -f "$MALO" "$CADENA" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_04.Dockerfile" "$TRABAJO/Dockerfile.malo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Construir pasando el token de módulos (de mentira) por ARG"
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" \
  -f Dockerfile.malo -t "$MALO" . >/dev/null && echo "construida"

echo
echo "== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" --user 0 "$MALO" ls -A /root

echo
echo "== 3. Pero el historial guardó el valor del ARG, en dos renglones"
docker history --no-trunc --format '{{.CreatedBy}}' "$MALO" | grep 'TOKEN_MODULOS='

echo
echo "== 4. Y la configuración de la imagen trae el token de ejecución"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$MALO" | grep TOKEN

echo "== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$MALO" printenv REVISOR_TOKEN

echo
echo "== 6. docker build --check lo habría dicho antes de construir"
rc=0
docker build --check -f Dockerfile.malo . 2>&1 || rc=$?
echo "[código de salida: $rc]"

echo
echo "== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use"
cat > Dockerfile.cadena <<'FIN'
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS base
ARG TOKEN_MODULOS
RUN echo "paso 1: no uso ningún argumento"
FROM base AS hija
ARG VERSION=desarrollo
RUN echo "paso 2: tampoco"
FIN
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" --build-arg VERSION=1.3.0 \
  -f Dockerfile.cadena -t "$CADENA" . >/dev/null
docker history --no-trunc --format '{{.CreatedBy}}' "$CADENA" | head -4
