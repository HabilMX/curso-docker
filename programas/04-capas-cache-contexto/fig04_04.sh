#!/usr/bin/env bash
# fig04_04.sh — Qué viaja en el contexto. Siembra en la carpeta un respaldo de
# 50 MB y una carpeta .git falsa de 10 MB, y construye tres veces:
#   1) Dockerfile de esta lección (COPY selectivos), con .dockerignore;
#   2) Dockerfile de la Lección 3 (COPY . .), con .dockerignore;
#   3) Dockerfile de la Lección 3, SIN .dockerignore: falla a propósito.
# Borra al salir lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L4="${PREFIJO}revisor:1.1.0"
CON="${PREFIJO}revisor:con-ignore"
SIN="${PREFIJO}revisor:sin-ignore"

cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rmi -f "$L4" "$CON" "$SIN" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB"
head -c 52428800 /dev/urandom > respaldo.tar
mkdir -p .git && head -c 10485760 /dev/urandom > .git/objeto-falso
muestra "for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size \$f; done"

titulo "1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore"
muestra "docker build --progress=plain -t $L4 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore"
muestra "docker build --progress=plain -t $CON -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "3. Dockerfile de la Lección 3, SIN .dockerignore"
mv .dockerignore dockerignore.apartado
muestra "docker build --progress=plain -t $SIN -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"
grep -E -A4 '^#[0-9]+ ERROR|error obtaining' ../construccion.log | head -8
mv dockerignore.apartado .dockerignore
