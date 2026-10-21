#!/usr/bin/env bash
# fig07_06.sh — Solo lectura y el revisor endurecido completo. Primero el error:
# con --read-only, el revisor no puede guardar su reporte. Después el arreglo,
# un tmpfs solo donde hace falta escribir. Y al final, todas las opciones de la
# lección juntas: lo que Docker anotó, lo que el núcleo aplica y cómo se apaga.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
SERVICIOS='propio http://127.0.0.1:8080/salud'
# El número del archivo temporal cambia en cada corrida: se tapa a la vista.
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. --read-only, y el revisor guardando su reporte en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
echo "-- /salud no escribe nada, así que sigue contestando:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/salud"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El arreglo: un tmpfs pequeño solo en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=1m \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -o /dev/null -w '[%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker inspect --format '{{range $ruta, $opciones := .HostConfig.Tmpfs}}{{$ruta}} {{$opciones}}{{end}}' "$NOMBRE"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Todo junto: el revisor endurecido"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
echo "-- lo que Docker anotó:"
docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} SecurityOpt={{.HostConfig.SecurityOpt}} Init={{.HostConfig.Init}} Restart={{.HostConfig.RestartPolicy.Name}}' "$NOMBRE"
echo "-- los procesos:"
docker top "$NOMBRE" -o pid,ppid,user,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
echo "-- lo que el núcleo aplica al revisor (el hijo de docker-init):"
PID1=$(pid_de "$NOMBRE")
HIJO=$(pgrep -P "$PID1" | head -1)
grep -E '^(CapEff|CapBnd|NoNewPrivs)' "/proc/$HIJO/status"
echo "-- docker stop:"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
