#!/usr/bin/env bash
# fig05_05.sh — Una prueba rota detiene la construcción... si el Dockerfile la
# pone en el camino. Agrega una prueba que falla a propósito y construye dos
# veces: con el Dockerfile de la lección y con una variante donde la etapa
# «binario» sale de «compilacion» en vez de «pruebas». Borra lo que crea.
set -uo pipefail
# PREFIJO cambia el principio de todos los nombres (imágenes, contenedores y la
# caché de compilación). Con el valor por omisión, el guion usa los nombres del
# curso; otro valor sirve para que dos corridas en la misma máquina no choquen.
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# La variante equivocada: un solo renglón distinto.
sed 's/^FROM pruebas AS binario/FROM compilacion AS binario/' Dockerfile > Dockerfile.salta-pruebas

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
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
ROTA="${PREFIJO}revisor:rota"
trap 'docker rmi -f "$ROTA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

cat > cmd/revisor/rota_test.go <<'GO'
package main

import "testing"

func TestRotaAProposito(t *testing.T) { t.Fatal("esta prueba falla a propósito") }
GO

titulo "Con el Dockerfile de la lección"
muestra "docker build --progress=plain -t $ROTA . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit \${PIPESTATUS[0]})"
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Con la variante: binario sale de compilacion"
muestra "diff Dockerfile Dockerfile.salta-pruebas"
muestra "docker build --progress=plain -t $ROTA -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo \"construcción: código \${PIPESTATUS[0]}\""
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
