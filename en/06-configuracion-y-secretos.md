# Lesson 6 — Configuration and secrets

It is Thursday, 6:40 in the evening, and the team wants to release the `revisor` at seven. One detail is missing: the test environment needs a different list of services and a different token. Someone proposes the quick route: "I'll change the token in the Dockerfile, rebuild, and push it; five minutes." They do it, and the image goes up to the shared registry. At 6:52, a colleague from another team asks in the chat, as innocently as can be, why the `revisor` image carries a `REVISOR_TOKEN` variable with a value that looks like a password. They did not have to log into any server or break anything: a `docker inspect` on an image they were allowed to download was enough. Now the token has to be written off, a new one generated, and someone has to find out who else pulled the image. The seven o'clock release is not happening. This lesson exists so that conversation never takes place: the image carries neither an environment's configuration nor its secrets, and you are going to verify with your own eyes what stays inside it.

**Time:** 90 min

**What you build:** the `revisor` configured without rebuilding. The image `curso-docker-revisor:1.3.0` has its version stamped into it, which is not secret, and nothing else from any environment. The list of services arrives when the container runs, through environment variables or an env file. The access token arrives as a read-only file, never as a variable. And the pattern for using a secret **while building** is ready in the Dockerfile without leaving a trace in the image.

**What you learn:** what configuration is and what a secret is; `ARG` versus `ENV` (when each exists and where it ends up); `-e` and `--env-file`; OCI labels with the version; build secrets with `--mount=type=secret` and `--secret`; runtime secrets via file and why not via variable; and, above all, to **look** with `docker history` and `docker inspect` at what travels inside an image.

**Where you are coming from.** From [Lesson 5](05-multi-stage.md), where the `revisor` ended up in a four-stage image, `curso-docker-revisor:1.2.0`, at 16.1 MB, with no *shell*, no compiler, and user `65532`. That image has a gap you may have noticed: its `version` subcommand says `desarrollo`, because nobody told it which version it is. From [Lesson 3](03-primer-dockerfile.md) you also bring the `.dockerignore` that leaves out `.env` and `secretos/`, and from [Lesson 2](02-contenedores-dia-a-dia.md) the habit of publishing ports only on `127.0.0.1`. And from Lesson 3, the error of starting the `revisor` without `REVISOR_SERVICIOS`: today you are going to see why that variable does not go in the Dockerfile.

**What this lesson does not do.** It does not explain mounts in depth: the token arrives with a single-file `--mount type=bind`, and for now it is enough to know that it puts a file from your machine inside the container. [Lesson 8](08-volumenes-y-redes.md) explains mounts in full. Nor does it use Compose secrets, which are the convenient way to do the same thing and arrive in [Lesson 9](09-compose.md). It does not teach external secret managers (vaults, cloud services): this course works on your machine, and what you learn here is the part those managers also need, namely that the secret arrives as a file and does not stay in the image. And you do not need private Go modules: the `revisor` does not use them, and the build secret is taught with a fake value.

**About the runs.** All outputs are real and were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4, the same base as Linux Mint 22, the course's reference system. The scripts were run **inside** that virtual machine, with Docker 29.2.1 (client and daemon) and Buildx v0.31.1, and with their working folder on Linux's own disk. That last point matters in this lesson: folders shared between the Mac and the virtual machine lie about permissions (a file with permissions `600` can be read just the same from a container running as another user), and section 6.5 is precisely about permissions. On your Mint that problem does not exist. To avoid collisions with other runs that were using the same machine, the scripts were launched with a different name prefix and different ports (the `PREFIJO` and `PUERTO` variables they include); no container name, image name, or host port appears in their outputs, so what you see is exactly what they printed. With their default values, the scripts use auxiliary names of their own that include `fig06` (the image `curso-docker-revisor:fig06`, the container `curso-docker-revisor-fig06`): that way they never touch your image `curso-docker-revisor:1.3.0` or your container `curso-docker-revisor`, and on exit they delete only what they created. The course was planned with Docker Engine 29.8.2, and the most recent version published that day was 29.9.2, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)); nothing in this lesson changes between those versions. What **does** change from one run to another, and is flagged where it appears: the times in the `revisor`'s table (masked with `<t>` in the script itself), the times and date in the build lines, and the word `arm64` in the image history, which on an Intel or AMD machine says `amd64`. The programs are in [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos), each with its output next to it, and `estado/` holds the project files as they stand at the end.

## By the end you will be able to

- Classify a piece of the `revisor`'s data as code, configuration, or secret, and say where each one should live.
- Explain the difference between `ARG` and `ENV` by saying when each one exists and where it gets written, and verify it with `docker history` and `docker image inspect`.
- Run the same image with two different configurations, with `-e` and with `--env-file`, without rebuilding.
- Find a secret left in an image by `ARG` or by `ENV`, and read the `SecretsUsedInArgOrEnv` warning from `docker build --check`.
- Deliver the `revisor`'s token as a read-only file, and fix the `permission denied` error that shows up when doing so.
- Use a secret during the build with `--secret` and show that it did not stay in the image.

## The why before the how

Up to Lesson 5, everything the `revisor` needed to run came from the image or from a couple of `-e` flags typed on the fly. It worked because there was only one environment: your machine. As soon as a second environment appears (testing, production, a teammate's computer), this lesson's question appears: **what changes between one environment and another, and where is it written?**

The classic answer comes from a widely cited guide, *The Twelve-Factor App*, which defines an app's config as "everything that is likely to vary between deploys" ([12factor.net, "Config"](https://12factor.net/config)). In the `revisor` that means the list of services it checks, the port, the report path, and the token. What does **not** vary is the code and the version: `1.3.0` is `1.3.0` everywhere. The same guide proposes a simple test to know whether you separated things properly: could you open-source your code at any moment without compromising any credentials? This course is open, so the test is not hypothetical: the `revisor`'s Dockerfile is published, and that is why it cannot carry anything you would not want the world to read.

With images, the question has one more twist. An image is not just a file that runs; it is a package that **travels**: it is pushed to a registry, pulled onto other machines, stored in caches, copied to a cluster. Everything you put into it is received by anyone who can pull it. And an image stores more than it seems: in addition to the files in its layers, it stores its **configuration** (the environment, the user, the labels) and its **history** (the instruction that created each layer, with the values it had). Docker's documentation says it bluntly: build arguments and environment variables "are inappropriate for passing secrets to your build", because "they persist in the final image" ([Docker, "Build secrets"](https://docs.docker.com/build/building/secrets/)).

So this lesson does three things, in this order:

1. **Get configuration out of the image** (6.1 to 6.3): the image carries its version and default values that are not secret; everything else arrives at run time.
2. **See with your own eyes what happens when a secret gets into the image** (6.4): you are going to put one in on purpose, with fake values, and find it.
3. **Do it right** (6.5 and 6.6): the runtime secret as a read-only file, and the build secret as a mount that lasts as long as a `RUN`.

With that destination in mind, this is what you will see in section 6.4, when searching inside a badly made image. The fake value is right there, in the history, even though the `RUN` itself deleted the file that held it:

```text
== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

## The concepts

### 6.1 Code, configuration, and secret: three different things

#### 6.1.1 Classifying what the `revisor` needs

Before writing a single line, it is worth giving each piece of data a name. There are three boxes:

| Box | What it is | In the `revisor` | Where it lives |
|---|---|---|---|
| **Code** | what the program does; the same in every environment | the binary, compiled at version `1.3.0` | inside the image |
| **Configuration** | what changes from one environment to another and is not secret | `REVISOR_SERVICIOS`, `REVISOR_PUERTO`, `REVISOR_REPORTE` | outside the image; arrives at run time |
| **Secret** | configuration that, if it leaks, someone can use against you | the token for `/api/estados`; a credential to download private modules | outside the image **and** outside environment variables; arrives as a file |

Two items deserve comment. The **port** is configuration, but it has a reasonable default value (`8080`) that is not secret, which is why the image declares it with `ENV`: it serves as documentation and as a default, and any environment can change it. The **version** is not configuration: it does not change between environments, it describes the code. That is why it is stamped in at build time and not requested at run time.

The secret has its own box because it meets both conditions: it changes between environments (the test token is not the production one) and its value cannot be left in plain view. That second condition is what rules out environment variables, as you will see in 6.5.

#### 6.1.2 This course's secrets are fake, and they say so

All the secrets that appear in this lesson are **made up for the exercise** and announce it in their own value: `curso-docker-token-de-mentira-7f3a9c`, `curso-docker-modulos-de-mentira-41be`. They open nothing. They live in the project's `secretos/` folder, which the course publishes on purpose so that you can run everything. In a real project that folder is **never** published: it goes in `.gitignore` and in `.dockerignore`, and its values come from wherever your team keeps credentials.

The `.dockerignore` you bring from Lessons 3 and 4 already excludes it, along with `.env` and the `Dockerfile*` files:

```text
# Lo que nunca viaja al daemon al construir.
.git
.env
*.tar
*.md
Dockerfile*
.dockerignore
compose.yaml
secretos/
```

That means no `COPY` can accidentally put a file from `secretos/` into the image: it does not even reach the daemon. It is the first barrier, and the cheapest. This lesson closes the other three: the history, the image's configuration, and the container's configuration.

### 6.2 `ARG` versus `ENV`

#### 6.2.1 Two instructions that look alike and are not alike

Both instructions define variables with a name and a value, and both are used with `${NAME}` inside the Dockerfile. What separates them is **when they exist**:

- **`ARG`** declares a **build argument**. It exists only while the image is being built, and its value can be changed from outside with `docker build --build-arg NAME=value`. Containers born from the image do not receive it. The documentation sums it up this way: build arguments "aren't accessible or present in containers" created from the image, but their values "can persist in image metadata", in provenance attestations, and **in the history** ([Docker, "Build variables"](https://docs.docker.com/build/building/variables/)).
- **`ENV`** defines an **environment variable** that exists during the build and that, in addition, the image hands to every container born from it: "environment variables set using `ENV` will persist when a container is run from the resulting image", and they can be viewed with `docker inspect` and changed with `docker run --env` ([Dockerfile reference](https://docs.docker.com/reference/dockerfile/)).

In one line: `ARG` is a value for **building**; `ENV` is a value for **running**. And neither is a hiding place: both leave their value written in the image, one in the history and the other in the configuration.

There is a scope detail that confuses everyone the first time. An `ARG` is valid **in the stage where it is declared** (and in the stages that derive from it). In a multi-stage Dockerfile, if the `final` stage also needs the value, it declares it again. That is what this lesson's Dockerfile does with `VERSION`.

#### 6.2.2 This lesson's Dockerfile

This is the Dockerfile the lesson ends with. It is Lesson 5's with four changes, each explained below:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_01.Dockerfile — Lección 6: la imagen no lleva configuración de un ambiente ni secretos.
# Lo único que se le fija al construir es su VERSIÓN, que no es secreta.

FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

FROM pruebas AS binario
# ARG existe solo mientras se construye. Aquí se usa para grabar la versión
# dentro del binario; /salud la devuelve.
ARG VERSION=desarrollo
# Un secreto de CONSTRUCCIÓN (por ejemplo, credenciales para módulos privados)
# se monta solo durante este RUN y no queda en ninguna capa. Este curso no usa
# módulos privados: el montaje es opcional (required=false) y queda como patrón.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    --mount=type=secret,id=netrc,target=/root/.netrc,required=false \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" \
      -o /out/revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
ARG VERSION=desarrollo
LABEL org.opencontainers.image.title="revisor" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://www.habil.mx/es/cursos/docker/"
# ENV solo para valores por omisión que NO son secretos.
ENV REVISOR_PUERTO=8080
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

The four changes, in the order they appear:

1. **`ARG VERSION=desarrollo` in the `binario` stage.** It declares the argument with a default value. If you build without `--build-arg`, it is `desarrollo`, which is exactly what the `revisor` said in Lesson 5; that way nothing breaks for anyone who builds without knowing about this argument.
2. **`-X main.version=${VERSION}` in `go build`.** It is a Go linker option that replaces, at compile time, the value of one of the program's string variables ([cmd/link](https://pkg.go.dev/cmd/link)). The `revisor` has a `version` variable in its `main` package that is `desarrollo` if nobody touches it. With this option, the number ends up **inside the binary**, which is the only place where it cannot be lost or contradicted.
3. **`--mount=type=secret,...,required=false`** in that same `RUN`. It is the build secret; it has its own section, 6.6. For now it is enough to know that, since it is optional, the build works the same with or without it.
4. **In the `final` stage: `ARG VERSION` again, `LABEL`, and `ENV`.** The `ARG` is repeated because each stage has its own scope (6.2.1). With it, `LABEL` attaches three **labels** to the image with names from a standard, that of the *Open Container Initiative*: `org.opencontainers.image.title` is the "human-readable title" of the image, `org.opencontainers.image.version` is the "version of the packaged software", and `org.opencontainers.image.source` is the "URL to get source code for building the image" ([OCI, pre-defined annotation keys](https://github.com/opencontainers/image-spec/blob/main/annotations.md)). Here it points to the course page, which is this material's public reference address; in your own project, put the repository's address, which is what the specification asks for. Any tool that knows how to read those labels (a registry, a scanner, Lesson 10) knows what the image is without running it. And `ENV REVISOR_PUERTO=8080` leaves the port's default value in plain view for whoever inspects the image.

Notice what is **not** there: no `REVISOR_SERVICIOS`, no `REVISOR_TOKEN`, no `REVISOR_TOKEN_ARCHIVO`. The image does not know which environment it is going to run in, and that is how it has to be.

#### 6.2.3 Building and looking at where each thing ended up

The script `fig06_02.sh` builds the image with `--build-arg VERSION=1.3.0` and then asks it, without running the server, what it contains:

```bash
#!/usr/bin/env bash
# fig06_02.sh — Construir el revisor con su versión como ARG y mirar dónde quedó.
# Construye curso-docker-revisor:1.3.0 con fig06_01.Dockerfile y pregunta a la
# imagen qué trae: la versión, las etiquetas, el entorno y el historial.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

echo "== 1. Construir, pasando la versión como argumento de construcción"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
docker image ls "$IMAGEN" --format 'tamaño: {{.Size}}'

echo
echo "== 2. La versión, grabada dentro del binario"
docker run --rm --name "${PREFIJO}revisor-fig06-version" "$IMAGEN" version

echo
echo "== 3. Las etiquetas OCI de la imagen"
docker image inspect --format '{{range $k, $v := .Config.Labels}}{{$k}} = {{$v}}{{println}}{{end}}' "$IMAGEN"

echo "== 4. El entorno que la imagen entrega a cada contenedor (ENV)"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGEN"

echo "== 5. El historial de la imagen final, de arriba (lo último) hacia abajo"
docker history --format '{{.Size}}	{{.CreatedBy}}' "$IMAGEN" | head -8
```

```text
$ ./fig06_02.sh
== 1. Construir, pasando la versión como argumento de construcción
tamaño: 16.1MB

== 2. La versión, grabada dentro del binario
1.3.0

== 3. Las etiquetas OCI de la imagen
org.opencontainers.image.source = https://www.habil.mx/es/cursos/docker/
org.opencontainers.image.title = revisor
org.opencontainers.image.version = 1.3.0

== 4. El entorno que la imagen entrega a cada contenedor (ENV)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
REVISOR_PUERTO=8080

== 5. El historial de la imagen final, de arriba (lo último) hacia abajo
0B	ENTRYPOINT ["/revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 65532:65532
6.69MB	COPY /out/revisor /revisor # buildkit
0B	ENV REVISOR_PUERTO=8080
0B	LABEL org.opencontainers.image.title=revisor…
0B	ARG VERSION=1.3.0
319kB	bazel build //common:cacerts_debian13_arm64_…
```

Five blocks, five different places where an image's information lives:

1. **The size did not change**: 16.1 MB, the same as `1.2.0`. Labels, `ENV`, and `ARG` weigh nothing: they are metadata, not files.
2. **The version is in the binary.** The `version` subcommand prints `1.3.0`. It is the same one `GET /salud` returns and the same one the `revisor` writes at startup (`revisor 1.3.0 escuchando en :8080`), as you will see in 6.5.
3. **The OCI labels** are in the image's configuration and are read with `docker image inspect`, without running anything. The template `{{range $k, $v := .Config.Labels}}` iterates over the map of labels; `docker` sorts them by name.
4. **The environment** each container will receive: two variables that come with the *distroless* base (`PATH` and `SSL_CERT_FILE`, the path to the trusted certificates) and ours, `REVISOR_PUERTO=8080`. Look carefully at what is **missing**: `VERSION`. The `ARG` did not make it into the environment. No container is going to receive it.
5. **The history**, from most recent to oldest. Each line is an instruction from the `final` stage (the other stages are not there: they are not part of the delivered image, as you saw in Lesson 5). Those that do not create files weigh `0B`. The `…` is `docker history` truncating long lines; with `--no-trunc` you see them in full. And now the line that matters for the rest of the lesson: **`ARG VERSION=1.3.0`**. The argument's value is written in the history, in plain view for anyone who has the image. For a version that is perfectly fine: it is not secret, and it even helps. For a token it would be a leak. Keep that picture in your head; in 6.4 you are going to see it with a value that should not be there.

The last line (`bazel build //common:cacerts_debian13_arm64_…`) is a layer from the *distroless* base: its authors build it with a tool called Bazel, and the history records it. On your Mint with an Intel or AMD processor it says `amd64` where it says `arm64` here.

#### 6.2.4 In your folder

The course's scripts work in temporary folders and delete what they create; your project has lived in `~/curso-docker/revisor` since Lesson 3. From the root of the course repository, put this lesson's Dockerfile and the folder of fake secrets there, and build the image you are going to keep:

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cp -R programas/06-configuracion-y-secretos/estado/secretos ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 -t curso-docker-revisor:1.3.0 .
docker run --rm curso-docker-revisor:1.3.0 version
```

The last command has to print `1.3.0`. The `.dockerignore` does not change: it already excludes `secretos/`. In `estado/` there is also `Dockerfile.malo`, the wrong recipe from 6.4. Copy it too, because "How I know I succeeded" asks you to repeat that experiment; the `.dockerignore` (which excludes `Dockerfile*`) keeps it from traveling in the context. And when you get to 6.6, rebuild your image with the build secret, to verify that it leaves no trace:

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile.malo ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt -t curso-docker-revisor:1.3.0 .
```

This lesson's scripts touch none of this: they use auxiliary names with `fig06` and delete only their own.

### 6.3 Configuring without rebuilding

#### 6.3.1 `-e` and `--env-file`

The image no longer knows which services to check. That is told to it **at run time**, and there are two ways:

- **`-e NAME=value`** (or `--env`), one per variable, on the same `docker run` line. It is what you have used since Lesson 2. If you write just `-e NAME`, without a value, Docker takes the value that variable has in your terminal and passes it along; if it does not exist in your terminal, the container does not receive it ([`docker run` reference](https://docs.docker.com/reference/cli/docker/container/run/)).
- **`--env-file file`**: a text file with one `NAME=value` per line. Lines that **begin** with `#` are comments; a `#` in the middle of a line is part of the value. A line with just `NAME`, without `=`, takes the value from your terminal, just like `-e NAME`. It is used to keep each environment's configuration in its own file (`pruebas.env`, `local.env`) and not in a three-line command nobody remembers.

The two forms can be mixed, and both win over whatever the image's `ENV` says. That is the point of a default value: to be there until someone says otherwise.

#### 6.3.2 The same image, three configurations

The script `fig06_03.sh` builds `curso-docker-revisor:1.3.0` once and runs it three times with different configurations. The first has a deliberate mistake:

```bash
#!/usr/bin/env bash
# fig06_03.sh — Configurar sin reconstruir: la MISMA imagen, tres configuraciones.
# Una variable mal escrita, una lista por -e y otra lista por --env-file.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# La tabla del revisor, con el tiempo tapado: es lo único que cambia entre corridas.
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
}

echo "== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS"
rc=0
docker run --name "$NOMBRE" -e REVISOR_SERVICIO='propio http://127.0.0.1:8080/salud' "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. La configuración por -e: un solo servicio"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla
IMAGEN_1=$(docker inspect --format '{{.Image}}' "$NOMBRE")
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Otra configuración, desde un archivo con --env-file"
cat > revisor.env <<'FIN'
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
FIN
cat revisor.env
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --env-file revisor.env "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR

echo "== 5. ¿Las dos corridas usaron la misma imagen?"
IMAGEN_2=$(docker inspect --format '{{.Image}}' "$NOMBRE")
[ "$IMAGEN_1" = "$IMAGEN_2" ] && echo "sí: el mismo identificador de imagen en las dos" || echo "no: son imágenes distintas"
```

```text
$ ./fig06_03.sh
== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]

== 2. La configuración por -e: un solo servicio
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <t>  200

== 3. Otra configuración, desde un archivo con --env-file
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
SERVICIO     ESTADO    TIEMPO  DETALLE
inexistente  FALLA         <t>  no responde: Get "http://127.0.0.1:9/": dial tcp 127.0.0.1:9: connect: connection refused
propio       OK            <t>  200

== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
REVISOR_PUERTO=8080
== 5. ¿Las dos corridas usaron la misma imagen?
sí: el mismo identificador de imagen en las dos
```

Before reading the output, the script's new lines. The `tabla` function requests the report in table form and masks the response time with `<t>`, because it is the only thing that changes between runs; it masks it **in the command itself**, in plain view, not by editing the output. The `propio` service is the `revisor` checking itself: inside the container, `127.0.0.1:8080` is the container itself, not your machine. And the `inexistente` service points to port 9, where nothing listens; it is there so you can see a failure.

Now the output, block by block:

1. **One letter short.** `REVISOR_SERVICIO` is not a variable the `revisor` knows, so it silently ignores it, as any program ignores variables it does not read. For it, `REVISOR_SERVICIOS` simply does not exist, and it refuses to start, with code 1. It is the same error as in Lesson 3, but now you know why it is so common: Docker does not validate variable names; it has no way of knowing which ones your program reads. The program is what validates, and that is why it is good that the `revisor` fails loudly and with an example, instead of starting with an empty list and pretending everything is fine.
2. **With `-e`, one service.** The report has one line, `propio`, healthy.
3. **With `--env-file`, two services.** The file has a comment and a variable. Notice that the value **has no quotes**: in a `docker run --env-file` file, everything after the `=` is the value, quotes included. It is a classic trap, and Exercise 3 makes you step into it. Be careful when carrying this rule over to Lesson 9: Compose's `env_file` is a different reader and **does** strip the quotes ([Compose services reference](https://docs.docker.com/reference/compose-file/services/)). Measured with Compose v5.0.2: the same line with quotes reached the container as `REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud`, without them. Same kind of file, two readers, two results. The table now has two lines: `inexistente` with `FALLA` and the exact cause, and `propio` with `OK`.
4. **What the container received** is the sum of what the image brings (`REVISOR_PUERTO=8080`, from its `ENV`) and what arrived at run time (`REVISOR_SERVICIOS`, from the file). The `grep REVISOR` leaves out `PATH` and `SSL_CERT_FILE`, which are also there.
5. **The same image.** The script saved the image identifier of the first container and compared it with the second's: they are identical. Two different behaviors, zero rebuilds. That is the whole point of separating configuration.

#### 6.3.3 What this gives you

Separating configuration from the image is not a matter of style. It has three practical consequences. First: **the image you tested is the one you deliver**. If going from testing to production required rebuilding with another configuration, the production image would be one nobody tested. Second: **changing configuration costs seconds**, the time it takes a container to start, not the time a build takes. Third: **the image can be published**, because it carries nothing from any environment. Those three together are what allow, in Lesson 10, publishing a single image and taking it to Kubernetes.

### 6.4 NOT like this: seeing with your own eyes what stays inside the image

#### 6.4.1 The wrong recipe

To learn to find a secret in an image, the best thing is to hide one and look for it. This Dockerfile does both things the lesson forbids. It has a single stage, as in Lesson 4, so that everything is in plain view:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_04.Dockerfile — Lección 6: ASÍ NO. Dos formas de dejar un secreto dentro de la imagen.
# (Una sola etapa, como en la Lección 4, para que todo quede a la vista.)
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/
# Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
# aunque el RUN borre el archivo al final.
ARG TOKEN_MODULOS
RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
 && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
 && rm /root/.netrc
# Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
USER 10001:10001
CMD ["revisor"]
```

Both mistakes imitate real cases:

- **Mal 1** is what someone does when they need a credential to download private dependencies. Go, like many tools, reads credentials from a `.netrc` file in the user's home directory: a line `machine <server> password <secret>`. The recipe writes the file with an `ARG`'s value, compiles, and deletes it **in the same `RUN`**. Whoever wrote it knew that a file deleted in a later `RUN` is still in the earlier layer, which is why they did it all in one. It looks prudent. It is not enough. (The server is `ejemplo.invalid`, a reserved domain that does not exist on the internet.)
- **Mal 2** is the shortcut from the opening scene: the `revisor`'s token as `ENV`, so that it "comes already configured".

#### 6.4.2 Looking for it

The script `fig06_05.sh` builds that recipe, passing it the fake module token, and then looks for both secrets where anyone who has the image can look:

```bash
#!/usr/bin/env bash
# fig06_05.sh — ASÍ NO: dos secretos (de mentira) que quedan dentro de la imagen.
# Construye fig06_04.Dockerfile y busca los secretos donde cualquiera que tenga
# la imagen los puede buscar: el historial y la configuración.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
MALO="${PREFIJO}revisor:fig06-malo"
CADENA="${PREFIJO}revisor:fig06-cadena"
trap 'docker rmi -f "$MALO" "$CADENA" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_04.Dockerfile" "$TRABAJO/Dockerfile.malo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Construir pasando el token de módulos (de mentira) por ARG"
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" \
  -f Dockerfile.malo -t "$MALO" . >/dev/null && echo "construida"

echo
echo "== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" --user 0 "$MALO" ls -A /root

echo
echo "== 3. Pero el historial guardó el valor del ARG, en dos renglones"
docker history --no-trunc --format '{{.CreatedBy}}' "$MALO" | grep 'TOKEN_MODULOS='

echo
echo "== 4. Y la configuración de la imagen trae el token de ejecución"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$MALO" | grep TOKEN

echo "== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$MALO" printenv REVISOR_TOKEN

echo
echo "== 6. docker build --check lo habría dicho antes de construir"
rc=0
docker build --check -f Dockerfile.malo . 2>&1 || rc=$?
echo "[código de salida: $rc]"

echo
echo "== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use"
cat > Dockerfile.cadena <<'FIN'
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS base
ARG TOKEN_MODULOS
RUN echo "paso 1: no uso ningún argumento"
FROM base AS hija
ARG VERSION=desarrollo
RUN echo "paso 2: tampoco"
FIN
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" --build-arg VERSION=1.3.0 \
  -f Dockerfile.cadena -t "$CADENA" . >/dev/null
docker history --no-trunc --format '{{.CreatedBy}}' "$CADENA" | head -4
```

```text
$ ./fig06_05.sh
== 1. Construir pasando el token de módulos (de mentira) por ARG
construida

== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está
.bashrc
.cache
.config
.profile

== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be

== 4. Y la configuración de la imagen trae el token de ejecución
REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo
curso-docker-token-de-mentira-en-env

== 6. docker build --check lo habría dicho antes de construir
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile.malo
#1 transferring dockerfile: 892B done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.1s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#4 DONE 0.0s

#5 [internal] load .dockerignore
#5 transferring context: 155B done
#5 DONE 0.0s
Check complete, 2 warnings have been found!

WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
Dockerfile.malo:11
--------------------
   9 |     # Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
  10 |     # aunque el RUN borre el archivo al final.
  11 | >>> ARG TOKEN_MODULOS
  12 |     RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
  13 |      && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
--------------------

WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "REVISOR_TOKEN")
Dockerfile.malo:16
--------------------
  14 |      && rm /root/.netrc
  15 |     # Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
  16 | >>> ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
  17 |     USER 10001:10001
  18 |     CMD ["revisor"]
--------------------
[código de salida: 1]

== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use
RUN |2 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be VERSION=1.3.0 /bin/sh -c echo "paso 2: tampoco" # buildkit
ARG VERSION=1.3.0
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "paso 1: no uso ningún argumento" # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

#### 6.4.3 Reading what you found

1. **The file is no longer there.** Inside the image, `/root` has the base's usual files and the caches `go build` left (`.cache`, `.config`), but not `.netrc`. The script uses `--user 0` only to be able to look at `/root`, which is not readable by the image's user `10001`. If you stopped here, you would say the recipe worked.
2. **The history has it, twice.** One line is the instruction itself, `ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`, with the value it received. The other is the `RUN`, which starts with `|1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`. That `|1` is a **count**: "in this step there was 1 build argument"; after it come all of them, with their values. Deleting the file did not delete the value, because the value was never only in the file. It is the same mechanism that in 6.2.3 left `ARG VERSION=1.3.0` in plain view; the only difference is what you put in the argument.
3. **The configuration has the runtime token**, just as in the opening scene: `REVISOR_TOKEN=curso-docker-token-de-mentira-en-env`.
4. **And every container receives it.** `printenv` prints it from inside without anyone having passed it at run time: it comes from the image.
5. **`docker build --check` had warned about it**, without building anything. It checks the Dockerfile against BuildKit's rules and, for each finding, tells you the rule's name (`SecretsUsedInArgOrEnv`), a link to its explanation, which instruction triggered it (`ARG "TOKEN_MODULOS"`, `ENV "REVISOR_TOKEN"`), the file and line, and the snippet of the Dockerfile with a `>>>` arrow. It exits with code 1 when it finds something, so it can stop an automated process. The rule looks at the variable's **name**: the documentation says it flags keys that "indicate that they contain sensitive data", without giving the list ([Docker, `SecretsUsedInArgOrEnv` rule](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/)); here `TOKEN` triggered it, and in Exercise 4 you are going to see a Spanish name that gets through without a warning. That is why it is a safety net and not a guarantee. If you want a normal `docker build` (not just `--check`) to stop on any warning, the `# check=error=true` directive, on the line following `# syntax=`, does it ([Docker, "Build checks"](https://docs.docker.com/build/checks/)). The lines starting with `#0`… `#5` are BuildKit's preliminary work to be able to read the Dockerfile; you can ignore them.
6. **An `ARG` contaminates every `RUN` that comes after it.** The last block uses a two-stage recipe, written inside the script itself, where **no** `RUN` mentions the arguments. Even so, the `RUN` in the `base` stage carries `|1 TOKEN_MODULOS=…`, and the one in the `hija` stage, which derived from `base` and also declared `VERSION`, carries `|2 TOKEN_MODULOS=… VERSION=1.3.0`. BuildKit records on every `RUN` all the arguments declared in its stage and in the stage it derives from, whether it uses them or not. A token in an `ARG` does not leave one trace: it leaves one for every subsequent `RUN`.

The important thing about this experiment is the way of searching, because it is the one you are going to use on your own images:

```bash
docker history --no-trunc --format '{{.CreatedBy}}' <imagen>
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <imagen>
```

Two commands, no special permissions, no extra tools. Anyone who can pull your image can run them. And if a secret has already reached a published image, no command fixes it: the secret is written off and **rotated** in the service that issued it. Deleting the image from the registry does not unpublish it from the machines and caches that already pulled it.

### 6.5 The runtime secret: a file, not a variable

#### 6.5.1 Why not an environment variable, even if it arrives at run time

Taking the token out of the Dockerfile and passing it with `-e REVISOR_TOKEN=...` at run time is better than leaving it in the image: it no longer travels to the registry. But it is not enough, for two reasons Compose's documentation sums up this way: environment variables "are often available to all processes, and it can be difficult to track access", and they "can also be printed in logs when debugging errors without your knowledge" ([Docker, "Secrets in Compose"](https://docs.docker.com/compose/how-tos/use-secrets/)). On top of that comes something specific to Docker: the **container's** configuration stores its full environment, and anyone who can use `docker inspect` on that machine reads it. And since Lesson 1 you know who can use `docker`: the `docker` group, which is equivalent to `root`. There is one more trace, which has nothing to do with Docker: if you type the literal value in the terminal (`-e REVISOR_TOKEN=abc…`, and the same goes for `--build-arg`), it stays in your *shell*'s history and, while the command runs, in your machine's process list. This lesson's scripts never type a value by hand: they read it from the file with `$(cat secretos/…)`, and that avoids the first problem, the value ending up in your *shell*'s history. **It does not avoid the second.** Your *shell* expands the `$(cat …)` before launching `docker`, so the value reaches `docker` as one more argument, and while the command runs, anyone who can list processes (`ps`, or reading `/proc/<pid>/cmdline`) sees it exactly as if you had typed it. It does not matter here, because the lesson's tokens are made up. With a real secret, the way out is not to pass it as an argument: hand it over as a mounted file, as the rest of this lesson does, or, at build time, with `--secret` (6.6).

The `revisor` accepts both forms, but does not treat them the same. `REVISOR_TOKEN` works and prints a warning. `REVISOR_TOKEN_ARCHIVO` receives the **path** of a file and reads the token from there; if both are present, the file wins. The path convention is `/run/secrets/<name>`: it is where Compose puts its secrets and where BuildKit puts build secrets by default, as you will see in 6.6.

#### 6.5.2 The two forms, and the error you will hit first

The script `fig06_06.sh` tries both forms, and in between triggers the most common error of the good form. It uses the fake file `secretos/revisor_token.txt`, which contains `curso-docker-token-de-mentira-7f3a9c`:

```bash
#!/usr/bin/env bash
# fig06_06.sh — El secreto de EJECUCIÓN: por variable de entorno (se ve) y por
# archivo (no se ve), con el error de permisos que vas a encontrar primero.
# Córrelo en el disco propio de Linux: una carpeta compartida con otro sistema
# miente con los permisos.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
SERVICIOS='propio http://127.0.0.1:8080/salud'

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}

echo "== 1. El token por -e: funciona, pero queda a la vista"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  -e REVISOR_TOKEN="$(cat secretos/revisor_token.txt)" "$IMAGEN" >/dev/null
sleep 1
echo "-- lo que dice el revisor al arrancar:"
docker logs "$NOMBRE" 2>&1
echo "-- lo que ve cualquiera con docker inspect:"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep TOKEN
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El token por archivo, con permisos 600"
chmod 600 secretos/revisor_token.txt
stat -c '%a %n' secretos/revisor_token.txt
rc=0
timeout 20 docker run --name "$NOMBRE" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. El token por archivo, con permisos 644 y montado de solo lectura"
chmod 644 secretos/revisor_token.txt   # 644: solo porque el token es de mentira (6.5.4)
stat -c '%a %n' secretos/revisor_token.txt
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
echo "-- /salud no pide token:"
curl -s "http://127.0.0.1:$PUERTO/salud"; echo
echo "-- /api/estados sin token:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
echo "-- /api/estados con el token:"
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" \
  "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'

echo
echo "== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR
docker inspect --format '{{range .Mounts}}{{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE"
```

```text
$ ./fig06_06.sh
== 1. El token por -e: funciona, pero queda a la vista
-- lo que dice el revisor al arrancar:
revisor: aviso: el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer; usa REVISOR_TOKEN_ARCHIVO
revisor 1.3.0 escuchando en :8080 (1 servicio(s))
-- lo que ve cualquiera con docker inspect:
REVISOR_TOKEN=curso-docker-token-de-mentira-7f3a9c

== 2. El token por archivo, con permisos 600
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]

== 3. El token por archivo, con permisos 644 y montado de solo lectura
644 secretos/revisor_token.txt
-- /salud no pide token:
{"estado":"vivo","version":"1.3.0"}

-- /api/estados sin token:
{"error":"falta el token o no es válido"}
 [401]
-- /api/estados con el token:
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <t>  200

== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud
REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token
REVISOR_PUERTO=8080
/run/secrets/revisor_token (escribible: false)
```

#### 6.5.3 Reading the run

1. **Via variable, it works and it is visible.** The `revisor` starts, but the first thing it writes to its log is a warning: `el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer`. And `docker inspect` confirms it, with the full token. There was no need to get into the container or to have the image: being able to talk to the daemon was enough. (The version `1.3.0` in the startup message is the one you stamped in 6.2.)
2. **Via file, with `600`, it does not start.** This is the lesson's error. The file on your machine belongs to your user and has permissions `600`: only its owner can read it. When it is mounted, the container sees **the same file**, with the same owner (a user number) and the same permissions; a mount neither copies nor translates anything. And inside the container the `revisor` runs as user `65532`, which is not the owner. The kernel does what it would do with any other user on your machine: `permission denied`. It is the direct consequence of something you saw in Lesson 0: in Lesson 1's normal installation, user numbers inside and outside are the same. (With rootless Docker or user remapping, the number inside is translated to another one outside, and the diagnosis with `ls -ln` changes.) Notice also that the `revisor` **does not start halfway**: if you told it there is a token file and it cannot read it, it prefers to die with code 1 rather than keep listening without protection.
3. **With `644`, it works.** `644` grants read access to everyone; now user `65532` can read it. And not only that user: **any other account on your machine** can too (6.5.4). Here it is a made-up token. `/salud` answers without a token (it is so health can be monitored, Lesson 7), and `/api/estados` answers `401` without a token and the table with it. The output has a blank line after the `/salud` JSON: it is the script's `echo`, which adds a newline to the one the `revisor` already sent. And the order of the variables in block 4's `docker inspect` may vary from one run to another; what matters is which ones are there.
4. **`docker inspect` no longer shows the secret.** It shows `REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token`, a path, which is useless without the file. And the mount appears as `escribible: false`: the `readonly` option prevents the container from modifying the host's file, even if it had permission.

#### 6.5.4 Isn't `644` dangerous?

Yes, and the short answer is: **with a real secret, never**. `644` means **any other account on your machine** can read the file: another person's on a shared server, a service's that runs with its own user, a program's that someone made run as another user. Lesson 9 demonstrates it with an unprivileged account (`sudo -u nobody cat`, section 9.8.3): with `644` it prints the whole token. The course uses `644` in this lesson because the token is made up (`curso-docker-token-de-mentira-7f3a9c` opens nothing) and the practice is on your computer; it is the shortest way to see the `revisor` start. Do not copy it to a real project.

The good fixes attack the same cause (who the file belongs to, not just how open it is), and are checked with `ls -l` or with `stat -c '%a %U:%G' secretos/revisor_token.txt`:

- **Make the file's group the container's**: `sudo chgrp +65532 secretos/revisor_token.txt` and `chmod 640 secretos/revisor_token.txt` (the `+` indicates that `65532` is a group number). You remain the owner (you read and edit it without `sudo`), the `revisor` reads it because it runs as `65532:65532`, and nobody else does, except `root` and whoever manages Docker (9.8.3). Choose this one **or** the next, not both.
- **Make the file belong to the container's user**: `chmod 600 secretos/revisor_token.txt` and **then** `sudo chown 65532:65532 secretos/revisor_token.txt`, in that order: once the owner is already `65532`, your `chmod` fails with `Operation not permitted` and the file stays open. That way only that user and `root` can read it. The price is that your user can no longer read it without `sudo`.
- **Let an orchestrator deliver it, with an important caveat.** Compose secrets (Lesson 9) put the file in `/run/secrets/`, but when the secret comes from a **file**, Compose mounts it as-is, just like this lesson's `--mount`: the owner and permissions remain those of the file on your machine. Its reference says so: with a file as the source, Compose uses a mount underneath that does not allow changing the owner, and the `uid`, `gid`, and `mode` attributes "are silently ignored"; they only work when the secret comes from an environment variable ([Compose services reference](https://docs.docker.com/reference/compose-file/services/)). We measured it with Compose v5.0.2: the file at `600`, with `uid: "65532"`, `gid: "65532"`, and `mode: 0400` declared in the `compose.yaml`, gave exactly the same `permission denied` as in 6.5.2. That is why Lesson 9 measures the four cases (`644`, `600` yours, `600` owned by `65532`, and `640` with group `65532`) and leaves your file in the last one. Kubernetes does mount its secrets with the permissions you declare, but that is the subject of the Kubernetes course.

And keep the secret from reaching the repository: `secretos/` goes in your project's `.gitignore`, just as in the `.dockerignore`. This course does carry its `secretos/` in the repository, on purpose, because the token is made up.

What is **not** a fix: changing the image's `USER` to `root` "so it can read". That trades a permissions problem for a security one, and undoes the work of Lessons 3 and 5.

### 6.6 The build secret: a mount that lasts one `RUN`

#### 6.6.1 When it is needed

Sometimes the secret is not for running but for **building**: credentials to download private Go modules, packages from a private npm or Maven repository, a certificate to access an internal dependency server. The `revisor` has no external dependencies, so it does not need one today, but the pattern stays in its Dockerfile for the day it does.

BuildKit has a tool made for this: the **secret mount**. In the Dockerfile, a `RUN` asks for the secret with `--mount=type=secret,id=<name>`; when building, you hand it over with `docker build --secret id=<name>,src=<file>` (or `env=<VARIABLE>`, if you have it in a variable in your terminal). According to the documentation, the mount makes the secret available "temporarily inside the build container, for the duration of the build instruction" ([Docker, "Build secrets"](https://docs.docker.com/build/building/secrets/)). The options the `revisor` uses, with their default values according to the [Dockerfile reference](https://docs.docker.com/reference/dockerfile/):

| Option | What it does | Default |
|---|---|---|
| `id` | the name under which `--secret` delivers it | the file name from `target` |
| `target` | where the file appears during the `RUN` | `/run/secrets/<id>` |
| `required` | if `true`, the instruction fails when the secret is not provided | `false` |
| `mode` | the file's permissions | `0400` |
| `uid`, `gid` | the file's owner | `0` (`root`) |
| `env` | instead of a file (or in addition), puts the secret in an environment variable that exists **only during that `RUN`** | no value: file only |

**Mind the user during the build.** The mount delivers the file owned by `0` (`root`) with `0400` permissions by default. If your build stage has already switched to an unprivileged user with `USER`, that user will not be able to read the secret and the `RUN` will fail with `permission denied`: it is the same permissions trap as in 6.5. You fix it by setting the owner on the mount (`uid=` and `gid=`) or by relaxing the mode (`mode=0444`, bearing in mind that the secret only exists during that `RUN`). The Dockerfile in this lesson does not need it, because the stage that uses it runs as `root`.

Watch out for the two `env`s. In `docker build --secret id=x,env=MY_VAR`, `env` says **which variable in your terminal** the secret is read from. In `--mount=type=secret,id=x,env=TOKEN`, it says **under what name the `RUN` sees it**. That second variable is not an `ENV`: it is born and dies with the instruction, and it stays neither in the image nor in the history. It is the form the documentation itself uses in the correct example for the `SecretsUsedInArgOrEnv` rule, and the one that suits when the tool reads its credential from a variable rather than a file. "Environment variable" is not bad in itself; what is bad is it being written down where the image travels or where anyone can read it.

The `revisor` uses `target=/root/.netrc` because that is where Go looks for its credentials, and `required=false` because this course has no private modules: that way its build works with and without `--secret`.

#### 6.6.2 Watching it appear and disappear

To see the mount in action you need a `RUN` that does something visible with the secret. This demonstration Dockerfile receives it, counts its bytes, and lists the file, **without printing the value**. It uses `required=true` so you can see the error of forgetting it:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_07.Dockerfile — Lección 6: dónde vive un secreto de construcción.
# Solo para mirar: un RUN que recibe el secreto, lo cuenta y no lo imprime.
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
RUN --mount=type=secret,id=netrc,target=/root/.netrc,required=true \
    echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes" \
 && ls -l /root/.netrc
```

The script `fig06_08.sh` builds it twice (without and with the secret), looks at what was left, and finishes by building the real `revisor` with `--secret`:

```bash
#!/usr/bin/env bash
# fig06_08.sh — El secreto de CONSTRUCCIÓN con --secret: está durante el RUN y
# en ningún otro lado. Primero el error de olvidarlo; después, el revisor real.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
DEMO="${PREFIJO}revisor:fig06-demo-secreto"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$DEMO" "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp "$AQUI/fig06_07.Dockerfile" "$TRABAJO/Dockerfile.demo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Olvidar --secret cuando el Dockerfile dice required=true"
rc=0
docker build --no-cache --progress=plain -f Dockerfile.demo -t "$DEMO" . > salida-1.txt 2>&1 || rc=$?
grep -E '^ERROR' salida-1.txt
echo "[código de salida: $rc]"

echo
echo "== 2. Con --secret: el RUN lo recibe"
docker build --no-cache --progress=plain --secret id=netrc,src=secretos/token_modulos.txt \
  -f Dockerfile.demo -t "$DEMO" . 2>&1 | grep -E 'durante el RUN|/root/.netrc$' | grep -v '^#[0-9]* \[' 

echo
echo "== 3. Terminado el RUN, ¿qué quedó en /root?"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$DEMO" ls -lA /root

echo
echo "== 4. ¿Y en el historial? Ni el valor ni el archivo: solo la instrucción"
docker history --no-trunc --format '{{.CreatedBy}}' "$DEMO" | head -1
echo "-- renglones del historial con el valor del secreto:"
docker history --no-trunc --format '{{.CreatedBy}}' "$DEMO" | grep -c 'modulos-de-mentira' || true

echo
echo "== 5. El revisor real, construido con el secreto (opcional en su Dockerfile)"
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt \
  -t "$IMAGEN" . >/dev/null && echo "construida"
echo "-- renglones del historial con el valor del secreto:"
docker history --no-trunc --format '{{.CreatedBy}}' "$IMAGEN" | grep -c 'modulos-de-mentira' || true
```

```text
$ ./fig06_08.sh
== 1. Olvidar --secret cuando el Dockerfile dice required=true
ERROR: failed to build: failed to solve: secret netrc: not found
[código de salida: 1]

== 2. Con --secret: el RUN lo recibe
#7 0.092 durante el RUN: /root/.netrc existe y mide 37 bytes
#7 0.093 -r-------- 1 root root 37 Oct 21 09:17 /root/.netrc

== 3. Terminado el RUN, ¿qué quedó en /root?
total 8
-rw-r--r-- 1 root root 607 Jul 17 17:05 .bashrc
-rw-r--r-- 1 root root 132 Jul 17 17:05 .profile

== 4. ¿Y en el historial? Ni el valor ni el archivo: solo la instrucción
RUN /bin/sh -c echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes"  && ls -l /root/.netrc # buildkit
-- renglones del historial con el valor del secreto:
0

== 5. El revisor real, construido con el secreto (opcional en su Dockerfile)
construida
-- renglones del historial con el valor del secreto:
0
```

The script's new options: `--no-cache` forces the `RUN` to run even if there is a cache, so that it prints something; `--progress=plain` shows each step's output as plain text, instead of the view that redraws itself in the terminal. Each line of that output starts with the step number (`#7`) and the seconds since it started; those numbers and the file's date change on every run (the date is in the virtual machine's time, which is Greenwich Mean Time). The `|| true` at the end are there because `grep -c` exits with code 1 when it counts zero, and here zero is exactly what we want to see.

And the output:

1. **Forgetting the secret** with `required=true` stops the build with a short message: `secret netrc: not found`. It is what you want when the secret is indispensable: a clear error at build time, and not a compilation that fails three steps later with an "unauthorized" nobody understands. The `revisor` uses `required=false` because for it the secret is optional.
2. **With `--secret`, the `RUN` sees it**: a 37-byte file (36 characters of the fake value plus the newline), with permissions `-r--------` (the default `0400`) and owner `root`, the user that `RUN` runs as.
3. **Once the `RUN` is over, it is gone.** `/root` only has the base's files. Unlike the `rm` in 6.4, here nobody had to delete anything: the file was never written to the layer; it was mounted on top, like a loan, and returned when the instruction finished.
4. **The history records the instruction and nothing else.** Not the value, not even the `--mount` options. The count of lines with the secret's value is `0`.
5. **The real `revisor`**, built with its optional secret: also `0`.

Put this output next to the one from 6.4. With `ARG`, the value stayed written even though the file was deleted. With `--secret`, the value never got written.

#### 6.6.3 The five paths, together

You have now seen each mechanism working separately. This table brings them together, because the question you are going to ask yourself in your own project is always the same: where does this value come in, and where does it end up written?

| Mechanism | When it exists | How it is delivered | Where it ends up written | Is it suitable for secrets? |
|---|---|---|---|---|
| `ARG` | only when building | `docker build --build-arg` | in the history, on its own line and on every subsequent `RUN` in the stage (6.4); in the provenance in `max` mode (6.7) | no |
| `ENV` | when building and in every container | the Dockerfile; changed with `-e` | in the image's configuration (`docker image inspect`) | no |
| `-e` / `--env-file` | at run time | `docker run` | in the container's configuration (`docker inspect`) | no |
| `--mount=type=secret` | only during one `RUN` | `docker build --secret` | nowhere (6.6.2) | yes, for build |
| file in `/run/secrets/` | at run time | read-only mount | `docker inspect` shows the path, not the value (6.5) | yes, for runtime |

The first three rows are for configuration; the last two, for secrets. If a sensitive value is in any of the first three, it is already written somewhere another person can read.

#### 6.6.4 Why it does not sneak in through the cache

A reasonable doubt: if the secret changes, does BuildKit's cache run the `RUN` again? No. The documentation puts it this way: "The contents of build secrets are not part of the build cache", and "changing the value of a secret doesn't result in cache invalidation"; what does count are its properties, such as the `id` and the mount path ([Docker, "Build cache invalidation"](https://docs.docker.com/build/cache/invalidation/)). The documentation does not explain why; the practical thing is to know that the value does not count for the cache, and that the `id` and the mount path do. If you change the secret and need the `RUN` to repeat, the documentation suggests also passing some build argument that you change at the same time (arguments do invalidate the cache), or you can force it with `--no-cache`, as the script did. It is a small inconvenience in exchange for the value not appearing in any build log.

### 6.7 What you will find in old tutorials

- **`ARG` for npm, GitHub, or private registry tokens**, with the comment "don't worry, we delete it at the end of the `RUN`". You already saw in 6.4 that the value stays in the history. Secret mounts have existed since BuildKit introduced them, and they are the documented path.
- **Building in several stages "so the `ARG` doesn't reach the final image".** It is true that the delivered image's history only shows the final stage (you saw it in 6.2.3), but the values can also remain in the **provenance attestations**, the record of how the image was built that Lesson 10 attaches to it. In the minimal mode, the one used by default, argument values are not included; with `--provenance=mode=max`, the one Lesson 10 uses, the documentation warns that this mode "exposes the values of build arguments", from all stages ([Docker, SLSA provenance](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). It helps, but it is not the solution.
- **`docker run -e PASSWORD=...` in an image's instructions.** Many popular images accept secrets via variable because it is the easiest thing to document, and many also offer a `_FILE` variant that reads from a file, like the `revisor`'s `REVISOR_TOKEN_ARCHIVO`. When the file variant exists, use it.
- **"Squashing" the layers so the secrets disappear.** Some old guides propose merging all the layers into one. Even if that removed a file from an intermediate layer, it does not touch the image's configuration: an `ENV` with a token is still there, as you saw in 6.4. The current path is for the secret never to get in.

## The error you will see

This lesson has one main error and two secondary ones. All three have already appeared.

**The main error: the secret file the container cannot read.** It is the one from `fig06_06.sh`:

```text
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]
```

It reads from right to left. `permission denied` is said by the kernel: the process does not have permission to open that file. `open /run/secrets/revisor_token` says which file, with the path **inside** the container; the path on your machine is the mount's. And `leyendo el token de REVISOR_TOKEN_ARCHIVO` is added by the `revisor` so you know what it was doing. The question that solves it is "who owns the file, and which user does the container run as?". The first answer comes from `ls -ln` on your machine; the second, from `docker inspect --format '{{.Config.User}}'` on the image (`65532:65532`). If they do not match and the permissions are `600`, this is the result. Fixes: the right group or owner, which let the `revisor` read it and nobody else (6.5.4); `644` also works, but it is only acceptable with a made-up token. What is not a fix: running as `root`.

**The secondary error: the build secret that did not arrive.**

```text
ERROR: failed to build: failed to solve: secret netrc: not found
```

You see it when the Dockerfile asks for a secret with `required=true` and the `docker build` does not include `--secret id=netrc,...`. The fix is to add it. If you did write `--secret` but with a different `id` (for example, `id=nettrc`), you are in the same situation: the `RUN` asked for the `netrc` secret and nobody gave it, so check that both `id`s match letter for letter. With `required=false`, as in the `revisor`, there is no error: the `RUN` runs without the file.

**The warning you have to treat as an error: `SecretsUsedInArgOrEnv`.**

```text
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
```

It is a warning, not an error: a normal `docker build` prints it and builds anyway. That is why it is easy to ignore. With `docker build --check` the result is code 1, and that is how it should be run: before every build that is going to be published. Remember that it only looks at names: a missing warning does not prove there are no secrets.

## The security habit of the lesson

**Secrets do not go through `ARG` or `ENV`, and you verify with `docker history` and `docker inspect` that they did not stay.** The habit has two halves, and the second is the one that gets forgotten. The first is the rule: the build secret comes in with `--secret`, the runtime secret as a read-only file in `/run/secrets/`. The second is the check: before publishing an image, you search its full history and its configuration, with the two commands from 6.4.3, and you find nothing. This habit prevents the accident in the opening scene (a token published to a registry that more people have access to than you think) and another, quieter one: a token passed via `-e` that ends up in an error log, on the shared screen of a video call, or in the `docker inspect` output someone pasted into a chat to ask for help.

## Common mistakes

**Rebuilding the image to change environments.** If the production image is different from the test one, nobody tested the production one. One image, many configurations.

**Putting an environment's configuration in the Dockerfile's `ENV`.** `ENV` is for default values that work anywhere, like the port. A list of test services in the `ENV` forces you to rebuild for production, and it stays in the image forever.

**Passing a secret via `ARG` and deleting it "in the same `RUN`".** The file disappears; the value stays in the history (6.4). The prudence of doing it in a single `RUN` protects against a different error from the one that actually happens.

**Passing the token via `-e` because "it's no longer in the image".** It no longer travels to the registry, but it is still in the container's configuration, visible to anyone with access to `docker`, and in the environment of every child process.

**Fixing `permission denied` with `--user root` or `chmod 777`.** The first undoes the image's hardening; the second leaves the file writable for the whole machine. The problem is the owner; fix it there.

**Keeping the secrets folder in the repository.** This course does it on purpose and with fake values. Your project does not: `secretos/` goes in `.gitignore` and in `.dockerignore` from day one.

**Trusting that `docker build --check` said nothing.** It checks names, not values. A variable `X` with a token in it passes clean.

**Copying the mounted secret to another path.** The mount leaves no trace, but whatever the `RUN` writes does: if a `cp /run/secrets/…` or a tool saves the credential in its own configuration (an `.npmrc`, a credentials file), that copy stays in the layer like any other file. The secret is read in the `RUN` and written nowhere.

**Printing a secret "just for debugging".** A `RUN cat /run/secrets/...` or an `echo $TOKEN` leaves the value in the build output or in the container's logs, which are stored and shared. To know whether a secret arrived, count its bytes, as `fig06_07.Dockerfile` did.

## Exercises

Do them in order. Before running each one, write in your [logbook](bitacora.md) what you think will happen; comparing it afterwards is half of the learning. When you finish, delete what you created: everything carries the `curso-docker-` prefix.

### Exercise 1 — Code, configuration, or secret?

Classify each item into one of the three boxes from 6.1.1 and say where it should live (inside the image, in `ENV` as a default value, via `-e`/`--env-file`, or as a file in `/run/secrets/`):

1. The `revisor`'s version `1.3.0`.
2. The list of services the test environment checks.
3. The token that protects `/api/estados` in production.
4. Port `8080`.
5. The path where the `revisor` stores its report (`REVISOR_REPORTE`).
6. A credential to download private Go modules when compiling.

### Exercise 2 — Without `--build-arg` (project)

In your folder `~/curso-docker/revisor`, with this lesson's Dockerfile, build an image **without** `--build-arg` and with the tag `curso-docker-revisor:sin-version`. Before building, predict what these three things will say, and then check:

1. `docker run --rm curso-docker-revisor:sin-version version`
2. The image's `org.opencontainers.image.version` label.
3. The `ARG` line in its `docker history`.

The exercise is self-checking: if your three predictions match what you see, you understood where an `ARG`'s value comes from. At the end, `docker rmi curso-docker-revisor:sin-version`.

### Exercise 3 — The quotes in the env file

Create a file `comillas.env` with this single line, quotes included:

```text
REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"
```

Before running it, predict: does the `revisor` start or refuse? If it starts, what will its table say? Then run it with `docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --env-file comillas.env curso-docker-revisor:1.3.0`, request the table with `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'`, and read with `docker inspect` exactly which value it received. Fix the file so that the service comes out `OK`. At the end, `docker rm -f curso-docker-revisor`.

### Exercise 4 — Find the leak

A teammate hands you this recipe and swears that "it leaves nothing behind because the secret is deleted". Without building it, say **where** each of the two sensitive values would end up and with what command you would find it. Then rewrite the build-secret part with a secret mount, and say which `docker build` option delivers it:

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
ARG CLAVE_REGISTRO
ENV API_KEY=valor-de-mentira-para-el-ejercicio
RUN echo "${CLAVE_REGISTRO}" > /tmp/clave && go env -w GOPRIVATE=ejemplo.invalid && rm /tmp/clave
```

Extra question: which of the two variables would `docker build --check` have flagged, and which not? Think about how the rule decides.

## Solutions

### Solution 1

1. **Code.** Inside the image: stamped into the binary with `-X main.version` and in the OCI label. It does not change between environments.
2. **Configuration.** Via `-e` or `--env-file` at run time. It changes between environments and is not secret.
3. **Secret.** As a read-only file in `/run/secrets/revisor_token`, with `REVISOR_TOKEN_ARCHIVO` pointing there. Never in `ENV` or via `-e`.
4. **Configuration with a default value.** `ENV REVISOR_PUERTO=8080` in the image; any environment changes it with `-e`.
5. **Configuration.** Via `-e` or `--env-file`. (Lesson 8 gives it a default value inside the image, once there is a `/datos` directory prepared for it.)
6. **Build secret.** With `--mount=type=secret` in the `RUN` that needs it, delivered with `docker build --secret`. Never in `ARG`.

### Solution 2

Measured with the same machine and the same Docker version as the lesson:

1. `desarrollo`. Without `--build-arg`, `VERSION` takes the default value from its declaration, `ARG VERSION=desarrollo`, and that is what `-X main.version` stamps into the binary.
2. `desarrollo` as well, because the `final` stage declares its own `ARG VERSION=desarrollo` and the label uses it.
3. `ARG VERSION=desarrollo`. The history records the value the argument had **in that build**, whether from `--build-arg` or from the declaration. That is exactly why a secret cannot go there.

### Solution 3

Measured with the same machine and the same Docker version as the lesson. The `revisor` **starts** (`revisor 1.3.0 escuchando en :8080 (1 servicio(s))`), but the table says:

```text
SERVICIO  ESTADO    TIEMPO  DETALLE
"propio   FALLA        1ms  codigo 404
```

The time changes on every run. The quotes arrived as part of the value: `docker inspect` shows `REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"`. The `revisor` read a service named `"propio` (with the quote) whose address is `http://127.0.0.1:8080/salud"` (with the quote at the end); that path does not exist and the server answers `404`. It is the worst kind of configuration error: it does not prevent startup, it just gives a wrong result. The fix is to remove the quotes: in an `--env-file` file, everything after the `=` is the value, as-is. (In the terminal you do use quotes, because there the *shell* interprets them and they do not reach the container. And in Compose's `env_file`, Lesson 9, you can use them too, because that reader does strip them.)

### Solution 4

- `CLAVE_REGISTRO` ends up **in the history**, on the `RUN` line, in the form `|1 CLAVE_REGISTRO=<value> /bin/sh -c ...`. You find it with `docker history --no-trunc --format '{{.CreatedBy}}' <image>`. The `rm /tmp/clave` does not prevent it, just as in 6.4.
- `API_KEY` ends up **in the image's configuration** and in every container's environment. You find it with `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <image>`.

The rewrite of the build secret:

```dockerfile
RUN --mount=type=secret,id=clave_registro,target=/root/.netrc,required=true \
    go env -w GOPRIVATE=ejemplo.invalid && go mod download
```

Here the secret is **used**: `go mod download` downloads the private modules and, to access the server, reads the credential from `/root/.netrc`, which exists only during this `RUN` (the secret file would have the line `machine ejemplo.invalid password …`, as in 6.4). If the tool you need reads its credential from a variable rather than a file, you change `target=…` to `env=CLAVE_REGISTRO`, and the variable exists only during that `RUN` (6.6.1). It is delivered with `docker build --secret id=clave_registro,src=<file> .` (or `env=<VARIABLE>` from your terminal). No `ARG`, no file to delete, and no history line with the value. And `API_KEY` leaves the Dockerfile: if the program needs it at run time, it arrives as a file.

Extra question: the rule decides by the variable's **name**. Measured with the same machine and the same Docker version as the lesson, `docker build --check .` on the recipe exits with code 1 and a single warning:

```text
Check complete, 1 warning has been found!
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "API_KEY")
```

`API_KEY` has the kind of name the rule looks for. `CLAVE_REGISTRO`, in Spanish, passes without a warning, and it is precisely the value that ends up in the history. The lesson that matters: the warning is a net, not a lock.

## How I know I got it

Check each item only if you can do it **without looking at the text again**:

- [ ] In your folder, `docker run --rm curso-docker-revisor:1.3.0 version` prints `1.3.0`, and `docker image inspect` shows the label `org.opencontainers.image.version = 1.3.0`.
- [ ] `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.3.0` shows `REVISOR_PUERTO=8080` and no other `REVISOR_*` variable.
- [ ] You run the same image with two different lists of services, one via `-e` and another via `--env-file`, without rebuilding.
- [ ] You can explain in one minute the difference between `ARG` and `ENV` using the words *build*, *run*, *history*, and *configuration*.
- [ ] You build `Dockerfile.malo` and find the two fake secrets with two commands; and `docker build --check -f Dockerfile.malo .` gives you the two warnings and code 1.
- [ ] The `revisor` starts with `REVISOR_TOKEN_ARCHIVO` and a file mounted read-only; `/api/estados` answers `401` without a token and the table with it; and `docker inspect` on the container does not show the token's value.
- [ ] You trigger the `permission denied` with `chmod 600` and explain why it happens using the words *owner* and `65532`.
- [ ] `docker history --no-trunc --format '{{.CreatedBy}}' curso-docker-revisor:1.3.0 | grep -c 'modulos-de-mentira'` gives `0` after building with `--secret`.
- [ ] You run the scripts in [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos) and your outputs match this lesson's, except for the times, the build step numbers, the file date in `fig06_08.sh`, the order of the variables in `docker inspect`, and the architecture in the history. And when you finish, `docker ps -a --filter name=curso-docker-` shows no containers from this lesson.

## Summary

Answer without looking at the lesson:

1. What is configuration, according to *The Twelve-Factor App*, and what test does it propose to know whether you separated it properly?
2. When does an `ARG` exist and when does an `ENV`? Where does each one's value end up written?
3. Why does the `revisor`'s Dockerfile declare `ARG VERSION` twice?
4. What is the difference between `-e` and `--env-file`, and what happens to quotes in an env file?
5. Why does deleting a file in the same `RUN` not protect a secret that arrived via `ARG`?
6. What does `docker build --check` check with the `SecretsUsedInArgOrEnv` rule, and what can it not see?
7. Why is a token via `-e` still a bad idea even though it is not in the image?
8. Why does a secret file with permissions `600` give `permission denied` inside the container, and what are the good fixes?
9. What does `--mount=type=secret` do, where does the file appear by default, and what does `required` mean?

## Sources

All consulted on October 21, 2026.

- [The Twelve-Factor App, "Config"](https://12factor.net/config): the definition of config as what varies between deploys, the open-source test, and config in environment variables.
- [Docker, "Build variables"](https://docs.docker.com/build/building/variables/): `ARG` versus `ENV`, that arguments do not reach containers but can persist in metadata, the history, and attestations, scope per stage, and the warning about secrets.
- [Docker, "Build secrets"](https://docs.docker.com/build/building/secrets/): why arguments and environment variables are inappropriate for secrets, the secret mount, its default path `/run/secrets/<id>`, `target`, and the `src` and `env` forms of `--secret`.
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/): the options of `RUN --mount=type=secret` (`id`, `target`, `required`, `mode`) and their defaults, `LABEL` and reading it with `docker image inspect`, and that `ENV` persists in containers and is changed with `docker run --env`.
- [Docker, "Build cache invalidation"](https://docs.docker.com/build/cache/invalidation/): that a secret's contents are not part of the cache and how to force the step to repeat.
- [Compose services reference](https://docs.docker.com/reference/compose-file/services/): that with a file as the source a secret's `uid`, `gid`, and `mode` attributes are ignored, and how `env_file` reads quotes.
- [Docker, SLSA provenance](https://docs.docker.com/build/metadata/attestations/slsa-provenance/): that the minimal mode, the default, does not include argument values and that `max` mode exposes them.
- [Docker, "Build checks"](https://docs.docker.com/build/checks/): the `# check=error=true` directive.
- [Docker, `SecretsUsedInArgOrEnv` rule](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/): what the rule reports and the correct example with secret mounts.
- [`docker run` reference](https://docs.docker.com/reference/cli/docker/container/run/): `-e`, `-e` without a value, and the `--env-file` format with its comments.
- [Docker, "Secrets in Compose"](https://docs.docker.com/compose/how-tos/use-secrets/): why environment variables are not a good place for secrets and the path `/run/secrets/<name>`.
- [OCI Image Specification, annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md): the definitions of `org.opencontainers.image.title`, `.version`, and `.source`.
- [cmd/link](https://pkg.go.dev/cmd/link): the Go linker's `-X` option, which sets the value of a string variable at compile time.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions and dates in "About the runs".
- [Colima](https://github.com/abiosoft/colima): the tool used to run the programs on macOS.

### Terms in this lesson

| | |
|---|---|
| **build argument** (`ARG`) | a variable that exists only while the image is being built; changed with `--build-arg`, and its value stays in the history |
| **configuration** | what changes from one environment to another; it arrives at run time, it does not go in the image |
| **label** | a name-value pair attached to the image as metadata; read with `docker image inspect` |
| **OCI labels** | labels with standard names (`org.opencontainers.image.*`) that any tool understands |
| **history** | the list of instructions that created the image, with their values; read with `docker history` |
| **secret mount** | a file BuildKit makes available to a single `RUN` and that does not stay in any layer |
| **secret** | configuration that, if it leaks, someone can use against you: tokens, passwords, credentials |
| **build secret** | one needed to build the image; delivered with `docker build --secret` |
| **runtime secret** | one the program needs at run time; delivered as a file in `/run/secrets/` |
| **environment variable** (`ENV`, `-e`) | a name-value pair a process receives when it starts; visible in `docker inspect` |

---

**Next:** [Lesson 7 — Health checks and lifecycle](07-salud-y-ciclo-de-vida.md)
