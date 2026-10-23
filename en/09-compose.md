# Lesson 9 — Compose: the complete system

It is Thursday, 5:40 in the afternoon. Tomorrow at 9:00 a new intern joins the team and her first task is to start the `revisor` on her computer to see how it works. You sent her on chat what you use: six commands from Lesson 8, copied from your history. Two networks, a volume, two `docker run`s of three and five lines, a `docker network connect`. At 5:52 she answers with a screenshot: the `revisor` says `FALLA` for the test service, with a `no such host`. You check the commands she copied and find the problem: she skipped the `docker network connect`, the last one, because she thought it was optional. You explain. At 6:05 she sends another screenshot: now it shows `OK`, but the `revisor`'s container has no `--read-only` or `--cap-drop ALL`, because she copied the `docker run` from Lesson 3, which was higher up in the same chat. And tomorrow your boss wants the report to show three services at once, one healthy, one slow and one down, to show at the meeting. That is four containers, with their startup order, and somebody will have to remember everything. It is 6:10. The question is no longer how a container is run, but **how to write an entire system so that nobody has to remember anything**. This lesson exists so that tomorrow you send a single file and a single command, and what it starts is exactly what you tested, hardened, with its token outside the file and with the report in its place.

**Time:** 2 × 45 min

**What you build:** a `compose.yaml` in your `revisor/` folder that describes the complete system: the `revisor`, built from its Dockerfile, and three copies of the test service (healthy, slow and down) so that the report shows `OK`, `LENTO` and `FALLA` without touching anything by hand. The two networks from Lesson 8 (a normal one and an internal one with no way out), the report's volume, the token as a Compose secret and all the security options from Lessons 2 to 8, written just once. With `docker compose up -d --build` the system is started from scratch; with `docker compose down`, it is shut down without losing the report.

**What you learn:** what Compose is and what a project is; how each `docker run` option translates into a key in the file; `docker compose config` to validate and to see what Compose understood; `up`, `ps`, `logs`, `stop` and `down`, and why asking for `up` twice does nothing the second time; how Compose names its containers, networks and volumes; `depends_on` with `service_healthy` and why "started" is not "ready"; Compose secrets and the trap in their permissions; YAML anchors and `x-` fields to avoid repetition; `pull_policy: never`; the error of three services building the same image and that of `--wait` with a service that fails on purpose; and what `docker init` is and why we do not use it.

**Where you are coming from.** From [Lesson 8](08-volumenes-y-redes.md) you bring the final state that this lesson moves into a file: the image `curso-docker-revisor:1.5.0`, which stores its report in `/datos` by default and ships that folder owned by `65532`; the report volume; the normal network through which the port is published and the internal network with no way out where the test service lives. From [Lesson 7](07-salud-y-ciclo-de-vida.md) you bring the hardened options (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`, limits), the `unless-stopped` restart policy and a promise: to use health to order the startup of several services. From [Lesson 6](06-configuracion-y-secretos.md) you bring the token in `secretos/revisor_token.txt`, with `644` permissions (a permission that is only acceptable for a fake token: in 9.8.3 you measure who can read it and in 9.8.4 you close it), and another promise: Compose secrets. And from [Lesson 2](02-contenedores-dia-a-dia.md), the image `curso-docker-prueba:1.0.0` and the habit of publishing ports only on `127.0.0.1`. Your folder has `revisor/` (with its `Dockerfile`, its `.dockerignore` and `secretos/`) and, next to it, `servicio-prueba/`.

**What this lesson does not do.** It does not change the Dockerfile: the image is the same 1.5.0 from Lesson 8, only now Compose builds it. It does not teach Docker Swarm or the `deploy` fields that only make sense in a cluster: this course works on one machine, and the step to several machines is the Kubernetes course. It does not use profiles, override files (`compose.override.yaml`) or `include`: they are useful when a project grows, and with a single file you first learn what all of them combine. It does not use `docker compose watch` or code mounts for development, because here the `revisor` is delivered, not programmed. And it does not publish the image to any registry: that is [Lesson 10](10-entregar-la-imagen.md).

**About the runs.** All outputs are real and were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4, the same base as Linux Mint 22, the course's reference system, with kernel 6.8 and an `arm64` processor. The scripts were run **inside** that virtual machine, with Docker 29.2.1 (client and daemon), **Docker Compose v5.0.2** and Buildx v0.31.1, and with their working folder on Linux's own disk; that matters in section 9.10, which deals with a file's permissions, because folders shared between the Mac and the virtual machine lie about them. On your Mint that problem does not exist. The course was planned with Docker Engine 29.8.2 and Compose v5.6.0 (measured on October 7), and the latest Engine version published on the day of the runs was 29.9.2, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)); we do not expect anything in this lesson to change between those versions, but the outputs were measured with Compose v5.0.2: if your version gives a different text in an error, compare it by its meaning. Check yours with `docker version` and `docker compose version`. **The names.** So as not to touch yours, the scripts use a Compose project of their own, `curso-docker-fig09`, and their own images, `curso-docker-revisor:fig09` and `curso-docker-prueba:fig09`; that way they never touch your `curso-docker` project, your `curso-docker-revisor:1.5.0` or your `curso-docker-prueba:1.0.0`, and on exit they delete only what they created. That is why in the outputs the containers are called `curso-docker-fig09-revisor-1` and not `curso-docker-revisor-1`, which is what they will be called in your folder (section 9.4 explains where each part of the name comes from). Also, since other lessons were running on the same machine, the scripts were launched with another prefix and another port (the `PREFIJO` and `PUERTO` variables they carry); a `nombres` function, in plain view in each script, rewrites that prefix as `curso-docker-` and the port as `8080`, and with the default values it changes nothing. What **does** change from one run to another, and it is flagged where it appears: the times in the `revisor`'s table (masked with `<t>`, which is why sometimes the column ends up one space further left or right), the seconds in `Up N`, the number of the report's temporary file (`<n>`), the dates, the order of some events that happen at the same time, the service that a validation error names and, in 9.11, in which attempts and in which of the three services the clash happens. The programs are in [`programas/09-compose/`](../programas/09-compose), each one with its output next to it, and `estado/` keeps the project's files as they end up when finished.

## By the end you will be able to

- Translate Lesson 8's `docker run`, `docker network create` and `docker volume create` commands into a `compose.yaml` without `version:`, and explain which key corresponds to each option.
- Validate the file with `docker compose config --quiet` and read in `docker compose config` the long form of what you wrote short.
- Start, look at and shut down the system with `up -d --build`, `ps`, `logs`, `stop` and `down`, and predict which containers Compose recreates when you change the file.
- Trigger and explain the `500` of `read-only file system` when the hardened `revisor` has nothing mounted on `/datos`.
- Order the startup with `depends_on` and `condition: service_healthy`, and explain why the `revisor` waits only for the healthy copy.
- Deliver the token as a Compose secret, check that it does not appear in `docker inspect` or in `docker compose config`, and diagnose the `permission denied` of a file with `600`.
- Measure who can read the token's file with `644`, `600` and `640` (with `ls -l`, `stat` and an unprivileged account), and leave it with the minimum permission that still lets the `revisor` work.
- Recognize the clash of three services that build the same tag and the failure of `up --wait` with a service that is down on purpose, and choose the correct alternative.

## The why before the how

What you did in Lesson 8 works, and that is exactly how it should be learned: each piece with its command, to see what it contributes. But it has three problems that appear the day someone else uses it, or the day you yourself use it three weeks later.

The first is that **the system lives in your history**. Six commands, in an order that matters, with options that nobody writes the same way twice. The scene at the beginning is not exaggerated: skipping a `docker network connect` is enough for the `revisor` not to find the test service, and copying the wrong `docker run` is enough to lose Lesson 7's hardening without anything warning you. A service that depends on someone remembering six commands depends, really, on that person's memory.

The second is that **the order is done by hand**. The networks before the containers, the volume before the `revisor`, the test service before whoever checks it. And when shutting down, the other way around: containers first, because a network or a volume in use cannot be deleted. In Lesson 8 you did that ordering; with four containers instead of two, and with one that must wait for another to be **healthy** and not merely running, the order no longer fits in your head.

The third is that **there is no way to know what is running compared with what should be**. If tomorrow you change the mode of a test service, which containers do you have to delete and create again? With `docker run` you give the answer. Ideally a tool would compare what you asked for with what exists and touch only what changed.

Compose solves the three things with one idea: **describe the system in a file, and let a tool make it exist**. Its documentation defines it as "a tool for defining and running multi-container applications" ([Docker, "Docker Compose"](https://docs.docker.com/compose/)). The file, `compose.yaml`, says which services there are, which networks they live in, which volumes and secrets they use, and with which options they run. The `docker compose up` command reads the file, compares it with what already exists and creates, recreates or leaves alone what is needed, in the right order. The file is stored next to the code, reviewed like code, and sent to the intern in place of six commands.

With that destination in mind, this is what you will have at the end, in section 9.9: the complete system started with one command, and the `revisor`'s report showing the test service's three behaviors without you having touched anything by hand:

```text
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200
```

(It is block 3 of `fig09_05.sh`; the spaces before `<t>` change with the time that was masked.) That table is the first of the course's goals: "`docker compose up` starts everything from scratch and the report shows the down test service as `FALLA`".

## The concepts

### 9.1 What Compose is, and what a project is

#### 9.1.1 A *plugin*, a file, a specification

Compose comes with Lesson 1's installation: the `docker-compose-plugin` package adds the `docker compose` subcommand (with a space). It is not a separate program you have to install with `pip` or a binary you download by hand; it is an extension of the `docker` client, and that is why its version is asked for with `docker compose version`.

The file is called `compose.yaml`. The documentation says that the default path is `compose.yaml` ("preferred") or `compose.yml` in the working folder, and that Compose also accepts `docker-compose.yaml` and `docker-compose.yml` "for backward compatibility with earlier versions" ([Docker, "How Compose works"](https://docs.docker.com/compose/intro/compose-application-model/)). This course uses the preferred name.

What goes inside the file is not invented by Docker every year: it is defined by the **Compose specification**, a public document that describes each key and what it means ([Compose specification](https://docs.docker.com/reference/compose-file/)). The top-level elements you will use today are five: `name`, `services`, `networks`, `volumes` and `secrets`. There are others this lesson does not use: `configs` (configuration files that are not secrets; the `revisor` is configured through variables and does not need it), `include` (to join several files) and `models` (which, according to the specification, "declares the AI models your Compose application uses", [specification, `models`](https://docs.docker.com/reference/compose-file/models/)); and `version`, which is already obsolete (9.2.3). The documentation presents them like this: an application's components "are defined as services", services "communicate with each other through networks", and "store and share persistent data in volumes" ([Docker, "How Compose works"](https://docs.docker.com/compose/intro/compose-application-model/)).

#### 9.1.2 A service is not a container

Here is the first new idea, and it is worth not passing over it quickly. In Lesson 8 you created **containers**: `curso-docker-revisor`, `curso-docker-prueba`. In Compose you describe **services**: `revisor`, `prueba`. A service is the recipe ("run this image, with these options, on these networks"); the container is what comes out of applying the recipe. Normally a service yields one container, but the difference matters for two reasons you will see in the lesson. One: the name it is best to use to find it by DNS is the **service**'s (`prueba`), not the container's. The container's name also resolves inside the network (it was checked), but it carries the project's name and a replica number, which change from one folder to another. Two: when you change the recipe, Compose throws away the old container and creates a new one; the service remains the same.

#### 9.1.3 The project: everything's surname

A **project** is, according to the documentation, "an individual deployment of an application specification" ([Docker, "How Compose works"](https://docs.docker.com/compose/intro/compose-application-model/)). In practice, it is the name Compose puts in front of everything it creates, to know what is its own. The course's `compose.yaml` starts with `name: curso-docker`, and that is why everything it creates carries that name: containers, networks and volumes. If you do not write it, Compose uses the name of the folder where the file is, which in your case would be `revisor`: a surname too generic for you to recognize among other projects.

The project name can be set in five ways, and the documentation says which one wins: first the `-p` command-line option; then the `COMPOSE_PROJECT_NAME` environment variable; then the file's `name:`; then the name of the file's folder; and finally the name of the current folder. It only admits "lowercase letters, decimal digits, dashes, and underscores" ([Docker, "Specify a project name"](https://docs.docker.com/compose/how-tos/project-name/)). That same page says what it is for: "Compose uses a project name to isolate environments from each other". This lesson's scripts take advantage of that: they set `COMPOSE_PROJECT_NAME=curso-docker-fig09`, which wins over the file's `name:`, and so their run never mixes with your `curso-docker` project, even though the file is the same.

### 9.2 From `docker run` to the file

#### 9.2.1 Lesson 8's final state, written once

The concrete first. This is Lesson 8's final state, the one from section 8.10.3, in a file. Save it in your `revisor/` folder with the name `compose.yaml`:

```yaml
# fig09_01.compose.yaml — Lección 9, primer paso: el estado final de la
# Lección 8 (sección 8.10.3), escrito en un archivo en vez de en seis comandos.
# Un solo servicio de prueba, sin token. Va en tu carpeta revisor/ como compose.yaml.
#
# Sin «version:» a propósito: la especificación de Compose ya no la usa.
name: curso-docker

services:
  revisor:
    build:
      context: .
      args:
        VERSION: "1.5.0"
    image: curso-docker-revisor:1.5.0
    environment:
      REVISOR_SERVICIOS: "prueba http://prueba:9000/ 2s"
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - reportes:/datos
    networks:
      - publica
      - interna
    depends_on:
      - prueba
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50

  prueba:
    build: ../servicio-prueba
    image: curso-docker-prueba:1.0.0
    networks:
      - interna
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50

networks:
  publica: {}
  interna:
    internal: true

volumes:
  reportes: {}
```

Read it from the bottom up, which is how Compose builds it. At the end are the **networks** and the **volume**: `publica`, `interna` (with `internal: true`, Lesson 8's `--internal`) and `reportes`. The empty braces `{}` say "with the default options": a `bridge` network and a local volume. At the top are the two **services**. Each service lists its networks by short name (`publica`, `interna`) and mounts the volume by short name (`reportes:/datos`); Compose adds the project's surname when creating them. The test service is only on `interna`; the `revisor`, on both. Exactly as in 8.10.3, but without the `docker network connect` step that the intern forgot: here there are no steps, there is a description.

#### 9.2.2 Each option, its key

Almost every `docker run` option has a key with a similar name. This table is the one you will use to translate any command from the earlier lessons:

| `docker run` | `compose.yaml` | Note |
|---|---|---|
| `curso-docker-revisor:1.5.0` (the image) | `image:` | with `build:` next to it, it is the name the built image receives |
| `docker build --build-arg VERSION=1.5.0 .` | `build: { context: ., args: { VERSION: "1.5.0" } }` | Compose builds before creating the container |
| `-e REVISOR_SERVICIOS=…` | `environment:` | as a map (`KEY: value`), with no quotes reaching the value |
| `-p 127.0.0.1:8080:8080` | `ports: ["127.0.0.1:8080:8080"]` | the `127.0.0.1` address is written just as in Lesson 2 |
| `-v curso-docker-reportes:/datos` | `volumes: [reportes:/datos]` + `volumes:` at the top | the volume is declared once at the top level |
| `--network …` and `docker network connect …` | `networks: [publica, interna]` + `networks:` at the top | all of the service's networks in a list |
| `--read-only` | `read_only: true` | |
| `--cap-drop ALL` | `cap_drop: [ALL]` | |
| `--security-opt no-new-privileges` | `security_opt: ["no-new-privileges:true"]` | |
| `--init` | `init: true` | |
| `--memory 64m`, `--cpus 0.5`, `--pids-limit 50` | `mem_limit: 64m`, `cpus: 0.5`, `pids_limit: 50` | |
| `--restart unless-stopped` | `restart: unless-stopped` | appears in the final file (9.9) |
| `--name curso-docker-revisor` | (nothing) | Compose sets the name: project, service and number |

The services reference describes each one with the same intention you met in Lesson 7: `read_only` creates the container "with a read-only filesystem"; `init` runs "an init process (PID 1) inside the container that forwards signals and reaps processes"; `cpus` defines how many CPUs, "potentially virtual", are assigned to it; and `pids_limit` tunes the process limit ([Compose services reference](https://docs.docker.com/reference/compose-file/services/)). There is no new magic: they are the same daemon options, written in another place.

Two keys in the table deserve one more sentence. The first, `security_opt`: the reference says that boolean options like `no-new-privileges` can be written in three equivalent forms (`no-new-privileges`, `no-new-privileges=true` and `no-new-privileges:true`). The course uses the last one because it leaves the fewest doubts. The second, `depends_on: [prueba]`: it has no equivalent in `docker run`, because ordering containers was your job. It tells Compose that the `revisor` is created and started after `prueba`. Further on (9.7) you will see that "after" does not mean "when it is ready".

#### 9.2.3 Without `version:`

The file does not start with `version: "3.8"` or anything like it, and it is not an oversight. The specification says that the `version` element exists only for compatibility, that it "is only informative" and that if you use it you will receive "a warning that it is obsolete" ([specification, `version` and `name`](https://docs.docker.com/reference/compose-file/version-and-name/)). You will see it in almost every tutorial from a few years ago, because the old Compose required it in order to know which keys to accept. Today's applies the specification in force for the version you have installed and does not need that field. If you find it, delete it.

### 9.3 Validating and reading what Compose understood

#### 9.3.1 `docker compose config`

Before starting anything, it is worth knowing whether the file is valid and whether Compose understood what you meant. That is what `docker compose config` is for, which according to its reference "renders the actual data model to be applied on the Docker Engine": it resolves the variables and "expands short notation into the canonical form" ([`docker compose config` reference](https://docs.docker.com/reference/cli/docker/compose/config/)). Three options make it useful day to day: `--quiet` only validates and prints nothing (if the file is wrong, the error comes out and the code is not 0); `--services` lists the services, one per line; and `--volumes`, the volumes.

The script `fig09_02.sh` takes your first `compose.yaml` and runs it through the whole cycle: validate, read, start, ask again and shut down. It is the lesson's first script, so here it goes in full; the following ones repeat the same beginning (the support names, the working folder and the functions `muestra`, `eventos`, `esperar` and `tabla`) and in the lesson only the part that changes is shown:

```bash
#!/usr/bin/env bash
# fig09_02.sh — El primer compose.yaml (fig09_01): validarlo, leer lo que Compose
# entiende, levantarlo, pedir el reporte, volver a pedir «up» y apagarlo.
# Construye sus propias imágenes de apoyo; no usa ni toca las tuyas.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig09»: el proyecto de Compose se llama curso-docker-fig09
# y las imágenes curso-docker-revisor:fig09 y curso-docker-prueba:fig09. Así el
# guion nunca toca tu proyecto curso-docker, tu curso-docker-revisor:1.5.0 ni tu
# curso-docker-prueba:1.0.0, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig09.XXXXXX")"
export COMPOSE_PROJECT_NAME="${PREFIJO}fig09"   # gana sobre el «name:» del archivo
trap 'cd "$TRABAJO/revisor" 2>/dev/null && docker compose down --volumes --remove-orphans >/dev/null 2>&1
      docker rmi -f "${PREFIJO}revisor:fig09" "${PREFIJO}prueba:fig09" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso, el estado de la Lección 8 (con el
# token de la Lección 6) y el compose.yaml de fig09_01.compose.yaml, con los nombres de apoyo
# y el puerto del guion.
mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
cp -R "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$AQUI/estado/secretos" "$TRABAJO/revisor/"
chmod 644 "$TRABAJO/revisor/secretos/revisor_token.txt"   # 644: solo porque el token es de mentira (9.8.4)
sed -e "s/curso-docker-revisor:1.5.0/${PREFIJO}revisor:fig09/" \
    -e "s/curso-docker-prueba:1.0.0/${PREFIJO}prueba:fig09/" \
    -e "s/127.0.0.1:8080:8080/127.0.0.1:${PUERTO}:8080/" \
    "$AQUI/fig09_01.compose.yaml" > "$TRABAJO/revisor/compose.yaml"
cd "$TRABAJO/revisor"
TOKEN="$(cat secretos/revisor_token.txt)"   # se lee del archivo; nunca se escribe

# Si corres el guion con otro PREFIJO o PUERTO, la salida se escribe con los del
# curso. Con los valores por omisión esto no cambia nada.
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g" -e "s/127.0.0.1:${PUERTO}->/127.0.0.1:8080->/g" \
                -e "s/127.0.0.1:${PUERTO}\//127.0.0.1:8080\//g" -e "s/published: \"${PUERTO}\"/published: \"8080\"/"; }
# muestra COMANDO: lo imprime con «$ », lo corre y dice el código si no fue 0
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# eventos: de lo que imprime Compose, solo los renglones «Objeto nombre Estado»
eventos() { grep -E '^ *(Image|Network|Volume|Container) ' | sed -E 's/^ +//; s/ +$//'; }
# esperar SERVICIO ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar() {
  for _ in $(seq 60); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "${COMPOSE_PROJECT_NAME}-$1-1" 2>/dev/null)" = "$2" ] && return 0
    sleep 1
  done
  echo "($1 no llegó a $2)"; return 1
}
# tabla: el reporte en forma de tabla, con el token y con los tiempos tapados
tabla() { curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'; }

echo "== 1. ¿Es válido? ¿Qué servicios y volúmenes declara?"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config --volumes"

echo
echo "== 2. Lo que Compose entendió: la forma larga de lo que escribiste corto"
muestra "docker compose config | sed -n '/^  revisor:/,/^  prueba:/p' | grep -E -A5 '^    (ports|volumes|depends_on):'"
muestra "docker compose config | grep -E '^  [a-z]+:$|^    (cpus|mem_limit|pids_limit|read_only|internal|init):'"

echo
echo "== 3. Levantarlo todo"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s 'http://127.0.0.1:${PUERTO}/api/estados?formato=tabla' | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'"

echo
echo "== 4. Pedir «up» otra vez, sin cambiar nada"
muestra "docker compose up -d 2>&1 | eventos"

echo
echo "== 5. Apagar: down borra contenedores y redes; el volumen se queda"
muestra "docker compose down 2>&1 | eventos | grep -vE 'Stopping|Removing'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
```

And its output:

```text
$ ./fig09_02.sh
== 1. ¿Es válido? ¿Qué servicios y volúmenes declara?
$ docker compose config --quiet && echo 'compose.yaml válido'
compose.yaml válido
$ docker compose config --services
prueba
revisor
$ docker compose config --volumes
reportes

== 2. Lo que Compose entendió: la forma larga de lo que escribiste corto
$ docker compose config | sed -n '/^  revisor:/,/^  prueba:/p' | grep -E -A5 '^    (ports|volumes|depends_on):'
    depends_on:
      prueba:
        condition: service_started
        required: true
    environment:
      REVISOR_SERVICIOS: prueba http://prueba:9000/ 2s
--
    ports:
      - mode: ingress
        host_ip: 127.0.0.1
        target: 8080
        published: "8080"
        protocol: tcp
--
    volumes:
      - type: volume
        source: reportes
        target: /datos
        volume: {}
networks:
$ docker compose config | grep -E '^  [a-z]+:$|^    (cpus|mem_limit|pids_limit|read_only|internal|init):'
  prueba:
    cpus: 0.5
    init: true
    mem_limit: "67108864"
    pids_limit: 50
    read_only: true
  revisor:
    cpus: 0.5
    init: true
    mem_limit: "67108864"
    pids_limit: 50
    read_only: true
  interna:
    internal: true
  publica:
  reportes:

== 3. Levantarlo todo
$ docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'
Image curso-docker-prueba:fig09 Built
Image curso-docker-revisor:fig09 Built
Network curso-docker-fig09_interna Created
Network curso-docker-fig09_publica Created
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-1 Created
Container curso-docker-fig09-revisor-1 Created
Container curso-docker-fig09-prueba-1 Started
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-prueba-1 | Up N (healthy) | 9000/tcp
curso-docker-fig09-revisor-1 | Up N (healthy) | 127.0.0.1:8080->8080/tcp
$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200

== 4. Pedir «up» otra vez, sin cambiar nada
$ docker compose up -d 2>&1 | eventos
Container curso-docker-fig09-prueba-1 Running
Container curso-docker-fig09-revisor-1 Running

== 5. Apagar: down borra contenedores y redes; el volumen se queda
$ docker compose down 2>&1 | eventos | grep -vE 'Stopping|Removing'
Container curso-docker-fig09-revisor-1 Stopped
Container curso-docker-fig09-revisor-1 Removed
Container curso-docker-fig09-prueba-1 Stopped
Container curso-docker-fig09-prueba-1 Removed
Network curso-docker-fig09_interna Removed
Network curso-docker-fig09_publica Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
```

#### 9.3.2 Reading blocks 1 and 2

1. **Valid, with two services and a volume.** `config --quiet` prints nothing if the file is fine; the script's `echo` says it for it. Notice that `prueba` comes out before `revisor`, even though in the file you wrote it afterwards. Compose does not list in the order you wrote: dependencies come out first and whoever depends on them last, and `depends_on` decides that. (You will see it more clearly in 9.9, with four services: the three copies of the test service first, among them in alphabetical order, and the `revisor` last. What does vary from one run to another is the order of `up`'s events, because several things happen at once.)
2. **The long form.** Here is what the person reviewing someone else's file really wants to know. Your `depends_on: [prueba]` became `condition: service_started` and `required: true`: the short form is the long form with the default values. Your `"127.0.0.1:8080:8080"` became a block with `host_ip: 127.0.0.1`, `target: 8080` (the container's port) and `published: "8080"` (your machine's): if you ever doubt which number is which, `config` tells you with names. Your `reportes:/datos` became `type: volume`, `source: reportes`, `target: /datos`. And in the second command, `mem_limit: 64m` appears as `"67108864"`, which is 64 × 1024 × 1024 bytes, the same number that `docker inspect` showed you in Lesson 2. `config` is the best tool for reviewing a `compose.yaml` you did not write: it does not tell you what the author meant, it tells you what is going to happen.

A habit worth adopting from today: **every time you edit the file, run `docker compose config --quiet` before `up`**. An indentation error in YAML changes the meaning without giving a syntax error (a key that ended up inside the wrong service, for example), and `config` is where you see it before the container starts with a different configuration.

### 9.4 Starting, looking and shutting down

#### 9.4.1 `up`: creating what is missing, in order

`docker compose up` is the central command. Its reference sums it up in one line: "builds, (re)creates, starts, and attaches to containers for a service" ([`docker compose up` reference](https://docs.docker.com/reference/cli/docker/compose/up/)). With `-d` ("detached mode") it leaves the containers in the background and gives you the terminal back; with `--build`, it builds the images before starting, even if they already exist.

Block 3 of `fig09_02.sh` shows what it did, in the order it did it. First the **two images**, `Built`. Then the **networks**, `curso-docker-fig09_interna` and `curso-docker-fig09_publica`, and the **volume**, `curso-docker-fig09_reportes`. Then the **containers**: both `Created`, and `Started` first `prueba` and then `revisor`, because the `revisor` depends on it. It is the order you used to do by hand in Lesson 8, now decided by the file. (The script removes the intermediate lines from the listing, like `Building`, `Creating` or `Starting`, so that the results can be read; in your terminal you will see them all.)

#### 9.4.2 What things are called

Look at the names carefully, because you will type them in `docker inspect`, in `docker logs` and in the `alpine` helper:

- **Containers**: `<project>-<service>-<number>`. In the output, `curso-docker-fig09-revisor-1`; in your folder, with `name: curso-docker`, `curso-docker-revisor-1`. The number exists because a service can have several replicas; here it is always `1`.
- **Networks and volumes**: `<project>_<name>`, with an underscore. `curso-docker-fig09_interna`, `curso-docker-fig09_reportes`; in your folder, `curso-docker_interna` and `curso-docker_reportes`.

Since the project starts with `curso-docker`, everything keeps carrying the course prefix, and Lesson 2's habit (being able to delete the course's things without touching the rest) is maintained. Besides, Compose puts the label `com.docker.compose.project=<project>` on everything it creates. It is the clean way to ask "what belongs to this project", and block 5 uses it: `docker volume ls --filter label=com.docker.compose.project=…`.

And a question you are surely asking yourself: if the container is called `curso-docker-fig09-prueba-1`, why does the `revisor` look for it as `http://prueba:9000/`? Because in a project's networks, each container registers in the built-in DNS (Lesson 8's `127.0.0.11`) under its **service**'s name and also under its own; in a separate test, both names resolved to the same address. The service's name is the one worth writing, because it is the only one that depends neither on the project nor on the replica number. The documentation explains it with its example: the `web` service's container joins the network "under the name `web`" ([Docker, "Networking in Compose"](https://docs.docker.com/compose/how-tos/networking/)). That lets you write `REVISOR_SERVICIOS` without knowing what the project will be called: the same file works in your folder, in the intern's and in the script.

The same page says what happens if you declare no networks: Compose creates **one** network, `<project>_default`, and connects all the services to it. Your file declares its own, and that is why there is no `_default` in the output. It is not a detail: with Compose's default network, the test service would have access to the internet, and Lesson 8 decided it does not need it.

#### 9.4.3 `ps`: what there is, and how it is doing

`docker compose ps` is the project's `docker ps`: it only shows its containers. Block 3 uses it with a custom format (name, status and ports) and masks the seconds of `Up` with `Up N`. Both are `(healthy)`, because both images carry their `HEALTHCHECK` from Lessons 2 and 7, and the `revisor`'s port is on `127.0.0.1:8080`. The test service publishes nothing: it does not need to, the `revisor` talks to it over the internal network. And the `revisor`'s table says `prueba OK`.

#### 9.4.4 Asking for `up` again: nothing happens, and that is the good part

Block 4 runs `docker compose up -d` again, changing nothing. Compose answers `Running` for both and touches neither. This is the most important difference from a `docker run` script: a repeated script tries to create again and clashes with Lesson 2's repeated name. Compose, instead, **compares** what you ask for with what exists. The `up` reference says it like this: if a service's configuration or image changed, Compose "picks up the changes by stopping and recreating the containers", and keeps the mounted volumes ([`docker compose up` reference](https://docs.docker.com/reference/cli/docker/compose/up/)). If nothing changed, nothing is touched. That is why `docker compose up -d` is safe to repeat: it is the way of saying "let this exist", not "create this".

#### 9.4.5 `down`: the volume stays

Block 5 shuts down with `docker compose down`. It stops and deletes the containers (first the `revisor`, which depends on `prueba`; Compose shuts down in the reverse order of the dependencies) and deletes the networks. And the volume **stays**: `docker volume ls` still shows it. The `down` reference lists what it deletes by default: the services' containers, the networks in the `networks` section and the default network if one was used ([`docker compose down` reference](https://docs.docker.com/reference/cli/docker/compose/down/)). Named volumes are not on that list; to delete them you have to ask for it with `--volumes`, which deletes "the named volumes declared in the `volumes` section". It is the right decision: shutting the system down should not cost you the report. In 9.12 you will see it survive.

### 9.5 The error: the hardened `revisor` with nothing on `/datos`

#### 9.5.1 Triggering it

Since Lesson 8's 1.5.0 image, the `revisor` stores its report in `/datos/reporte.json` **by default**: the image carries `REVISOR_REPORTE=/datos/reporte.json` in its `ENV`. And the `compose.yaml` runs it with `read_only: true`. What happens if someone, while tidying up the file, deletes the volume line because "we do not use the report"? The script `fig09_03.sh` does it in plain view, with `sed`, and shows the difference with `diff` before starting. The part of the script that changes with respect to `fig09_02.sh`:

```bash
cp compose.yaml compose.bueno.yaml

echo "== 1. Sin el volumen en /datos"
# Borra el renglón «volumes:» del revisor y el que le sigue («- reportes:/datos»).
sed -i '/^    volumes:$/{N;d;}' compose.yaml
muestra "diff compose.bueno.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Healthy)'"
esperar revisor healthy
muestra "docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'"

echo
echo "== 2. Con el volumen: Compose recrea SOLO el revisor"
cp compose.bueno.yaml compose.yaml
muestra "docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing'"
esperar revisor healthy
muestra "curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
```

```text
$ ./fig09_03.sh
== 1. Sin el volumen en /datos
$ diff compose.bueno.yaml compose.yaml
19,20d18
<     volumes:
<       - reportes:/datos
[código de salida: 1]
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Healthy)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]

== 2. Con el volumen: Compose recrea SOLO el revisor
$ docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing'
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-1 Running
Container curso-docker-fig09-revisor-1 Recreate
Container curso-docker-fig09-revisor-1 Recreated
Container curso-docker-fig09-revisor-1 Started
$ curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:8080/api/estados
[200]
```

#### 9.5.2 Reading it

1. **The `diff`** shows the two lines that are missing (and exits with `1`, which in `diff` means "there are differences", not "it failed"). The file is still valid: a service with no volumes is perfectly legal, and that is why `config --quiet` would not save you here. The container starts and reaches `(healthy)`, because `/salud` writes nothing. Docker is happy.
2. **But the report gives `500`**: `open /datos/.reporte-<n>.tmp: read-only file system`. It is the error from section 7.7 of Lesson 7, in another folder: the `revisor` tries to create its temporary file in `/datos`, and `/datos` is part of the container's filesystem, which is read-only. There is nothing mounted on top that accepts writes. Notice that the `revisor` does not crash or pretend: it answers `500` with the exact cause. It is the course's second principle at work: the container is `healthy` and the service does not do what it should.
3. **The fix**, putting the two lines back, and the day's second Compose lesson. `up -d` creates the volume that is now used (`Volume … Created`), leaves the test service as it was (`Running`) and **recreates only the `revisor`** (`Recreate`, `Recreated`, `Started`), because its configuration changed. The report goes back to `200`.

The rule you take away: **with `read_only: true`, every folder where the program writes needs something mounted on top**. In the `revisor` it is just one, `/datos`, and the course's file always mounts it. If one day you change `REVISOR_REPORTE` to another path, that path also needs its volume (or its `tmpfs`, if it does not have to last).

### 9.6 Three copies of the test service without writing the same thing three times

#### 9.6.1 Why three

With a single test service, the report always says `OK`, unless you change its mode by hand with `POST /modo/caido`. But the test service lives on an internal network and publishes no port: to change its mode you would have to get in some other way. There is a better way to show the three behaviors at once, and it is the one the boss in the scene asked for: **three containers from the same image, each started in a different mode** with `PRUEBA_MODO`. That way the report shows `OK`, `LENTO` and `FALLA` as soon as the system starts, without touching anything.

Three nearly identical services mean the same block of hardened options written three times, and a repeated block is a block that someday somebody changes in two of the three copies. Compose has two tools for that, and they are used together.

#### 9.6.2 `x-` fields and YAML anchors

The first is a Compose rule: top-level fields that start with `x-` are ignored. The documentation says it just so: "Compose ignores any field that starts with `x-`", and it is "the only exception" where it silently ignores a field it does not recognize; they serve to "modularize configurations you want to reuse" ([specification, extensions](https://docs.docker.com/reference/compose-file/extension/)).

The second is not Compose's but YAML's: **anchors** and **aliases**. An anchor is placed with `&name` in front of a block; an alias, `*name`, refers to that block; and the merge key `<<: *name` copies the block's keys into another map, where you can add or replace the ones you want. Compose's documentation warns of two details: the merge "only applies to mappings, and cannot be used with sequences", and when fragments are used, environment variables go as a map (`KEY: value`) and not as a list (`- KEY=value`) ([specification, fragments](https://docs.docker.com/reference/compose-file/fragments/)). That is why all of the course's `environment` is written as a map.

Together they look like this, in a fragment of the final file:

```yaml
x-prueba: &prueba
  image: curso-docker-prueba:1.0.0
  pull_policy: never
  networks: [interna]
  read_only: true

services:
  prueba-lento:
    <<: *prueba
    environment:
      PRUEBA_MODO: lento
```

`x-prueba` is not a service (Compose ignores it), but its content exists for YAML with the `&prueba` anchor. `prueba-lento` copies that whole block with `<<: *prueba` and adds its `environment`. Block 1 of `fig09_05.sh`, below, proves it to you by asking `config` for the `prueba-lento` service: `image`, `pull_policy`, `read_only`, `mem_limit` and `networks` appear, which are not written in the service but in the anchor.

#### 9.6.3 Who builds, and `pull_policy: never`

One decision remains: who builds the image `curso-docker-prueba:1.0.0`? If the anchor carried `build: ../servicio-prueba`, the three copies would inherit it, and Compose would launch **three builds at once of the same tag**. That clashes, and in 9.11 you will trigger it. The final file does something else: only `prueba-sano` carries `build`. The other two use the image that the first one builds.

And so that those two do not go looking for it on the internet, the anchor carries `pull_policy: never`. The reference defines it like this: with `never`, Compose "does not pull the image from a registry and relies on the platform cached image" ([Compose services reference](https://docs.docker.com/reference/compose-file/services/)). What happens without that line? You will measure it in block 2 of `fig09_07.sh` (section 9.11): on a machine where the image does not yet exist, Compose first goes looking for it on Docker Hub for each service that does not build it, receives Lesson 2's `pull access denied` twice, and then, since another service in the project does build it, goes on ahead, builds it and starts everything. It works, but it makes queries to the internet that you do not need, fills the output with errors that are not errors, and leaves the result in the hands of whatever someone published under that name. With `pull_policy: never`, the image name stops being a question to the internet and becomes a reference to something you built.

A consequence worth knowing: since only `prueba-sano` builds, asking for a single service on a machine where the image does not exist yet (for example, `docker compose up prueba-lento` right after cloning the project) leaves nobody to build it. In a separate test with a nonexistent image and `pull_policy: never`, Compose ended with code `1` and the message `No such image`. Start the whole project with `docker compose up -d --build`, or build first with `docker compose build prueba-sano`.

### 9.7 "Started" is not "ready": `depends_on` with a condition

#### 9.7.1 What `depends_on` does by default

In the first file you wrote `depends_on: [prueba]`, and `config` showed you that this is `condition: service_started`. The documentation is very clear about what it means: "On startup, Compose does not wait until a container is 'ready', only until it is running" ([Docker, "Control startup order"](https://docs.docker.com/compose/how-tos/startup-order/)). It is the same confusion as in Lesson 7, carried over to the startup order: the process exists, but perhaps it is not serving yet.

#### 9.7.2 The three conditions

The long form of `depends_on` accepts three conditions ([Compose services reference](https://docs.docker.com/reference/compose-file/services/)):

| Condition | Compose waits for the dependency to… |
|---|---|
| `service_started` | be running (it is what the short form does) |
| `service_healthy` | be "healthy", according to its `healthcheck` |
| `service_completed_successfully` | finish successfully (for one-off tasks, such as preparing something beforehand) |

This lesson's is `service_healthy`: "Compose waits for the health checks of the dependencies marked `service_healthy` to pass" ([Docker, "Control startup order"](https://docs.docker.com/compose/how-tos/startup-order/)). For that the dependency needs a health check, and the test service has it in its image since Lesson 2 (every 5 s, with 2 retries). It is Lesson 7's promise: health restarts nothing, but somebody uses it. Today Compose uses it.

#### 9.7.3 Why the `revisor` waits only for the healthy one

Here is the file's finest decision, and it deserves a slow reading. The `revisor` depends on the three copies, but **not** with the same condition:

```yaml
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
```

Think about what would happen if all three were `service_healthy`. `prueba-caido` always answers `503`: its health check **never** passes, so Compose would wait for Docker to declare it `unhealthy` (with 2 retries every 5 s, about ten seconds) and then it would give up: in a separate test with a dependency that always fails (check every 2 s, 2 retries), `docker compose up -d` ended after 5 s with code `1` and the message `dependency failed to start: container ... is unhealthy`, and the service that depended on it was left in `Created`, not started. It is the same error you will see in 9.11.3. The result is the same: the `revisor` would never start. And neither would `prueba-lento`: its check demands an answer in under 2 seconds, and in slow mode it takes 3. Services that fail on purpose cannot be healthy, because failing is their job. What the `revisor` needs is for them to **exist** (so that their name is in the DNS) and for at least one to be ready so that the first report has something to say. Hence: the healthy one, `service_healthy`; the others, `service_started`.

That is the general rule, and you will use it in all your projects: **`service_healthy` for what your service needs healthy in order to start (a database, for example), and `service_started` for what it only needs to exist**. And an honest warning: `depends_on` only orders the **startup**. If a dependency goes down an hour later, Compose does not stop or restart the one that depended on it. The `revisor` handles it well because its job is precisely to report whoever does not respond.

### 9.8 Compose secrets

#### 9.8.1 What they are and where they appear

In Lesson 6 you mounted the token with a single-file `--mount type=bind`, at `/run/secrets/revisor_token`, and said where it pointed with `REVISOR_TOKEN_ARCHIVO`. Compose has an element for that. Its documentation defines a secret as "any piece of data, such as a password, certificate, or API key" that should not travel unprotected, and says where it appears: secrets "are mounted as a file in `/run/secrets/<secret_name>` inside the container" ([Docker, "Secrets in Compose"](https://docs.docker.com/compose/how-tos/use-secrets/)). That is why the `revisor` has used that path since Lesson 6: it is Compose's convention.

They are declared in two places, like networks and volumes. At the top, where it comes from:

```yaml
secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

And in the service, who receives it:

```yaml
    secrets:
      - revisor_token
```

That second part matters: "services can only access secrets when explicitly granted by a `secrets` attribute" ([Docker, "Secrets in Compose"](https://docs.docker.com/compose/how-tos/use-secrets/)). The three copies of the test service do not receive it, and that is why they do not see it. The value is never written in the file: the `compose.yaml` says **where** the token is, not **what** it is. That way the file can go into the repository and `secretos/` cannot: they are two exclusion files, one per destination. The `.dockerignore` keeps it out of the image (it has done so since Lesson 6) and the `.gitignore` keeps it out of the repository (9.8.4). This course's material does carry its `secretos/` folder inside the repository, on purpose, because its token is fake; yours, with a real token, must not.

#### 9.8.2 The trap: the permissions are the file's

What follows is the most important thing in this section, because it is an error that the documentation explains in a note and almost nobody reads. The long form of a secret in the service accepts `uid`, `gid` and `mode`, and they seem the perfect solution: "let the file inside the container belong to user 65532, with `0400` permission". But **when the secret comes from a file, Compose ignores them**. The reference puts it like this: with a file as the source, Compose uses underneath a mount that does not allow changing the owner, "and these attributes are silently ignored"; they only work when the secret comes from an environment variable ([Compose services reference](https://docs.docker.com/reference/compose-file/services/)).

In practice, that means the Compose secret is **the same mount as Lesson 6's**, with the owner and permissions the file has on your machine. If the file is `600`, only your user reads it; the `revisor` runs as `65532`; the result is `permission denied` and the `revisor` exits with code 1. If it is `644`, it reads it. You will trigger it in 9.10, with `uid`, `gid` and `mode` declared, so that you see they change nothing. That is why the course uses the short form (`- revisor_token`): writing `uid`, `gid` and `mode` with a file secret does nothing but give a false sense of security.

The practical consequence is that **the file's permission on your machine is a security decision you make**, not Compose. `644` makes the `revisor` start, but it also lets any other account on your machine read the token. The next two sections measure it and show the safe way; section 6.5.4 of Lesson 6 says the same thing, in other words.

#### 9.8.3 Measuring who can read the token

A permission like `644` is three digits, one for each group of people: the file's **owner**, the file's **group** and **everyone else**. Each digit adds up `4` (read), `2` (write) and `1` (execute). So, `644` is "the owner reads and writes (`6 = 4 + 2`), the group reads (`4`) and everyone else reads (`4`)". "Everyone else" is not a way of saying "you": it is **any account on your machine**, that of another person with an open session on a shared server, that of a service running with its own user, or that of a program that someone managed to make run as another user. With `600` only the owner reads it, and with `640` the owner and the group read it, and nobody else.

It is checked with two commands. `ls -l secretos/` shows the permissions in letters: `-rw-r--r--` is `644`, `-rw-------` is `600` and `-rw-r-----` is `640`. And `stat -c '%a %U:%G' secretos/revisor_token.txt` shows them as a number, along with the owner and the group. When an owner's number does not correspond to any account on your machine (the `revisor`'s `65532` is not an account), `stat` writes `UNKNOWN`; to see the number, ask for it with `%u:%g` or use `ls -ln`.

But looking at permissions is not the same as **testing** them. The script `fig09_11.sh` does both things and in each case asks the same: can another unprivileged user read it?, can you read it?, can the `revisor`, which runs as `65532`, read it? For "another user" it uses `sudo -u nobody`: `nobody` is an unprivileged account that ships with every Linux, and it is used to impersonate any other user. Before each `Permission denied` from `nobody` there is a control: `sudo -u nobody stat` shows that `nobody` **does reach the file** (the folder is open), so that if the following `cat` fails it is because of the file's permission and nothing else. (On the test machine, the home folder is `750`, and that only stops whoever tries to enter it; do not count on that: the project may be in another path, or someone may open the folder someday.) The script needs `sudo`, to impersonate `nobody` and to change the file's owner. Cases 3 and 4 follow options B and A of 9.8.4 **as they are**, starting from the `644` you arrive with from Lesson 6. The part that changes, with the fake token's file:

```bash
# La cuenta sin privilegios: «nobody» existe en todo Linux y sirve para hacerse
# pasar por «otro usuario cualquiera de tu equipo». El nombre de tu usuario y de tu
# grupo se tapa con sed, porque depende del equipo.
SUBE="docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
PS_REV="docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
STAT="stat -c '%a %U:%G' secretos/revisor_token.txt"
TAPA_TODO="sed -E 's/ .*/ <tu usuario>:<tu grupo>/'"
TAPA_DUENO="sed -E 's/ [^:]+:/ <tu usuario>:/'"
# El control de cada negativa: «nobody» sí llega hasta el archivo (la carpeta está
# abierta); si el cat siguiente falla, es por el permiso del archivo.
CONTROL="sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt"
OTRO="sudo -u nobody cat secretos/revisor_token.txt"

echo "== 1. Permisos 644, dueño tu usuario"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "$PS_REV"

echo
echo "== 2. Permisos 600, dueño tu usuario"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
sleep 4
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "[ \"\$(docker inspect --format '{{.RestartCount}}' ${COMPOSE_PROJECT_NAME}-revisor-1)\" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'"

echo
echo "== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala"
muestra "chmod 644 secretos/revisor_token.txt"   # el estado con el que llegas de la Lección 6
muestra "chmod 600 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "$STAT"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "sudo cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"   # el archivo vuelve a ser tuyo
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chgrp +65532 secretos/revisor_token.txt"
muestra "chmod 640 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_DUENO"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 5. Lo mismo, más la carpeta secretos/ cerrada con 700"
muestra "chmod 700 secretos"
muestra "stat -c '%a' secretos"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"
muestra "chmod 755 secretos"

echo
echo "== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"

echo
echo "== 7. ¿El grupo 65532 es de alguien en este equipo?"
muestra "getent group 65532"
```

```text
$ ./fig09_11.sh
== 1. Permisos 644, dueño tu usuario
$ chmod 644 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ .*/ <tu usuario>:<tu grupo>/'
644 <tu usuario>:<tu grupo>
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)

== 2. Permisos 600, dueño tu usuario
$ chmod 600 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ .*/ <tu usuario>:<tu grupo>/'
600 <tu usuario>:<tu grupo>
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
600 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose logs --no-log-prefix revisor | sort -u
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
$ [ "$(docker inspect --format '{{.RestartCount}}' curso-docker-fig09-revisor-1)" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'
el revisor se reinició: no pudo leer su token

== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala
$ chmod 644 secretos/revisor_token.txt
$ chmod 600 secretos/revisor_token.txt
$ sudo chown 65532:65532 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt
600 UNKNOWN:UNKNOWN
$ stat -c '%a %u:%g' secretos/revisor_token.txt
600 65532:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
600 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ sudo cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200

== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640
$ sudo chown "$(id -un)" secretos/revisor_token.txt
$ chmod 644 secretos/revisor_token.txt
$ sudo chgrp +65532 secretos/revisor_token.txt
$ chmod 640 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ [^:]+:/ <tu usuario>:/'
640 <tu usuario>:UNKNOWN
$ stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'
640 <tu uid>:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
640 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA       <t>  codigo 503
lento     LENTO     <t>  200
sano      OK          <t>  200

== 5. Lo mismo, más la carpeta secretos/ cerrada con 700
$ chmod 700 secretos
$ stat -c '%a' secretos
700
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
$ chmod 755 secretos

== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra
$ sudo chown "$(id -un)" secretos/revisor_token.txt
$ chmod 644 secretos/revisor_token.txt
$ sudo chown 65532:65532 secretos/revisor_token.txt
$ chmod 600 secretos/revisor_token.txt
chmod: changing permissions of 'secretos/revisor_token.txt': Operation not permitted
[código de salida: 1]
$ stat -c '%a %u:%g' secretos/revisor_token.txt
644 65532:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c

== 7. ¿El grupo 65532 es de alguien en este equipo?
$ getent group 65532
[código de salida: 2]
```

A summary of what it showed, case by case:

| Permissions and owner | Can another user read it? | Can you read it? | Can the `revisor` read it? |
|---|---|---|---|
| `644`, your user | **yes** | yes | yes |
| `600`, your user | no | yes | **no** (`permission denied`) |
| `600`, owner `65532` (option B) | no | no, except with `sudo` | yes |
| `640`, your user, group `65532` (option A) | no | yes | yes |

1. **`644`: anyone reads it.** The first block is the finding: `sudo -u nobody cat` prints the complete token. The `revisor` starts healthy, and that is why `644` seems "the solution": it works. But it works because it opens the file to everyone, not only to the `revisor`.
2. **`600` of your user: it closes, and it also closes to the `revisor`.** `nobody` gets `Permission denied`, but so does the `revisor`: it is the error from Lesson 6 and from 9.10. The file is your user's, the `revisor` is user `65532`, and to the kernel the `revisor` is "another user" just like `nobody`. The `se reinició` line confirms that the `revisor` goes in and out in a loop.
3. **`600` with owner `65532` (option B): closed to everyone, except the `revisor`.** Only the file's owner (the `revisor`) and `root` can read it. `nobody` gets `Permission denied`, and so do you, because you are no longer the owner; to see or change it you need `sudo cat`. The `revisor` reaches `(healthy)` and the table comes out with the token. The price: your convenience. And the `UNKNOWN:UNKNOWN` in the first `stat` is not an error: the number `65532` has no account name on your machine. Notice the **order**: first `chmod 600` and then `sudo chown`.
4. **`640` with group `65532` (option A): the convenient way out.** You are still the owner (you read and edit it without `sudo`), and the file's **group** is `65532`. The `revisor` runs as `65532:65532` (user and group, which come from the image: `docker inspect --format '{{.Config.User}}'`), so to the kernel it gets in through the group digit. `nobody` is not in that group and reads nothing. It is the minimum permission that lets both parties work. The same holds as in Lesson 6: the numbers inside and outside must be the same (the normal installation from Lesson 1). With rootless Docker or with user remapping, the `65532` inside corresponds outside to another number (the start of your range in `/etc/subuid` and `/etc/subgid` plus 65532; that start changes from one installation to another, and you read it in those files. As an example, the [`userns-remap` documentation](https://docs.docker.com/engine/security/userns-remap/) tells that, with a range starting at `231072`, `231073` is user `1` inside; `231072` is only the value of that example), and this recipe does not apply as it stands: the `revisor` will give `permission denied`, and there is no leak, but there is no quick fix either; the diagnosis is the `ls -ln` one from Lesson 6.
5. **The `secretos/` folder at `700` does not get in the way.** Block 5 closes it (`chmod 700 secretos`) and the `revisor` is recreated and stays `(healthy)`: the single-file mount is set up by the daemon, not by your user. Close the folder as well as the file: whoever cannot enter it does not even see that the token exists.
6. **The wrong order leaves the token open.** Block 6 does option B backwards: `sudo chown 65532:65532` first and `chmod 600` afterwards. The `chmod` fails with `Operation not permitted`, because you are no longer the owner and the kernel only lets the owner (or `root`) change the permissions. The file stays at `644`, now `65532`'s, and `nobody` prints the token. You always **close first and give away afterwards**, and check at the end.
7. **Group `65532` is not exclusive to the `revisor`.** It is the `nonroot` user and group of the *distroless* images (the `revisor`'s final image is `gcr.io/distroless/static-debian13:nonroot`) and of Chainguard's, so any container from those images to which you mount this file reads it through the group digit. And if on your machine a real group with that number existed, its members would too. That is why the last block asks `getent group 65532`: if it prints nothing (as here, with exit code 2), the number belongs to nobody on your machine.

What no permission prevents: `root` reads everything, and whoever can talk to the Docker daemon (Lesson 1's `docker` group) can mount your folder in a container and read it. That is why you take care over who is in that group; it is another reason not to give the file away to "everyone else".

#### 9.8.4 The safe way in your folder

There are two ways of leaving the file closed, from the most convenient to the strictest. Both let the `revisor` read it and keep the rest out. **Choose one**; do not apply them one after the other.

**Option A**: you are the owner and the `revisor`'s group can read.

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt
chmod 640 secretos/revisor_token.txt
```

The `+` tells `chgrp` that `65532` is a group number and not a name (without the `+`, it also takes it as a number if no group with that name exists).

**Option B**: the owner is the `revisor` itself. You need `sudo` to read it.

```bash
cd revisor
chmod 600 secretos/revisor_token.txt               # primero se cierra, mientras aún eres el dueño
sudo chown 65532:65532 secretos/revisor_token.txt  # después se regala; ya no podrás cambiarlo sin sudo
```

The order matters: if you give away first, the `chmod` fails and the file stays as it was (block 6 of 9.8.3).

Whichever you choose, **always check it**:

```bash
ls -l secretos/revisor_token.txt
stat -c '%a %U:%G' secretos/revisor_token.txt
sudo -u nobody cat secretos/revisor_token.txt   # debe decir: Permission denied
chmod 700 secretos                              # y cierra también la carpeta
```

Afterwards, `docker compose up -d --force-recreate revisor` (changing a file's permission is not a configuration change for Compose, and the `revisor` only reads its token on startup).

**Copies count too.** Each copy of the token is born with its own permissions: a `cp` without `-p` leaves the file in your name, with your group and your `umask`; and an editor's backup copy (`revisor_token.txt~`), the backup of your home folder or a copy to a USB stick or to the cloud do not keep the `640`. Check them with the same `stat`, or do not make them.

**To create a new secret**, have it born closed instead of opening and closing it afterwards. Look at your `umask` with `umask`: it is the permission "subtraction" the system applies to every new file. On Ubuntu and Linux Mint it is usually `0002` (measured on the test machine, Ubuntu 24.04), and a new file comes out as `664`: anyone can read it, just like with `644`. The `644` you saw in Lesson 6 was not set by the `umask`: it was set by the course's `chmod`. Two ways to create a closed file:

```bash
install -m 600 /dev/null secretos/token.txt                              # crea el archivo vacío, ya en 600
(umask 077; read -rs VALOR; printf '%s' "$VALOR" > secretos/token2.txt)  # pegas el valor sin que se vea
```

Three warnings. Both ways are for a file that **does not exist yet**: if it already exists, `umask` does not change its permission (close it with `chmod 600`) and `install` replaces it with an empty one, without warning. Both leave it at `600` **in your name**, which is case 2 of 9.8.3: the `revisor` still cannot read it, so you finish with option A or B. And **do not write the value on the command line** (`VALOR=... ` or `echo ... >`): it stays in your terminal's history; that is why the example uses `read -rs`, or paste it from an editor.

**And when is `644` acceptable?** Only in one situation: a fake token, on a computer that is yours alone, for practice. This lesson's scripts use it inside a temporary folder that is deleted when they finish, and that is why they leave it at `644`. Three warnings, with no fine print:

- **The course's token is fictitious** (`curso-docker-token-de-mentira-7f3a9c`); it opens nothing.
- **`644` lets any local account read it**, as you have just measured.
- **Never use `644` with a real secret**: not on your laptop, not on a server, not "just for a moment while I test".

And the other half of the secret's hygiene: **it must not reach the repository**. In your project, `secretos/` goes in the `.gitignore` from day one, and it is checked:

```bash
echo 'secretos/' >> .gitignore
git check-ignore -v secretos/revisor_token.txt
```

```text
.gitignore:1:secretos/	secretos/revisor_token.txt
```

If `git check-ignore` prints nothing, the file is **not** ignored. (One exception: if `git` already tracked the file before you ignored it, the `.gitignore` does not release it; it is removed with `git rm --cached` and the already-published token is considered lost and is changed, just as in Lesson 6.) What you already saw of Compose in 9.8.1 ends up like this: the `compose.yaml` says where the token is, the `.gitignore` keeps it out of the repository, the `.dockerignore` keeps it out of the image, and the file's permission keeps it out of reach of the rest of your machine.

### 9.9 The final file

#### 9.9.1 All together

This is the `compose.yaml` you end the lesson with. It replaces the first one in your `revisor/` folder; it is the same one that `estado/compose.yaml` keeps:

```yaml
# fig09_04.compose.yaml — el compose.yaml final de la Lección 9. Va en tu carpeta
# revisor/ como compose.yaml (es el mismo que guarda estado/compose.yaml).
#
# Lección 9 — el sistema completo: el revisor y tres copias del servicio de
# prueba (sana, lenta y caída), con todo lo que se endureció en las lecciones 2 a 8.
#
# Sin «version:» a propósito: la especificación de Compose ya no la usa.
name: curso-docker

# Lo común a las tres copias del servicio de prueba, escrito una sola vez.
# Compose ignora los campos que empiezan con «x-»; sirven para anclas de YAML.
# Solo prueba-sano lleva «build»: si las tres construyeran la misma etiqueta a la
# vez, chocarían («image ... already exists»). Las otras dos usan la imagen que
# construye la primera y nunca la buscan en internet (pull_policy: never).
x-prueba: &prueba
  image: curso-docker-prueba:1.0.0
  pull_policy: never
  networks: [interna]
  read_only: true
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
  init: true
  mem_limit: 32m
  cpus: 0.25
  pids_limit: 20

services:
  revisor:
    build:
      context: .
      args:
        VERSION: "1.5.0"
    image: curso-docker-revisor:1.5.0
    environment:
      REVISOR_SERVICIOS: >-
        sano http://prueba-sano:9000/ 2s,
        lento http://prueba-lento:9000/ 5s,
        caido http://prueba-caido:9000/ 2s
      REVISOR_TOKEN_ARCHIVO: /run/secrets/revisor_token
    secrets:
      - revisor_token
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - reportes:/datos
    networks:
      - publica
      - interna
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50
    restart: unless-stopped

  prueba-sano:
    <<: *prueba
    build: ../servicio-prueba
    environment:
      PRUEBA_MODO: sano

  prueba-lento:
    <<: *prueba
    environment:
      PRUEBA_MODO: lento

  prueba-caido:
    <<: *prueba
    environment:
      PRUEBA_MODO: caido

networks:
  publica: {}
  interna:
    internal: true

volumes:
  reportes: {}

secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

What changed with respect to the first one, service by service:

- **`x-prueba`**: the common block of the three copies (9.6), with the same hardened options as the `revisor`, `init: true` included. They carry smaller limits (32 MB and a quarter of a CPU), because they do almost nothing.
- **`revisor`**: three services in `REVISOR_SERVICIOS`, the token as a secret with `REVISOR_TOKEN_ARCHIVO` pointing to `/run/secrets/revisor_token`, `depends_on` with its conditions (9.7), and `restart: unless-stopped`, the policy Lesson 7 chose for the `revisor`.
- **`prueba-sano`, `prueba-lento`, `prueba-caido`**: the anchor plus its mode. Only the healthy one builds.
- **At the top**: the same networks and the same volume, plus the secret.

A YAML detail in `REVISOR_SERVICIOS`: the `>-` is a **folded block**. YAML joins the three lines into one, with a space where there were line breaks, and the `-` removes the final newline. That way each service stays on its own line of the file, easy to read and to change, and the `revisor` receives a single comma-separated string, which is what it expects. Block 5 of the next run shows you the value as it reached the container.

#### 9.9.2 Seeing it work

The script `fig09_05.sh` starts it from scratch and checks it from the inside. The part that changes:

```bash
echo "== 1. Validar"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'"

echo
echo "== 2. Levantar todo desde cero"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 3. El reporte: sin token, 401; con token, la tabla"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
muestra "tabla"

echo
echo "== 4. Lo que creó Compose, todo con el nombre del proyecto"
muestra "docker network ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}} interna={{.Internal}}' | sort"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 5. El token no está a la vista"
muestra "docker inspect ${COMPOSE_PROJECT_NAME}-revisor-1 | grep -c \"\$TOKEN\""
muestra "docker compose config | grep -c \"\$TOKEN\""
muestra "docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1 | grep REVISOR_"
muestra "docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
```

```text
$ ./fig09_05.sh
== 1. Validar
$ docker compose config --quiet && echo 'compose.yaml válido'
compose.yaml válido
$ docker compose config --services
prueba-caido
prueba-lento
prueba-sano
revisor
$ docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'
      PRUEBA_MODO: lento
    image: curso-docker-prueba:fig09
    mem_limit: "33554432"
    networks:
    pull_policy: never
    read_only: true

== 2. Levantar todo desde cero
$ docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'
Image curso-docker-revisor:fig09 Built
Image curso-docker-prueba:fig09 Built
Network curso-docker-fig09_publica Created
Network curso-docker-fig09_interna Created
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-caido-1 Created
Container curso-docker-fig09-prueba-sano-1 Created
Container curso-docker-fig09-prueba-lento-1 Created
Container curso-docker-fig09-revisor-1 Created
Container curso-docker-fig09-prueba-caido-1 Started
Container curso-docker-fig09-prueba-sano-1 Started
Container curso-docker-fig09-prueba-lento-1 Started
Container curso-docker-fig09-prueba-sano-1 Waiting
Container curso-docker-fig09-prueba-sano-1 Healthy
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-prueba-caido-1 | Up N (unhealthy) | 9000/tcp
curso-docker-fig09-prueba-lento-1 | Up N (health: starting) | 9000/tcp
curso-docker-fig09-prueba-sano-1 | Up N (healthy) | 9000/tcp
curso-docker-fig09-revisor-1 | Up N (healthy) | 127.0.0.1:8080->8080/tcp

== 3. El reporte: sin token, 401; con token, la tabla
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados
{"error":"falta el token o no es válido"}
 [401]
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200

== 4. Lo que creó Compose, todo con el nombre del proyecto
$ docker network ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}} interna={{.Internal}}' | sort
curso-docker-fig09_interna interna=true
curso-docker-fig09_publica interna=false
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
$ docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' curso-docker-fig09-revisor-1
ReadonlyRootfs=true CapDrop=[ALL] Init=true Memory=67108864 User=65532:65532 Restart=unless-stopped

== 5. El token no está a la vista
$ docker inspect curso-docker-fig09-revisor-1 | grep -c "$TOKEN"
0
[código de salida: 1]
$ docker compose config | grep -c "$TOKEN"
0
[código de salida: 1]
$ docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-fig09-revisor-1 | grep REVISOR_
REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token
REVISOR_SERVICIOS=sano http://prueba-sano:9000/ 2s, lento http://prueba-lento:9000/ 5s, caido http://prueba-caido:9000/ 2s
REVISOR_PUERTO=8080
REVISOR_REPORTE=/datos/reporte.json
$ docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' curso-docker-fig09-revisor-1
bind /run/secrets/revisor_token ro=true
volume /datos ro=false
```

#### 9.9.3 Reading the run

1. **Validate.** Four services. And the `prueba-lento` service, read by `config`, carries `image`, `pull_policy: never`, `read_only`, `mem_limit` (32 MB, in bytes) and `networks`, which came from the anchor. The anchor works.
2. **Start.** Notice the order of the events, which is the heart of this lesson. The two images are built (only two, even though there are four services), networks, volume and the four containers are created. The three copies of the test service start. And then `prueba-sano-1 Waiting` and `prueba-sano-1 Healthy` appear: Compose **waited** for the healthy one to pass its health check, and only afterwards started the `revisor`. It is `service_healthy` at work. The order in which the three copies start may change from one run to another, because they start at the same time.
3. **`ps`.** The health status tells the whole story: `prueba-caido` is `(unhealthy)`, which is its job; `prueba-lento` is `(health: starting)` and will end up `unhealthy` (it takes 3 s and its check demands less than 2); `prueba-sano` and the `revisor`, `(healthy)`. Four `Up` containers, and only two healthy: the course's second principle, in a single table.
4. **The report.** Without a token, `401` with the `revisor`'s message: the secret arrived and the `revisor` is demanding it. With the token, the table with the three states: `FALLA` with `codigo 503`, `LENTO` (it answered `200`, but in more than a second) and `OK`. That is the course's goal.
5. **What Compose created.** Two networks, the internal one with `interna=true`; one volume; and the `revisor` with all of Lesson 7's hardening applied by the daemon: read-only filesystem, `CapDrop=[ALL]`, `Init=true`, 64 MB, user `65532:65532` (which comes from the image) and the restart policy.
6. **The token is not in plain view.** `grep -c` counts zero occurrences of the token's value in the whole `docker inspect` and the whole `docker compose config` (the `[código de salida: 1]` is `grep`'s, which exits with 1 when it finds nothing: here, that is the good news). The container's environment has `REVISOR_TOKEN_ARCHIVO`, which is a **path**, not a value. And the mounts show what a file secret is on the inside: a read-only `bind` (`ro=true`) at `/run/secrets/revisor_token`, next to the `volume` at `/datos`. The course's third goal ("no secret appears in `docker history`, in `docker inspect` or in the container's environment variables") is met, in its run-time part, with the complete system.

#### 9.9.4 In your folder

With the final file in `revisor/compose.yaml`, `servicio-prueba/` next to it and `secretos/revisor_token.txt` with `640` permissions and group `65532` (9.8.4):

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt   # el grupo del revisor puede leerlo...
chmod 640 secretos/revisor_token.txt          # ...y ningún otro usuario (9.8.4)
docker compose config --quiet && echo 'compose.yaml válido'
docker compose up -d --build
docker compose ps
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" 'http://127.0.0.1:8080/api/estados?formato=tabla'
```

A note on that `curl`: while it runs, the token is on its command line and any account can see it with `ps`, even if the file is `640`. With the fake token it does not matter; with a real one, pass it from a headers file (`curl -H @cabeceras.txt`, which must have its own closed permissions).

This lesson's scripts use `644` in a temporary folder, with the fake token; your folder does not need it. With `644`, any user of your computer can read the token (9.8.3), and on a shared server that is not acceptable: the fix is the right group or owner (section 6.5.4 of Lesson 6), not opening it to everyone.

The names will be `curso-docker-revisor-1`, `curso-docker-prueba-sano-1` and so on, with networks `curso-docker_publica` and `curso-docker_interna` and the volume `curso-docker_reportes`. If Lesson 8 left you with `curso-docker-revisor` running on port 8080, shut it down first (`docker rm -f curso-docker-revisor curso-docker-prueba`), or the `up` will clash with Lesson 2's port in use. And if you kept the `curso-docker-reportes` volume from Lesson 8, it does not get in the way: Compose's is another one, `curso-docker_reportes`, with an underscore.

### 9.10 The error that will cost you the most: the secret at `600`

#### 9.10.1 Triggering it with `uid`, `gid` and `mode` written

The script `fig09_06.sh` takes the final file, changes the secret to the long form with `uid: "65532"`, `gid: "65532"` and `mode: 0400` (what "should" fix the permission), puts the token's file at `600` and starts. Then it fixes it with `644`, which is what its scripts use in their temporary folder with the fake token (in your folder, the fix is the one in 9.8.4). The part that changes:

```bash
cp compose.yaml compose.final.yaml

echo "== 1. El secreto en forma larga, con uid, gid y mode; el archivo en 600"
python3 - <<'PY'
s = open("compose.yaml").read()
s = s.replace("""    secrets:
      - revisor_token
""", """    secrets:
      - source: revisor_token
        uid: "65532"
        gid: "65532"
        mode: 0400
""")
open("compose.yaml", "w").write(s)
PY
chmod 600 secretos/revisor_token.txt
muestra "diff compose.final.yaml compose.yaml"
muestra "stat -c '%a %u:%g %n' secretos/revisor_token.txt | sed -E 's/ [0-9]+:[0-9]+ / <tu usuario> /'"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
sleep 3
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
muestra "docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/run/secrets/revisor_token\"}}{{.Type}} {{.Destination}} ro={{not .RW}}{{end}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 2. El arreglo: 644 (y el compose.yaml de la lección, en forma corta)"
cp compose.final.yaml compose.yaml
chmod 644 secretos/revisor_token.txt   # 644: solo porque el token es de mentira (9.8.4)
muestra "stat -c '%a %n' secretos/revisor_token.txt"
muestra "docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "tabla"
```

```text
$ ./fig09_06.sh
== 1. El secreto en forma larga, con uid, gid y mode; el archivo en 600
$ diff compose.final.yaml compose.yaml
41c41,44
<       - revisor_token
---
>       - source: revisor_token
>         uid: "65532"
>         gid: "65532"
>         mode: 0400
[código de salida: 1]
$ stat -c '%a %u:%g %n' secretos/revisor_token.txt | sed -E 's/ [0-9]+:[0-9]+ / <tu usuario> /'
600 <tu usuario> secretos/revisor_token.txt
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose logs --no-log-prefix revisor | sort -u
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
$ docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
Status=restarting ExitCode=1
$ docker inspect --format '{{range .Mounts}}{{if eq .Destination "/run/secrets/revisor_token"}}{{.Type}} {{.Destination}} ro={{not .RW}}{{end}}{{end}}' curso-docker-fig09-revisor-1
bind /run/secrets/revisor_token ro=true

== 2. El arreglo: 644 (y el compose.yaml de la lección, en forma corta)
$ stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
```

#### 9.10.2 Reading it

1. **The `diff`** shows the long form, and `stat` shows the file at `600`, your user's (the number is masked because it depends on the machine).
2. **`Started`.** Compose says the `revisor` started, and it is true: the process started. But the logs tell the rest: `leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied`. The `revisor` could not read its token and preferred to die with code 1 rather than be left listening unprotected (Lesson 6). The script's `sort -u` merges the repeated lines, because the message comes out once per attempt.
3. **`Status=restarting ExitCode=1`.** Attempts? Yes: the final file carries `restart: unless-stopped`, so the daemon starts it again every time it dies, with ever-longer waits, and each time it dies the same way. This is what you will see in a real system when a secret has the wrong permissions: a container that goes in and out, and a `docker compose ps` that says `Restarting`. The restart policy handles the process's death, as you saw in Lesson 7; it cannot fix its cause.
4. **The mount.** The secret is a read-only `bind`, even with `uid`, `gid` and `mode` declared. The three attributes did nothing. It is exactly what the reference says, measured.
5. **The script's fix**: `644` and the lesson's file, with the short form. It is the shortest fix, not the best: it opens the token to the whole machine (9.8.3). In your folder use the one from 9.8.4. `--force-recreate revisor` asks Compose to recreate that service even if its configuration is the same as that of the container that exists; here it is needed because the only thing that changed was a file's permission on your machine, and Compose does not compare that. The `revisor` reaches `(healthy)` and the table is back.

If this happens to you in your folder: `ls -l secretos/`, and if it says `-rw-------`, give read access **only** to the `revisor`'s group (`sudo chgrp +65532 secretos/revisor_token.txt` and `chmod 640 secretos/revisor_token.txt`, 9.8.4) and `docker compose up -d --force-recreate revisor`. `chmod 644` also fixes it, but it leaves the token in view of your whole machine: only with a fake token. What is **not** a fix: removing the image's `USER` or putting `user: "0"` in the service so that `root` reads it. That trades a file permissions problem for an entire container running as `root`.

### 9.11 Two Compose errors worth knowing beforehand

The script `fig09_07.sh` triggers the two errors specific to this file and measures what happens without `pull_policy: never` (the question left open in 9.6.3). The part that changes:

```bash
cp compose.yaml compose.final.yaml

echo "== 1. Las tres copias del servicio de prueba con «build»"
# Pone «build» en el ancla común (las tres copias la heredan) y quita la de prueba-sano.
sed -i -e 's|^  image: \(.*prueba:fig09\)$|  build: ../servicio-prueba\n  image: \1|' \
       -e '/^    build: ..\/servicio-prueba$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
# Es una carrera: a veces una de las tres termina antes de que empiecen las otras
# y no choca. Por eso se intenta cinco veces, borrando la etiqueta entre una y otra.
for i in 1 2 3 4 5; do
  docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1
  echo "-- intento $i"
  muestra "docker compose build >build.log 2>&1; echo \"build salió con \$?\"; grep -h '^target' build.log || true"
done
docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1

echo
echo "== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir"
cp compose.final.yaml compose.yaml
sed -i '/^  pull_policy: never$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'"
docker compose down --remove-orphans >/dev/null 2>&1

echo
echo "== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar"
cp compose.final.yaml compose.yaml
docker compose build >/dev/null 2>&1
inicio=$(date +%s)
muestra "docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1"
echo "(tardó $(( $(date +%s) - inicio )) s)"
muestra "docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1"
muestra "docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 4. Lo que sí funciona: up -d y esperar la salud del revisor"
esperar revisor healthy && echo "revisor: healthy"
muestra "tabla"
```

```text
$ ./fig09_07.sh
== 1. Las tres copias del servicio de prueba con «build»
$ diff compose.final.yaml compose.yaml
15a16
>   build: ../servicio-prueba
67d67
<     build: ../servicio-prueba
[código de salida: 1]
-- intento 1
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 2
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 0
-- intento 3
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 4
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-lento: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 5
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 0

== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir
$ diff compose.final.yaml compose.yaml
17d16
<   pull_policy: never
[código de salida: 1]
$ docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'
Image curso-docker-prueba:fig09 Pulling
Image curso-docker-prueba:fig09 Pulling
Image curso-docker-prueba:fig09 Error pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'
Image curso-docker-prueba:fig09 Error pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'
Image curso-docker-prueba:fig09 Building
Image curso-docker-prueba:fig09 Built

== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar
$ docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1
container curso-docker-fig09-prueba-caido-1 is unhealthy
[código de salida: 1]
(tardó 11 s)
$ docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1
container curso-docker-fig09-prueba-caido-1 is unhealthy
[código de salida: 1]
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (health: starting)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)

== 4. Lo que sí funciona: up -d y esperar la salud del revisor
revisor: healthy
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
```

#### 9.11.1 Three builds of the same tag

With `build` in the anchor, the three test services build the same image with the same name, and Compose launches the three builds **at the same time**. All three end with the same image and all three try to give it the same name at the end; the one that arrives later finds the name taken: `target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists`, and `build` exits with `1`. Notice two things. The first: the service that reports the clash can be any of the three, depending on which one finishes last; in this run it was `prueba-sano` in attempts 1 and 3, and `prueba-lento` in the 4th. The second: in attempts 2 and 5 it did **not** clash, and `build` exited with `0`. It is a race, and sometimes it is won: in this run it failed in 3 of 5 attempts. An error that appears "sometimes" is worse than one that always appears, because it makes you believe you fixed it when you were only lucky.

The cause is one of design, not of luck: **an image is built once and used many times**. That is why the final file puts `build` in a single service and `pull_policy: never` in the other two (9.6.3). In your terminal, the full message is preceded by BuildKit's steps; look for the line that starts with `target`, which tells you in which service it failed.

#### 9.11.2 Without `pull_policy: never`

Block 2 removes the `pull_policy: never` line from the anchor (the `diff` shows it) and starts with the test service's image still unbuilt (block 1 deleted it at the end). The image events tell what we said in 9.6.3: two `Pulling` and two `Error pull access denied`, one for each service that does **not** build the image (`prueba-lento` and `prueba-caido`) and that, without `never`, first look for it on Docker Hub. Afterwards, `Building` and `Built`: Compose sees that another service in the project builds that same image, lets the error pass and goes on. The system starts all the same. That is why `pull_policy: never` is not there to make it work, but so that it **does not ask**: without the line, the startup depends on nothing existing on Docker Hub under that name, and it fills your terminal with errors you have to learn to ignore, which is the worst habit one can have in the face of an error.

#### 9.11.3 `--wait` with a service that fails on purpose

`docker compose up --wait` exists for scripts and for continuous integration: according to its reference, it waits for the services to be "running or healthy", and implies detached mode; `--wait-timeout` sets how many seconds to wait at most ([`docker compose up` reference](https://docs.docker.com/reference/cli/docker/compose/up/)). It sounds perfect for waiting for the `revisor`, but look at block 3: `container curso-docker-fig09-prueba-caido-1 is unhealthy`, code `1`, in eleven seconds according to the script itself (`tardó 11 s`). `--wait` waits for **all** services with a health check, and `prueba-caido` is never going to be healthy; as soon as Docker marks it `unhealthy`, `--wait` gives up. And naming only the `revisor` (`up --wait revisor`) gives the same error: to start the `revisor`, Compose starts its dependencies, and waits for them too.

Notice the `ps` afterwards: the system was left **up** and running, with the `revisor` `(healthy)`. `--wait` undid nothing; it only reported with a non-zero code that not everything is healthy. In a real system that is exactly what you want to know. In this one, where a service is down on purpose, the course uses `up -d` and then waits for the **`revisor`**'s health with `docker inspect`, which is what the scripts' `esperar` function does. Block 4 demonstrates it, and the table comes out complete.

### 9.12 The life cycle: changing, shutting down, keeping

The script `fig09_08.sh` starts the final system, asks for a report so that there is something stored, and then goes through what you will do every day. The part that changes:

```bash
cp compose.yaml compose.final.yaml
docker compose up -d --build >/dev/null 2>&1
esperar revisor healthy
curl -s -o /dev/null -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados"

echo "== 1. Cambiar un servicio: prueba-caido pasa a modo sano"
sed -i '/^  prueba-caido:/,/^[a-z]/s/PRUEBA_MODO: caido/PRUEBA_MODO: sano/' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy'"
esperar prueba-caido healthy
muestra "tabla"
cp compose.final.yaml compose.yaml
docker compose up -d >/dev/null 2>&1

echo
echo "== 2. down sin --volumes: el reporte sigue ahí, en su volumen"
muestra "docker compose down 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker run --rm -v ${COMPOSE_PROJECT_NAME}_reportes:/datos:ro alpine:3.24.2 ls -ln /datos | sed -E 's/[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{5}/<fecha>/'"
docker compose up -d >/dev/null 2>&1
esperar revisor healthy

echo
echo "== 3. Apagado ordenado"
inicio=$(date +%s%3N); docker compose stop revisor >/dev/null 2>&1; fin=$(date +%s%3N)
echo "docker compose stop revisor tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
muestra "docker compose logs --no-log-prefix revisor | tail -2"

echo
echo "== 4. down --volumes: ahora sí, también el reporte"
muestra "docker compose down --volumes 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}' | wc -l"
```

```text
$ ./fig09_08.sh
== 1. Cambiar un servicio: prueba-caido pasa a modo sano
$ diff compose.final.yaml compose.yaml
79c79
<       PRUEBA_MODO: caido
---
>       PRUEBA_MODO: sano
[código de salida: 1]
$ docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy'
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-prueba-caido-1 Recreate
Container curso-docker-fig09-prueba-caido-1 Recreated
Container curso-docker-fig09-revisor-1 Running
Container curso-docker-fig09-prueba-caido-1 Started
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     OK            <t>  200
lento     LENTO     <t>  200
sano      OK            <t>  200

== 2. down sin --volumes: el reporte sigue ahí, en su volumen
$ docker compose down 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'
Network curso-docker-fig09_interna Removed
Network curso-docker-fig09_publica Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
$ docker run --rm -v curso-docker-fig09_reportes:/datos:ro alpine:3.24.2 ls -ln /datos | sed -E 's/[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{5}/<fecha>/'
total 4
-rw-------    1 65532    65532          269 <fecha> reporte.json

== 3. Apagado ordenado
docker compose stop revisor tardó 203 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
ExitCode=0
$ docker compose logs --no-log-prefix revisor | tail -2
revisor: recibí terminated, apagando
revisor: apagado limpio

== 4. down --volumes: ahora sí, también el reporte
$ docker compose down --volumes 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'
Volume curso-docker-fig09_reportes Removed
Network curso-docker-fig09_publica Removed
Network curso-docker-fig09_interna Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}' | wc -l
0
```

1. **Changing a service.** The file switches `prueba-caido` to healthy mode and `up -d` is requested. Compose leaves three containers at `Running` and **recreates only `prueba-caido`**. Not even the `revisor`, which depends on it, is touched: its configuration did not change, and its `depends_on` does not ask to restart when a dependency changes (the `restart: true` option exists inside `depends_on` for that; the documentation describes it for a service that must reconnect when its database is recreated, and the `revisor` does not need it because it opens a new connection on every check) ([Docker, "Control startup order"](https://docs.docker.com/compose/how-tos/startup-order/)). The next table says `caido OK 200`: the service's name is still `caido`, but now it answers healthy. It is Compose's model in one example: you describe the state you want, and the tool computes the minimum change. The script returns the file to its final form before going on.
2. **`down` without `--volumes`.** Containers and networks are deleted; the volume is still in `docker volume ls`. Lesson 8's `alpine` helper reads it read-only and there is `reporte.json`, owned by `65532`, with its `600` permissions (the `revisor` creates it like that: the report belongs to whoever writes it). When the script asks for `up -d` again, the new `revisor` mounts the same volume. It is the course's fifth goal, "the report survives", now with the complete system.
3. **Orderly shutdown.** `docker compose stop revisor` takes less than a second (in this run, 203 ms) and the `revisor` ends with `ExitCode=0`. Its logs tell it: `recibí terminated, apagando` and `apagado limpio`. `stop` uses underneath the same `SIGTERM` and the same 10 s deadline as Lesson 7's `docker stop`; `init: true` and the `revisor`'s handler do the rest.
4. **`down --volumes`.** Now the volume does go, and the report with it. Use it when you really want to start from scratch, knowing it has no recycle bin.

### 9.13 And `docker init`?

The course plan asked to compare your file with the one `docker init` generates, a command that creates a `Dockerfile`, a `.dockerignore`, a `compose.yaml` and a `README.Docker.md` from a per-language template (Go, Python, Node, Java, Rust and others) ([`docker init` reference](https://docs.docker.com/reference/cli/docker/init/)). The first sentence of that same page is the one that matters here: "Docker Desktop provides the `docker init` command". It is not part of Docker Engine, which is what you installed on your Mint in Lesson 1. The script `fig09_09.sh` checks it (it creates nothing, so it does not need the other scripts' startup):

```bash
#!/usr/bin/env bash
# fig09_09.sh — docker init es una función de Docker Desktop: en Docker Engine,
# el que instalaste en la Lección 1, el comando no existe. No crea nada.
set -uo pipefail
echo "\$ docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'"
docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'
echo "\$ docker compose version"
docker compose version
echo "\$ docker init"
docker init 2>&1
echo "[código de salida: $?]"
```

```text
$ ./fig09_09.sh
$ docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'
Cliente: 29.2.1  Daemon: 29.2.1
$ docker compose version
Docker Compose version v5.0.2
$ docker init
docker: unknown command: docker init

Run 'docker --help' for more information
[código de salida: 1]
```

So the course does not depend on it, and the comparison is made with what the official documentation shows. Docker's guide to containerizing a Python application starts with this single-service `compose.yaml` (here without its header comments) ([Docker, "Containerize a Python application"](https://docs.docker.com/guides/python/containerize/)):

```yaml
services:
  server:
    build:
      context: .
    ports:
      - 8000:8000
```

It is a good starting point, and a very different file from yours. Exercise 4 asks you to find the differences, one by one, and say which lesson of the course explains each. A generator saves you from writing; it does not save you from understanding what it wrote. If someday you use `docker init` on a machine with Docker Desktop, read its `compose.yaml` with `docker compose config` and run it through this lesson's security-habit list before using it.

### 9.14 What you will find in old tutorials

- **`docker-compose`, with a hyphen.** It is Compose "V1", a separate program written in Python. Docker declares it retired: "Compose v1 is no longer maintained, and users should migrate to Compose v2" ([Docker, "Retired features"](https://docs.docker.com/retired/)). Today it is `docker compose`, with a space. If a tutorial says `docker-compose up`, translate it.
- **Container names with an underscore**, like `project_web_1`. Those were V1's. The Compose V2 announcement puts it like this: container names "now use dashes as separators instead of underscores", and if a script depends on those names, it will break; that is why it recommends, in general, not depending on container names ([Docker, "Announcing Compose V2 General Availability"](https://www.docker.com/blog/announcing-compose-v2-general-availability/)). If an old script looks for `curso-docker_revisor_1` (the name that the `curso-docker-revisor-1` of this lesson would have had in V1), it will not find it.
- **`version: "3.8"`** (or `"2"`, or `"3"`) at the start of the file. Obsolete; it only produces a warning (9.2.3).
- **`docker-compose.yml`** as a file name. It is still accepted for compatibility, but the preferred one is `compose.yaml`.
- **`links:`** inside a service. It is Lesson 8's `--link` in the form of a key; on a project's networks, services already find each other by name.
- **The token in `environment:`**, or in a `.env` file used to fill `environment`. It works, and it is what Lesson 6 taught you not to do: it ends up in `docker inspect`. That is what `secrets` exist for.

## The error you will see

This lesson has three main errors. All have already appeared, and each one is told apart by where you see it.

**In the report: `read-only file system` on `/datos`.**

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

The container is `healthy` and the report fails. It reads from right to left, like those in Lessons 7 and 8: `read-only file system` is said by the kernel; `/datos/.reporte-<n>.tmp` says the problem is the `/datos` folder; and the `500` is set by the `revisor`, which does not pretend. The question that solves it is: "what is mounted on `/datos`?". The answer is given by `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' <container>`. If `/datos` does not appear, the service is missing the volume. Fix: `volumes: [reportes:/datos]` in the service and `reportes: {}` at the top, and `docker compose up -d` (it recreates only the `revisor`). What is not a fix: `read_only: false`.

**In the logs: `permission denied` on `/run/secrets/`.**

```text
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
```

And in `docker compose ps`, a `revisor` that says `Restarting`. The `Started` in `up`'s output will not warn you: the process did start, and died afterwards. It is diagnosed with `docker compose logs revisor` and `ls -l secretos/`. If the file is at `600`, the container's user `65532` cannot read it, and `uid`, `gid` and `mode` in the `compose.yaml` do not change that, because with a file secret Compose ignores them. Fix: make the file's group `65532` and the permission `640` (`sudo chgrp +65532 secretos/revisor_token.txt` and `chmod 640 secretos/revisor_token.txt`), or make the owner `65532` with `600`, and `docker compose up -d --force-recreate revisor`. `chmod 644` also fixes it, but it opens the token to the whole machine: only with a fake token (9.8.4).

**On the command: a `--wait` that does not end well.**

```text
container curso-docker-fig09-prueba-caido-1 is unhealthy
```

(In your folder, `curso-docker-prueba-caido-1`.) Code `1`, even if you name only the `revisor`. It is not a failure of the system: it is `--wait` also waiting for a service that cannot be healthy. In this project, `up -d` and wait for the `revisor`'s health. In a project with no services that fail on purpose, that message is an alarm: it tells you exactly which container to check.

**And a secondary one, when building**:

```text
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
```

(In your folder the tag will be yours, `curso-docker-prueba:1.0.0`, and the service can be any of the three.) Several services with `build` and the same `image`. It appears sometimes, not always: in 9.11's run, in 3 of 5 attempts. Fix: `build` in a single service, `pull_policy: never` in the others.

## The security habit of the lesson

**The `compose.yaml` is born with everything that came before, and its secrets live outside the file.** It is the habit the course README assigns to this lesson, and it is checked with a list you can run any `compose.yaml` through, yours or someone else's, by reading its `docker compose config`:

- Each published port carries `host_ip: 127.0.0.1` (Lesson 2), and what does not need a port does not publish one.
- Each service carries `read_only: true`, `cap_drop: [ALL]`, `no-new-privileges` and `init: true` (Lesson 7), and memory, CPU and process limits (Lesson 2).
- Images carry a version, never `latest` (Lesson 3), and the ones you build yourself are not looked up on the internet (`pull_policy: never`).
- What writes, writes to a named volume mounted exactly where it is needed (Lesson 8).
- What does not need the internet lives on an `internal: true` network, and there is no `network_mode: host` (Lesson 8).
- No secret value in `environment`, in `build.args` or in the file itself: secrets go in `secrets:`, from files that are not pushed to the repository, and a `grep` for the value in `docker compose config` and in `docker inspect` gives zero (Lesson 6 and this one).

The accident it prevents is the scene's: that the system that runs is not the one you tested. A file hardened once is hardened for everyone who uses it; six hardened commands depend on nobody copying the wrong one.

## Common mistakes

**Writing `version:` at the top of the file.** It is obsolete and only produces a warning. And it almost always gives away that the rest of the file was copied from an old tutorial: review it more carefully.

**Ports without `127.0.0.1`.** `"8080:8080"` in a `compose.yaml` is Lesson 2's `-p 8080:8080`: the port open to your whole network. It is the first thing lost when copying an example.

**Removing `read_only` "because it fails".** If it fails, the program writes somewhere you did not foresee. Find where (the error tells you) and mount a volume or a `tmpfs` there.

**`depends_on` without a condition for something that must be ready.** The short form only waits for the container to run. If your service needs another one healthy, `condition: service_healthy`, and that other one must have its health check.

**`service_healthy` for everything.** With a service that is never going to be healthy, the one that depends on it never starts. Ask for health only from what needs it.

**The token in `environment:` or in a `.env`.** It ends up in `docker inspect` for anyone in the `docker` group. That is what `secrets:` is for.

**Trusting `uid`, `gid` and `mode` of a file secret.** Compose silently ignores them. The permission is that of the file on your machine.

**`build` in several services with the same `image`.** A race that is won "almost always" by the other side. Build in one and use the image in the others.

**`docker compose down --volumes` out of habit.** It deletes the report. Use it when you want to start from scratch, not to shut down.

**Deleting by hand with `docker rm` what Compose created.** It works, but Compose no longer knows where everything stands. What is created with Compose is shut down with `docker compose stop` or `docker compose down`.

**Two projects with the same name.** Two `compose.yaml` with `name: curso-docker`, even if in different folders, trample each other: Compose thinks the containers of one belong to the other. One project, one name.

## Exercises

Do them in order. Before running each one, write in your [logbook](bitacora.md) what you think is going to happen; comparing it afterwards is half of the learning. When you finish, leave your project with the final file and shut it down with `docker compose down` (without `--volumes`, if you want to keep the report).

### Exercise 1 — Translate a `docker run`

This is the test service's command from Lesson 8, section 8.10.3:

```text
docker run -d --name curso-docker-prueba --network curso-docker-interna \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Write the equivalent Compose service, called `prueba`, without looking at `fig09_01.compose.yaml`. Then say: which option of the command has **no** key in your service, and why? What would have to exist in the file, outside the service, for your `networks` to work?

### Exercise 2 — What does Compose recreate?

With the final system up, predict, for each change separately, which containers will say `Running` and which `Recreated` on the next `docker compose up -d`. Then check it and return the file to its final form before the next one:

1. You change the `lento` time in `REVISOR_SERVICIOS` from `5s` to `4s`.
2. You change `mem_limit: 32m` to `mem_limit: 24m` in the `x-prueba` anchor.
3. You do not change the file, but you run `chmod 600 secretos/revisor_token.txt`.

Extra question: in case 3, what would you have to do to see the error from 9.10, and which command undoes it?

### Exercise 3 — Diagnose without running

A teammate sends you this, copied from her terminal (it is the "Exercise 3" block of `fig09_10.sh`, so the names are the support ones and the temporary file's number is masked). The `revisor` says `healthy` and yet its report does not work:

```text
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

1. Are the `(unhealthy)` of `prueba-caido` and `prueba-lento` the problem? Why?
2. Which lines is her `compose.yaml` surely missing? With which command would you check it without opening the file?
3. What tells you that the token **is** fine?

### Exercise 4 — Your file against the guide's

Take the `compose.yaml` from the official Python guide in section 9.13 and make a list of **everything** that your final file has and that one does not, applied to the `server` service. For each difference, say which lesson of the course explains it and which risk it closes. Then answer: is there anything in the guide's file that you would **not** have to change?

## Solutions

The solutions that say "measured" come from the script `fig09_10.sh`, which makes each change in plain view with `sed`, checks it and undoes it. Its full output:

```text
$ ./fig09_10.sh
== Ejercicio 1. Un servicio en una red que no está declarada arriba
$ docker compose config --quiet
service "prueba-lento" refers to undefined network otra: invalid compose project
[código de salida: 1]

== Ejercicio 2.1. lento: de 5s a 4s en REVISOR_SERVICIOS
$ cambios
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-caido-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-revisor-1 Recreated
Container curso-docker-fig09-revisor-1 Started

== Ejercicio 2.2. mem_limit: de 32m a 24m en el ancla x-prueba
$ docker compose config | grep mem_limit
    mem_limit: "25165824"
    mem_limit: "25165824"
    mem_limit: "25165824"
    mem_limit: "67108864"
  mem_limit: 24m
$ cambios
Container curso-docker-fig09-prueba-caido-1 Recreated
Container curso-docker-fig09-prueba-sano-1 Recreated
Container curso-docker-fig09-prueba-lento-1 Recreated
Container curso-docker-fig09-revisor-1 Running
Container curso-docker-fig09-prueba-sano-1 Started
Container curso-docker-fig09-prueba-lento-1 Started
Container curso-docker-fig09-prueba-caido-1 Started

== Ejercicio 2.3. Sin cambiar el archivo: chmod 600 al token
$ cambios
Container curso-docker-fig09-prueba-caido-1 Running
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-revisor-1 Running
$ tabla | head -2
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
$ docker compose restart revisor 2>&1 | eventos | grep -v Restarting
Container curso-docker-fig09-revisor-1 Started
$ docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
Status=restarting ExitCode=1
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 Started'
Container curso-docker-fig09-revisor-1 Started
revisor: healthy

== Ejercicio 3. El revisor sin volumen en /datos, con los cuatro servicios
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
$ docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes
[código de salida: 1]
$ docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-fig09-revisor-1
/run/secrets/revisor_token 
```

### Solution 1

```yaml
  prueba:
    image: curso-docker-prueba:1.0.0
    networks:
      - interna
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50
```

It is the service from `fig09_01.compose.yaml`, except for the `build` (which Lesson 8's command did not carry, because the image already existed). The option with no key is `--name curso-docker-prueba`: the container's name is set by Compose (`curso-docker-prueba-1` in your folder), and the others find it by the **service**'s name, `prueba`. `-d` has no key either: it is an option of the command (`docker compose up -d`), not of the service. For `networks: [interna]` to work, the network has to be declared at the top, in `networks:`; if not, the file is not valid. And for it to remain Lesson 8's network with no way out, that declaration carries `internal: true`. Measured: with the anchor pointing to a network `otra` that is not declared at the top, `docker compose config --quiet` answers `service "prueba-lento" refers to undefined network otra: invalid compose project` and exits with `1` (it names one of the three copies that inherit the anchor; it may be another in your run). It is the kind of error `config` catches before creating anything.

### Solution 2

Measured ("Exercise 2" blocks of `fig09_10.sh`):

1. **Only the `revisor` is recreated.** `REVISOR_SERVICIOS` is part of its configuration; the test services do not change and say `Running`. It is the same as you saw in block 2 of `fig09_03.sh`, with another change.
2. **The three copies of the test service are recreated**, and the `revisor` stays at `Running`. For Compose, what counts is the result of copying the anchor into the three services, so changing the anchor is changing all three. `docker compose config | grep mem_limit` confirms it before starting: three times `25165824` (24 MB in bytes) and one `67108864` (the `revisor`). The last line, `mem_limit: 24m` without quotes and with less indentation, is `x-prueba` itself: `config` keeps the `x-` fields in its output, even though it does not use them to create anything.
3. **Nothing is recreated**: all four at `Running`, and the table keeps coming out. A permission on a file on your machine is not part of the configuration Compose compares, and the `revisor` already read its token on startup, so it keeps working. To see the error from 9.10 you have to force it to start again: `docker compose restart revisor` says `Started`, and three seconds later `docker inspect` says `Status=restarting ExitCode=1`. You undo it by restoring the previous permission (in the script's temporary folder, `644` with the fake token; in yours, the `640` with group `65532` from 9.8.4) followed by `docker compose up -d --force-recreate revisor`, the same command as in 9.10. The lesson of this case: a permissions error can lie **dormant** for days, until the next restart.

### Solution 3

1. **No.** They are `unhealthy` because they fail on purpose: the down one answers `503` and the slow one takes 3 s when its check demands less than 2. It is what is expected, and that is why the `revisor` only asks `service_healthy` of the healthy one. The `revisor` is `healthy` because `/salud` writes nothing.
2. It is missing the `revisor`'s volume at `/datos`: the two lines `volumes:` and `- reportes:/datos` of the service. It is block 1 of `fig09_03.sh`. You check it without opening the file with `docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes`, which finds nothing and exits with `1`; or, on the container, with `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-revisor-1`, which shows `/run/secrets/revisor_token` and does not show `/datos`. Both things are in `fig09_10.sh`'s output.
3. That the answer is **not** `401`. With the wrong or missing token, the `revisor` answers `{"error":"falta el token o no es válido"}` before trying anything. Here it passed that check and failed when saving. And if the token's file were at `600`, the `revisor` would not even be `Up`: it would be restarting (9.10).

### Solution 4

What your file has and the guide's does not, in the service:

- **`127.0.0.1` on the port** (Lesson 2). `8000:8000` publishes on all your machine's interfaces; anyone on your network reaches the service.
- **`image:` with a name and a version** (Lesson 3). Without it, the image's name is decided by Compose and does not say which version is running.
- **`read_only`, `cap_drop`, `no-new-privileges` and `init`** (Lesson 7). Without them, whoever takes control of the process can write to the container's disk, use the `root` capabilities Docker leaves by default and gain privileges with a *setuid* program; and a program that does not know how to be process 1 does not shut down properly.
- **Memory, CPU and process limits** (Lesson 2). Without them, a bug in the program can take the whole machine.
- **`restart`** (Lesson 7). Without a policy, if the process dies it stays dead.
- **Networks of its own, with the internal one with no way out** (Lesson 8). The guide uses the project's default network, with internet access for everyone.
- **A named volume where it writes** (Lesson 8). In that example it is not needed because the application stores nothing; the day it does, it will need it.
- **`secrets:`** (Lesson 6 and this one). The guide the example comes from later adds a database with its password as a secret: the pattern is the same.

What you would not change: `build` with `context: .`, which is exactly what your `revisor` does, and the absence of `version:`. And a fair clarification: the final stage of that guide's Dockerfile runs without `root` by default, as the page itself says, so Lesson 3's `USER` is solved in its Dockerfile, not in the `compose.yaml`. A generated file is not bad: it is a starting point, and your job is to take it up to here.

## How I know I got it

Check each point only if you can do it **without looking at the text again**:

- [ ] In your `revisor/` folder, `docker compose config --quiet && echo 'compose.yaml válido'` prints `compose.yaml válido`, and `grep -c '^version' compose.yaml` gives `0`.
- [ ] `docker compose up -d --build` starts the four services from scratch, `docker compose ps` shows `curso-docker-revisor-1` as `(healthy)` with `127.0.0.1:8080->8080/tcp`, and in `up`'s events `prueba-sano-1 Healthy` appears **before** `revisor-1 Started`.
- [ ] The `revisor`'s table, requested with the token, shows `caido FALLA`, `lento LENTO` and `sano OK`, without you having changed any mode by hand.
- [ ] `docker inspect curso-docker-revisor-1 | grep -c "$(cat secretos/revisor_token.txt)"` gives `0`, and the same with `docker compose config`.
- [ ] You explain why the `revisor` waits with `service_healthy` only for `prueba-sano`, using the words *health*, *503* and *2 seconds*.
- [ ] You trigger the `read-only file system` by removing the `/datos` volume, and the secret's `permission denied` with `chmod 600`, and you explain why `uid`, `gid` and `mode` do not prevent it.
- [ ] With `stat -c '%a %U:%G'` and `sudo -u nobody cat` you check that your `secretos/revisor_token.txt` is **not** readable by another account, and that the `revisor` can read it (`640` with group `65532`, or `600` with owner `65532`); and `git check-ignore -v secretos/revisor_token.txt` says your project's `.gitignore` covers it.
- [ ] After `docker compose down` (without `--volumes`), `docker run --rm -v curso-docker_reportes:/datos:ro alpine:3.24.2 ls -ln /datos` shows `reporte.json` owned by `65532`.
- [ ] `docker compose stop revisor` takes less than a second and leaves `ExitCode=0`.
- [ ] You run the scripts in [`programas/09-compose/`](../programas/09-compose) (with your project shut down, or with another port: `PUERTO=18080 ./fig09_05.sh`; the `nombres` function rewrites the port in the output) and your outputs match those in this lesson, except for the times, the dates, the temporary file's number, the order of simultaneous events, the service that Exercise 1's error names and the attempts and services of 9.11's clash. And when you finish, `docker ps -a --filter name=fig09`, `docker volume ls --filter name=fig09` and `docker network ls --filter name=fig09` show nothing.

## Summary

Answer without looking at the lesson:

1. What is the difference between a service and a container, and what name do the other containers use to find one?
2. Where does a project's name come from, in what order is it decided, and how does it show in the names of containers, networks and volumes?
3. What does `docker compose config` do, and what did it teach you about `depends_on: [prueba]` and about `"127.0.0.1:8080:8080"`?
4. Why does asking for `docker compose up -d` twice do nothing the second time, and what does it do when you change a service?
5. Why does the `revisor` with `read_only: true` always need something mounted on `/datos`?
6. What are an `x-` field and a YAML anchor used for together?
7. What is the difference between `service_started` and `service_healthy`, and why can `service_healthy` not be asked of `prueba-caido`?
8. Where does a Compose secret appear inside the container, and why does a file at `600` give `permission denied` even if you declare `uid`, `gid` and `mode`? Who can read the same file at `644`, and how do you leave it so that the `revisor` and you can read it, but nobody else?
9. Why does only one test service carry `build`, and what does `pull_policy: never` do in the other two?
10. What does `docker compose down` delete, what does `--volumes` add, and why does `up --wait` fail in this project even though everything works?

## Sources

All consulted on October 21, 2026.

- [Docker, "Docker Compose"](https://docs.docker.com/compose/): what Compose is.
- [Docker, "How Compose works"](https://docs.docker.com/compose/intro/compose-application-model/): the `compose.yaml` name (preferred) and the legacy names; what a project is; services, networks, volumes, configs and secrets.
- [Compose specification](https://docs.docker.com/reference/compose-file/): the document that defines the file's keys and its top-level elements.
- [Specification, `version` and `name`](https://docs.docker.com/reference/compose-file/version-and-name/): that `version` is informative only and produces an obsolescence warning; `name` as the project name.
- [Compose services reference](https://docs.docker.com/reference/compose-file/services/): `depends_on` and its three conditions; `pull_policy: never`; `read_only`, `cap_drop`, `security_opt` and the three forms of `no-new-privileges`; `init`; `mem_limit`, `cpus`, `pids_limit`; `restart`; `image` alongside `build`; the long form of `secrets` and that with a file as the source `uid`, `gid` and `mode` are silently ignored.
- [Specification, extensions](https://docs.docker.com/reference/compose-file/extension/): that Compose ignores fields that start with `x-` and that they serve to reuse configuration.
- [Specification, fragments](https://docs.docker.com/reference/compose-file/fragments/): anchors, aliases and the `<<` merge key; that the merge only applies to mappings; `environment` as a map when using fragments.
- [Docker, "Specify a project name"](https://docs.docker.com/compose/how-tos/project-name/): the order in which the project name is decided, the characters it admits and that it is used to isolate environments.
- [Docker, "Networking in Compose"](https://docs.docker.com/compose/how-tos/networking/): the `<project>_default` network, the service name in DNS and custom networks with `networks`.
- [Docker, "Control startup order"](https://docs.docker.com/compose/how-tos/startup-order/): that Compose does not wait for a container to be ready, only running; `service_healthy`; the dependency-based deletion order; `restart: true` inside `depends_on`.
- [Docker, "Secrets in Compose"](https://docs.docker.com/compose/how-tos/use-secrets/): what a secret is, the `/run/secrets/<name>` path, that Docker creates a mount (`bind mount`) at that path, that access is controlled with the filesystem's normal permissions and that only the service it is granted to receives it.
- [Specification, top-level `secrets`](https://docs.docker.com/reference/compose-file/secrets/): that the secret is created with the contents of the `file` file (or with an `environment` variable).
- [`docker compose config` reference](https://docs.docker.com/reference/cli/docker/compose/config/): that it shows the model to be applied, in canonical form; `--quiet`, `--services`, `--volumes`.
- [`docker compose up` reference](https://docs.docker.com/reference/cli/docker/compose/up/): what `up` does; that it recreates on a configuration or image change and keeps the volumes; `-d`, `--build`, `--wait`, `--wait-timeout`, `--no-recreate`.
- [`docker compose down` reference](https://docs.docker.com/reference/cli/docker/compose/down/): what it deletes by default and what `--volumes` adds.
- [`docker init` reference](https://docs.docker.com/reference/cli/docker/init/): that Docker Desktop provides it, the files it creates and its templates.
- [Docker, "Containerize a Python application"](https://docs.docker.com/guides/python/containerize/): the single-service `compose.yaml` used in 9.13 and Exercise 4.
- [Docker, "Retired features"](https://docs.docker.com/retired/): that Compose v1 is no longer maintained and you should migrate to Compose v2.
- [Docker, "Announcing Compose V2 General Availability"](https://www.docker.com/blog/announcing-compose-v2-general-availability/): the change from underscore to dash in container names and the warning not to depend on them.
- [Specification, `models`](https://docs.docker.com/reference/compose-file/models/): the top-level element for AI models, mentioned in 9.1.1.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions and dates in "About the runs".
- [Colima](https://github.com/abiosoft/colima): the tool used to run the programs on macOS.

### Terms in this lesson

| | |
|---|---|
| **anchor and alias** (YAML) | `&name` marks a block; `*name` refers to it; `<<: *name` copies its keys into another map |
| **folded block** (YAML) | `>-`: joins several lines into one, with spaces, and removes the final newline |
| **`x-` field** | a top-level field that Compose ignores; used to store reusable blocks |
| **Compose** | the tool (`docker compose`) that reads a `compose.yaml` and creates, recreates or deletes what is needed so that what it describes exists |
| **`depends_on`** | startup order between services, with a condition: `service_started`, `service_healthy` or `service_completed_successfully` |
| **canonical form** | the long, complete version of the file, with all default values written out; shown by `docker compose config` |
| **project** | one deployment of a `compose.yaml`; its name goes in front of everything Compose creates |
| **Compose secret** | a file that Compose mounts read-only at `/run/secrets/<name>`, only in the services that ask for it |
| **service** | the recipe for a container in the `compose.yaml`; its name is the one used in the project's DNS |

---

**Next:** [Lesson 10 — Delivering the image](10-entregar-la-imagen.md)
