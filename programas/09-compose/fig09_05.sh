#!/usr/bin/env bash
# fig09_05.sh — El compose.yaml final (fig09_04): el revisor con su token como
# secreto y tres copias del servicio de prueba (sana, lenta y caída). Validar,
# levantar desde cero, leer el reporte, ver lo que creó Compose y comprobar que
# el token no está a la vista.
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

echo "== 1. Validar"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'"

echo
echo "== 2. Levantar todo desde cero"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 3. El reporte: sin token, 401; con token, la tabla"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
muestra "tabla"

echo
echo "== 4. Lo que creó Compose, todo con el nombre del proyecto"
muestra "docker network ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}} interna={{.Internal}}' | sort"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 5. El token no está a la vista"
muestra "docker inspect ${COMPOSE_PROJECT_NAME}-revisor-1 | grep -c \"\$TOKEN\""
muestra "docker compose config | grep -c \"\$TOKEN\""
muestra "docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1 | grep REVISOR_"
muestra "docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
