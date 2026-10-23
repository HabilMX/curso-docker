# Lesson 2 — Containers day to day

There are twelve minutes left before the demo and the service will not start. You type the same command that worked yesterday and Docker answers with a line in English that ends in `port is already allocated`. You try again and now the message is a different one: `The container name ... is already in use`. Someone next to you suggests rebooting the computer. Before doing so, you run `docker ps -a` and the screen fills up: containers from last week, some stopped, others still running, one of them published on port 9000 **for anyone on the same wireless network** as the café where you worked on Tuesday. Nobody did it out of malice. It is simply that nobody learned to start, look at, stop and delete containers in an orderly way. You have ten minutes left, and this lesson is what you would have needed to know.

**Time:** 2 × 45 min

**What you build:** the course's test service running in a container, with its port published only for your machine and with memory, CPU and process limits; you query it in its three modes (healthy, slow and down), read its log, inspect it, stop it and delete it. In the end no course container is left on your machine; the image `curso-docker-prueba:1.0.0`, on the other hand, stays, because the following lessons use it again.

**What you learn:** the day-to-day commands —`run`, `ps`, `logs`, `exec`, `inspect`, `stats`, `stop`, `start` and `rm`—; what publishing a port means and why in this course it is always published on `127.0.0.1`; how to set memory, CPU and process limits and how to check that they were applied; the life cycle of a container (created, running, stopped, deleted); and how to clean up only what is yours without touching anyone else's.

**Where you are coming from.** From [Lesson 0](00-que-es-un-contenedor.md) you bring the map: a container is an isolated process, the image is the template and the container the live copy, and the `docker` client asks the daemon for everything through a *socket*. From [Lesson 1](01-instalacion.md) you bring Docker installed on your Mint and your user in the `docker` group, knowing that this is the same as `root`. You also need the course repository on your machine: from it you will use the `programas/servicio-prueba/` folder, which brings the test service already written and with its `Dockerfile` done. You do not need to know Go or how to read that `Dockerfile` yet.

**What this lesson does not do.** It does not write any `Dockerfile`: the test service's is used as it comes, and learning to read it is the work of Lessons 3 to 5. It does not touch the `revisor` yet, the course's main project, because to run it it first has to be packaged, and that starts in [Lesson 3](03-primer-dockerfile.md). Nor does it explain volumes or networks between containers; here each container lives alone and you talk to it from your machine.

**About the runs.** The outputs in this lesson were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a Linux virtual machine with Ubuntu 24.04.4 (the same base as Linux Mint 22), 64-bit ARM processor. The scripts were run **inside that virtual machine**, with Docker 29.2.1 (client and daemon, API 1.53). The Mac's client was 29.8.2, the version the course was planned with, and the latest release published that day was 29.9.2, from October 20, 2026, according to the [official release notes](https://docs.docker.com/engine/release-notes/29/). Four notes on how it was run. **First:** that machine was being used at the same time by other lessons of the course, so, to avoid collisions, the scripts were launched with a different name prefix and different ports: they have the variables `PREFIJO` (default `curso-docker-`) and `PUERTO` (default `9000`), and they were run with `PREFIJO=curso-docker-l02-` and `PUERTO=18020`; `fig02_05.sh` also uses the next port, `18021` instead of `9001`. Where the outputs show names and ports, the lesson shows the default values, which are the ones you will see: `curso-docker-prueba` instead of `curso-docker-l02-prueba`, and `9000` and `9001` instead of `18020` and `18021`; the tables were rearranged to the width of the shortest name, because each column's width depends on the name; that is the only change, and the `.salida.txt` files keep the run as it was. What does not change with the variables, because it happens inside the container, appears as is: port `9000` in the health checks. Each script's `trap` deletes by exact name, so with another prefix it does not touch another lesson's. On your Mint no variable is needed: the scripts run exactly as written. **Second:** the output of `fig02_01.sh` is that of a **cold** build, run with `SIN_CACHE=1` so that it does not reuse layers from earlier builds, which is what you will see the first time. The machine already had the base images downloaded, so no downloads show; on your first time you will first see the download of three images: the Go one, the minimal one and a small one, `docker/dockerfile:1`, which is the interpreter of the recipe (Lesson 3 explains that first line), and it will take longer. The step that compiles took 236.8 seconds in this run because the machine was shared and heavily loaded; in an earlier run of the same script, with less load, it took 32.9 (that output was not saved): the time depends on your machine. If you repeat the script with the image already built, the output is different (2.1.3); that run is in `fig02_01.salida-repetida.txt`. **Third:** what changes on your Mint is the architecture (`amd64` instead of `arm64` if your processor is Intel or AMD), the identifiers, the times and the total memory that `docker stats` reports. **Fourth:** the exercises and their solutions were also run, with the same prefixes, in `fig02_08.sh` (exercise 1), `fig02_09.sh` (exercises 2 and 3) and `fig02_10.sh` (`docker update`, 2.10.4); each with its saved output. The programs are in [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia), each one with its saved output next to it.

## By the end you will be able to

- Build the test service's image with a single command and find it with `docker image ls`.
- Start a container in the background with a name, a port published on `127.0.0.1` and memory, CPU and process limits, and explain each option of the command.
- List your containers with `docker ps`, filter them by name and choose which columns to show.
- Read a container's log with `docker logs`, whole or only its last lines, and run a program inside it with `docker exec`.
- Check with `docker inspect` and `docker stats` that the limits were applied, and with `ss` which interfaces your machine listens on.
- Read and resolve the two everyday errors: repeated name and port in use.
- Stop, restart and delete containers, and leave your machine without any `curso-docker-` container when you finish.

## The why before the how

In Lesson 0 you saw containers from the inside, to understand what they are. Now it is the opposite: using them every day without thinking about namespaces or control groups. And here a problem appears that has nothing technical about it and does more damage than many kernel errors: **disorder**.

A container is very easy to create. A single `docker run` is enough. And, since it makes no noise, it is very easy to forget. After a week of testing you have stopped containers that take up disk, running containers that take up memory and ports, and names you can no longer reuse. The worst is not the disk: it is that one of them was left listening on all your machine's network interfaces, and you do not know it. The scene at the beginning was not caused by a strange error; it was caused by three habits that nobody corrected: publishing ports without saying where, running without limits and not cleaning up.

This lesson gives you the full set of commands to manage a container from start to finish, and along with each command, the habit that prevents disorder. You are going to do it with the course's **test service**, a very small HTTP server that fails on purpose. It has three modes: in **healthy** mode it answers `200` immediately; in **slow** mode it takes three seconds and then answers `200`; in **down** mode it answers `503`, the HTTP code for "service unavailable". And the mode is changed on the fly, without restarting it, with a `POST` request. That service will be, throughout the course, the target that the `revisor` watches; here it serves as safe practice, and everything you do with it you will repeat with the `revisor`: when you package it in Lesson 3, you will start it with a command from the same family: the name, the image and port 8080 change, and the `127.0.0.1` address and the three limits stay. And it lets you see an idea the course repeats: **a container saying "running" does not mean the service is healthy**.

The lesson goes in this order:

1. **Building the image** of the test service (2.1), getting it wrong first.
2. **Starting** a container and understanding each part of the command (2.2).
3. **Looking at it**: `ps` (2.3), querying it (2.4) and reading its log with `logs` (2.5).
4. **Getting in**, or trying to, with `exec` (2.6).
5. **Inspecting it** with `inspect` and `stats` (2.7).
6. **Ports**: `127.0.0.1` versus all interfaces (2.8), and **limits** (2.9).
7. **The life cycle**: stopping, restarting and deleting (2.10), and **leaving no leftovers** (2.11).

This is the command you will arrive at. By the end of the lesson, every word will have a reason:

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

## The concepts

### 2.1 Building the test service's image

#### 2.1.1 First, the error

To run a container you need an image. Before building it, it is worth seeing what happens if you skip it, because it is an error you will see many times in your life: someone hands you a command, you paste it and the image does not exist on your machine. `fig02_01.sh` does exactly that, and then builds the image:

```bash
#!/usr/bin/env bash
# fig02_01.sh — Correr una imagen que todavía no existe, y después construirla.
# Primero el error (la imagen no está en tu equipo ni en Docker Hub); luego el
# único comando que necesitas para construir el servicio de prueba.
set -uo pipefail
cd "$(dirname "$0")/.."          # la carpeta programas/, donde está servicio-prueba/
# Nombres por omisión: los del curso. Se pueden cambiar para no chocar con otra
# corrida en el mismo equipo (PREFIJO=... ./fig02_01.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
# SIN_CACHE=1 ./fig02_01.sh construye sin reusar capas, como la primera vez en un equipo nuevo.
NOMBRE="${PREFIJO}prueba"
IMAGEN="${PREFIJO}prueba:1.0.0"
# Si la imagen ya existía, el bloque 1 no falla y SÍ crea un contenedor: se borra al salir.
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== 1. Correr la imagen antes de construirla"
docker run -d --name "$NOMBRE" "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Construirla: un solo comando"
docker build ${SIN_CACHE:+--no-cache} -t "$IMAGEN" servicio-prueba
echo "código de salida: $?"

echo
echo "== 3. La imagen ya está en tu equipo"
docker image ls "$IMAGEN"

echo
echo "== 4. Y el intento fallido no dejó contenedores"
docker ps -a --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}' | wc -l

echo
echo "== 5. El tamaño, con un formato propio"
docker image ls "$IMAGEN" --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

The script uses `set -uo pipefail` and not `set -euo pipefail` like those in Lesson 0: we removed the `-e` on purpose, because the first command **must** fail and we want the script to go on. `cd "$(dirname "$0")/.."` moves to the `programas/` folder, which is where `servicio-prueba/` is, no matter where you run the script from. And the `trap ... EXIT` schedules deleting the container on exit: the first time there is nothing to delete, but if you run the script with the image already built, block 1 no longer fails, it creates the container and the `trap` removes it. This is the first part of the output:

```text
$ ./fig02_01.sh
== 1. Correr la imagen antes de construirla
Unable to find image 'curso-docker-prueba:1.0.0' locally
docker: Error response from daemon: pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'

Run 'docker run --help' for more information
código de salida: 125
```

It reads in two steps. The first line says the image is not **on your machine** (*locally*). That is not yet an error: when `docker run` does not find an image, it looks for it in a registry, which by default is Docker Hub. The documentation explains it with the `--pull` option, whose default value is `missing`: it downloads the image only if it is not already on your machine ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). The second line is the real error: Docker Hub has no public repository called `curso-docker-prueba` and you gave it no credentials, so it denied the download. The message cannot know which of the two things is happening —that it does not exist or that it is private—, which is why it says both.

Exit code **125** also has a meaning. Docker's documentation reserves three codes: 125 means that the error is in the Docker daemon itself; 126, that the container's command could not be invoked; and 127, that the container's command was not found. Any other number is the code the program inside ended with ([Docker, "Running containers"](https://docs.docker.com/engine/containers/run/)). Here the container did not even come to exist: Docker failed, not the service. You will see a 127 in section 2.6.

> [!NOTE]
> 🔧 **Engineering observation 2.1**
> The search order has a security consequence. If you mistype the name of one of your own images and by chance a public image with that name exists, Docker will download it and run it without asking you. The risk is mainly in names that carry a user or organization, like `someone/image`, because anyone can publish in those spaces; a one-part name, like this course's, is looked up among Docker Hub's official images. That is why it is a good idea for your local image names to be unmistakable; this course's `curso-docker-` prefix plays that role, besides letting you clean up what is yours with a filter (2.11).

#### 2.1.2 A single command to build it

The test service ships with its recipe written: the file `programas/servicio-prueba/Dockerfile`. Building it is a single command:

```bash
docker build -t curso-docker-prueba:1.0.0 servicio-prueba
```

It has two parts. `-t curso-docker-prueba:1.0.0` gives a **name and a tag** to the resulting image: the name is `curso-docker-prueba` and the tag, what comes after the colon, is `1.0.0`. And `servicio-prueba`, at the end, is the folder Docker uses as the **context**: it looks for the `Dockerfile` there and takes from there the files that the recipe asks to copy. Lessons 3 and 4 explain the context in depth; here it is enough to know it is a folder.

The build output is long; this is the central part (the full file is in `fig02_01.salida.txt`):

```text
== 2. Construirla: un solo comando
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 836B 0.1s done
#1 DONE 0.1s
[…]
#9 [compilacion 1/4] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#9 resolve docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c 0.2s done
#9 DONE 0.3s
[…]
#12 [compilacion 4/4] RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/servicio-prueba .
#12 DONE 236.8s

#13 [stage-1 2/2] COPY --from=compilacion /out/servicio-prueba /servicio-prueba
#13 DONE 2.4s

#14 exporting to image
[…]
#14 naming to docker.io/library/curso-docker-prueba:1.0.0 0.2s done
#14 unpacking to docker.io/library/curso-docker-prueba:1.0.0 0.3s done
#14 DONE 6.1s
código de salida: 0
```

You do not need to understand every line today, but three things matter. The build goes in **numbered steps** (`#1`, `#2`…) and each says how long it took: the longest, 236.8 seconds in this run (the machine was heavily loaded; see "About the runs"), is the one that compiles the Go program inside an image that carries the compiler. At the end `naming to docker.io/library/curso-docker-prueba:1.0.0` appears: the short name you gave is, in full, that of a Docker Hub image in the official library (`library`), even though it will never be pushed anywhere; that is how Docker names everything that does not carry a written registry. And the exit code is **0**: everything went well. Lessons 3, 4 and 5 teach you to read this file line by line.

#### 2.1.3 Finding the image

```text
== 3. La imagen ya está en tu equipo
WARNING: This output is designed for human readability. For machine-readable output, please use --format.
IMAGE                       ID             DISK USAGE   CONTENT SIZE   EXTRA
curso-docker-prueba:1.0.0   56406ca1d761       15.1MB         3.37MB        

== 4. Y el intento fallido no dejó contenedores
0

== 5. El tamaño, con un formato propio
curso-docker-prueba:1.0.0 15.1MB
```

If you come from old tutorials, this table will look different to you. Since version 29.0, `docker image ls` shows a new view by default, "like `--tree`, but collapsed", and hides untagged images unless you ask for `--all` ([Docker Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/)). The command's reference page still shows the earlier columns (`REPOSITORY`, `TAG`, `IMAGE ID`, `CREATED`, `SIZE`) ([docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/)), so do not be surprised if your output and a tutorial do not match. The `WARNING` on the first line is Docker itself telling you: this view is for a person to read; if you are going to process the output with a script, use `--format`, which is what the rest of the lesson does.

The column this course uses to talk about an image's size is **DISK USAGE**: 15.1 MB is what the image takes on your disk. The **CONTENT SIZE** column is smaller; everything suggests it counts the image's content compressed, as it travels over the network, but the reference documentation does not describe it yet, so in this course we do not use it for anything. With a custom format you get the size directly:

```bash
docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

It is block 5 of `fig02_01.sh`, and in the run it printed `curso-docker-prueba:1.0.0 15.1MB`.

Block 4 confirms something that matters for cleanup: the failed `docker run` of section 2.1.1 **left no container**. Since there was no image, there was nothing to create it from. In "The error you will see" you trigger one that does leave a container.

A warning if you repeat the script: with the image already built, block 1 does **not** fail. It creates the container `curso-docker-prueba`, prints its identifier and ends with code 0, and block 4 counts `1` and not `0`, because that container keeps running until the `trap` deletes it on exit. It is not an error: it is the proof that block 1's error depended on the image not existing. The run is in `fig02_01.salida-repetida.txt`.

### 2.2 Starting a container

#### 2.2.1 The command, option by option

With the image ready, this lesson's command:

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Read it from left to right. Each option answers a question that, if you do not answer it, Docker answers for you, and almost never the way you would like:

| Option | Question it answers | What happens if you leave it out |
|---|---|---|
| `-d` | do you give me my terminal back? | the container stays attached to your terminal; if you close it or press Ctrl+C, the signal reaches it |
| `--name curso-docker-prueba` | what is it called? | Docker makes up a random name, like `busy_goldwasser`, which you will not remember |
| `-p 127.0.0.1:9000:9000` | who can talk to it, and through which port? | no other machine, and you only through the container's internal address, not through `127.0.0.1`; and if you put `-p 9000:9000` without an address, **anyone on your network** |
| `--memory 64m` | how much memory can it use? | all of your machine's |
| `--cpus 0.5` | how much CPU? | all of it |
| `--pids-limit 50` | how many processes (and threads) can it create? | as many as it wants |
| `curso-docker-prueba:1.0.0` | from which image? | (mandatory) |

`-d` is the short form of `--detach`: according to the documentation, it runs the container in the background and prints its identifier ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Without `-d`, the service's output shows up in your terminal and the terminal stays busy until the container ends. That is sometimes useful for a quick test; for a server, almost never.

`--name` gives it a name. The documentation says that, if you do not give one, the daemon generates a random one ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). A name of your own is useful for two things: to type `docker logs curso-docker-prueba` instead of copying a 64-character identifier, and so that the name reminds you whose container it is. But it has a consequence: **in the same daemon there cannot be two containers with the same name**, not even if one is stopped. It is the first error of the scene, and you trigger it in "The error you will see".

`-p` is the short form of `--publish`, and has three parts separated by colons: `address:host-port:container-port`. `127.0.0.1:9000:9000` means "on my machine, only at the `127.0.0.1` address and on port 9000, receive connections and pass them to the container's port 9000". The two numbers do not have to be equal: with `127.0.0.1:18000:9000`, you would talk to it on 18000 and the service would keep listening on its 9000. Remember from Lesson 0 that each container has its own network. Without `-p`, its port 9000 can only be reached from Docker's internal network: from the other containers on that network and from your own machine, if you use the container's internal address; the documentation puts it like this: the ports of containers on bridge-type networks are accessible from the host even if they are not published ([Docker, "Port publishing and mapping"](https://docs.docker.com/engine/network/port-publishing/)). What is not reached without `-p` is the port from your machine's `127.0.0.1` or from any other machine. Section 2.8 is devoted to the address, which is the most important part.

`--memory`, `--cpus` and `--pids-limit` are the budget that Lesson 0 taught you to read in `/sys/fs/cgroup`. Section 2.9 explains why these numbers.

#### 2.2.2 Starting it and waiting for it to answer

`fig02_02.sh` starts the container and does with it what you would do on a normal day. This is the complete script; its output is spread across sections 2.2 to 2.5:

```bash
#!/usr/bin/env bash
# fig02_02.sh — El servicio de prueba corriendo: arrancar, listar, consultar y leer su bitácora.
# Puerto publicado solo en 127.0.0.1 y con límites de memoria, CPU y procesos.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
NOMBRE="${PREFIJO}prueba"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== 1. Arrancar en segundo plano"
docker run -d --name "$NOMBRE" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" | cut -c1-12
# Esperar a que conteste (máximo 10 s), en vez de dormir un número fijo.
for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && break; sleep 0.5; done

echo
echo "== 2. Lo que está corriendo"
docker ps --filter name="$NOMBRE" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== 3. Consultarlo en sus tres modos"
curl -s "http://127.0.0.1:${PUERTO}/"
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/caido"
curl -s -w 'código HTTP: %{http_code}\n' "http://127.0.0.1:${PUERTO}/"
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/lento"
curl -s -w 'código HTTP: %{http_code} en %{time_total} s\n' "http://127.0.0.1:${PUERTO}/"
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/sano"
curl -s "http://127.0.0.1:${PUERTO}/modo"

echo
echo "== 4. Su bitácora completa"
docker logs "$NOMBRE"

echo
echo "== 5. Solo los dos últimos renglones"
docker logs --tail 2 "$NOMBRE"
```

```text
$ ./fig02_02.sh
== 1. Arrancar en segundo plano
7f01c45325dd
```

All that `docker run -d` prints is the container's **identifier**, a 64-character hexadecimal number; the script trims it to the first 12 with `cut -c1-12`, which is how Docker shows it almost everywhere. It changes on every run. Its appearing means that the container was created and asked to start; it does **not** mean that the service inside is already serving.

That is why the script's next line is a loop: it tries a request with `curl` every half second, up to twenty times, and exits as soon as one answers properly. `curl -f` makes `curl` fail if the server responds with an error, `-s` silences it and `-o /dev/null` throws the response away. It is better than a fixed `sleep 3` for two reasons: on a fast computer you do not wait more than needed, and on a slow one you do not move on too early. You will see this pattern in all the course scripts that talk to the service; where it is not talked to, there is no need to wait.

The `trap ... EXIT` above is the same habit as in Lesson 0: whatever happens, when it exits the script deletes its container. You will always see it in this lesson's scripts, because section 2.11 makes it a rule.

### 2.3 Seeing what is running: `docker ps`

```text
== 2. Lo que está corriendo
NAMES                 IMAGE                       STATUS                            PORTS
curso-docker-prueba   curso-docker-prueba:1.0.0   Up 2 seconds (health: starting)   127.0.0.1:9000->9000/tcp
```

`docker ps` lists containers. By default it shows only **the ones that are running**; with `-a` (`--all`) it also shows the stopped ones ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). That difference is what hides the leftovers: a stopped container does not appear in `docker ps`, but it still exists, takes up disk and holds on to its name.

The script uses two options that are worth learning right away. `--filter name=curso-docker-prueba` leaves only the containers whose name contains that text; the documentation says the `name` filter matches "all or part" of the name ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). And `--format 'table ...'` chooses the columns: `{{.Names}}`, `{{.Image}}`, `{{.Status}}` and `{{.Ports}}` are fields, and the word `table` at the beginning asks for headers and aligned columns. What goes between double braces is a Go-language template; you do not need to know Go to use it, only the field names, which the command's page lists. There are other useful filters; the status one, for example, accepts `created`, `restarting`, `running`, `removing`, `paused`, `exited` and `dead` ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)).

The columns, one by one:

- **NAMES** is the name you gave it.
- **IMAGE**, the image it was born from.
- **STATUS** says `Up 2 seconds`: it has been running for two seconds. And it carries something else, `(health: starting)`, which deserves a paragraph of its own.
- **PORTS** says `127.0.0.1:9000->9000/tcp`: your machine's port 9000, only on `127.0.0.1`, leads to the container's 9000, over TCP.

The `(health: starting)` appears because the test service's `Dockerfile` has a `HEALTHCHECK` instruction: it tells Docker to run, every five seconds, the `servicio-prueba healthcheck` subcommand inside the container, which asks the service itself whether it answers properly. As long as no check has passed yet, the status is `starting`; it becomes `healthy` with the first one that answers properly, and `unhealthy` when as many fail in a row as `retries` says (in this image, two) ([Dockerfile reference, `HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck)). Today you will not use it for anything beyond reading it; how a health check is written and what Docker does with it is the subject of Lesson 7. But notice from now on that **`Up` and health are two different things**: `Up` says the process exists; health says whether it is serving. The next section shows it.

### 2.4 Talking to the service

```text
== 3. Consultarlo en sus tres modos
sano
modo: caido
caido
código HTTP: 503
modo: lento
lento
código HTTP: 200 en 3.002647 s
modo: sano
modo: sano
```

Read each pair of lines as a question and its answer:

1. `GET /` in healthy mode answers `sano`.
2. `POST /modo/caido` changes the mode and confirms `modo: caido`. From that instant, `GET /` answers the text `caido` with code **503** (*Service Unavailable*, [RFC 9110, §15.6.4](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.6.4)). `curl`'s `-w` option prints data about the request after the response; here, the HTTP code.
3. `POST /modo/lento` and the next `GET /` takes **3.00 seconds** to answer `lento` with a 200. The three seconds are the slow mode's delay; the extra (here, about two thousandths) is the round trip. That number changes a little on every run.
4. `POST /modo/sano` returns it to normal, and `GET /modo` confirms it.

Now the question that matters. While the service was answering `503`, what did `docker ps` say? It said `Up`. For Docker, the container was perfect: the process existed and had not ended. For anyone using it, it was down. **Docker does not know what your service answers**, unless you teach it with a health check. It is the principle the course repeats in every lesson: a running container is not a healthy service. The `revisor`, the project you will package from Lesson 3, exists exactly to ask that question from the outside.

### 2.5 The log: `docker logs`

```text
== 4. Su bitácora completa
servicio-prueba escuchando en :9000 en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: modo cambiado a caido
servicio-prueba: GET / en modo caido
servicio-prueba: modo cambiado a lento
servicio-prueba: GET / en modo lento
servicio-prueba: modo cambiado a sano

== 5. Solo los dos últimos renglones
servicio-prueba: GET / en modo lento
servicio-prueba: modo cambiado a sano
```

Everything the container's main program writes to its **standard output** and its **error output** —what in your terminal you would see with `printf` or with `echo`— is stored by Docker, and `docker logs` gives it back to you. The documentation describes it like this: the command delivers the logs that exist at the moment it is run, and with `--follow` it keeps streaming whatever new comes out of the container's `STDOUT` and `STDERR` ([docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/)).

Notice that the log tells the whole story of the previous section, in order: the startup, the first two requests (the one from the wait loop and yours), each mode change and each request with its mode. The requests to `/modo` leave no trace because the service does not record them; a program leaves in the log only what its author decided to write. And a warning: the image's health check (2.3) also does a `GET /` every five seconds, and each one leaves its line. The first one runs five seconds after startup ([Dockerfile reference, `HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck)). In this run none appears, and it is not because the run lasted less than five seconds: block 2 already said `Up 2 seconds` and the slow request in block 3 took three more. The most likely explanation is that the first check fell while the service was in slow mode: the check gives up after two seconds, and the service, seeing that whoever asked has already left, returns without recording the request that was left half-done (in its code, slow mode ends without writing if the request is canceled). That is, the check happened and left no trace. In a container that has been running for a while you will see `GET / en modo …` lines that you did not ask for, and on your machine, depending on its speed, one extra may appear at the end of this block and then your block 5 will be different. Docker asked for them, not you.

The options you will use every day, all from the [command's page](https://docs.docker.com/reference/cli/docker/container/logs/):

| Option | What it does |
|---|---|
| `--tail N` (or `-n N`) | only the last N lines; by default, all |
| `--follow` (or `-f`) | keeps listening and shows you what is new as it arrives; you leave with Ctrl+C |
| `--since 10m` | only the last ten minutes; it also accepts a date and time |
| `--timestamps` (or `-t`) | prefixes each line with the time Docker received it |

`--tail` matters more than it seems. A service that has been running for weeks can have millions of lines, and a `docker logs` without limits fills your terminal. The good habit is `docker logs --tail 50 <name>` first, and `-f` if you want to keep watching.

Two warnings that will spare you some scares. **The log survives `docker stop`, but not `docker rm`:** it lives with the container, so you can read it after stopping it (you will see it in 2.10) and it disappears when you delete it. If a container died in a strange way, **read its log before deleting it**. And **`docker logs` only sees what the main program writes to its two outputs**: if the program writes its log to a file inside the container, `docker logs` does not see it. That is why programs designed for containers, like the test service and the `revisor`, write everything to standard output.

### 2.6 Getting into the container: `docker exec`

#### 2.6.1 The image has no shell

In tutorials you will see this command a lot: `docker exec -it <name> sh`, "to get into the container". `docker exec` runs a program **inside** a container that is already running; `-i` keeps standard input open and `-t` assigns it a terminal, so you can type commands ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)). Try it with the test service, which is what `fig02_03.sh` does (without `-it`, because a script has nobody typing):

```bash
#!/usr/bin/env bash
# fig02_03.sh — exec: ejecutar un programa dentro de un contenedor que ya corre.
# La imagen del servicio de prueba no trae shell: se ve el error y lo que sí funciona.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
NOMBRE="${PREFIJO}prueba"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && break; sleep 0.5; done

echo "== 1. Pedir un shell"
docker exec "$NOMBRE" sh
echo "código de salida: $?"

echo
echo "== 2. Ejecutar un programa que la imagen SÍ trae"
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 3. Lo mismo, con el servicio en modo caído"
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/caido" >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 4. exec en un contenedor detenido"
docker stop "$NOMBRE" >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"
```

```text
$ ./fig02_03.sh
== 1. Pedir un shell
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH
código de salida: 127

== 2. Ejecutar un programa que la imagen SÍ trae
sano
código de salida: 0

== 3. Lo mismo, con el servicio en modo caído
no sano: GET / respondió 503
código de salida: 1

== 4. exec en un contenedor detenido
Error response from daemon: container 9601e9716cd5e38f75a59d4cfb0b59706907808aaefba701a04fb9244a931c4a is not running
código de salida: 1
```

The first block is the error. Read it from right to left, which is how almost all Docker errors are read: the cause is at the end. `exec: "sh": executable file not found in $PATH` says there is no program called `sh` in the folders where programs are searched for. What comes before, `OCI runtime exec failed`, says who discovered it: `runc`, the program that creates the containers' processes (you met it in Lesson 0). And code **127** is the same one that `docker run`'s documentation reserves for "the command was not found" (2.1.1); in `exec` the runtime returns it, with the same meaning.

It is not a failure of the container: it is a design decision. The test service's image was built on a minimal base, of the so-called *distroless* kind, which **only carries the program and what is essential for it to run**: it has no `sh`, no `ls`, no `cat`, no package manager. That has a price, which you have just paid: you cannot "get in" to poke around. And it has a gain, which Lesson 5 takes advantage of for the `revisor`: if someone managed to run something inside that container, they would find no tools to go further. An image without a shell is an image with less to attack with.

#### 2.6.2 What you can do

The second block shows that `exec` works perfectly with a program the image **does** carry: `/servicio-prueba` itself, with its `healthcheck` subcommand. The program asks the service running next to it whether it answers, prints `sano` and exits with 0. The third block repeats the question with the service in down mode: `no sano: GET / respondió 503`, and exits with 1. That subcommand is the same one the `HEALTHCHECK` instruction runs every five seconds; you have just run it by hand. Notice that here the code is not 127 but 1: the program was found and did run; it simply answered "no".

Two `exec` rules that come from its documentation ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)):

- **It only works while the container's main process is running.** That is the fourth block: with the container stopped, the daemon answers `container ... is not running`. To see what happened to a stopped container you do not use `exec`, you use `logs` and `inspect`.
- **The command has to be an executable**, not a shell line. `docker exec <name> "echo hola && ls"` does not work; if the image has a shell, you write `docker exec <name> sh -c 'echo hola && ls'`.

When the image does carry a shell, like the `alpine:3.24.2` from Lesson 0, the famous command works and leaves you typing inside:

```bash
docker run -d --name curso-docker-dormilon --memory 16m --cpus 0.25 --pids-limit 20 \
  alpine:3.24.2 sleep 300
docker exec -it curso-docker-dormilon sh
```

Use it to **look**, never to **fix**. You learned it in Lesson 0: what you change in there lives in the container's layer and goes away with it. And delete the container when you finish: `docker rm -f curso-docker-dormilon`.

### 2.7 What Docker knows about a container: `inspect` and `stats`

#### 2.7.1 `docker inspect` with a template

`docker inspect` returns "low-level information" about a Docker object ([docker inspect](https://docs.docker.com/reference/cli/docker/inspect/)): everything the daemon knows about it, in JSON. It is a lot. `fig02_04.sh` uses it with templates to pull out only what matters, and compares the container with limits against an identical one without limits:

```bash
#!/usr/bin/env bash
# fig02_04.sh — inspect y stats: lo que Docker sabe de un contenedor, con y sin límites.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
CON="${PREFIJO}prueba"
SIN="${PREFIJO}sin-limites"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "$CON" "$SIN" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CON" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
docker run -d --name "$SIN" "$IMAGEN" >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && break; sleep 0.5; done

FORMATO='{{.Name}}: memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}'

echo "== 1. inspect, con una plantilla: solo los campos que me importan"
docker inspect --format "$FORMATO" "$CON" "$SIN"

echo
echo "== 2. inspect: estado, puerto publicado y comando principal"
docker inspect --format 'estado={{.State.Status}} pid1={{.Config.Entrypoint}} puertos={{json .HostConfig.PortBindings}}' "$CON"

echo
echo "== 3. stats: lo que gastan ahora mismo, contra su límite"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.PIDs}}' "$CON" "$SIN"

echo
echo "== 4. Cuántos renglones trae inspect completo"
docker inspect "$CON" | wc -l
```

```text
$ ./fig02_04.sh
== 1. inspect, con una plantilla: solo los campos que me importan
/curso-docker-prueba: memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532
/curso-docker-sin-limites: memoria=0 cpus(nano)=0 pids=<no value> usuario=65532:65532

== 2. inspect: estado, puerto publicado y comando principal
estado=running pid1=[/servicio-prueba] puertos={"9000/tcp":[{"HostIp":"127.0.0.1","HostPort":"9000"}]}

== 3. stats: lo que gastan ahora mismo, contra su límite
NAME                       MEM USAGE / LIMIT    PIDS
curso-docker-prueba        1.484MiB / 64MiB     7
curso-docker-sin-limites   1.57MiB / 15.59GiB   8

== 4. Cuántos renglones trae inspect completo
224
```

The whole first block is stable: these numbers come out the same on your Mint. Read them:

- `memoria=67108864` is 64 × 1024 × 1024 bytes: the 64 MiB you asked for, the same number Lesson 0 read in `memory.max`.
- `cpus(nano)=500000000`: Docker stores CPU in billionths of a CPU; 500 million is half a CPU.
- `pids=50`, the process cap.
- `usuario=65532:65532`: the service **does not run as `root`**. The image decided that, with a `USER` instruction that Lesson 3 teaches you to write. Compare it with Lesson 0's `sleep`, which ran as user 0.

And the line for the container without limits says `memoria=0`, `cpus(nano)=0` and `pids=<no value>`. In this field, **zero does not mean "no memory": it means "no limit"**. It is how Docker stores "you asked me for nothing". `<no value>` is what the template prints when the field is empty: in `docker inspect`'s full JSON it appears as `"PidsLimit": null`. When you review someone else's container, a zero here is an alarm signal, not a reassuring one.

The name comes out with a slash in front, `/curso-docker-prueba`. It is not a mistake of yours: that is how Docker stores names internally, and that is why the repeated-name message in "The error you will see" carries it too.

The second block shows three other fields. `.State.Status` is the state (`running`). `.Config.Entrypoint` is the program the image starts as the main process. And `{{json .HostConfig.PortBindings}}` uses the templates' `json` function to print a compound field as it is: the container's port 9000 is bound to address `127.0.0.1`, port 9000, of your machine.

The fourth block explains why templates are used: the full `inspect` of this container, which is one of the simple ones, has **224 lines**. Reading it whole is useful once, to know what is there. To ask something specific, a template.

#### 2.7.2 `docker stats`: what it is spending right now

`inspect` says what the limits are; `docker stats` says **how much is being spent**. By default it is a screen that updates itself, like `top`; with `--no-stream` it takes a single reading and ends, which is what a script needs ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)). The **MEM USAGE / LIMIT** column shows the memory the container uses against the memory it is allowed, and **PIDS** how many processes and threads it has created ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)).

The test service uses between 1 and 2 MiB and has a handful of threads (7 and 8 in this run; the number varies from run to run). What matters is the limit column. With limits it says `64MiB`. Without limits it says `15.59GiB`, which is **all the memory of the machine** where it ran (the Colima virtual machine). On your Mint, that number will be your computer's memory. It is Lesson 0's scene seen from Docker: a container with no limit has the whole machine as its limit.

### 2.8 Ports: `127.0.0.1` versus all interfaces

#### 2.8.1 What the address means

Your computer has several **network interfaces**, which are like doors through which connections come in: the wireless one, perhaps the cable one, and a special one called ***loopback***, with the address `127.0.0.1`. The *loopback* one leads nowhere outside your machine: what comes in through there can only come from your own computer.

When you publish a port without an address, with `-p 9000:9000`, Docker publishes it **on all interfaces**. The documentation says so bluntly: if you do not give an address, the daemon publishes ports on all the host's addresses, `0.0.0.0` and `[::]`, and it warns in a callout that "publishing container ports is insecure by default", because the port is within reach not only of the host but of "the outside world" ([Docker, "Port publishing and mapping"](https://docs.docker.com/engine/network/port-publishing/)). With `127.0.0.1` in front, "only the host can access" the published port (same source). That holds since Docker 28: the same page warns that, in versions before 28.0.0, machines on the same network segment could reach ports published on `127.0.0.1`. It is one more reason to install Docker from the official repository, as in Lesson 1, and not an old version.

`fig02_05.sh` starts two copies of the service, one of each kind, and asks Docker and the operating system where they ended up:

```bash
#!/usr/bin/env bash
# fig02_05.sh — Publicar en 127.0.0.1 contra publicar en todas las interfaces.
# Se corre en el anfitrión (tu Mint): ss lista los puertos en los que escucha el equipo.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
ABIERTO=$((PUERTO + 1))        # el segundo puerto, el que se abre a propósito
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "${PREFIJO}prueba" "${PREFIJO}abierto" >/dev/null 2>&1 || true' EXIT

docker run -d --name "${PREFIJO}prueba" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
docker run -d --name "${PREFIJO}abierto" -p "${ABIERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
for p in "$PUERTO" "$ABIERTO"; do
  for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:$p/" && break; sleep 0.5; done
done

echo "== 1. Lo que dice docker port"
echo "-- ${PREFIJO}prueba:"; docker port "${PREFIJO}prueba"
echo "-- ${PREFIJO}abierto:"; docker port "${PREFIJO}abierto"

echo
echo "== 2. Lo que dice el sistema operativo: dónde escucha el equipo"
ss -ltn | grep -E ":(${PUERTO}|${ABIERTO}) " | awk '{print $4}' | sort
```

```text
$ ./fig02_05.sh
== 1. Lo que dice docker port
-- curso-docker-prueba:
9000/tcp -> 127.0.0.1:9000
-- curso-docker-abierto:
9000/tcp -> 0.0.0.0:9001
9000/tcp -> [::]:9001

== 2. Lo que dice el sistema operativo: dónde escucha el equipo
0.0.0.0:9001
127.0.0.1:9000
[::]:9001
```

`docker port` shows, for a container, which of its ports goes to which address and port of your machine. `ss -ltn` is a normal Linux tool that lists the ports where the machine listens for TCP connections (`-l` listening, `-t` TCP, `-n` with numbers instead of names); the `grep` leaves only the lines for ports 9000 and 9001, and the `awk` keeps the address column.

Both sources say the same thing. The correctly published container listens **only** on `127.0.0.1:9000`. The other one listens on `0.0.0.0:9001`, which in networking language means "on all of this machine's IPv4 addresses", and on `[::]:9001`, the same for IPv6. If your Mint is connected to the network of a café, a university or an office, anyone on that network can type your computer's address and port 9001 and talk to your container. The test service is harmless; a test database with a sample password is not.

#### 2.8.2 The firewall does not save you

You may think that is what you have a firewall for. On Mint, the desktop firewall is `ufw`. Here is the trap: **the ports Docker publishes go over the top of `ufw`'s rules**. The `docker run` reference warns about it: ports published on all interfaces are reachable from outside even if `ufw` is configured to block them, because Docker manages its own packet-filtering rules ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Docker's firewall guide explains the mechanism: a container's traffic is "diverted before it goes through `ufw`'s configuration" and the packets are routed "before the firewall rules can be applied" ([Docker, "Packet filtering and firewalls"](https://docs.docker.com/engine/network/packet-filtering-firewalls/)).

Do not measure it on your network without permission. It is enough to know it and to draw the conclusion: **the protection is in the `-p`, not in the firewall**. Whoever needs to really filter the traffic to containers has the `DOCKER-USER` chain (1.3), but that is work with hand-written `iptables` rules, not with `ufw` as it comes, and it does not change the conclusion for a normal desktop. That is why in this course all ports are published with `127.0.0.1:` in front, and the only one that does not carry it is this script's `9001`, which exists so that you can see it and is deleted when it finishes.

> [!NOTE]
> 🔧 **Engineering observation 2.2**
> An extra published port gives no warning. There is no message saying "this container was left open to your network". The only way to know is to ask: `docker ps` in the PORTS column (look for `0.0.0.0` or `[::]`) or `ss -ltn` on the machine. Make it a habit every time you connect to a network that is not yours.

### 2.9 Limits: memory, CPU and processes

Lesson 0 showed you what limits do on the inside: Docker writes a number into a kernel file and the kernel enforces it. Here the question is practical: **which numbers to set**.

Docker's documentation is clear about what happens if you set none: a container "has no resource constraints" and uses whatever the kernel's scheduler lets it; and when the machine runs out of memory, the kernel starts killing processes, any process, including Docker itself, and that "can bring down the entire system if the wrong process is killed" ([Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/)). The three limits in this lesson's command:

**`--memory 64m`.** The test service uses between 1 and 2 MiB (you measured it in 2.7.2). 64 MiB give it a margin of more than thirty times. The general rule is that one: **measure first, and set a generous limit above what you measured**, not below. If the program goes over the limit, the kernel kills it inside its own group, as you saw in Lesson 0 (code 137 and `OOMKilled=true`), and nobody else on your machine finds out. The documentation sets a minimum of 6 MB for this option ([Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/)).

**`--cpus 0.5`.** Half a CPU. A service that only answers small requests does not need more, and if it enters an infinite loop because of a bug, it eats half a CPU and not all of it. The documentation explains it with its own example: on a machine with two CPUs, `--cpus="1.5"` guarantees the container at most one and a half CPUs ([Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/)). Unlike memory, going over on CPU kills nobody: the kernel simply gives it less time (it is said to *throttle* it), and the program goes slower. Watch for an indirect consequence: a service that is throttled too much can take longer to answer than its health check tolerates (2.3), and then Docker will mark it `unhealthy` without anything having killed it.

**`--pids-limit 50`.** It sets the container's process cap; with `-1` it is removed ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). This limit protects against something very specific: a program that, by mistake or through an attack, creates processes nonstop. Without a cap, it can fill the machine's process table and leave you unable to open even a terminal. The service had 7 or 8 (2.7.2); 50 is plenty.

Notice that the three limits go **from the very first container**, not "when the service is in production". Lesson 0 said it with the scene of the database: the limit is not for the normal day, it is for the bad day, and the bad day gives no warning.

### 2.10 The life cycle: stopping, restarting and deleting

#### 2.10.1 The states

A container goes through states, and each command moves it from one to another:

| State | How it gets there | What `docker ps -a` shows |
|---|---|---|
| created (`created`) | `docker create`, or a `docker run` that could not start | `Created` |
| running (`running`) | `docker run` or `docker start` | `Up …` |
| stopped (`exited`) | `docker stop`, or the main program ended on its own | `Exited (code) …` |
| deleted | `docker rm` | no longer appears |

The most important thing in the table is the difference between **stopped** and **deleted**. A stopped container does not run, but it exists: it keeps its write layer, its log, its configuration and its name. It can be started again. A deleted container no longer exists, and its layer and its log go with it.

`fig02_07.sh` walks through the whole cycle and ends with the cleanup check:

```bash
#!/usr/bin/env bash
# fig02_07.sh — El ciclo de vida completo y la limpieza: stop, start, rm y --rm.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
NOMBRE="${PREFIJO}prueba"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "$NOMBRE" "${PREFIJO}efimero" >/dev/null 2>&1 || true' EXIT
ms() { date +%s%3N; }

docker run -d --name "$NOMBRE" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && break; sleep 0.5; done

echo "== 1. Borrar un contenedor que está corriendo, sin -f"
docker rm "$NOMBRE"
echo "código de salida: $?"

echo
echo "== 2. Detenerlo, midiendo cuánto tarda"
inicio=$(ms); docker stop "$NOMBRE" >/dev/null; fin=$(ms)
echo "docker stop tardó $(( fin - inicio )) ms"
docker ps -a --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'
docker logs --tail 2 "$NOMBRE"

echo
echo "== 3. Detenido no es borrado: vuelve a arrancar con start"
docker start "$NOMBRE" >/dev/null
docker ps --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'

echo
echo "== 4. Ahora sí: borrarlo"
docker stop "$NOMBRE" >/dev/null
docker rm "$NOMBRE"

echo
echo "== 5. Un contenedor con --rm se borra solo al terminar"
# Lo que va después de la imagen reemplaza al comando por omisión: aquí, en vez
# de servir, el programa corre su subcomando healthcheck y termina.
docker run --rm --name "${PREFIJO}efimero" "$IMAGEN" healthcheck
echo "código de salida: $?"
docker ps -a --filter name="${PREFIJO}efimero" --format '{{.Names}}' | wc -l

echo
echo "== 6. La revisión final: ningún contenedor del curso"
docker ps -a --filter name="^${PREFIJO}" --format '{{.Names}}' | wc -l
```

```text
$ ./fig02_07.sh
== 1. Borrar un contenedor que está corriendo, sin -f
Error response from daemon: cannot remove container "curso-docker-prueba": container is running: stop the container before removing or force remove
código de salida: 1

== 2. Detenerlo, midiendo cuánto tarda
docker stop tardó 414 ms
curso-docker-prueba Exited (0) Less than a second ago
servicio-prueba: GET / en modo sano
servicio-prueba: recibí terminated, apagando

== 3. Detenido no es borrado: vuelve a arrancar con start
curso-docker-prueba Up Less than a second (health: starting)

== 4. Ahora sí: borrarlo
curso-docker-prueba

== 5. Un contenedor con --rm se borra solo al terminar
no sano: Get "http://127.0.0.1:9000/": dial tcp 127.0.0.1:9000: connect: connection refused
código de salida: 1
0

== 6. La revisión final: ningún contenedor del curso
0
```

The times change on every run; everything else comes out the same.

#### 2.10.2 `docker rm` does not delete what is running

The first block is a protection: Docker does not let you delete a container that is running. The message gives you the two ways out: stop it first (*stop the container before removing*) or force the deletion (*force remove*). Forcing is `docker rm -f`, and the documentation says what it does: it sends `SIGKILL` to the main process and then deletes the container ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)). `SIGKILL` is signal 9, the one Lesson 0 taught you to recognize in code 137: it cannot be caught, so the program has no chance to close anything. For a test container you are about to throw away, it is fine, and the `trap`s in these scripts use it. For a service with data, `stop` first.

#### 2.10.3 `docker stop`: the signal and the deadline

`docker stop` is the polite way. The documentation says it sends the main process the `SIGTERM` signal (unless the image or the container configures another one), waits for a deadline —by default, **10 seconds** on Linux— and, if the container is still alive, kills it with `SIGKILL`. The deadline is changed with `--timeout` ([docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/)).

The second block shows that the test service shuts down properly. `docker stop` took **414 ms** in this run (the machine was loaded), far less than the 10-second deadline. The state is `Exited (0)`: the program ended on its own with code 0, which on Linux is "all good". And the log, which is still there after stopping it, shows why: `recibí terminated, apagando`. The service is written to handle `SIGTERM` (*terminated* is how Go names that signal): it receives it, stops accepting requests and exits. If the program ignored the signal, you would see `docker stop` take 10 seconds and the state `Exited (137)`. Why a program sometimes does not receive the signal, even if it is written to handle it, is a real problem with its own name, that of process number 1, and Lessons 3 and 7 deal with it.

#### 2.10.4 `docker start`: stopped is not deleted

The third block starts the same container again with `docker start`. There is no need to repeat the options: the name, the port and the limits were stored in the container. `docker start` is used to continue something you stopped. The memory, CPU and process limits can indeed be changed without recreating the container, with `docker update` ([docker container update](https://docs.docker.com/reference/cli/docker/container/update/)), which this course does not use in its scripts but which `fig02_10.sh` tests: with the container running, `docker update --memory 128m --memory-swap 128m --cpus 1 --pids-limit 100` left `memoria=134217728 cpus(nano)=1000000000 pids=100`, the container kept running with no restarts, and `-p` does not exist as an option of `update`. (`--memory-swap` goes together with `--memory` because otherwise `docker update` complains when the swap cap already set ends up below the new memory.) What cannot be changed is the published port or the image: for that you have to delete the container and create a new one with `docker run`. This is `fig02_10.sh`:

```bash
#!/usr/bin/env bash
# fig02_10.sh — docker update: cambiar los límites de un contenedor sin recrearlo.
# El puerto publicado y la imagen, en cambio, sí exigen un contenedor nuevo.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
IMAGEN="${PREFIJO}prueba:1.0.0"
NOMBRE="${PREFIJO}prueba"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT
FORMATO='memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} puertos={{json .HostConfig.PortBindings}}'

docker run -d --name "$NOMBRE" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null

echo "== 1. Antes"
docker inspect --format "$FORMATO" "$NOMBRE"

echo
echo "== 2. docker update de los tres límites, con el contenedor corriendo"
docker update --memory 128m --memory-swap 128m --cpus 1 --pids-limit 100 "$NOMBRE"
echo "código de salida: $?"

echo
echo "== 3. Después (mismo contenedor, sin reiniciar)"
docker inspect --format "$FORMATO" "$NOMBRE"
docker inspect --format 'sigue corriendo: {{.State.Running}}, reinicios: {{.RestartCount}}' "$NOMBRE"

echo
echo "== 4. El puerto publicado no tiene opción en update"
docker update -p 127.0.0.1:9002:9000 "$NOMBRE" 2>&1 | head -2
```

Real run:

```text
$ ./fig02_10.sh
== 1. Antes
memoria=67108864 cpus(nano)=500000000 pids=50 puertos={"9000/tcp":[{"HostIp":"127.0.0.1","HostPort":"9000"}]}

== 2. docker update de los tres límites, con el contenedor corriendo
curso-docker-prueba
código de salida: 0

== 3. Después (mismo contenedor, sin reiniciar)
memoria=134217728 cpus(nano)=1000000000 pids=100 puertos={"9000/tcp":[{"HostIp":"127.0.0.1","HostPort":"9000"}]}
sigue corriendo: true, reinicios: 0

== 4. El puerto publicado no tiene opción en update
unknown shorthand flag: 'p' in -p
```

The fourth block does the cleanup in order: `stop` and then `rm`, which prints the name of what it deleted.

#### 2.10.5 `--rm`: containers that delete themselves

For containers that only run one task and finish there is `--rm`: according to the documentation, it deletes the container, and its anonymous volumes, automatically when it ends (volumes are the subject of Lesson 8) ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). The fifth block uses it with a new detail: after the image name comes the word `healthcheck`. **What you write after the image is passed to the main program**, and here it turns the service into its own client: instead of serving, it runs the health check and ends. Since inside that container nobody is serving on port 9000, the check fails with `connection refused` and code 1. And the `0` afterwards says the container no longer exists: `--rm` deleted it.

A detail measured while writing this lesson: with `docker run -d --rm`, the deletion happens **an instant after** the container stops, and not before `docker stop` returns. In a first version of this script, which did `docker stop` of a `-d --rm` container and counted right away, the count came out `1`: the stopped container was still there for a few milliseconds. That is why the script uses the form without `-d`, in which `docker run` does not return until the container has finished and been deleted. If one of your own scripts ever counts containers right after stopping one with `--rm`, now you know where the extra number comes from.

### 2.11 Leaving no leftovers

#### 2.11.1 Only what is yours

The sixth block of `fig02_07.sh` is the check you will do at the end of each lesson of the course:

```bash
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

`-a` includes the stopped ones, which are the ones that get forgotten. The filter `name=^curso-docker-` leaves only the containers whose name **starts with** `curso-docker-`: the `^` marks the start of the name. The documentation only says that the filter matches all or part of the name, so it was checked while writing this lesson, with block 4 of `fig02_06.sh`: with three containers (`curso-docker-prueba`, `curso-docker-otro` and an `viejo-curso-docker-x`), `--filter name=prueba` found one, but `--filter name='^prueba'` found none, even though the name has `prueba` in the middle: the `^` really anchors to the start. And `--filter name=curso-docker-` found all three, while `--filter name='^curso-docker-'` found only the two that start that way. Without the `^`, a filter for `curso-docker-` also catches the `viejo-curso-docker-x` that is not yours. And `wc -l` counts lines. If it comes out `0`, you left nothing behind.

To **delete** everything of yours in one go, the same list serves as input to `docker rm -f`:

```bash
docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f
```

`-q` asks for only the identifiers ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)), `xargs` passes them as arguments to the next command, and `-r` makes `xargs` run nothing if the list is empty.

This is the underlying reason for the course rule that **everything you create starts with `curso-docker-`**: it lets you clean up only what is yours without touching anything else on the machine.

#### 2.11.2 The command you must not use blindly

Sooner or later you will read `docker container prune` in a tutorial. It does exactly what its documentation says: "removes **all** stopped containers" ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). All of them: yours, those of other projects you may have on the same machine and those of any tool that uses Docker underneath. A stopped container may be another project's database that you left switched off on purpose, with its configuration stored in the container. `prune` does not ask whose it is; it asks only once "are you sure?", and with `--force` not even that. It accepts filters by label and by age, but not by name ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). The `docker rm` documentation itself recommends it for deleting all the stopped ones ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)); that is fine on a machine dedicated to a single thing. On yours, prefer the filter by name: delete what you know is yours. The same goes for its relatives `docker system prune` and `docker volume prune`, which delete even more.

> [!NOTE]
> 🔧 **Engineering observation 2.3**
> Cleaning up is not a step you do "at the end, if there is time". In this lesson's scripts, the cleanup is scheduled **before** creating anything, with `trap ... EXIT`, so that it happens even if the script fails halfway. It is the same idea in your daily work: decide how you are going to delete something at the moment you create it, not afterwards.

## The error you will see

There are two, those of the scene at the beginning, and `fig02_06.sh` triggers both of them:

```bash
#!/usr/bin/env bash
# fig02_06.sh — Los dos errores de todos los días: nombre repetido y puerto ocupado.
# Ojo con el segundo: el contenedor que falla SÍ queda creado.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "${PREFIJO}prueba" "${PREFIJO}otro" "viejo-${PREFIJO}x" >/dev/null 2>&1 || true' EXIT

docker run -d --name "${PREFIJO}prueba" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null

echo "== 1. Otro contenedor con el MISMO nombre"
docker run -d --name "${PREFIJO}prueba" "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Otro contenedor en el MISMO puerto"
docker run -d --name "${PREFIJO}otro" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" | cut -c1-12
echo "código de salida: ${PIPESTATUS[0]}"

echo
echo "== 3. ¿Qué quedó?"
docker ps -a --filter name="^${PREFIJO}" --format 'table {{.Names}}\t{{.Status}}'

echo
echo "== 4. El filtro name y el ancla ^ (cuántos contenedores encuentra cada uno)"
docker create --name "viejo-${PREFIJO}x" "$IMAGEN" >/dev/null     # un nombre que lleva el prefijo en medio
echo "name=prueba           : $(docker ps -aq --filter name=prueba | wc -l)"
echo "name='^prueba'        : $(docker ps -aq --filter name='^prueba' | wc -l)"
echo "name=${PREFIJO}      : $(docker ps -aq --filter name="${PREFIJO}" | wc -l)"
echo "name='^${PREFIJO}'   : $(docker ps -aq --filter name="^${PREFIJO}" | wc -l)"
```

```text
$ ./fig02_06.sh
== 1. Otro contenedor con el MISMO nombre
docker: Error response from daemon: Conflict. The container name "/curso-docker-prueba" is already in use by container "61860733f6c9d97f75ca78c406e3c29d849500f981d1c8a506de77775199b7c6". You have to remove (or rename) that container to be able to reuse that name.

Run 'docker run --help' for more information
código de salida: 125

== 2. Otro contenedor en el MISMO puerto
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint curso-docker-otro (1de3263e30d85ae5c235769e50302b3a7bba937a5a2d7b88698413e7b62995d3): Bind for 127.0.0.1:9000 failed: port is already allocated

Run 'docker run --help' for more information
ab4acba42a64
código de salida: 125

== 3. ¿Qué quedó?
NAMES                 STATUS
curso-docker-otro     Created
curso-docker-prueba   Up 5 seconds (health: starting)

== 4. El filtro name y el ancla ^ (cuántos contenedores encuentra cada uno)
name=prueba           : 1
name='^prueba'        : 0
name=curso-docker-      : 3
name='^curso-docker-'   : 2
```

The long identifiers change on every run; the messages and the codes come out the same. `${PIPESTATUS[0]}` is a *bash* variable that stores the exit code of the **first** command of a pipeline; it is needed because `$?` would give that of the `cut`.

**The repeated name.** The message says it all: there is a conflict (*Conflict*), the name `/curso-docker-prueba` is already used by the container with such an identifier, and to reuse the name you have to delete or rename that container. Code **125**: Docker failed, not the service. The treacherous part is that the container that holds the name **may be stopped**: it does not appear in `docker ps`, only in `docker ps -a`. The fix, in order of preference: if the old one is no longer useful, `docker rm` (or `docker rm -f` if it is running); if you want to keep it, `docker rename <old> <new>`; or use another name for the new one.

**The port in use.** It reads from right to left: the cause is `port is already allocated`, the port is already taken; the attempt was `Bind for 127.0.0.1:9000`, binding to that address and that port; and the one making the attempt was the network configuration of the container `curso-docker-otro`. **125** again. To find out who holds the port, `docker ps` in the PORTS column; if it is not a container, `ss -ltnp` tells you which program on the machine is using it (the `p` asks for the process; to see other users' processes you need `sudo`). The fix: stop the one that has it, or publish yours on another host port (`-p 127.0.0.1:9002:9000`), which changes nothing inside the container.

**And the detail nobody tells you.** Notice the `1dad19130213` that appears after the port error: it is a container's identifier. `docker run -d` printed it because **the container was indeed created**; what failed was starting it. The third block confirms it: `curso-docker-otro` was left in the `Created` state. It does not run, it uses no memory, but it **holds on to its name**. If you fix the port and repeat the command with the same name, the next error you will see is the repeated-name one, and you will think Docker has gone mad. It has not: they are two chained errors. After a "port in use", delete the container that was left: `docker rm curso-docker-otro`. And do not try to rescue it with `docker start` when the port is freed: exercise 1 shows you what happens.

The repeated-name error with a **stopped** container and the port error with its ghost container are, together, the scene at the beginning. With `docker ps -a` and the filter from 2.11, they show up in ten seconds.

## The security habit of the lesson

**Ports published only on `127.0.0.1`, limits from the first container, and never `--privileged` or Docker's *socket* inside a container.**

You have already practiced the first two. Publishing on `127.0.0.1` keeps a test container from being within reach of anyone on your network, and the firewall does not cover you (2.8). The limits keep an error in one container from bringing down the other programs on your machine (2.9).

The third is stated here because in day-to-day tutorials you will find commands that violate it, and it is worth recognizing them before pasting them. Lesson 0 taught you that `--privileged` gives the container all capabilities and access to the host's devices ([Docker, "Running containers"](https://docs.docker.com/engine/containers/run/)): almost no wall is left. And it taught you that the daemon runs as `root` and that only trusted users should be able to control it ([Docker Engine security](https://docs.docker.com/engine/security/)), to the point that the `docker` group is the same as `root` ([Docker, Linux post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)). Mounting the *socket* inside a container —in tutorials it looks like `-v /var/run/docker.sock:/var/run/docker.sock`— gives that container exactly that power: it can ask the daemon to create another container with your machine's root folder mounted, as `root`. If a command you are about to copy carries either of the two, stop and ask yourself whether you really need it. In this course, never.

## Common mistakes

**Publishing ports without an address, "because that is how the example has it".** `-p 9000:9000` publishes on all interfaces, and `ufw` does not stop it. Always write `-p 127.0.0.1:9000:9000`, and when you really need another machine to reach the container, decide it on purpose.

**Running without limits "because it is only a test".** Tests are precisely where the program has bugs. `--memory`, `--cpus` and `--pids-limit` cost one line.

**Reading `Up` as "it is working".** `Up` says the process exists. You saw it in 2.4: the service answered `503` and Docker kept saying `Up`. To know whether it is serving, ask the service.

**Looking only at `docker ps`.** Without `-a` you do not see the stopped ones, which are the ones that hold on to names and disk. To review your machine, `docker ps -a`.

**Using `docker exec` to fix things.** What you change goes away with the container. Besides, in minimal images, like the test service's, there is not even a shell, and it is fine that there is not.

**`docker rm -f` as a reflex.** It kills with `SIGKILL`, without letting the program close what it has open. For anything with data, `docker stop` first.

**Deleting a container that failed without reading its log.** The log goes with it. First `docker logs --tail 50`, then `rm`.

**Cleaning up with `prune` on a shared machine.** It deletes everyone's. Filter by your prefix.

**Leaving the ghost container of the port in use.** It stays in `Created` with its name taken; delete it before retrying.

## Exercises

Exercises 1 and 4 are reasoning ones; 2 and 3 are done on your Mint. Write your predictions in the [logbook](bitacora.md) before looking at the solutions.

### Exercise 1 — Predict `docker ps -a`

You start from a machine with no `curso-docker-` containers. You run this, in order:

```bash
docker run -d --name curso-docker-a -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker run -d --name curso-docker-b -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker stop curso-docker-a
docker run --rm --name curso-docker-c curso-docker-prueba:1.0.0 healthcheck
```

The limits were removed from these commands so that they fit on the page and the sequence reads better; on your machine, add `--memory 64m --cpus 0.5 --pids-limit 50` to them, which do not change the answer.

1. Which of the four commands end with an error, and with which code?
2. Which containers appear in `docker ps -a --filter name=^curso-docker-`, and in which state?
3. If you now run `docker start curso-docker-b`, does it start? Why?
4. Which two commands leave the machine clean?

### Exercise 2 — Another port, another budget

Start the test service under these conditions: name `curso-docker-ejercicio`, you talk to it through port **9002** of your machine (only from your machine), and with **32 MiB** of memory, a quarter of a CPU and at most 20 processes. Then:

1. Check with `curl` that it answers `sano` on port 9002.
2. Predict what `memoria=` and `cpus(nano)=` will say with the `fig02_04.sh` template, and check it.
3. Predict what `docker stats --no-stream` will say in the memory limit column.
4. Put it in down mode and check that `docker ps` still says `Up`.
5. Leave everything clean.

### Exercise 3 — The log as evidence (project)

Imagine the `revisor` reported at 10:04 that the test service was down, and you want to know it without depending on the `revisor`. Start the test service, make three requests to it in healthy mode, switch it to down, make two more requests and return it to healthy. Then, using **only** `docker logs` and its options:

1. Show only the last three lines.
2. Show the log with the time of each line.
3. Show only the last minute.
4. Stop the container and demonstrate that the log is still there. Delete it and demonstrate that it is not any more.

### Exercise 4 — Explain it to whoever did it

Your teammate from the scene at the beginning tells you: "I have `ufw` active, so publishing with `-p 9000:9000` is perfectly fine." In five sentences at most, explain to him why it is not, and what he should have written. Use the words *interface*, *127.0.0.1* and *firewall*.

## Solutions

### Solution 1

1. The **second** one fails: port 9000 on `127.0.0.1` is already held by `curso-docker-a`; it ends with `port is already allocated` and code 125. The fourth is **not** a Docker error, but it does end with code **1**: the `healthcheck` subcommand finds nobody serving inside that container (`connection refused`), just like in block 5 of `fig02_07.sh`.
2. Two: `curso-docker-a` in `Exited (0)`, because you stopped it and the service shuts down properly with `SIGTERM`; and `curso-docker-b` in `Created`, the ghost container of the port in use. `curso-docker-c` does not appear: it had `--rm`, and `docker run` without `-d` does not return until it has deleted it.
3. **It starts, but without its port**, and this is the answer almost nobody predicts. It was measured while writing the lesson, with Docker 29.2.1: `docker start curso-docker-b` ended with code 0 and `docker ps` showed it `Up`, but the PORTS column came out **empty**, `docker port` printed nothing and `curl` to `127.0.0.1:9000` got no response. `docker inspect` showed the difference: in `.HostConfig.PortBindings` the `127.0.0.1:9000` was still requested, but in `.NetworkSettings.Ports`, what actually ended up connected, there was nothing. If you predicted "it starts and uses 9000, which is free now", your reasoning was the logical one; the ghost container simply does not behave that way. It is a behavior of the measured version (29.2.1) and I cannot say whether a later version fixes it; if on yours it starts with the port, good for you: the rule does not change, after a "port in use" you delete and create again. It is one more reason for the rule in "The error you will see": after a port in use, **delete** the container that was left in `Created` and create it again with `docker run`, instead of rescuing it with `docker start`.
4. One to delete and another to check: `docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f` and then `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l`, which must print `0`.

Points 1, 2 and 3 were checked by running this very sequence on the machine used for the runs, with `fig02_08.sh` (with the limits set, which do not change the answer):

```bash
#!/usr/bin/env bash
# fig02_08.sh — Ejercicio 1: la secuencia de cuatro comandos y qué queda en docker ps -a.
# Muestra el contenedor fantasma del puerto ocupado y qué pasa si lo rescatas con start.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
IMAGEN="${PREFIJO}prueba:1.0.0"
trap 'docker rm -f "${PREFIJO}a" "${PREFIJO}b" "${PREFIJO}c" >/dev/null 2>&1 || true' EXIT
LIMITES="--memory 64m --cpus 0.5 --pids-limit 50"

echo "== 1. docker run -d --name a -p 127.0.0.1:PUERTO:9000"
docker run -d --name "${PREFIJO}a" -p "127.0.0.1:${PUERTO}:9000" $LIMITES "$IMAGEN" >/dev/null
echo "código de salida: $?"
for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && break; sleep 0.5; done

echo
echo "== 2. docker run -d --name b -p 127.0.0.1:PUERTO:9000 (el mismo puerto)"
docker run -d --name "${PREFIJO}b" -p "127.0.0.1:${PUERTO}:9000" $LIMITES "$IMAGEN" | cut -c1-12
echo "código de salida: ${PIPESTATUS[0]}"

echo
echo "== 3. docker stop a"
docker stop "${PREFIJO}a" >/dev/null
echo "código de salida: $?"

echo
echo "== 4. docker run --rm --name c … healthcheck"
docker run --rm --name "${PREFIJO}c" $LIMITES "$IMAGEN" healthcheck
echo "código de salida: $?"

echo
echo "== 5. ¿Qué quedó?"
docker ps -a --filter name="^${PREFIJO}" --format 'table {{.Names}}\t{{.Status}}'

echo
echo "== 6. Con el puerto ya libre, docker start b"
docker start "${PREFIJO}b"
echo "código de salida: $?"
sleep 1
docker ps --filter name="${PREFIJO}b" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo "docker port: [$(docker port "${PREFIJO}b")]"
curl -s -o /dev/null --max-time 3 -w 'curl al puerto: código HTTP %{http_code}\n' "http://127.0.0.1:${PUERTO}/"
echo "pedido:   $(docker inspect --format '{{json .HostConfig.PortBindings}}' "${PREFIJO}b")"
echo "conectado: $(docker inspect --format '{{json .NetworkSettings.Ports}}' "${PREFIJO}b")"

echo
echo "== 7. Dejar el equipo limpio"
docker ps -aq --filter name="^${PREFIJO}" | xargs -r docker rm -f >/dev/null
docker ps -a --filter name="^${PREFIJO}" --format '{{.Names}}' | wc -l
```

Real run:

```text
$ ./fig02_08.sh
== 1. docker run -d --name a -p 127.0.0.1:PUERTO:9000
código de salida: 0

== 2. docker run -d --name b -p 127.0.0.1:PUERTO:9000 (el mismo puerto)
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint curso-docker-b (dc1814c6dd261d5f6ac915d4b103a3e985a4489040144a3ce76dc22e9f918cf0): Bind for 127.0.0.1:9000 failed: port is already allocated

Run 'docker run --help' for more information
e40dfd88f4b3
código de salida: 125

== 3. docker stop a
código de salida: 0

== 4. docker run --rm --name c … healthcheck
no sano: Get "http://127.0.0.1:9000/": dial tcp 127.0.0.1:9000: connect: connection refused
código de salida: 1

== 5. ¿Qué quedó?
NAMES            STATUS
curso-docker-b   Created
curso-docker-a   Exited (0) 4 seconds ago

== 6. Con el puerto ya libre, docker start b
curso-docker-b
código de salida: 0
NAMES            STATUS   PORTS
curso-docker-b   Up 1 second (health: starting)
docker port: []
curl al puerto: código HTTP 000
pedido:   {"9000/tcp":[{"HostIp":"127.0.0.1","HostPort":"9000"}]}
conectado: {}

== 7. Dejar el equipo limpio
0
```

The key is in block 6: `docker start` ended with code 0 and the container is `Up`, but the PORTS column is empty, `docker port` prints nothing, `curl` gets no response (`000`), `PortBindings` still asks for `127.0.0.1:9000` and `NetworkSettings.Ports` is empty (`{}`).

### Solution 2

```bash
docker run -d --name curso-docker-ejercicio -p 127.0.0.1:9002:9000 \
  --memory 32m --cpus 0.25 --pids-limit 20 curso-docker-prueba:1.0.0
curl -s http://127.0.0.1:9002/
docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}}' curso-docker-ejercicio
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' curso-docker-ejercicio
curl -s -X POST http://127.0.0.1:9002/modo/caido
docker ps --filter name=curso-docker-ejercicio --format '{{.Names}} {{.Status}}'
docker rm -f curso-docker-ejercicio
```

1. What matters is the `-p 127.0.0.1:9002:9000`: 9002 is **yours**, 9000 is still the service's inside the container. If you wrote `-p 127.0.0.1:9002:9002`, `curl` gets no response, because inside the container nobody listens on 9002.
2. `memoria=33554432`, which is 32 × 1024 × 1024, and `cpus(nano)=250000000`, a quarter of a billion: a quarter of a CPU. It is the same arithmetic as in 2.7.1 with other numbers.
3. The column will say `… / 32MiB`. What comes before the slash changes; the limit does not.
4. `Up`, with or without the health mark. It was measured while writing the lesson: right after switching it to down, `Up 7 seconds (health: starting)`; twelve seconds later, `Up 19 seconds (unhealthy)` (it is in `fig02_09.salida.txt`). It keeps saying `Up` even though it is marked unhealthy. Docker finds out about the outage thanks to the health check the image carries, not because it knows on its own what the service answers.
5. `docker rm -f` is fine here: it is a practice container with no data.

### Solution 3

```bash
docker run -d --name curso-docker-bitacora -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done
for i in 1 2 3; do curl -s http://127.0.0.1:9000/; done
curl -s -X POST http://127.0.0.1:9000/modo/caido
for i in 1 2; do curl -s http://127.0.0.1:9000/; done
curl -s -X POST http://127.0.0.1:9000/modo/sano
docker logs --tail 3 curso-docker-bitacora
docker logs --timestamps curso-docker-bitacora
docker logs --since 1m curso-docker-bitacora
docker stop curso-docker-bitacora
docker logs --tail 3 curso-docker-bitacora
docker rm curso-docker-bitacora
docker logs curso-docker-bitacora
```

1. If you pasted the block all at once, the last three lines are the two requests in down mode and the switch to healthy: `GET / en modo caido` twice and `modo cambiado a sano`. If you typed the commands one by one and took more than five seconds, `GET / en modo …` lines from the health check (2.5) appear between them: you did not ask for them, Docker did, and your `--tail 3` will be different.
2. With `--timestamps`, each line starts with the date and time at which Docker received it, in UTC (the final `Z` indicates it), with nanoseconds: in the verification run, `2026-10-21T15:30:46.762332653Z servicio-prueba: GET / en modo caido`. With that column you could answer exactly what time the outage began; remember to convert it to your time zone (in Mexico City, subtract 6 hours).
3. `--since 1m` shows everything, if you did the exercise in less than a minute: the startup, each request (including the wait loop's) and each mode change, plus one line for every health check that happened in the meantime, so the total grows with the time you took. It is the tool for "what happened since 10:00", changing `1m` to an hour.
4. After `docker stop`, the log is still there, and its last line is now `servicio-prueba: recibí terminated, apagando`: the shutdown was written down too. After `docker rm`, `docker logs` fails with `Error response from daemon: No such container: curso-docker-bitacora`: the container no longer exists, and its log went with it. That is the evidence you would lose if you deleted before reading.

The checks for solutions 2 and 3 are in `fig02_09.sh`, which uses the same names as the exercises with the prefix and port from the variables:

```bash
#!/usr/bin/env bash
# fig02_09.sh — Ejercicios 2 y 3: las comprobaciones de sus soluciones, con salida guardada.
set -uo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-9000}"
IMAGEN="${PREFIJO}prueba:1.0.0"
EJ="${PREFIJO}ejercicio"
BIT="${PREFIJO}bitacora"
trap 'docker rm -f "$EJ" "$BIT" >/dev/null 2>&1 || true' EXIT
esperar() { for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:${PUERTO}/" && return; sleep 0.5; done; }

echo "== Ejercicio 2: 32 MiB, un cuarto de CPU, 20 procesos"
docker run -d --name "$EJ" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 32m --cpus 0.25 --pids-limit 20 "$IMAGEN" >/dev/null
esperar
curl -s "http://127.0.0.1:${PUERTO}/"
docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}}' "$EJ"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' "$EJ"
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/caido"
docker ps --filter name="$EJ" --format '{{.Names}} {{.Status}}'
sleep 12
docker ps --filter name="$EJ" --format '{{.Names}} {{.Status}}'
docker rm -f "$EJ" >/dev/null

echo
echo "== Ejercicio 3: la bitácora como evidencia"
docker run -d --name "$BIT" -p "127.0.0.1:${PUERTO}:9000" \
  --memory 64m --cpus 0.5 --pids-limit 50 "$IMAGEN" >/dev/null
esperar
for i in 1 2 3; do curl -s "http://127.0.0.1:${PUERTO}/"; done
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/caido"
for i in 1 2; do curl -s "http://127.0.0.1:${PUERTO}/"; done
curl -s -X POST "http://127.0.0.1:${PUERTO}/modo/sano"
echo "-- 1. docker logs --tail 3"
docker logs --tail 3 "$BIT"
echo "-- 2. docker logs --timestamps"
docker logs --timestamps "$BIT"
echo "-- 3. docker logs --since 1m (renglones)"
docker logs --since 1m "$BIT" | wc -l
echo "-- 4. detenido: la bitácora sigue"
docker stop "$BIT" >/dev/null
docker logs --tail 3 "$BIT"
echo "-- 4. borrado: ya no"
docker rm "$BIT" >/dev/null
docker logs "$BIT"
echo "código de salida: $?"
```

Real run (the `--timestamps` instants and the time until `unhealthy` change on every run):

```text
$ ./fig02_09.sh
== Ejercicio 2: 32 MiB, un cuarto de CPU, 20 procesos
sano
memoria=33554432 cpus(nano)=250000000 pids=20
NAME                     MEM USAGE / LIMIT
curso-docker-ejercicio   1.594MiB / 32MiB
modo: caido
curso-docker-ejercicio Up 7 seconds (health: starting)
curso-docker-ejercicio Up 19 seconds (unhealthy)

== Ejercicio 3: la bitácora como evidencia
sano
sano
sano
modo: caido
caido
caido
modo: sano
-- 1. docker logs --tail 3
servicio-prueba: GET / en modo caido
servicio-prueba: GET / en modo caido
servicio-prueba: modo cambiado a sano
-- 2. docker logs --timestamps
2026-10-21T15:30:46.687217878Z servicio-prueba escuchando en :9000 en modo sano
2026-10-21T15:30:46.712613659Z servicio-prueba: GET / en modo sano
2026-10-21T15:30:46.727375778Z servicio-prueba: GET / en modo sano
2026-10-21T15:30:46.734891393Z servicio-prueba: GET / en modo sano
2026-10-21T15:30:46.744749971Z servicio-prueba: GET / en modo sano
2026-10-21T15:30:46.751853815Z servicio-prueba: modo cambiado a caido
2026-10-21T15:30:46.762332653Z servicio-prueba: GET / en modo caido
2026-10-21T15:30:46.771142826Z servicio-prueba: GET / en modo caido
2026-10-21T15:30:46.779167498Z servicio-prueba: modo cambiado a sano
-- 3. docker logs --since 1m (renglones)
9
-- 4. detenido: la bitácora sigue
servicio-prueba: GET / en modo caido
servicio-prueba: modo cambiado a sano
servicio-prueba: recibí terminated, apagando
-- 4. borrado: ya no
Error response from daemon: No such container: curso-docker-bitacora
código de salida: 1
```

### Solution 4

One possible answer: "Without an address, `-p 9000:9000` publishes the port on all of your machine's **interfaces**, including the wireless one, not only your own. And the `ufw` **firewall** does not stop it, because Docker writes its own network rules and the container's traffic passes before `ufw` checks it; Docker's documentation warns about it. So anyone on the café's network could talk to your container. What you should have written is `-p 127.0.0.1:9000:9000`: **127.0.0.1** is the interface that only leads to your own machine. The protection is in the `-p`, not in the firewall."

## How I know I got it

Run the scripts `fig02_01.sh` to `fig02_07.sh` from [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia) on your Mint, in order (`fig02_01.sh` builds the image the others use; its block 1 only shows the error if the image does not exist yet). `fig02_08.sh` to `fig02_10.sh` are those for exercises 1 to 3 and section 2.10.4 (exercise 4 has no script). Compare your outputs with those in this lesson. What is **not** compared, because it changes on every run: the container and image identifiers, the times (`Up 2 seconds`, `3.00 s`, `414 ms`, those of the build), the memory in use and the PIDS column that `docker stats` reports, your machine's total memory, the number of lines of `docker inspect` (it depends on the daemon's version), any extra `GET / en modo …` line in the log requested by the health check, and `arm64` versus `amd64`. The rest must come out the same. Check each point:

- [ ] `docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'` (block 5 of `fig02_01.sh`) prints `curso-docker-prueba:1.0.0 15.1MB` (or a very similar size on `amd64`).
- [ ] With the service running, `docker ps` shows `127.0.0.1:9000->9000/tcp` in the PORTS column, with no `0.0.0.0` or `[::]`.
- [ ] `curl -s http://127.0.0.1:9000/` answers `sano`; in down mode, `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/` answers `503`, and `docker ps` still says `Up`.
- [ ] `docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}' curso-docker-prueba` prints `memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532`.
- [ ] You triggered and read the two errors from `fig02_06.sh`, and you know why after the second one you have to delete a container in the `Created` state.
- [ ] `docker stop curso-docker-prueba` (this service handles `SIGTERM`) takes less than a second and leaves `Exited (0)`; the log ends in `recibí terminated, apagando`.
- [ ] You explain, without looking, the difference between stopped and deleted, and what is lost with each.
- [ ] When you finish, `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l` prints `0`, and the image `curso-docker-prueba:1.0.0` **is still** in `docker image ls`: you will need it.
- [ ] You noted in your logbook what changes between `-p 9000:9000` and `-p 127.0.0.1:9000:9000`, checked with `ss -ltn`.

## Summary

Answer without looking at the lesson:

1. What do `docker run`'s exit codes 125, 126 and 127 mean? Which one did you see when running an image that did not exist, and which when asking for `sh` in the test service?
2. What question does each option of the command `docker run -d --name … -p 127.0.0.1:9000:9000 --memory 64m --cpus 0.5 --pids-limit 50 …` answer?
3. What is the difference between `docker ps` and `docker ps -a`, and why does it matter for cleanup?
4. Why can `docker ps` say `Up` for a service that answers `503`?
5. What does `docker logs` see and what does it not see? What happens to the log with `stop` and with `rm`?
6. Why does `docker exec … sh` fail on the test service, and why is that good?
7. What does `memoria=0` mean in `docker inspect`?
8. What is the difference between publishing on `127.0.0.1` and giving no address? Why does `ufw` not protect you?
9. What does `docker stop` do, step by step, and how does it differ from `docker rm -f`?
10. How do you delete only your containers, and why do you not use `docker container prune` on a shared machine?

## Sources

All consulted on October 21, 2026.

- [docker container run](https://docs.docker.com/reference/cli/docker/container/run/): `-d`, `--name`, `-p`, `--rm`, `--pids-limit`, the default value of `--pull` and the warning about ports published on all interfaces and `ufw`.
- [Docker, "Running containers"](https://docs.docker.com/engine/containers/run/): the exit codes 125, 126 and 127, and what `--privileged` does.
- [docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/): `-a`, `-q`, the filter by name and by status, and the `--format` fields.
- [docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/): what the command delivers and the options `--follow`, `--tail`, `--since` and `--timestamps`.
- [docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/): `-i`, `-t`, that it only works while the main process is running and that the command must be an executable.
- [docker inspect](https://docs.docker.com/reference/cli/docker/inspect/): the low-level information and the templates with `--format`.
- [docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/): `--no-stream` and the memory and process columns.
- [docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM`, the 10-second deadline, `SIGKILL` and `--timeout`.
- [docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/): `--force` with `SIGKILL` and the recommendation of `prune`.
- [docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/): that it deletes all stopped containers, and its filters.
- [docker container update](https://docs.docker.com/reference/cli/docker/container/update/): that the memory, CPU and process limits can be changed on the fly.
- [Dockerfile reference, `HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck): when the first check runs and when the status goes from `starting` to `healthy` or `unhealthy`.
- [RFC 9110, §15.6.4](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.6.4): the 503 code, *Service Unavailable*.
- [docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/): the command's reference view.
- [Docker, "Port publishing and mapping"](https://docs.docker.com/engine/network/port-publishing/): publishing on all addresses by default, the insecurity warning and publishing on `127.0.0.1`.
- [Docker, "Packet filtering and firewalls"](https://docs.docker.com/engine/network/packet-filtering-firewalls/): why a container's traffic does not go through `ufw`'s rules.
- [Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/): that there are no limits by default, the risk of running out of memory, the minimum for `--memory` and the `--cpus` example.
- [Docker Engine security](https://docs.docker.com/engine/security/): the daemon as `root` and why only trusted users should control it.
- [Docker, Linux post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/): the `docker` group and its `root`-equivalent privileges.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions and dates in "About the runs" and the new `docker image ls` view since 29.0.
- [Colima](https://github.com/abiosoft/colima): the tool used to run the programs on macOS.

### Terms in this lesson

| | |
|---|---|
| **log** (*logs*) | what a container's main program writes to its standard output and error output; Docker stores it and `docker logs` shows it |
| **exit code** | the number a program ends with; 0 is "all good" |
| **build context** | the folder `docker build` uses to look for the `Dockerfile` and the files the recipe copies |
| **distroless** | a family of minimal base images that carry only what is essential for a program to run, with no shell |
| **container state** | created, running, stopped; deleted means it no longer exists |
| **tag** | what comes after the colon in an image's name: `1.0.0` in `curso-docker-prueba:1.0.0` |
| **network interface** | each network "door" of a machine; `127.0.0.1` is the one that only leads to the machine itself (*loopback*) |
| **publishing a port** | connecting a host port to a container port, with `-p` |
| **`SIGTERM`** | the signal used to ask a program to finish; it can be handled so as to shut down in an orderly way |
| **`SIGKILL`** | signal 9, which kills a program without giving it a chance to close anything |

---

**Next:** [Lesson 3 — Your first Dockerfile](03-primer-dockerfile.md)
