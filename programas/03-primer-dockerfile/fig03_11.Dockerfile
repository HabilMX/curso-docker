# syntax=docker/dockerfile:1
# fig03_11.Dockerfile — Lección 3: el Dockerfile de la lección con USER ANTES del RUN.
# Existe solo para ver fallar la compilación (Solución 1): así NO se escribe.
FROM golang:1.27.3-trixie

WORKDIR /src
COPY . .
USER 10001:10001
RUN go build -o /usr/local/bin/revisor ./cmd/revisor

EXPOSE 8080
CMD ["revisor"]
