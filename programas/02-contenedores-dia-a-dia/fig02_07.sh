#!/usr/bin/env bash
# fig02_07.sh — El ciclo de vida completo y la limpieza: stop, start, rm y --rm.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
NOMBRE="${PREFIJO}prueba"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "$NOMBRE" "${PREFIJO}efimero" >/dev/null 2>&1 || true' EXIT
ms() { date +%s%3N; }

docker run -d --name "$NOMBRE" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && break; sleep 0.5; done

echo "== 1. Borrar un contenedor que está corriendo, sin -f"
docker rm "$NOMBRE"
echo "código de salida: $?"

echo
echo "== 2. Detenerlo, midiendo cuánto tarda"
inicio=$(ms); docker stop "$NOMBRE" >/dev/null; fin=$(ms)
echo "docker stop tardó $(( fin - inicio )) ms"
docker ps -a --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'
docker logs --tail 2 "$NOMBRE"

echo
echo "== 3. Detenido no es borrado: vuelve a arrancar con start"
docker start "$NOMBRE" >/dev/null
docker ps --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'

echo
echo "== 4. Ahora sí: borrarlo"
docker stop "$NOMBRE" >/dev/null
docker rm "$NOMBRE"

echo
echo "== 5. Un contenedor con --rm se borra solo al terminar"
# Lo que va después de la imagen reemplaza al comando por omisión: aquí, en vez
# de servir, el programa corre su subcomando healthcheck y termina.
docker run --rm --name "${PREFIJO}efimero" "$IMAGEN" healthcheck
echo "código de salida: $?"
docker ps -a --filter name="${PREFIJO}efimero" --format '{{.Names}}' | wc -l

echo
echo "== 6. La revisión final: ningún contenedor del curso"
docker ps -a --filter name="^${PREFIJO}" --format '{{.Names}}' | wc -l
