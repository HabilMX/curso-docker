# syntax=docker/dockerfile:1
# fig05_07.Dockerfile — Lección 5: el error a propósito: el mismo Dockerfile SIN CGO_ENABLED=0.

# --- Etapa 1: el código, sobre la imagen de Go (fijada por versión Y por digest) ---
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

# --- Etapa 2: las pruebas. Si fallan, la construcción se detiene aquí ---
FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

# --- Etapa 3: el binario, estático (CGO_ENABLED=0), sale DESPUÉS de las pruebas ---
FROM pruebas AS binario
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
