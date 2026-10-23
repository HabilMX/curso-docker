#!/usr/bin/env bash
# fig01_01.sh — ¿Qué sistema tengo y qué nombre en clave le toca en el
# repositorio de Docker? Solo lee archivos de configuración (os-release): no
# cambia nada en tu equipo.
# Uso: ./fig01_01.sh            (lee /etc/os-release, el de tu sistema)
#      ./fig01_01.sh ARCHIVO    (lee otro archivo con el mismo formato)
set -euo pipefail
ARCHIVO="${1:-/etc/os-release}"

# os-release es un archivo de variables de shell: «.» lo carga en este guion, y
# cargar es EJECUTAR: pásale solo archivos os-release (puras asignaciones).
. "$ARCHIVO"

echo "== Lo que dice $ARCHIVO"
echo "NAME=$NAME"
echo "VERSION=${VERSION:-}"
echo "ID=$ID  ID_LIKE=${ID_LIKE:-}"
echo "VERSION_CODENAME=${VERSION_CODENAME:-(vacío)}"
echo "UBUNTU_CODENAME=${UBUNTU_CODENAME:-(no existe)}"
echo "DEBIAN_CODENAME=${DEBIAN_CODENAME:-(no existe)}"

echo
echo "== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)"
echo "Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}"

echo
echo "== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)"
dpkg --print-architecture
