#!/usr/bin/env bash
# fig10_07.sh — Las soluciones medidas de los Ejercicios 2 y 3: ¿hay un digest
# nuevo de la base?, y aceptar un hallazgo de Trivy por escrito, con su razón,
# en un .trivyignore (y ver que solo calla ESE hallazgo).
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
IMG="${PREFIJO}revisor:fig10"
CACHE="${PREFIJO}trivy-cache-fig10"
trap 'docker rmi "$IMG" >/dev/null 2>&1
      docker volume rm "$CACHE" >/dev/null 2>&1
      rm -rf "$TRABAJO"' EXIT

mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp "$AQUI/fig10_01.Dockerfile" "$TRABAJO/revisor/Dockerfile"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"

# Etiqueta propia al CONSTRUIR (no cambia el comando que se muestra). Una imagen con
# exactamente el mismo contenido que otra tiene el mismo identificador, y quien borra
# por identificador (docker rmi -f <id>) se lleva todos sus nombres. Con la etiqueta, el
# identificador de lo que construye este guion es solo suyo, y al salir se borra POR NOMBRE.
docker() {
  case "${1:-}" in
    build) command docker build --label curso-docker.figura=fig10_07 "${@:2}" ;;
    *) command docker "$@" ;;
  esac
}
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g"; }
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
sin_fechas() { grep -vE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'; }
PLATAFORMA="linux/$(uname -m | sed 's/aarch64/arm64/; s/x86_64/amd64/')"
TRIVY="docker run --rm -v $CACHE:/root/.cache -v \"\$PWD\":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar"

echo "== Ejercicio 2. ¿Qué digest tiene HOY la etiqueta nonroot de la base?"
muestra "grep -oE 'static-debian13:nonroot@sha256:[0-9a-f]{12}' Dockerfile"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot --format '{{json .Manifest.Digest}}' | cut -c2-20"
FIJO="$(grep -oE 'static-debian13:nonroot@sha256:[0-9a-f]{64}' Dockerfile | cut -d@ -f2)"
echo "(y el digest que fija el Dockerfile, ¿sigue existiendo en el registro?)"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13@$FIJO --format '{{json .Manifest.Digest}}' | cut -c2-20"

echo
echo "== Ejercicio 3. Aceptar el hallazgo por escrito, con razón y fecha"
docker build -q --build-arg VERSION=1.6.0 -t "$IMG" . >/dev/null
docker save --platform "$PLATAFORMA" -o revisor-1.6.0.tar "$IMG"
docker volume create "$CACHE" >/dev/null
cat > .trivyignore <<'EOF'
# ca-certificates 20250419 en la base distroless fijada por digest.
# Debian ya lo corrigió (20250419+deb13u1); el arreglo llega al renovar el
# digest de la base (Ejercicio 4). Mientras tanto se acepta, por escrito.
# Revisado el 21-oct-2026. Borrar esta línea al renovar la base.
DSA-6572-1
EOF
muestra "cat .trivyignore"
muestra "{ $TRIVY --exit-code 1 2>&1; echo \"código de Trivy: \$?\"; } | sin_fechas | grep -E '^Total|^código|tar \\(' | sed 's#/trabajo/#./#'"
muestra "{ $TRIVY --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo \"código de Trivy: \$?\"; } | sin_fechas | grep -E '^Total|^código|tar \\(' | sed 's#/trabajo/#./#'"
echo "(el mismo archivo, con un identificador que NO es el del hallazgo)"
muestra "sed -i.orig 's/^DSA-6572-1\$/DSA-0000-1/' .trivyignore && tail -1 .trivyignore"
muestra "{ $TRIVY --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo \"código de Trivy: \$?\"; } | sin_fechas | grep -E '^Total|^código|tar \\(' | sed 's#/trabajo/#./#'"

echo
echo "== Ejercicio 3 (continuación). La fecha que Trivy SÍ hace cumplir: exp:"
muestra "sed -i.orig 's/^DSA-0000-1\$/DSA-6572-1 exp:2026-11-21/' .trivyignore"
muestra "tail -1 .trivyignore"
muestra "{ $TRIVY --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo \"código de Trivy: \$?\"; } | sin_fechas | grep -E '^Total|^código|tar \\(' | sed 's#/trabajo/#./#'"
echo "(la misma línea, con una fecha que ya pasó)"
muestra "sed -i.orig 's/exp:2026-11-21/exp:2026-01-01/' .trivyignore"
muestra "tail -1 .trivyignore"
muestra "{ $TRIVY --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo \"código de Trivy: \$?\"; } | sin_fechas | grep -E '^Total|^código|tar \\(' | sed 's#/trabajo/#./#'"
