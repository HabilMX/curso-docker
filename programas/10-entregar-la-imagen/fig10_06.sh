#!/usr/bin/env bash
# fig10_06.sh — El puente a Kubernetes: un clúster kind de un nodo, la imagen
# cargada SIN registro, y el pod con imagePullPolicy: Never. Primero el error de
# pedir el pod antes de cargar la imagen; después, el arreglo.
#
# Usa un kubeconfig PROPIO en la carpeta de trabajo: no toca tu contexto de
# kubectl ni tu archivo ~/.kube/config. En tu equipo, al seguir la lección, kind
# sí cambia tu contexto a kind-curso-docker-puente (es lo que quieres ahí).
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig10»: el clúster curso-docker-puente-fig10 y la imagen
# curso-docker-revisor:fig10. Nunca toca tu clúster curso-docker-puente ni tu
# curso-docker-revisor:1.6.0, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig10.XXXXXX")"
CLUSTER="${PREFIJO}puente-fig10"
IMG="${PREFIJO}revisor:fig10"
export KUBECONFIG="$TRABAJO/kubeconfig"
trap 'kind delete cluster --name "$CLUSTER" >/dev/null 2>&1
      docker rmi -f "$IMG" >/dev/null 2>&1
      rm -rf "$TRABAJO"' EXIT

mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp "$AQUI/fig10_01.Dockerfile" "$TRABAJO/revisor/Dockerfile"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"

# Etiqueta propia al CONSTRUIR (no cambia el comando que se muestra): una imagen
# con exactamente el mismo contenido que otra tiene el mismo identificador, y quien
# borra una por identificador (docker rmi -f <id>) se lleva las dos. Con la etiqueta,
# el identificador de esta imagen es solo suyo. Útil cuando otras personas o
# guiones usan el mismo Docker; en tu equipo no cambia nada.
docker() {
  if [ "${1:-}" = build ]; then command docker build --label curso-docker.figura=fig10_06 "${@:2}"
  else command docker "$@"; fi
}
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g"; }
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# El pod del revisor: el mismo comando las dos veces.
POD="kubectl run revisor --image=$IMG --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'"

echo "== 1. Versiones"
muestra "kind version"
muestra "kubectl version --client | head -1"

echo
echo "== 2. La imagen, para la plataforma de este equipo"
muestra "docker build -q --build-arg VERSION=1.6.0 -t $IMG . >/dev/null && docker image ls $IMG --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

echo
echo "== 3. Un clúster kind de un nodo"
muestra "kind create cluster --name $CLUSTER --wait 120s 2>&1 | grep -E '^Creating|Ready after|Set kubectl context' | sed -E 's/Ready after [0-9]+s/Ready after Ns/; s/ +[^ -~]+//g'"
muestra "kubectl config current-context"

echo
echo "== 4. El error: el pod ANTES de cargar la imagen"
muestra "$POD"
sleep 8
muestra "kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason"
muestra "kubectl get events --field-selector involvedObject.name=revisor,reason=ErrImageNeverPull -o custom-columns=MENSAJE:.message | head -2 | cut -c1-110"
muestra "kubectl delete pod revisor --wait=true"

echo
echo "== 5. Cargar la imagen en el nodo (sin registro) y volver a pedir el pod"
muestra "kind load docker-image $IMG --name $CLUSTER"
muestra "docker exec ${CLUSTER}-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor' | cut -c1-100"
muestra "$POD"
muestra "kubectl wait --for=condition=Ready pod/revisor --timeout=90s"
muestra "kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image,REINICIOS:.status.containerStatuses[0].restartCount"
muestra "kubectl logs revisor"
muestra "kubectl get events --field-selector involvedObject.name=revisor -o custom-columns=RAZON:.reason,MENSAJE:.message | cut -c1-110"
