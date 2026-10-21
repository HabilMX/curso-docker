# syntax=docker/dockerfile:1
# fig04_01.Dockerfile — Lección 4: la misma imagen que la 3, ordenada para la caché.
FROM golang:1.27.3-trixie

WORKDIR /src

# Primero lo que casi nunca cambia (la descripción del módulo)...
COPY go.mod ./
# ...después el código, que cambia en cada edición.
COPY cmd/ cmd/
COPY internal/ internal/

# La caché de compilación de Go vive en un montaje de caché: sobrevive entre
# construcciones, acelera la siguiente y NO queda dentro de la imagen.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -o /usr/local/bin/revisor ./cmd/revisor

USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
