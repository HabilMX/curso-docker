#!/usr/bin/env bash
# fig01_05.sh — Las comprobaciones al terminar la instalación.
# Córrelo SIN sudo, después de entrar al grupo docker (sección 1.8).
set -uo pipefail

echo "== 1. El servicio: ¿corre ahora y arrancará con el equipo?"
systemctl is-active docker
systemctl is-enabled docker

echo
echo "== 2. Los cinco paquetes instalados"
dpkg-query -W -f='${Package} ${Version}\n' \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo
echo "== 3. Versiones"
docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}  API: {{.Server.APIVersion}}'
docker compose version
docker buildx version | cut -d' ' -f1,2

echo
echo "== 4. El primer contenedor"
docker run --rm --name curso-docker-hola hello-world

echo
echo "== 5. El socket: dueño root, grupo docker"
ls -l /var/run/docker.sock | awk '{print $1, $3, $4, $NF}'

echo
echo "== 6. Basura: contenedores curso-docker- que quedaron"
docker ps -a --filter name=curso-docker- --format '{{.Names}}' | wc -l
