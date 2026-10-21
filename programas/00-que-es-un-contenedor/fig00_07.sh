#!/usr/bin/env bash
# fig00_07.sh — El cliente y el daemon son dos programas distintos.
set -uo pipefail

echo "== Las dos versiones: la del cliente y la del daemon"
docker version --format 'cliente: {{.Client.Version}} ({{.Client.Os}}/{{.Client.Arch}})
daemon:  {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})'

echo
echo "== Por dónde habla el cliente con el daemon"
docker context inspect --format '{{.Endpoints.docker.Host}}'

echo
echo "== El cliente apuntando a un daemon que no existe"
DOCKER_HOST=unix:///tmp/curso-docker-no-hay-daemon.sock docker ps
echo "código de salida: $?"
