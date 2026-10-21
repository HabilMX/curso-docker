#!/usr/bin/env bash
# fig09_10.sh — Las corridas de las soluciones de los ejercicios, con el archivo
# final (fig09_04): una red que no está declarada (Ejercicio 1), qué recrea
# Compose con tres cambios distintos (Ejercicio 2) y el diagnóstico del
# Ejercicio 3. Cada cambio se hace a la vista con sed y se deshace después.
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
chmod 644 "$TRABAJO/revisor/secretos/revisor_token.txt"
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
# arriba: levanta el archivo final y espera al revisor
arriba() { cp compose.final.yaml compose.yaml; chmod 644 secretos/revisor_token.txt
           docker compose up -d >/dev/null 2>&1; esperar revisor healthy; }
# cambios: lo que dice «up -d», sin los pasos intermedios
cambios() { docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy|Recreate$'; }

echo "== Ejercicio 1. Un servicio en una red que no está declarada arriba"
sed -i 's/^  networks: \[interna\]$/  networks: [otra]/' compose.yaml
muestra "docker compose config --quiet"
docker compose build >/dev/null 2>&1
arriba

echo
echo "== Ejercicio 2.1. lento: de 5s a 4s en REVISOR_SERVICIOS"
sed -i 's|http://prueba-lento:9000/ 5s|http://prueba-lento:9000/ 4s|' compose.yaml
muestra "cambios"
arriba >/dev/null

echo
echo "== Ejercicio 2.2. mem_limit: de 32m a 24m en el ancla x-prueba"
sed -i 's/^  mem_limit: 32m$/  mem_limit: 24m/' compose.yaml
muestra "docker compose config | grep mem_limit"
muestra "cambios"
arriba >/dev/null

echo
echo "== Ejercicio 2.3. Sin cambiar el archivo: chmod 600 al token"
chmod 600 secretos/revisor_token.txt
muestra "cambios"
muestra "tabla | head -2"
muestra "docker compose restart revisor 2>&1 | eventos | grep -v Restarting"
sleep 3
muestra "docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
chmod 644 secretos/revisor_token.txt
muestra "docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 Started'"
esperar revisor healthy && echo "revisor: healthy"

echo
echo "== Ejercicio 3. El revisor sin volumen en /datos, con los cuatro servicios"
docker compose down --volumes >/dev/null 2>&1
sed -i '/^    volumes:$/{N;d;}' compose.yaml
docker compose up -d >/dev/null 2>&1
esperar revisor healthy; esperar prueba-lento unhealthy
muestra "docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s -H \"Authorization: Bearer \$TOKEN\" http://127.0.0.1:${PUERTO}/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'"
muestra "docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes"
muestra "docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
