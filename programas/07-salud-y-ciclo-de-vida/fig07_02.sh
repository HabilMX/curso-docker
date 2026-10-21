#!/usr/bin/env bash
# fig07_02.sh — El proceso número 1 y las señales, con un programa que NO sabe
# apagarse: sleep. Mide cuánto tarda docker stop, con qué código muere el
# contenedor, qué cambia con -t y con --init, y quién recoge a los zombis.
# No construye nada: usa la imagen de Go que ya bajaste para el revisor.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor
# ni tu imagen curso-docker-revisor:1.4.0, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}fig07-sleep"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
# detener [opciones de docker stop]: detiene el contenedor, mide y dice cómo murió
detener() {
  local inicio fin
  inicio=$(t); docker stop "$@" "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop${*:+ $*} tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
  docker rm -f "$NOMBRE" >/dev/null
}

echo "== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
PID1=$(pid_de "$NOMBRE")
grep -E '^SigCgt' "/proc/$PID1/status"
detener

echo
echo "== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
detener -t 2

echo
echo "== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM"
sleep 300 & HIJO=$!
kill -TERM "$HIJO"; rc=0; wait "$HIJO" || rc=$?
echo "sleep en el equipo murió con código $rc"

echo
echo "== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep"
docker run -d --init --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
detener

echo
echo "== 5. Zombis: un hijo huérfano termina y nadie lo recoge"
# El subshell lanza «sleep 1» y se va; ese sleep queda huérfano y el núcleo se
# lo entrega al proceso 1. Después, exec convierte al shell en «sleep 300».
docker run -d --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- docker top:"
docker top "$NOMBRE" -o pid,stat,args | sed -E 's/^ *[0-9]+ /<pid> /'
echo "-- ps en el equipo, hijos del proceso 1 del contenedor:"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 6. Lo mismo con --init: el init recoge al huérfano"
docker run -d --init --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
