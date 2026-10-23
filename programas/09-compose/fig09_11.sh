#!/usr/bin/env bash
# fig09_11.sh — Quién puede leer el token: 644, 600 de tu usuario, 600 de 65532 (la
# receta B de la lección, en su orden), el orden contrario que falla, 640 con grupo
# 65532 y la carpeta secretos/ en 700. En cada caso se mide lo mismo: si un usuario sin privilegios
# del equipo (la cuenta «nobody») lo lee, si tú lo lees, y si el revisor del
# contenedor (usuario 65532) lo lee. El token es de mentira.
# Usa sudo (para hacerse pasar por «nobody» y para cambiar el dueño del archivo):
# córrelo donde tengas sudo, en el disco propio de Linux (una carpeta compartida
# con otro sistema miente con los dueños y los permisos).
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
      sudo -n chown -R "$(id -u):$(id -g)" "$TRABAJO" >/dev/null 2>&1
      case "$TRABAJO" in "${TMPDIR:-/tmp}/${PREFIJO}fig09."??????) rm -rf "$TRABAJO" ;; esac' EXIT

# El proyecto: el código que entrega el curso, el estado de la Lección 8 (con el
# token de la Lección 6) y el compose.yaml de fig09_04.compose.yaml, con los nombres de apoyo
# y el puerto del guion.
mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
cp -R "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$AQUI/estado/secretos" "$TRABAJO/revisor/"
chmod 755 "$TRABAJO" "$TRABAJO/revisor" "$TRABAJO/revisor/secretos"   # el camino hasta el archivo está abierto: lo que se mide es el archivo
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

# La cuenta sin privilegios: «nobody» existe en todo Linux y sirve para hacerse
# pasar por «otro usuario cualquiera de tu equipo». El nombre de tu usuario y de tu
# grupo se tapa con sed, porque depende del equipo.
SUBE="docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
PS_REV="docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
STAT="stat -c '%a %U:%G' secretos/revisor_token.txt"
TAPA_TODO="sed -E 's/ .*/ <tu usuario>:<tu grupo>/'"
TAPA_DUENO="sed -E 's/ [^:]+:/ <tu usuario>:/'"
# El control de cada negativa: «nobody» sí llega hasta el archivo (la carpeta está
# abierta); si el cat siguiente falla, es por el permiso del archivo.
CONTROL="sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt"
OTRO="sudo -u nobody cat secretos/revisor_token.txt"

echo "== 1. Permisos 644, dueño tu usuario"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "$PS_REV"

echo
echo "== 2. Permisos 600, dueño tu usuario"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
sleep 4
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "[ \"\$(docker inspect --format '{{.RestartCount}}' ${COMPOSE_PROJECT_NAME}-revisor-1)\" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'"

echo
echo "== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala"
muestra "chmod 644 secretos/revisor_token.txt"   # el estado con el que llegas de la Lección 6
muestra "chmod 600 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "$STAT"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "sudo cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"   # el archivo vuelve a ser tuyo
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chgrp +65532 secretos/revisor_token.txt"
muestra "chmod 640 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_DUENO"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 5. Lo mismo, más la carpeta secretos/ cerrada con 700"
muestra "chmod 700 secretos"
muestra "stat -c '%a' secretos"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"
muestra "chmod 755 secretos"

echo
echo "== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"

echo
echo "== 7. ¿El grupo 65532 es de alguien en este equipo?"
muestra "getent group 65532"
