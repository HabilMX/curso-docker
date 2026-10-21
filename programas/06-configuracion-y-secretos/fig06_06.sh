#!/usr/bin/env bash
# fig06_06.sh — El secreto de EJECUCIÓN: por variable de entorno (se ve) y por
# archivo (no se ve), con el error de permisos que vas a encontrar primero.
# Córrelo en el disco propio de Linux: una carpeta compartida con otro sistema
# miente con los permisos.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
SERVICIOS='propio http://127.0.0.1:8080/salud'

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}

echo "== 1. El token por -e: funciona, pero queda a la vista"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  -e REVISOR_TOKEN="$(cat secretos/revisor_token.txt)" "$IMAGEN" >/dev/null
sleep 1
echo "-- lo que dice el revisor al arrancar:"
docker logs "$NOMBRE" 2>&1
echo "-- lo que ve cualquiera con docker inspect:"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep TOKEN
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El token por archivo, con permisos 600"
chmod 600 secretos/revisor_token.txt
stat -c '%a %n' secretos/revisor_token.txt
rc=0
timeout 20 docker run --name "$NOMBRE" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. El token por archivo, con permisos 644 y montado de solo lectura"
chmod 644 secretos/revisor_token.txt
stat -c '%a %n' secretos/revisor_token.txt
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
echo "-- /salud no pide token:"
curl -s "http://127.0.0.1:$PUERTO/salud"; echo
echo "-- /api/estados sin token:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
echo "-- /api/estados con el token:"
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" \
  "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'

echo
echo "== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR
docker inspect --format '{{range .Mounts}}{{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE"
