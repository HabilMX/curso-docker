#!/usr/bin/env bash
# fig10_03.sh — Dos plataformas: con emulación (el Dockerfile de la Lección 8, sin
# cambios) contra compilación cruzada (fig10_01.Dockerfile). Mide cuánto tarda
# cada una y comprueba, leyendo el propio binario, para qué procesador quedó.
# No crea imágenes: exporta los archivos a una carpeta de trabajo y la borra.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
trap 'rm -rf "$TRABAJO"' EXIT

# El proyecto, dos veces: con el Dockerfile de la Lección 8 (el de estado/ de la
# Lección 9) y con el de esta lección.
for d in emulada cruzada; do
  mkdir -p "$TRABAJO/$d"
  cp -R "$AQUI/../revisor/." "$TRABAJO/$d/"
  cp "$AQUI/estado/.dockerignore" "$TRABAJO/$d/"
done
cp "$AQUI/../09-compose/estado/Dockerfile" "$TRABAJO/emulada/Dockerfile"
cp "$AQUI/fig10_01.Dockerfile" "$TRABAJO/cruzada/Dockerfile"
cd "$TRABAJO"

muestra() {
  printf '$ %s\n' "$*"
  eval "$@" 2>&1
  local rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
t() { date +%s%3N; }
# maquina ARCHIVO: el campo e_machine de la cabecera ELF (bytes 18 y 19):
# 3e 00 = x86-64 (amd64), b7 00 = AArch64 (arm64)
maquina() { printf '%s: ' "$1"; od -An -tx1 -j18 -N2 "$1" | sed 's/^ //; s/3e 00/3e 00 = x86-64 (amd64)/; s/b7 00/b7 00 = AArch64 (arm64)/'; }

echo "== 1. Este equipo y lo que su constructor sabe correr"
muestra "uname -m"
muestra "docker buildx inspect | grep -E '^Platforms:'"

echo
echo "== 2. El Dockerfile de la Lección 8, para linux/amd64: todo corre emulado (QEMU)"
i=$(t)
muestra "docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada.log 2>&1; echo \"construcción: código \$?\""
f=$(t); echo "(tardó $(( (f - i) / 1000 )) s)"
muestra "{ grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110"
muestra "grep -E '^ERROR' emulada.log"
echo "(el mismo intento, dos veces más, para ver si el fallo es siempre el mismo)"
muestra "for n in 2 3; do docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada-\$n.log 2>&1; echo \"intento \$n: código \$?\"; { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada-\$n.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110; done"

echo
echo "== 3. fig10_01.Dockerfile, para las DOS plataformas: compila cruzado"
i=$(t)
muestra "docker buildx build --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-cruzada cruzada > cruzada.log 2>&1; echo \"construcción: código \$?\""
f=$(t); echo "(tardó $(( (f - i) / 1000 )) s)"
muestra "grep -oE '\[linux/[a-z0-9>-]+ (pruebas|binario) [0-9]/[0-9]\]' cruzada.log | sort -u"
muestra "ls salida-cruzada"
muestra "maquina salida-cruzada/linux_amd64/revisor; maquina salida-cruzada/linux_arm64/revisor"
