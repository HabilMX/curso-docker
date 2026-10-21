#!/usr/bin/env bash
# fig08_09.sh — Solución del Ejercicio 4: volume-nocopy. La imagen 1.5.0 trae
# /datos de 65532, pero si el volumen nuevo se monta con volume-nocopy, Docker no
# copia nada (ni el dueño) y vuelve el permission denied. Se prueba con --mount
# y con -v, que también admite la opción, pero con OTRO nombre: nocopy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0,
# tu contenedor curso-docker-revisor ni tus volúmenes, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}sin-copia-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
probar() {  # probar OPCIÓN-DE-MONTAJE…: corre el revisor con un volumen nuevo y mira /datos
  docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO "$@" \
    -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
  curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'
  docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
  docker rm -f "$NOMBRE" >/dev/null
  docker volume rm "$VOLUMEN" >/dev/null
}

echo "== 1. Con --mount …,volume-nocopy"
probar --mount type=volume,src="$VOLUMEN",dst=/datos,volume-nocopy

echo
echo "== 2. Con -v, el nombre de --mount no sirve"
salida=$(docker run --rm -v "$VOLUMEN":/datos:volume-nocopy "$IMAGEN" version 2>&1) && rc=0 || rc=$?
echo "$salida" | sed '/^$/d'
echo "[código de salida: $rc]"
docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true

echo
echo "== 3. Con -v …:nocopy"
probar -v "$VOLUMEN":/datos:nocopy
