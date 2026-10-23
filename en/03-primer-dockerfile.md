# Lesson 3 — Your first Dockerfile

It is 6:40 on a Friday evening and the window to update the server closes at 7. The plan was simple: stop the old `revisor`, start the new one, go home. You type `docker stop` and the terminal goes silent. One second. Three. Seven. At ten, it finally comes back. You try it on the next copy and again: exactly ten seconds of silence. You check the logs and the line the `revisor` always writes when it shuts down, `apagado limpio`, is missing; the last report was left half-written. Someone on the team finds the container's state and reads it out loud: `ExitCode=137`. Nobody killed it on purpose, and yet it was killed. The culprit is not in the `revisor`'s code, which knows how to shut down properly. It is in a three-word line at the end of its Dockerfile, one that looks harmless and that many tutorials write exactly that way. This lesson teaches you to write that line, and all the others, knowing what each one does.

**Time:** 2 × 45 min

**What you build:** the first image of the `revisor`, `curso-docker-revisor:1.0.0`, in a single stage, with its `Dockerfile` and its `.dockerignore`. It runs unprivileged, shuts down in a fraction of a second, and carries a version in its name.

**What you learn:** what a Dockerfile is and what each of its basic instructions does (`FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`); the difference between the *exec* form and the *shell* form, measured with a stopwatch; what the build context is and what `.dockerignore` is for; why the first Dockerfile already includes `USER`; how to name and tag an image with a version; and how to check a Dockerfile before building it with `docker build --check`.

**Where you are coming from.** From [Lesson 2](02-contenedores-dia-a-dia.md) you bring a feel for the day to day: you start a container with `docker run`, look at it with `ps`, `logs`, `inspect`, and `exec`, publish its port only on `127.0.0.1`, and delete it without leaving leftovers. There you built the test service's image with a single command, without asking what was in its Dockerfile. From [Lesson 0](00-que-es-un-contenedor.md) you bring the map: a container is a process; an image is the template it is born from; and code 137 means the kernel killed the process with signal 9. That last idea is going to come back here in a different guise. From the course you also bring the `revisor`'s code, in `programas/revisor/`, exactly as the course delivers it: an HTTP service written in Go that does not have a Dockerfile yet. You do not need to know Go: you will not change a single line of the program.

**What this lesson does not do.** It does not make the image small: the one that comes out of here weighs more than a gigabyte, and that is fine for now, because seeing it big is the best way to understand later why it is worth shrinking it (the course plan leaves that for [Lesson 5](05-multi-stage.md)). Nor does it order the Dockerfile so that rebuilding is fast, or explain the layers one by one: that is the subject of [Lesson 4](04-capas-cache-contexto.md). It does not connect the `revisor` to other containers (which is why, in this lesson, the `revisor` checks itself), and it does not give it health checks or secrets. A single stage, a single image, everything in plain view.

**About the runs.** All outputs are real and were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4, the same base as Linux Mint 22, the course's reference system. The scripts were run **inside that virtual machine**, with Docker 29.2.1 and Buildx v0.31.1 (the first line of `docker build --check` says `building with "default" instance`, as it will on your Mint). That same machine was being used by other runs at the same time, and was heavily loaded, so, to avoid collisions, the scripts were launched with a different name prefix and a different port: they have the variables `PREFIJO` (default `curso-docker-`) and `PUERTO` (default `8080`), and they were run with `PREFIJO=curso-docker-l03-` and `PUERTO=18030`. In the outputs where names and port appear, the lesson shows the default values, which are the ones you will see: `curso-docker-revisor` instead of `curso-docker-l03-revisor` and `8080` instead of `18030` (and the width of the tables, which depends on the longest name, was left as it came out); that is the only change, and the `.salida.txt` files keep the run as it was. What does not change with the variables, because it happens inside the container, appears as is: the internal port `8080`. There are eight programs: the usual scripts `fig03_02`, `fig03_04`, `fig03_05`, `fig03_07` and `fig03_08`, plus `fig03_09` (the "In your folder" setup of 3.6.1, assembled in a temporary folder and with the tag `1.0.0-carpeta`, so as not to touch yours), `fig03_12` (the two Dockerfiles with defects for the exercises, `fig03_10.Dockerfile` and `fig03_11.Dockerfile`) and `fig03_13` (how far a `.dockerignore` pattern reaches). The scripts' `t` helper falls back to `python3` when the system's `date` does not give milliseconds, as is the case on macOS; on Mint and on the virtual machine it is not needed. The times in this lesson (build, shutdown) came out with the machine loaded, so on your Mint they should be lower or similar; the 10 seconds of the *shell* form do not depend on load. The course was planned with Docker Engine 29.8.2, and the latest version published that day was 29.9.2, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)); nothing in this lesson changes between those versions. What **does** change on your Mint, and it is flagged where it appears: the process numbers (PIDs), the times, and, if your machine is Intel or AMD, the architecture (`amd64` instead of `arm64`), which is not printed here but does decide which variant of the Go image gets downloaded. The programs are in [`programas/03-primer-dockerfile/`](../programas/03-primer-dockerfile), each one with its output next to it; `estado/` keeps the `Dockerfile` and the `.dockerignore` as they end up when finished.

## By the end you will be able to

- Write a single-stage Dockerfile for an existing program and say, line by line, whether that instruction acts when **building** the image or when **running** the container.
- Build an image with a name and a version tag, and explain why the course's `revisor` is called `curso-docker-revisor:1.0.0` and not `revisor` or `revisor:latest`.
- Show with `docker exec ... id` that your container does not run as `root`, and explain what `USER 10001:10001` changes.
- Write a `.dockerignore` and verify, by looking inside the image, that a `.env` file did not make the trip.
- Measure how long `docker stop` takes with `CMD` in *exec* form and in *shell* form, and explain with `docker top` why one takes a fraction of a second and the other a little over 10 s with code 137.
- Run `docker build --check` before building and read the `JSONArgsRecommended` warning.

## The why before the how

In Lesson 2 you worked with an image that was handed to you ready-made. It works, but there is a catch: if you do not know how it was put together, you do not know what it contains or how it is going to behave. Does it run as `root`? Does it carry your configuration files inside? Does it shut down when you ask it to, or does it wait to be killed? Those three questions are not answered by looking at the running container; they are answered by reading its **recipe**.

An image's recipe is called a **Dockerfile**. It is a text file with instructions, one per line, that Docker reads from top to bottom to produce the image. The documentation defines it this way: Docker builds images by reading the instructions from a Dockerfile, "a text file containing instructions for building your source code" ([Docker, "Dockerfile overview"](https://docs.docker.com/build/concepts/dockerfile/)); and its reference describes it as a text document with all the commands a user could run on the command line to assemble an image ([Dockerfile reference](https://docs.docker.com/reference/dockerfile/)). What matters for you is that the recipe is **repeatable**: it describes the same process on your machine, on your teammate's and on the server, and that is why an image is fixed by changing its recipe and rebuilding, not by getting into the container. (For two builds to give an *identical* image you also have to pin the base by its fingerprint, as you will in Lesson 5; with a tag, the base can change underneath you, as you will see in 3.3.1.) What you called in Lesson 0 "you do not fix an image by getting into the container" has its other half here: an image is fixed by **changing its recipe and rebuilding**.

And every line of that recipe is a decision. The scene at the beginning was not caused by a programming error: it was caused by writing `CMD revisor` instead of `CMD ["revisor"]`. They look almost the same. This is the difference you will measure in section 3.7, with the same image and the same program:

```text
## docker stop con forma exec
tardó 562 ms

## docker stop con forma shell
tardó 10365 ms
ExitCode=137
```

A few tenths of a second against ten seconds and a corpse. Those are this lesson's run numbers. The milliseconds change (that machine was heavily loaded); the ten seconds and the 137 do not. The lesson has seven parts:

1. **What building is** (3.1): the recipe, the context and who does the work.
2. **The `revisor`'s Dockerfile, line by line** (3.2).
3. **The name and the tag** (3.3): why `curso-docker-revisor:1.0.0`.
4. **`USER`: not running as `root`** (3.4).
5. **The context and `.dockerignore`** (3.5), with a fake secret that sneaks in.
6. **Building, failing and running** (3.6), and the ***exec* form versus the *shell* form** (3.7), with the stopwatch.
7. **Checking before building** (3.8) and the old things you will find in tutorials (3.9).

## The concepts

### 3.1 What building an image is

#### 3.1.1 The recipe, the ingredients and the kitchen

Building an image has three components, and it is worth separating them from the start because each one fails in a different way:

- **The recipe**: the Dockerfile.
- **The ingredients**: the files the recipe can use. They are called the **build context**, and almost always they are the contents of a folder. In the command `docker build .`, the final dot is that folder: "the context is this folder I am in".
- **The kitchen**: the builder, which in Docker is called **BuildKit** and is part of the daemon. Remember Lesson 0: the `docker` client does not do the work; it asks the daemon. When building, the client sends it the recipe and the ingredients the recipe asks for, and the daemon cooks.

The build documentation says it with these same components: the context is the set of files the build has access to, and the Dockerfile instructions can only take files from there ([Docker, "Build context"](https://docs.docker.com/build/concepts/context/)). This has a practical consequence you will use in 3.5: **what is not in the context cannot get into the image**, and what is in the context can get in even if you do not want it to.

#### 3.1.2 Two moments: building and running

There is an idea that organizes everything else in this lesson: a Dockerfile describes **two different moments**.

1. **When building** (`docker build`): Docker starts from a base image, copies files and runs commands. What results is stored in the image. This happens once, on your machine or on a build server.
2. **When running** (`docker run`): Docker creates a container from that image and starts **one** process. This happens every time someone runs the image, on any machine.

Some instructions act in the first moment and others only leave a **note** of what to do in the second. If you confuse the two moments, you write things like a `RUN` that tries to start the server (it would run at build time, would sit waiting, and the build would never finish) or you expect an `EXPOSE` to open a port (it only notes it). The table in 3.2.2 separates each instruction by moment.

### 3.2 The `revisor`'s Dockerfile, line by line

#### 3.2.1 The complete recipe

This is the Dockerfile the lesson ends with. It goes in the root of the `revisor`'s project, next to `go.mod`, and it is called exactly `Dockerfile`, with no extension, which is the name `docker build` looks for by default:

```dockerfile
# syntax=docker/dockerfile:1
# fig03_01.Dockerfile — Lección 3: el primer Dockerfile del revisor: una sola etapa.
FROM golang:1.27.3-trixie

WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor

# Un usuario sin privilegios, por número: la imagen no necesita tenerlo en /etc/passwd.
USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

Twelve lines, of which seven are instructions. Let us take them one by one.

**`# syntax=docker/dockerfile:1`.** It looks like a comment, and for almost all of the file it is, but on the first line it is a **directive**: it tells BuildKit which version of the Dockerfile syntax to use. The reference explains it like this: it is used to "declare the Dockerfile syntax version to use for the build", and it lets you use new features without upgrading Docker ([Dockerfile reference, *syntax*](https://docs.docker.com/reference/dockerfile/#syntax)). The `1` means "the latest version 1". That is why, in the build outputs, you will see Docker first resolve `docker.io/docker/dockerfile:1`: it goes for the recipe's interpreter before reading it. All the course's Dockerfiles start with this line.

**`FROM golang:1.27.3-trixie`.** Every image starts from another (the only exception is the empty image `scratch`, which you will not need in this course). `FROM` says which is the **base image**: here, the official Go one in its version 1.27.3, built on Debian 13, whose codename is *trixie*. The `revisor` is written in Go and compiling it requires the Go compiler; this image brings it, along with a whole Debian. Docker Hub lists that tag among the current ones of the Go image, and clarifies that names like *bookworm* or *trixie* are the codenames of the Debian versions it is built on ([golang on Docker Hub](https://hub.docker.com/_/golang)).

**`WORKDIR /src`.** It sets the working folder inside the image: everything that comes afterwards (`COPY`, `RUN`, `CMD`) happens there. If the folder does not exist, Docker creates it ([reference, `WORKDIR`](https://docs.docker.com/reference/dockerfile/#workdir)). It is better than writing `RUN cd /src`, which does not work: each `RUN` starts afresh and the `cd` is lost when that line ends.

**`COPY . .`.** It copies from the context (the first dot) to the image's working folder (the second dot, which here is `/src`). It is the only door through which your files enter the image. Copying **everything** is the simplest and the most dangerous: everything in the context goes in. That is why the `.dockerignore` of 3.5 exists. (Copying everything at once also makes rebuilding slow; the course plan deals with that in Lesson 4.)

**`RUN go build -o /usr/local/bin/revisor ./cmd/revisor`.** It runs a command **at build time** and stores the result in the image. Here it compiles the `revisor` and leaves the executable at `/usr/local/bin/revisor`, a folder that is already in the image's `PATH` variable. That is why further down it is enough to write `revisor`, without a path.

**`USER 10001:10001`.** From here on, and above all at run time, the process uses user 10001 and group 10001 instead of `root`. It has its own section, 3.4.

**`EXPOSE 8080`.** It notes that the program listens on port 8080. It only notes it: the reference is clear that `EXPOSE` "does not actually publish the port"; to publish it you need `-p` when running ([reference, `EXPOSE`](https://docs.docker.com/reference/dockerfile/#expose)). It serves as documentation for whoever reads the image and for tools that query it. The port is published, as you learned in Lesson 2, with `-p 127.0.0.1:8080:8080`.

**`CMD ["revisor"]`.** It notes which process to start **when running** the container. Only one can be effective: if you write several `CMD`s, the last one wins ([reference, `CMD`](https://docs.docker.com/reference/dockerfile/#cmd)). And it is a default value: if you pass `docker run` a command after the image name, that command replaces the `CMD` ([Docker, "Running containers"](https://docs.docker.com/engine/containers/run/)). The brackets and the quotes are not decoration: they are the *exec* form, the subject of 3.7.

#### 3.2.2 Each instruction in its moment

| Instruction | When it acts | What it leaves in the image |
|---|---|---|
| `FROM` | at build time | all the contents of the base image |
| `WORKDIR` | at build time, and notes the folder for running | the folder, and the value of where to start |
| `COPY` | at build time | the copied files |
| `RUN` | at build time | what the command wrote to disk |
| `USER` | notes for running (and for the `RUN`s that come after) | the user value |
| `EXPOSE` | only notes | the port value; it opens nothing |
| `CMD` | only notes | the command each container will start |

Read the third column carefully: the last three instructions do not add files, they add **data** to the image's configuration. You will be able to read them with `docker inspect` and, later on, in the image's history. Keep in mind that order matters: a `USER` that goes before a `RUN` makes that `RUN` execute as that user. That is why here `USER` goes after compiling: the compilation needs to write to `root`'s folders, the server does not.

> [!NOTE]
> 🔧 **Engineering observation 3.1**
> For each line of a Dockerfile, ask yourself: "does this happen once, when I build, or every time, when someone runs it?". What happens at build time can be slow and heavy, because it is paid for only once. What happens at run time has to be fast and minimal, because it is paid for at every start, and on a bad day, at every restart.

### 3.3 The name and the tag

#### 3.3.1 The parts of a name

When you build, you name the image with `-t`. An image's full name has this form, according to the `docker image tag` documentation: `[HOST[:PORT]/]NAMESPACE/REPOSITORY[:TAG]` ([`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/)). In practice almost everything can be omitted: `golang:1.27.3-trixie` writes neither the registry nor the namespace, because Docker fills in `docker.io/library/` (the `library` namespace is that of the official images; you already saw that full name in Lesson 2, in `naming to docker.io/library/…`). For an image that only lives on your machine, two parts are enough:

- the **repository**, which says what it is: `curso-docker-revisor`;
- the **tag**, after the colon, which says which of its versions: `1.0.0`.

The same documentation says something worth underlining: "if no tag is given, Docker uses `latest`". That is, `latest` does **not** mean "the newest". It means "they did not give it a tag". An image built two years ago without a tag is called `latest` just like one from today. In the scene at the beginning, had the images been called `revisor:latest`, you could not even have known which version was running when the problem started.

Tags, besides, are **nicknames that move**. Look at the base image's line on Docker Hub: the same content carries at the same time the tags `1.27.3-trixie`, `1.27-trixie`, `1-trixie` and `trixie` ([golang on Docker Hub](https://hub.docker.com/_/golang)). When Go 1.27.4 comes out, `1.27-trixie` will point to something else and `1.27.3-trixie` will stay where it is. That is why this lesson's `FROM` uses the most specific tag there is. Not even that is an absolute guarantee, because whoever publishes can push a tag again: the best practices guide warns that "image tags are mutable" and that to really pin a version you have to use its fingerprint (*digest*) ([best practices](https://docs.docker.com/build/building/best-practices/)). The course plan leaves that step for Lesson 5; here it is enough not to use `latest`.

#### 3.3.2 Why `curso-docker-revisor` and not `revisor`

The course plan, in its lesson table, already says that here you build `curso-docker-revisor:1.x.0` and not `revisor`. It is worth stopping at that prefix, because it is a lesson in itself: **the course prefix**.

Since Lesson 0, everything the course creates on your machine starts with `curso-docker-`: the containers, the networks, the volumes and, from now on, the images. That prefix does three things for you:

1. **It avoids clashes.** `revisor` is a name anyone would use. If your machine already has a `revisor:1.0.0` image from another project (from another Hábil course, say), your `docker build -t revisor:1.0.0` takes the name away from it without asking: the old image is left without a tag and the new one takes its place. It is not hypothetical: on the machine where this lesson was run there was already an image called `revisor:1.0.0`, from another project, which has nothing to do with this Dockerfile. With the prefix, the two coexist.
2. **It lets you clean up only what is yours.** Docker's filters work by name. `docker ps -a --filter name=curso-docker-` lists only the course's containers, and `docker image ls --filter reference='curso-docker-*'` only its images (the form that the [`docker image ls` reference](https://docs.docker.com/reference/cli/docker/image/ls/) describes for wildcards). Deleting "everything from the course" becomes a safe command, which does not touch the databases or the images of other projects you may have on the same machine.
3. **It says where it came from.** Six months from now, when you clean up and find `curso-docker-revisor:1.0.0`, you will know what it is without investigating.

The `revisor`'s versioning rule in this course is simple: every time a lesson changes the image, the version goes up. This one is `1.0.0`: the first that works completely. When the Dockerfile changes, the tag is not reused; another is created.

> [!NOTE]
> 🔧 **Engineering observation 3.2**
> An image name is a promise: "this is such-and-such, in such-and-such a version". `latest` promises nothing, and a name without a prefix promises something that another project may also be promising. Both mistakes are paid for on the day you need to know what is running, which is usually the worst day to find out.

### 3.4 `USER`: the first Dockerfile no longer runs as `root`

#### 3.4.1 What happens if you say nothing

In Lesson 0 you saw that `root` inside a container is user 0 of the same kernel, with fourteen capabilities enabled. Now the concrete question: if your Dockerfile says nothing about the user, who does the `revisor` run as? It depends on the base image. `fig03_02.sh` asks the Go image:

```bash
#!/usr/bin/env bash
# fig03_02.sh — Sin USER, la imagen base corre como root.
# Pregunta con qué usuario arranca la imagen de Go que usa el revisor, y compara
# con un usuario sin privilegios elegido por número.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
IMAGEN=golang:1.27.3-trixie
docker pull -q "$IMAGEN" >/dev/null

echo "== 1. Lo que la imagen base declara como usuario (vacío = root)"
docker image inspect --format 'User="{{.Config.User}}"' "$IMAGEN"

echo
echo "== 2. Quién soy dentro, sin decir nada"
docker run --rm --name "${PREFIJO}quien" "$IMAGEN" id

echo
echo "== 3. Quién soy dentro, con el usuario 10001:10001"
docker run --rm --name "${PREFIJO}quien" --user 10001:10001 "$IMAGEN" id

echo
echo "== 4. ¿Existe ese usuario en /etc/passwd de la imagen?"
docker run --rm --name "${PREFIJO}quien" "$IMAGEN" \
  sh -c 'grep -q ":10001:" /etc/passwd && echo "sí está" || echo "no está"'

echo
echo "== 5. ¿Puede ese usuario abrir un puerto bajo? (primer puerto sin privilegios)"
docker run --rm --name "${PREFIJO}quien" --user 10001:10001 "$IMAGEN" \
  cat /proc/sys/net/ipv4/ip_unprivileged_port_start

echo
echo "== 6. Lo mismo con la red del anfitrión (--network host)"
docker run --rm --name "${PREFIJO}quien" --network host --user 10001:10001 "$IMAGEN" \
  cat /proc/sys/net/ipv4/ip_unprivileged_port_start

echo
echo "== 7. Y el valor del propio anfitrión (sin contenedor)"
cat /proc/sys/net/ipv4/ip_unprivileged_port_start
```

```text
$ ./fig03_02.sh
== 1. Lo que la imagen base declara como usuario (vacío = root)
User=""

== 2. Quién soy dentro, sin decir nada
uid=0(root) gid=0(root) groups=0(root)

== 3. Quién soy dentro, con el usuario 10001:10001
uid=10001 gid=10001 groups=10001

== 4. ¿Existe ese usuario en /etc/passwd de la imagen?
no está

== 5. ¿Puede ese usuario abrir un puerto bajo? (primer puerto sin privilegios)
0

== 6. Lo mismo con la red del anfitrión (--network host)
0

== 7. Y el valor del propio anfitrión (sin contenedor)
0
```

This output is stable. The first time, `docker pull` downloads the Go image, which weighs hundreds of megabytes; be patient. `--user` does at run time the same thing `USER` does in the Dockerfile, and here it is used to test the user without building anything.

Read it from top to bottom. The base image declares an empty user, and empty means `root`: block 2 confirms it, with `uid=0(root)`. A Dockerfile that starts from `golang` and says nothing inherits that, and the `revisor` would serve network requests as your kernel's user 0. With user 10001, block 3 says `uid=10001 gid=10001`, **with no name in parentheses**. And block 4 explains why: that user does not exist in the image's `/etc/passwd`.

#### 3.4.2 A number is enough

That is correct, and it is on purpose. For the kernel, a user is a number; the name is a convenience that lives in `/etc/passwd`. The `USER` reference accepts a name or a number, in the form `USER <UID>[:<GID>]` ([reference, `USER`](https://docs.docker.com/reference/dockerfile/#user)), and writing both numbers has two advantages. The first: there is no need to create the user in the image. That is enough for the `revisor`, which does not ask for its name or its home folder; a program that does will find that its home folder is `/`, where it cannot write (it is what you will see in Solution 1). For those cases the user is created in the image, or a base that already has one is used, like Lesson 5's `nonroot`. The second: the group is fixed; if you give a user without a group and that user has no primary group, the reference warns that the process runs with `root`'s group. With `10001:10001` there are no surprises.

Why 10001? Because it is far from the numbers distributions use for their own users and for the team's people (on Mint, your user is usually 1000). A high, dedicated number reduces the chance that the container's process coincides with a real user of the host.

The best practices guide asks for it bluntly: "if a service can run without privileges, use `USER` to change to a non-`root` user" ([best practices, `USER`](https://docs.docker.com/build/building/best-practices/#user)). The `revisor` needs nothing from `root`: it listens on 8080, a high port, and writes to no system folders. (Ports below 1024 are the ones that, on Linux, require `root` or a special capability; the first one that does not is in `net.ipv4.ip_unprivileged_port_start`, which by default is 1024 and is a value **per network namespace** ([kernel documentation](https://docs.kernel.org/networking/ip-sysctl.html)). Inside a Docker container with its own network, that value comes as 0: block 5 of `fig03_02.sh` measured it and it gave `0`, which means any port can be opened without privileges. But that is not a law: with `--network host` the container shares the host's network and sees **the host's value**. On this lesson's machine that value is also 0 (the virtual machine sets it that way), so blocks 5, 6 and 7 give `0` and do not tell the cases apart; on a freshly installed Mint you should see `0` in 5 and `1024` in 6 and 7. That difference was not measured here.) So from the first Dockerfile it runs as 10001. The course plan puts it like this: security is not a lesson, it is a habit.

### 3.5 The context and `.dockerignore`

#### 3.5.1 What travels ends up inside

Now the dangerous ingredient: `COPY . .`. It copies the **whole** context. In a real project, the folder holds more than code: a `.git` with the history, a `.env` with passwords for testing on your machine, a `.tar` backup you left there last week. `fig03_04.sh` builds the `revisor` with this lesson's Dockerfile and a **fake** `.env` file in the folder, first without a `.dockerignore` and then with one, and looks at what ended up in `/src` inside the image:

```bash
#!/usr/bin/env bash
# fig03_04.sh — Lo que viaja en el contexto acaba dentro de la imagen.
# Construye el revisor con un archivo .env de mentira en la carpeta: primero SIN
# .dockerignore y después CON el de fig03_03. Mira qué quedó en /src cada vez.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
SIN="${PREFIJO}revisor:1.0.0-sin-ignore"
CON="${PREFIJO}revisor:1.0.0-con-ignore"
trap 'docker rmi -f "$SIN" "$CON" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + el Dockerfile de la lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/fig03_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
# Un secreto DE MENTIRA, como el que cualquiera deja en la carpeta del proyecto.
echo 'REVISOR_TOKEN=curso-docker-env-de-mentira-3c1d' > .env

echo "== 1. SIN .dockerignore: lo que hay en /src dentro de la imagen"
docker build -q -t "$SIN" . >/dev/null
docker run --rm --name "${PREFIJO}mira" "$SIN" ls -A /src
echo "-- y el .env, leído desde la imagen:"
docker run --rm --name "${PREFIJO}mira" "$SIN" cat /src/.env

echo
echo "== 2. CON .dockerignore: lo que hay en /src dentro de la imagen"
cp "$AQUI/fig03_03.dockerignore" .dockerignore
docker build -q -t "$CON" . >/dev/null
docker run --rm --name "${PREFIJO}mira" "$CON" ls -A /src
```

```text
$ ./fig03_04.sh
== 1. SIN .dockerignore: lo que hay en /src dentro de la imagen
.env
Dockerfile
cmd
go.mod
internal
-- y el .env, leído desde la imagen:
REVISOR_TOKEN=curso-docker-env-de-mentira-3c1d

== 2. CON .dockerignore: lo que hay en /src dentro de la imagen
cmd
go.mod
internal
```

This output is stable. The script works in a temporary folder (`mktemp -d`) so as not to dirty `programas/revisor/`, which is the code the course delivers and which is not edited, and it deletes its two images on exit. `docker build -q` builds quietly (*quiet*); `ls -A` also lists files that start with a dot. The two builds take the same as a normal one, because each compiles again: in this lesson's run, the whole script took a little over a minute, with the base image already downloaded.

Look at the first block. The `.env` got into the image and can be read with a `cat`. Anyone who has the image —your teammate, the server, a public registry if you ever push it— also has that secret. And you do not need to run the image to extract it: it is enough to save it to a file and open it. The `Dockerfile` itself also got in, which is of no use inside. In the second block, with the `.dockerignore`, `/src` has only what the program needs in order to compile: `cmd`, `go.mod` and `internal`.

#### 3.5.2 The lesson's `.dockerignore`

This is the file. It is called exactly `.dockerignore`, with the dot, and goes at the root of the context, next to the `Dockerfile`:

```text
# fig03_03.dockerignore
# Lo que no entra a la imagen. (El Dockerfile y este archivo sí viajan al
# constructor porque los necesita, pero COPY no los mete en la imagen.)
.git
.env
*.tar
Dockerfile*
.dockerignore
```

Each line is a pattern, similar to *shell* wildcards; lines with `#` are comments ([Docker, "Build context", `.dockerignore` files](https://docs.docker.com/build/concepts/context/#dockerignore-files)). The documentation says where it is looked for: the client looks for a file called `.dockerignore` "in the root directory of the context". Each line has its reason:

- **`.git`**: the project's complete history. It can weigh much more than the code and can hold secrets that someone deleted from the code but not from the history.
- **`.env`**: the place where people keep passwords for testing on their machine. It is exactly the file in the figure.
- **`*.tar`**: backups and exported files that stay in the folder without anyone remembering. Mind the scope: this pattern only reaches the `.tar` files at the root of the context; one inside a subfolder keeps traveling. It was checked with `fig03_13.sh` (below). To exclude them at any level, the pattern is `**/*.tar`.
- **`Dockerfile*` and `.dockerignore`**: the recipe does not have to be inside the dish. And then how does Docker build, if you exclude the Dockerfile? The documentation answers: those two files "are sent to the builder anyway, because it needs them to build"; what the pattern prevents is `COPY` from putting them into the image. The asterisk in `Dockerfile*` also reaches the `Dockerfile.forma-shell` of 3.7.

`fig03_13.sh` measures it with a `.tar` at the root and another in `respaldos/`, and lists those that reached the image:

```bash
#!/usr/bin/env bash
# fig03_13.sh — Dónde alcanza un patrón de .dockerignore: «*.tar» contra «**/*.tar».
# Construye una imagen mínima con un .tar en la raíz y otro en una subcarpeta, y
# lista los .tar que llegaron adentro. Borra lo que crea.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}ctx:1.0.0-tar"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT
cd "$TRABAJO"
mkdir respaldos
touch raiz.tar respaldos/enero.tar
printf 'FROM golang:1.27.3-trixie\nCOPY . /ctx\n' > Dockerfile

muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

echo '*.tar' > .dockerignore
echo "## .dockerignore con: *.tar"
docker build -q -t "$IMAGEN" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mira $IMAGEN find /ctx -name '*.tar'"

echo
echo '**/*.tar' > .dockerignore
echo "## .dockerignore con: **/*.tar"
docker build -q -t "$IMAGEN" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mira $IMAGEN find /ctx -name '*.tar'"
```

```text
$ ./fig03_13.sh
## .dockerignore con: *.tar
$ docker run --rm --name curso-docker-mira curso-docker-ctx:1.0.0-tar find /ctx -name '*.tar'
/ctx/respaldos/enero.tar

## .dockerignore con: **/*.tar
$ docker run --rm --name curso-docker-mira curso-docker-ctx:1.0.0-tar find /ctx -name '*.tar'
```

With `*.tar`, the one at the root stayed out and `respaldos/enero.tar` got into the image; with `**/*.tar`, neither did. This output is stable.

A reading detail: a line that starts with `!` makes an exception ("this one yes, even if an earlier pattern excludes it"), and when several patterns match a file, the last one wins. You do not need it today, but you will see it in other people's projects.

> [!NOTE]
> 🔧 **Engineering observation 3.3**
> `.dockerignore` is a list of what does **not** travel. That means that everything you forget to put on it, travels. That is why a project's first Dockerfile already carries its `.dockerignore`, even if today the folder is clean: the folder is not going to stay clean, and the day someone leaves a `.env` there, the file will already be waiting for it.

### 3.6 Building, failing and running

#### 3.6.1 Building

With the `Dockerfile` and the `.dockerignore` in the `revisor`'s folder, the build is a single command. `fig03_05.sh` assembles the project in a temporary folder, builds, triggers the first error, runs the service properly, queries it and stops it:

```bash
#!/usr/bin/env bash
# fig03_05.sh — Construir el revisor, verlo fallar sin configuración, correrlo
# bien y detenerlo. CMD en forma exec. Borra lo que crea al salir.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
LIMITES="--memory 64m --cpus 0.5 --pids-limit 50"   # los tres límites de la Lección 2
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
cd "$TRABAJO/revisor"

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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'docker rm -f ${PREFIJO}revisor >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0 >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construir y medir"
muestra "docker build -q -t ${PREFIJO}revisor:1.0.0 . >/dev/null && docker image ls ${PREFIJO}revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "El error: arrancar sin configuración"
muestra "docker run --name ${PREFIJO}revisor ${LIMITES} ${PREFIJO}revisor:1.0.0"
muestra "docker ps -a --filter name=${PREFIJO}revisor --format '{{.Names}} {{.Status}}'"
docker rm ${PREFIJO}revisor >/dev/null

titulo "Correrlo bien"
muestra "docker run -d --name ${PREFIJO}revisor -p 127.0.0.1:${PUERTO}:8080 ${LIMITES} -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0 >/dev/null"
esperar_http "http://127.0.0.1:${PUERTO}/salud"
muestra "curl -s http://127.0.0.1:${PUERTO}/salud"
muestra "curl -s 'http://127.0.0.1:${PUERTO}/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'"
muestra "docker exec ${PREFIJO}revisor id"
muestra "docker top ${PREFIJO}revisor -o pid,user,args"

titulo "docker stop con forma exec"
inicio=$(t); docker stop ${PREFIJO}revisor >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms"
muestra "docker logs ${PREFIJO}revisor"
```

The script is long because of the helpers at the beginning, which you will recognize in the following ones: `muestra` prints each command with a `$` in front before running it, so that in the output you know what produced what, and if the command fails, it records its exit code instead of stopping the script; `t` gives the time in milliseconds for timing; `esperar_http` asks for the service's health until it answers, because a freshly started container takes a moment to listen. The first part of the output:

```text
## Construir y medir
$ docker build -q -t curso-docker-revisor:1.0.0 . >/dev/null && docker image ls curso-docker-revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

**1.45 GB.** The compiled `revisor` is a single file of a few megabytes; everything else is what the base image brings: a whole Debian, the Go compiler and its tools, plus what the compilation left in the image. None of that is needed to **run** the `revisor`, only to **build** it. Note the number in your logbook: it is the starting point, and the course plan devotes Lesson 5 to bringing it down. On your machine the number may vary a little depending on the architecture.

#### In your folder: the image that stays

The course scripts work in temporary folders and **delete what they create** on exit: they are for seeing and measuring, not for leaving you anything. Your project, on the other hand, has to stay, because Lesson 4 starts from it. From the root of the course repository, assemble your folder and build the image you are going to keep:

```bash
mkdir -p ~/curso-docker/revisor
cp -R programas/revisor/. ~/curso-docker/revisor/
cp programas/03-primer-dockerfile/estado/Dockerfile \
   programas/03-primer-dockerfile/estado/.dockerignore ~/curso-docker/revisor/
cd ~/curso-docker/revisor
ls -A
docker build -q -t curso-docker-revisor:1.0.0 .
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

```text
$ ls -A
.dockerignore
Dockerfile
cmd
go.mod
internal
$ docker build -q -t curso-docker-revisor:1.0.0 .
sha256:1eb7de835928…
$ docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

The `sha256:…` that `docker build -q` prints is the image's identifier on your machine and changes with every build; it was trimmed here. (The fingerprint used to pin a base, the one from 3.3.1, is the one the registry publishes; Lesson 5 uses it.) This output is from `fig03_09.sh`, which does these same commands in a temporary folder and with the tag `curso-docker-revisor:1.0.0-carpeta` (and the run prefix from "About the runs"), so as not to touch yours; here it is shown with the tag you are going to use, and it is saved as is in `fig03_09.salida.txt`. The order in which `ls -A` lists the files may vary with your system's language. The `cp -R programas/revisor/. …` copies the *contents* of the folder, so repeating it does not nest a `revisor/revisor`. This is `fig03_09.sh`, in case you want to see how the run was assembled:

```bash
#!/usr/bin/env bash
# fig03_09.sh — «En tu carpeta»: armar la carpeta del revisor y construir la imagen
# que se queda. Aquí se hace en una carpeta temporal y con la etiqueta 1.0.0-carpeta,
# para no tocar tu ~/curso-docker ni tu curso-docker-revisor:1.0.0. Borra lo que crea.
set -euo pipefail
# Nombres por omisión: los del curso. Se pueden cambiar para no chocar con otra
# corrida en el mismo equipo (PREFIJO=... ./fig03_09.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:1.0.0-carpeta"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# muestra: imprime el comando con «$ » y lo ejecuta (salida y error juntos)
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

# Los comandos del bloque de la lección, desde la raíz del repositorio del curso;
# la carpeta ~/curso-docker es aquí una carpeta temporal.
cd "$AQUI/../.."
mkdir -p "$TRABAJO/curso-docker/revisor"
cp -R programas/revisor/. "$TRABAJO/curso-docker/revisor/"
cp programas/03-primer-dockerfile/estado/Dockerfile \
   programas/03-primer-dockerfile/estado/.dockerignore "$TRABAJO/curso-docker/revisor/"
cd "$TRABAJO/curso-docker/revisor"

muestra "ls -A"
muestra "docker build -q -t $IMAGEN ."
muestra "docker image ls ${PREFIJO}revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

From now on, when the lesson says "in the `revisor` folder", it means `~/curso-docker/revisor`, and **this** `curso-docker-revisor:1.0.0` is the one that stays on your machine when you finish. You can type the commands in 3.6.2 and 3.6.3 exactly as written there, with a caution stated in each one: only one container at a time can have the name `curso-docker-revisor`.

#### 3.6.2 The first error: starting without configuration

```text
## El error: arrancar sin configuración
$ docker run --name curso-docker-revisor --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-revisor:1.0.0
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]
$ docker ps -a --filter name=curso-docker-revisor --format '{{.Names}} {{.Status}}'
curso-docker-revisor Exited (1) Less than a second ago
```

The image is fine; the container started and the `revisor` refused to work. The `revisor` is configured through environment variables, and the only mandatory one is `REVISOR_SERVICIOS`, the list of services it must check. Without it, it prints what is missing, with an example, and exits with code 1. `docker ps -a` shows it as `Exited (1)`: the process ended on its own, with an error of its own. Compare it with the 137 from Lesson 0: there, someone killed the process; here, the process decided to leave. Knowing how to read that difference saves you from looking for the problem in the wrong place. Notice also that the container was left created even though it ended: the script deletes it with `docker rm` before going on, because the name is taken. If you type the commands yourself, do the same before moving on to 3.6.3: `docker rm curso-docker-revisor`.

#### 3.6.3 Running it properly

```text
## Correrlo bien
$ docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --memory 64m --cpus 0.5 --pids-limit 50 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.0.0 >/dev/null
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"desarrollo"}
$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <tiempo>  200
$ docker exec curso-docker-revisor id
uid=10001 gid=10001 groups=10001
$ docker top curso-docker-revisor -o pid,user,args
PID                 USER                COMMAND
2246176             10001               revisor
```

The process number changes on every run; everything else is stable, except for the time in the table: the command's `sed` is there to mask it when it comes out in milliseconds, and in this run it came out that way, which is why you see `<tiempo>` (in another run it may come out `0s`, and then there is nothing to mask).

`-p 127.0.0.1:8080:8080` and the three limits (`--memory 64m --cpus 0.5 --pids-limit 50`) are Lesson 2's habits, put in from the `revisor`'s first container: the port only for your machine and a cap on memory, CPU and processes. Those numbers are Lesson 2's, not a measurement of the `revisor`; if more is needed later on, it is measured and raised. `-e` passes an environment variable to the container. Here the `revisor` checks **itself**: the list has a single service, `propio`, which points at its own health. It is a way of checking that everything works without another container, because connecting containers to each other is a subject for networks and the course plan leaves it for Lesson 8. The table says `OK` and `200`.

`/salud` answers `"version":"desarrollo"`. It is not an error: the image was built without stamping a version into the program, and the `revisor` is made to give that away. Mind the difference: the **image** has the tag `1.0.0`, but the **program** inside does not know which version it is. They are two different things, and joining them is the job of a later lesson.

Now the last two lines, which are the important ones of this section. `docker exec ... id` says `uid=10001`: the Dockerfile's `USER` worked. And `docker top`, which lists a container's processes as seen from the host, shows **a single process**: `revisor`, owned by user 10001. That single line is just the *exec* form working. Keep it in mind, because in the next section you will see one with **two** lines. When you finish testing: `docker stop curso-docker-revisor && docker rm curso-docker-revisor`, so that the name is free and `docker ps -a` is clean.

### 3.7 *Exec* form versus *shell* form

#### 3.7.1 Two ways of writing the same thing

`CMD` (and also `RUN` and `ENTRYPOINT`, `CMD`'s sister instruction that sets the image's main program and which you will use from Lesson 5) can be written in two ways ([Dockerfile reference, *shell* and *exec* forms](https://docs.docker.com/reference/dockerfile/#shell-and-exec-form)):

- ***Exec* form**: a list in JSON format, with brackets and double quotes: `CMD ["revisor"]`. Docker starts that program directly, with nothing in between.
- ***Shell* form**: plain text: `CMD revisor`. Docker wraps it in a *shell*; on Linux, in `/bin/sh -c "revisor"`. The reference puts it like this: unlike the *exec* form, instructions in *shell* form "always use a shell".

The *shell* form exists for a reason: with a *shell* in the middle you can use variables (`$HOME`), pipes (`|`) and chain commands (`&&`). That is why it is used a lot in `RUN`s and it is fine to use it there. The problem appears when you use it for the container's **main** process, the one `CMD` starts.

To see it, the lesson brings a copy of the Dockerfile in which only the last line changes. It exists only for comparison:

```dockerfile
# syntax=docker/dockerfile:1
# fig03_06.Dockerfile — Lección 3: la MISMA imagen, pero con CMD en forma shell. Existe solo para
# comparar: así NO se escribe.
FROM golang:1.27.3-trixie
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
USER 10001:10001
EXPOSE 8080
CMD revisor
```

In the project it is saved as `Dockerfile.forma-shell`, and built with `docker build -f Dockerfile.forma-shell`: the `-f` option tells Docker which recipe to use when it is not the one called `Dockerfile`.

#### 3.7.2 The measurement

First, the half you have already seen: the end of `fig03_05.sh`, which stops the container with the *exec* form and shows its logs:

```text
## docker stop con forma exec
tardó 562 ms
$ docker logs curso-docker-revisor
revisor desarrollo escuchando en :8080 (1 servicio(s))
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /api/estados 200 1ms
revisor: recibí terminated, apagando
revisor: apagado limpio
```

The times (562 ms, and the `0s` and `1ms` of each request) change on every run; the sequence of lines is stable, although the number of `GET /salud` depends on how many times `esperar_http` asked before the service answered. The two final lines are the ones that matter: the `revisor` **received** the signal (`terminated` is the name Go gives `SIGTERM`), finished what it was doing and said goodbye. All in 562 milliseconds in this run, with the machine heavily loaded.

Now the other half. `fig03_07.sh` builds the image with the *shell* form, runs it with the same configuration, looks at its processes and stops it:

```bash
#!/usr/bin/env bash
# fig03_07.sh — La MISMA imagen con CMD en forma shell: quién es el PID 1,
# cuánto tarda docker stop y con qué código muere. Borra lo que crea al salir.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
LIMITES="--memory 64m --cpus 0.5 --pids-limit 50"   # los tres límites de la Lección 2
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
cd "$TRABAJO/revisor"

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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'docker rm -f ${PREFIJO}revisor-shell >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0-shell >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "docker stop con forma shell"
docker build -q -t ${PREFIJO}revisor:1.0.0-shell -f Dockerfile.forma-shell . >/dev/null
docker run -d --name ${PREFIJO}revisor-shell ${LIMITES} -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0-shell >/dev/null
sleep 1
muestra "docker top ${PREFIJO}revisor-shell -o pid,user,args"
inicio=$(t); docker stop ${PREFIJO}revisor-shell >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${PREFIJO}revisor-shell"
muestra "docker logs ${PREFIJO}revisor-shell"
```

The helpers at the beginning are the same as in `fig03_05.sh`. The tag `1.0.0-shell` and the name `curso-docker-revisor-shell` are support items: they live only as long as the script lasts.

```text
## docker stop con forma shell
$ docker top curso-docker-revisor-shell -o pid,user,args
PID                 USER                COMMAND
2254874             10001               /bin/sh -c revisor
2254924             10001               revisor
tardó 10365 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor-shell
ExitCode=137
$ docker logs curso-docker-revisor-shell
revisor desarrollo escuchando en :8080 (1 servicio(s))
```

The process numbers change; the time changes by a few hundred milliseconds, but it always ends up **a little above 10 seconds**; `ExitCode=137` and the one-line log are stable. It is the scene at the beginning, in full.

#### 3.7.3 What happened: the signal that did not arrive

Put the two `docker top` outputs side by side. With the *exec* form there was **one** process, `revisor`. With the *shell* form there are **two**: `/bin/sh -c revisor` and, as its child, `revisor`. The *shell* started first, so the *shell* is the container's process number 1 (remember Lesson 0: inside the container, the main program is number 1). The `revisor` was left as its child.

Now, the `docker stop` chain, according to its documentation: it sends the container's main process the `SIGTERM` signal, waits for a deadline that by default is **10 seconds** on Linux, and if the process is still alive, it sends `SIGKILL` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)). The "main process" is number 1. With the *exec* form, number 1 is the `revisor`, which is written to handle `SIGTERM`: it receives it, shuts down in an orderly way and exits. With the *shell* form, number 1 is `/bin/sh`.

Here two facts come together. The first: the *shell* does not forward the signal to its child. The explanation of the `JSONArgsRecommended` rule says it verbatim: with the *shell* form, the program "runs as a child process of a shell, which does not pass signals along" ([Docker, `JSONArgsRecommended`](https://docs.docker.com/reference/build-checks/json-args-recommended/)). The Dockerfile reference says it of `ENTRYPOINT`'s *shell* form in so many words: the executable "will not be the container's PID 1 and will not receive Unix signals" ([reference, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). The second fact is the kernel's and is subtler: process number 1 of a process namespace is special. `docker stop` sends the signal from outside the container, from the host's namespace, which is the container's "ancestor". For that case, the Linux manual says that process number 1 only receives the signals for which it has established a handler, and that `SIGKILL` and `SIGSTOP` are the exception: those two "are forcibly delivered" when they come from an ancestor namespace ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). The *shell* did not install a handler for `SIGTERM`, so the signal does not even kill it: it is lost.

With that, the output reads itself:

1. `docker stop` sends `SIGTERM` to number 1, the *shell*. It is lost. The `revisor`, underneath, never finds out.
2. Ten seconds pass. That is almost all the time you measured: 10,365 ms is the 10,000 of the deadline plus what Docker and the kernel take (with the machine loaded).
3. `docker stop` sends `SIGKILL`, which, according to the signals manual, "cannot be caught, blocked, or ignored" ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)). The *shell* and the `revisor` die at once.
4. Docker records `ExitCode=137`. You already know how to read it since Lesson 0: 128 plus 9, and 9 is `SIGKILL`'s number.
5. The log has a single line. It does not say `recibí terminated` because the `revisor` received nothing, and it does not say `apagado limpio` because it did not shut down: it was killed in the middle of what it was doing. If at that instant it was writing a report, the report was left half-written.

Notice that the `revisor`'s code is exactly the same in both images. It knows how to shut down: it demonstrated it in a few tenths of a second. What changed is that, with a *shell* in the middle, the signal never reached it. And it is not worth finding out how each base image's *shell* behaves: with the *exec* form there is no *shell* in the middle and the question disappears.

Lessons 0 and 2 left you this problem noted for later. Here you saw the half that depends on the Dockerfile: the *exec* form puts your program as process number 1. Lesson 7 brings the other half: what obligations that process number 1 has toward the processes it creates (`--init`), how to change the signal with `STOPSIGNAL` and how to measure shutdown together with health.

> [!NOTE]
> 🔧 **Engineering observation 3.4**
> Ten seconds seem like little. Multiply them: an update that stops twenty containers one after another loses more than three minutes waiting, and in each one what it was doing gets cut off. And the 137 pollutes your alarms: if every normal shutdown ends in 137, the day a container really dies from lack of memory, with the same 137, nobody is going to notice.

#### 3.7.4 When you do need a *shell*

Sometimes the startup needs something only a *shell* gives, such as reading a variable. The same rule page gives two ways out that remain honest: writing a small startup script and calling it in *exec* form, or declaring the *shell* on purpose with the `SHELL` instruction. In both cases the program is once again a child of a *shell* and the signal is once again your responsibility, for example with `exec` at the end of the script, which replaces the *shell* with your program. The `revisor` needs none of that: it reads its variables itself. The practical rule of this course ends up like this: **`CMD` and `ENTRYPOINT`, always in *exec* form**.

### 3.8 Checking before building: `docker build --check`

What you have just measured with a stopwatch, Docker can detect by reading the recipe, without building anything. `docker build --check` runs the **build checks**: rules that look for common errors in the Dockerfile. The documentation says that, instead of executing the build steps, the command "only runs the checks and reports what it finds", and that they exist since version 1.8 of the Dockerfile syntax and Buildx 0.15.0 ([Docker, "Build checks"](https://docs.docker.com/build/checks/)). Your Docker ships a much newer version. `fig03_08.sh` checks the lesson's two Dockerfiles:

```bash
#!/usr/bin/env bash
# fig03_08.sh — Revisar los dos Dockerfile ANTES de construir, con
# docker build --check. No construye nada ni crea contenedores.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
cd "$TRABAJO/revisor"

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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'rm -rf "$TRABAJO"' EXIT

titulo "Revisar el Dockerfile antes de construir"
muestra "docker build --check ."
muestra "docker build --check -f Dockerfile.forma-shell ."
```

The first, the good one:

```text
## Revisar el Dockerfile antes de construir
$ docker build --check .
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 372B 0.0s done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.0s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie
#4 DONE 0.2s

#5 [internal] load .dockerignore
#5 transferring context: 231B done
#5 DONE 0.0s
Check complete, no warnings found.
```

The times and the long *digest* after `dockerfile:1@sha256:` change (that *digest* is the exact version of the syntax interpreter that Docker used that day); the size in bytes of `transferring dockerfile` and of `transferring context` also change, since they depend on the files' comments. What is stable is the sequence of steps and the last line. The numbered steps are what BuildKit did: load the recipe (`#1`), resolve the interpreter the `# syntax` line asks for (`#2` and `#3`), ask for the base image's metadata without downloading it entirely (`#4`) and read the `.dockerignore` (`#5`). There was no `COPY` or `RUN`: nothing was built. And at the end, `Check complete, no warnings found.`

The second, the *shell*-form one:

```text
$ docker build --check -f Dockerfile.forma-shell .
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile.forma-shell
#1 transferring dockerfile: 355B done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.1s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie
#4 DONE 0.1s

#5 [internal] load .dockerignore
#5 transferring context: 231B done
#5 DONE 0.0s
Check complete, 1 warning has been found!

WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
Dockerfile.forma-shell:10
--------------------
   8 |     USER 10001:10001
   9 |     EXPOSE 8080
  10 | >>> CMD revisor
  11 |     
--------------------
[código de salida: 1]
```

There is the scene at the beginning, found before building. The warning has four parts. The rule's name, `JSONArgsRecommended`, with the address of its explanation. The sentence: "JSON arguments recommended for `CMD` to prevent unintended behavior related to OS signals". The exact place: `Dockerfile.forma-shell:10`. And the line pointed to with `>>>`. Besides, the command exits with **code 1**: the documentation clarifies that, unlike a normal build, with `--check` any violation makes the command end with a non-zero code. That is what makes it useful on a build server: a warning stops the process instead of getting lost on the screen.

A **normal** build (`docker build` without `--check`) also runs these checks and shows the same warning, but it ends successfully and builds the image anyway. It is easy not to see it among hundreds of lines. That is why the habit is to run `--check` beforehand, on purpose. And if you want no build to pass with warnings, the Dockerfile can declare it on its second line, right after `# syntax`, with `# check=error=true`: that way the warning also stops a normal `docker build` ([Docker, "Build checks"](https://docs.docker.com/build/checks/)).

### 3.9 What you will find in old tutorials

You will read other people's Dockerfiles, and some carry things this course does not use. It is worth recognizing them:

- **`MAINTAINER name`.** It declared the image's author. It is deprecated: the reference indicates that `LABEL` is "a much more flexible version" and that it should be used instead, for example `LABEL org.opencontainers.image.authors="..."` ([reference, `MAINTAINER`](https://docs.docker.com/reference/dockerfile/#maintainer-deprecated)).
- **`ADD` to copy local files.** `ADD` does more than `COPY`: it also downloads from the internet and decompresses. That magic is surprising. The best practices guide uses `COPY` for copying and reserves `ADD` for when you really need to bring in something remote ([best practices, `ADD` or `COPY`](https://docs.docker.com/build/building/best-practices/#add-or-copy)). In this course `ADD` is not needed.
- **`FROM something:latest` or `FROM something` without a tag.** You already know why not (3.3).
- **`CMD command` and `ENTRYPOINT command` in *shell* form.** You already know how to measure why not (3.7).
- **Installing `sudo` in the image.** The guide advises against it because of its unpredictable behavior with terminals and signal forwarding. If something needs `root` at build time, it goes before the `USER`; at run time, it should not need it.

## The error you will see

This lesson has three errors, from least to most serious. You have already triggered all three.

**1. The `docker build --check` warning.**

```text
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
Dockerfile.forma-shell:10
```

It reads like this: there is a rule that is not met (`JSONArgsRecommended`); its explanation is at the address; and line 10 of `Dockerfile.forma-shell` is the culprit. It is fixed by changing `CMD revisor` to `CMD ["revisor"]`. If you really need a *shell* at startup, see 3.7.4. What is not done is to ignore the warning because "the image built fine": it builds fine and shuts down badly.

**2. The container that exits with 1 at startup.**

```text
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
curso-docker-revisor Exited (1) Less than a second ago
```

It reads like this: the container started, the program read its configuration, did not find something mandatory and exited on its own with 1. It is not a problem of the image or of Docker. The first question when faced with a just-started `Exited (1)` is always `docker logs <container>`: the cause is almost always there, written by the program itself. It is fixed by passing the variable with `-e`.

**3. The 10-second `docker stop` and code 137.**

```text
tardó 10365 ms
ExitCode=137
```

It reads like this: the main process did not handle `SIGTERM`, the deadline ran out and Docker killed it with `SIGKILL` (137 = 128 + 9). Before blaming the program, look at `docker top <container>`: if the first line is `/bin/sh -c ...`, the signal stayed in the *shell*. It is fixed with `CMD` in *exec* form. There are other possible causes of a 137 —the lack of memory from Lesson 0 is the other big one, and it is told apart because `docker inspect` says `OOMKilled=true`—, but when `docker stop`'s time is exactly the deadline, the main suspect is this one. What you do **not** do is raise `docker stop`'s deadline so that it "is enough": a longer deadline only lengthens the wait, because the signal still does not arrive.

## The security habit of the lesson

**The first Dockerfile already carries `USER`, `.dockerignore` and a tag with a version.** All three are cheap on day one and expensive to add afterwards, when there are already containers running and people who depend on them.

- **`USER 10001:10001`** keeps a bug in the `revisor` —or in any library it uses— from handing whoever exploits it your kernel's user 0. You checked it with `docker exec ... id`.
- **`.dockerignore`** prevents the accident of 3.5: a `.env`, a key or the history of `.git` stuffed into an image that then travels to other machines. You checked it by looking at `/src` inside the image.
- **The tag with a version and the prefix** keep you from running "whatever happens to have that name": you know which image is running and you delete it without touching other people's.

## Common mistakes

**Writing `CMD` in *shell* form "because it is easier to read".** It reads easier and shuts down worse: 10 seconds of waiting and a 137 on every `docker stop`. The *exec* form is two brackets and some quotes.

**Using `latest`, or giving no tag, which is the same thing.** `latest` does not mean "the newest"; it means "no tag". On the day of the problem you will not know which version was running.

**Naming the image with a generic name like `revisor` or `app`.** It clashes with images of other projects on the same machine and takes their name away without warning.

**Leaving the Dockerfile without `USER` because "it is only for testing".** What is for testing tends to end up in production with the same Dockerfile. It costs one line.

**`COPY . .` without `.dockerignore`.** Everything in the folder travels and ends up in the image, including files nobody remembers having left there.

**Using `RUN` to start the service.** `RUN` executes at build time: the build would wait for the server forever. What is executed at run time goes in `CMD`.

**Believing that `EXPOSE` publishes the port.** It only notes it. Without `-p` at run time, nobody from outside gets in. And with `-p`, the port is published on `127.0.0.1`, as you learned in Lesson 2.

**Ignoring the build warnings.** A normal build shows the `JSONArgsRecommended` warning and ends successfully. Running `docker build --check` beforehand turns the warning into an error that cannot be overlooked.

## Exercises

Do them in order. Before running each one, write in your [logbook](bitacora.md) what you think is going to happen; comparing it afterwards is half of the learning. When you finish, delete what you created: everything carries the `curso-docker-` prefix.

### Exercise 1 — At build time or at run time?

Without looking at the table in 3.2.2, classify each line: does it act **at build time**, does it only **note something for running**, or both?

1. `FROM golang:1.27.3-trixie`
2. `COPY . .`
3. `RUN go build -o /usr/local/bin/revisor ./cmd/revisor`
4. `USER 10001:10001`
5. `EXPOSE 8080`
6. `CMD ["revisor"]`

And a trick question: if you change the order and put `USER 10001:10001` **before** the `RUN go build`, which user does the compilation run as?

### Exercise 2 — Your own `.dockerignore` (project)

Work in your folder `~/curso-docker/revisor` (the one from the "In your folder" block in 3.6.1). Set the lesson's `.dockerignore` aside for a moment with `mv .dockerignore ../dockerignore-leccion3` and create three things there: a `.env` file with a fake secret, a `notas.md` file and a `secretos/` folder with a file inside. Build `curso-docker-revisor:1.0.0-ej2` and list `/src` inside the image with `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src`. Then write a new `.dockerignore` that leaves out the three things, in addition to everything the lesson's excluded (you have it in `../dockerignore-leccion3`), rebuild with the same tag and list again. The exercise is self-checking: you are done when `/src` shows exactly `cmd`, `go.mod` and `internal`. At the end, `docker rmi curso-docker-revisor:1.0.0-ej2`. Your extended `.dockerignore` can stay: it excludes everything the lesson's excluded and something more, so your `curso-docker-revisor:1.0.0` does not change.

### Exercise 3 — The stopwatch on your machine

Run `fig03_05.sh` and `fig03_07.sh` on your Mint (after Lesson 1 and with the Go image downloaded). Note in your logbook, on the line that Lesson 3 provides for it, the two `docker stop` times.

A warning before running them: `fig03_05.sh` builds and, on exit, deletes an image called `curso-docker-revisor:1.0.0`, the same name as your own from 3.6.1. So that it does not take it away, run it with a different prefix, which is what the variable exists for: `PREFIJO=curso-docker-ej3- ./fig03_05.sh`. In your output you will read `curso-docker-ej3-revisor` where the lesson says `curso-docker-revisor`; it still starts with `curso-docker-`, so the course cleanup reaches it. If you already ran it without the prefix and your image disappeared, go back to `~/curso-docker/revisor` and rebuild it with `docker build -q -t curso-docker-revisor:1.0.0 .`: it takes seconds, because everything comes from the cache.

Before running them, predict:

1. Which of the two times will change the most from one run to another, and which will stay almost the same?
2. What number will `ExitCode` show in the *shell* form? And what number would you expect in the *exec* form, knowing that the `revisor` is written to end with 0 after a clean shutdown? Check it by adding, after the `docker stop` in `fig03_05.sh`, a `docker inspect --format 'ExitCode={{.State.ExitCode}}' "${PREFIJO}revisor"` (with the prefix above, the container is called `curso-docker-ej3-revisor`).

### Exercise 4 — Fix someone else's Dockerfile

A teammate hands you this Dockerfile for the `revisor`. Find **six** problems, five in the file and one that is missing next to it; say what accident each one can cause and write the corrected version. Then check yours with `docker build --check`: it has to say `Check complete, no warnings found.`

```dockerfile
# ASÍ NO — seis problemas a propósito (Ejercicio 4 de la Lección 3).
FROM golang
MAINTAINER alguien@ejemplo.invalid
COPY . /src
RUN cd /src && go build -o /usr/local/bin/revisor ./cmd/revisor
EXPOSE 8080
CMD revisor
```

Hint: `docker build --check` finds two of the six; the other four you have to find yourself.

## Solutions

### Solution 1

1. **At build time.** It brings in all the contents of the base image.
2. **At build time.** It copies the context's files into the image.
3. **At build time.** It compiles and leaves the executable in the image. It is not executed again at run time.
4. **Both.** It notes the user the container will run as, and it also affects the `RUN`s that come after it in the Dockerfile.
5. **It only notes.** It publishes nothing (3.2).
6. **It only notes** the process each container will start.

The trick question: as user **10001**, because `USER` changes the user of everything that comes after, at build time too. And the compilation fails. Go tries to create its cache in the user's home folder and, since 10001 does not exist in `/etc/passwd`, that folder is `/`, where it cannot write. Measured on this lesson's machine with `fig03_12.sh`, which builds with `docker build --progress=plain` the `fig03_11.Dockerfile` (the lesson's, with `USER` before the `RUN`); the `#10` and the `0.204` are the step number and the seconds, and they change, and between the two lines below the rest of the output is in `fig03_12.salida.txt`:

```text
#10 0.204 failed to initialize build cache at /.cache/go-build: mkdir /.cache: permission denied
ERROR: failed to build: failed to solve: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

Even if the cache worked, it could not write to `/usr/local/bin` either. That is why `USER` goes after compiling.

This is the Dockerfile with the `USER` moved (`fig03_11.Dockerfile`), which exists only to see the failure:

```dockerfile
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
```

And this is `fig03_12.sh`, which builds it and, while at it, checks with `docker build --check` the other person's Dockerfile from Exercise 4 (`fig03_10.Dockerfile`, the same one as above):

```bash
#!/usr/bin/env bash
# fig03_12.sh — Los dos Dockerfile con defectos de la lección: el del Ejercicio 4,
# revisado con docker build --check, y el de la Solución 1 (USER antes del RUN),
# que falla al compilar. No deja imágenes ni contenedores.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los dos Dockerfile con defectos.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_10.Dockerfile" "$TRABAJO/revisor/Dockerfile.ajeno"
cp "$AQUI/fig03_11.Dockerfile" "$TRABAJO/revisor/Dockerfile.user-antes"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

titulo "Ejercicio 4: el Dockerfile ajeno, revisado antes de construir"
muestra "docker build --check -f Dockerfile.ajeno ."

titulo "Solución 1: USER antes del RUN, la compilación falla"
muestra "docker build --progress=plain -f Dockerfile.user-antes ."
```

### Solution 2

A `.dockerignore` that meets the goal:

```text
.git
.env
*.tar
*.md
secretos/
Dockerfile*
.dockerignore
```

With it, `ls -A /src` inside the image shows only `cmd`, `go.mod` and `internal`, just like the second block of `fig03_04.sh`. If your list still shows `notas.md` or `secretos`, check that the pattern is written correctly and that the `.dockerignore` file is at the root of the context, next to the `Dockerfile`, and not in a subfolder. If `.dockerignore` or `Dockerfile` appears, you missed the last two lines. A variant that is also valid is `*.md` changed to `notas.md`: it excludes only that file. The one above is more far-sighted, because the `revisor` does not need any `.md` to compile.

### Solution 3

1. The *exec* form's time changes the most from one run to another (tens or hundreds of milliseconds, depending on how busy your machine is); the *shell* form's stays almost the same, always a little above 10,000 ms, because almost all of it is `docker stop`'s fixed deadline.
2. In the *shell* form, `ExitCode=137`, as in `fig03_07.sh`. In the *exec* form, `ExitCode=0`: the `revisor` receives `SIGTERM`, writes `apagado limpio` and its code ends with 0. If your run gives another number, look at `docker logs`: if `apagado limpio` does not appear, the signal did not arrive, and the first suspicion is that your Dockerfile has the *shell* form.

### Solution 4

The five problems in the file:

1. **`FROM golang` without a tag**, which is `golang:latest`: each build can use a different version of Go. Fix: `FROM golang:1.27.3-trixie`.
2. **`MAINTAINER`**, deprecated. Fix: remove it, or use `LABEL org.opencontainers.image.authors="..."`.
3. **`RUN cd /src && ...` instead of `WORKDIR`.** It works on that line, but the `cd` is lost afterwards, and the container starts in `/`. Fix: `WORKDIR /src` and `COPY . .`.
4. **No `USER`**: the `revisor` would run as `root`. Fix: `USER 10001:10001` after compiling.
5. **`CMD revisor` in *shell* form**: 10 seconds and 137 on every `docker stop`. Fix: `CMD ["revisor"]`. It is exactly what `docker build --check` points to.

And the sixth, the one that is not in the file: **the `.dockerignore` is missing**, and with `COPY . /src` the whole context goes into the image. The corrected version is this lesson's `fig03_01.Dockerfile` plus the `fig03_03.dockerignore`.

`docker build --check` on the original Dockerfile (`fig03_10.Dockerfile`, which `fig03_12.sh` checks) finds two of the six. Measured on this lesson's machine (only the warning lines are shown; the full output is in `fig03_12.salida.txt`):

```text
Check complete, 2 warnings have been found!
WARNING: MaintainerDeprecated - https://docs.docker.com/go/dockerfile/rule/maintainer-deprecated/
Maintainer instruction is deprecated in favor of using label
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
```

`MaintainerDeprecated` is problem 2: the rule says `MAINTAINER` is deprecated and that a label (`LABEL`) should be used in its place ([Docker, `MaintainerDeprecated`](https://docs.docker.com/reference/build-checks/maintainer-deprecated/)). `JSONArgsRecommended` is problem 5. The other four (`latest`, the `cd`, the missing `USER` and the missing `.dockerignore`) are not detected by any of the rules that ran here: that is why `--check` helps but does not replace reading the recipe. Your version has to say `Check complete, no warnings found.`

## How I know I got it

Check each point only if you verified it on your machine:

- [ ] `docker build --check .` in `~/curso-docker/revisor` ends with `Check complete, no warnings found.` and code 0.
- [ ] `docker image ls 'curso-docker-revisor'` shows `curso-docker-revisor` with the tag `1.0.0`, and you noted its size in the logbook (in this lesson's run, 1.45 GB).
- [ ] Without `REVISOR_SERVICIOS`, the container is left `Exited (1)` and `docker logs` says what is missing.
- [ ] With the variable, `curl -s http://127.0.0.1:8080/salud` answers `{"estado":"vivo","version":"desarrollo"}`.
- [ ] `docker exec curso-docker-revisor id` says `uid=10001 gid=10001 groups=10001`.
- [ ] `docker top curso-docker-revisor -o pid,user,args` shows **a single** process, `revisor`.
- [ ] `docker stop curso-docker-revisor` takes less than a second and `docker logs` ends with `revisor: apagado limpio`.
- [ ] With the *shell*-form image you measured the 10 seconds and the 137, and you can explain with `docker top` why.
- [ ] Inside the image, `ls -A /src` shows no `.env`, `.git` or `Dockerfile`.
- [ ] When you finish, `docker ps -a --filter name=curso-docker-revisor` shows nothing, and `docker image ls 'curso-docker-revisor'` shows only `curso-docker-revisor:1.0.0`, the one you built in your folder and which Lesson 4 uses.

## Summary

Answer without looking at the lesson:

1. What is a Dockerfile, what is the context and who does the work of building?
2. Which instructions act at build time and which only note something for running?
3. What does the `latest` tag really mean? Why is the course's image called `curso-docker-revisor:1.0.0` and not `revisor:1.0.0`?
4. Which user does an image run as if nobody wrote `USER`? Why is a number enough?
5. What does `.dockerignore` do and what happens to a `.env` if you do not have one?
6. What is the difference between `CMD ["revisor"]` and `CMD revisor`? What does `docker top` show in each case?
7. Why does `docker stop` take 10 seconds and leave 137 with the *shell* form? What is the 137?
8. What does `docker build --check` do and which code does it exit with if it finds something?

## Sources

All consulted on October 21, 2026.

- [Docker, "Dockerfile overview"](https://docs.docker.com/build/concepts/dockerfile/): what a Dockerfile is.
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/): the instructions `FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`, `ENTRYPOINT` and `MAINTAINER`; the *shell* and *exec* forms; the `syntax` directive.
- [Docker, "Build context"](https://docs.docker.com/build/concepts/context/): the build context and the `.dockerignore` files.
- [Docker, "Build checks"](https://docs.docker.com/build/checks/): `docker build --check`, its exit code and the minimum versions.
- [Docker, `MaintainerDeprecated` rule](https://docs.docker.com/reference/build-checks/maintainer-deprecated/): the warning about `MAINTAINER` in exercise 4.
- [Docker, `JSONArgsRecommended` rule](https://docs.docker.com/reference/build-checks/json-args-recommended/): why the *shell* form does not pass signals along, and the two alternatives when a *shell* is needed.
- [Docker, best practices for building images](https://docs.docker.com/build/building/best-practices/): `USER`, `sudo`, `ADD` versus `COPY`, mutable tags and `.dockerignore`.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM`, the 10-second deadline and `SIGKILL`.
- [`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/): the parts of an image name and the default `latest` tag.
- [Docker, "Running containers"](https://docs.docker.com/engine/containers/run/): replacing the `CMD` from `docker run`.
- [golang on Docker Hub](https://hub.docker.com/_/golang): the `1.27.3-trixie` tag and its nicknames, and the meaning of *trixie*.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions in "About the runs".
- [Linux kernel, "IP Sysctl"](https://docs.kernel.org/networking/ip-sysctl.html): `ip_unprivileged_port_start`, per namespace and with a default value of 1024.
- [`docker image ls`](https://docs.docker.com/reference/cli/docker/image/ls/): the `reference` filter with wildcards.
- [pid_namespaces(7), Linux manual](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html): the signals that process number 1 of a namespace can receive.
- [signal(7), Linux manual](https://man7.org/linux/man-pages/man7/signal.7.html): the numbers of `SIGTERM` (15) and `SIGKILL` (9), and that `SIGKILL` cannot be caught.
- [Colima](https://github.com/abiosoft/colima): the tool used to run the programs on macOS.

### Terms in this lesson

| | |
|---|---|
| **BuildKit** | the image builder Docker uses; it is part of the daemon |
| **build context** | the files the build can use; almost always, a folder |
| **Dockerfile** | the text recipe used to build an image |
| **`.dockerignore`** | the list of what does not travel in the context and cannot get into the image |
| **`ENTRYPOINT`** | an instruction that sets the container's main program; `CMD` gives it default arguments; you use it from Lesson 5 |
| **tag** | the part of an image's name after the colon; it says which version it is |
| ***exec* form** | an instruction written as a JSON list: `CMD ["revisor"]`; it starts the program without a *shell* |
| ***shell* form** | an instruction written as text: `CMD revisor`; it is wrapped by `/bin/sh -c` |
| **base image** | the image another one starts from, the one in `FROM` |
| **`latest`** | the tag Docker adds when none is given; it does not mean "the newest" |
| **PID 1** | a container's first process; the one that receives `docker stop`'s signal |
| **build check** | a rule that looks for common errors in a Dockerfile without building it |
| **`SIGTERM`** | signal 15: "please finish"; the one `docker stop` sends first |
| **`SIGKILL`** | signal 9: immediate death; it cannot be caught; it leaves code 137 |

---

**Next:** [Lesson 4 — Layers, cache, and context](04-capas-cache-contexto.md)
