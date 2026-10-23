#!/usr/bin/env bash
# fig01_08.sh — ¿Te dejó otro tutorial restos de Docker en apt?
# Solo lee: no cambia nada en tu equipo. Córrelo ANTES de fig01_03.sh.
set -uo pipefail

echo "== 1. Archivos de apt que apuntan a download.docker.com"
grep -rl download.docker.com /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null \
  || echo "(ninguno)"

echo
echo "== 2. Llaves de Docker sueltas en las carpetas de llaves"
ls -l /etc/apt/keyrings/ /usr/share/keyrings/ 2>/dev/null | grep -i docker \
  || echo "(ninguna)"

echo
echo "== 3. Llaves de Docker en el llavero viejo (apt-key)"
apt-key list 2>/dev/null | grep -i -B1 -A1 docker \
  || echo "(ninguna)"
