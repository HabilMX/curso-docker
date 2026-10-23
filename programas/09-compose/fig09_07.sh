#!/usr/bin/env bash
# fig09_07.sh — Tres comportamientos de Compose con el archivo final (fig09_04):
#   1. tres servicios que construyen la MISMA etiqueta a la vez;
#   2. sin «pull_policy: never», qué hace Compose con una imagen que no existe;
#   3. «up --wait» con un servicio que está caído a propósito.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig09»: el proyecto de Compose se llama curso-docker-fig09
# y las imágenes curso-docker-revisor:fig09 y curso-docker-prueba:fig09. Así el
# guion nunca toca tu proyecto curso-docker, tu curso-docker-revisor:1.5.0 ni tu
# curso-docker-prueba:1.0.0, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig09.XXXXXX")"
export COMPOSE_PROJECT_NAME="${PREFIJO}fig09"   # gana sobre el «name:» del archivo
trap 'cd "$TRABAJO/revisor" 2>/dev/null && docker compose down --volumes --remove-orphans >/dev/null 2>&1
      docker rmi -f "${PREFIJO}revisor:fig09" "${PREFIJO}prueba:fig09" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso, el estado de la Lección 8 (con el
# token de la Lección 6) y el compose.yaml de fig09_04.compose.yaml, con los nombres de apoyo
# y el puerto del guion.
mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
cp -R "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$AQUI/estado/secretos" "$TRABAJO/revisor/"
chmod 644 "$TRABAJO/revisor/secretos/revisor_token.txt"   # 644: solo porque el token es de mentira (9.8.4)
sed -e "s/curso-docker-revisor:1.5.0/${PREFIJO}revisor:fig09/" \
    -e "s/curso-docker-prueba:1.0.0/${PREFIJO}prueba:fig09/" \
    -e "s/127.0.0.1:8080:8080/127.0.0.1:${PUERTO}:8080/" \
    "$AQUI/fig09_04.compose.yaml" > "$TRABAJO/revisor/compose.yaml"
cd "$TRABAJO/revisor"
TOKEN="$(cat secretos/revisor_token.txt)"   # se lee del archivo; nunca se escribe

# Si corres el guion con otro PREFIJO o PUERTO, la salida se escribe con los del
# curso. Con los valores por omisión esto no cambia nada.
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g" -e "s/127.0.0.1:${PUERTO}->/127.0.0.1:8080->/g" \
                -e "s/127.0.0.1:${PUERTO}\//127.0.0.1:8080\//g" -e "s/published: \"${PUERTO}\"/published: \"8080\"/"; }
# muestra COMANDO: lo imprime con «$ », lo corre y dice el código si no fue 0
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# eventos: de lo que imprime Compose, solo los renglones «Objeto nombre Estado»
eventos() { grep -E '^ *(Image|Network|Volume|Container) ' | sed -E 's/^ +//; s/ +$//'; }
# esperar SERVICIO ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar() {
  for _ in $(seq 60); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "${COMPOSE_PROJECT_NAME}-$1-1" 2>/dev/null)" = "$2" ] && return 0
    sleep 1
  done
  echo "($1 no llegó a $2)"; return 1
}
# tabla: el reporte en forma de tabla, con el token y con los tiempos tapados
tabla() { curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'; }
cp compose.yaml compose.final.yaml

echo "== 1. Las tres copias del servicio de prueba con «build»"
# Pone «build» en el ancla común (las tres copias la heredan) y quita la de prueba-sano.
sed -i -e 's|^  image: \(.*prueba:fig09\)$|  build: ../servicio-prueba\n  image: \1|' \
       -e '/^    build: ..\/servicio-prueba$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
# Es una carrera: a veces una de las tres termina antes de que empiecen las otras
# y no choca. Por eso se intenta cinco veces, borrando la etiqueta entre una y otra.
for i in 1 2 3 4 5; do
  docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1
  echo "-- intento $i"
  muestra "docker compose build >build.log 2>&1; echo \"build salió con \$?\"; grep -h '^target' build.log || true"
done
docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1

echo
echo "== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir"
cp compose.final.yaml compose.yaml
sed -i '/^  pull_policy: never$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'"
docker compose down --remove-orphans >/dev/null 2>&1

echo
echo "== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar"
cp compose.final.yaml compose.yaml
docker compose build >/dev/null 2>&1
inicio=$(date +%s)
muestra "docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1"
echo "(tardó $(( $(date +%s) - inicio )) s)"
muestra "docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1"
muestra "docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 4. Lo que sí funciona: up -d y esperar la salud del revisor"
esperar revisor healthy && echo "revisor: healthy"
muestra "tabla"
