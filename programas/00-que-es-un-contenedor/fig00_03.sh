#!/usr/bin/env bash
# fig00_03.sh — Los espacios de nombres (namespaces) del anfitrión y de un contenedor.
# Si el número entre corchetes coincide, los dos procesos comparten ese espacio.
set -euo pipefail
IMAGEN=alpine:3.24.2
TIPOS="cgroup ipc mnt net pid time user uts"

LISTA='for n in '"$TIPOS"'; do echo "$n $(readlink /proc/self/ns/$n)"; done'

ANFITRION=$(sh -c "$LISTA")
CONTENEDOR=$(docker run --rm --name curso-docker-ns "$IMAGEN" sh -c "$LISTA")

printf '%-7s %-20s %-20s %s\n' TIPO ANFITRION CONTENEDOR ¿IGUAL?
for n in $TIPOS; do
  a=$(echo "$ANFITRION"  | awk -v t="$n" '$1==t {print $2}')
  c=$(echo "$CONTENEDOR" | awk -v t="$n" '$1==t {print $2}')
  if [ "$a" = "$c" ]; then igual="sí, compartido"; else igual="no, aislado"; fi
  printf '%-7s %-20s %-20s %s\n' "$n" "${a#*:}" "${c#*:}" "$igual"
done
