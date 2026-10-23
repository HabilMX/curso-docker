# Lesson 5 — Multi-stage: from gigabytes to megabytes

It is 7:50 in the morning and the branch opens at 9. The `revisor` has to be installed before then on the server in the communications room, which connects to the rest of the world over a modest link. You start downloading the image and the progress bar crawls along drop by drop: the image weighs 1.32 GB. While you wait, a message arrives from the security person who reviews every installation: "Before you start it, can you explain why that image has `gcc`, `git`, `curl`, `apt-get`, and a *shell*? The `revisor` is a single program. If someone manages to get into that container, you are leaving them a fully equipped workshop: something to download tools with, something to compile them with, and something to run them with." You have forty minutes and two problems that seem different: the image is huge and the image is dangerous. This lesson teaches you that they are the same problem, and that it is fixed with a single, better-written Dockerfile: the image that comes out of here weighs 16.1 MB, has no *shell*, and does not run as `root`.

**Time:** 2 × 45 min

**What you build:** the final image of the `revisor`, `curso-docker-revisor:1.2.0`: a four-stage Dockerfile that compiles and tests in a large image and delivers in a minimal one, with the base pinned by version and by *digest*. It weighs 16.1 MB, has neither a *shell* nor a compiler, and runs as the unprivileged user 65532.

**What you learn:** what a multi-stage build is and how files are passed from one stage to another with `COPY --from`; how to put the tests inside the build so that a broken test stops it, and the silent error that skips them; what a minimal base image without a *shell* (*distroless*) is and what changes when operating it; what a *digest* is and why the base is pinned with it in addition to the tag; and why a binary that is not static does not start in a minimal image, with the exact message you are going to see.

**Where you are coming from.** From [Lesson 4](04-capas-cache-contexto.md) you bring the image `curso-docker-revisor:1.1.0`: the same `revisor` from Lesson 3, but with the Dockerfile ordered for the cache (first `go.mod`, then the code) and with Go's compilation cache in a mount that does not stay inside the image. You know how to read `docker history`, you know what a layer is and what travels in the context. You also bring a number written in your logbook: that image weighs **1.32 GB**. From [Lesson 3](03-primer-dockerfile.md) you bring `USER`, the *exec* form, and the `~/curso-docker/revisor` folder, where your project lives. And from [Lesson 2](02-contenedores-dia-a-dia.md) you bring a memory: you tried to get into the test service with `docker exec` and there was no `sh`. Here you are going to understand why, and you are going to do the same to the `revisor`.

**What this lesson does not do.** It does not touch the `revisor`'s code or add features to it: the program is the same as in Lessons 3 and 4. It does not stamp a version on the binary (which is why `revisor version` still says `desarrollo`; versioning and configuration belong to [Lesson 6](06-configuracion-y-secretos.md)). It does not add a `HEALTHCHECK` or harden it at run time (read-only file system, capabilities dropped): that is Lesson 7. And it does not build for multiple platforms or scan for vulnerabilities: that is Lesson 10. Here the job is just one: that what is **delivered** is only what is **needed to run**.

**About the runs.** All outputs are real and were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4, the same base as Linux Mint 22, the course's reference system. The scripts were run **inside** that virtual machine, with Docker 29.2.1 (client and daemon) and Buildx v0.31.1. The course was planned with Docker Engine 29.8.2, and the most recent version published that day was 29.9.2, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)); nothing in this lesson changes between those versions. The same machine was being used at the same time by other runs of the course, so, to avoid collisions, each script was launched with a different name prefix and a different port, using the `PREFIJO` and `PUERTO` variables they all have, and the output was saved by passing it through a `sed` that restores the course's names. The command was, for each figure: `PREFIJO=curso-docker-l05- PUERTO=18050 ./fig05_NN.sh 2>&1 | sed -e 's/curso-docker-l05-/curso-docker-/g' -e 's/127\.0\.0\.1:18050/127.0.0.1:8080/g'`. You do not need any of that: without variables, the scripts use the course's names and port, and what they print is what you see here. What **does** change on your Mint, and is flagged where it appears: the process numbers (PIDs), the times, the file dates and, if your machine is Intel or AMD, the architecture: where it says `arm64` or `aarch64` here, yours will say `amd64` or `x86_64`, and sizes may vary by a few megabytes. The programs are in [`programas/05-multi-stage/`](../programas/05-multi-stage), each with its output next to it; `inicio/` holds the `Dockerfile` and `.dockerignore` Lesson 4 ends with, and `estado/`, the ones you have at the end of this one.

## By the end you will be able to

- Explain, with the numbers from your own image, why a single-stage image weighs more than a gigabyte when the program it carries weighs less than ten megabytes.
- Write a Dockerfile with several named stages (`FROM ... AS`), pass a file from one stage to another with `COPY --from`, and build only up to a stage with `--target`.
- Put the tests inside the build so that a broken test stops it, and show with a run why the binary stage must come from the test stage and not from the compilation stage.
- Show with `docker exec`, `docker inspect`, and `docker top` that the final image has no *shell* and does not run as `root`, and list all its files without getting into it.
- Pin a base image by tag and by *digest*, and say what each one ensures.
- Read the message `exec /revisor: no such file or directory`, explain which file is the one missing, and fix it with `CGO_ENABLED=0`.

## The why before the how

In Lesson 3 you built the `revisor` in a single stage: you started from the Go image, copied the code, compiled, and told Docker what to run. It works, and it was the right way to start because everything was in plain view. But that recipe has a design flaw that no reordering fixes: **the image used to build and the image that is delivered are the same**. Everything that was needed to compile—the Go compiler, the C compiler, a full Debian with its package manager, the networking tools—stays inside the image that goes to the server, even though the `revisor` uses none of it at run time.

That costs in three places at once, and the opening scene brings them together:

1. **In time and disk space.** Every server that runs the `revisor` downloads and stores more than a gigabyte. On a slow link, that is the difference between making it by 9 or not.
2. **In security.** Every program that travels in the image is something an intruder can use. A container with a *shell*, `curl`, and a compiler saves whoever gets in almost all the work. A container that has only the `revisor` leaves them nothing to continue with.
3. **In noise.** A vulnerability scanner checks every package in the image. If the image brings two hundred Debian packages that the `revisor` never touches, the report fills up with findings that do not matter and hides the ones that do. Google's own minimal-images project puts it this way: an image without the extras "improves the signal to noise of scanners" ([distroless](https://github.com/GoogleContainerTools/distroless)).

The solution you are going to build separates the two jobs: a large image to **build and test**, which never leaves your machine, and a minimal image to **run**, which is the one that is delivered. Both are described in the same Dockerfile, and going from one to the other is a single line: copying the binary. Docker's documentation sums it up in one sentence: with multi-stage builds "you can selectively copy artifacts from one stage to another, leaving behind everything you don't want in the final image" ([Docker, "Multi-stage builds"](https://docs.docker.com/build/building/multi-stage/)).

The lesson has eight parts, in this order:

1. **What is inside 1.32 GB** (5.1): measuring before shrinking.
2. **The idea of stages** (5.2): `FROM ... AS`, `COPY --from`, and `--target`.
3. **The four-stage Dockerfile** (5.3), line by line.
4. **Building and measuring** (5.4): from 1.32 GB to 16.1 MB.
5. **Tests inside the build** (5.5), with this lesson's silent error.
6. **The minimal base** (5.6): no *shell* and no `root`.
7. **Version and *digest*** (5.7): truly pinning the base.
8. **The binary that does not start** (5.8), the lesson's main error.

With that destination in mind, this is what you will see in section 5.4, when you put the image you arrive with side by side with the one you build here:

```text
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB
```

## The concepts

### 5.1 What is inside 1.32 GB

#### 5.1.1 Measure before shrinking

Before changing a single line, it is worth knowing what is in the image and how much of that weight is the `revisor`. Shrinking without measuring is guessing. The program `fig05_01.sh` builds Lesson 4's image from `inicio/` and asks it three things: how much the `revisor` weighs, what other tools travel with it, and how much space the heaviest directories take up:

```bash
#!/usr/bin/env bash
# fig05_01.sh — Qué hay dentro de la imagen con la que termina la Lección 4.
# La construye desde inicio/ (el Dockerfile y el .dockerignore de la Lección 4),
# mide su tamaño y busca adentro lo que el revisor necesita para correr y lo que
# no. Borra lo que crea al salir.
set -euo pipefail
# PREFIJO cambia el principio de todos los nombres (imágenes, contenedores y la
# caché de compilación). Con el valor por omisión, el guion usa los nombres del
# curso; otro valor sirve para que dos corridas en la misma máquina no choquen.
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/inicio/Dockerfile" "$AQUI/inicio/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

titulo() { printf '\n## %s\n' "$*"; }
# muestra: imprime el comando con «$ » y lo ejecuta (salida y error juntos)
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
IMAGEN="${PREFIJO}revisor:1.1.0"
MIRAR="docker run --rm --name ${PREFIJO}mirar $IMAGEN"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "La imagen de la Lección 4"
muestra "docker build -q -t $IMAGEN . >/dev/null && docker image ls $IMAGEN --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Lo único que el revisor necesita para correr"
muestra "$MIRAR ls -lh /usr/local/bin/revisor"

titulo "Lo demás que viaja con él"
muestra "$MIRAR sh -c 'for p in sh bash apt-get gcc go git curl; do printf \"%-8s %s\n\" \$p \"\$(command -v \$p || echo no-esta)\"; done'"
muestra "$MIRAR du -sh /usr/local/go /usr/lib /usr/bin /usr/share"
muestra "$MIRAR sh -c 'dpkg-query -W | wc -l'"
muestra "$MIRAR id"
```

Before the output, the script's new lines. The structure is the same as Lesson 3's scripts: the project is assembled in a temporary folder (`mktemp -d`) with the code the course delivers plus the lesson's files, the helpers `titulo` and `muestra` are defined (the latter prints each command with `$ ` in front before running it, so you know what produced each line), and a `trap ... EXIT` deletes the image and the folder on exit. The `sed` at the beginning changes the compilation cache's name only if you change the `PREFIJO`; with the default value, it changes nothing. `MIRAR` is a shorthand so as not to repeat `docker run --rm --name ... image` in every question.

```text
$ ./fig05_01.sh

## La imagen de la Lección 4
$ docker build -q -t curso-docker-revisor:1.1.0 . >/dev/null && docker image ls curso-docker-revisor:1.1.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.1.0 1.32GB

## Lo único que el revisor necesita para correr
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 ls -lh /usr/local/bin/revisor
-rwxr-xr-x 1 root root 9.5M Oct 21 08:46 /usr/local/bin/revisor

## Lo demás que viaja con él
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 sh -c 'for p in sh bash apt-get gcc go git curl; do printf "%-8s %s\n" $p "$(command -v $p || echo no-esta)"; done'
sh       /usr/bin/sh
bash     /usr/bin/bash
apt-get  /usr/bin/apt-get
gcc      /usr/bin/gcc
go       /usr/local/go/bin/go
git      /usr/bin/git
curl     /usr/bin/curl
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 du -sh /usr/local/go /usr/lib /usr/bin /usr/share
277M	/usr/local/go
276M	/usr/lib
120M	/usr/bin
140M	/usr/share
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 sh -c 'dpkg-query -W | wc -l'
208
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 id
uid=10001 gid=10001 groups=10001
```

The file's date and time change on every build; on an Intel or AMD machine the sizes may vary by a few megabytes. The rest comes out the same.

#### 5.1.2 Reading the numbers

Put the numbers in a single sentence and the problem becomes obvious: **the `revisor` weighs about 10 MB and travels in a 1.32 GB image**. Less than one percent of what is downloaded is the program you are going to run. The remaining 99 % is baggage:

- **The Go compiler**, in `/usr/local/go`: 277 MB. (`ls -lh` and `du -sh` count in powers of 1024: the `revisor`'s `9.5M` is 9.5 MiB, about 10 MB; `docker image ls` counts in powers of 1000.) It was needed to compile; at run time, the `revisor` does not use it even once.
- **An almost complete Debian**: 208 installed packages (`dpkg-query -W` lists one per line and `wc -l` counts them), with their libraries in `/usr/lib` and their programs in `/usr/bin`.
- **The tools that worried the security person in the opening scene**: a *shell* (`sh` and `bash`), a package manager (`apt-get`), a C compiler (`gcc`), `git`, and `curl`. Each one is there for a good reason for **building**: the official Go image ships them so that compiling works with almost any project. For **running** the `revisor`, none of them.

The last line is a good reminder that Lesson 3 was not in vain: the image runs as user `10001`, not as `root`. But that user has `curl` at hand to download whatever it wants and `sh` to run it. Unprivileged, yes; unarmed, no.

Notice also what is **not** on the list: none of this is fixed by deleting files. If you add a `RUN rm -rf /usr/local/go` to the Dockerfile, the image does not shrink by a single byte: Lesson 4 taught you that each instruction adds a layer on top of the previous ones, and that what one layer deletes is still stored in the layer below. Deleting in a new layer only hides. For the compiler not to travel, the final image has to **be born without it**.

> [!NOTE]
> 🔧 **Engineering observation 5.1**
> Measure before optimizing, and measure the proportion, not just the total. "The image weighs 1.32 GB" invites you to look for where to trim. "The program is less than 1 % of the image" tells you there is nothing to trim: you have to change images.

### 5.2 The idea of stages

#### 5.2.1 Several `FROM`s in the same Dockerfile

Until now each Dockerfile had a single `FROM`, and everything that came after was stacked on that base. The central idea of this lesson is that **a Dockerfile can have several `FROM`s**. Each `FROM` starts a new **stage**, from scratch, with its own base. The Dockerfile reference puts it this way: `FROM` "can appear multiple times within a single Dockerfile" to create multiple images or to use one build stage as a dependency for another ([Dockerfile reference, `FROM`](https://docs.docker.com/reference/dockerfile/#from)).

What makes that idea useful is three components, which you are going to see in a four-line fragment before the full Dockerfile:

```dockerfile
FROM golang:1.27.3-trixie AS compilacion
RUN ... go build -o /out/revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=compilacion /out/revisor /revisor
```

This block is a fragment to read, not a program: it is missing lines needed to build. What it shows:

1. **The stage's name.** `AS compilacion`, at the end of the `FROM`, names the stage. The documentation recommends naming them this way instead of referring to them by number ([Docker, "Name your build stages"](https://docs.docker.com/build/building/multi-stage/#name-your-build-stages)). A name survives someone adding or removing stages; a number does not.
2. **The copy between stages.** `COPY --from=compilacion` copies a file **from another stage**, not from the context. The reference clarifies that `--from` accepts a stage, an image, or a named context ([reference, `COPY --from`](https://docs.docker.com/reference/dockerfile/#copy---from)). Here, the compilation stage leaves the binary in `/out/revisor` and the last stage picks it up.
3. **The image that comes out.** The image `docker build` produces is that of the **last** stage. Everything that happened in the earlier ones—the compiler, the source code, the cache—is left behind. That is the documentation's sentence: copy what you want and leave behind what you do not.

If you come from programming, a comparison helps: a stage is like a function that returns a value. The compilation stage "returns" a file; the final stage receives only that file, not the local variables used to compute it.

#### 5.2.2 Building up to a stage: `--target`

The second tool is being able to build **only up to** a stage. `docker build --target pruebas` builds the stage named `pruebas` (and those it needs) and stops there; the resulting image is that stage's, not the final one ([Docker, "Stop at a specific build stage"](https://docs.docker.com/build/building/multi-stage/#stop-at-a-specific-build-stage); in the command-line reference, `--target` is "set the target build stage to build", [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)). It is used for two things you are going to use in this lesson: running only the tests, and looking inside an intermediate stage that does have tools.

#### 5.2.3 What BuildKit builds and what it does not

The third component is the least known and the one that brings the most surprises. Docker's builder, BuildKit, does not build all the stages in the file in order: **it builds only the stages the stage you asked for depends on**. The documentation says it bluntly: "BuildKit only builds the stages that the target stage depends on" ([Docker, "Differences between legacy builder and BuildKit"](https://docs.docker.com/build/building/multi-stage/#differences-between-legacy-builder-and-buildkit)). A stage nobody needs does not run.

That is an advantage (no time is wasted on what is not needed) and a trap, which you are going to trigger in 5.5: if the tests live in a stage the final image does not depend on, BuildKit does not run them, and the build comes out green with a broken test inside. Keep that sentence in mind; it is the key to this lesson's silent error.

### 5.3 The four-stage Dockerfile, line by line

#### 5.3.1 The complete recipe

This is the Dockerfile the lesson ends with. It replaces Lesson 4's in your folder, and the `.dockerignore` does not change:

```dockerfile
# syntax=docker/dockerfile:1
# fig05_02.Dockerfile — Lección 5: multi-stage: compilar y probar en una imagen grande, entregar en una mínima.

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
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

There are four chained stages, and each has a single job:

| Stage | Starts from | Its job | Does it travel in the final image? |
|---|---|---|---|
| `compilacion` | the official Go image | having the code ready to compile | no |
| `pruebas` | `compilacion` | running `go test ./...` | no |
| `binario` | `pruebas` | producing `/out/revisor`, static | only that file |
| `final` | *distroless* `static`, no *shell* | running the `revisor` | it is the final image |

The stage names are the course's and they recur in the lessons that follow: `compilacion`, `pruebas`, `binario`, and `final`. They are written without accents on purpose, because they are identifiers you are going to type in `--target` and in `COPY --from`.

#### 5.3.2 Each line at its moment

**The `compilacion` stage.** It is almost the top half of Lesson 4's Dockerfile: the same base, the same `WORKDIR /src`, and the same three `COPY`s in the order the cache appreciates (first `go.mod`, which almost never changes; then the code). The only new thing is in the `FROM`: after the tag `1.27.3-trixie` comes `@sha256:6041…`, the *digest*, and at the end `AS compilacion`. The *digest* has its own section (5.7). This stage does not compile anything yet: it just puts the code in place, so that the next two start from it.

**The `pruebas` stage.** `FROM compilacion AS pruebas` says "start where `compilacion` finished". It is the first time you see a `FROM` that names not an image from the internet but a stage in the same file. Its only `RUN` runs `go test ./...`, the tests for the `revisor`'s five packages, with the same cache mount as in Lesson 4 (the `id=curso-docker-go-build` is the same, so both stages share Go's compilation cache). If a test fails, `go test` exits with a non-zero code, the `RUN` fails, and the build stops: there is no image.

**The `binario` stage.** `FROM pruebas AS binario` is the most important line in the file, even if it looks like a detail. It says the binary is compiled **on top of** the test stage, not the compilation stage. From 5.2.3 you already know why it matters: since the final stage copies from `binario`, and `binario` comes from `pruebas`, BuildKit is forced to run the tests to get to the final image. If `binario` came from `compilacion`, the tests would be off the path and nobody would run them. You are going to measure it in 5.5.

The `RUN` in this stage brings three new things in the Go command:

- **`CGO_ENABLED=0`** asks for a **static** binary: one that does not depend on system libraries to start. It is the piece that makes the final stage possible, and removing it is the lesson's main error (5.8).
- **`-trimpath`** removes from the binary the paths of the machine where it was compiled (here, `/src`): in their place are the module names ([`go help build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies)). That way the binary neither depends on which folder you compiled it in nor reveals it.
- **`-ldflags="-s -w"`** passes two options to Go's linker: `-s` "omit the symbol table and debug information", and `-w` "omit the DWARF symbol table" ([cmd/link](https://pkg.go.dev/cmd/link)). That is what you would use with a debugger; a service in production does not need it, and removing it makes the file smaller. (`-s` already implies `-w`, according to that same documentation; both are written out of habit, and that is how you will see them in almost every Go Dockerfile.) Compare: Lesson 4's binary was 9.5 MiB according to `ls -lh`, about 10 MB; this one is going to be 6.68 MB (6,684,832 bytes). Part of the difference is `-s -w`, and part is that it no longer carries the *cgo* code (5.8).

The binary ends up in `/out/revisor`, a directory that exists only for that: to have a fixed, clean place from which the final stage picks it up.

**The `final` stage.** It starts from scratch on `gcr.io/distroless/static-debian13:nonroot`, pinned by *digest*. Of everything before it, it brings only one file: `COPY --from=binario /out/revisor /revisor`. After that:

- `USER 65532:65532` is the `nonroot` user that the *distroless* image itself has in its `/etc/passwd`; you are going to see it with your own eyes in 5.4. From here on, the course drops the `10001` of the single-stage images and uses `65532`, because it is the one the base already knows. Notice that the `COPY --from=binario` has no `--chown`: the `/revisor` file ends up owned by `root` (you will see it as `0/0` in 5.4) with `rwxr-xr-x` permissions. That is on purpose. User `65532` can execute it, but cannot modify or replace it; if someone took control of the process, they could not rewrite the program on the image's disk.
- `EXPOSE 8080` is still just an annotation, as in Lesson 3.
- **`ENTRYPOINT ["/revisor"]`** replaces the `CMD ["revisor"]` from the earlier lessons. The difference is practical. The reference explains it: the arguments you write after the image name in `docker run` "will be appended after all elements" of an `ENTRYPOINT` in *exec* form, and instead "will override all elements specified using `CMD`" ([reference, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). With `ENTRYPOINT`, `docker run curso-docker-revisor:1.2.0 version` runs `/revisor version`: the image behaves like the program, and its subcommands (`version`, and in Lesson 7 `healthcheck`) are invoked just as in the terminal. With the earlier `CMD`, that `version` would have replaced the whole program and Docker would have tried to run a file called `version`. It is still in *exec* form, for everything you measured in Lesson 3. And the path is written in full, `/revisor`, because the file is at the root of the file system, `/`, which is not one of the directories where the image's `PATH` looks for programs.

#### 5.3.3 In your folder

The course's scripts work in temporary folders and delete what they create; your project has lived in `~/curso-docker/revisor` since Lesson 3. From the root of the course repository, put this lesson's Dockerfile there and build the image you are going to keep:

```bash
cp programas/05-multi-stage/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q -t curso-docker-revisor:1.2.0 .
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

Lesson 4's `.dockerignore` stays as it is. Image `1.1.0` can also stay, so you can compare; when you no longer want it, `docker rmi curso-docker-revisor:1.1.0`.

### 5.4 Building and measuring

#### 5.4.1 The build, stage by stage

`fig05_03.sh` builds both images—Lesson 4's, for comparison, and this one's—and asks the new one five questions: which steps of which stage ran, how much it weighs, what layers it is made of, where its size comes from, and what files it contains:

```bash
#!/usr/bin/env bash
# fig05_03.sh — Construir el revisor en cuatro etapas y medir lo que se entrega.
# Construye la imagen de la Lección 4 (para comparar) y la de esta lección,
# muestra qué etapas corrieron, compara tamaños, lee las capas y lista los
# archivos de la imagen final. Borra lo que crea al salir.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/inicio/Dockerfile" "$TRABAJO/revisor/Dockerfile.leccion4"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.leccion4 && rm -f ./*.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

VIEJA="${PREFIJO}revisor:1.1.0"
NUEVA="${PREFIJO}revisor:1.2.0"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$VIEJA" "$NUEVA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

docker build -q -t "$VIEJA" -f Dockerfile.leccion4 . >/dev/null

titulo "Construir: qué pasos de qué etapa corrieron"
muestra "docker build --progress=plain -t $NUEVA . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[\$0]++'"

titulo "Antes y después"
muestra "docker image ls --filter reference='${PREFIJO}revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Las capas de la imagen nueva"
muestra "docker history $NUEVA --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90"

titulo "De dónde salen los 16.1 MB"
muestra "docker history $NUEVA --format '{{.Size}}' --human=false | awk '{s+=\$1} END {print \"suma de las capas desempacadas:\", s, \"bytes\"}'"
muestra "docker image inspect $NUEVA --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'"

titulo "Todos los archivos de la imagen nueva"
docker create --name "${PREFIJO}mirar" "$NUEVA" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -v '/\$' | wc -l"
muestra "docker export ${PREFIJO}mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo"
muestra "docker export ${PREFIJO}mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |\$)|/?(revisor|passwd)\$' || echo '(nada más)'"
muestra "docker export ${PREFIJO}mirar | tar -xO etc/passwd"
```

The file in the repository has the full helpers; here they are summarized in a comment so as not to repeat them. Two new tools: `grep -oE` prints only the part of each line that matches the pattern (here, the step number, the stage, and the first 60 characters of the instruction), and `awk '!visto[$0]++'` removes repeated lines without changing the order.

```text
$ ./fig05_03.sh

## Construir: qué pasos de qué etapa corrieron
$ docker build --progress=plain -t curso-docker-revisor:1.2.0 . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[$0]++'
#7 [final 1/2] FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757
#8 [compilacion 1/5] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
#10 [compilacion 3/5] COPY go.mod ./
#11 [compilacion 4/5] COPY cmd/ cmd/
#12 [compilacion 5/5] COPY internal/ internal/
#13 [pruebas 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/
#15 [compilacion 2/5] WORKDIR /src
#16 [final 2/2] COPY --from=binario /out/revisor /revisor

## Antes y después
$ docker image ls --filter reference='curso-docker-revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB

## Las capas de la imagen nueva
$ docker history curso-docker-revisor:1.2.0 --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90
0B	ENTRYPOINT ["/revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 65532:65532
6.69MB	COPY /out/revisor /revisor # buildkit
319kB	bazel build //common:cacerts_debian13_arm64_…
16.4kB	bazel build //common:os_release_debian13
12.3kB	bazel build //static:nsswitch
8.19kB	bazel build //common:tmp
12.3kB	bazel build //common:group
16.4kB	bazel build //common:home
12.3kB	bazel build //common:passwd
4.1kB	bazel build //common:rootfs
160kB	bazel build @trixie//media-types/arm64:data_…
2.15MB	bazel build @trixie//tzdata-legacy/arm64:dat…
2.24MB	bazel build @trixie//tzdata/arm64:data_statu…
86kB	bazel build @trixie//netbase/arm64:data_stat…
741kB	bazel build @trixie//base-files/arm64:data_s…

## De dónde salen los 16.1 MB
$ docker history curso-docker-revisor:1.2.0 --format '{{.Size}}' --human=false | awk '{s+=$1} END {print "suma de las capas desempacadas:", s, "bytes"}'
suma de las capas desempacadas: 12468224 bytes
$ docker image inspect curso-docker-revisor:1.2.0 --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'
capas comprimidas (las que se descargan): 3679492 bytes

## Todos los archivos de la imagen nueva
$ docker export curso-docker-mirar | tar -t | grep -v '/$' | wc -l
1301
$ docker export curso-docker-mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo
.dockerenv bin boot dev etc home lib proc revisor root run sbin sys tmp usr var 
$ docker export curso-docker-mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |$)|/?(revisor|passwd)$' || echo '(nada más)'
-rw-r--r-- 0/0             149 1969-12-31 18:00 etc/passwd
-rwxr-xr-x 0/0         6684832 2026-10-21 01:55 revisor
$ docker export curso-docker-mirar | tar -xO etc/passwd
root:x:0:0:root:/root:/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/sbin/nologin
nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin
```

What changes on every run: the step numbers (`#7`, `#8`…) and their order, the date of the `revisor` file, and on an Intel or AMD machine the word `arm64` in the layers and the sizes, by a few kilobytes or megabytes. What is stable: the four stages, the two sizes in their order of magnitude, the fact that the two byte figures add up to the size from `docker image ls`, the list of directories, and the contents of `/etc/passwd`.

#### 5.4.2 Reading the build

The first block shows the steps with their stage in brackets: `[compilacion 4/5]` is the fourth of the five steps of the `compilacion` stage. All four stages appear, and two details show how BuildKit works:

- **The order is not the file's.** The `final` stage's `FROM` appears first (`#7`), before everything in `compilacion`, and the `WORKDIR` (`[compilacion 2/5]`) comes out almost at the end, after the `COPY`s. BuildKit builds a graph of what depends on what and runs in parallel whatever it can: downloading the minimal base does not have to wait for the code to be copied. The final stage only waits for `binario` in its second step, the `COPY --from`.
- **The step numbers are not the stage's.** `#13` is a BuildKit number for this build; `[pruebas 1/1]` is the position within the stage. If you run the script twice, the former may change and so may the order; the labels in brackets do not. (In another run of this same lesson, with more things already in the cache, BuildKit did not even print steps 1 and 2 of `compilacion`; that is why it is not wise to count lines in this output, but rather to read which stages appear.)

#### 5.4.3 Reading the sizes

The second block is the one that justifies the lesson: **from 1.32 GB to 16.1 MB**, about eighty times less. The new image fits seventeen times into what the Go compiler alone used to take up (277 MB in `/usr/local/go`, in 5.1). And the third block, `docker history`, says what is inside: the big layer is `COPY /out/revisor /revisor`, at **6.69 MB**, the binary; the others belong to the *distroless* base and add up to about 5.8 MB, the largest at 2.24 MB (the time zones, `tzdata`). The base's layers say `bazel build`: that is the tool Google builds those images with, and in their history there is not a single `RUN apt-get`, because they were not put together by installing packages with a package manager. Compare with Lesson 4, where `docker history` showed layers of 290 MB, 281 MB, and 208 MB.

If you add up those layers by hand, you do not get 16.1 MB, and it is worth knowing why before it confuses you. The fourth block adds them up for you: **12,468,224 bytes**, about 12.5 MB. 3.6 MB are missing. And the second query in that block finds them: `docker image inspect` reports **3,679,492 bytes**, and 12,468,224 + 3,679,492 = 16,147,716 bytes, the 16.1 MB from `docker image ls`. The explanation lies in how Docker Engine 29 stores images, with the containerd image store: according to its documentation, that store "stores images in both compressed and uncompressed format": it keeps the compressed layers just as they arrived from the registry **and also** unpacks them on disk ([Docker, "containerd image store"](https://docs.docker.com/engine/storage/containerd/)). The `docker image ls` number counts both copies; `docker history` counts only the unpacked layers, and `docker image inspect`, on this machine, the compressed part, which is what gets downloaded. All of this holds for a freshly installed Docker Engine 29, which uses the containerd store by default; the documentation makes clear that a Docker that was upgraded from an earlier version stays on the classic store, `overlay2`, until you enable it by hand. In that case `docker image ls` will show about 12.5 MB instead of 16.1 MB, and so will `docker image inspect`: it is not a mistake of yours, it is another store counting a single copy. For what matters in this lesson nothing changes: always compare images with the **same** command, and the two `docker image ls` figures (1.32 GB and 16.1 MB) were measured the same way.

A natural question is where the `compilacion`, `pruebas`, and `binario` stages went. They stayed in your machine's build cache, which is what makes the next build fast, but **they are not part of the image**: `docker history` for `1.2.0` has not a single layer from them. The only thing that crossed from one side to the other is the file the `COPY --from` names.

#### 5.4.4 Looking inside without getting in

The last part of the script answers the opening scene's question: what is in this image? Since it has no *shell* (you are going to verify that in 5.6), you cannot get in and look with `docker exec`. But you can ask Docker to give you its files. `docker create` creates a container from the image **without starting it**, and `docker export` dumps that container's entire file system as a `tar` archive, which `tar -t` lists without extracting. It is the way to inspect a minimal image from the outside.

What it says:

- **1,301 files** in total (`grep -v '/$'` removes the directories from the count). It seems like a lot, until you look at what they are: almost all of them are the time zones and the certificates of the internet's authorities, which a service that queries others over HTTPS needs.
- **The top-level directories** are those of any Linux (`bin`, `etc`, `usr`, `var`…), plus `revisor` and `.dockerenv`, an empty file Docker adds to every container. That a `bin` directory exists does not mean there are programs inside.
- **The search for *shells*** asked, in any directory, for a file called `sh`, `bash`, `dash`, `ash`, or `busybox`, plus `revisor` and `passwd` as a control: if the pattern were badly written, those two would not come out either. The two controls came out and no *shell*. There is no *shell*, and in 5.6 you confirm it another way: by trying to run it. The `revisor` is 6,684,832 bytes, the 6.69 MB of the layer.
- **The date of `/etc/passwd`**, `1969-12-31 18:00`, is the zero date of the Unix clock (January 1, 1970 in universal time) seen in the time zone of the machine used for the runs. The base's files carry that date on purpose: that way the date of the day the base was built does not alter the files, and two builds of the same base cannot be told apart by that value. (A byte-for-byte reproducible build asks for more than fixing the date, such as a fixed file order and deterministic compression; here the date is only one of those requirements.) The `revisor`, on the other hand, carries the date it was compiled. The one you see here is from the early hours of that same day: the binary came from the build cache, because nothing that produces it had changed since the previous run on that machine. On yours you will see a different date.
- **The contents of `/etc/passwd`** have three users, and the third is the one the final stage uses: `nonroot`, with number **65532**. That is the reason for the `USER 65532:65532`. Notice also the last column of all three: `/sbin/nologin`. Not even `root` has a *shell* assigned.

> [!NOTE]
> 🔧 **Engineering observation 5.2**
> The final image was not "cleaned up": it was born without the extras. It is the difference between tidying a room and moving into an empty one carrying only a suitcase. The first comes undone over time; the second starts clean every time you build.

### 5.5 Tests inside the build

#### 5.5.1 Running only the tests

Having the tests live in their own stage makes it possible to run them **alone**, without building the final image. `fig05_04.sh` builds up to the `pruebas` stage, forcing it to run even if it is in the cache, and measures the resulting intermediate image:

```bash
#!/usr/bin/env bash
# fig05_04.sh — La etapa de pruebas, sola: construye solo hasta «pruebas»,
# obligándola a correr de nuevo, y mide la imagen intermedia que queda.
# Borra lo que crea al salir.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

PRUEBAS="${PREFIJO}revisor:pruebas"
trap 'docker rmi -f "$PRUEBAS" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Solo hasta la etapa de pruebas"
muestra "docker build --target pruebas --no-cache-filter pruebas --progress=plain -t $PRUEBAS . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[\$0]++'"

titulo "La imagen intermedia: sirve para probar, no para entregar"
muestra "docker image ls $PRUEBAS --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

`--no-cache-filter pruebas` tells BuildKit not to use the cache for that stage ([docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)): without it, since nothing changed, the tests would come from the cache and you would not see a single line of `go test`.

```text
$ ./fig05_04.sh

## Solo hasta la etapa de pruebas
$ docker build --target pruebas --no-cache-filter pruebas --progress=plain -t curso-docker-revisor:pruebas . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[$0]++'
#6 [compilacion 1/5] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#8 [compilacion 3/5] COPY go.mod ./
#9 [compilacion 4/5] COPY cmd/ cmd/
#10 [compilacion 2/5] WORKDIR /src
#11 [compilacion 5/5] COPY internal/ internal/
#12 [pruebas 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     go test ./...
#12 15.92 ok  	github.com/habil/revisor/cmd/revisor	0.008s
#12 15.92 ok  	github.com/habil/revisor/internal/config	0.005s
#12 15.92 ok  	github.com/habil/revisor/internal/reporte	0.004s
#12 16.06 ok  	github.com/habil/revisor/internal/revisar	0.141s
#12 16.06 ok  	github.com/habil/revisor/internal/servicio	0.003s

## La imagen intermedia: sirve para probar, no para entregar
$ docker image ls curso-docker-revisor:pruebas --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:pruebas 1.31GB
```

What changes: the step numbers, the seconds in the third column (`15.92` is the number of seconds since that step started), and each package's times. What is stable: the five packages with `ok`.

Three things to read here. First: **only `compilacion` and `pruebas` ran**. There is not a single line from `binario` or `final`: it is the rule from 5.2.3 in action, BuildKit built only what the requested stage needed. Second: the `revisor`'s five packages passed their tests **inside** the build, with the same compiler from the pinned image; it does not depend on whether you have Go installed on your machine, or which version. Third: the `pruebas` image weighs **1.31 GB**. It is for testing and for looking around, never for delivering. That is why it is a stage and not the final image.

#### 5.5.2 A broken test stops the build... if it is on the path

Now this section's error, and its silent version. `fig05_05.sh` adds a test that fails on purpose, `rota_test.go`, and builds twice: with the lesson's Dockerfile and with a variant that changes **a single line**, so that the `binario` stage comes from `compilacion` instead of `pruebas`:

```bash
#!/usr/bin/env bash
# fig05_05.sh — Una prueba rota detiene la construcción... si el Dockerfile la
# pone en el camino. Agrega una prueba que falla a propósito y construye dos
# veces: con el Dockerfile de la lección y con una variante donde la etapa
# «binario» sale de «compilacion» en vez de «pruebas». Borra lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# La variante equivocada: un solo renglón distinto.
sed 's/^FROM pruebas AS binario/FROM compilacion AS binario/' Dockerfile > Dockerfile.salta-pruebas

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

ROTA="${PREFIJO}revisor:rota"
trap 'docker rmi -f "$ROTA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

cat > cmd/revisor/rota_test.go <<'GO'
package main

import "testing"

func TestRotaAProposito(t *testing.T) { t.Fatal("esta prueba falla a propósito") }
GO

titulo "Con el Dockerfile de la lección"
muestra "docker build --progress=plain -t $ROTA . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit \${PIPESTATUS[0]})"
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Con la variante: binario sale de compilacion"
muestra "diff Dockerfile Dockerfile.salta-pruebas"
muestra "docker build --progress=plain -t $ROTA -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo \"construcción: código \${PIPESTATUS[0]}\""
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

The script uses `set -uo pipefail`, without `-e`, because it has to continue after the failure it triggers. `${PIPESTATUS[0]}` is a *bash* variable that holds the exit code of the **first** command in the previous pipeline, the `docker build`, and not that of the `grep` filtering its output; `(exit N)` returns it so that the `muestra` helper records it.

```text
$ ./fig05_05.sh

## Con el Dockerfile de la lección
$ docker build --progress=plain -t curso-docker-revisor:rota . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit ${PIPESTATUS[0]})
#14 1.127     rota_test.go:5: esta prueba falla a propósito
#14 1.127 FAIL
#14 1.127 FAIL	github.com/habil/revisor/cmd/revisor	0.008s
#14 1.128 FAIL
1.127     rota_test.go:5: esta prueba falla a propósito
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1
[código de salida: 1]
$ docker image ls curso-docker-revisor:rota --format '{{.Repository}}:{{.Tag}} {{.Size}}'

## Con la variante: binario sale de compilacion
$ diff Dockerfile Dockerfile.salta-pruebas
17c17
< FROM pruebas AS binario
---
> FROM compilacion AS binario
[código de salida: 1]
$ docker build --progress=plain -t curso-docker-revisor:rota -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo "construcción: código ${PIPESTATUS[0]}"
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor
construcción: código 0
$ docker image ls curso-docker-revisor:rota --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:rota 16.1MB
```

What changes: the step numbers and the seconds. The `[código de salida: 1]` after the `diff` is not an error: `diff` exits with 1 when it finds differences, which is exactly what it was asked to show.

**The first half is the behavior you want.** (The test line comes out twice: the first, with `#14`, is the step's output while it runs; the second, without a number, is the summary BuildKit repeats right before the `ERROR` with the last lines of the step that failed.) The test fails, `go test` prints `FAIL` with the file and line (`rota_test.go:5`) and the message, and BuildKit stops everything with an `ERROR` saying which process failed and with what code: `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. The build exits with 1 and, most importantly, the second command prints nothing: **the `rota` image does not exist**. Code with a broken test produces no image. If your build server publishes what it builds, this is what prevents publishing something broken.

**The second half is the silent error.** The `diff` confirms that the variant changes a single line: `binario` comes from `compilacion`. The broken test is still there. And the build finishes with **code 0** and a 16.1 MB image. There is no `FAIL` or `ERROR` because **the tests never ran**: the filter was looking for `pruebas` and `binario` lines, and only `binario` appears (twice, because BuildKit printed the step's header again when it finished). The `pruebas` stage is still written in the file, but the final stage copies from `binario`, `binario` comes from `compilacion`, and nobody on the path needs `pruebas`. By the rule in 5.2.3, BuildKit does not build it.

It is the worst kind of error: it gives no warning. The Dockerfile *looks* fine, it has a test stage with its comment, and whoever reviews it in passing believes the tests protect the image. That is why `FROM pruebas AS binario` is not a style detail: it is what turns the tests into a condition for the image to exist.

> [!NOTE]
> 🔧 **Engineering observation 5.3**
> A check that can be skipped without anyone noticing is not a check. The way to know whether a gate works is the one in this section: break it on purpose and verify that it stops the build. A green build does not prove the tests passed; it may only prove they did not run.

### 5.6 The minimal base: no *shell* and no `root`

#### 5.6.1 What *distroless* is

The final stage starts from `gcr.io/distroless/static-debian13`. *Distroless* is a family of base images published by Google, and its name already explains the idea: "without a distribution". Its documentation puts it this way: they contain "only your application and its runtime dependencies", and they do not include "package managers, shells or any other programs you would expect to find in a standard Linux distribution" ([distroless](https://github.com/GoogleContainerTools/distroless)).

The family has several variants, depending on what the program needs to run: `base`, `cc`, and others with the Python, Java, or Node.js runtime already installed. The one the `revisor` uses is the smallest of all, **`static`**: for programs that already carry everything inside and depend on nothing from the system. Its documentation gives it as "approximately 2 MiB". Your measurements do not give that number, and it is worth saying so: in the layers in 5.4 you saw it take up about 5.8 MB unpacked, and its compressed version for `arm64`, the one that is downloaded, adds up to 855,334 bytes across its thirteen layers (measured the same day with `docker buildx imagetools inspect --raw` on the `arm64` *digest* from 5.7). The documentation does not say how it measured its 2 MiB, so take it as an order of magnitude: a few megabytes, versus the hundreds of a base with a full distribution. Of the 5.8 MB unpacked, almost 4.4 MB are the time zones (`tzdata` and `tzdata-legacy`). It brings the minimum a static program still needs from the world: the authorities' certificates (to speak HTTPS), the time zones, `/etc/passwd` with its three users, and a `/tmp` directory. Those are the layers you saw in 5.4.

The full name has three parts worth reading one by one:

- `static`: the variant, for static binaries.
- `debian13`: which Debian release the few files it carries (certificates, time zones) come from. The documentation recommends always writing the Debian release in the name, so that your build does not change base without warning on the day the next one comes out.
- `:nonroot`: the tag. *Distroless* publishes few tags, which are names and not versions: `latest`, `nonroot`, `debug`, and `debug-nonroot`, and the same with an architecture suffix, such as `nonroot-arm64` ([distroless](https://github.com/GoogleContainerTools/distroless)); none carries a version. `nonroot` is the same image, but configured to run as the `nonroot` user instead of `root`. The `debug` variants carry a minimal *shell* for debugging; they are not for production.

#### 5.6.2 Running it

`fig05_06.sh` runs the minimal image in the two ways the `revisor` is used—as a program that does one thing and exits, and as a service—and verifies what the lesson promised:

```bash
#!/usr/bin/env bash
# fig05_06.sh — Correr la imagen mínima: su versión, su salud, su reporte, que
# no tiene shell, que no es root y cuánto tarda en detenerse. Borra lo que crea.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# PUERTO: el puerto del equipo donde se publica el revisor, siempre en 127.0.0.1.
PUERTO="${PUERTO:-8080}"

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

IMAGEN="${PREFIJO}revisor:1.2.0"
NOMBRE="${PREFIJO}revisor"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1; docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT
docker build -q -t "$IMAGEN" . >/dev/null

titulo "Un subcomando, sin servidor"
muestra "docker run --rm --name ${PREFIJO}version $IMAGEN version"

titulo "Como servicio"
muestra "docker run -d --name $NOMBRE -p 127.0.0.1:$PUERTO:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' $IMAGEN >/dev/null"
esperar_http "http://127.0.0.1:$PUERTO/salud"
muestra "curl -s http://127.0.0.1:$PUERTO/salud; echo"
muestra "curl -s 'http://127.0.0.1:$PUERTO/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'"

titulo "Sin shell y sin root"
muestra "docker exec $NOMBRE sh"
muestra "docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' $NOMBRE"
muestra "docker top $NOMBRE -o pid,user,args"

titulo "Detenerlo"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' $NOMBRE"
muestra "docker logs $NOMBRE"
```

As in Lesson 3, the `revisor` checks itself (`propio http://127.0.0.1:8080/salud`) because you are not connecting it to other containers yet; that is Lesson 8. The `sed` on the report masks, in plain view, the response time, which changes on every run.

```text
$ ./fig05_06.sh

## Un subcomando, sin servidor
$ docker run --rm --name curso-docker-version curso-docker-revisor:1.2.0 version
desarrollo

## Como servicio
$ docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.2.0 >/dev/null
$ curl -s http://127.0.0.1:8080/salud; echo
{"estado":"vivo","version":"desarrollo"}

$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <tiempo>  200

## Sin shell y sin root
$ docker exec curso-docker-revisor sh
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH
[código de salida: 127]
$ docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' curso-docker-revisor
User=65532:65532 Entrypoint=[/revisor] Cmd=[]
$ docker top curso-docker-revisor -o pid,user,args
PID                 USER                COMMAND
1451351             65532               /revisor

## Detenerlo
docker stop tardó 298 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor
ExitCode=0
$ docker logs curso-docker-revisor
revisor desarrollo escuchando en :8080 (1 servicio(s))
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /api/estados 200 8ms
revisor: recibí terminated, apagando
revisor: apagado limpio
```

What changes: the PID (`1451351`), the `docker stop` time, the `/api/estados` time in the log, and how many times `GET /salud` appears (it depends on how many attempts the script made while waiting for the service to respond). The rest comes out the same.

#### 5.6.3 Reading the run

- **`version` worked as a subcommand.** `docker run ... curso-docker-revisor:1.2.0 version` ran `/revisor version`, thanks to the `ENTRYPOINT`. It prints `desarrollo` because the binary does not have a version stamped on it yet; Lesson 6 adds it.
- **As a service, it does the same as before.** `/salud` answers, the table report says `OK`. The image shrank eightyfold and the behavior did not change at all: everything that was removed really was baggage.
- **There is no *shell*.** `docker exec curso-docker-revisor sh` fails with the same message you saw with the test service in Lesson 2: `exec: "sh": executable file not found in $PATH`, code 127. Now you know why: the base is *distroless* and `sh` does not exist. For the opening scene, this is the answer: whoever managed to run something inside this container would find neither a *shell*, nor `curl`, nor a compiler.
- **It is not `root`.** `docker inspect` says `User=65532:65532`, and `docker top`, which looks at the process from the host, confirms it: the process belongs to user 65532. It also says `Entrypoint=[/revisor] Cmd=[]`: the program is set by the `ENTRYPOINT`, and there are no default arguments.
- **It shuts down properly.** `docker stop` took 298 ms, the code was 0, and the log ends with `recibí terminated, apagando` and `apagado limpio`: the *exec* form makes the signal reach the `revisor`, which is process number 1. Notice that in `docker top`'s `COMMAND` column there is only `/revisor`, with no `/bin/sh -c` in front: there could not even be one, because there is no *shell*.

#### 5.6.4 The cost of not having a *shell*

An image without a *shell* has a price, and it is worth saying so: **you cannot get in and poke around**. There is no `ls`, `cat`, `ps`, or `sh`. When something fails, the tools you have left are the external ones, and they are enough:

- `docker logs`, for what the program writes;
- `docker inspect`, for the configuration and the state;
- `docker top`, to see the process from the host;
- `docker export` with `tar`, to see the files, as in 5.4.4;
- and the `binario` stage built with `--target`, which does have all the tools, to examine the program from the inside. You are going to use it in 5.8.

What you do **not** do is change the final base to one with a *shell* "so you can debug". If you really need a *shell* next to the process, there are tools to attach one from the outside, temporarily, without putting it in the image; this course does not need them.

### 5.7 Version and *digest* of the base

#### 5.7.1 A tag is an alias that moves

In Lesson 3 you saw that a tag like `1.27.3-trixie` is more specific than `latest`, and that even so it can change: whoever publishes the image can push it again. Docker's best practices guide spells it out: "image tags are mutable, meaning a publisher can update a tag to point to a new image" ([best practices, pin base image versions](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). For *distroless* the matter is even clearer: its `nonroot` tag has no version, so **by definition** it points to whatever was published last. Writing just `static-debian13:nonroot` is, in practice, writing `latest`.

#### 5.7.2 What a *digest* is

A ***digest*** is the fingerprint of an image's contents: it is computed by running its bytes through a hash function, SHA-256, and written as `sha256:` followed by 64 hexadecimal characters. The OCI image specification defines it as a "content identifier" that "uniquely identifies content", computed with a collision-resistant hash function ([OCI, descriptors](https://github.com/opencontainers/image-spec/blob/main/descriptor.md)). The practical consequence is what matters: **if a single byte of the image changes, the *digest* changes**. A *digest* cannot be moved to another image, because it is the image.

`fig05_09.sh` asks the registry which *digest* the Dockerfile's two bases have today, without building or creating anything:

```bash
#!/usr/bin/env bash
# fig05_09.sh — Etiqueta contra digest: qué hay detrás de las dos bases.
# Solo consulta el registro y la copia local; no construye ni crea nada.
set -euo pipefail

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

titulo "La base de compilación: la etiqueta y el digest que hoy le corresponde"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'"
muestra "docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie"

titulo "La base final: distroless no publica versiones, solo nombres"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'"
```

`docker buildx imagetools inspect` asks the registry what is behind a name, without downloading the image. `docker image inspect` with `.RepoDigests` says which *digest* the copy you already have on your machine came from.

```text
$ ./fig05_09.sh

## La base de compilación: la etiqueta y el digest que hoy le corresponde
$ docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'
Name:      docker.io/library/golang:1.27.3-trixie
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
$ docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'
  Platform:    linux/amd64
  Platform:    linux/arm64/v8
$ docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie
golang@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c

## La base final: distroless no publica versiones, solo nombres
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'
Name:      gcr.io/distroless/static-debian13:nonroot
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'
  Name:      gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a
  Platform:  linux/amd64
  Name:      gcr.io/distroless/static-debian13:nonroot@sha256:6964c30f0122730c54f70f8f51a777490f85d077d25da672830c43968c14993e
  Platform:  linux/arm64/v8
```

This output is the one from October 21, 2026. **It is the one most likely to change in the whole lesson**, and not because of your machine: the day Google publishes a new base with the `nonroot` tag, the `Digest` in the fourth query will be different. That of `golang:1.27.3-trixie` may also change if its publisher rebuilds it. And if you never downloaded the Go image, the third query fails because you have no local copy.

#### 5.7.3 Reading the output

- **The `MediaType` says `image.index`.** What is behind those tags is not an image but an **index**: a list of images, one per platform. That is why the second and fifth queries find one entry for `linux/amd64` and another for `linux/arm64/v8`, each with its own *digest*. The *digest* the Dockerfile writes is **the index's**: with it, the same line works on your Intel or AMD Mint and on the ARM machine of these runs, and Docker picks the image for your platform within the index.
- **The Dockerfile's two *digests* match that day's**: `6041…` for Go and `5167…` for *distroless*. The local copy of Go came from that same *digest*.
- **If you write a platform's *digest*** (for example, `arm64`'s `6964…`) instead of the index's, the base becomes tied to that architecture: whoever builds on another one no longer gets the base for theirs. It is an easy mistake to make if you copy the *digest* from the wrong line.

#### 5.7.4 Tag **and** *digest*

The Dockerfile writes both together: `golang:1.27.3-trixie@sha256:6041…`. The reference allows that syntax: `FROM <image>[@<digest>] [AS <name>]` ([reference, `FROM`](https://docs.docker.com/reference/dockerfile/#from)). When there is a *digest*, the *digest* rules: Docker pulls exactly those bytes, whatever the tag says today. So what is the tag for? For people: `@sha256:6041…` tells nobody which version of Go it is; `1.27.3-trixie` does. The tag documents; the *digest* pins the content: it ensures that Docker always pulls the same bytes, even if someone has moved the tag in the registry. It does not ensure that the registry keeps that image forever, or that the image has no flaws or vulnerabilities.

The best practices guide explains the guarantee and also its price. The guarantee: with the *digest*, you are "guaranteed to always use the same image version, even if a publisher replaces the tag with a new image". The price: a pinned *digest* **does not update itself**, so the base's security fixes do not reach you on their own either ([best practices](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). Pinning is not forgetting: it is deciding when you change base, after reviewing it, instead of having it change without warning in the middle of a build. The same guide mentions tools that open automatic change requests when a new *digest* comes out. And Lesson 10 teaches you to scan the pinned base so you know when it is time to renew it.

> [!NOTE]
> 🔧 **Engineering observation 5.4**
> A reproducible build is one that gives the same result today and three months from now with the same code. Without a *digest*, the same Dockerfile can produce two different images without anyone having touched anything, and on the day something fails you will not be able to tell whether it was your change or the base's.

### 5.8 The binary that does not start

#### 5.8.1 Triggering it

This is the part of the lesson where everything looks fine and nothing works. `fig05_07.Dockerfile` is the lesson's Dockerfile with **a single change**: the `RUN` in the `binario` stage does not say `CGO_ENABLED=0`:

```dockerfile
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

# --- Etapa 3: el binario, SIN CGO_ENABLED=0 (el binario sale dinámico), sale DESPUÉS de las pruebas ---
FROM pruebas AS binario
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

The comment on stage 3 does tell the truth here (without `CGO_ENABLED=0` the binary comes out dynamic), but in real life that comment tends to keep saying "static" after it has stopped being true: the Dockerfile warns of nothing and the error does not show up until the image runs. `fig05_08.sh` builds that image, runs it, and then examines both binaries, this image's and the lesson's, from the `binario` stage, which does have tools:

```bash
#!/usr/bin/env bash
# fig05_08.sh — El error de esta lección: el binario que no es estático.
# Construye la imagen de fig05_07.Dockerfile (sin CGO_ENABLED=0), la corre, y
# después mira los dos binarios del revisor por dentro, el de esa imagen y el
# de la lección. Borra lo que crea al salir.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig05_07.Dockerfile" "$TRABAJO/revisor/Dockerfile.dinamico"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.dinamico && rm -f ./*.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

DINAMICO="${PREFIJO}revisor:dinamico"
B_DIN="${PREFIJO}revisor:binario-dinamico"
B_EST="${PREFIJO}revisor:binario-estatico"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$DINAMICO" "$B_DIN" "$B_EST" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construye sin error... y no arranca"
muestra "docker build -q -t $DINAMICO -f Dockerfile.dinamico . >/dev/null; echo \"construcción: código \$?\""
muestra "docker run --rm --name ${PREFIJO}dinamico $DINAMICO version"

titulo "Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)"
docker build -q --target binario -t "$B_DIN" -f Dockerfile.dinamico . >/dev/null
docker build -q --target binario -t "$B_EST" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mirar $B_DIN sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'"
muestra "docker run --rm --name ${PREFIJO}mirar $B_EST sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo \"(sin intérprete)\"'"

titulo "¿Está ese intérprete en la imagen final?"
docker create --name "${PREFIJO}mirar" "$DINAMICO" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -E 'ld-linux|libc\\.so' || echo '(no está)'"
```

`ldd` is a Linux tool that lists the shared libraries a program needs to start. `readelf -l` shows the headers of a Linux executable (ELF format), and among them the line saying which program has to load it. Both exist in the Go image, not in *distroless*: that is why they are used from the `binario` stage, built with `--target`.

```text
$ ./fig05_08.sh

## Construye sin error... y no arranca
$ docker build -q -t curso-docker-revisor:dinamico -f Dockerfile.dinamico . >/dev/null; echo "construcción: código $?"
construcción: código 0
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]

## Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:binario-dinamico sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'
	linux-vdso.so.1 (0x0000fd7da7955000)
	libc.so.6 => /lib/aarch64-linux-gnu/libc.so.6 (0x0000fd7da7750000)
	/lib/ld-linux-aarch64.so.1 (0x0000fd7da7910000)
      [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:binario-estatico sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo "(sin intérprete)"'
	not a dynamic executable
(sin intérprete)

## ¿Está ese intérprete en la imagen final?
$ docker export curso-docker-mirar | tar -t | grep -E 'ld-linux|libc\.so' || echo '(no está)'
(no está)
```

What changes: the addresses in parentheses (`0x0000fd7d…`), which are different on every execution. On an Intel or AMD machine, the paths say `x86_64` instead of `aarch64`: the interpreter is `/lib64/ld-linux-x86-64.so.2` and the library is in `/lib/x86_64-linux-gnu/`. The error message and code 255 come out the same.

#### 5.8.2 Reading the error

The build exited with **code 0**: nothing in the Dockerfile is badly written, the tests passed, and the binary was compiled. The error only appears when **running**: `exec /revisor: no such file or directory`, with code 255. That code was not set by the `revisor`, which never got to run: the failure happened when trying to start it.

The message is one of the most confusing you are going to see in Docker, because **the file `/revisor` does exist**: the `COPY --from` copied it, and in 5.4 you saw it in the image's file list. What does not exist is **another** file, and the second part of the output says which one:

- `ldd` on this image's binary lists three things it needs from the system: `libc.so.6`, Debian's C library, and `/lib/ld-linux-aarch64.so.1`, the **dynamic loader** (`linux-vdso.so.1` is provided by the kernel itself and is not a file). `readelf` confirms it with an explicit line: `Requesting program interpreter: /lib/ld-linux-aarch64.so.1`, "I request `/lib/ld-linux-aarch64.so.1` as the program's interpreter".
- The lesson's binary, on the other hand, is `not a dynamic executable` and requests no interpreter: it is **static**, it carries everything it needs inside.
- And the last query looks for the loader and the C library in the final image: `(no está)`. The `static` base does not have them, because it is for static programs.

The Linux manual explains the chain. A dynamic program does not start on its own: the kernel reads from the executable itself which loader it uses, the one "stored in the `.interp` section of the program", and runs it so that it finds and loads "the shared objects (shared libraries) needed by a program" ([ld.so(8)](https://man7.org/linux/man-pages/man8/ld.so.8.html)). If that loader does not exist, the system call that starts programs, `execve`, fails with the error `ENOENT`, which the manual describes this way: "The file pathname or a script or ELF interpreter does not exist" ([execve(2)](https://man7.org/linux/man-pages/man2/execve.2.html)). `ENOENT` is precisely the error that is printed as `no such file or directory`. The message does not lie; it just does not say **which** file is missing, and the missing one is not the one it names.

#### 5.8.3 Why Go produced a dynamic binary

Go is famous for producing binaries that depend on nothing, and that is true almost always. The exception is *cgo*, the mechanism a Go program uses to call C code. Go's documentation says *cgo* "is enabled by default for native builds on systems where it is expected to work", and that it is disabled with the variable `CGO_ENABLED=0` ([cmd/cgo](https://pkg.go.dev/cmd/cgo)). The Go image ships a C compiler (you saw it in 5.1: `gcc`), so *cgo* is enabled there.

And why would the `revisor` want C code, if it has not a single line of C? Because of networking. The `revisor` uses the standard library's `net` package, for its server and to query other services. That package has two ways of turning a name into an address: one written in pure Go and another that calls the system C library's functions. It normally uses the Go one, but under certain system configurations it uses the C one ([net package, "Name Resolution"](https://pkg.go.dev/net#hdr-Name_Resolution)). To be able to choose at run time, when *cgo* is available the binary carries both, and that is what you saw with `ldd` in 5.8.1: the dependency on `libc.so.6` and on the loader. With `CGO_ENABLED=0`, Go uses only its own implementation and the binary ends up static.

The fix, then, is the one in the lesson's `binario` stage: `CGO_ENABLED=0` in front of `go build`. There is no need to change the base or to copy libraries manually.

> [!NOTE]
> 🔧 **Engineering observation 5.5**
> A green build does not guarantee an image that starts. Between building and running there is an implicit agreement between the binary and the base: what one asks for, the other has to have. That is why every new image is **run** before it is considered good, even if only with a subcommand as simple as `version`.

### 5.9 What you will find in old tutorials

Multi-stage builds arrived in Docker in version 17.05, on May 4, 2017: that release's notes announce "support for multi-stage builds" and, in the same list, the option to specify the target stage ([Docker Engine 17.05 release notes](https://docs.docker.com/engine/release-notes/17.05/)). Before that, this lesson's problem was solved with tricks you will still see in old repositories:

- **The "builder pattern" with two Dockerfiles.** A `Dockerfile.build` built an image with the compiler; a *shell* script created a container from that image, extracted the binary with `docker cp`, and then built a second image with another Dockerfile. It worked, but it was three steps that had to be kept in sync by hand. A single multi-stage build does the same.
- **Chained `RUN`s with `&&` that install, compile, and delete in a single line**, so that what is deleted does not remain in any layer. It was the way to save space with a single stage; it is still less effective than not putting the compiler in the final image.
- **`FROM scratch`.** `scratch` is an empty image, without a single file. A static binary can run there, and many tutorials do it. It lacks what *distroless* `static` does bring: certificates for HTTPS, time zones, and an `/etc/passwd` with an unprivileged user. For the `revisor`, which queries services and must not run as `root`, the course's base saves you from having to add those components by hand.
- **`FROM alpine` as the final base "because it is tiny".** Alpine is small, but it brings a *shell* and a package manager, and it uses a different C library (musl) from Debian's: a dynamic binary compiled in Debian's Go image does not start on it, for the same reason as in 5.8.
- **`COPY --from=0`**, with a number instead of a name. It works, but it breaks silently the day someone adds a stage at the beginning.

## The error you will see

This lesson has one main error and one you do not see.

**The main error: `exec /revisor: no such file or directory`.** It is the one from `fig05_08.sh`:

```text
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]
```

It reads like this: the container could not **start** the program, and the program never ran (which is why it printed nothing of its own). The treacherous part is that the file it names does exist. What is missing is what that file needs in order to start: its dynamic loader and the libraries it requests. When you see this message with a minimal base, the sequence is:

1. Build the binary stage with `--target` and look at the program with `ldd` and `readelf -l`. If it says `not a dynamic executable`, the problem is something else (check the `ENTRYPOINT`'s path). If it lists libraries and an interpreter, you found the cause.
2. Fix it in the compilation: for Go, `CGO_ENABLED=0`. If a program really needs the C library, the right base is one that has it, not the `static` variant: *distroless* has more complete variants, such as `base` and `cc`, and its documentation says what each one brings.
3. What you do **not** do is copy loose libraries into the final image until it starts, or change the base to one with a *shell* "so it works". The first is fragile and the second undoes the lesson.

**The error you do not see: the test stage nobody runs.** It is the second half of `fig05_05.sh`: with `FROM compilacion AS binario`, a broken test does not stop the build, because BuildKit does not build a stage the final image does not depend on. There is no message to read; the symptom is precisely that there is **no** `FAIL`. The only way to find it is the one in that figure: add a broken test on purpose and verify that the build fails with `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. If it ends with code 0, check which stage your binary stage comes from.

## The security habit of the lesson

**Deliver only what is needed to run, on a minimal base, pinned and without `root`.** The final image has no *shell*, no package manager, no compiler, and no `curl`; it runs as user 65532; and its base is pinned by *digest*. This habit prevents three concrete accidents. The first is the one in the opening scene: whoever manages to run something inside the container—through a bug in the program, for example—finds no tools to download, compile, or run anything else; they have to bring everything, and without a *shell* they do not even have anything to run it with. The second is the base that changes by itself: without a *digest*, tomorrow's build may bring a different base from today's without anyone deciding so. The third is noise: a scanner that checks 16 MB with a handful of packages tells you something you can read; one that checks 1.32 GB with two hundred Debian packages does not. That the image also shrinks eightyfold is the consequence, not the goal.

## Common mistakes

**Shrinking the image by deleting files with `RUN rm`.** What is deleted is still in the layer below; the image does not shrink. What must not travel stays in another stage.

**Delivering the single-stage image "because it works".** It works just like the 16 MB one, and it carries a full workshop for whoever gets in. Running is not the criterion; the criterion is what else it carries.

**Taking the binary from the compilation stage and leaving the tests in a separate stage nobody needs.** It looks as if there were tests, and there are none (5.5). The binary comes **from** the test stage.

**Pinning the base only by tag, or using *distroless*'s `nonroot` tag without a *digest*.** It is using `latest` under another name. Tag for reading, *digest* for pinning the content.

**Copying a platform's *digest* instead of the index's.** The base becomes tied to a single architecture, and whoever builds on another does not get the one that corresponds to them. The *digest* that goes in the `FROM` is the one on the `Digest:` line at the top, the index's.

**Changing the final base to one with a *shell* "so you can debug".** You debug from the outside (`logs`, `inspect`, `top`, `export`) and from the build stage with `--target`; the delivered image does not carry tools just in case.

**Using `CMD` where the image is a program with subcommands.** With `CMD ["revisor"]`, `docker run image version` replaces the whole program. With `ENTRYPOINT ["/revisor"]`, it is appended as an argument.

**Considering an image good because it built.** The dynamic binary in 5.8 builds without a single error. An image is considered good when it **runs**.

## Exercises

Do them in order. Before each one, write in your [logbook](bitacora.md) what you think will happen; comparing it afterwards is half of the learning. If you run something, delete what you created when you finish: everything carries the `curso-docker-` prefix.

### Exercise 1 — Which stages run?

With the lesson's Dockerfile (fig05_02), and assuming the cache is empty, say which stages BuildKit builds in each case:

1. `docker build -t curso-docker-revisor:1.2.0 .`
2. `docker build --target pruebas -t curso-docker-revisor:pruebas .`
3. `docker build --target compilacion -t curso-docker-revisor:compilacion .`
4. With the `fig05_05.sh` variant (`FROM compilacion AS binario`): `docker build -t curso-docker-revisor:1.2.0 .`

And one more question: in case 2, does the resulting image have the `/out/revisor` binary?

### Exercise 2 — Fix someone else's Dockerfile

A teammate hands you this "multi-stage" Dockerfile for the `revisor`. Find **six** problems that cause an accident, say which accident each one causes, and write the corrected version. (There are also two style details worth correcting; they do not count among the six.)

```dockerfile
FROM golang:latest
WORKDIR /src
COPY . .
RUN go test ./...

FROM golang:latest
WORKDIR /src
COPY . .
RUN go build -o /revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=1 /revisor /revisor
CMD ["/revisor"]
```

Hint: one of the six is the lesson's main error and another is the error you do not see.

### Exercise 3 — The right `FROM`

With the output of `fig05_09.sh` in view, write the final stage's `FROM` for these three cases, and say which of the three is right for the course:

1. By tag only.
2. By tag and by the *digest* that works on any platform.
3. By tag and by your platform's *digest*, if your Mint is Intel or AMD.

What happens with case 3 if a teammate with an ARM computer builds your Dockerfile?

### Exercise 4 — Your image, measured (project)

In your folder `~/curso-docker/revisor`, with the image `curso-docker-revisor:1.2.0` you built in 5.3.3, verify without looking at the lesson:

1. Its size, compared with that of the `1.1.0` you wrote down in Lesson 4. Write both in your logbook.
2. That it has no *shell*.
3. That it does not run as `root`, in two different ways: one that reads the image's configuration and another that looks at the process from the host.
4. That your image's binary is static, without getting into the final image.

The exercise is self-checking: you are done when you have four commands whose outputs say, respectively, about 16 MB (or about 12.5 MB if your Docker uses the classic store, see 5.4.3), `executable file not found`, the user `65532` (as `65532:65532` in `inspect` and as `65532` in `top`), and `not a dynamic executable`.

## Solutions

### Solution 1

1. All four: `final` copies from `binario`, `binario` comes from `pruebas`, and `pruebas` comes from `compilacion`. It is the chain that forces the tests to run. You saw it in the first block of `fig05_03.sh`.
2. `compilacion` and `pruebas`, and nothing else. It is exactly what `fig05_04.sh` showed: not a single line from `binario` or `final`.
3. Only `compilacion`.
4. `compilacion`, `binario`, and `final`. **`pruebas` does not run**, because nobody on the final stage's path needs it: it is the second half of `fig05_05.sh`, which ended with code 0 and an image, with a broken test inside.

The extra question: **no**. The `pruebas` stage only runs `go test`; the binary is produced in the `binario` stage, which comes after and was not built. The `pruebas` image has the source code and the compiler, which is why it weighs 1.31 GB.

### Solution 2

1. **`golang:latest`.** The base can change on any build, and with it the Go version: the same code compiles differently from one day to the next. It should be `golang:1.27.3-trixie@sha256:…`.
2. **The binary stage does not come from the test stage.** It is a separate `FROM golang:latest`, so the test stage is not on the final stage's path and BuildKit **does not run it**: a broken test stops nothing (the error you do not see, 5.5). The binary stage must come from the test stage.
3. **`CGO_ENABLED=0` is missing.** The binary comes out dynamic and on *distroless* `static` it fails with `exec /revisor: no such file or directory` (the main error, 5.8).
4. **`COPY --from=1` with a number.** The day someone adds or removes a stage at the beginning, the number points to another stage and the wrong thing is copied, without warning. With names (`COPY --from=binario`), that does not happen silently: the instruction still points to the stage its name says, and if someone deletes that stage, the build fails with an error instead of copying from another one.
5. **The final base without a *digest*.** The `nonroot` tag without a *digest* is `latest` under another name: the base can change without anyone deciding so (5.7).
6. **`CMD` instead of `ENTRYPOINT`.** With `CMD ["/revisor"]`, `docker run image version` replaces the whole program and Docker tries to run a file called `version`, which does not exist (5.3.2).

The two style details: the `COPY . .` repeated in two stages (it copies the whole context twice; with a common `compilacion` stage once is enough, and with selective `COPY`s, as in Lesson 4) and the implicit `USER` (the `nonroot` base already runs as 65532, because its configuration says `"User": "65532"`, but writing `USER 65532:65532` makes the intention visible to whoever reads the Dockerfile).

The corrected version is the lesson's Dockerfile, `fig05_02.Dockerfile`.

### Solution 3

1. `FROM gcr.io/distroless/static-debian13:nonroot AS final`
2. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final`
3. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a AS final`

The right one is 2: the index's *digest*, the one on the `Digest:` line, which works on `amd64` and on `arm64`. With 3, the base is tied to the `linux/amd64` image: on your teammate's ARM computer, Docker can no longer pick the base for their platform within the index, because the `FROM` names not the index but a single one of its images, and their final image would end up with a base of a different architecture from their binary's. This lesson did not run that case; what matters is that with the index's *digest* the question does not even come up. The *digests* in this solution are from October 21, 2026; if `fig05_09.sh` shows you others, use yours and write in your logbook that the base changed.

### Solution 4

One way to do it:

```bash
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.2.0
docker exec curso-docker-revisor sh
docker inspect --format '{{.Config.User}}' curso-docker-revisor
docker top curso-docker-revisor -o pid,user,args
docker build -q --target binario -t curso-docker-revisor:binario .
docker run --rm curso-docker-revisor:binario ldd /out/revisor
docker rm -f curso-docker-revisor && docker rmi curso-docker-revisor:binario
```

The expected outputs are the lesson's: `16.1MB` (a few megabytes more or less on Intel or AMD) versus `1.32GB`; the error `exec: "sh": executable file not found in $PATH` with code 127; `65532:65532` in `inspect` and `65532` in `top`'s `USER` column; and `not a dynamic executable` in `ldd` (as in `fig05_08.sh`). If in the last step `ldd` lists `libc.so.6`, your Dockerfile lost the `CGO_ENABLED=0`.

## How I know I got it

Check each item only if you can do it **without looking at the text again**:

- [ ] `docker image ls curso-docker-revisor` shows the tag `1.2.0` at about **16 MB**, and you wrote the before and after in your logbook (in this lesson's run, 1.32 GB → 16.1 MB).
- [ ] `docker run --rm curso-docker-revisor:1.2.0 version` prints `desarrollo`.
- [ ] `docker exec` with `sh` on a container from your image fails with `executable file not found in $PATH`, and `docker top` shows the process with user `65532`.
- [ ] You added a broken test to your folder, `docker build -t curso-docker-revisor:rota .` failed with `exit code: 1`, and `docker image ls curso-docker-revisor:rota` shows nothing; afterwards you deleted the test.
- [ ] You can explain why `FROM pruebas AS binario` and not `FROM compilacion AS binario`, with BuildKit's sentence about which stages it builds.
- [ ] You can explain which file is missing when `exec /revisor: no such file or directory` appears, and how you confirm it with `ldd` or `readelf` from the `binario` stage.
- [ ] You can say what the tag ensures, what the *digest* ensures, and why the *digest* in the `FROM` is the index's.
- [ ] You ran the scripts in [`programas/05-multi-stage/`](../programas/05-multi-stage) and your outputs match this lesson's in what each section marks as stable. What is not compared: step numbers, PIDs, times, dates, `ldd` addresses, the architecture, sizes within a few megabytes, and the *digests* from `fig05_09.sh` if the base was republished. And when you finish, `docker ps -a --filter name=curso-docker-` shows no containers from this lesson.

## Summary

Answer without looking at the lesson:

1. Why did Lesson 4's image weigh 1.32 GB if the `revisor` weighed 9.5 MB? Why does deleting the compiler with a `RUN rm` not shrink it?
2. What is a stage? What do `AS`, `COPY --from`, and `--target` do?
3. Which stages does BuildKit build when you ask for the final image? What consequence does that have for the test stage?
4. What does the *distroless* `static` base bring and not bring? What tools do you have left to debug an image without a *shell*?
5. Why does the Dockerfile use `ENTRYPOINT ["/revisor"]` instead of `CMD ["revisor"]`?
6. What is a *digest*? Why are the tag and the *digest* written together, and what is the price of pinning the base?
7. What does `exec /revisor: no such file or directory` mean when the file does exist? What does `CGO_ENABLED=0` do?

## Sources

All consulted on October 21, 2026.

- [Docker, "Multi-stage builds"](https://docs.docker.com/build/building/multi-stage/): multiple `FROM`s, copying selectively between stages, naming stages, `--target`, and that BuildKit only builds the stages the target stage depends on.
- [Docker, "containerd image store"](https://docs.docker.com/engine/storage/containerd/): that the containerd store keeps each layer compressed and unpacked, which explains the size from `docker image ls`.
- [Docker, build best practices](https://docs.docker.com/build/building/best-practices/): stages to reduce size, the minimal base, mutable tags, and pinning by *digest* with its price.
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/): the syntax `FROM <image>[@<digest>] [AS <name>]`, `COPY --from`, and how `ENTRYPOINT` and `CMD` receive the arguments from `docker run`.
- [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/): the `--target` and `--no-cache-filter` options.
- [Docker Engine 17.05, release notes](https://docs.docker.com/engine/release-notes/17.05/): the arrival of multi-stage builds and of the target stage, on May 4, 2017.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions and dates in "About the runs".
- [distroless (GoogleContainerTools)](https://github.com/GoogleContainerTools/distroless): what *distroless* images bring and do not bring, the size of `static-debian13`, its tags, and the recommendation to name the Debian release.
- [golang on Docker Hub](https://hub.docker.com/_/golang): the `1.27.3-trixie` tag and its aliases.
- [OCI Image Specification, descriptors](https://github.com/opencontainers/image-spec/blob/main/descriptor.md): what a *digest* is and why it identifies the content.
- [cmd/cgo](https://pkg.go.dev/cmd/cgo): when *cgo* is enabled and how it is disabled with `CGO_ENABLED=0`.
- [Go net package, "Name Resolution"](https://pkg.go.dev/net#hdr-Name_Resolution): the two ways of resolving names, pure Go and the one that uses the C library.
- [cmd/link](https://pkg.go.dev/cmd/link): the linker's `-s` and `-w` options, and that `-s` implies `-w`.
- [cmd/go, `go build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies): the `-trimpath` option.
- [ld.so(8), Linux manual](https://man7.org/linux/man-pages/man8/ld.so.8.html): the dynamic loader and the `.interp` section.
- [execve(2), Linux manual](https://man7.org/linux/man-pages/man2/execve.2.html): the `ENOENT` error when an ELF's interpreter is missing.
- [Colima](https://github.com/abiosoft/colima): the tool used to run the programs on macOS.

### Terms in this lesson

| | |
|---|---|
| **dynamic binary** | an executable that needs system libraries and a loader to start |
| **static binary** | an executable that carries inside everything it needs; it does not depend on system libraries |
| **dynamic loader** | the program (`ld-linux…`) that starts a dynamic binary and loads its libraries |
| ***cgo*** | the mechanism a Go program uses to call C code; it is disabled with `CGO_ENABLED=0` |
| ***digest*** | the SHA-256 fingerprint of an image's or an index's contents; if one byte changes, the fingerprint changes |
| ***distroless*** | a family of minimal base images, without a *shell* or a package manager |
| **stage** | each part of a Dockerfile that begins with a `FROM`; only the last one is the image that is delivered |
| **target stage** | the stage up to which you build with `--target` |
| **index** (*image index*) | a list of images under the same name, one per platform |
| ***multi-stage*** | a build in several stages within the same Dockerfile |

---

**Next:** [Lesson 6 — Configuration and secrets](06-configuracion-y-secretos.md)
