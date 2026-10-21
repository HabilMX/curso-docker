# syntax=docker/dockerfile:1
# El servicio de prueba del curso. Te lo entregamos hecho: en la Lección 2 solo
# lo construyes con un comando, y en las Lecciones 3 a 5 aprendes a leer cada
# renglón de este archivo.
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/servicio-prueba .

FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087
COPY --from=compilacion /out/servicio-prueba /servicio-prueba
USER 65532:65532
EXPOSE 9000
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=2 CMD ["/servicio-prueba", "healthcheck"]
ENTRYPOINT ["/servicio-prueba"]
