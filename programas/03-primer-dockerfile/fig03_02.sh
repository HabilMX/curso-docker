#!/usr/bin/env bash
# fig03_02.sh — Sin USER, la imagen base corre como root.
# Pregunta con qué usuario arranca la imagen de Go que usa el revisor, y compara
# con un usuario sin privilegios elegido por número.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
IMAGEN=golang:1.27.3-trixie
docker pull -q "$IMAGEN" >/dev/null

echo "== 1. Lo que la imagen base declara como usuario (vacío = root)"
docker image inspect --format 'User="{{.Config.User}}"' "$IMAGEN"

echo
echo "== 2. Quién soy dentro, sin decir nada"
docker run --rm --name "${PREFIJO}quien" "$IMAGEN" id

echo
echo "== 3. Quién soy dentro, con el usuario 10001:10001"
docker run --rm --name "${PREFIJO}quien" --user 10001:10001 "$IMAGEN" id

echo
echo "== 4. ¿Existe ese usuario en /etc/passwd de la imagen?"
docker run --rm --name "${PREFIJO}quien" "$IMAGEN" \
  sh -c 'grep -q ":10001:" /etc/passwd && echo "sí está" || echo "no está"'

echo
echo "== 5. ¿Puede ese usuario abrir un puerto bajo? (primer puerto sin privilegios)"
docker run --rm --name "${PREFIJO}quien" --user 10001:10001 "$IMAGEN" \
  cat /proc/sys/net/ipv4/ip_unprivileged_port_start

echo
echo "== 6. Lo mismo con la red del anfitrión (--network host)"
docker run --rm --name "${PREFIJO}quien" --network host --user 10001:10001 "$IMAGEN" \
  cat /proc/sys/net/ipv4/ip_unprivileged_port_start

echo
echo "== 7. Y el valor del propio anfitrión (sin contenedor)"
cat /proc/sys/net/ipv4/ip_unprivileged_port_start
