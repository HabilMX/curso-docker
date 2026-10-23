#!/usr/bin/env bash
# fig10_04.sh — La entrega completa: dos plataformas, SBOM y procedencia en modo
# max, publicadas en un registro local. Leer el índice, la lista de materiales y
# la procedencia; comparar modo min contra modo max; volver a construir para ver
# qué digest cambia y cuál no; y traer la imagen por digest.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig10» (como en fig10_02.sh): nunca toca tu registro
# curso-docker-registro ni tus imágenes, y al salir borra solo lo que creó.
P_REG="${P_REG:-5000}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
REGISTRO="${PREFIJO}registro-fig10"
REPO="localhost:${P_REG}/${PREFIJO}revisor"
IMG="$REPO:fig10"
# Al salir se borra POR NOMBRE, nunca por identificador (docker rmi -f <id>): ese borraría
# también cualquier otra imagen idéntica que tengas con otro nombre. Con el almacén de
# containerd, `--push` también deja la imagen en tu equipo: por eso se borran las copias.
borra_copias() { docker images --digests --format '{{.Repository}}@{{.Digest}}' | grep "^$REPO@" | xargs -r docker rmi >/dev/null 2>&1
                 docker images --format '{{.Repository}}:{{.Tag}}' | grep "^$REPO:" | xargs -r docker rmi >/dev/null 2>&1; }
trap 'docker rm -f -v "$REGISTRO" >/dev/null 2>&1
      borra_copias
      rm -rf "$TRABAJO"' EXIT
# ocupado PUERTO: ¿ya contesta algo en 127.0.0.1:PUERTO? (por ejemplo, TU registro)
ocupado() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
ocupado "$P_REG" && { echo "El puerto $P_REG ya está en uso (¿tu registro?). Corre con otro: P_REG=…" >&2; exit 1; }

mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp "$AQUI/fig10_01.Dockerfile" "$TRABAJO/revisor/Dockerfile"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"

nombres() { sed -e "s/${PREFIJO}/curso-docker-/g" -e "s/localhost:${P_REG}\//localhost:5000\//g" \
                -e "s/127.0.0.1:${P_REG}/127.0.0.1:5000/g"; }
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
esperar_http() { for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done; echo "(no respondió $1)"; }
t() { date +%s%3N; }
# Atajos para leer lo que guarda el registro (el texto del comando se imprime
# completo en cada «muestra», para que lo puedas copiar).
INSPECT="docker buildx imagetools inspect"

echo "== 1. Registro local"
muestra "docker run -d --name $REGISTRO -p 127.0.0.1:${P_REG}:5000 registry:3.1.2 >/dev/null && echo registro arriba"
esperar_http "http://127.0.0.1:${P_REG}/v2/"

echo
echo "== 2. Construir para dos plataformas, con SBOM y procedencia max, y publicar"
i=$(t)
muestra "docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t $IMG --push . > ../construccion.log 2>&1; echo \"construcción: código \$?\""
f=$(t); echo "(tardó $(( (f - i) / 1000 )) s)"
muestra "grep -E 'exporting (manifest|attestation manifest|manifest list) sha256' ../construccion.log | sed -E 's/^#[0-9]+ //; s/ done$//; s/ [0-9.]+s$//' | sort -u"

echo
echo "== 3. El índice que quedó en el registro"
muestra "$INSPECT $IMG"
INDICE="$($INSPECT "$IMG" --format '{{json .Manifest.Digest}}' | tr -d '"')"

echo
echo "== 4. La lista de materiales (SBOM) de linux/amd64"
muestra "$INSPECT $IMG --format '{{range (index .SBOM \"linux/amd64\").SPDX.packages}}{{.name}} {{.versionInfo}}{{println}}{{end}}' | sort"
muestra "$INSPECT $IMG --format '{{(index .SBOM \"linux/amd64\").SPDX.spdxVersion}} {{(index .SBOM \"linux/amd64\").SPDX.creationInfo.creators}}'; echo"

echo
echo "== 5. La procedencia de linux/amd64"
muestra "$INSPECT $IMG --format 'tipo: {{(index .Provenance \"linux/amd64\").SLSA.buildType}}{{println}}construida EN: {{(index .Provenance \"linux/amd64\").SLSA.invocation.environment.platform}}'; echo"
muestra "$INSPECT $IMG --format '{{range (index .Provenance \"linux/amd64\").SLSA.materials}}{{.uri}}{{println}}{{end}}' | cut -c1-100"
muestra "$INSPECT $IMG --format '{{json (index .Provenance \"linux/amd64\").SLSA.invocation.parameters.args}}'; echo"

echo
echo "== 6. Modo min contra modo max, con un argumento que el Dockerfile ni declara"
for modo in min max; do
  docker buildx build -q --platform linux/arm64 --build-arg VERSION=1.6.0 \
    --build-arg NOTA=curso-docker-nota-de-mentira --provenance=mode=$modo \
    -t "$REPO:fig10-$modo" --push . >/dev/null 2>&1
done
for modo in min max; do
  muestra "$INSPECT $REPO:fig10-$modo --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo"
  muestra "$INSPECT $REPO:fig10-$modo --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(\"campos:\", sorted(d)); print(\"secretos:\", d[\"invocation\"][\"parameters\"].get(\"secrets\", \"(no aparecen)\"))'"
done
muestra "$INSPECT $REPO:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys,base64; d=json.load(sys.stdin); i=d[\"metadata\"][\"https://mobyproject.org/buildkit@v1#metadata\"][\"source\"][\"infos\"][0]; print(i[\"filename\"]); print(\"\\n\".join(base64.b64decode(i[\"data\"]).decode().splitlines()[:3]))'"

echo
echo "== 7. Otra construcción idéntica: ¿qué digest cambia?"
muestra "docker buildx build -q --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t $IMG --push . >/dev/null 2>&1; echo \"construcción: código \$?\""
echo "antes:   índice ${INDICE}"
muestra "$INSPECT $IMG --format '{{json .Manifest.Digest}}'; echo"
muestra "$INSPECT $IMG --raw | python3 -c 'import json,sys; [print(m[\"platform\"][\"architecture\"], m[\"digest\"]) for m in json.load(sys.stdin)[\"manifests\"] if m[\"platform\"][\"os\"]==\"linux\"]'"
muestra "$INSPECT $IMG --format '{{(index .Provenance \"linux/amd64\").SLSA.metadata.buildStartedOn}}'; echo"

echo
echo "== 8. Y otra más, ahora SIN caché (--no-cache): ¿siguen iguales los de cada plataforma?"
muestra "docker buildx build -q --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t $IMG --push . >/dev/null 2>&1; echo \"construcción: código \$?\""
muestra "$INSPECT $IMG --raw | python3 -c 'import json,sys; [print(m[\"platform\"][\"architecture\"], m[\"digest\"]) for m in json.load(sys.stdin)[\"manifests\"] if m[\"platform\"][\"os\"]==\"linux\"]'"

echo
echo "== 9. Traerla por digest, no por etiqueta"
DIGEST="$($INSPECT "$IMG" --format '{{json .Manifest.Digest}}' | tr -d '"')"
# Como en un equipo que nunca construyó la imagen: se borra la copia local que
# dejó la construcción, y lo único que queda es lo que hay en el registro.
echo "(copias locales de $REPO que dejó la construcción)" | nombres
muestra "docker image ls $REPO --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'"
borra_copias
echo "(y después de borrarlas)"
muestra "docker image ls $REPO --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'"
muestra "docker pull -q $REPO@$DIGEST"
muestra "docker run --rm $REPO@$DIGEST version"
muestra "docker image inspect --format '{{json .RepoDigests}}' $REPO@$DIGEST; echo"

echo
echo "== 10. Lo que bajó a este equipo: solo su plataforma"
PROPIA="linux/$(uname -m | sed 's/aarch64/arm64/; s/x86_64/amd64/')"
OTRA="$( [ "$PROPIA" = linux/arm64 ] && echo linux/amd64 || echo linux/arm64 )"
muestra "docker image ls --tree $REPO@$DIGEST 2>/dev/null | sed -E 's/@sha256:([0-9a-f]{12})[0-9a-f]+/@sha256:\1…/'"
muestra "docker save --platform $PROPIA -o ../propia.tar $REPO@$DIGEST && echo 'guardada: $PROPIA'"
muestra "docker save --platform $OTRA -o ../otra.tar $REPO@$DIGEST"

echo
echo "== 11. Traer la OTRA plataforma, guardarla y probar a correrla ($OTRA)"
muestra "docker pull -q --platform $OTRA $REPO@$DIGEST"
muestra "docker save --platform $OTRA -o ../otra.tar $REPO@$DIGEST && echo 'guardada: $OTRA'"
muestra "docker run --rm --platform $OTRA $REPO@$DIGEST version 2>&1 | head -3"
