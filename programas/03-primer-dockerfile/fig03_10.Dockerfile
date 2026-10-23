# ASÍ NO — seis problemas a propósito (Ejercicio 4 de la Lección 3).
FROM golang
MAINTAINER alguien@ejemplo.invalid
COPY . /src
RUN cd /src && go build -o /usr/local/bin/revisor ./cmd/revisor
EXPOSE 8080
CMD revisor
