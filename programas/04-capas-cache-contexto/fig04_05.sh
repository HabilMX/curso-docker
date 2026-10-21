#!/usr/bin/env bash
# fig04_05.sh — Solución del Ejercicio 1: qué pasos se repiten con cada cambio.
# Construye una vez para llenar las dos cachés y después aplica cuatro cambios, uno
# por uno, reconstruyendo con el Dockerfile de la lección después de cada uno.
# Borra al salir su imagen y su caché de compilación.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L4="${PREFIJO}revisor:1.1.0"

cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
# construir: construye con --progress=plain y deja el registro en ../construccion.log
construir() { docker build --progress=plain -t "$L4" . > ../construccion.log 2>&1; }
# pasos: las mismas ayudas de fig04_03.sh
pasos() {
  awk '
    /^#[0-9]+ \[([a-z0-9-]+ )?[0-9]+\/[0-9]+\]/ {
      if (!($1 in paso)) {
        l=$0; sub(/^#[0-9]+ \[([a-z0-9-]+ )?/, "", l); split(l, p, "/"); i=p[1]+0
        sub(/^[0-9]+\/[0-9]+\] /, "", l); sub(/--mount=[^ ]+ +/, "", l); paso[$1]=i; nombre[i]=l; if (i > k) k=i
      }
    }
    /^#[0-9]+ (CACHED|DONE)/ { if ($1 in paso) estado[paso[$1]]=$2 ($2=="DONE" ? " " $3 : "") }
    END { for (i=1; i<=k; i++) printf "  paso %d  %-10s %s\n", i, estado[i], substr(nombre[i], 1, 60) }
  ' ../construccion.log
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rmi -f "$L4" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

# La primera, sin caché de capas: así el RUN corre y llena la caché de compilación.
docker build -q --no-cache -t "$L4" . >/dev/null

titulo "a) Solo cambia la fecha de un archivo (touch), no su contenido"
sleep 1; touch internal/reporte/tabla.go
construir; pasos

titulo "b) Un comentario nuevo en cmd/revisor/main.go"
echo "// cambio de prueba $(date +%s)" >> cmd/revisor/main.go
construir; pasos

titulo "c) Un comentario nuevo en go.mod"
echo "// cambio de prueba $(date +%s)" >> go.mod
construir; pasos

titulo "d) Un comentario nuevo en el Dockerfile"
echo "# cambio de prueba $(date +%s)" >> Dockerfile
construir; pasos
