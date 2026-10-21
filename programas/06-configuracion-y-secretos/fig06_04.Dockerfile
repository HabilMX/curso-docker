# syntax=docker/dockerfile:1
# fig06_04.Dockerfile — Lección 6: ASÍ NO. Dos formas de dejar un secreto dentro de la imagen.
# (Una sola etapa, como en la Lección 4, para que todo quede a la vista.)
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/
# Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
# aunque el RUN borre el archivo al final.
ARG TOKEN_MODULOS
RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
 && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
 && rm /root/.netrc
# Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
USER 10001:10001
CMD ["revisor"]
