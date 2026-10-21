# Docker course — package a service and operate it the way it is really done

**By Dorian Chávez, founder of Hábil and integration architect.**

**Who it is for:** anyone who has already programmed something—the `revisor` from our [Go](https://www.habil.mx/en/courses/go/), [Rust](https://www.habil.mx/en/courses/rust/) or [TypeScript](https://www.habil.mx/en/courses/typescript/) courses, or a service of their own—and needs to package it, run it and operate it in containers without copying commands blindly. Intermediate level: it assumes you use a terminal comfortably and know what an HTTP server is. It does not assume you have touched Docker: every concept is explained as it comes up, along with why it exists, not only how it is written. And there is no need to program anything new: the course hands you the service ready-made.

**What you will know by the end:** how to turn a service into a small, unprivileged and reproducible image; run it with limits, with a health check and with graceful shutdown; manage its configuration and its secrets without leaving them inside the image; bring up several containers that talk to each other by name with a single command; and read what Docker tells you when something fails, instead of looking for the answer blindly.

**Where it goes next:** this course is the step before our [**Kubernetes with kind** course](https://www.habil.mx/en/courses/kubernetes/), which takes the image you finish with here and deploys it, configures it, scales it and protects it in a local cluster.

**What you need before you start:** a computer with Linux Mint 22.x and administrator permission (`sudo`). [Lesson 1](01-instalacion.md) installs Docker from scratch. If you come from the Go, Rust or TypeScript course, you already know the problem the `revisor` solves; if not, lesson 0 introduces it in two paragraphs.

## The project you will build

The **`revisor`**: an HTTP server that queries a list of services **at once** and delivers, over `GET /api/estados`, a report with the name, the status and the response time of each one; and over `GET /salud`, the short response that says whether the process itself is alive. It is configured with environment variables (the port, the list of services, the path where it saves the report and an access token). The `revisor` server is written in **Go** (it comes from our Go course) and compiles to a static binary; it listens on port 8080, serves `GET /salud` and `GET /api/estados`, is configured through environment variables and comes with a `healthcheck` subcommand so it can check itself without `curl`. You do not need to know Go: the course hands it to you and you package it.

The course hands it to you ready-made, together with a **test service that fails on purpose** in three modes: healthy, slow and down. With those two pieces you do all the work of the course: package, harden, configure, add health checks, save data, connect and deliver. It is the same problem as in our Go, Rust and TypeScript courses: you already know what the `revisor` does, so all your attention stays on what is new, which is **how it is shipped and how it is operated**.

## The eleven lessons

| Lesson | | What you build | What you learn |
|---|---|---|---|
| 0 | [What a container is and what it is NOT](00-que-es-un-contenedor.md) | nothing yet (reading) | a container is an isolated process, not a virtual machine; image versus container; the client and the daemon; what is shared with the host and why that determines security |
| 1 | [Installing Docker on your Linux Mint](01-instalacion.md) | the environment and your first container | Docker Engine from the official repository; Mint is not an official platform and what to do; removing conflicting packages; the `docker` group is equivalent to `root` |
| 2 | [Containers day to day](02-contenedores-dia-a-dia.md) | the test service running, queried and clean | `run`, `ps`, `logs`, `exec`, `stop`, `rm`, `inspect`; publishing ports only on `127.0.0.1`; memory and CPU limits; leaving nothing behind |
| 3 | [Your first Dockerfile](03-primer-dockerfile.md) | `curso-docker-revisor:1.x.0` in a single stage | Dockerfile instructions; *exec* form versus *shell* form; `.dockerignore`; `USER`; versioned tags; `docker build --check` |
| 4 | [Layers, cache and context](04-capas-cache-contexto.md) | the same image, rebuilt in seconds | how an image is put together layer by layer; the order of instructions; `--progress=plain` and `docker history`; build cache (`--mount=type=cache`); what gets sent in the build context |
| 5 | [Multi-stage: from gigabytes to megabytes](05-multi-stage.md) | the minimal, unprivileged final image | build, test and final stages; minimal base without a shell; version and *digest* of the base; the binary that does not start because it is not static |
| 6 | [Configuration and secrets](06-configuracion-y-secretos.md) | the `revisor` configured without rebuilding | environment variables; `ARG` versus `ENV`; build secrets; runtime secrets via file; seeing with your own eyes what stays inside the image |
| 7 | [Health checks and lifecycle](07-salud-y-ciclo-de-vida.md) | a container that reports its own health and shuts down cleanly | PID 1 and signals; the `docker stop` grace period; `HEALTHCHECK` without `curl`; restart policies; read-only file system; `--cap-drop`; `no-new-privileges` |
| 8 | [Volumes and networks](08-volumenes-y-redes.md) | the report that survives and two containers that talk to each other | named volumes, *bind mounts* and `tmpfs`; file ownership with an unprivileged user; user-defined networks; DNS by name; internal networks |
| 9 | [Compose: the complete system](09-compose.md) | `compose.yaml` with the `revisor` and its failing service | services, networks, volumes and secrets in one file; `depends_on` with `service_healthy`; `compose config`; comparing your file with the one from `docker init` |
| 10 | [Delivering the image](10-entregar-la-imagen.md) | the image published, verified and ready for Kubernetes | tags and *digest*; local registry; vulnerability scanning with Trivy; bill of materials (SBOM) and provenance; multiple platforms; the bridge to `kind load docker-image` |

**Prefixed names.** Everything the course creates on your machine (images, containers, networks, volumes) carries the `curso-docker-` prefix; that is why the image from lesson 3 is called `curso-docker-revisor:1.x.0` and not `revisor`. That way it does not clash with anything you already have, and you can delete only what the course created without touching the rest.

At the end of each lesson there are exercises with their solutions. And the [logbook](bitacora.md) is yours: write down there what was hard for you.

## Three principles that run through the whole course

**Security is not a lesson, it is a habit.** There is no final security module. There is one habit per lesson, and each one is practiced on the `revisor` and not in a separate example:

| Lesson | The habit that gets built |
|---|---|
| 0 | knowing what a container shares with the machine (the kernel) and what it does not |
| 1 | the `docker` group is equivalent to `root`: membership is granted deliberately |
| 2 | ports published only on `127.0.0.1`; memory and CPU limits; never `--privileged` or the Docker *socket* inside a container |
| 3 | the first Dockerfile already has `USER`; `.dockerignore` from day one; versioned tags, never `latest` |
| 4 | the build context does not carry `.git`, `.env` or keys; the Dockerfile check tool is always run |
| 5 | minimal base without a shell; the base is pinned by version and by *digest*; the test stage runs before packaging |
| 6 | secrets do not go through `ARG` or `ENV`; you check with `docker history` and `docker inspect` that none were left behind |
| 7 | read-only file system, without unused capabilities, without privilege escalation, with an `init` |
| 8 | volumes with the right owner; internal networks; never the host network |
| 9 | the final `compose.yaml` includes all of the above from the start, and its secrets live outside the file |
| 10 | what gets published is scanned, ships with its bill of materials and is referenced by *digest* |

A topic left for the end is a topic that does not get learned.

**A “running” container is not a healthy service.** Almost every operational failure in this field comes from confusing the two things: the process exists, but it is not serving. The test service fails on purpose and each lesson teaches you to tell **what Docker believes from what is really happening**.

**Only what is current is taught, and what is obsolete is named so you can recognize it.** Compose is `docker compose` (the *plugin*), the file is called `compose.yaml` and has no `version:`; `MAINTAINER` is deprecated. When something old shows up in a tutorial that you will run into anyway, the course tells you what it is and why it is no longer used. And every version is given with its date: the ones in this course were measured on October 7, 2026 (Docker Engine 29.8.2, Compose v5.6.0).

## How you know you are done

The course does not end when you have read lesson 10, but when your project meets these six things. The numbers are design targets: they are measured and adjusted as the lessons are written, and each lesson repeats its own once measured.

1. **`docker compose up` brings everything up from scratch** and the report shows the down test service as `FALLA`, without your having to restart anything by hand.
2. **The final image weighs tens of megabytes** (target), not hundreds, contains neither a shell nor a compiler, and **does not run as `root`** (you check it with `docker exec` and with `docker inspect`).
3. **No secret appears** in `docker history`, in `docker inspect` or in the container's environment variables.
4. **`docker stop` stops the container in a few seconds** (target: under two), because the process receives the signal and shuts down gracefully; and `docker ps` shows `(healthy)` and, when you break the service, `(unhealthy)`.
5. **The report survives `docker rm`** and the `revisor` finds the other container by its name.
6. **The published image is referenced by *digest***, passes the Trivy scan with the threshold you set and loads into a `kind` cluster without a single download error.
