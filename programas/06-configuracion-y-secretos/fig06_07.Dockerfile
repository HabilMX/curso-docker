# syntax=docker/dockerfile:1
# fig06_07.Dockerfile — Lección 6: dónde vive un secreto de construcción.
# Solo para mirar: un RUN que recibe el secreto, lo cuenta y no lo imprime.
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
RUN --mount=type=secret,id=netrc,target=/root/.netrc,required=true \
    echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes" \
 && ls -l /root/.netrc
