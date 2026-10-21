#!/usr/bin/env bash
# fig08_06.sh — tmpfs contra volumen. Un contenedor de solo lectura con dos
# lugares escribibles: un volumen en /datos y un tmpfs de 1 MB en /cache. Escribe
# en los dos, se reinicia, y se ve qué sobrevivió. También el tope del tmpfs.
# No construye nada: usa el contenedor ayudante alpine:3.24.2.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores ni tus
# volúmenes del curso, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}ayudante-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true' EXIT
# en COMANDO: corre COMANDO con sh dentro del contenedor y avisa si falló
en() { docker exec "$NOMBRE" sh -c "$1" 2>&1 || echo "[código de salida: $?]"; }

echo "== 1. Solo lectura, con un volumen en /datos y un tmpfs en /cache"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --mount type=volume,src="$VOLUMEN",dst=/datos \
  --mount type=tmpfs,dst=/cache,tmpfs-size=1m \
  "$AYUDANTE" sleep 300 >/dev/null
echo "-- dónde está montado cada uno, de qué tipo y con qué opciones:"
en 'awk "\$2 == \"/datos\" || \$2 == \"/cache\" {print \$2, \$3, \$4}" /proc/mounts'
en 'stat -c "%a %n" /cache'

echo
echo "== 2. Escribir en los dos, y en la raíz"
en 'echo reporte > /datos/a.txt && echo temporal > /cache/b.txt && ls /datos /cache'
en 'echo hola > /c.txt'

echo
echo "== 3. El tmpfs tiene tope: 2 MB no caben en 1 MB"
en 'dd if=/dev/zero of=/cache/grande bs=1k count=2000 2>&1 | head -1'
en 'rm -f /cache/grande'

echo
echo "== 4. Reiniciar el contenedor"
docker restart -t 2 "$NOMBRE" >/dev/null
en 'ls /datos; echo "-- /cache tiene $(ls /cache | wc -l) archivos"'
