#!/usr/bin/env bash
# fig10_02.sh — Un registro local y la diferencia entre etiqueta y digest:
# publicar, volver a publicar con la MISMA etiqueta, y comprobar que la etiqueta
# se movió y el digest no. Después, correr la imagen traída por digest, endurecida.
# Una sola plataforma (la de tu equipo); las dos plataformas son de fig10_04.sh.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig10»: el registro se llama curso-docker-registro-fig10 y
# la imagen se etiqueta «fig10». Así el guion nunca toca tu registro
# curso-docker-registro ni tu curso-docker-revisor:1.6.0, y al salir borra solo
# lo que creó (el registro CON su volumen anónimo: -v).
P_REG="${P_REG:-5000}"    # puerto del registro en tu equipo
P_REV="${P_REV:-8080}"    # puerto del revisor en tu equipo
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
REGISTRO="${PREFIJO}registro-fig10"
REPO="localhost:${P_REG}/${PREFIJO}revisor"
VOLUMEN="${PREFIJO}reportes-fig10"
# Al salir se borra POR NOMBRE (el registro con su volumen anónimo: -v), nunca por identificador.
trap 'docker rm -f -v "$REGISTRO" "${PREFIJO}revisor-fig10" >/dev/null 2>&1
      docker volume rm "$VOLUMEN" >/dev/null 2>&1
      docker rmi "$REPO:fig10" >/dev/null 2>&1
      docker images --digests --format "{{.Repository}}@{{.Digest}}" | grep "^$REPO@" | xargs -r docker rmi >/dev/null 2>&1
      rm -rf "$TRABAJO"' EXIT
# ocupado PUERTO: ¿ya contesta algo en 127.0.0.1:PUERTO? (por ejemplo, TU registro
# curso-docker-registro). Si sí, el guion para: empujaría a un registro que no es el suyo.
ocupado() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
# Etiqueta propia al CONSTRUIR (no cambia el comando que se muestra). Una imagen con
# exactamente el mismo contenido que otra tiene el mismo identificador, y quien borra
# por identificador (docker rmi -f <id>) se lleva todos sus nombres. Con la etiqueta, el
# identificador de lo que construye este guion es solo suyo, y al salir se borra POR NOMBRE.
docker() {
  case "${1:-} ${2:-}" in
    "build "*|"build") command docker build --label curso-docker.figura=fig10_02 "${@:2}" ;;
    *) command docker "$@" ;;
  esac
}
for p in "$P_REG" "$P_REV"; do
  ocupado "$p" && { echo "El puerto $p ya está en uso (¿tu registro?). Corre con otros: P_REG=… P_REV=…" >&2; exit 1; }
done

# El proyecto: el código que entrega el curso y el estado final de esta lección.
mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp "$AQUI/fig10_01.Dockerfile" "$TRABAJO/revisor/Dockerfile"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"

# Si corres el guion con otro PREFIJO o con otros puertos, la salida se escribe
# con los del curso. Con los valores por omisión esto no cambia nada.
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g" -e "s/localhost:${P_REG}\//localhost:5000\//g" \
                -e "s/127.0.0.1:${P_REG}/127.0.0.1:5000/g" -e "s/127.0.0.1:${P_REV}/127.0.0.1:8080/g"; }
# muestra COMANDO: lo imprime con «$ », lo corre y dice el código si no fue 0
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# esperar_http URL: hasta 20 s a que responda
esperar_http() { for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done; echo "(no respondió $1)"; }
# digest REF: el digest del índice que guarda el registro para esa referencia
digest() { docker buildx imagetools inspect "$1" --format '{{json .Manifest.Digest}}' | tr -d '"'; }

echo "== 1. Un registro local, publicado solo en 127.0.0.1"
muestra "docker run -d --name $REGISTRO -p 127.0.0.1:${P_REG}:5000 registry:3.1.2 >/dev/null && echo registro arriba"
esperar_http "http://127.0.0.1:${P_REG}/v2/"
muestra "curl -s http://127.0.0.1:${P_REG}/v2/_catalog"
muestra "docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'"

echo
echo "== 2. Construir la 1.6.0 y publicarla con la etiqueta fig10"
muestra "docker build -q --build-arg VERSION=1.6.0 -t $REPO:fig10 . >/dev/null && docker push -q $REPO:fig10"
PRIMERO="$(digest "$REPO:fig10")"
muestra "docker buildx imagetools inspect $REPO:fig10 --format '{{json .Manifest.Digest}}'; echo"
muestra "curl -s http://127.0.0.1:${P_REG}/v2/_catalog; curl -s http://127.0.0.1:${P_REG}/v2/${PREFIJO}revisor/tags/list"

echo
echo "== 3. Otra construcción (VERSION=1.6.1) con la MISMA etiqueta"
muestra "docker build -q --build-arg VERSION=1.6.1 -t $REPO:fig10 . >/dev/null && docker push -q $REPO:fig10"
muestra "docker buildx imagetools inspect $REPO:fig10 --format '{{json .Manifest.Digest}}'; echo"
muestra "curl -s http://127.0.0.1:${P_REG}/v2/${PREFIJO}revisor/tags/list"

echo
echo "== 4. Lo que trae cada referencia"
echo "(la copia local que dejó la construcción)"
muestra "docker image ls $REPO --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'"
docker rmi "$REPO:fig10" >/dev/null 2>&1
echo "(y después de borrarla)"
muestra "docker image ls $REPO --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'"
muestra "docker pull -q $REPO:fig10 && docker run --rm $REPO:fig10 version"
muestra "docker pull -q $REPO@$PRIMERO && docker run --rm $REPO@$PRIMERO version"

echo
echo "== 5. La de digest, endurecida como en la Lección 8: sin nada en /datos"
CORRE="docker run -d --name ${PREFIJO}revisor-fig10 -p 127.0.0.1:${P_REV}:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init"
muestra "$CORRE -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' $REPO@$PRIMERO >/dev/null && echo 'contenedor arriba'"
esperar_http "http://127.0.0.1:${P_REV}/salud"
muestra "curl -s http://127.0.0.1:${P_REV}/salud"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${P_REV}/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'"

echo
echo "== 6. La misma, con un volumen en /datos (un contenedor no recibe un volumen después: se borra y se crea otro)"
muestra "docker rm -f ${PREFIJO}revisor-fig10 >/dev/null && echo 'contenedor anterior borrado'"
muestra "$CORRE -v $VOLUMEN:/datos -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' $REPO@$PRIMERO >/dev/null && echo 'contenedor arriba'"
esperar_http "http://127.0.0.1:${P_REV}/salud"
muestra "curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:${P_REV}/api/estados"
muestra "docker inspect --format '{{.Config.Image}}' ${PREFIJO}revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'"
