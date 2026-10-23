#!/usr/bin/env bash
# fig10_09.sh — El puente a Kubernetes con una imagen TRAÍDA DE UN REGISTRO por su
# digest (lo que harás en el curso siguiente si la bajas en vez de construirla):
# ¿la acepta `kind load docker-image`? Si no, ¿qué funciona?
#
# Usa un kubeconfig PROPIO en la carpeta de trabajo (no toca tu contexto de kubectl).
# Se corre donde viven kind y kubectl (la Mac del autor); en tu Mint es el mismo comando.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
P_REG="${P_REG:-5000}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
REGISTRO="${PREFIJO}registro-fig10"
REPO="localhost:${P_REG}/${PREFIJO}revisor"
CLUSTER="${PREFIJO}puente-fig10"
export KUBECONFIG="$TRABAJO/kubeconfig"
# Al salir se borra POR NOMBRE, nunca por identificador.
trap 'kind delete cluster --name "$CLUSTER" >/dev/null 2>&1
      docker rm -f -v "$REGISTRO" >/dev/null 2>&1
      docker images --digests --format "{{.Repository}}@{{.Digest}}" | grep "^$REPO@" | xargs -r docker rmi >/dev/null 2>&1
      docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$REPO:" | xargs -r docker rmi >/dev/null 2>&1
      docker rmi ${PREFIJO}revisor:fig10-registro >/dev/null 2>&1
      rm -rf "$TRABAJO"' EXIT
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
PLATAFORMA="linux/$(uname -m | sed 's/aarch64/arm64/; s/x86_64/amd64/')"
POD="kubectl run revisor --image=\$REF --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'"

echo "== 1. Una imagen de dos plataformas, publicada en el registro local"
docker run -d --name "$REGISTRO" -p "127.0.0.1:${P_REG}:5000" registry:3.1.2 >/dev/null
esperar_http "http://127.0.0.1:${P_REG}/v2/"
docker buildx build -q --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 -t "$REPO:1.6.0" --push . >/dev/null 2>&1
DIGEST="$(docker buildx imagetools inspect "$REPO:1.6.0" --format '{{json .Manifest.Digest}}' | tr -d '"')"
REF="$REPO@$DIGEST"
muestra "docker buildx imagetools inspect $REPO:1.6.0 --format '{{json .Manifest.Digest}}'; echo"
muestra "docker pull -q $REF"

echo
echo "== 2. Un clúster kind de un nodo"
muestra "kind create cluster --name $CLUSTER --wait 120s 2>&1 | grep -E '^Creating|Ready after|Set kubectl context' | sed -E 's/Ready after [0-9]+s/Ready after Ns/; s/ +[^ -~]+//g'"
muestra "kubectl config current-context"

echo
NODO="${CLUSTER}-control-plane"
echo "== 3. Cargar la imagen traída del registro, por su referencia con digest"
muestra "kind load docker-image $REF --name $CLUSTER"
muestra "docker exec $NODO crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120"

echo
echo "== 4. Guardarla con docker save y cargar el archivo"
muestra "docker save --platform $PLATAFORMA -o revisor.tar $REF && du -h revisor.tar | cut -f1"
muestra "kind load image-archive revisor.tar --name $CLUSTER"

echo
echo "== 5. ¿Qué nombres tiene la imagen dentro del nodo?"
muestra "docker exec $NODO crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120 | sed -E 's/([0-9a-f]{12})[0-9a-f]{52}/\\1…/g'"

echo
echo "== 6. Pedir el pod con la MISMA referencia con digest, sin descarga"
muestra "kubectl run revisor --image=$REF --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'"
muestra "kubectl wait --for=condition=Ready pod/revisor --timeout=60s"
muestra "kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason"

echo
echo "== 7. Una etiqueta local sobre la misma imagen, y cargar esa etiqueta"
muestra "kubectl delete pod revisor --wait=true"
muestra "docker tag $REF ${PREFIJO}revisor:fig10-registro"
muestra "kind load docker-image ${PREFIJO}revisor:fig10-registro --name $CLUSTER"
muestra "docker exec $NODO crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100"
muestra "kubectl run revisor --image=${PREFIJO}revisor:fig10-registro --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'"
muestra "kubectl wait --for=condition=Ready pod/revisor --timeout=60s"
muestra "kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image"
muestra "kubectl delete pod revisor --wait=true"

echo
echo "== 8. Traer solo el manifiesto de la plataforma (no el índice) y cargarlo"
MANIF="$(docker buildx imagetools inspect $REF --raw | python3 -c 'import json,sys; print([m["digest"] for m in json.load(sys.stdin)["manifests"] if m["platform"]["architecture"]=="'${PLATAFORMA#linux/}'" and m["platform"]["os"]=="linux"][0])')"
REF2="$REPO@$MANIF"
muestra "docker pull -q $REF2"
muestra "kind load docker-image $REF2 --name $CLUSTER"
muestra "docker exec $NODO crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100"
muestra "kubectl run revisor --image=$REF2 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'"
muestra "kubectl wait --for=condition=Ready pod/revisor --timeout=60s"

