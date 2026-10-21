#!/usr/bin/env bash
# fig08_08.sh — Red interna. El servicio de prueba vive SOLO en una red interna,
# sin salida a internet. El revisor vive en la red normal (por donde se publica
# su puerto) y se conecta además a la interna. Es el estado final de la lección.
# Usa tu imagen curso-docker-prueba:1.0.0 (de la Lección 2) sin modificarla.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores, tus redes,
# tus volúmenes ni tus imágenes del curso, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
PRUEBA="${PREFIJO}prueba-fig08"
RED="${PREFIJO}red-fig08"
INTERNA="${PREFIJO}interna-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
IMAGEN_PRUEBA=curso-docker-prueba:1.0.0
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null 2>&1 || true
      docker network rm "$RED" "$INTERNA" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

docker image inspect "$IMAGEN_PRUEBA" >/dev/null 2>&1 \
  || { echo "falta $IMAGEN_PRUEBA: constrúyela como en la Lección 2"; exit 1; }
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null || exit 1

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" \
    | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /' | nombres
}

echo "== 1. Dos redes: la normal y la interna"
docker network create "$RED" >/dev/null
docker network create --internal "$INTERNA" >/dev/null
docker network inspect --format '{{.Name}} driver={{.Driver}} interna={{.Internal}}' "$RED" "$INTERNA" | nombres

echo
echo "== 2. El servicio de prueba, solo en la interna; el revisor, solo en la normal"
docker run -d --name "$PRUEBA" --network "$INTERNA" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
docker run -d --name "$NOMBRE" --network "$RED" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -v "$VOLUMEN":/datos -e REVISOR_SERVICIOS="prueba http://$PRUEBA:9000/ 2s" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 3. Conectar el revisor también a la interna, sin reiniciarlo"
docker network connect "$INTERNA" "$NOMBRE"
tabla
docker inspect --format '{{range $red, $v := .NetworkSettings.Networks}}{{$red}} {{end}}' "$NOMBRE" | nombres
echo "-- el puerto publicado sigue en 127.0.0.1:"
docker port "$NOMBRE" | sed "s/:$PUERTO\$/:<puerto>/"

echo
echo "== 4. Desde la red interna no hay salida a internet"
docker run --rm --network "$INTERNA" "$AYUDANTE" wget -q -T 5 -O /dev/null https://www.docker.com/
echo "[código de salida: $?]"
echo "-- pero la puerta de enlace de la red interna sí contesta:"
PUERTA=$(docker network inspect --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' "$INTERNA")
docker run --rm --network "$INTERNA" "$AYUDANTE" sh -c "ip route; ping -c 1 -W 2 $PUERTA | grep -E 'packets'" \
  | sed -E 's/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?/<IP>\1/g'
echo "-- desde la red normal, sí:"
docker run --rm --network "$RED" "$AYUDANTE" wget -q -T 5 -O /dev/null https://www.docker.com/ \
  && echo "desde la red normal sí hay salida"
