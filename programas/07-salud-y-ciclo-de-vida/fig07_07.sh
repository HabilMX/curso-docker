#!/usr/bin/env bash
# fig07_07.sh — Capacidades y no-new-privileges, vistos en un contenedor que SÍ
# tiene shell y herramientas: la imagen de Go que ya bajaste. Qué puede hacer
# root con sus 14 capacidades, qué deja de poder sin ellas, y cómo un programa
# setuid convierte a un usuario normal en root… salvo con no-new-privileges.
# No construye nada y cada contenedor se borra solo (--rm).
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombre de apoyo con «fig07»: el guion nunca toca tus contenedores del curso.
NOMBRE="${PREFIJO}fig07-caps"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# correr [opciones de docker run] -- COMANDO: corre COMANDO con sh en un contenedor desechable
correr() {
  local opciones=()
  while [ "$1" != "--" ]; do opciones+=("$1"); shift; done
  shift
  docker run --rm --name "$NOMBRE" "${opciones[@]}" "$GO" sh -c "$1" 2>&1 || echo "[código de salida: $?]"
}
# La prueba: ¿puede root regalarle un archivo a otro usuario?
REGALAR='grep CapEff /proc/self/status; touch /tmp/a && chown 10001 /tmp/a && echo "chown: hecho"'

echo "== 1. root, con las capacidades que Docker deja por omisión"
correr -- "$REGALAR"

echo
echo "== 2. El mismo root, con --cap-drop ALL"
correr --cap-drop ALL -- "$REGALAR"

echo
echo "== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta"
correr --cap-drop ALL --cap-add CHOWN -- "$REGALAR"

# La otra prueba: un usuario normal ejecuta una copia de «id» con el bit setuid.
SETUID='cp /usr/bin/id /tmp/id-suid && chmod u+s /tmp/id-suid && ls -l /tmp/id-suid | cut -d" " -f1,3
setpriv --reuid 10001 --regid 10001 --clear-groups sh -c "id; /tmp/id-suid; grep NoNewPrivs /proc/self/status"'

echo
echo "== 4. Un programa setuid de root, ejecutado por el usuario 10001"
correr -- "$SETUID"

echo
echo "== 5. Lo mismo con --security-opt no-new-privileges"
correr --security-opt no-new-privileges -- "$SETUID"

echo
echo "== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80"
correr --user 10001:10001 --cap-drop ALL -- \
  'cat /proc/sys/net/ipv4/ip_unprivileged_port_start; perl -MIO::Socket::INET -e '"'"'IO::Socket::INET->new(LocalPort => 80, Listen => 1, ReuseAddr => 1) or die "no pude: $!\n"; print "escuchando en el 80\n"'"'"
