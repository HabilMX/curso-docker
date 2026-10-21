# Lesson 2 — Day-to-Day Containers

Twelve minutes left until the demo and the service won't start. You type the same command that worked yesterday, and Docker answers with a line in English ending in `port is already allocated`. You try again, and now the message is different: `The container name ... is already in use`. Someone next to you suggests restarting the computer. Before doing that, you run `docker ps -a` and the screen fills up: containers from last week, some stopped, others still running, one of them published on port 9000 **for anyone on the same coffee shop wireless network** where you worked on Tuesday. Nobody did it with bad intentions. Simply nobody learned to start, inspect, stop, and delete containers in an orderly way. You have ten minutes left, and this lesson is what you would have needed to know.

**Time:** 2 × 45 min

**What you build:** the course test service running in a container, with its port published only to your machine and with memory, CPU, and process limits; you query it in its three modes (healthy, slow, and down), read its log, inspect it, stop it, and delete it. At the end, no course container remains on your machine; the image `curso-docker-prueba:1.0.0`, however, stays, because subsequent lessons use it again.

**What you learn:** the day-to-day commands (`run`, `ps`, `logs`, `exec`, `inspect`, `stats`, `stop`, `start`, and `rm`); what publishing a port means and why in this course it is always published to `127.0.0.1`; how to set memory, CPU, and process limits and how to verify that they are applied; the lifecycle of a container (created, running, stopped, deleted); and how to clean up only your own without touching anyone else's.

**Where you are coming from.** From [Lesson 0](00-que-es-un-contenedor.md) you bring the map: a container is an isolated process, the image is the template and the container the living copy, and the `docker` client requests everything from the daemon over a *socket*. From [Lesson 1](01-instalacion.md) you bring Docker installed on your Mint and your user in the `docker` group, knowing that this is equivalent to `root`. You also need the course repository on your machine: from it you will use the folder `programas/servicio-prueba/`, which contains the test service already written and with its `Dockerfile` ready. You do not need to know Go or know how to read that `Dockerfile` yet.

**What this lesson does not do.** It does not write any `Dockerfile`: the test service's is used as-is, and learning to read it is the work of Lessons 3 to 5. It does not touch the `revisor` yet, the course's main project, because to run it you must first package it, and that begins in [Lesson 3](03-primer-dockerfile.md). Nor does it explain volumes or container networks; here each container lives on its own and you communicate with it from your machine.

**About the runs.** The outputs in this lesson were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which spins up a Linux virtual machine with Ubuntu 24.04.4 (the same base as Linux Mint 22), 64-bit ARM processor. The scripts were run **inside that virtual machine**, with Docker 29.2.1 (client and daemon, API 1.53). The Mac client was 29.8.2, the version with which the course was planned, and the most recent published that day was 29.9.2, from October 20, 2026, according to the [official release notes](https://docs.docker.com/engine/release-notes/29/). Three notes about how it was run. **First:** multiple lessons of the course were being written simultaneously on that machine, so, to avoid collisions, the runs used names with their own prefix (`curso-docker-l02-` instead of `curso-docker-`) and ports 18020 and 18021 instead of 9000 and 9001. In the outputs you read here, and in the `.salida.txt` files of the programs, the names and ports were reverted to the ones you will use, and table spacing was rearranged, because each column's width depends on the longest name; nothing else was touched. This is an exception to the course's rule of not editing output, and it was taken deliberately: running the scripts with the real names on that shared machine would have been dangerous, not just inconvenient, because each script's `trap` removes `curso-docker-prueba` upon exit, and that container could have belonged to another lesson running at that moment. On your Mint, nobody else is there, and the scripts run exactly as written. **Second:** the output of `fig02_01.sh` is from the first build, when the image did not yet exist; the Go base image was already downloaded, so the build in section 2.1 does not show downloads; on your first run you will first see the download of the two base images, the Go one and the minimal one, and it will take longer. **Third:** what changes on your Mint is the architecture (`amd64` instead of `arm64` if your processor is Intel or AMD), identifiers, timings, and the total memory reported by `docker stats`. The solutions to the exercises that cite output were also verified on that machine, with the same prefix. The programs are in [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia), each with its output saved next to it.

## By the end you will be able to

- Build the test service image with a single command and find it with `docker image ls`.
- Start a container in the background with a name, port published to `127.0.0.1`, and memory, CPU, and process limits, and explain each option of the command.
- List your containers with `docker ps`, filter them by name, and choose which columns to display.
- Read a container's log with `docker logs`, either in full or just its last few lines, and execute a program inside it with `docker exec`.
- Verify with `docker inspect` and `docker stats` that the limits were applied, and with `ss` which interfaces your machine is listening on.
- Read and resolve the two everyday errors: duplicate name and allocated port.
- Stop, restart, and delete containers, leaving your machine with no `curso-docker-` containers when finished.

## The why before the how

In Lesson 0 you saw containers from the inside, to understand what they are. Now comes the opposite: using them every day without thinking about namespaces or control groups. And here a problem appears that is not technical at all and does more harm than many kernel bugs: **disorder**.

A container is very easy to create. A `docker run` is all it takes. And, because it makes no noise, it is very easy to forget. After a week of testing you have stopped containers eating up disk space, running containers consuming memory and ports, and names you can no longer reuse. The worst part is not the disk: it is that one of them was left listening on all network interfaces of your machine, and you don't even know it. The opening scene was not caused by a weird bug; it was caused by three habits nobody corrected: publishing ports without specifying where, running without limits, and failing to clean up.

This lesson gives you the complete set of commands to manage a container from start to finish, and alongside each command, the habit that prevents disorder. You will do this with the course's **test service**, a tiny HTTP server that fails deliberately. It has three modes: in **healthy** mode it replies `200` immediately; in **slow** mode it takes three seconds and then replies `200`; in **down** mode it replies `503`, the HTTP code for "Service Unavailable". And the mode can be changed on the fly, without restarting it, using a `POST` request. Throughout the course, that service will serve as the target that the `revisor` monitors; here it provides safe practice, and everything you do with it you will repeat with the `revisor`: when you package it in Lesson 3, you will launch it with this exact same type of command, changing the name, the image, and using port 8080. And it illustrates an idea the course repeats: **a container stating "running" does not mean the service is healthy**.

The lesson proceeds in this order:

1. **Building the image** of the test service (2.1), making a mistake first.
2. **Starting** a container and understanding each part of the command (2.2).
3. **Looking at it**: `ps` (2.3), querying it (2.4), and reading its log with `logs` (2.5).
4. **Entering**, or trying to, with `exec` (2.6).
5. **Inspecting it** with `inspect` and `stats` (2.7).
6. **Ports**: `127.0.0.1` versus all interfaces (2.8), and **limits** (2.9).
7. **The lifecycle**: stopping, restarting, and deleting (2.10), and **leaving nothing behind** (2.11).

This is the command you will arrive at. By the end of the lesson, every single word will have a clear purpose:

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

## The concepts

### 2.1 Building the test service image

#### 2.1.1 First, the error

To run a container you need an image. Before building it, it is worth seeing what happens if you skip it, because it is an error you will encounter many times in your career: someone hands you a command, you paste it, and the image does not exist on your machine. `fig02_01.sh` does precisely that, and then builds the image:

```bash
#!/usr/bin/env bash
# fig02_01.sh — Correr una imagen que todavía no existe, y después construirla.
# Primero el error (la imagen no está en tu equipo ni en Docker Hub); luego el
# único comando que necesitas para construir el servicio de prueba.
set -uo pipefail
cd "$(dirname "$0")/.."          # la carpeta programas/, donde está servicio-prueba/
IMAGEN=curso-docker-prueba:1.0.0
# Si la imagen ya existía, el bloque 1 no falla y SÍ crea un contenedor: se borra al salir.
trap 'docker rm -f curso-docker-prueba >/dev/null 2>&1 || true' EXIT

echo "== 1. Correr la imagen antes de construirla"
docker run -d --name curso-docker-prueba "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Construirla: un solo comando"
docker build -t "$IMAGEN" servicio-prueba
echo "código de salida: $?"

echo
echo "== 3. La imagen ya está en tu equipo"
docker image ls "$IMAGEN"

echo
echo "== 4. Y el intento fallido no dejó contenedores"
docker ps -a --filter name=curso-docker-prueba --format '{{.Names}} {{.Status}}' | wc -l
```

The script uses `set -uo pipefail` and not `set -euo pipefail` like the ones in Lesson 0: we deliberately remove `-e` because the first command **must** fail and we want the script to continue. `cd "$(dirname "$0")/.."` moves to the `programas/` folder, which is where `servicio-prueba/` is located, regardless of where you run the script from. And `trap ... EXIT` schedules the container to be deleted upon exit: the first time there is nothing to delete, but if you run the script with the image already built, block 1 no longer fails, creates the container, and the `trap` cleans it up. This is the first part of the output:

```text
$ ./fig02_01.sh
== 1. Correr la imagen antes de construirla
Unable to find image 'curso-docker-prueba:1.0.0' locally
docker: Error response from daemon: pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'

Run 'docker run --help' for more information
código de salida: 125
```

It reads in two steps. The first line says the image is not found **on your machine** (*locally*). That is not an error yet: when `docker run` cannot find an image, it looks for it in a registry, which by default is Docker Hub. The documentation explains this with the `--pull` option, whose default value is `missing`: it downloads the image only if it is not already on your machine ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). The second line is the actual error: Docker Hub does not have a public repository called `curso-docker-prueba` and you provided no credentials, so it denied the pull. The message cannot know which of the two applies—that it does not exist or that it is private—which is why it mentions both.

The exit code **125** also has meaning. Docker's documentation reserves three codes: 125 means the error comes from the Docker daemon itself; 126 means the container command could not be invoked; and 127 means the container command was not found. Any other number is the exit code of the program inside ([Docker, "Running containers"](https://docs.docker.com/engine/containers/run/)). Here the container never even came to exist: Docker failed, not the service. You will see a 127 in section 2.6.

> [!NOTE]
> 🔧 **Engineering observation 2.1**
> The search order has a security implication. If you make a typo in the name of one of your images and by chance a public image exists with that name, Docker will pull and run it without asking you. The risk is greatest with names that include a user or organization, such as `someone/image`, because in those namespaces anyone can publish; a single-part name, like the one in this course, is searched among official Docker Hub images. That is why it is good practice for local image names to be unmistakable; the prefix `curso-docker-` in this course serves that purpose, in addition to allowing you to clean up your own containers with a filter (2.11).

#### 2.1.2 A single command to build it

The test service is delivered with its recipe already written: the file `programas/servicio-prueba/Dockerfile`. Building it takes a single command:

```bash
docker build -t curso-docker-prueba:1.0.0 servicio-prueba
```

It has two parts. `-t curso-docker-prueba:1.0.0` assigns **name and tag** to the resulting image: the name is `curso-docker-prueba` and the tag, what comes after the colon, is `1.0.0`. And `servicio-prueba`, at the end, is the directory Docker uses as the **context**: it looks for the `Dockerfile` there and pulls the files that the recipe asks to copy from there. Lesson 4 is devoted entirely to context; here it is enough to know it is a folder.

The build output is long; this is the central part (the full file is in `fig02_01.salida.txt`):

```text
== 2. Construirla: un solo comando
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 836B done
#1 DONE 0.0s
[…]
#6 [1/4] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#6 resolve docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c 0.0s done
#6 DONE 0.0s
[…]
#12 [compilacion 4/4] RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/servicio-prueba .
#12 DONE 32.9s

#13 [stage-1 2/2] COPY --from=compilacion /out/servicio-prueba /servicio-prueba
#13 DONE 0.1s

#14 exporting to image
[…]
#14 naming to docker.io/library/curso-docker-prueba:1.0.0 done
#14 unpacking to docker.io/library/curso-docker-prueba:1.0.0 0.1s done
#14 DONE 0.5s
código de salida: 0
```

You don't need to understand every line today, but three things matter. The build proceeds in **numbered steps** (`#1`, `#2`…) and each reports how long it took: the longest, 32.9 seconds, compiles the Go program inside an image containing the compiler. At the end, `naming to docker.io/library/curso-docker-prueba:1.0.0` appears: the short name you supplied is, in full, an image name in Docker Hub's official library (`library`), even if it is never uploaded anywhere; that is how Docker names anything without an explicit registry. And the exit code is **0**: everything succeeded. Lessons 3, 4, and 5 teach you to read this file line by line.

#### 2.1.3 Finding the image

```text
== 3. La imagen ya está en tu equipo
WARNING: This output is designed for human readability. For machine-readable output, please use --format.
IMAGE                       ID             DISK USAGE   CONTENT SIZE   EXTRA
curso-docker-prueba:1.0.0   06306fe8744c   15.1MB       3.37MB

== 4. Y el intento fallido no dejó contenedores
0
```

If you are coming from older tutorials, this table might look different. Since version 29.0, `docker image ls` defaults to a new view, "like `--tree`, but collapsed", hiding untagged images unless you specify `--all` ([Docker Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/)). The command's reference page still displays the old columns (`REPOSITORY`, `TAG`, `IMAGE ID`, `CREATED`, `SIZE`) ([docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/)), so do not be surprised if your output and a tutorial don't match. Docker itself tells you in the `WARNING` on the first line: this view is meant for human reading; if you are going to process the output with a script, use `--format`, which is what the rest of the lesson does.

The column this course uses when discussing image size is **DISK USAGE**: 15.1 MB is what the image takes up on your disk. The **CONTENT SIZE** column is smaller; all evidence suggests it measures the compressed content of the image as it travels across the network, but reference documentation does not yet describe it, so in this course we do not use it for anything. With a custom format, you can get the size directly:

```bash
docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

In the course runs' output, that command printed `curso-docker-prueba:1.0.0 15.1MB`.

Block 4 confirms something important for cleanup: the failed `docker run` from section 2.1.1 **left no container behind**. Since there was no image, there was nothing to create it from. In section 2.8 you will see an error that does leave one behind.

### 2.2 Starting a container

#### 2.2.1 The command, option by option

With the image ready, here is this lesson's command:

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Read it from left to right. Each option answers a question that, if you don't answer, Docker answers for you, and rarely in your favor:

| Option | Question it answers | What happens if you omit it |
|---|---|---|
| `-d` | do you give me back my terminal? | the container stays attached to your terminal; if you close it or press Ctrl+C, it receives the signal |
| `--name curso-docker-prueba` | what is its name? | Docker invents a random name, like `busy_goldwasser`, that you won't remember |
| `-p 127.0.0.1:9000:9000` | who can talk to it, and on what port? | no other machine, and you only via the container's internal address, not via `127.0.0.1`; and if you put `-p 9000:9000` without an address, **anyone on your network** |
| `--memory 64m` | how much memory can it use? | all of your machine's |
| `--cpus 0.5` | how much CPU? | all of it |
| `--pids-limit 50` | how many processes can it create? | as many as it wants |
| `curso-docker-prueba:1.0.0` | from which image? | (required) |

`-d` is short for `--detach`: according to documentation, it runs the container in the background and prints its container ID ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Without `-d`, the service's output appears in your terminal and the terminal remains occupied until the container stops. That is sometimes handy for a quick check; for a server, almost never.

`--name` gives it a name. The documentation states that if you omit it, the daemon generates a random one ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). A custom name serves two purposes: writing `docker logs curso-docker-prueba` instead of copying a 64-character identifier, and reminding you whose container it is. But it has a consequence: **on a given daemon, no two containers can share the same name**, even if one of them is stopped. That is the first error from the opening scene, and you will trigger it in section 2.8.

`-p` is short for `--publish`, and has three parts separated by colons: `address:host-port:container-port`. `127.0.0.1:9000:9000` means "on my machine, only on address `127.0.0.1` and port 9000, accept connections and forward them to port 9000 of the container." The two numbers do not have to be identical: with `127.0.0.1:18000:9000`, you would talk to it on 18000 and the service would still listen on its 9000. Recall from Lesson 0 that each container has its own network. Without `-p`, its port 9000 can only be reached from Docker's internal network: from other containers on that network and from your own host, provided you use the container's internal IP address; the documentation puts it like this: container ports on bridge networks are accessible from the host even without publishing them ([Docker, "Port publishing and mapping"](https://docs.docker.com/engine/network/port-publishing/)). What cannot be reached without `-p` is the port from your host's `127.0.0.1` or from any other machine. Section 2.8 is dedicated to the address, which is the most critical part.

`--memory`, `--cpus`, and `--pids-limit` are the budget that Lesson 0 taught you to inspect in `/sys/fs/cgroup`. Section 2.9 explains why these specific numbers were chosen.

#### 2.2.2 Starting it and waiting for it to respond

`fig02_02.sh` starts the container and does what you would do on a normal workday. This is the complete script; its output is split across sections 2.2 to 2.5:

```bash
#!/usr/bin/env bash
# fig02_02.sh — El servicio de prueba corriendo: arrancar, listar, consultar y leer su bitácora.
# Puerto publicado solo en 127.0.0.1 y con límites de memoria, CPU y procesos.
set -euo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== 1. Arrancar en segundo plano"
docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
# Esperar a que conteste (máximo 10 s), en vez de dormir un número fijo.
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo
echo "== 2. Lo que está corriendo"
docker ps --filter name="$NOMBRE" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== 3. Consultarlo en sus tres modos"
curl -s http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/caido
curl -s -w 'código HTTP: %{http_code}\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/lento
curl -s -w 'código HTTP: %{http_code} en %{time_total} s\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/sano
curl -s http://127.0.0.1:9000/modo

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
c516467655b6
```

The only thing `docker run -d` prints is the container **identifier**, a 64-character hexadecimal number; the script trims it to the first 12 characters with `cut -c1-12`, which is how Docker displays it almost everywhere. It changes on every run. Seeing it appear means the container was created and instructed to start; it does **not** mean the service inside is already serving requests.

That is why the script's next line is a loop: it attempts a request with `curl` every half second, up to twenty times, and exits as soon as one succeeds. `curl -f` makes `curl` fail if the server returns an error, `-s` silences it, and `-o /dev/null` discards the body. It is better than a fixed `sleep 3` for two reasons: on a fast machine you don't wait unnecessarily, and on a slow machine you don't proceed prematurely. You will see this pattern in all course scripts that communicate with the service; where no communication occurs, waiting is not necessary.

The `trap ... EXIT` at the top is the same habit from Lesson 0: no matter what happens, the script removes its container on exit. You will see it constantly in this lesson's scripts, because section 2.11 turns it into a strict rule.

### 2.3 Seeing what is running: `docker ps`

```text
== 2. Lo que está corriendo
NAMES                 IMAGE                       STATUS                            PORTS
curso-docker-prueba   curso-docker-prueba:1.0.0   Up 2 seconds (health: starting)   127.0.0.1:9000->9000/tcp
```

`docker ps` lists containers. By default it only shows **those that are running**; with `-a` (`--all`) it also displays stopped ones ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). That distinction is what hides leftovers: a stopped container does not appear in `docker ps`, but it still exists, consumes disk space, and reserves its name.

The script uses two options worth learning right away. `--filter name=curso-docker-prueba` keeps only containers whose name contains that string; the documentation states that the `name` filter matches "all or part" of the name ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). And `--format 'table ...'` selects the columns: `{{.Names}}`, `{{.Image}}`, `{{.Status}}`, and `{{.Ports}}` are fields, and the word `table` at the beginning requests headers and aligned columns. What is inside double curly braces is a Go language template; you don't need to know Go to use it, only the field names, which the command page lists. Other filters are useful too; the status filter, for example, accepts `created`, `restarting`, `running`, `removing`, `paused`, `exited`, and `dead` ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)).

The columns, one by one:

- **NAMES** is the name you gave it.
- **IMAGE**, the image it was created from.
- **STATUS** says `Up 2 seconds`: it has been running for two seconds. And it includes something else, `(health: starting)`, which deserves its own paragraph.
- **PORTS** says `127.0.0.1:9000->9000/tcp`: port 9000 on your machine, bound only to `127.0.0.1`, forwards to port 9000 on the container over TCP.

The `(health: starting)` appears because the test service's `Dockerfile` includes a `HEALTHCHECK` instruction: it instructs Docker to run the subcommand `servicio-prueba healthcheck` inside the container every five seconds, asking the service itself if it is responding properly. Until the first check finishes, the status is `starting`; afterward it will be `healthy` or `unhealthy`. Today you won't use it for anything other than reading it; how to write a health check and what Docker does with it is the topic of Lesson 7. But notice from now on that **`Up` and health are two different things**: `Up` says the process exists; health says whether it is serving. The next section demonstrates this.

### 2.4 Talking to the service

```text
== 3. Consultarlo en sus tres modos
sano
modo: caido
caido
código HTTP: 503
modo: lento
lento
código HTTP: 200 en 3.081298 s
modo: sano
modo: sano
```

Read each pair of lines as request and response:

1. `GET /` in healthy mode replies `sano`.
2. `POST /modo/caido` changes the mode and confirms `modo: caido`. From that moment on, `GET /` replies with the text `caido` with HTTP status **503**. The `-w` option of `curl` prints request metrics after the response; here, the HTTP code.
3. `POST /modo/lento` and the following `GET /` takes **3.08 seconds** to reply `lento` with a 200. The three seconds are the delay of slow mode; the rest is round-trip time. That number varies slightly on each run; in another run of the course it came out to 3.003 seconds.
4. `POST /modo/sano` returns it to normal, and `GET /modo` confirms it.

Now the question that matters. While the service was returning `503`, what did `docker ps` say? It said `Up`. For Docker, the container was perfectly fine: the process existed and had not terminated. For anyone using it, it was down. **Docker does not know what your service returns**, unless you teach it through a health check. This is the principle the course emphasizes in every lesson: a running container is not a healthy service. The `revisor`, the project you will package starting in Lesson 3, exists precisely to ask that question from the outside.

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

Everything the container's main program writes to its **standard output** and **standard error**—what in your terminal you would see with `printf` or `echo`—is captured by Docker, and `docker logs` delivers it to you. The documentation describes it like this: the command returns logs present at the time of execution, and with `--follow` it continues streaming new output from the container's `STDOUT` and `STDERR` ([docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/)).

Notice that the log tells the complete story of the previous section, in chronological order: startup, the first two requests (the wait loop's and your own), each mode switch, and each request alongside its mode. Requests to `/modo` leave no trace because the service does not record them; a program only leaves in the log what its author chose to write. And a heads-up: the image's health check (2.3) also issues a `GET /` every five seconds, and each one logs a line. This run lasted less than five seconds, so none appears; in a container that has been running for a while, you will see `GET / en modo …` lines you did not trigger. Docker did.

The options you will use daily, all from the [command page](https://docs.docker.com/reference/cli/docker/container/logs/):

| Option | What it does |
|---|---|
| `--tail N` (or `-n N`) | only the last N lines; by default, all |
| `--follow` (or `-f`) | keeps listening and streams new output as it arrives; exit with Ctrl+C |
| `--since 10m` | only output from the last ten minutes; also accepts a date and time |
| `--timestamps` (or `-t`) | prepends the time Docker received each line |

`--tail` matters more than it seems. A service running for weeks can accumulate millions of lines, and an unconstrained `docker logs` will flood your terminal. The best practice is `docker logs --tail 50 <name>` first, and `-f` if you want to keep watching.

Two notes that will save you headaches. **The log survives `docker stop`, but not `docker rm`:** it lives with the container, so you can read it after stopping the container (you will see this in 2.10) and it disappears when you delete it. If a container died under strange circumstances, **read its log before deleting it**. And **`docker logs` only sees what the main process writes to its two standard streams**: if the program writes its log to a file inside the container, `docker logs` cannot see it. That is why programs designed for containers, like the test service and the `revisor`, write everything to standard output.

### 2.6 Entering the container: `docker exec`

#### 2.6.1 The image has no shell

In tutorials you will often see this command: `docker exec -it <name> sh`, "to get inside the container." `docker exec` runs a program **inside** an already running container; `-i` keeps standard input open and `-t` allocates a pseudo-TTY, enabling you to type commands ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)). Try it with the test service, which is what `fig02_03.sh` does (without `-it`, since a script has nobody typing):

```bash
#!/usr/bin/env bash
# fig02_03.sh — exec: ejecutar un programa dentro de un contenedor que ya corre.
# La imagen del servicio de prueba no trae shell: se ve el error y lo que sí funciona.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo "== 1. Pedir un shell"
docker exec "$NOMBRE" sh
echo "código de salida: $?"

echo
echo "== 2. Ejecutar un programa que la imagen SÍ trae"
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 3. Lo mismo, con el servicio en modo caído"
curl -s -X POST http://127.0.0.1:9000/modo/caido >/dev/null
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
Error response from daemon: container 78614f9ea0da425237a13924f63235bf6a1e45629efd4000d3764b5c54e23dcb is not running
código de salida: 1
```

The first block is the error. Read it from right to left, which is how almost all Docker errors are read: the root cause is at the end. `exec: "sh": executable file not found in $PATH` says that no program named `sh` exists in the directories where executables are sought. What precedes it, `OCI runtime exec failed`, tells you who discovered it: `runc`, the tool that spawns container processes (you met it in Lesson 0). And the code **127**, as you saw in 2.1.1, is reserved by Docker for "command not found."

This is not a defect of the container: it is a design choice. The test service image was built on a minimal base, known as *distroless*, which **only carries the program and the bare essentials needed to run it**: it has no `sh`, no `ls`, no `cat`, and no package manager. That carries a price, which you just paid: you cannot "hop in" to poke around. And it offers a gain, which Lesson 5 leverages for the `revisor`: if an attacker managed to execute something inside that container, they would find no built-in tools to continue their attack. An image without a shell is an image with less attack surface.

#### 2.6.2 What you can do

The second block shows that `exec` works flawlessly with a program that the image **does** include: `/servicio-prueba` itself, with its `healthcheck` subcommand. The program queries the running service next to it, prints `sano`, and exits with 0. The third block repeats the query with the service in down mode: `no sano: GET / respondió 503`, and exits with 1. That subcommand is identical to what the `HEALTHCHECK` instruction runs every five seconds; you just ran it manually. Notice here the code is not 127 but 1: the program was found and did run; it simply answered "no".

Two rules of `exec` derived from its documentation ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)):

- **It only works while the container's main process is running.** That is the fourth block: with the container stopped, the daemon replies `container ... is not running`. To see what happened to a stopped container you do not use `exec`, you use `logs` and `inspect`.
- **The command must be an executable**, not a shell command line. `docker exec <name> "echo hola && ls"` does not work; if the image includes a shell, you write `docker exec <name> sh -c 'echo hola && ls'`.

When an image does include a shell, such as `alpine:3.24.2` from Lesson 0, the familiar command works and drops you into a shell inside:

```bash
docker run -d --name curso-docker-dormilon --memory 16m --cpus 0.25 --pids-limit 20 \
  alpine:3.24.2 sleep 300
docker exec -it curso-docker-dormilon sh
```

Use it to **look**, never to **fix**. You learned this in Lesson 0: whatever you modify in there lives in the container layer and is discarded with it. And delete the container when finished: `docker rm -f curso-docker-dormilon`.

### 2.7 What Docker knows about a container: `inspect` and `stats`

#### 2.7.1 `docker inspect` with a template

`docker inspect` returns "low-level information" about a Docker object ([docker inspect](https://docs.docker.com/reference/cli/docker/inspect/)): everything the daemon knows about it, formatted as JSON. It is extensive. `fig02_04.sh` uses templates to extract only what matters, and compares the container with limits against an identical one without limits:

```bash
#!/usr/bin/env bash
# fig02_04.sh — inspect y stats: lo que Docker sabe de un contenedor, con y sin límites.
set -euo pipefail
CON=curso-docker-prueba
SIN=curso-docker-sin-limites
trap 'docker rm -f "$CON" "$SIN" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CON" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name "$SIN" curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

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
NAME                       MEM USAGE / LIMIT     PIDS
curso-docker-prueba        1.59MiB / 64MiB       8
curso-docker-sin-limites   1.496MiB / 15.59GiB   7

== 4. Cuántos renglones trae inspect completo
224
```

The entire first block is stable: these numbers come out identical on your Mint. Read them:

- `memoria=67108864` is 64 × 1024 × 1024 bytes: the 64 MiB you requested, the same number Lesson 0 read in `memory.max`.
- `cpus(nano)=500000000`: Docker stores CPU in billionths of a CPU; 500 million is half a CPU.
- `pids=50`, the process cap.
- `usuario=65532:65532`: the service **does not run as `root`**. The image decided this, via a `USER` instruction that Lesson 3 teaches you to write. Compare it with the `sleep` from Lesson 0, which ran as user 0.

And the line for the container without limits says `memoria=0`, `cpus(nano)=0`, and `pids=<no value>`. In this field, **zero does not mean "no memory": it means "no limit"**. It is Docker's internal representation for "you requested no constraint." `<no value>` is what the template prints when the field does not even exist. When inspecting someone else's container, a zero here is an alarm bell, not reassurance.

The name appears with a leading slash, `/curso-docker-prueba`. That is not your mistake: that is how Docker stores names internally, and why the duplicate name error in section 2.8 also includes it.

The second block shows three other fields. `.State.Status` is the status (`running`). `.Config.Entrypoint` is the program the image launches as its main process. And `{{json .HostConfig.PortBindings}}` uses the template `json` function to output a composite field as-is: port 9000 of the container is bound to address `127.0.0.1`, port 9000, on your host machine.

The fourth block explains why templates are used: the full `inspect` for this container, which is a simple one, spans **224 lines**. Reading it entirely is useful once, to see what is there. To query something specific, use a template.

#### 2.7.2 `docker stats`: what it is consuming right now

`inspect` reports what the limits are; `docker stats` reports **how much is currently being consumed**. By default it is a screen that updates continuously, like `top`; with `--no-stream` it takes a single reading and exits, which is what a script needs ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)). The **MEM USAGE / LIMIT** column displays the memory the container consumes against what it is permitted, and **PIDS** reports how many processes and threads it has spawned ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)).

The test service uses between 1 and 2 MiB and has a handful of threads (8 in this run, 6 in another; the count varies). What matters is the limit column. With limits it shows `64MiB`. Without limits it shows `15.59GiB`, which is **the entire memory of the machine** on which it was run (Colima's virtual machine). On your Mint, that figure will be your computer's total memory. It is the Lesson 0 scenario viewed through Docker: an unconstrained container has the entire host as its limit.

### 2.8 Ports: `127.0.0.1` versus all interfaces

#### 2.8.1 What the address means

Your computer has multiple **network interfaces**, which act like doors through which incoming connections arrive: the Wi-Fi interface, perhaps Ethernet, and a special one called ***loopback***, with address `127.0.0.1`. The loopback interface leads nowhere outside your machine: traffic arriving through it can only originate from your own computer.

When you publish a port without an address, using `-p 9000:9000`, Docker publishes it **on all interfaces**. The documentation states it plainly: if you do not specify an address, the daemon publishes ports on all host addresses, `0.0.0.0` and `[::]`, and warns in a callout that "publishing container ports is insecure by default" because the port becomes reachable not just from the host but "from the outside world" ([Docker, "Port publishing and mapping"](https://docs.docker.com/engine/network/port-publishing/)). With `127.0.0.1` prepended, "only the host can access" the published port (same source). That holds true starting with Docker 28: the same page cautions that in versions prior to 28.0.0, machines on the same network segment could reach ports published on `127.0.0.1`. That is one more reason to install Docker from the official repository, as done in Lesson 1, rather than relying on an outdated version.

`fig02_05.sh` starts two copies of the service, one each way, and queries Docker and the operating system to see where they ended up:

```bash
#!/usr/bin/env bash
# fig02_05.sh — Publicar en 127.0.0.1 contra publicar en todas las interfaces.
# Se corre en el anfitrión (tu Mint): ss lista los puertos en los que escucha el equipo.
set -euo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-abierto >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name curso-docker-abierto -p 9001:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for p in 9000 9001; do
  for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:$p/" && break; sleep 0.5; done
done

echo "== 1. Lo que dice docker port"
echo "-- curso-docker-prueba:"; docker port curso-docker-prueba
echo "-- curso-docker-abierto:"; docker port curso-docker-abierto

echo
echo "== 2. Lo que dice el sistema operativo: dónde escucha el equipo"
ss -ltn | grep -E ':900[01] ' | awk '{print $4}' | sort
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

`docker port` shows, for a given container, which container port forwards to which host address and port. `ss -ltn` is standard Linux tooling that lists ports where the host is listening for TCP connections (`-l` listening, `-t` TCP, `-n` numeric instead of service names); `grep` filters for lines corresponding to ports 9000 and 9001, and `awk` isolates the address column.

Both sources tell the same story. The properly published container listens **only** on `127.0.0.1:9000`. The other listens on `0.0.0.0:9001`, which in networking terms means "on all IPv4 addresses of this machine," and on `[::]:9001`, the equivalent for IPv6. If your Mint is connected to a coffee shop, university, or office Wi-Fi network, anyone on that network can enter your computer's IP address and port 9001 and interact with your container. The test service is harmless; a test database with a default password is not.

#### 2.8.2 The firewall does not save you

You might think that is why you have a firewall. On Mint, the desktop firewall is `ufw`. Here is the catch: **ports published by Docker bypass `ufw` rules**. The reference for `docker run` warns of this: ports published on all interfaces remain accessible from the outside even if `ufw` is configured to block them, because Docker manages its own packet filtering rules ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Docker's firewall documentation explains the mechanism: container traffic "is routed before going through the `ufw` configuration" and packets are routed "before firewall rules can be applied" ([Docker, "Packet filtering and firewalls"](https://docs.docker.com/engine/network/packet-filtering-firewalls/)).

Do not test this on your network without permission. Knowing it and drawing the conclusion is enough: **the protection lies in `-p`, not in the firewall**. That is why in this course all ports are published with `127.0.0.1:` in front, and the only one that lacks it is `9001` in this script, which exists solely for you to see it and is deleted upon completion.

> [!NOTE]
> 🔧 **Engineering observation 2.2**
> An overly published port gives no warning. There is no message saying "this container was left open to your local network." The only way to know is to check: `docker ps` under the PORTS column (look for `0.0.0.0` or `[::]`) or `ss -ltn` on the host. Make it a habit every time you connect to a network that isn't your own.

### 2.9 Limits: memory, CPU, and processes

Lesson 0 showed you what limits do on the inside: Docker writes a number into a kernel file and the kernel enforces it. Here the practical question is: **what numbers to set**.

Docker's documentation is clear about what happens if you specify none: a container "has no resource constraints" and uses as much as the kernel scheduler allows; and when the host runs low on memory, the kernel starts killing processes—any process, including Docker itself—which "can bring down the entire system if the wrong process is killed" ([Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/)). The three limits in this lesson's command:

**`--memory 64m`.** The test service consumes between 1 and 2 MiB (you measured it in 2.7.2). 64 MiB grants it a margin of over thirty times. The general rule is this: **measure first, and set a comfortable limit well above what was measured**, never below. If the program exceeds the limit, the kernel terminates it inside its own cgroup, as you saw in Lesson 0 (exit code 137 and `OOMKilled=true`), and no other process on your machine is affected. The documentation enforces a minimum of 6 MB for this option ([Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/)).

**`--cpus 0.5`.** Half a CPU. A service that only answers small requests needs no more, and if an infinite loop occurs due to a bug, it eats half a CPU rather than the whole machine. The documentation illustrates this with its own example: on a two-CPU host, `--cpus="1.5"` guarantees the container at most one and a half CPUs ([Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/)). Unlike memory, exceeding CPU limits kills nobody: the kernel simply allocates less compute time, making the program run slower.

**`--pids-limit 50`.** Sets the container's process limit; setting `-1` removes it ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). This limit protects against something very specific: a program that, whether due to a bug or an attack (fork bomb), spawns processes endlessly. Without a cap, it can exhaust the host's process table and leave you unable even to open a terminal. The service had 8 (2.7.2); 50 is plenty.

Notice that all three limits are applied **from the very first container**, not "when the service reaches production." Lesson 0 made this point with the database scenario: limits are not for normal days; they are for bad days, and bad days give no advance warning.

### 2.10 The lifecycle: stopping, restarting, and deleting

#### 2.10.1 States

A container transitions through states, and each command moves it from one to another:

| State | How it gets there | What is seen in `docker ps -a` |
|---|---|---|
| created (`created`) | `docker create`, or a `docker run` that failed to start | `Created` |
| running (`running`) | `docker run` or `docker start` | `Up …` |
| stopped (`exited`) | `docker stop`, or the main program exited on its own | `Exited (code) …` |
| deleted | `docker rm` | no longer appears |

The most important takeaway from the table is the distinction between **stopped** and **deleted**. A stopped container does not run, but it exists: it preserves its writable layer, its logs, its configuration, and its name. It can be started again. A deleted container no longer exists, and with it go its layer and its log.

`fig02_07.sh` walks through the entire cycle and ends with the cleanup check:

```bash
#!/usr/bin/env bash
# fig02_07.sh — El ciclo de vida completo y la limpieza: stop, start, rm y --rm.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" curso-docker-efimero >/dev/null 2>&1 || true' EXIT
ms() { date +%s%3N; }

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

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
docker run --rm --name curso-docker-efimero curso-docker-prueba:1.0.0 healthcheck
echo "código de salida: $?"
docker ps -a --filter name=curso-docker-efimero --format '{{.Names}}' | wc -l

echo
echo "== 6. La revisión final: ningún contenedor del curso"
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

```text
$ ./fig02_07.sh
== 1. Borrar un contenedor que está corriendo, sin -f
Error response from daemon: cannot remove container "curso-docker-prueba": container is running: stop the container before removing or force remove
código de salida: 1

== 2. Detenerlo, midiendo cuánto tarda
docker stop tardó 242 ms
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

Timings vary with each run; everything else comes out identical.

#### 2.10.2 `docker rm` does not delete what is running

The first block is a safeguard: Docker does not let you delete a running container. The error message gives you both exits: stop it first (*stop the container before removing*) or force removal (*force remove*). Forcing is `docker rm -f`, and documentation explains what it does: it sends `SIGKILL` to the main process and then removes the container ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)). `SIGKILL` is signal 9, which Lesson 0 taught you to recognize in exit code 137: it cannot be caught, so the program gets no chance to close anything cleanly. For a disposable test container, that is fine, and the `trap`s in these scripts make use of it. For a service with state or data, use `stop` first.

#### 2.10.3 `docker stop`: the signal and the timeout

`docker stop` is the polite way. Documentation states that it sends the main process the `SIGTERM` signal (unless the image or container configures another), waits for a timeout—by default, **10 seconds** on Linux—and, if the container remains alive, kills it with `SIGKILL`. The timeout can be customized with `--timeout` ([docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/)).

The second block shows that the test service shuts down cleanly. `docker stop` took **242 ms**, far below the 10-second timeout (in another run of the course it took 120 ms, and in another, 199). The status is `Exited (0)`: the program exited on its own with exit code 0, which on Linux means "all good." And the log, which remains intact after stopping, explains why: `recibí terminated, apagando`. The service is written to handle `SIGTERM` (*terminated* is how Go identifies that signal): it receives it, stops accepting requests, and exits cleanly. If the program ignored the signal, you would see `docker stop` take 10 seconds and the status would be `Exited (137)`. Why a program sometimes fails to receive the signal, even when coded to handle it, is a real issue known as the PID 1 problem, which Lesson 7 tackles.

#### 2.10.4 `docker start`: stopped is not deleted

The third block restarts the exact same container with `docker start`. There is no need to repeat the options: the name, port, and limits remain saved in the container. `docker start` is for resuming something you stopped; to alter an option (a different port, different limits), you must delete the container and create a new one with `docker run`. The fourth block cleans up in proper order: `stop` and then `rm`, which prints the name of what was removed.

#### 2.10.5 `--rm`: containers that clean up after themselves

For containers that execute a one-off task and exit, `--rm` exists: according to documentation, it automatically removes the container, and its anonymous volumes, when it exits (volumes are covered in Lesson 8) ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). The fifth block uses it with a new nuance: after the image name comes the word `healthcheck`. **Whatever you write after the image name is passed to the container's main program**, and here it turns the service into its own client: instead of serving, it runs the health check and exits. Since inside that container nobody is serving on port 9000, the check fails with `connection refused` and exit code 1. And the `0` that follows confirms the container no longer exists: `--rm` deleted it.

A nuance measured while writing this lesson: with `docker run -d --rm`, the deletion occurs **a fraction of a second after** the container stops, not before `docker stop` returns. In an early version of this script, which performed `docker stop` on a `-d --rm` container and counted immediately afterward, the count yielded `1`: the stopped container lingered for a few milliseconds. That is why the script uses the form without `-d`, where `docker run` does not return until the container has finished and been removed. If a script of yours ever counts containers immediately after stopping one with `--rm`, now you know where that extra number comes from.

### 2.11 Leaving nothing behind

#### 2.11.1 Only your own

The sixth block of `fig02_07.sh` is the check you will run at the end of each lesson in this course:

```bash
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

`-a` includes stopped containers, which are the ones people forget. The filter `name=^curso-docker-` matches only containers whose name **begins** with `curso-docker-`: the `^` anchors the start of the name. The documentation only states that the filter matches all or part of the name, so this was measured when writing this lesson: on a machine with ten containers having `dev-` in the middle of their names, `--filter name=dev-` matched all ten, while `--filter name='^dev'` matched none. Without the `^`, filtering for `curso-docker-` would also grab a container named, for example, `old-curso-docker-x`. And `wc -l` counts lines. If it outputs `0`, you left nothing behind.

To **delete** all your containers in one shot, that same list feeds into `docker rm -f`:

```bash
docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f
```

`-q` requests only container IDs ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)), `xargs` passes them as arguments to the next command, and `-r` prevents `xargs` from executing if the input is empty.

This is the underlying reason for the course rule that **everything you create begins with `curso-docker-`**: it allows you to clean up strictly your own work without disturbing anything else on the machine.

#### 2.11.2 The command you must not use blindly

Sooner or later you will encounter `docker container prune` in a tutorial. It does exactly what its documentation states: "remove **all** stopped containers" ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). All of them: yours, those from other projects on the same computer, and those belonging to any tool that uses Docker behind the scenes. A stopped container might be another project's database that you intentionally left shut down, with its configuration preserved inside the container. `prune` does not ask whose container it is; it asks "are you sure?" once, and with `--force`, not even that. It supports filters by label and age, but not by name ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). Docker's own `docker rm` documentation recommends it for removing all stopped containers ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)); that is fine on a dedicated single-purpose machine. On yours, prefer filtering by name: delete what you know is yours. The same applies to its relatives `docker system prune` and `docker volume prune`, which delete even more aggressively.

> [!NOTE]
> 🔧 **Engineering observation 2.3**
> Cleanup is not a step left "for the end, if there is time." In this lesson's scripts, cleanup is scheduled **before** creating anything, using `trap ... EXIT`, so that it happens even if the script aborts halfway through. Apply the same mindset to your daily work: decide how you will delete something at the moment you create it, not afterward.

## The error you will see

There are two, the ones from the opening scene, and both are triggered by `fig02_06.sh`:

```bash
#!/usr/bin/env bash
# fig02_06.sh — Los dos errores de todos los días: nombre repetido y puerto ocupado.
# Ojo con el segundo: el contenedor que falla SÍ queda creado.
set -uo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-otro >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null

echo "== 1. Otro contenedor con el MISMO nombre"
docker run -d --name curso-docker-prueba curso-docker-prueba:1.0.0
echo "código de salida: $?"

echo
echo "== 2. Otro contenedor en el MISMO puerto"
docker run -d --name curso-docker-otro -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
echo "código de salida: ${PIPESTATUS[0]}"

echo
echo "== 3. ¿Qué quedó?"
docker ps -a --filter name='^curso-docker-' --format 'table {{.Names}}\t{{.Status}}'
```

```text
$ ./fig02_06.sh
== 1. Otro contenedor con el MISMO nombre
docker: Error response from daemon: Conflict. The container name "/curso-docker-prueba" is already in use by container "c0117bd0d82f44831263964f4f0c3e80262188eee2be39287f270aef5b82cc4d". You have to remove (or rename) that container to be able to reuse that name.

Run 'docker run --help' for more information
código de salida: 125

== 2. Otro contenedor en el MISMO puerto
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint curso-docker-otro (482400ed3eb7fd3dab4753f6c5bf95038ed4b93f2b80fd70c3ac301e5f8059c2): Bind for 127.0.0.1:9000 failed: port is already allocated

Run 'docker run --help' for more information
1dad19130213
código de salida: 125

== 3. ¿Qué quedó?
NAMES                 STATUS
curso-docker-otro     Created
curso-docker-prueba   Up Less than a second (health: starting)
```

Long identifiers change on every run; error messages and exit codes remain identical. `${PIPESTATUS[0]}` is a *bash* variable storing the exit code of the **first** command in a pipeline; it is needed because `$?` would capture the exit code of `cut`.

**The duplicate name.** The message says it all: there is a conflict (*Conflict*), the name `/curso-docker-prueba` is already in use by container with such-and-such ID, and to reuse the name you must remove or rename that container. Exit code **125**: Docker failed, not the service. What is treacherous is that the container holding the name **may be stopped**: it won't appear in `docker ps`, only in `docker ps -a`. The fix, in order of preference: if the old container is no longer needed, `docker rm` (or `docker rm -f` if running); if you want to keep it, `docker rename <old> <new>`; or choose another name for the new one.

**The allocated port.** Read from right to left: the cause is `port is already allocated`; the attempt was `Bind for 127.0.0.1:9000`, binding to that address and port; and the entity attempting it was the network setup for container `curso-docker-otro`. Again code **125**. To see who holds the port, check `docker ps` under the PORTS column; if it isn't a container, `ss -ltnp` tells you which host process is using it (the `p` flag requests the process; inspecting other users' processes requires `sudo`). The fix: stop the process holding it, or publish yours on a different host port (`-p 127.0.0.1:9002:9000`), which changes nothing inside the container.

**And the detail nobody tells you.** Notice the `1dad19130213` appearing after the port error: it is a container ID. `docker run -d` printed it because **the container was indeed created**; what failed was starting it. The third block confirms it: `curso-docker-otro` was left in the `Created` state. It isn't running, it isn't consuming memory, but **it holds onto its name**. If you correct the port and re-run the command with the same name, the next error you will see is the duplicate name error, leading you to think Docker went mad. No: they are two chained errors. After an "allocated port" error, delete the leftover container: `docker rm curso-docker-otro`. And do not attempt to rescue it with `docker start` once the port frees up: Exercise 1 shows you what happens.

The duplicate name error with a **stopped** container and the port collision with its ghost container together make up the opening scene. With `docker ps -a` and the filter from 2.11, both are solved in ten seconds.

## The security habit of the lesson

**Ports published only to `127.0.0.1`, limits from the very first container, and never `--privileged` or mounting the Docker socket inside a container.**

You have already practiced the first two. Publishing to `127.0.0.1` prevents a test container from being exposed to anyone on your network, and your firewall will not protect you (2.8). Limits prevent a buggy container from bringing down other programs on your machine (2.9).

The third is highlighted here because in everyday tutorials you will encounter commands violating it, and it pays to recognize them before pasting. Lesson 0 taught you that `--privileged` gives the container full capabilities and device access to the host ([Docker, "Running containers"](https://docs.docker.com/engine/containers/run/)): almost no barrier remains. And it taught you that the daemon runs as `root` and only trusted users should be allowed to control it ([Docker Engine security](https://docs.docker.com/engine/security/)), to the extent that membership in the `docker` group is equivalent to `root` ([Docker, Linux post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)). Mounting the socket inside a container—seen in tutorials as `-v /var/run/docker.sock:/var/run/docker.sock`—hands that container that exact same power: it can ask the daemon to spawn another container with your host's root filesystem mounted, running as `root`. If a command you are about to copy contains either of these two, pause and ask yourself if you genuinely need it. In this course, never.

## What gets done wrong

**Publishing ports without an address, "because that's how the example wrote it."** `-p 9000:9000` publishes on all interfaces, and `ufw` does not stop it. Always write `-p 127.0.0.1:9000:9000`, and when you genuinely need another machine to reach the container, make that decision deliberately.

**Running without limits "because it's just a test."** Tests are precisely where programs have bugs. `--memory`, `--cpus`, and `--pids-limit` cost a single line.

**Reading `Up` as "it is working."** `Up` merely means the process exists. You saw this in 2.4: the service answered `503` and Docker kept saying `Up`. To know if it is serving, query the service.

**Only checking `docker ps`.** Without `-a` you miss stopped containers, which are the ones hogging names and disk space. To inspect your machine, use `docker ps -a`.

**Using `docker exec` to fix things.** Whatever you change disappears with the container. Furthermore, in minimal images, such as the test service, there is not even a shell—and that is a good thing.

**Using `docker rm -f` as a reflex.** It kills with `SIGKILL`, giving the program no chance to clean up open files or connections. For anything with data, run `docker stop` first.

**Deleting a failed container without reading its log.** The log disappears with it. First run `docker logs --tail 50`, then `rm`.

**Cleaning up with `prune` on a shared machine.** It wipes out everyone's containers. Filter by your prefix instead.

**Leaving behind the ghost container from an occupied port.** It lingers in `Created` status with its name reserved; remove it before retrying.

## Exercises

Exercises 1 and 4 are analytical; 2 and 3 are performed on your Mint. Write your predictions in your [logbook](bitacora.md) before looking at the solutions.

### Exercise 1 — Predict `docker ps -a`

You start with a machine clean of `curso-docker-` containers. You run this, in order:

```bash
docker run -d --name curso-docker-a -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker run -d --name curso-docker-b -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker stop curso-docker-a
docker run --rm --name curso-docker-c curso-docker-prueba:1.0.0 healthcheck
```

Resource limits were omitted from these commands to keep them compact on the page and make the sequence clearer; on your machine, add `--memory 64m --cpus 0.5 --pids-limit 50`, which does not change the outcome.

1. Which of the four commands exit with an error, and with which exit code?
2. Which containers appear in `docker ps -a --filter name=^curso-docker-`, and in what status?
3. If you now run `docker start curso-docker-b`, does it start? Why?
4. What two commands leave the machine completely clean?

### Exercise 2 — Another port, another budget

Start the test service under these conditions: name `curso-docker-ejercicio`, you talk to it on port **9002** of your host machine (only from your host), and with **32 MiB** of memory, a quarter of a CPU, and a maximum of 20 processes. Afterward:

1. Verify with `curl` that it replies `sano` on port 9002.
2. Predict what `memoria=` and `cpus(nano)=` will output using the template from `fig02_04.sh`, and verify it.
3. Predict what `docker stats --no-stream` will display in the memory limit column.
4. Set it to down mode and verify that `docker ps` still displays `Up`.
5. Clean everything up.

### Exercise 3 — The log as evidence (project)

Imagine that the `revisor` reported at 10:04 that the test service was down, and you want to verify it independently without relying on the `revisor`. Start the test service, make three requests in healthy mode, switch it to down mode, make two more requests, and switch it back to healthy. Then, using **only** `docker logs` and its options:

1. Display only the last three lines.
2. Display the log showing the timestamp for each line.
3. Display only logs from the last minute.
4. Stop the container and prove that the log is still there. Delete it and prove that it is gone.

### Exercise 4 — Explain it to the person who did it

Your teammate from the opening scene tells you: "I have `ufw` enabled, so publishing with `-p 9000:9000` is harmless." In five sentences at most, explain why it isn't, and what they should have written instead. Use the words *interface*, *127.0.0.1*, and *firewall*.

## Solutions

### Solution 1

1. The **second** command fails: port 9000 on `127.0.0.1` is already held by `curso-docker-a`; it terminates with `port is already allocated` and exit code 125. The fourth is **not** a Docker error, but it does exit with code **1**: the `healthcheck` subcommand finds no service listening inside that container (`connection refused`), just as in block 5 of `fig02_07.sh`.
2. Two: `curso-docker-a` in `Exited (0)`, because you stopped it and the service shuts down cleanly with `SIGTERM`; and `curso-docker-b` in `Created`, the ghost container from the occupied port. `curso-docker-c` does not appear: it had `--rm`, and `docker run` without `-d` does not return until it has deleted it.
3. **It starts, but without its port**, and this is the outcome almost nobody predicts. This was measured when writing the lesson, with Docker 29.2.1: `docker start curso-docker-b` exited with code 0 and `docker ps` showed it `Up`, but the PORTS column was **empty**, `docker port` printed nothing, and `curl` to `127.0.0.1:9000` got no response. `docker inspect` revealed the difference: in `.HostConfig.PortBindings`, `127.0.0.1:9000` was still requested, but in `.NetworkSettings.Ports`, what was actually mapped, there was nothing. If you predicted "it starts and takes port 9000, which is now free," your reasoning was logical; the ghost container simply does not behave that way. This is one more reason for the rule in "The error you will see": after an occupied port, **delete** the container left in `Created` and create it fresh with `docker run`, rather than trying to rescue it with `docker start`.
4. One command to delete and another to verify: `docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f` followed by `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l`, which must print `0`.

Items 1, 2, and 3 were verified by running this exact sequence on the test machine.

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

1. The critical part is `-p 127.0.0.1:9002:9000`: 9002 is **yours**, 9000 remains the service's port inside the container. If you wrote `-p 127.0.0.1:9002:9002`, `curl` gets no response, because nobody inside the container is listening on 9002.
2. `memoria=33554432`, which is 32 × 1024 × 1024, and `cpus(nano)=250000000`, a quarter of a billion: a quarter of a CPU. It is the same calculation from 2.7.1 with different values.
3. The column will show `… / 32MiB`. What precedes the slash changes; the limit does not.
4. `Up`, with or without the health tag. When writing the lesson this was measured: immediately after setting it to down mode, `Up 2 seconds (health: starting)`; twelve seconds later, `Up 14 seconds (unhealthy)`. It continues to show `Up` even when flagged as unhealthy. Docker discovers the downtime thanks to the health check built into the image, not because it independently monitors what the service returns.
5. `docker rm -f` is appropriate here: it is a disposable practice container with no data.

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

1. If you pasted the block all at once, the last three lines are the two down-mode requests and the switch back to healthy: `GET / en modo caido` twice and `modo cambiado a sano`. If you typed the commands one by one and took more than five seconds, `GET / en modo …` lines from the health check will appear interspersed (2.5): you didn't trigger them, Docker did, and your `--tail 3` will differ.
2. With `--timestamps`, each line begins with the date and time Docker received it, in UTC (indicated by the trailing `Z`), with nanoseconds: in the verification run, `2026-10-21T08:39:45.967466997Z servicio-prueba: GET / en modo caido`. With that column you could pinpoint the exact second the outage started; remember to convert to your local timezone (in Mexico City, subtract 6 hours).
3. `--since 1m` shows everything, provided you completed the exercise in under a minute: startup, each request (including the wait loop), each mode switch, plus one line per health check executed in the interim, so the total grows with the time you take. This is your tool for investigating "what happened since 10:00", substituting `1m` with an hour or timestamp.
4. After `docker stop`, the log is still there, and now its final line is `servicio-prueba: recibí terminated, apagando`: the shutdown was also recorded. After `docker rm`, `docker logs` fails with `Error response from daemon: No such container: curso-docker-bitacora`: the container no longer exists, and its log vanished with it. That is the evidence you would lose if you deleted before reading.

### Solution 4

One possible answer: "Without an address, `-p 9000:9000` publishes the port across all **interfaces** on your machine, including Wi-Fi, not just your local loopback. And the `ufw` **firewall** does not block it, because Docker injects its own routing rules and container traffic is processed before `ufw` ever sees it; Docker's documentation explicitly warns about this. As a result, anyone on the coffee shop network could communicate with your container. What you should have written is `-p 127.0.0.1:9000:9000`: **127.0.0.1** is the interface that only routes to your own machine. The protection lies in the `-p`, not in the firewall."

## How I know I succeeded

Run the seven scripts in [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia) on your Mint, in order (`fig02_01.sh` builds the image used by the others; its block 1 only displays the error if the image does not yet exist), and compare your outputs against those in this lesson. What is **not** compared, because it changes on every run: container and image identifiers, timings (`Up 2 seconds`, `3.08 s`, `242 ms`, build durations), active memory reported by `docker stats` and your host's total memory, and `arm64` versus `amd64`. Everything else should match. Check off each item:

- [ ] `docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'` prints `curso-docker-prueba:1.0.0 15.1MB` (or a very similar size on `amd64`).
- [ ] With the service running, `docker ps` displays `127.0.0.1:9000->9000/tcp` in the PORTS column, with neither `0.0.0.0` nor `[::]`.
- [ ] `curl -s http://127.0.0.1:9000/` replies `sano`; in down mode, `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/` replies `503`, and `docker ps` continues to say `Up`.
- [ ] `docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}' curso-docker-prueba` prints `memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532`.
- [ ] You triggered and analyzed both errors in `fig02_06.sh`, and you understand why a container left in `Created` status must be deleted following the second one.
- [ ] `docker stop curso-docker-prueba` takes under a second and leaves `Exited (0)`; the log terminates with `recibí terminated, apagando`.
- [ ] You can explain, without looking, the difference between stopped and deleted, and what is lost with each.
- [ ] When finished, `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l` prints `0`, and the image `curso-docker-prueba:1.0.0` **remains** in `docker image ls`: you will need it.
- [ ] You recorded in your logbook what changes between `-p 9000:9000` and `-p 127.0.0.1:9000:9000`, verified using `ss -ltn`.

## Summary

Answer without looking at the lesson:

1. What do exit codes 125, 126, and 127 of `docker run` signify? Which did you see when running an image that did not exist, and which when requesting `sh` in the test service?
2. What question does each option in `docker run -d --name … -p 127.0.0.1:9000:9000 --memory 64m --cpus 0.5 --pids-limit 50 …` answer?
3. What is the difference between `docker ps` and `docker ps -a`, and why does it matter for cleanup?
4. Why can `docker ps` report `Up` for a service returning `503`?
5. What does `docker logs` see and what does it miss? What happens to the log with `stop` and with `rm`?
6. Why does `docker exec … sh` fail in the test service, and why is that beneficial?
7. What does `memoria=0` mean in `docker inspect`?
8. What is the difference between publishing on `127.0.0.1` versus specifying no address? Why doesn't `ufw` protect you?
9. What does `docker stop` do, step by step, and how does it differ from `docker rm -f`?
10. How do you delete strictly your own containers, and why should you avoid `docker container prune` on a shared machine?

## Sources

All consulted on October 21, 2026.

- [docker container run](https://docs.docker.com/reference/cli/docker/container/run/): `-d`, `--name`, `-p`, `--rm`, `--pids-limit`, the default value of `--pull`, and the warning regarding ports published on all interfaces and `ufw`.
- [Docker, "Running containers"](https://docs.docker.com/engine/containers/run/): exit codes 125, 126, and 127, and what `--privileged` does.
- [docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/): `-a`, `-q`, filtering by name and status, and `--format` fields.
- [docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/): what the command returns and options `--follow`, `--tail`, `--since`, and `--timestamps`.
- [docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/): `-i`, `-t`, requirement that the main process be running, and requirement that the command be an executable.
- [docker inspect](https://docs.docker.com/reference/cli/docker/inspect/): low-level information and `--format` templates.
- [docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/): `--no-stream` and memory and process columns.
- [docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM`, the 10-second timeout, `SIGKILL`, and `--timeout`.
- [docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/): `--force` with `SIGKILL` and the `prune` recommendation.
- [docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/): that it removes all stopped containers, and its filters.
- [docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/): reference view of the command.
- [Docker, "Port publishing and mapping"](https://docs.docker.com/engine/network/port-publishing/): publishing to all addresses by default, security warning, and publishing to `127.0.0.1`.
- [Docker, "Packet filtering and firewalls"](https://docs.docker.com/engine/network/packet-filtering-firewalls/): why container traffic bypasses `ufw` rules.
- [Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/): no limits by default, out-of-memory risks, minimum `--memory`, and `--cpus` example.
- [Docker Engine security](https://docs.docker.com/engine/security/): daemon as `root` and why only trusted users should control it.
- [Docker, Linux post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/): the `docker` group and its root-equivalent privileges.
- [Docker Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/): versions and dates in "About the runs" and the new view in `docker image ls` since 29.0.
- [Colima](https://github.com/abiosoft/colima): tool used to run the programs on macOS.

### Terms in this lesson

| | |
|---|---|
| **log** (*bitácora*) | what the main program of a container writes to its standard output and standard error; Docker stores it and `docker logs` displays it |
| **exit code** (*código de salida*) | the number a program finishes with; 0 is "all good" |
| **build context** (*contexto de construcción*) | the folder that `docker build` uses to look for the `Dockerfile` and the files the recipe copies |
| **distroless** | family of minimal base images that only contain what is essential for a program to run, without a shell |
| **container state** (*estado de un contenedor*) | created, running, stopped; deleted means it no longer exists |
| **tag** (*etiqueta*) | what follows the colon in an image name: `1.0.0` in `curso-docker-prueba:1.0.0` |
| **network interface** (*interfaz de red*) | each network "entry point" of a machine; `127.0.0.1` is the one that only leads to the machine itself (*loopback*) |
| **publishing a port** (*publicar un puerto*) | connecting a host port to a container port, with `-p` |
| **`SIGTERM`** | the signal used to request a program to terminate; it can be handled to shut down cleanly |
| **`SIGKILL`** | signal 9, which kills a program without giving it an opportunity to close anything |

---

**Next:** [Lesson 3 — Your First Dockerfile](03-primer-dockerfile.md)
