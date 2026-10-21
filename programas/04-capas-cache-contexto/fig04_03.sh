#!/usr/bin/env bash
# fig04_03.sh — Capas y caché: el Dockerfile de la Lección 3 contra el de la
# Lección 4. Construye los dos en frío, otra vez sin cambios y después de
# cambiar un archivo; cronometra cada construcción, muestra qué pasos salieron
# de la caché (--progress=plain) y compara las capas con docker history.
# Borra al salir sus imágenes y su caché de compilación.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L3="${PREFIJO}revisor:1.0.0"
L4="${PREFIJO}revisor:1.1.0"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
# muestra: imprime el comando con «$ » y lo ejecuta (salida y error juntos)
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
# construir ETIQUETA DOCKERFILE [opciones...]: construye con --progress=plain,
# guarda el registro en ../construccion.log e imprime cuánto tardó
construir() {
  local etiqueta="$1" archivo="$2" inicio fin; shift 2
  inicio=$(t)
  docker build --progress=plain "$@" -t "$etiqueta" -f "$archivo" . > ../construccion.log 2>&1
  fin=$(t)
  echo "$etiqueta ($archivo${*:+ $*}): $(( fin - inicio )) ms"
}
# pasos: de ../construccion.log, cada paso [n/m] con su estado final
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
trap 'docker rm -f "${PREFIJO}revisor" >/dev/null 2>&1; docker rmi -f "$L3" "$L4" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "1. En frío: sin caché de capas y con la caché de compilación vacía"
borrar_cache
construir "$L3" Dockerfile.leccion3 --no-cache
pasos
construir "$L4" Dockerfile --no-cache
pasos

titulo "2. Otra vez, sin cambiar nada"
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "3. Cambio un comentario en internal/reporte/tabla.go"
echo "// cambio de prueba $(date +%s)" >> internal/reporte/tabla.go
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "4. Cambio un archivo que el .dockerignore deja fuera"
echo "notas de trabajo $(date +%s)" > NOTAS.md
construir "$L4" Dockerfile
pasos

titulo "5. Las capas de cada imagen: solo los pasos de la receta"
muestra "docker history $L3 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70"
muestra "docker history $L4 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70"
muestra "docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^${PREFIJO}revisor:1\.[01]\.0 '"
muestra "for i in $L3 $L4; do docker image inspect --format \"\$i {{.Size}}\" \$i; done"

titulo "6. La caché de compilación vive en el constructor, no en la imagen"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
muestra "docker buildx du --verbose --filter 'description~=${CACHE_ID}' | grep -E '^(Description|Type):'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L4 sh -c 'du -sh /root/.cache/go-build 2>&1'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L3 sh -c 'du -sh /root/.cache/go-build 2>&1'"

titulo "7. La imagen nueva hace lo mismo que la vieja"
docker run -d --name "${PREFIJO}revisor" -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$L4" >/dev/null
for _ in $(seq 40); do docker exec "${PREFIJO}revisor" curl -fsS -o /dev/null http://127.0.0.1:8080/salud 2>/dev/null && break; sleep 0.5; done
muestra "docker exec ${PREFIJO}revisor curl -s http://127.0.0.1:8080/salud"
docker rm -f "${PREFIJO}revisor" >/dev/null

titulo "8. Borro SOLO mi caché de compilación y compruebo que ya no está"
muestra "docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]' | tail -1"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
