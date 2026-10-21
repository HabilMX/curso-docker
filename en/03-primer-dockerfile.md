# Lesson 3 — Your First Dockerfile

It is 6:40 on a Friday evening and the window to update the server closes at 7. The plan was simple: stop the old `revisor`, start the new one, go home. You type `docker stop` and the terminal goes silent. One second. Three. Seven. At ten, it finally comes back. You try it on the next copy and again: exactly ten seconds of silence. You check the logs and the line the `revisor` always writes when it shuts down, `apagado limpio`, is missing; the last report was left half-written. Someone on the team finds the container's state and reads it out loud: `ExitCode=137`. Nobody killed it on purpose, and yet it was killed. The culprit is not in the `revisor`'s code, which knows how to shut down properly. It is in a three-word line at the end of its Dockerfile, one that looks harmless and is written that way in many tutorials. This lesson teaches you to write that line, and all the others, knowing what each one does.

**Time:** 2 × 45 min

**What you build:** the first image of the `revisor`, `curso-docker-revisor:1.0.0`, in a single stage, with its `Dockerfile` and its `.dockerignore`. It runs unprivileged, shuts down in a fraction of a second, and carries a version in its name.

**What you learn:** what a Dockerfile is and what each of its basic instructions does (`FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`); the difference between the *exec* form and the *shell* form, measured with a stopwatch; what the build context is and what `.dockerignore` is for; why the first Dockerfile already includes `USER`; how to name and tag an image with a version; and how to check a Dockerfile before building it with `docker build --check`.

**Where you are coming from.** From [Lesson 2](02-contenedores-dia-a-dia.md) you bring a feel for the day to day: you start a container with `docker run`, look at it with `ps`, `logs`, `inspect`, and `exec`, publish its port only on `127.0.0.1`, and delete it without leaving garbage behind. There you built the test service's image with a single command, without asking what was in its Dockerfile. From [Lesson 0](00-que-es-un-contenedor.md) you bring the map: a container is a process; an image is the template it is born from; and code 137 means the kernel killed the process with signal 9. That last idea is going to come back here in a different guise. From the course you also bring the `revisor`'s code, in `programas/revisor/`, just as the course delivers it: an HTTP service written in Go that does not have a Dockerfile yet. You do not need to know Go: you are not going to change a single line of the program.

**What this lesson does not do.** It does not make the image small: the one that comes out of here weighs more than a gigabyte, and that is fine for now, because seeing it big is the best way to understand later why it is worth shrinking it (the course plan leaves that for [Lesson 5](05-multi-stage.md)). Nor does it order the Dockerfile so that rebuilding is fast, or explain the layers one by one: that is the subject of [Lesson 4](04-capas-cache-contexto.md). It does not connect the `revisor` to other containers (which is why, in this lesson, the `revisor` checks itself), and it does not give it health checks or secrets. A single stage, a single image, everything in plain view.

**About the runs.** All outputs are real and were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4, the same base as Linux Mint 22, the course's reference system. The five scripts were run that day from the Mac's client (Docker 29.8.2) against the daemon of that virtual machine (Docker 29.2.1, Buildx v0.31.1). That same machine was being used by other runs at the same time, so, to avoid collisions, the scripts were launched with a different name prefix and a different port: they have the variables `PREFIJO` (default `curso-docker-`) and `PUERTO` (default `8080`), and they were run with `PREFIJO=curso-docker-l03-` and `PUERTO=18030`. In the outputs of `fig03_05` and `fig03_07`, where names and the port appear, the lesson shows the default values, which are the ones you will see: `curso-docker-revisor` instead of `curso-docker-l03-revisor` and `8080` instead of `18030`; that is the only change, and the `.salida.txt` files keep the run exactly as it was. The outputs of `fig03_02`, `fig03_04`, and `fig03_08` show neither names nor the port and are untouched. Two more things about the Mac: macOS's `date` does not give milliseconds, so the scripts' `t` helper falls back to `python3` when needed (on Mint it is not needed); and the first line of `docker build --check` says `building with "colima" instance`, because that is the name of the Docker context on the Mac; on your Mint it will say `"default"`. The course was planned with Docker Engine 29.8.2, and the most recent version published that day was 29.9.2, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)); nothing in this lesson changes between those versions. What **does** change on your Mint, and is flagged where it appears: the process numbers (PIDs), the build and shutdown times (the ones in this lesson also include the round trip between the Mac and its virtual machine, so on your Mint they should come out somewhat lower), and, if your machine is Intel or AMD, the architecture (`amd64` instead of `arm64`), which is not printed here but does decide which variant of the Go image is downloaded. The programs are in [`programas/03-primer-dockerfile/`](../programas/03-primer-dockerfile), each with its output next to it; `estado/` holds the `Dockerfile` and the `.dockerignore` as they stand at the end.

## By the end you will be able to

- Write a single-stage Dockerfile for an existing program and say, line by line, whether that instruction acts when **building** the image or when **running** the container.
- Build an image with a name and a version tag, and explain why the course's `revisor` is called `curso-docker-revisor:1.0.0` and not `revisor` or `revisor:latest`.
- Show with `docker exec ... id` that your container does not run as `root`, and explain what `USER 10001:10001` changes.
- Write a `.dockerignore` and verify, by looking inside the image, that a `.env` file did not make the trip.
- Measure how long `docker stop` takes with `CMD` in *exec* form and in *shell* form, and explain with `docker top` why one takes a fraction of a second and the other a little over 10 s with code 137.
- Run `docker build --check` before building and read the `JSONArgsRecommended` warning.

## The why before the how

In Lesson 2 you worked with an image that was handed to you ready-made. It works, but there is a catch: if you do not know how it was put together, you do not know what it contains or how it is going to behave. Does it run as `root`? Does it carry your configuration files inside? Does it shut down when you ask it to, or does it wait to be killed? Those three questions are not answered by looking at the running container; they are answered by reading its **recipe**.

An image's recipe is called a **Dockerfile**. It is a text file with instructions, one per line, that Docker reads from top to bottom to produce the image. The documentation defines it this way: Docker builds images by reading the instructions from a Dockerfile, "a text file containing instructions for building your source code" ([Dockerfile reference](https://docs.docker.com/reference/dockerfile/)). What matters for you is that the recipe is **reproducible**: the same recipe with the same code yields the same image, today, on Friday at 6:40, and on your teammate's machine. What you called in Lesson 0 "you do not fix an image by getting into the container" has its other half here: you fix an image **by changing its recipe and rebuilding**.

And every line of that recipe is a decision. The opening scene was not caused by a programming error: it was caused by writing `CMD revisor` instead of `CMD ["revisor"]`. They look almost the same. This is the difference you are going to measure in section 3.6, with the same image and the same program:

```text
## docker stop con forma exec
tardó 299 ms

## docker stop con forma shell
tardó 10485 ms
ExitCode=137
```

A few tenths of a second versus ten seconds and a corpse. Those are the numbers from this lesson's run; in another run, done inside the virtual machine and without the trip from the Mac, they came out at 161 ms versus 10,112 ms (10.1 s), with the same `ExitCode=137`. The milliseconds change; the ten seconds and the 137 do not. The lesson has seven parts:

1. **What building is** (3.1): the recipe, the context, and who does the work.
2. **The `revisor`'s Dockerfile, line by line** (3.2).
3. **The name and the tag** (3.3): why `curso-docker-revisor:1.0.0`.
4. **`USER`: not running as `root`** (3.4).
5. **The context and `.dockerignore`** (3.5), with a fake secret that sneaks in.
6. **Building, failing, and running** (3.6), and the ***exec* form versus the *shell* form** (3.7), with the stopwatch.
7. **Checking before building** (3.8) and the old stuff you will find in tutorials (3.9).

## The concepts

### 3.1 What building an image is

#### 3.1.1 The recipe, the ingredients, and the kitchen

Building an image has three pieces, and it is worth separating them from the start because each one fails in a different way:

- **The recipe**: the Dockerfile.
- **The ingredients**: the files the recipe can use. They are called the **build context**, and they are almost always the contents of a folder. In the command `docker build .`, the final dot is that folder: "the context is this folder I am in".
- **The kitchen**: the builder, which in Docker is called **BuildKit** and is part of the daemon. Remember Lesson 0: the `docker` client does not do the work; it asks the daemon to. When building, the client sends it the recipe and the ingredients the recipe asks for, and the daemon cooks.

The build documentation describes it with these same pieces: the context is the set of files the build has access to, and the Dockerfile's instructions can only take files from there ([Docker, "Build context"](https://docs.docker.com/build/concepts/context/)). This has a practical consequence you will use in 3.5: **what is not in the context cannot get into the image**, and what is in the context can get in even if you do not want it to.

#### 3.1.2 Two moments: building and running

There is one idea that organizes everything else in this lesson: a Dockerfile describes **two different moments**.

1. **When building** (`docker build`): Docker starts from a base image, copies files, and runs commands. The result is saved in the image. This happens once, on your machine or on a build server.
2. **When running** (`docker run`): Docker creates a container from that image and starts **one** process. This happens every time someone runs the image, on any machine.

Some instructions act in the first moment and others only **record** what to do in the second. If you confuse the two moments, you write things like a `RUN` that tries to start the server (it would run while building, sit there waiting, and the build would never finish) or you expect an `EXPOSE` to open a port (it only records it). The table in 3.2.2 separates each instruction by moment.

### 3.2 The `revisor`'s Dockerfile, line by line

#### 3.2.1 The complete recipe

This is the Dockerfile the lesson ends with. It goes in the root of the `revisor` project, next to `go.mod`, and it is called exactly `Dockerfile`, with no extension, which is the name `docker build` looks for by default:

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

Twelve lines, seven of which are instructions. Let's go one by one.

**`# syntax=docker/dockerfile:1`.** It looks like a comment, and for almost the entire file it would be, but on the first line it is a **directive**: it tells BuildKit which version of the Dockerfile syntax to use. The reference explains it this way: it is used "to declare the Dockerfile syntax version to use for the build", and it lets you use new features without upgrading Docker ([Dockerfile reference, *syntax*](https://docs.docker.com/reference/dockerfile/#syntax)). The `1` means "the latest version 1". That is why, in the build outputs, you will see Docker first resolve `docker.io/docker/dockerfile:1`: it fetches the recipe's interpreter before reading it. Every Dockerfile in the course starts with this line.

**`FROM golang:1.27.3-trixie`.** Every image starts from another one. `FROM` says which is the **base image**: here, the official Go image at version 1.27.3, built on Debian 13, whose codename is *trixie*. The `revisor` is written in Go, and compiling it requires the Go compiler; this image has it, along with an entire Debian. Docker Hub lists that tag among the Go image's current ones, and clarifies that names like *bookworm* or *trixie* are the codenames of the Debian releases it is built on ([golang on Docker Hub](https://hub.docker.com/_/golang)).

**`WORKDIR /src`.** Sets the working directory inside the image: everything that comes after (`COPY`, `RUN`, `CMD`) happens there. If the directory does not exist, Docker creates it ([reference, `WORKDIR`](https://docs.docker.com/reference/dockerfile/#workdir)). It is better than writing `RUN cd /src`, which does nothing useful: each `RUN` starts afresh, and the `cd` is lost when that line ends.

**`COPY . .`.** Copies from the context (the first dot) to the image's working directory (the second dot, which here is `/src`). It is the only entry point through which your files get into the image. Copying **everything** is the simplest and the most dangerous option: everything in the context gets in. That is why the `.dockerignore` from 3.5 exists. (Copying everything at once also makes rebuilding slow; the course plan covers that in Lesson 4.)

**`RUN go build -o /usr/local/bin/revisor ./cmd/revisor`.** Runs a command **when building** and saves the result in the image. Here it compiles the `revisor` and leaves the executable in `/usr/local/bin/revisor`, a directory that is already in the image's `PATH` variable. That is why, further down, it is enough to write `revisor`, without a path.

**`USER 10001:10001`.** From here on, and above all when running, the process uses user 10001 and group 10001 instead of `root`. It has its own section, 3.4.

**`EXPOSE 8080`.** Records that the program listens on port 8080. It only records it: the reference is clear that `EXPOSE` "doesn't actually publish the port"; to publish it you need `-p` when running ([reference, `EXPOSE`](https://docs.docker.com/reference/dockerfile/#expose)). It serves as documentation for whoever reads the image and for tools that query it. The port is published, as you learned in Lesson 2, with `-p 127.0.0.1:8080:8080`.

**`CMD ["revisor"]`.** Records which process to start **when running** the container. Only one can be in effect: if you write several `CMD`s, the last one wins ([reference, `CMD`](https://docs.docker.com/reference/dockerfile/#cmd)). And it is a default: if you pass `docker run` a command after the image name, that command replaces the `CMD` ([Docker, "Running containers"](https://docs.docker.com/engine/containers/run/)). The brackets and quotes are not decoration: they are the *exec* form, the subject of 3.7.

#### 3.2.2 Each instruction at its moment

| Instruction | When it acts | What it leaves in the image |
|---|---|---|
| `FROM` | when building | the entire contents of the base image |
| `WORKDIR` | when building, and records the directory for running | the directory, and the value of where to start |
| `COPY` | when building | the copied files |
| `RUN` | when building | whatever the command wrote to disk |
| `USER` | records for running (and for any later `RUN`) | the user value |
| `EXPOSE` | only records | the port value; it opens nothing |
| `CMD` | only records | the command each container will start |

Read the third column carefully: the last three instructions do not add files, they add **values** to the image's configuration. You will be able to read them with `docker inspect` and, later on, in the image's history. Keep in mind that order matters: a `USER` placed before a `RUN` makes that `RUN` execute as that user. That is why here `USER` comes after compiling: compilation needs to write to `root`'s directories, the server does not.

> [!NOTE]
> 🔧 **Engineering observation 3.1**
> For every line of a Dockerfile, ask yourself: "does this happen once, when I build, or every time, when someone runs it?". What happens when building can be slow and heavy, because you pay for it only once. What happens when running has to be fast and minimal, because you pay for it on every start, and on a bad day, on every restart.

### 3.3 The name and the tag

#### 3.3.1 The parts of a name

When you build, you name the image with `-t`. An image's full name has this shape, according to the `docker image tag` documentation: `[HOST[:PORT]/]NAMESPACE/REPOSITORY[:TAG]` ([`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/)). For an image that lives only on your machine, two parts are enough:

- the **repository**, which says what it is: `curso-docker-revisor`;
- the **tag**, after the colon, which says which of its versions: `1.0.0`.

The same documentation says something worth underlining: "If you don't specify a tag, Docker uses `latest`". In other words, `latest` does **not** mean "the newest". It means "nobody gave it a tag". An image built two years ago without a tag is called `latest` just like one from today. In the opening scene, if the images had been called `revisor:latest`, you would not even be able to tell which version was running when the problem started.

Tags, moreover, are **aliases that move**. Look at the base image's line on Docker Hub: the same content carries the tags `1.27.3-trixie`, `1.27-trixie`, `1-trixie`, and `trixie` all at once ([golang on Docker Hub](https://hub.docker.com/_/golang)). When Go 1.27.4 comes out, `1.27-trixie` will point to something else and `1.27.3-trixie` will stay where it is. That is why this lesson's `FROM` uses the most specific tag available. Not even that is an absolute guarantee, because the publisher can push a tag again: the best practices guide warns that "image tags are mutable" and that to truly pin a version you have to use its *digest* ([best practices](https://docs.docker.com/build/building/best-practices/)). The course plan leaves that step for Lesson 5; here it is enough not to use `latest`.

#### 3.3.2 Why `curso-docker-revisor` and not `revisor`

The course plan, in the lesson table, says that in this lesson you build `revisor:1.0.0`. Here the image is called `curso-docker-revisor:1.0.0`. The difference is deliberate, and it is a lesson in itself: **the course prefix**.

Since Lesson 0, everything the course creates on your machine starts with `curso-docker-`: containers, networks, volumes and, from now on, images. That prefix does three things for you:

1. **It avoids collisions.** `revisor` is a name anyone would use. If an image `revisor:1.0.0` from another project already exists on your machine (from another Hábil course, for example), your `docker build -t revisor:1.0.0` takes its name without asking: the old image is left without a tag and the new one takes its place. This is not hypothetical: on the machine where this lesson was run there was already an image called `revisor:1.0.0`, from another project, that has nothing to do with this Dockerfile. With the prefix, both coexist.
2. **It lets you clean up only your own.** Docker's filters work by name. `docker ps -a --filter name=curso-docker-` lists only the course's containers, and `docker image ls 'curso-docker-*'` only its images. Deleting "everything from the course" becomes a safe command, one that does not touch the databases or the images of other projects you have on the same machine.
3. **It says where it came from.** Six months from now, when you clean up and find `curso-docker-revisor:1.0.0`, you will know what it is without investigating.

The `revisor`'s versioning rule in this course is simple: every time a lesson changes the image, the version goes up. This one is `1.0.0`: the first one that fully works. When the Dockerfile changes, the tag is not reused; a new one is created.

> [!NOTE]
> 🔧 **Engineering observation 3.2**
> An image name is a promise: "this is such-and-such, at such-and-such version". `latest` promises nothing, and a name without a prefix promises something another project may also be promising. You pay for both mistakes on the day you need to know what is running, which tends to be the worst day to find out.

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
```

This output is stable. The first time, `docker pull` downloads the Go image, which weighs hundreds of megabytes; be patient. `--user` does at run time what `USER` does in the Dockerfile, and here it lets you try the user without building anything.

Read it from top to bottom. The base image declares an empty user, and empty means `root`: block 2 confirms it, with `uid=0(root)`. A Dockerfile that starts from `golang` and says nothing inherits that, and the `revisor` would serve requests from the network as user 0 of your kernel. With user 10001, block 3 says `uid=10001 gid=10001`, **with no name in parentheses**. And block 4 explains why: that user does not exist in the image's `/etc/passwd`.

#### 3.4.2 A number is enough

That is correct, and deliberate. To the kernel, a user is a number; the name is a convenience that lives in `/etc/passwd`. The `USER` reference accepts a name or a number, in the form `USER <UID>[:<GID>]` ([reference, `USER`](https://docs.docker.com/reference/dockerfile/#user)), and writing both numbers has two advantages. First: there is no need to create the user in the image. Second: the group is fixed; if you give a user without a group and that user has no primary group, the reference warns that the process runs with the `root` group. With `10001:10001` there are no surprises.

Why 10001? Because it is far from the numbers distributions use for their own users and for the people on the machine (on Mint, your user is usually 1000). A high number of your own reduces the chance that the container's process coincides with a real user on the host.

The best practices guide asks for it without beating around the bush: "If a service can run without privileges, use `USER` to change to a non-root user" ([best practices, `USER`](https://docs.docker.com/build/building/best-practices/#user)). The `revisor` needs nothing from `root`: it listens on 8080, a high port, and does not write to system directories. (Ports below 1024 are the ones that, on Linux, require a special capability; inside a Docker container not even that applies: `docker run --rm --user 10001:10001 golang:1.27.3-trixie cat /proc/sys/net/ipv4/ip_unprivileged_port_start` printed `0` on this lesson's machine, which means any port can be opened without privileges.) So from the very first Dockerfile it runs as 10001. The course plan puts it this way: security is not a lesson, it is a habit.

### 3.5 The context and `.dockerignore`

#### 3.5.1 What travels ends up inside

Now the dangerous ingredient: `COPY . .`. It copies the **entire** context. In a real project, the folder has more than code: a `.git` with the history, a `.env` with passwords for testing on your machine, a `.tar` backup you left there last week. `fig03_04.sh` builds the `revisor` with this lesson's Dockerfile and a **fake** `.env` file in the folder, first without a `.dockerignore` and then with one, and looks at what ended up in `/src` inside the image:

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

This output is stable. The script works in a temporary folder (`mktemp -d`) so as not to dirty `programas/revisor/`, which is the code the course delivers and is not edited, and it deletes its two images on exit. `docker build -q` builds quietly (*quiet*); `ls -A` also lists files starting with a dot. Both builds take as long as a normal one, because each one compiles again: in this lesson's run, the whole script took a little over a minute, with the base image already downloaded.

Look at the first block. The `.env` got into the image and can be read with a `cat`. Anyone who has the image—your teammate, the server, a public registry if you push it someday—also has that secret. And you do not even need to run the image to extract it: it is enough to save it to a file and open it. The `Dockerfile` itself also got in, and it is useless inside. In the second block, with the `.dockerignore`, `/src` has only what the program needs to compile: `cmd`, `go.mod`, and `internal`.

#### 3.5.2 The lesson's `.dockerignore`

This is the file. It is called exactly `.dockerignore`, with the dot, and it goes in the root of the context, next to the `Dockerfile`:

```text
# fig03_03.dockerignore
# Lo que nunca viaja al daemon al construir.
.git
.env
*.tar
Dockerfile*
.dockerignore
```

Each line is a pattern, similar to *shell* wildcards; lines with `#` are comments ([Docker, "Build context", `.dockerignore` files](https://docs.docker.com/build/concepts/context/#dockerignore-files)). The documentation says where it is looked for: the client looks for a file named `.dockerignore` "in the root directory of the context". Each line has its reason:

- **`.git`**: the project's entire history. It can weigh much more than the code and can hold secrets that someone deleted from the code but not from the history.
- **`.env`**: where people keep passwords for testing on their machine. It is exactly the file in the figure.
- **`*.tar`**: backups and exported files that linger in the folder without anyone remembering them.
- **`Dockerfile*` and `.dockerignore`**: the recipe has no business being inside the dish. So how does Docker build, if you exclude the Dockerfile? The documentation answers: those two files "are still sent to the builder as they're needed for running the build"; what the pattern prevents is `COPY` putting them into the image. The asterisk in `Dockerfile*` also covers the `Dockerfile.forma-shell` from 3.7.

A reading detail: a line starting with `!` makes an exception ("include this, even if an earlier pattern excludes it"), and when several patterns match a file, the last one wins. You do not need it today, but you will see it in other people's projects.

> [!NOTE]
> 🔧 **Engineering observation 3.3**
> `.dockerignore` is a list of what does **not** travel. That means everything you forget to put in it, travels. That is why a project's first Dockerfile already comes with its `.dockerignore`, even if the folder is clean today: the folder is not going to stay clean, and the day someone leaves a `.env` there, the file will already be waiting for it.

### 3.6 Building, failing, and running

#### 3.6.1 Building

With the `Dockerfile` and the `.dockerignore` in the `revisor`'s folder, building is a single command. `fig03_05.sh` assembles the project in a temporary folder, builds, triggers the first error, runs the service correctly, queries it, and stops it:

```bash
#!/usr/bin/env bash
# fig03_05.sh — Construir el revisor, verlo fallar sin configuración, correrlo
# bien y detenerlo. CMD en forma exec. Borra lo que crea al salir.
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
trap 'docker rm -f ${PREFIJO}revisor >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0 >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construir y medir"
muestra "docker build -q -t ${PREFIJO}revisor:1.0.0 . >/dev/null && docker image ls ${PREFIJO}revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "El error: arrancar sin configuración"
muestra "docker run --name ${PREFIJO}revisor ${PREFIJO}revisor:1.0.0"
muestra "docker ps -a --filter name=${PREFIJO}revisor --format '{{.Names}} {{.Status}}'"
docker rm ${PREFIJO}revisor >/dev/null

titulo "Correrlo bien"
muestra "docker run -d --name ${PREFIJO}revisor -p 127.0.0.1:${PUERTO}:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0 >/dev/null"
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

The script is long because of the helpers at the beginning, which you will recognize in the following ones: `muestra` prints each command with a `$` in front before running it, so that in the output you know what produced what, and if the command fails, it notes its exit code instead of stopping the script; `t` gives the time in milliseconds for timing; `esperar_http` polls the service's health until it answers, because a freshly started container takes a moment to start listening. The first part of the output:

```text
## Construir y medir
$ docker build -q -t curso-docker-revisor:1.0.0 . >/dev/null && docker image ls curso-docker-revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

**1.45 GB.** The compiled `revisor` is a single file of a few megabytes; everything else is what the base image brings: a full Debian, the Go compiler and its tools, plus whatever the compilation left in the image. None of that is needed to **run** the `revisor`, only to **build** it. Write the number in your logbook: it is the starting point, and the course plan devotes Lesson 5 to bringing it down. On your machine the number may vary slightly depending on the architecture.

#### In your folder: the image that stays

The course's scripts work in temporary folders and **delete what they create** on exit: they are for seeing and measuring, not for leaving you anything. Your project, on the other hand, has to stay, because Lesson 4 starts from it. From the root of the course repository, set up your folder and build the image you are going to keep:

```bash
mkdir -p ~/curso-docker
cp -R programas/revisor ~/curso-docker/revisor
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
cmd
Dockerfile
go.mod
internal
$ docker build -q -t curso-docker-revisor:1.0.0 .
sha256:f1b8e9646140…
$ docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

The identifier `docker build -q` prints is the image's digest and changes on every machine; here it was truncated. This run used the run prefix from "About the runs" in the tag, and it is shown with the default name; the order in which `ls -A` lists files may vary with your system's language. From now on, when the lesson says "in the `revisor`'s folder", that is `~/curso-docker/revisor`, and **this** `curso-docker-revisor:1.0.0` is the one that stays on your machine when you finish. You can type the commands in 3.6.2 and 3.6.3 there as-is.

#### 3.6.2 The first error: starting without configuration

```text
## El error: arrancar sin configuración
$ docker run --name curso-docker-revisor curso-docker-revisor:1.0.0
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]
$ docker ps -a --filter name=curso-docker-revisor --format '{{.Names}} {{.Status}}'
curso-docker-revisor Exited (1) Less than a second ago
```

The image is fine; the container started and the `revisor` refused to work. The `revisor` is configured with environment variables, and the only mandatory one is `REVISOR_SERVICIOS`, the list of services it must check. Without it, it prints what is missing, with an example, and exits with code 1. `docker ps -a` shows it as `Exited (1)`: the process ended on its own, with an error of its own. Compare it with the 137 from Lesson 0: there, someone killed the process; here, the process decided to leave. Knowing how to read that difference saves you from looking for the problem in the wrong place. Notice also that the container remained created even though it exited: the script deletes it with `docker rm` before continuing, because the name is taken.

#### 3.6.3 Running it correctly

```text
## Correrlo bien
$ docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.0.0 >/dev/null
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"desarrollo"}
$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK            0s  200
$ docker exec curso-docker-revisor id
uid=10001 gid=10001 groups=10001
$ docker top curso-docker-revisor -o pid,user,args
PID                 USER                COMMAND
1387809             10001               revisor
```

The process number `1387809` changes on every run; everything else is stable, except, in another run, the time in the table (the `sed` in the command is there to mask it if it comes out in milliseconds; in this run it came out as `0s` and there was nothing to mask).

`-e` passes an environment variable to the container. Here the `revisor` checks **itself**: the list has a single service, `propio`, which points to its own health endpoint. It is a way of verifying that everything works without another container, because connecting containers to each other is a networking topic and the course plan leaves it for Lesson 8. The table says `OK` and `200`.

`/salud` answers `"version":"desarrollo"`. It is not an error: the image was built without stamping a version on the program, and the `revisor` is made to reveal that this way. Mind the difference: the **image** has the tag `1.0.0`, but the **program** inside does not know which version it is. They are two different things, and joining them is the job of a later lesson.

Now the last two lines, which are the important ones in this section. `docker exec ... id` says `uid=10001`: the Dockerfile's `USER` worked. And `docker top`, which lists a container's processes as seen from the host, shows **a single process**: `revisor`, owned by user 10001. That single line is the *exec* form at work. Keep it in mind, because in the next section you are going to see one with **two** lines.

### 3.7 *Exec* form versus *shell* form

#### 3.7.1 Two ways of writing the same thing

`CMD` (and also `RUN` and `ENTRYPOINT`) can be written in two ways ([Dockerfile reference, *shell* and *exec* form](https://docs.docker.com/reference/dockerfile/#shell-and-exec-form)):

- ***Exec* form**: a list in JSON format, with brackets and double quotes: `CMD ["revisor"]`. Docker starts that program directly, with nothing in between.
- ***Shell* form**: plain text: `CMD revisor`. Docker wraps it in a *shell*; on Linux, in `/bin/sh -c "revisor"`. The reference puts it this way: unlike the *exec* form, instructions in *shell* form "always use a command shell".

The *shell* form exists for a reason: with a *shell* in between you can use variables (`$HOME`), pipes (`|`), and chain commands (`&&`). That is why it is used a lot in `RUN` instructions, and it is fine to use it there. The problem appears when you use it for the container's **main** process, the one `CMD` starts.

To see it, the lesson includes a copy of the Dockerfile in which only the last line changes. It exists only for comparison:

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

In the project it is saved as `Dockerfile.forma-shell`, and it is built with `docker build -f Dockerfile.forma-shell`: the `-f` option tells Docker which recipe to use when it is not the one called `Dockerfile`.

#### 3.7.2 The measurement

First, the half you already saw: the end of `fig03_05.sh`, which stops the container with the *exec* form and shows its logs:

```text
## docker stop con forma exec
tardó 299 ms
$ docker logs curso-docker-revisor
revisor desarrollo escuchando en :8080 (1 servicio(s))
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /api/estados 200 1ms
revisor: recibí terminated, apagando
revisor: apagado limpio
```

The times (299 ms, and the `0s` and `1ms` of each request) change on every run; the sequence of lines is stable, although the number of `GET /salud` lines depends on how many times `esperar_http` asked before the service answered. The two final lines are the ones that matter: the `revisor` **received** the signal (`terminated` is the name Go gives to `SIGTERM`), finished what it was doing, and said goodbye. All in 299 milliseconds in this run (161 in the other one, inside the virtual machine).

Now the other half. `fig03_07.sh` builds the image with the *shell* form, runs it with the same configuration, looks at its processes, and stops it:

```bash
#!/usr/bin/env bash
# fig03_07.sh — La MISMA imagen con CMD en forma shell: quién es el PID 1,
# cuánto tarda docker stop y con qué código muere. Borra lo que crea al salir.
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
trap 'docker rm -f ${PREFIJO}revisor-shell >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0-shell >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "docker stop con forma shell"
docker build -q -t ${PREFIJO}revisor:1.0.0-shell -f Dockerfile.forma-shell . >/dev/null
docker run -d --name ${PREFIJO}revisor-shell -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0-shell >/dev/null
sleep 1
muestra "docker top ${PREFIJO}revisor-shell -o pid,user,args"
inicio=$(t); docker stop ${PREFIJO}revisor-shell >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${PREFIJO}revisor-shell"
muestra "docker logs ${PREFIJO}revisor-shell"
```

The helpers at the beginning are the same as in `fig03_05.sh`. The tag `1.0.0-shell` and the name `curso-docker-revisor-shell` are auxiliary: they live only as long as the script.

```text
## docker stop con forma shell
$ docker top curso-docker-revisor-shell -o pid,user,args
PID                 USER                COMMAND
1388087             10001               /bin/sh -c revisor
1388102             10001               revisor
tardó 10485 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor-shell
ExitCode=137
$ docker logs curso-docker-revisor-shell
revisor desarrollo escuchando en :8080 (1 servicio(s))
```

The process numbers change; the time changes by a few milliseconds, but it always stays **a little above 10 seconds**; `ExitCode=137` and the single-line log are stable. It is the opening scene, in full.

#### 3.7.3 What happened: the signal that never arrived

Put the two `docker top` outputs side by side. With the *exec* form there was **one** process, `revisor`. With the *shell* form there are **two**: `/bin/sh -c revisor` and, as its child, `revisor`. The *shell* started first, so the *shell* is the container's process number 1 (remember Lesson 0: inside the container, the main program is number 1). The `revisor` ended up as number 2 inside, just another child.

Now, the `docker stop` chain, according to its documentation: it sends the container's main process the `SIGTERM` signal, waits for a grace period that by default is **10 seconds** on Linux, and if the process is still alive, sends it `SIGKILL` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)). The "main process" is number 1. With the *exec* form, number 1 is the `revisor`, which is written to handle `SIGTERM`: it receives it, shuts down in an orderly way, and exits. With the *shell* form, number 1 is `/bin/sh`.

Two facts come together here. The first: the *shell* does not forward the signal to its child. The explanation of the `JSONArgsRecommended` rule says it word for word: with the *shell* form, the program "runs as a child process of a shell, and the shell doesn't pass signals" ([Docker, `JSONArgsRecommended`](https://docs.docker.com/reference/build-checks/json-args-recommended/)). The Dockerfile reference spells it out for the *shell* form of `ENTRYPOINT`: the executable "will not be the container's PID 1, and will not receive Unix signals" ([reference, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). The second fact comes from the kernel and is more subtle: process number 1 of a PID namespace is special. `docker stop` sends the signal from outside the container, from the host's namespace, which is the container's "ancestor". For that case, the Linux manual says that process number 1 only receives signals for which it has established a handler, and that `SIGKILL` and `SIGSTOP` are the exception: those two "are forcibly delivered" when they come from an ancestor namespace ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). The *shell* did not install a handler for `SIGTERM`, so the signal does not even kill it: it gets lost.

With that, the output reads itself:

1. `docker stop` sends `SIGTERM` to number 1, the *shell*. It gets lost. The `revisor`, below, never finds out.
2. 10 seconds go by. That is almost all the time you measured: 10,485 ms are the 10,000 of the grace period plus what Docker, the kernel, and, in this run, the trip from the Mac take (in the run inside the virtual machine it was 10,112 ms).
3. `docker stop` sends `SIGKILL`, which, according to the signals manual, "cannot be caught, blocked, or ignored" ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)). The *shell* and the `revisor` die at once.
4. Docker records `ExitCode=137`. You have known how to read it since Lesson 0: 128 plus 9, and 9 is the number of `SIGKILL`.
5. The log has a single line. It does not say `recibí terminated` because the `revisor` received nothing, and it does not say `apagado limpio` because it did not shut down: it was killed in the middle of what it was doing. If at that instant it was writing a report, the report was left half-written.

Notice that the `revisor`'s code is exactly the same in both images. It knows how to shut down: it proved it in a few tenths of a second. What changed is that, with a *shell* in between, the signal never reached it. And it is not worth figuring out how each base image's *shell* behaves: with the *exec* form there is no *shell* in between and the question disappears.

> [!NOTE]
> 🔧 **Engineering observation 3.4**
> Ten seconds seem like little. Multiply them: an update that stops twenty containers one after another loses more than three minutes waiting, and each one gets cut off in the middle of what it was doing. And the 137 pollutes your alerts: if every normal shutdown ends in 137, the day a container really dies from running out of memory, with the same 137, nobody is going to notice.

#### 3.7.4 When you do need a *shell*

Sometimes startup needs something only a *shell* provides, such as reading a variable. The rule's page itself gives two ways out that remain honest: write a small startup script and call it in *exec* form, or declare the *shell* deliberately with the `SHELL` instruction. In both cases the program is once again a child of a *shell* and the signal is once again your responsibility, for example with `exec` at the end of the script, which replaces the *shell* with your program. The `revisor` needs none of that: it reads its variables itself. The practical rule of this course is therefore: **`CMD` and `ENTRYPOINT`, always in *exec* form**.

### 3.8 Checking before building: `docker build --check`

What you just measured with a stopwatch, Docker can detect by reading the recipe, without building anything. `docker build --check` runs the **build checks**: rules that look for common mistakes in the Dockerfile. The documentation says that, instead of executing the build steps, the command "only runs the checks and reports any violations it finds", and that they have existed since version 1.8 of the Dockerfile syntax and Buildx 0.15.0 ([Docker, "Build checks"](https://docs.docker.com/build/checks/)). Your Docker ships a much newer version. `fig03_08.sh` checks the lesson's two Dockerfiles:

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

The first one, the good one:

```text
## Revisar el Dockerfile antes de construir
$ docker build --check .
#0 building with "colima" instance using docker driver

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
#5 transferring context: 127B 0.0s done
#5 DONE 0.0s
Check complete, no warnings found.
```

The times and the long *digest* after `dockerfile:1@sha256:` change (that *digest* is the exact version of the syntax interpreter Docker used that day); so do the size in bytes of `transferring dockerfile`, which depends on the file's comments, and the context name on the `#0` line (here `colima`; on your Mint, `default`). What is stable is the sequence of steps and the last line. The numbered steps are what BuildKit did: load the recipe (`#1`), resolve the interpreter requested by the `# syntax` line (`#2` and `#3`), query the base image's metadata without downloading all of it (`#4`), and read the `.dockerignore` (`#5`). There was no `COPY` and no `RUN`: nothing was built. And at the end, `Check complete, no warnings found.`

The second one, the *shell* form:

```text
$ docker build --check -f Dockerfile.forma-shell .
#0 building with "colima" instance using docker driver

#1 [internal] load build definition from Dockerfile.forma-shell
#1 transferring dockerfile: 355B done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.0s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie
#4 DONE 0.1s

#5 [internal] load .dockerignore
#5 transferring context: 127B done
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

There is the opening scene, found before building. The warning has four parts. The rule's name, `JSONArgsRecommended`, with the address of its explanation. The sentence: "JSON arguments recommended for `CMD` to prevent unintended behavior related to OS signals". The exact location: `Dockerfile.forma-shell:10`. And the line marked with `>>>`. In addition, the command exits with **code 1**: the documentation clarifies that, unlike a normal build, with `--check` any violation makes the command end with a non-zero code. That is what makes it useful on a build server: a warning stops the process instead of getting lost on the screen.

A **normal** build (`docker build` without `--check`) also runs these checks and shows the same warning, but it finishes successfully and builds the image anyway. It is easy to miss among hundreds of lines. That is why the habit is to run `--check` beforehand, on purpose. And if you want no build to get through with warnings, the Dockerfile can declare it on its second line, right after `# syntax`, with `# check=error=true`: that way the warning also stops a normal `docker build` ([Docker, "Build checks"](https://docs.docker.com/build/checks/)).

### 3.9 What you will find in old tutorials

You are going to read other people's Dockerfiles, and some include things this course does not use. It is worth recognizing them:

- **`MAINTAINER name`.** It declared the image's author. It is deprecated: the reference states that `LABEL` is "a much more flexible version" and should be used instead, for example `LABEL org.opencontainers.image.authors="..."` ([reference, `MAINTAINER`](https://docs.docker.com/reference/dockerfile/#maintainer-deprecated)).
- **`ADD` to copy local files.** `ADD` does more than `COPY`: it also downloads from the internet and extracts archives. That magic is surprising. The best practices guide uses `COPY` for copying and reserves `ADD` for when you really need to fetch something remote ([best practices, `ADD` or `COPY`](https://docs.docker.com/build/building/best-practices/#add-or-copy)). This course does not need `ADD`.
- **`FROM something:latest` or `FROM something` without a tag.** You already know why not (3.3).
- **`CMD command` and `ENTRYPOINT command` in *shell* form.** You already know how to measure why not (3.7).
- **Installing `sudo` in the image.** The guide advises against it because of its unpredictable behavior with terminals and with signal forwarding. If something needs `root` when building, it goes before the `USER`; when running, it should not need it.

## The error you will see

This lesson has three errors, from least to most serious. You have already triggered all three.

**1. The `docker build --check` warning.**

```text
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
Dockerfile.forma-shell:10
```

It reads like this: there is a rule that is not met (`JSONArgsRecommended`); its explanation is at the address; and line 10 of `Dockerfile.forma-shell` is the culprit. You fix it by changing `CMD revisor` to `CMD ["revisor"]`. If you really need a *shell* at startup, see 3.7.4. What you do not do is ignore the warning because "the image built fine": it builds fine and shuts down badly.

**2. The container that exits with 1 at startup.**

```text
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
curso-docker-revisor Exited (1) Less than a second ago
```

It reads like this: the container started, the program read its configuration, did not find something mandatory, and exited on its own with 1. It is not a problem with the image or with Docker. The first question in the face of a freshly started `Exited (1)` is always `docker logs <container>`: the cause is almost always there, written by the program itself. You fix it by passing the variable with `-e`.

**3. The 10-second `docker stop` and code 137.**

```text
tardó 10485 ms
ExitCode=137
```

It reads like this: the main process did not handle `SIGTERM`, the grace period ran out, and Docker killed it with `SIGKILL` (137 = 128 + 9). Before blaming the program, look at `docker top <container>`: if the first line is `/bin/sh -c ...`, the signal got stuck in the *shell*. You fix it with `CMD` in *exec* form. There are other possible causes of a 137—running out of memory, from Lesson 0, is the other big one, and you can tell it apart because `docker inspect` says `OOMKilled=true`—but when the `docker stop` time is exactly the grace period, this is the main suspect. What you do **not** do is raise the `docker stop` grace period so that it "has enough time": a longer grace period only lengthens the wait, because the signal still does not arrive.

## The security habit of the lesson

**The first Dockerfile already comes with `USER`, `.dockerignore`, and a versioned tag.** All three are cheap on day one and expensive to add later, when there are already containers running and people depending on them.

- **`USER 10001:10001`** prevents a bug in the `revisor`—or in any library it uses—from giving whoever exploits it user 0 of your kernel. You verified it with `docker exec ... id`.
- **`.dockerignore`** prevents the accident from 3.5: a `.env`, a key, or the `.git` history baked into an image that then travels to other machines. You verified it by looking at `/src` inside the image.
- **The versioned tag and the prefix** prevent running "whatever happens to be called that": you know which image is running and you delete it without touching other people's.

## What gets done wrong

**Writing `CMD` in *shell* form "because it is easier to read".** It reads more easily and shuts down worse: 10 seconds of waiting and a 137 on every `docker stop`. The *exec* form is two brackets and some quotes.

**Using `latest`, or not setting a tag, which is the same thing.** `latest` does not mean "the newest"; it means "no tag". On the day of the problem you will not know which version was running.

**Giving the image a generic name like `revisor` or `app`.** It collides with images from other projects on the same machine and takes their name without warning.

**Leaving the Dockerfile without `USER` because "it is just for testing".** What is for testing ends up in production with the same Dockerfile. It costs one line.

**`COPY . .` without `.dockerignore`.** Everything in the folder travels and stays in the image, including files nobody remembers leaving there.

**Using `RUN` to start the service.** `RUN` runs when building: the build would wait for the server forever. What runs when running goes in `CMD`.

**Believing that `EXPOSE` publishes the port.** It only records it. Without `-p` when running, nobody from outside gets in. And with `-p`, the port is published on `127.0.0.1`, as you learned in Lesson 2.

**Ignoring build warnings.** A normal build shows the `JSONArgsRecommended` warning and finishes successfully. Running `docker build --check` beforehand turns the warning into an error that cannot be overlooked.

## Exercises

Do them in order. Before running each one, write in your [logbook](bitacora.md) what you think will happen; comparing it afterwards is half of the learning. When you finish, delete what you created: everything carries the `curso-docker-` prefix.

### Exercise 1 — When building or when running?

Without looking at the table in 3.2.2, classify each line: does it act **when building**, does it only **record something for running**, or both?

1. `FROM golang:1.27.3-trixie`
2. `COPY . .`
3. `RUN go build -o /usr/local/bin/revisor ./cmd/revisor`
4. `USER 10001:10001`
5. `EXPOSE 8080`
6. `CMD ["revisor"]`

And a trick question: if you change the order and put `USER 10001:10001` **before** the `RUN go build`, which user does the compilation run as?

### Exercise 2 — Your own `.dockerignore` (project)

Work in your folder `~/curso-docker/revisor` (the one from the "In your folder" block in 3.6.1). Set the lesson's `.dockerignore` aside for a moment with `mv .dockerignore ../dockerignore-leccion3` and create three things there: a `.env` file with a fake secret, a `notas.md` file, and a `secretos/` folder with a file inside. Build `curso-docker-revisor:1.0.0-ej2` and list `/src` inside the image with `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src`. Then write a new `.dockerignore` that leaves out the three things, in addition to everything the lesson's one excluded (you have it in `../dockerignore-leccion3`), rebuild with the same tag, and list again. The exercise is self-checking: you are done when `/src` shows exactly `cmd`, `go.mod`, and `internal`. At the end, `docker rmi curso-docker-revisor:1.0.0-ej2`. Your extended `.dockerignore` can stay: it excludes everything the lesson's one excluded and a bit more, so your `curso-docker-revisor:1.0.0` does not change.

### Exercise 3 — The stopwatch on your machine

Run `fig03_05.sh` and `fig03_07.sh` on your Mint (after Lesson 1 and with the Go image downloaded). Write down in your logbook, on the line Lesson 3 provides for it, the two `docker stop` times. Before running them, predict:

1. Which of the two times will change more from one run to another, and which will stay almost the same?
2. What number will come out in `ExitCode` with the *shell* form? And what number would you expect with the *exec* form, knowing that the `revisor` is written to exit with 0 after a clean shutdown? Check it by adding, after the `docker stop` in `fig03_05.sh`, a `docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor`.

### Exercise 4 — Fix someone else's Dockerfile

A teammate hands you this Dockerfile for the `revisor`. Find **six** problems, five in the file and one that is missing next to it; say what accident each one can cause and write the corrected version. Then check yours with `docker build --check`: it has to say `Check complete, no warnings found.`

```dockerfile
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

1. **When building.** It brings in the entire contents of the base image.
2. **When building.** It copies the files from the context into the image.
3. **When building.** It compiles and leaves the executable in the image. It does not run again when running.
4. **Both.** It records the user the container will run as, and it also affects any `RUN` that comes after it in the Dockerfile.
5. **Only records.** It publishes nothing (3.2).
6. **Only records** the process each container will start.

The trick question: as user **10001**, because `USER` changes the user for everything that comes after, including when building. And the compilation fails. Go tries to create its cache in the user's home directory and, since 10001 does not exist in `/etc/passwd`, that directory is `/`, where it cannot write. Measured on this lesson's machine with `docker build --progress=plain` (the `#10` and the `0.881` are the step number and the seconds, and they change):

```text
#10 0.881 failed to initialize build cache at /.cache/go-build: mkdir /.cache: permission denied
ERROR: failed to build: failed to solve: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

Even if the cache worked, it could not write to `/usr/local/bin` either. That is why `USER` comes after compiling.

### Solution 2

A `.dockerignore` that does the job:

```text
.git
.env
*.tar
*.md
secretos/
Dockerfile*
.dockerignore
```

With it, `ls -A /src` inside the image shows only `cmd`, `go.mod`, and `internal`, just like the second block of `fig03_04.sh`. If `notas.md` or `secretos` still appears in your list, check that the pattern is written correctly and that the `.dockerignore` file is in the root of the context, next to the `Dockerfile`, and not in a subfolder. If `.dockerignore` or `Dockerfile` appears, you are missing the last two lines. An equally valid variant replaces `*.md` with `notas.md`: it excludes only that file. The one above is more forward-looking, because the `revisor` does not need any `.md` to compile.

### Solution 3

1. The *exec* form's time changes more from one run to another (tens or hundreds of milliseconds, depending on how busy your machine is); the *shell* form's stays almost the same, always a little above 10,000 ms, because almost all of it is `docker stop`'s fixed grace period.
2. With the *shell* form, `ExitCode=137`, as in `fig03_07.sh`. With the *exec* form, `ExitCode=0`: the `revisor` receives `SIGTERM`, writes `apagado limpio`, and exits with 0. If your run gives another number, look at `docker logs`: if `apagado limpio` does not appear, the signal did not arrive, and the first suspect is that your Dockerfile has the *shell* form.

### Solution 4

The five problems in the file:

1. **`FROM golang` without a tag**, which is `golang:latest`: each build may use a different Go version. Fix: `FROM golang:1.27.3-trixie`.
2. **`MAINTAINER`**, deprecated. Fix: remove it, or use `LABEL org.opencontainers.image.authors="..."`.
3. **`RUN cd /src && ...` instead of `WORKDIR`.** It works on that line, but the `cd` is lost afterwards, and the container starts in `/`. Fix: `WORKDIR /src` and `COPY . .`.
4. **No `USER`**: the `revisor` would run as `root`. Fix: `USER 10001:10001` after compiling.
5. **`CMD revisor` in *shell* form**: 10 seconds and 137 on every `docker stop`. Fix: `CMD ["revisor"]`. It is exactly what `docker build --check` flags.

And the sixth, the one that is not in the file: **the `.dockerignore` is missing**, and with `COPY . /src` the entire context gets into the image. The corrected version is this lesson's `fig03_01.Dockerfile` plus `fig03_03.dockerignore`.

`docker build --check .` on the original Dockerfile finds two of the six. Measured on this lesson's machine (only the warning lines are shown):

```text
Check complete, 2 warnings have been found!
WARNING: MaintainerDeprecated - https://docs.docker.com/go/dockerfile/rule/maintainer-deprecated/
Maintainer instruction is deprecated in favor of using label
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
```

`MaintainerDeprecated` is problem 2: the rule says `MAINTAINER` is deprecated and a label (`LABEL`) should be used instead ([Docker, `MaintainerDeprecated`](https://docs.docker.com/reference/build-checks/maintainer-deprecated/)). `JSONArgsRecommended` is problem 5. The other four (`latest`, the `cd`, the missing `USER`, and the missing `.dockerignore`) are not detected by any of the rules that ran here: that is why `--check` helps but does not replace reading the recipe. Your version has to say `Check complete, no warnings found.`

## How I know I succeeded

Check each item only if you verified it on your machine:

- [ ] `docker build --check .` in `~/curso-docker/revisor` ends with `Check complete, no warnings found.` and code 0.
- [ ] `docker image ls 'curso-docker-revisor'` shows `curso-docker-revisor` with the tag `1.0.0`, and you wrote its size in your logbook (in this lesson's run, 1.45 GB).
- [ ] Without `REVISOR_SERVICIOS`, the container ends up `Exited (1)` and `docker logs` says what is missing.
- [ ] With the variable, `curl -s http://127.0.0.1:8080/salud` answers `{"estado":"vivo","version":"desarrollo"}`.
- [ ] `docker exec curso-docker-revisor id` says `uid=10001 gid=10001 groups=10001`.
- [ ] `docker top curso-docker-revisor -o pid,user,args` shows **a single** process, `revisor`.
- [ ] `docker stop curso-docker-revisor` takes less than a second and `docker logs` ends with `revisor: apagado limpio`.
- [ ] With the *shell*-form image you measured the 10 seconds and the 137, and you can explain why with `docker top`.
- [ ] Inside the image, `ls -A /src` shows neither `.env`, nor `.git`, nor `Dockerfile`.
- [ ] When you finish, `docker ps -a --filter name=curso-docker-revisor` shows nothing, and `docker image ls 'curso-docker-revisor'` shows only `curso-docker-revisor:1.0.0`, the one you built in your folder and that Lesson 4 uses.

## Summary

Answer without looking at the lesson:

1. What is a Dockerfile, what is the context, and who does the work of building?
2. Which instructions act when building and which only record something for running?
3. What does the `latest` tag really mean? Why is the course's image called `curso-docker-revisor:1.0.0` and not `revisor:1.0.0`?
4. Which user does an image run as if nobody wrote `USER`? Why is a number enough?
5. What does `.dockerignore` do, and what happens to a `.env` if you do not have one?
6. What is the difference between `CMD ["revisor"]` and `CMD revisor`? What does `docker top` show in each case?
7. Why, with the *shell* form, does `docker stop` take 10 seconds and leave a 137? What is the 137?
8. What does `docker build --check` do, and with what code does it exit if it finds something?

## Sources

All consulted on October 21, 2026.

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/): the `FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`, `ENTRYPOINT`, and `MAINTAINER` instructions; the *shell* and *exec* forms; the `syntax` directive.
- [Docker, "Build context"](https://docs.docker.com/build/concepts/context/): the build context and `.dockerignore` files.
- [Docker, "Build checks"](https://docs.docker.com/build/checks/): `docker build --check`, its exit code, and the minimum versions.
- [Docker, `MaintainerDeprecated` rule](https://docs.docker.com/reference/build-checks/maintainer-deprecated/): the warning about `MAINTAINER` in exercise 4.
- [Docker, `JSONArgsRecommended` rule](https://docs.docker.com/reference/build-checks/json-args-recommended/): why the *shell* form does not pass signals, and the two alternatives when a *shell* is needed.
- [Docker, best practices for building images](https://docs.docker.com/build/building/best-practices/): `USER`, `sudo`, `ADD` versus `COPY`, mutable tags, and `.dockerignore`.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM`, the 10-second grace period, and `SIGKILL`.
- [`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/): the parts of an image name and the default `latest` tag.
- [Docker, "Running containers"](https://docs.docker.com/engine/containers/run/): overriding the `CMD` from `docker run`.
- [golang on Docker Hub](https://hub.docker.com/_/golang): the `1.27.3-trixie` tag and its aliases, and the meaning of *trixie*.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions in "About the runs".
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
| **tag** | the part of an image's name after the colon; it says which version it is |
| ***exec* form** | an instruction written as a JSON list: `CMD ["revisor"]`; it starts the program without a *shell* |
| ***shell* form** | an instruction written as text: `CMD revisor`; it is wrapped by `/bin/sh -c` |
| **base image** | the image another one starts from, the one in `FROM` |
| **`latest`** | the tag Docker sets when none is given; it does not mean "the newest" |
| **PID 1** | a container's first process; the one that receives the `docker stop` signal |
| **build check** | a rule that looks for common mistakes in a Dockerfile without building it |
| **`SIGTERM`** | signal 15: "please terminate"; the one `docker stop` sends first |
| **`SIGKILL`** | signal 9: immediate death; it cannot be caught; it leaves code 137 |

---

**Next:** [Lesson 4 — Layers, Cache, and Context](04-capas-cache-contexto.md)
