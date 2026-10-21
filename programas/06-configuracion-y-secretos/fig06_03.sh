#!/usr/bin/env bash
# fig06_03.sh — Configurar sin reconstruir: la MISMA imagen, tres configuraciones.
# Una variable mal escrita, una lista por -e y otra lista por --env-file.
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
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# La tabla del revisor, con el tiempo tapado: es lo único que cambia entre corridas.
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
}

echo "== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS"
rc=0
docker run --name "$NOMBRE" -e REVISOR_SERVICIO='propio http://127.0.0.1:8080/salud' "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. La configuración por -e: un solo servicio"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla
IMAGEN_1=$(docker inspect --format '{{.Image}}' "$NOMBRE")
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Otra configuración, desde un archivo con --env-file"
cat > revisor.env <<'FIN'
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
FIN
cat revisor.env
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --env-file revisor.env "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR

echo "== 5. ¿Las dos corridas usaron la misma imagen?"
IMAGEN_2=$(docker inspect --format '{{.Image}}' "$NOMBRE")
[ "$IMAGEN_1" = "$IMAGEN_2" ] && echo "sí: el mismo identificador de imagen en las dos" || echo "no: son imágenes distintas"
