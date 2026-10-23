# Lesson 8 — Volumes and networks

It is Monday, 9:05 in the morning. At 10:00 there is a review with the operations team and you were asked to bring the `revisor`'s latest report: which services failed over the weekend. On Friday night someone updated the container the way it is always done: `docker rm -f`, `docker run` with the new image, and home. You open the terminal, look for the report, and it is not there. It is not in the new container, which has just been born, and the old one no longer exists. While you take that in, you notice something else: the new container says `FALLA` for the test service, with a message you had not seen before: `lookup curso-docker-prueba ... no such host`. The test service is running, `docker ps` shows it, and `curl` from your machine reaches it. But the `revisor` swears it does not exist. It is 9:12. You have two problems that look different and are the same question: **where does what a container needs to keep live, and how does it find the others?** This lesson exists so you can answer it before ten: the report is saved in a place that outlives the container, with the right owner, and containers find each other by name on a network you define, with the part that does not need the internet locked inside a network with no way out.

**Time:** 2 × 45 min

**What you build:** the report that survives and two containers that talk to each other. The image `curso-docker-revisor:1.5.0` carries a folder `/datos` that belongs to the unprivileged user `65532` and saves its report there by default. A named volume, `curso-docker-reportes`, is mounted on that folder and keeps the report even if you delete the container. The test service lives **only** on an internal network, `curso-docker-interna`, with no way out to the internet; the `revisor` lives on a network defined by you, `curso-docker-red`, through which it exposes its port, and it also connects to the internal one to check the test service by name.

**What you learn:** where a container writes and why that is lost; the three types of mount (named volumes, *bind mounts*, and `tmpfs`) and when to use each; `-v` versus `--mount`; who owns the files when the process is not `root`, and how to fix it from the image and not with `root`; what happens to a folder's contents when you mount something on top of it (sometimes it is copied, sometimes it is hidden); the default network and why there are no names there; user-defined networks and their internal DNS; and internal networks, with no way out.

**Where you are coming from.** From [Lesson 7](07-salud-y-ciclo-de-vida.md) you bring the image `curso-docker-revisor:1.4.0`, with its `HEALTHCHECK` and its `STOPSIGNAL`, and the way to run it hardened: read-only file system, no capabilities, no privilege escalation, with `--init` and with limits. You also bring a promise: in Lesson 7 the report was saved in a `tmpfs`, which dies with the container, and giving it a place that lasts was left pending. From [Lesson 6](06-configuracion-y-secretos.md) you bring the mount of a single file (the token at `/run/secrets/`), used without being explained in depth, and the permissions error with user `65532`: today that same error comes back, on a whole folder. From [Lesson 2](02-contenedores-dia-a-dia.md) you bring the image `curso-docker-prueba:1.0.0` and the habit of publishing ports only on `127.0.0.1`. And from [Lesson 3](03-primer-dockerfile.md), a phrase that makes sense today: the `revisor` checked itself "because there is no network between containers yet".

**What this lesson does not do.** It does not use Compose: everything is done with `docker volume`, `docker network`, and `docker run`, so you see each piece; [Lesson 9](09-compose.md) writes the same thing in a `compose.yaml`. It does not teach remote volume drivers (network or cloud storage) or networks that span several machines (*overlay*): this course works on a single machine, and what you learn here (file ownership, DNS by name, the network with no way out) is what those other tools need too. It does not use the `host` network except to say why it is not used. And it does not back up or restore volumes with special tools: the report is read with a helper container, which is the way of looking inside a volume that works on any machine.

**About the runs.** All the outputs are real and were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4, the same base as Linux Mint 22, the course's reference system, with kernel 6.8 and an `arm64` processor. The scripts were run **inside** that virtual machine, with Docker 29.2.1 (client and daemon) and Buildx v0.31.1, and with their working folder on Linux's own disk. That matters a great deal in this lesson, which is about owners and permissions: folders shared between the Mac and the virtual machine lie about them, and no ownership example was measured in one of those folders. On your Mint that problem does not exist. Two differences you will see with your own eyes: in the virtual machine the user who ran the scripts is `501`, with group `1000`, so where the output says `501:1000` your Mint will almost surely say `1000:1000`, the first user created at install time; and the dates in the `ls -l` listings are in the virtual machine's time, which is Greenwich meridian time. To avoid colliding with other runs that used the same machine, the scripts were launched with a different name prefix and a different port (the `PREFIJO` and `PUERTO` variables they come with). Since in this lesson the names of networks, volumes, and containers **do** appear in the outputs (DNS uses them), the scripts that show names carry a function `nombres` that, in plain sight, rewrites that prefix as `curso-docker-`; with the default prefix it changes nothing, so what you see is what you will see. With their default values, the scripts use their own helper names containing `fig08` (the image `curso-docker-revisor:fig08`, and `:fig08-l7`, the 1.4.0 that `fig08_02.sh` builds; the container `curso-docker-revisor-fig08`, the volume `curso-docker-reportes-fig08`, the networks `curso-docker-red-fig08` and `curso-docker-interna-fig08`): that way they never touch your image `curso-docker-revisor:1.5.0`, your container `curso-docker-revisor`, your volume `curso-docker-reportes`, or your networks, and on exit they delete only what they created. For the same reason they publish their port, by default, on `127.0.0.1:8081`, not on the `8080` of your `revisor`: that way you can run them with your final state up (if you have `8081` taken, pass them another, for example `PUERTO=8082 ./fig08_03.sh`; the port does not appear in the outputs). They use, unmodified, two images you already have: `curso-docker-prueba:1.0.0`, from Lesson 2, and `alpine:3.24.2`, a helper container with a *shell* for looking at volumes and networks, because the course's two images have no *shell*. The course was planned with Docker Engine 29.8.2, and the most recent version published that day was 29.9.2, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)); nothing in this lesson changes between those versions. What **does** change from one run to another, and is flagged where it appears: the timings in the `revisor`'s table (masked with `<t>`), the number of the report's temporary file (masked with `<n>`), the containers' IP addresses and your machine's DNS (masked with `<IP>` and `<DNS del anfitrión>`), the container identifiers (`<id>`), and the dates. Everything is masked in the script itself, in plain sight, never by editing the output. The programs are in [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes), each with its output beside it, and `estado/` keeps the project's files as they stand at the end.

## By the end you will be able to

- Explain why what a container writes to its own file system is lost with `docker rm`, and choose between a named volume, a *bind mount*, and a `tmpfs` for each piece of data of the `revisor`.
- Trigger and diagnose the `permission denied` of a new volume with an unprivileged process, and fix it in the image with `COPY --chown`, without running as `root`.
- Demonstrate that the report survives `docker rm` by reading it from a helper container.
- Predict what happens to a folder's contents when you mount a new volume, a volume with data, or a *bind mount* on top of it, and explain the difference between `-v` and `--mount` when the host folder does not exist.
- Run the `revisor` with a *bind mount* of a folder of yours, fixing the owner with `--user`, and mount read-only whatever the container must not change.
- Show that on the default network a container cannot find another by name, and that on a user-defined network it can, by reading which DNS server each one uses.
- Lock the test service inside an internal network with no way out to the internet and connect the `revisor` to both networks, without restarting it.

## The why before the how

Until now every container in the course has been a disposable island. You created it, asked it something, deleted it. That was fine for learning, because a disposable container cannot hold surprises. But a real service has two needs that an island does not cover.

The first is **keeping something that lasts longer than it does**. The `revisor` writes a report; that report is exactly what someone is going to ask for on Monday. And a container is made to be replaced: every update, every configuration change, every machine reboot with `--rm` ends in a new container. Docker's documentation says it bluntly: what is written in the container layer "doesn't persist when the container is destroyed", and also "it can be difficult to get the data out of the container if another process needs it" ([Docker, "Storage"](https://docs.docker.com/engine/storage/)). If the report lives inside the container, it lives as long as the container does. And since Lesson 7 the problem is even more direct: the `revisor`'s file system is **read-only**. It is not that the report would be lost; it is that it cannot even be written. A writable place is needed, outside the container, that the `revisor` can use without ceasing to be read-only.

The second is **talking to other containers**. The `revisor` exists to check services, and until today it has only checked itself (`propio http://127.0.0.1:8080/salud`), because inside a container `127.0.0.1` is the container itself. To check the test service it needs to reach another container. It could use its IP address, but addresses are handed out by Docker at startup and change; nobody wants to write in `REVISOR_SERVICIOS` an address that stops being valid at the next restart. What you want is what any program on the internet does: use a **name**. And as soon as containers talk to each other, the lesson's security question appears: if the test service exists only for the `revisor` to query, why should it be able to reach the internet?

So the lesson has two halves, and both follow the same path: first the error, then the fix.

1. **Storage** (8.1 to 8.7): where a container writes, the three types of mount, the ownership error you will run into with an unprivileged user and its fix in the image, what happens to what was already in the folder, and `tmpfs` for what must not last.
2. **Networks** (8.8 to 8.11): the default network, which has no names; the network you define, which does; and the internal network, which has no way out.

With that destination in mind, here is what you will have at the end, in section 8.10: the test service on a network with no way out, the `revisor` on both, finding it by name, and a container that tries to reach the internet from the internal network and cannot even resolve the site's name:

```text
== 3. Conectar el revisor también a la interna, sin reiniciarlo
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
curso-docker-interna-fig08 curso-docker-red-fig08 

== 4. Desde la red interna no hay salida a internet
wget: bad address 'www.docker.com'
[código de salida: 1]
```

## The concepts

### 8.1 Where a container writes

#### 8.1.1 The writable layer, and why it is no good for saving

In Lesson 4 you saw that an image is a stack of read-only layers. When Docker creates a container, it puts on top **one more layer, writable and specific to that container**. Everything the process writes (a new file, a modified file, a deleted file) ends up in that layer; the image's layers are not touched, and that is why a hundred containers can come out of the same image without stepping on each other.

That layer has three problems for saving a report:

- **It dies with the container.** `docker rm` deletes it. `docker run --rm` deletes it on exit. An update that replaces the container throws it away.
- **It is hard to get anything out of it.** It sits somewhere in Docker's internal store, at a path that is not meant for you. Another container cannot read it.
- **In the hardened `revisor` it does not exist for writing.** With `--read-only`, the writable layer does not accept writes. It is exactly what you wanted in Lesson 7: whoever takes control of the process cannot write to disk. But neither can the `revisor` itself.

The way out is to **mount** something on top of a folder in the container: a writable place that is not part of the container's layer, that has its own lifecycle, and that is mounted only where it is needed. The rest of the file system stays read-only.

#### 8.1.2 The three types of mount

Docker offers three types of mount that interest you here (there are two others you will not use: named pipes, Windows only, and image mounts, which put the contents of another image inside the container and require containerd's image store). The documentation presents them like this ([Docker, "Storage"](https://docs.docker.com/engine/storage/)):

| Type | What it is | Where the data lives | How long it lasts | What it is for |
|---|---|---|---|---|
| **Volume** (named) | storage "managed by the Docker daemon" | in a folder in Docker's store, which you do not touch | until you delete the volume, even if you delete all the containers | service data that must last: the report |
| ***Bind mount*** | "a direct link" between a path on the host and one in the container | in a folder of yours, wherever you say | as long as that folder lasts | files that you and the container must both see: code under development, a configuration file, the token from Lesson 6 |
| **`tmpfs`** | files "directly in the memory" of the host | in memory | until the container stops | temporary files that must not last or touch the disk |

The same page gives the short recommendation: volumes are for long-term storage; *bind mounts*, "when you need to access files from both the container and the host"; and `tmpfs`, "only when the data does not need to persist beyond the container's session". In the `revisor` that translates into a simple rule: **the report goes in a volume**. You already used *bind mounts* for the token and you will use them today to understand the ownership problem; the `tmpfs`, for what must not survive.

#### 8.1.3 Two ways to write the same thing: `-v` and `--mount`

Docker accepts two syntaxes for mounting, and you will see them everywhere:

- **`-v source:destination[:options]`** (or `--volume`). Short. If the source is a name (`curso-docker-reportes`), it is a volume; if it is an absolute path (`/home/you/reportes`), it is a *bind mount*. The options go at the end, separated by commas: `ro` for read-only, for example.
- **`--mount type=…,src=…,dst=…[,options]`**. Long, with names in each field: `type=volume`, `type=bind`, or `type=tmpfs`, and then `src` (the source), `dst` (the destination), `readonly`, and the options specific to each type.

The volumes documentation says that "in general, `--mount` is preferred", because it is "more explicit and supports all the available options" ([Docker, "Volumes"](https://docs.docker.com/engine/storage/volumes/)). `--mount` supports all the options of each mount type; `-v` only some. For a volume, `-v` supports few: the access ones (`ro` and `rw`), the SELinux labeling ones (`z` and `Z`, which you do not need on Mint), and the one that skips copying the image's content, which you will see in 8.5. That second one has a measured trap: the volumes page calls it `volume-nocopy` with `-v` as well, but Docker 29.2.1 rejects that name with `invalid mode: volume-nocopy`; with `-v` it is written `nocopy` (`-v vol:/datos:nocopy`), and with `--mount`, `volume-nocopy`. You see it in `fig08_09.sh`, the solution to Exercise 4. And there is a difference in behavior that matters: when the host folder **does not exist**, `-v` creates it and `--mount`, by default, refuses (8.5). This course uses `-v` for named volumes, because it is what you will read in most examples and it is just as clear (`-v curso-docker-reportes:/datos` leaves no doubt), and `--mount` for *bind mounts* and `tmpfs`, where its precision prevents mistakes.

### 8.2 Named volumes

#### 8.2.1 Create, inspect, delete

A volume is created with `docker volume create <name>`, listed with `docker volume ls`, inspected with `docker volume inspect`, and deleted with `docker volume rm`. If in a `docker run` you mount a volume that does not exist, Docker creates it at that moment; even so, creating it beforehand with its name makes clear it is something you decided to have, not a side effect.

Volumes of the default driver, `local`, live in a folder on the host inside Docker's store: the documentation shows the path `/var/lib/docker/volumes/<name>/_data` ([Docker, "Volumes"](https://docs.docker.com/engine/storage/volumes/)). That folder belongs to Docker and to `root`. You can see it with `sudo`, but it is not meant to be touched by hand: to look inside a volume, the course uses a **helper container**, a disposable `alpine` that mounts the volume read-only and runs `ls` or `cat`. It works the same on Mint, on a Mac, or on a server, it needs no `sudo`, and there is no way for it to damage the data.

A volume is **not deleted** with the container. That is its reason for existing. Neither `docker rm`, nor `docker rm -f`, nor `docker stop` touches it. The only exception is **anonymous** volumes (those created without a name, for example with `-v /datos` with no source): the documentation says those are destroyed with the container only if you created it with `--rm` ([Docker, "Volumes"](https://docs.docker.com/engine/storage/volumes/)). A named volume lives until you delete it with `docker volume rm`. That is why the course always gives them a name, with the prefix `curso-docker-`: an anonymous volume is a 64-character identifier nobody remembers the owner of, and that ends up taking up disk forever.

### 8.3 The error: a new volume over a folder the image does not have

#### 8.3.1 Triggering it

With the above, the plan seems obvious: create a volume, mount it on `/datos`, tell the `revisor` to save its report there with `REVISOR_REPORTE=/datos/reporte.json`. The script `fig08_02.sh` does exactly that with the Lesson 7 image, hardened as you left it:

```bash
#!/usr/bin/env bash
# fig08_02.sh — El error: un volumen nuevo sobre una carpeta que la imagen NO trae.
# Construye el revisor de la Lección 7 (la 1.4.0, sin /datos), le monta un volumen
# con nombre recién creado en /datos y le pide guardar su reporte ahí.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.4.0,
# tu contenedor curso-docker-revisor ni tu volumen curso-docker-reportes, y al
# salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08-l7"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$NOMBRE-mira" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + el Dockerfile de la Lección 7.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/../07-salud-y-ciclo-de-vida/estado/Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
# Con el prefijo por omisión esto no cambia nada.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# El número del archivo temporal cambia en cada corrida: se tapa a la vista.
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. ¿La imagen de la Lección 7 trae una carpeta /datos?"
docker create --name "$NOMBRE-mira" "$IMAGEN" >/dev/null
docker export "$NOMBRE-mira" | tar -tv --numeric-owner | grep -c ' datos/' || true
docker rm "$NOMBRE-mira" >/dev/null

echo
echo "== 2. Un volumen con nombre, nuevo y vacío"
docker volume create "$VOLUMEN" | nombres
docker volume inspect --format 'Driver={{.Driver}} Mountpoint={{.Mountpoint}}' "$VOLUMEN" | nombres

echo
echo "== 3. El revisor de la Lección 7, endurecido, con el volumen en /datos"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -v "$VOLUMEN":/datos -e REVISOR_REPORTE=/datos/reporte.json \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
echo "-- /salud no escribe nada, así que sigue contestando:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/salud"

echo
echo "== 4. ¿De quién es /datos? Lo mira un contenedor ayudante, de solo lectura"
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
echo "-- y el revisor corre como:"
docker inspect --format '{{.Config.User}}' "$NOMBRE"
```

```text
$ ./fig08_02.sh
== 1. ¿La imagen de la Lección 7 trae una carpeta /datos?
0

== 2. Un volumen con nombre, nuevo y vacío
curso-docker-reportes-fig08
Driver=local Mountpoint=/var/lib/docker/volumes/curso-docker-reportes-fig08/_data

== 3. El revisor de la Lección 7, endurecido, con el volumen en /datos
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
-- /salud no escribe nada, así que sigue contestando:
{"estado":"vivo","version":"1.4.0"}
 [200]

== 4. ¿De quién es /datos? Lo mira un contenedor ayudante, de solo lectura
drwxr-xr-x    2 0        0             4096 Oct 21 09:58 /datos
-- y el revisor corre como:
65532:65532
```

The new lines in the script, before reading the output. `docker create` creates a container without starting it, and `docker export` pulls out its entire file system as a `tar` archive; `tar -tv` lists it without unpacking, and `--numeric-owner` shows owners as numbers. It is the way to look at **which folders an image has** when it has no *shell* to run `ls`. `docker volume inspect` shows what Docker knows about a volume. And `-v "$VOLUMEN":/datos:ro` in the helper mounts the volume read-only: the helper only looks.

Now the output, block by block:

1. **The Lesson 7 image has no `/datos`.** The count of `tar` lines ending in ` datos/` is `0`. Nobody created it: in Lesson 7 the report went to `/tmp`.
2. **The volume is new and empty.** Its driver is `local` and it lives at `/var/lib/docker/volumes/curso-docker-reportes-fig08/_data`, the path the documentation gives.
3. **The `revisor` starts, answers `/salud`, and fails when saving.** `/api/estados` answers `500` with `permission denied` when opening the report's temporary file. (Recall from Lesson 3 that the `revisor` first writes a temporary file in the same folder and then renames it: that is why the error mentions `.reporte-<n>.tmp` and not `reporte.json`.) `/salud` stays at `200`, because it writes nothing; and since the `HEALTHCHECK` uses `/salud`, Docker would say this container is `healthy`. Running, healthy as far as Docker knows, and unable to do its job: the course's second principle, once again.
4. **The folder belongs to `root`.** The helper shows `/datos` with owner `0` and group `0`, permissions `drwxr-xr-x`: only the owner writes. And the `revisor` runs as `65532:65532`.

#### 8.3.2 Why it happens

When you mount a volume on a path the image does not have, Docker has to create that mount point, and the new volume is born with a root folder that belongs to `root`. Nobody told it otherwise. As long as the container's process was `root` (as in so many tutorials), this went unnoticed: `root` writes wherever it wants. But the `revisor` stopped being `root` in Lesson 3, and an unprivileged user does not bypass anyone's permissions. So the kernel does what it would do with any user on your machine trying to write in someone else's folder: it refuses.

It is the same error as in Lesson 6 with the token file, in another form. There the file was yours and the process was `65532`; here the folder belongs to `root` and the process is `65532`. The question that solves it is the same: **who is the owner, and which user does the process run as?**

There are three fixes you will see on the internet, and only one is good:

- **Run as `root`** (`--user 0`). It works and undoes the work of five lessons. No.
- **Change the volume's owner from outside**, with a helper container that runs `chown 65532:65532 /datos` before starting the `revisor`. It works, but it is one more step that someone has to remember on every machine, and a container that runs as `root` just for that.
- **Have the image bring the folder, with the correct owner.** It is this lesson's fix, and it works because of a rule of volumes explained in 8.4.

### 8.4 The fix: the image brings `/datos`, owned by the right user

#### 8.4.1 The rule that makes it possible

The volumes documentation describes what happens when you mount an **empty** volume on a container folder that **already has** files or folders: "those files or folders are propagated (copied) to the volume" ([Docker, "Volumes"](https://docs.docker.com/engine/storage/volumes/)). The documentation talks about the content; what it does not say, and you will measure in 8.4.3, is that the copy also carries the owner and permissions of the image's folder. If the image brings `/datos` owned by `65532`, a new volume mounted there is born owned by `65532`. The fix, then, is not in the `docker run`: it is in the Dockerfile.

#### 8.4.2 This lesson's Dockerfile

This is the Dockerfile the lesson ends with. It is Lesson 7's with three changes, marked below:

```dockerfile
# syntax=docker/dockerfile:1
# fig08_01.Dockerfile — Lección 8: la imagen trae la carpeta /datos, con el dueño
# correcto, para que un volumen nuevo herede ese dueño. Parte de la Lección 7.

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
      -o /out/revisor ./cmd/revisor \
 && mkdir -p /out/datos

FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
ARG VERSION=desarrollo
LABEL org.opencontainers.image.title="revisor" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://www.habil.mx/es/cursos/docker/"
# ENV solo para valores por omisión que NO son secretos.
ENV REVISOR_PUERTO=8080 \
    REVISOR_REPORTE=/datos/reporte.json
COPY --from=binario /out/revisor /revisor
# La carpeta de datos, del usuario sin privilegios. Un volumen con nombre que se
# monte aquí por primera vez copia este dueño.
COPY --from=binario --chown=65532:65532 /out/datos /datos
USER 65532:65532
EXPOSE 8080
# La salud la revisa el propio binario: la imagen no tiene shell ni curl.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/revisor", "healthcheck"]
# Señal de apagado explícita (es la de omisión; escribirla documenta la intención).
STOPSIGNAL SIGTERM
ENTRYPOINT ["/revisor"]
```

The three changes:

1. **`&& mkdir -p /out/datos` in the `binario` stage.** It creates an empty folder next to the binary. It is created in the build stage because the final image, *distroless*, has no *shell* or `mkdir`: there is nothing to create a folder with there. It is added to the same `RUN` that compiles so as not to add one more layer to that stage; it makes no difference in the final image, which only receives what is copied.
2. **`COPY --from=binario --chown=65532:65532 /out/datos /datos` in the `final` stage.** It copies that empty folder to `/datos` and sets its owner and group to `65532`. According to the Dockerfile reference, `--chown` "sets the owner of the copied files", and without that option they end up with user and group `0` ([Dockerfile reference](https://docs.docker.com/reference/dockerfile/)). Numbers are used and not names because the final image has no reason to know who `nonroot` is; the number is what the kernel compares.
3. **`REVISOR_REPORTE=/datos/reporte.json` in the `ENV`.** The default value of where the report is saved. It is configuration, not a secret (Lesson 6), and it works in any environment, because the image brings the folder. Whoever runs the image without saying anything saves to `/datos`, and if they mount a volume there, the report lasts.

That third change has a consequence worth seeing before it surprises you. Image 1.5.0 **expects** `/datos` to be writable. If you run it with `--read-only` and **without** a volume, as in Lesson 7, `/api/estados` fails again, now with `read-only file system`. You will see it in block 6 of `fig08_03.sh`, in 8.4.3.

It is not a defect: it is the image telling you where it saves. From this lesson on, the hardened `revisor` is run with something writable mounted on `/datos`: almost always a named volume, and a *bind mount* when another tool on the host has to read the reports (8.6). You will see it in all the scripts that follow, including the network ones, and in Lesson 9's `compose.yaml`.

#### 8.4.3 Watching it work, and watching it survive

The script `fig08_03.sh` builds image 1.5.0, looks at its `/datos`, mounts a new volume on it, and then deletes the container to see what is left:

```bash
#!/usr/bin/env bash
# fig08_03.sh — El arreglo: la imagen 1.5.0 trae /datos del usuario 65532, y un
# volumen nuevo copia ese dueño. Después, el reporte sobrevive a docker rm, y un
# volumen en uso no se deja borrar.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0,
# tu contenedor curso-docker-revisor ni tu volumen curso-docker-reportes, y al
# salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$NOMBRE-mira" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# Los identificadores de contenedor cambian en cada corrida: se tapan a la vista.
tapar_id() { sed -E 's/[0-9a-f]{64}/<id>/g'; }
revisor() {
  docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
    -v "$VOLUMEN":/datos -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
}

echo "== 1. Construir la 1.5.0 y mirar /datos dentro de la imagen"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null
docker image ls "$IMAGEN" --format 'tamaño: {{.Size}}'
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGEN" | grep REVISOR
docker create --name "$NOMBRE-mira" "$IMAGEN" >/dev/null
docker export "$NOMBRE-mira" | tar -tv --numeric-owner | grep ' datos/' | awk '{print $1, $2, $NF}'
docker rm "$NOMBRE-mira" >/dev/null

echo
echo "== 2. Un volumen nuevo, montado en /datos: hereda el dueño de la imagen"
docker volume create "$VOLUMEN" >/dev/null
revisor
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -ln /datos

echo
echo "== 3. Un volumen en uso no se deja borrar"
salida=$(docker volume rm "$VOLUMEN" 2>&1) && rc=0 || rc=$?
echo "$salida" | nombres | tapar_id
echo "[código de salida: $rc]"

echo
echo "== 4. Borrar el contenedor: el volumen se queda, y el reporte con él"
docker rm -f "$NOMBRE" >/dev/null
echo "contenedores con ese nombre: $(docker ps -a --filter "name=^${NOMBRE}\$" --format '{{.Names}}' | wc -l)"
docker volume ls --filter "name=^${VOLUMEN}\$" --format 'volumen: {{.Name}} ({{.Driver}})' | nombres
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" cat /datos/reporte.json

echo
echo "== 5. Un contenedor nuevo con el mismo volumen sigue donde iba el otro"
revisor
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -ln /datos | awk 'NR>1 {print $1, $3, $4, $NF}'
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker inspect --format '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE" | nombres
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 6. La 1.5.0 endurecida SIN volumen en /datos: la raíz es de solo lectura"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'
```

```text
$ ./fig08_03.sh
== 1. Construir la 1.5.0 y mirar /datos dentro de la imagen
tamaño: 16.2MB
REVISOR_PUERTO=8080
REVISOR_REPORTE=/datos/reporte.json
drwxr-xr-x 65532/65532 datos/

== 2. Un volumen nuevo, montado en /datos: hereda el dueño de la imagen
/api/estados: [200]
drwxr-xr-x    2 65532    65532         4096 Oct 21 13:10 /datos
total 4
-rw-------    1 65532    65532           92 Oct 21 13:10 reporte.json

== 3. Un volumen en uso no se deja borrar
Error response from daemon: remove curso-docker-reportes-fig08: volume is in use - [<id>]
[código de salida: 1]

== 4. Borrar el contenedor: el volumen se queda, y el reporte con él
contenedores con ese nombre: 0
volumen: curso-docker-reportes-fig08 (local)
[
  {
    "servicio": "propio",
    "ok": true,
    "codigo": 200,
    "tiempo_ms": 1
  }
]

== 5. Un contenedor nuevo con el mismo volumen sigue donde iba el otro
-rw------- 65532 65532 reporte.json
/api/estados: [200]
volume curso-docker-reportes-fig08 -> /datos (escribible: true)

== 6. La 1.5.0 endurecida SIN volumen en /datos: la raíz es de solo lectura
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

Block by block:

1. **The image weighs 16.2 MB**; Lesson 7's 1.4.0 measured 16.1 MB. An empty folder weighs almost nothing: the difference is rounding. Its environment carries the two default values, `REVISOR_PUERTO=8080` and `REVISOR_REPORTE=/datos/reporte.json`. And the `tar` of its file system already shows `datos/` owned by `65532/65532`.
2. **The new volume inherited the owner.** `/api/estados` answers `200`. The helper shows `/datos` with owner `65532`, not `0`: it is the copy from 8.4.1. Inside is `reporte.json`, owned by `65532`, with permissions `-rw-------`: only its owner reads and writes it. (That `600` is decided by the `revisor`: it creates the temporary file with Go's `os.CreateTemp` function, which uses those permissions, and then renames it. The helper can read it because it runs as `root`.) The number of bytes depends on how many services it checks.
3. **A volume in use cannot be deleted.** `docker volume rm` exits with code `1` and tells you who is using it: `volume is in use`, with the container's identifier in brackets. It is a safeguard: you cannot pull the floor out from under a container that is writing.
4. **The container goes away; the volume and the report stay.** After `docker rm -f`, there is no container with that name, the volume is still in the list, and the helper reads the full report: one service, `propio`, healthy, with code `200` (the time changes on every run). This is what was missing on Monday morning.
5. **A new container picks up the volume.** The `revisor` is born again, finds the previous report in place, replaces it with the next check (`200`), and `docker inspect` shows the mount: `volume curso-docker-reportes-fig08 -> /datos (escribible: true)`. The container's file system is still read-only; `/datos` is the only exception, and it has a name.
6. **Without the volume, the hardened 1.5.0 cannot save.** It is the consequence of 8.4.2: `read-only file system` and `500`. The image already says where it saves; whoever runs it with `--read-only` has to give it that place.

#### 8.4.4 In your folder

Your project has lived in `~/curso-docker/revisor` since Lesson 3. From the root of the course repository, put this lesson's Dockerfile there, build the image you are going to keep, and create your volume:

```bash
cp programas/08-volumenes-y-redes/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.5.0 -t curso-docker-revisor:1.5.0 .
docker volume create curso-docker-reportes
```

The `.dockerignore` and the `secretos/` folder do not change. Before continuing, repeat the error and the fix by hand with your own names: run `curso-docker-revisor:1.4.0` with a freshly created volume on `/datos` and `-e REVISOR_REPORTE=/datos/reporte.json`, and look at the `500`; delete it along with that volume; and run `curso-docker-revisor:1.5.0` with `curso-docker-reportes`. The only thing that changes relative to the scripts is the names. This lesson's scripts do not touch any of this: they use helper names with `fig08` and delete only their own.

### 8.5 Copying versus hiding: what was already in the folder

#### 8.5.1 Four cases worth not confusing

The rule in 8.4.1 has conditions, and almost every scare with mounts comes from forgetting them. When you mount something over a container folder that already has content, one of these things happens:

| What you mount | What the container sees | What happens to the image's content |
|---|---|---|
| a **new, empty** volume | the image's content | it is **copied** to the volume, with owners and permissions |
| a new volume with `volume-nocopy` | an empty folder | it is not copied; it stays hidden |
| a volume **that already has data** | what is in the volume | it is **hidden**; nothing is copied |
| a ***bind mount*** | what is in the host folder | it is **hidden**; nothing is copied |

"Hidden" is the documentation's word: if you mount a volume with data where there were already files, "the pre-existing files are obscured by the mount" ([Docker, "Volumes"](https://docs.docker.com/engine/storage/volumes/)); with a *bind mount*, "the existing content of the directory is obscured" ([Docker, "Bind mounts"](https://docs.docker.com/engine/storage/bind-mounts/)). They are not deleted: they remain in the image layer, underneath, and reappear if you run a container without the mount. But as long as the mount is there, the container does not see them.

Notice the third row, because it has a practical consequence: the copy happens **only the first time**, when the volume is empty. If the volume `curso-docker-reportes` was created with image 1.5.0 and tomorrow an image 1.6.0 brings something different in `/datos`, the volume is not updated: it already has data, so the volume wins. For a report that is exactly what you want (the service's data should not change because the image changed). For someone who keeps in a volume files that should come from the image, it is a classic source of "I updated and it's still the same".

#### 8.5.2 Seeing it with a helper container

The script `fig08_04.sh` shows the four cases with the `alpine` helper, on its `/etc/apk` folder, which has five entries. At the end it tests the difference between `-v` and `--mount` with a host folder that does not exist:

```bash
#!/usr/bin/env bash
# fig08_04.sh — Copiar contra tapar. Un volumen NUEVO montado sobre una carpeta
# con contenido recibe una copia de ese contenido; un bind mount, en cambio, la
# tapa. Y la diferencia entre -v y --mount cuando la carpeta del equipo no existe.
# No construye nada: usa el contenedor ayudante alpine:3.24.2.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus volúmenes del curso, y al
# salir borra solo lo que creó.
TRABAJO="$(mktemp -d)"
VOLUMEN="${PREFIJO}copia-fig08"
VOLUMEN_SIN_COPIA="${PREFIJO}sin-copia-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker volume rm "$VOLUMEN" "$VOLUMEN_SIN_COPIA" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT
cd "$TRABAJO"
# La ruta de la carpeta temporal cambia en cada corrida: se escribe como «.».
tapar_ruta() { sed "s#$TRABAJO#.#g"; }

echo "== 1. La carpeta /etc/apk de la imagen, sin montar nada"
docker run --rm "$AYUDANTE" ls /etc/apk

echo
echo "== 2. Un volumen NUEVO montado ahí: el contenedor ve lo mismo..."
docker run --rm -v "$VOLUMEN":/etc/apk "$AYUDANTE" ls /etc/apk
echo "-- ...porque Docker copió el contenido al volumen. Míralo montado en otra ruta:"
docker run --rm -v "$VOLUMEN":/mirar:ro "$AYUDANTE" ls /mirar

echo
echo "== 3. Lo mismo con volume-nocopy: el volumen se queda vacío"
docker run --rm --mount type=volume,src="$VOLUMEN_SIN_COPIA",dst=/etc/apk,volume-nocopy \
  "$AYUDANTE" ls /etc/apk | wc -l

echo
echo "== 4. Un bind mount de una carpeta vacía del equipo: tapa lo de la imagen"
mkdir vacia
docker run --rm --mount type=bind,src="$TRABAJO/vacia",dst=/etc/apk "$AYUDANTE" ls /etc/apk | wc -l
echo "-- y en el equipo, la carpeta sigue vacía: no se copió nada en ningún sentido"
ls vacia | wc -l

echo
echo "== 5. -v con una carpeta del equipo que NO existe: Docker la crea... como root"
docker run --rm -v "$TRABAJO/no-existia":/datos "$AYUDANTE" true
stat -c '%U:%G %n' no-existia

echo
echo "== 6. --mount con una carpeta que no existe: se niega"
docker run --rm --mount type=bind,src="$TRABAJO/tampoco-existe",dst=/datos "$AYUDANTE" true 2>&1 | tapar_ruta
echo "[código de salida: ${PIPESTATUS[0]}]"
```

```text
$ ./fig08_04.sh
== 1. La carpeta /etc/apk de la imagen, sin montar nada
arch
keys
protected_paths.d
repositories
world

== 2. Un volumen NUEVO montado ahí: el contenedor ve lo mismo...
arch
keys
protected_paths.d
repositories
world
-- ...porque Docker copió el contenido al volumen. Míralo montado en otra ruta:
arch
keys
protected_paths.d
repositories
world

== 3. Lo mismo con volume-nocopy: el volumen se queda vacío
0

== 4. Un bind mount de una carpeta vacía del equipo: tapa lo de la imagen
0
-- y en el equipo, la carpeta sigue vacía: no se copió nada en ningún sentido
0

== 5. -v con una carpeta del equipo que NO existe: Docker la crea... como root
root:root no-existia

== 6. --mount con una carpeta que no existe: se niega
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: ./tampoco-existe

Run 'docker run --help' for more information
[código de salida: 125]
```

Block by block:

1. **Without a mount**, `/etc/apk` has five entries: `arch`, `keys`, `protected_paths.d`, `repositories`, and `world`.
2. **With a new volume**, the container sees the same five. And it is not that it sees the image's "through" the volume: mounted at another path (`/mirar`), in a different container, the volume has them. Docker copied them when it mounted it for the first time.
3. **With `volume-nocopy`**, zero entries. The option tells Docker not to copy even though the volume is empty ([Docker, "Volumes"](https://docs.docker.com/engine/storage/volumes/)); it also exists with `-v`, but is written `nocopy` (8.1.3). If you ever see it in one of the `revisor`'s `docker run` commands, you already know what will happen: the volume is born with its `root` folder, as in 8.3, and the `permission denied` returns. You will check it in Exercise 4.
4. **With a *bind mount* of an empty folder**, zero entries: the image's content was hidden. And the host folder remains empty: a *bind mount* copies nothing in either direction. The container sees **your folder**, as it is, and nothing else.
5. **`-v` with a host path that does not exist**: the container starts without complaint, and on your machine the folder `no-existia` appears... owned by `root:root`. The daemon created it, and it runs as `root`. The documentation puts it this way: with `-v`, "Docker creates the directory on the host for you" ([Docker, "Bind mounts"](https://docs.docker.com/engine/storage/bind-mounts/)). What it does not say as loudly is the owner, and that is what bites: a typo in the path leaves you with a `root` folder in your project, a container writing in the wrong place, and, if the process is not `root`, another `permission denied`.
6. **`--mount` with a path that does not exist**: it refuses. `invalid mount config for type "bind": bind source path does not exist`, with code `125`, the one `docker run` uses when the error is Docker's own and not the program's. It is the behavior you want: a typo shows up immediately. (The path appears as `./tampoco-existe` because the script masks the temporary folder, which changes on every run.) It is the default behavior: `--mount` can also create the folder if you ask with the `bind-create-src` option, which according to the documentation "automatically creates the source directory on the host if it does not exist" ([Docker, "Bind mounts"](https://docs.docker.com/engine/storage/bind-mounts/)). This course does not use it, because what it wants is precisely for the typo to show. That is why it uses `--mount` for *bind mounts*.

### 8.6 *Bind mounts* and file ownership

#### 8.6.1 When a *bind mount* and not a volume

A *bind mount* is useful when you, from your machine, need to see or place the files without going through Docker: the code of a program while you develop it, a configuration file you edit by hand, the token from Lesson 6, or a report that another tool on your machine is going to pick up. The price is that the container writes **directly to your file system**. The documentation warns about it: with a *bind mount* "you can change the host file system from processes running in a container", and *bind mounts* have, by default, "write access to the host files" ([Docker, "Bind mounts"](https://docs.docker.com/engine/storage/bind-mounts/)). That is why, when the container only needs to read, the mount goes with `readonly`, like the token.

#### 8.6.2 The same error, from the opposite side

With a volume, the folder belonged to `root` and the fix was for the image to bring its own. With a *bind mount* that does not work: the container sees **your** folder, with **your** owner, and whatever the image brings in `/datos` is hidden (8.5). So the clash returns, now between your user and `65532`. The script `fig08_05.sh` triggers it and fixes it without `root`:

```bash
#!/usr/bin/env bash
# fig08_05.sh — Bind mount: la carpeta es tuya, el proceso es 65532. Primero el
# error de permisos; después el arreglo sin root (correr con TU usuario); y al
# final el mismo montaje de solo lectura.
# Córrelo en el disco propio de Linux: una carpeta compartida con otro sistema
# miente con los dueños y los permisos.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
SERVICIOS='propio http://127.0.0.1:8080/salud'
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. Una carpeta tuya en el equipo"
mkdir reportes
stat -c '%u:%g %a %n' reportes
echo "tu usuario: $(id -u):$(id -g)"

echo
echo "== 2. Montada en /datos con un bind mount; el revisor corre como 65532"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. El arreglo sin root: correr el contenedor con TU usuario"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
echo "-- el reporte, visto desde el equipo, sin docker ni sudo:"
stat -c '%u:%g %a %n' reportes/reporte.json
head -c 60 reportes/reporte.json | tr -d '\n '; echo " …"
echo "-- lo que anotó Docker:"
docker inspect --format 'User={{.Config.User}}{{range .Mounts}} | {{.Type}} -> {{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 4. El mismo bind mount, de solo lectura"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos,readonly \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
```

```text
$ ./fig08_05.sh
== 1. Una carpeta tuya en el equipo
501:1000 775 reportes
tu usuario: 501:1000

== 2. Montada en /datos con un bind mount; el revisor corre como 65532
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]

== 3. El arreglo sin root: correr el contenedor con TU usuario
/api/estados: [200]
-- el reporte, visto desde el equipo, sin docker ni sudo:
501:1000 600 reportes/reporte.json
[{"servicio":"propio","ok":true,"codigo" …
-- lo que anotó Docker:
User=501:1000 | bind -> /datos (escribible: true)

== 4. El mismo bind mount, de solo lectura
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

Block by block:

1. **The folder is yours**: owner `501:1000`, permissions `775` (you and your group write; others do not). On your Mint it will say `1000:1000`. The script prints your user so you can compare.
2. **Mounted on `/datos`, `permission denied`.** The `revisor` runs as `65532`, which is neither the owner nor in group `1000`, and for "others" the folder is not writable. The mount translates nothing: inside the container the folder has the same numeric owner as outside. (With rootless Docker or with user remapping, the number inside is translated to another outside; the installation from Lesson 1 does not do that.)
3. **The fix: run the container with your user.** `--user "$(id -u):$(id -g)"` replaces the image's `65532` with your numbers, and now the process is the folder's owner: `200`. And the report, seen from your machine, is yours (`501:1000`, `600`): you read it without `docker` and without `sudo`. Notice what did **not** change: the process is still not `root`, still has no capabilities, and the file system is still read-only. You swapped one unprivileged user for another unprivileged user, yours. Watch out: if you run the command with `sudo`, `$(id -u)` is `0` and you would be running as `root` without realizing it. That is why in Lesson 1 you joined the `docker` group: these commands go without `sudo`. `docker inspect` confirms it: `User=501:1000`, and the mount `bind -> /datos (escribible: true)`.
4. **Read-only, the kernel refuses.** With `readonly`, the `revisor` fails again, now with `read-only file system`: not even being the owner can it write. For the report that makes no sense, but it is exactly what you want for a configuration file or a secret: the container reads it and cannot change it.

Why not `chmod 777` on the folder? Because it lets **any user on your machine** write there, and any container with any user fill it up. It is the folder version of Lesson 6's `644`, but worse, because here things are written, not just read. `--user` with your numbers solves the problem where it is born: the owner.

### 8.7 `tmpfs`: what must not last

#### 8.7.1 What it is for

In Lesson 7 you used `--tmpfs /tmp` so the `revisor` could write its report with the file system read-only. It worked, and the report died with the container. Now the report has its volume, but the `tmpfs` still has a place: everything a program writes and **must not** survive. Temporary files, caches that last a single run, a file with a decrypted secret that must not touch the disk. The documentation sums it up: unlike volumes and *bind mounts*, a `tmpfs` "is temporary and only persisted in the host memory", and "when the container stops, the tmpfs mount is removed" ([Docker, "tmpfs mounts"](https://docs.docker.com/engine/storage/tmpfs/)). It cannot be shared between containers either.

Two default values from that page worth knowing: without a size, a `tmpfs`'s cap is **half of the host's memory**, and its permission is `1777`, writable by anyone (with the bit that prevents deleting other people's files, the same as `/tmp` on your Mint). And an honest warning: the kernel may send what is in a `tmpfs` to swap, so "in memory" is no guarantee that it never touches the disk.

#### 8.7.2 Volume and `tmpfs`, side by side

The script `fig08_06.sh` runs a read-only container with both mounts, writes to both, restarts it, and looks at what survived:

```bash
#!/usr/bin/env bash
# fig08_06.sh — tmpfs contra volumen. Un contenedor de solo lectura con dos
# lugares escribibles: un volumen en /datos y un tmpfs de 1 MB en /cache. Escribe
# en los dos, se reinicia, y se ve qué sobrevivió. También el tope del tmpfs.
# No construye nada: usa el contenedor ayudante alpine:3.24.2.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores ni tus
# volúmenes del curso, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}ayudante-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true' EXIT
# en COMANDO: corre COMANDO con sh dentro del contenedor y avisa si falló
en() { docker exec "$NOMBRE" sh -c "$1" 2>&1 || echo "[código de salida: $?]"; }

echo "== 1. Solo lectura, con un volumen en /datos y un tmpfs en /cache"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --mount type=volume,src="$VOLUMEN",dst=/datos \
  --mount type=tmpfs,dst=/cache,tmpfs-size=1m \
  "$AYUDANTE" sleep 300 >/dev/null
echo "-- dónde está montado cada uno, de qué tipo y con qué opciones:"
en 'awk "\$2 == \"/datos\" || \$2 == \"/cache\" {print \$2, \$3, \$4}" /proc/mounts'
en 'stat -c "%a %n" /cache'

echo
echo "== 2. Escribir en los dos, y en la raíz"
en 'echo reporte > /datos/a.txt && echo temporal > /cache/b.txt && ls /datos /cache'
en 'echo hola > /c.txt'

echo
echo "== 3. El tmpfs tiene tope: 2 MB no caben en 1 MB"
en 'dd if=/dev/zero of=/cache/grande bs=1k count=2000 2>&1 | head -1'
en 'rm -f /cache/grande'

echo
echo "== 4. Reiniciar el contenedor"
docker restart -t 2 "$NOMBRE" >/dev/null
en 'ls /datos; echo "-- /cache tiene $(ls /cache | wc -l) archivos"'
```

```text
$ ./fig08_06.sh
== 1. Solo lectura, con un volumen en /datos y un tmpfs en /cache
-- dónde está montado cada uno, de qué tipo y con qué opciones:
/cache tmpfs rw,nosuid,nodev,noexec,relatime,size=1024k,inode64
/datos ext4 rw,relatime,discard,errors=remount-ro,commit=30
1777 /cache

== 2. Escribir en los dos, y en la raíz
/cache:
b.txt

/datos:
a.txt
sh: can't create /c.txt: Read-only file system
[código de salida: 1]

== 3. El tmpfs tiene tope: 2 MB no caben en 1 MB
dd: error writing '/cache/grande': No space left on device

== 4. Reiniciar el contenedor
a.txt
-- /cache tiene 0 archivos
```

1. **The two mounts and their options**, read from `/proc/mounts`, the list the kernel keeps. `/datos` is `ext4`: the volume lives on the host's disk. `/cache` is `tmpfs`, with `size=1024k` (the `1m` you asked for) and three options Docker added on its own when mounting it with `--mount`: `nosuid`, `nodev`, and `noexec`. In Lesson 7 you wrote them by hand with `--tmpfs`; with `--mount type=tmpfs` they come by themselves. The permission is `1777`.
2. **You can write to both and not to the root.** `a.txt` in the volume, `b.txt` in the `tmpfs`; and `/c.txt` fails with `Read-only file system`, because outside the mounts everything is read-only. Three folders, three behaviors, and you asked for each one by name.
3. **The `tmpfs` has a cap.** Writing 2 MB to a 1 MB `tmpfs` ends in `No space left on device`. Without `size`, that cap would be half of the host's memory: a buggy program that writes nonstop could take up much more than you imagined. With the cap, the error appears right away and with a clear message.
4. **After `docker restart`, the volume keeps `a.txt` and the `tmpfs` is empty.** A restart is enough to wipe the `tmpfs`; you do not need to delete the container.

The documentation prefers `--mount type=tmpfs` and acknowledges that `--tmpfs` "is less verbose" and supports more mount options ([Docker, "tmpfs mounts"](https://docs.docker.com/engine/storage/tmpfs/)). Both work. What matters is setting a size.

#### 8.7.3 Which one to use, in the `revisor`

| Data | Mount | Why |
|---|---|---|
| the report (`/datos/reporte.json`) | named volume at `/datos` | it has to survive the container; nobody needs to edit it by hand |
| the token (`/run/secrets/revisor_token`) | *bind mount* of a file, `readonly` | you place it from outside; the container only reads it |
| a temporary file the program should not keep | `tmpfs` with a size | it must die with the container and not take up disk |
| the program's code | none: it goes in the image | it is code, not data (Lesson 6) |

### 8.8 Networks: the default network has no names

#### 8.8.1 What a Docker network is

Each container has its own network stack: its interfaces, its IP address, its routing table, its `127.0.0.1`. It is one of the isolations from Lesson 0. For containers to talk to each other, Docker connects them to **networks**: underneath, on Linux, a virtual bridge (*bridge*) to which one interface of each container is attached, like cables plugged into the same switch. The default driver is called, precisely, `bridge`.

Docker creates three networks when it is installed, `bridge`, `host`, and `none` (you see them with `docker network ls`), and if you say nothing else, every container is connected to `bridge`. That is where every container in the course has been until today. That network has a limitation the documentation states plainly: on the default network, containers "can only access each other by IP address". Moreover: "the default `bridge` network is considered a legacy detail of Docker and is not recommended for production use" ([Docker, `bridge` driver](https://docs.docker.com/engine/network/drivers/bridge/)).

#### 8.8.2 Seeing it: by name no, by IP yes

The script `fig08_07.sh` puts the `revisor` and the test service on the default network, and asks the `revisor` to check `http://curso-docker-prueba-fig08:9000/`. Then it does the same on a user-defined network, and at the end it breaks the test service from another container:

```bash
#!/usr/bin/env bash
# fig08_07.sh — Redes. En la red por omisión, el revisor no encuentra al servicio
# de prueba por su nombre (por IP sí). En una red definida por el usuario, sí lo
# encuentra, porque ahí hay un DNS. Y al romper el servicio, el reporte lo ve.
# Usa tu imagen curso-docker-prueba:1.0.0 (de la Lección 2) sin modificarla.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores, tus redes
# ni tus imágenes del curso, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
PRUEBA="${PREFIJO}prueba-fig08"
RED="${PREFIJO}red-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
IMAGEN_PRUEBA=curso-docker-prueba:1.0.0
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null 2>&1 || true
      docker network rm "$RED" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

docker image inspect "$IMAGEN_PRUEBA" >/dev/null 2>&1 \
  || { echo "falta $IMAGEN_PRUEBA: constrúyela como en la Lección 2"; exit 1; }
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# Lo que depende de cada equipo se tapa a la vista: los tiempos de la tabla, la
# dirección del DNS del anfitrión y las direcciones IP de los contenedores.
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" \
    | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /; s/on [0-9.]+:53/on <DNS del anfitrión>:53/' | nombres
}
tapar_ip() { sed -E 's/(^|[^0-9])(10|172|192)\.[0-9]+\.[0-9]+\.[0-9]+/\1<IP>/g'; }
revisor() {  # revisor [opciones de red]
  docker run -d --name "$NOMBRE" "$@" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO -v "$VOLUMEN":/datos \
    -e REVISOR_SERVICIOS="prueba http://$PRUEBA:9000/ 2s" "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
}

echo "== 1. Los dos en la red por omisión (bridge): por nombre, no"
docker run -d --name "$PRUEBA" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
revisor
tabla
echo "-- la red de cada uno:"
docker inspect --format '{{.Name}}: {{range $red, $v := .NetworkSettings.Networks}}{{$red}}{{end}}' "$NOMBRE" "$PRUEBA" | nombres
echo "-- el DNS que reciben los contenedores de esa red es el del anfitrión:"
docker run --rm "$AYUDANTE" grep nameserver /etc/resolv.conf | sed -E 's/[0-9.]+$/<DNS del anfitrión>/' | head -1
echo "-- por IP, en cambio, sí llega:"
IP=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PRUEBA")
echo "IP del servicio de prueba: $IP" | tapar_ip
docker run --rm "$AYUDANTE" wget -qO- "http://$IP:9000/"
docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null

echo
echo "== 2. Una red definida por el usuario"
docker network create "$RED" >/dev/null
docker network inspect --format '{{.Name}} driver={{.Driver}} interna={{.Internal}}' "$RED" | nombres
docker run -d --name "$PRUEBA" --network "$RED" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
revisor --network "$RED"
tabla
echo "-- en esta red, el DNS es el que Docker pone dentro de cada contenedor:"
docker run --rm --network "$RED" "$AYUDANTE" grep nameserver /etc/resolv.conf
docker run --rm --network "$RED" "$AYUDANTE" nslookup "$PRUEBA" 2>&1 \
  | grep -E '^(Server|Name|Address)' | nombres | tapar_ip
echo "-- quién está conectado a la red:"
docker network inspect --format '{{range .Containers}}{{.Name}}{{println}}{{end}}' "$RED" | sed '/^$/d' | sort | nombres

echo
echo "== 3. Romper el servicio de prueba desde otro contenedor de la misma red"
docker run --rm --network "$RED" "$AYUDANTE" wget -qO- --post-data= "http://$PRUEBA:9000/modo/caido"
tabla
```

```text
$ ./fig08_07.sh
== 1. Los dos en la red por omisión (bridge): por nombre, no
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53: no such host
-- la red de cada uno:
/curso-docker-revisor-fig08: bridge
/curso-docker-prueba-fig08: bridge
-- el DNS que reciben los contenedores de esa red es el del anfitrión:
nameserver <DNS del anfitrión>
-- por IP, en cambio, sí llega:
IP del servicio de prueba: <IP>
sano

== 2. Una red definida por el usuario
curso-docker-red-fig08 driver=bridge interna=false
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
-- en esta red, el DNS es el que Docker pone dentro de cada contenedor:
nameserver 127.0.0.11
Server:		127.0.0.11
Address:	127.0.0.11:53
Name:	curso-docker-prueba-fig08
Address: <IP>
-- quién está conectado a la red:
curso-docker-prueba-fig08
curso-docker-revisor-fig08

== 3. Romper el servicio de prueba desde otro contenedor de la misma red
modo: caido
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA         <t>  codigo 503
```

The first half of the output, the default network:

1. **`FALLA`, with `no such host`.** The full message is read from right to left: `no such host` (the name does not exist), `lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53` (it asked your machine's DNS server, on port 53, the DNS port), `dial tcp` (it wanted to open a connection), and `Get "http://…"` (in order to make this request). Your machine's DNS server has no idea which containers run in Docker, so it answers the only thing it can: that name does not exist. The real address of that server depends on each network, and the script masks it.
2. **Both are on the same network**, `bridge`. It is not that they are separated: they are together and still cannot find each other by name.
3. **The DNS they receive is the host's.** The documentation explains that containers on the default network receive a copy of your machine's `/etc/resolv.conf` ([Docker, "Networking"](https://docs.docker.com/engine/network/)). The helper shows it: `nameserver <DNS del anfitrión>`. A nuance for your Mint: if in your `/etc/resolv.conf` you see `nameserver 127.0.0.53` (the local *systemd* resolver, normal on Mint and Ubuntu), inside the container that address would point to the container itself, where there is no DNS, so Docker does not copy it as is; the container receives other servers. The "Networking" documentation does not detail that conversion; to know what yours received, compare with the helper, which is exactly what it is for.
4. **By IP, it does get through.** The script asks Docker for the test service's address (masked as `<IP>`) and the helper makes a direct request: `sano`. The network works; what is missing is names. And an IP is no use for configuring the `revisor`, because Docker hands it out at startup and it can change at the next one.

In old tutorials you will see the earlier solution to this, `--link`. Section 8.12 explains why it is no longer used.

### 8.9 User-defined networks: names for free

#### 8.9.1 What changes

A network you create with `docker network create` (also with the `bridge` driver) behaves differently. The documentation lists the differences ([Docker, `bridge` driver](https://docs.docker.com/engine/network/drivers/bridge/)):

- **Automatic DNS**: "user-defined bridges provide automatic DNS resolution between containers". Each container is found by its name.
- **Better isolation**: only the containers connected to that network talk to each other. On the default network, by contrast, any container someone starts without thinking ends up next to yours.
- **Connecting and disconnecting on the fly**: a container can be connected to a user-defined network, or disconnected, "on the fly", without recreating it. You will do it in 8.10.

The DNS is provided by a server that Docker puts **inside** each container on those networks, at the address `127.0.0.11`. The documentation calls it the embedded DNS server, and explains that it answers the names of the network's containers and forwards everything else to the host's DNS servers ([Docker, "Networking"](https://docs.docker.com/engine/network/)). That is why a container on a network of yours resolves both `curso-docker-prueba` and `www.docker.com`.

#### 8.9.2 Reading the second half of the run

Back to `fig08_07.sh`'s output, block 2:

1. **The network**: `curso-docker-red-fig08`, `bridge` driver, `interna=false` (it has a way out; in 8.10 you will create one that does not).
2. **`OK`, `200`.** The same `revisor`, with the same configuration, finds the test service by its name. You did not change a single letter of `REVISOR_SERVICIOS`: you changed the network.
3. **The DNS is now `127.0.0.11`.** The helper, connected to the same network, shows it in its `/etc/resolv.conf`, and `nslookup` asks it for the test service's name: the server `127.0.0.11` answers with its address (masked).
4. **Who is connected**: the two containers, and nobody else. The helper does not appear because it has already finished (`--rm`).

And block 3, the one that justifies the whole course: a container on the same network sends `POST /modo/caido` to the test service (`modo: caido`), and the `revisor`'s next check says `FALLA`, `codigo 503`. The test service keeps running; the `revisor`, which checks it by name across the network, tells apart what Docker believes (the container is up) from what is happening (it answers `503`). (The `TIEMPO` column of the last row comes out with an extra space because the script masks a time of a different width; it is the table, not an error.)

A note on the name: the `revisor` looks for `curso-docker-prueba-fig08` because that is what the script's container is called. In your folder the container is called `curso-docker-prueba`, and `REVISOR_SERVICIOS` says `prueba http://curso-docker-prueba:9000/ 2s`. The container's name **is** its name on the network; if you change it, you change its address.

### 8.10 Internal networks: no way out

#### 8.10.1 Why lock the test service in

The test service exists only for the `revisor` to query. It does not need to download anything, it does not need to call anyone, it does not need the internet. And everything a container can reach is something an attacker who controls it can also reach: downloading a tool, sending data out, using it as a stepping stone. The answer is an **internal network**: `docker network create --internal`. The `docker network create` reference describes it in one sentence, "restrict external access to the network", and explains it this way: the containers of an internal network "can communicate among themselves, but not with any other network, because no default route is configured and firewall rules are set up to drop all traffic to or from other networks" ([`docker network create` reference](https://docs.docker.com/reference/cli/docker/network/create/)).

The design is the one the documentation itself uses as an example: an internal network "to communicate with containers running internal services that do not need access to the external network" ([Docker, "Networking"](https://docs.docker.com/engine/network/)). The test service, **only** on the internal one. The `revisor`, on the normal network (through which it exposes its port to your `127.0.0.1`) **and** on the internal one (through which it checks the test service). A container can be on several networks at once: it has an interface on each.

#### 8.10.2 Seeing it

The script `fig08_08.sh` builds that state, which is the lesson's final state, in two steps, so you can see what each network contributes:

```bash
#!/usr/bin/env bash
# fig08_08.sh — Red interna. El servicio de prueba vive SOLO en una red interna,
# sin salida a internet. El revisor vive en la red normal (por donde expone
# su puerto) y se conecta además a la interna. Es el estado final de la lección.
# Usa tu imagen curso-docker-prueba:1.0.0 (de la Lección 2) sin modificarla.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores, tus redes,
# tus volúmenes ni tus imágenes del curso, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
PRUEBA="${PREFIJO}prueba-fig08"
RED="${PREFIJO}red-fig08"
INTERNA="${PREFIJO}interna-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
IMAGEN_PRUEBA=curso-docker-prueba:1.0.0
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null 2>&1 || true
      docker network rm "$RED" "$INTERNA" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

docker image inspect "$IMAGEN_PRUEBA" >/dev/null 2>&1 \
  || { echo "falta $IMAGEN_PRUEBA: constrúyela como en la Lección 2"; exit 1; }
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null || exit 1

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" \
    | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /' | nombres
}

echo "== 1. Dos redes: la normal y la interna"
docker network create "$RED" >/dev/null
docker network create --internal "$INTERNA" >/dev/null
docker network inspect --format '{{.Name}} driver={{.Driver}} interna={{.Internal}}' "$RED" "$INTERNA" | nombres

echo
echo "== 2. El servicio de prueba, solo en la interna; el revisor, solo en la normal"
docker run -d --name "$PRUEBA" --network "$INTERNA" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
docker run -d --name "$NOMBRE" --network "$RED" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -v "$VOLUMEN":/datos -e REVISOR_SERVICIOS="prueba http://$PRUEBA:9000/ 2s" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 3. Conectar el revisor también a la interna, sin reiniciarlo"
docker network connect "$INTERNA" "$NOMBRE"
tabla
docker inspect --format '{{range $red, $v := .NetworkSettings.Networks}}{{$red}} {{end}}' "$NOMBRE" | nombres
echo "-- el puerto publicado sigue en 127.0.0.1:"
docker port "$NOMBRE" | sed "s/:$PUERTO\$/:<puerto>/"

echo
echo "== 4. Desde la red interna no hay salida a internet"
docker run --rm --network "$INTERNA" "$AYUDANTE" wget -q -T 5 -O /dev/null https://www.docker.com/
echo "[código de salida: $?]"
echo "-- pero la puerta de enlace de la red interna sí contesta:"
PUERTA=$(docker network inspect --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' "$INTERNA")
docker run --rm --network "$INTERNA" "$AYUDANTE" sh -c "ip route; ping -c 1 -W 2 $PUERTA | grep -E 'packets'" \
  | sed -E 's/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?/<IP>\1/g'
echo "-- desde la red normal, sí:"
docker run --rm --network "$RED" "$AYUDANTE" wget -q -T 5 -O /dev/null https://www.docker.com/ \
  && echo "desde la red normal sí hay salida"
```

```text
$ ./fig08_08.sh
== 1. Dos redes: la normal y la interna
curso-docker-red-fig08 driver=bridge interna=false
curso-docker-interna-fig08 driver=bridge interna=true

== 2. El servicio de prueba, solo en la interna; el revisor, solo en la normal
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on 127.0.0.11:53: no such host

== 3. Conectar el revisor también a la interna, sin reiniciarlo
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
curso-docker-interna-fig08 curso-docker-red-fig08 
-- el puerto publicado sigue en 127.0.0.1:
8080/tcp -> 127.0.0.1:<puerto>

== 4. Desde la red interna no hay salida a internet
wget: bad address 'www.docker.com'
[código de salida: 1]
-- pero la puerta de enlace de la red interna sí contesta:
<IP>/16 dev eth0 scope link  src <IP> 
1 packets transmitted, 1 packets received, 0% packet loss
-- desde la red normal, sí:
desde la red normal sí hay salida
```

1. **Two networks**, both with the `bridge` driver; one with `interna=true`.
2. **The `revisor` alone on the normal network does not find the test service.** Now the message says `lookup … on 127.0.0.11:53: no such host`. Compare it with 8.8's: there it asked your machine's DNS (default network); here it asked Docker's embedded DNS (user-defined network), which does exist, but only answers the names on **the container's own networks**. The test service is on another network, so for the `revisor` it does not exist. It is the isolation from 8.9.1 at work: being on the same machine is not enough, you have to share a network. Reading which DNS server the question was asked of tells you what kind of network you are dealing with.
3. **`docker network connect` without restarting.** You connect the `revisor` to the internal network too, on the fly, and the next check says `OK`. `docker inspect` shows the `revisor`'s two networks (in alphabetical order, with a trailing space that the template adds). And `docker port` confirms that the published port is still on `127.0.0.1` (the host's number is masked, because the script receives it in `PUERTO`).
4. **From the internal network there is no way out.** A helper on the internal one tries to download `https://www.docker.com/` and fails before even trying to connect: `wget: bad address 'www.docker.com'`, code `1`. It cannot even resolve the name: the query goes from the container to Docker's embedded DNS, and an internal network has no way out through which that query could reach an external name server. (The documentation does not detail at which exact point the query is cut off, so the lesson only states what was measured: the name does not resolve and the download does not even start.) But the internal network is not isolated from everything: the same helper shows its routing table, with a single row (the internal network itself, no default route outward), and even so its gateway answers `ping` (`1 packets received`). From the normal network, the download works. The internal network is not a promise: outward there is no route, but the gateway is still there.

A clarification so you do not take away one idea too many: "no way out" does not mean "unreachable from your machine". The reference says the host can communicate directly with the addresses of an internal network's containers. What the internal network cuts is the container's path toward **other networks**, the internet included. And in the other direction there is a crack worth knowing about, the one you just measured: the same reference clarifies that "communication with the gateway IP address (and thus appropriately configured host services) is possible". A program on your machine that listens on `0.0.0.0` (all interfaces), for example a development database, ends up within reach of the internal network's containers. It is one more reason for Lesson 2's habit: what runs on your machine listens on `127.0.0.1`, not on all interfaces. That is why the course publishes the `revisor`'s port through the normal network, the one that does have a path outward, and leaves the internal one only for talking to the test service.

#### 8.10.3 In your folder: the final state

With your image `curso-docker-revisor:1.5.0`, your volume `curso-docker-reportes`, and the image `curso-docker-prueba:1.0.0` from Lesson 2, these are the commands for the final state, with the course's names:

```bash
docker network create curso-docker-red
docker network create --internal curso-docker-interna
docker volume create curso-docker-reportes
docker run -d --name curso-docker-prueba --network curso-docker-interna \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
docker run -d --name curso-docker-revisor --network curso-docker-red -p 127.0.0.1:8080:8080 \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 \
  -v curso-docker-reportes:/datos \
  -e REVISOR_SERVICIOS='prueba http://curso-docker-prueba:9000/ 2s' curso-docker-revisor:1.5.0
docker network connect curso-docker-interna curso-docker-revisor
```

(If you already created the volume in 8.4.4, `docker volume create` just returns its name: it does not empty it.) Check with `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'` that the test service comes out `OK`, and with `docker ps --filter name=curso-docker-` that both reach `(healthy)`. The test service carries the same hardened options as the `revisor`, without a port and without `-e`: it is Exercise 4 of Lesson 7, and you already know it does not even need a `tmpfs` because it writes nothing. These two containers, the two networks, and the volume are what Lesson 9 writes into a `compose.yaml`.

When you finish the lesson, delete them in this order (containers first, because a network or a volume in use cannot be deleted): `docker rm -f curso-docker-revisor curso-docker-prueba` and `docker network rm curso-docker-red curso-docker-interna`. The volume, if you want to keep the report, stays; if not, `docker volume rm curso-docker-reportes`.

### 8.11 What is **not** done: the host network

Another of the networks Docker creates when installed is `host`. A container on it **has no network of its own**: according to the documentation, its network stack "is not isolated from the Docker host" and the container "does not get its own IP address allocated" ([Docker, `host` driver](https://docs.docker.com/engine/network/drivers/host/)). It listens directly on your machine's interfaces, sees all its ports and all its local connections, and `-p` stops having any effect: Docker ignores it with the warning `WARNING: Published ports are discarded when using host network mode`. That last point wipes out Lesson 2's habit in one stroke: you no longer decide whether the port stays on `127.0.0.1` or on all interfaces; it stays wherever the program decides to listen.

It is sometimes used "because it just works" when a container cannot find another, or to gain a few microseconds of network time. Both reasons have a better answer: to find another container, a user-defined network; for performance, measure first, because it is almost never the container's network that is the limit. The course README states it as this lesson's habit: **never the host network**. The habit is for application services like the `revisor`; there are legitimate uses in infrastructure (for example, an agent that measures the host's own network) that are not the topic of this course, and whoever needs them already knows they are giving up isolation on purpose.

### 8.12 What you will find in old tutorials

- **`--link`.** The old way for one container to find another by name on the default network. The documentation no longer recommends it: links on the default network are "deprecated and scheduled for removal in Docker Engine 30.0", and it asks you to use "user-defined networks instead of the legacy `--link` flag" ([Docker, legacy links](https://docs.docker.com/engine/network/links/)). If you see it, translate it into a network.
- **"Data-only containers" and `--volumes-from`.** Before named volumes existed, a container that never ran was created just to "hold" a volume, and the others mounted it with `--volumes-from`. Today the volume has a name of its own and needs no container to hold it up.
- **`VOLUME /datos` in the Dockerfile "so the data persists".** The instruction exists and does something: it marks a path as a mount point, and if at run time you mount nothing there, Docker creates an **anonymous** volume initialized with whatever the image has at that path ([Dockerfile reference](https://docs.docker.com/reference/dockerfile/)). The result is exactly the opposite of what is wanted: a nameless volume for each container, which nobody recognizes and which piles up. And the instruction cannot choose a host folder. This course does not use it: the `revisor` brings the `/datos` folder with its owner, and the named volume is decided by whoever runs the container.
- **`chmod -R 777` on the data folder** to "fix the permissions". You already saw in 8.3 and 8.6 that the problem is the owner; a `777` hides it and opens the folder to everyone.

## The error you will see

This lesson has two main errors, one per half, and three secondary ones. All of them have already appeared.

**The main storage error: the new volume the process cannot write to.** It is the one from `fig08_02.sh`:

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
```

It is read from right to left, like the one in Lesson 6. `permission denied` is said by the kernel: the process has no permission to create a file there. `open /datos/.reporte-<n>.tmp` says which file, with the path **inside** the container: it is the temporary file the `revisor` writes before renaming it, so the problem is the **folder**, not `reporte.json`. And `no pude guardar el reporte` is added by the `revisor`, which also answers `500` instead of pretending everything is fine. The question that solves it is the usual one: "who owns the folder, and which user does the process run as?". The first answer is given by a helper (`docker run --rm -v <volume>:/datos:ro alpine:3.24.2 ls -lnd /datos`); the second, `docker inspect --format '{{.Config.User}}' <container>`. If the folder belongs to `0` and the process is `65532`, it is a volume that was born without an image folder to copy: either the image does not bring `/datos` (the 1.4.0), or someone used `volume-nocopy`. The fix is for the image to bring the folder with `COPY --chown` and for the volume to be new. The volume existing beforehand does not prevent the copy: as long as it is **empty**, the first mount over an image folder receives it, even if you created it yourself with `docker volume create` (it is what block 2 of `fig08_03.sh` does, and we repeated it by hand: a volume created in advance and mounted earlier with `nocopy` still received the `65532` folder when mounted afterwards with the good image). What prevents it is the volume **already having something inside**, for example a file once written by a `root` process: then the volume wins, the folder is still `root`'s, and the `permission denied` returns. In that case, if there is nothing to keep, `docker volume rm` and let the next `docker run` create it again.

With a *bind mount* the same text has a different origin: the folder is **yours** and the process is `65532`. Fix: `--user "$(id -u):$(id -g)"`, or make the folder belong to `65532`. What is not a fix, in either case: `--user 0` or `chmod 777`.

**The main network error: the name that does not exist.**

```text
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53: no such host
```

`no such host` says the name could not be resolved. What diagnoses the case is **who was asked**, right before the `:53`:

- **Your machine's DNS address**: the container is on the default network, which has no container DNS. Fix: a user-defined network for both.
- **`127.0.0.11`**: the container is on a network of yours, with Docker's embedded DNS, but the other container is on **none of its networks** (or it is named differently, or it is not running). Fix: `docker network connect`, or check the name with `docker ps`.

That detail turns a generic message into a one-line diagnosis.

**The secondary ones:**

```text
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: ./tampoco-existe
```

A `--mount type=bind` with a host path that does not exist (it exits with `125`; the path in the message is the one you wrote). It is almost always a typo or a path relative to the wrong place. With `-v` you would not have seen this error: Docker would have created the folder, owned by `root`, and the container would have started with an empty folder.

```text
Error response from daemon: remove curso-docker-reportes-fig08: volume is in use - [<id>]
```

`docker volume rm` on a volume that some container, running or stopped, still has mounted. Delete the container first (the identifier in brackets tells you which one). The same happens with `docker network rm` and a network with connected containers.

```text
wget: bad address 'www.docker.com'
```

From a container on an internal network, any name outside. If you see it in a container that **should** have a way out, check its networks with `docker inspect`: it is probably only on an internal one.

## The security habit of the lesson

**Data is mounted with a name, with the right owner, and only where it is needed; the networks are yours, the one for internal services has no way out, and the host one is not used.** They are three habits that are written together and checked together. The first: the file system stays read-only, and each writable folder has a name (a volume at `/datos`, a `tmpfs` with a size); none is fixed with `root` or with `777`, because the problem is the owner and it is fixed in the image or with `--user`. The second: each container is only on the networks it needs; the one that does not need the internet lives on an `--internal` network, and you check it by asking it to reach out (`bad address`). The third: never `--network host`, which wipes out in one stroke the network isolation and Lesson 2's `127.0.0.1`. The accident it prevents is concrete: a compromised internal service that cannot download anything or send anything out, and that cannot write anywhere but in a folder you chose.

## Common mistakes

**Saving data in the container layer.** It works until the first `docker rm`, which in a service is the next update. And with `--read-only` it does not even work.

**Running as `root` so the volume lets you write.** It swaps an ownership problem for a security one, and undoes Lessons 3, 5, and 7. The image brings its folder with `COPY --chown`.

**`chmod 777` on a host folder.** It opens it to all users and all containers. The fix is the owner: `--user` with your numbers.

**`-v` with host paths.** A typo silently creates a `root` folder. For *bind mounts*, `--mount type=bind`, which refuses by default.

**Mounting read-write what the container only reads.** Configuration, secrets, certificates: `readonly`. A writable *bind mount* is a direct path from the container to your disk.

**Anonymous volumes, through `VOLUME` in the Dockerfile or through `-v /datos` without a name.** They pile up without anyone knowing whose they are. Give them a name, with the project's prefix.

**Deleting volumes "just in case".** `docker volume rm` has no recycle bin. And `docker volume prune -a` deletes **all** volumes no container uses, named or not, including the data of stopped projects that are not yours (without `-a`, `prune` only deletes anonymous ones, according to its [reference](https://docs.docker.com/reference/cli/docker/volume/prune/)). Delete by exact name.

**Writing container IP addresses in the configuration.** Docker hands them out and they change. Use names on a user-defined network.

**Leaving everything on the default network.** No names, and with any container someone starts without thinking on the same network as yours. The documentation itself calls it a legacy detail.

**Giving internet access to whoever does not need it.** An internal service with a way out is a stepping stone. `--internal`.

**`--network host` "because that works".** If a container cannot find another, the answer is a network of yours, not removing isolation.

## Exercises

Do them in order. Before running each one, write in your [log](bitacora.md) what you think will happen; comparing it afterwards is half of the learning. When you finish, delete what you created: everything carries the prefix `curso-docker-`.

### Exercise 1 — Volume, *bind mount*, `tmpfs`, or nothing?

For each piece of data, choose one of the four and say why in one sentence:

1. A test database that a service uses and that must survive a container update.
2. A `config.yaml` file that you edit on your machine and that the container only reads.
3. A program's session files, which are regenerated on every startup.
4. A program's source code while you develop it and test it in a container.
5. The `revisor`'s binary.
6. The `revisor`'s report, which another tool on your machine, outside Docker, is going to pick up every hour.

### Exercise 2 — Read the `no such host`

Without running anything, say which network situation produced each message and with which command you would fix it. Both are from the `revisor`, looking for a container that **is** running:

```text
A) … lookup curso-docker-prueba on <DNS del anfitrión>:53: no such host
B) … lookup curso-docker-prueba on 127.0.0.11:53: no such host
```

Extra question: in case B, which two other causes, unrelated to networks, would give exactly the same message?

### Exercise 3 — The report that survives (project)

In your folder, with the final state from 8.10.3 running, do this sequence and, **before** each step, predict the result:

1. Ask for the table once: `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'`.
2. Delete the `revisor`'s container with `docker rm -f curso-docker-revisor`.
3. Read the report with a helper, with no `revisor` running.
4. Create the `revisor` again with the command from 8.10.3, **without** the `docker network connect`, and ask for the table.
5. With that `revisor` running, try `docker volume rm curso-docker-reportes`.
6. Connect it to the internal network and ask for the table again.

### Exercise 4 — `volume-nocopy`

Predict what happens if you run the image `curso-docker-revisor:1.5.0`, hardened, with a **new** volume mounted like this:

```text
--mount type=volume,src=curso-docker-sin-copia,dst=/datos,volume-nocopy
```

What does `/api/estados` answer? Who owns `/datos` inside the volume? Check it by publishing the port on `127.0.0.1:8081` (or by first stopping your `curso-docker-revisor`, which occupies `8080`), and say how it relates to the error in 8.3. Extra question: how do you write the same thing with `-v`? At the end, delete the container and the volume.

## Solutions

### Solution 1

1. **Named volume.** It must outlast the container and nobody needs to touch the files by hand. It is the report's case.
2. **Read-only *bind mount*.** You edit it on your machine and the container only reads it; with `readonly`, the container cannot change it even if it wanted to.
3. **`tmpfs` with a size.** It must not survive the container, and this way it also takes up no disk and leaves no trace.
4. ***Bind mount***. You edit it and the container has to see the change right away. It is the use the documentation gives as an example. (In a container that only runs it, read-only.)
5. **Nothing: it goes in the image.** It is code (Lesson 6). Mounting it from outside would mean the image you tested is not the one that runs.
6. ***Bind mount*** **of a folder of yours**, with `--user` set to your numbers, as in 8.6. A tool on your machine outside Docker needs to read it at a path of yours, without `sudo`. With a volume it would have to go through a helper container.

### Solution 2

- **A)** It asked your machine's DNS: the `revisor` is on the **default network**, which has no container DNS. Fix: create a network (`docker network create curso-docker-red`) and run both containers with `--network curso-docker-red`, or connect them to it with `docker network connect`.
- **B)** It asked the embedded DNS (`127.0.0.11`): the `revisor` **is** on a user-defined network, but the test service is on none of its networks. It is what you saw in block 2 of `fig08_08.sh`. Fix: `docker network connect <the other's network> curso-docker-revisor` (or connect the other to the `revisor`'s network).

Extra question: the same message appears if the name is **misspelled** in `REVISOR_SERVICIOS` (DNS does not guess), or if the other container **is not running**: the embedded DNS only answers the names of the containers connected at that moment. `docker ps --filter name=curso-docker-` answers both doubts.

### Solution 3

Steps 2, 5, and the first table of step 4 were measured with the same machine and the same Docker version as the lesson, in the scripts `fig08_03.sh` and `fig08_08.sh` (with the `-fig08` suffix in the names); the others are deduced from them, and in your folder they should come out like this:

1. `200`, and the table says `prueba OK`.
2. The container disappears; the volume does not (block 4 of `fig08_03.sh`).
3. The helper (`docker run --rm -v curso-docker-reportes:/datos:ro alpine:3.24.2 cat /datos/reporte.json`) must print the latest report, in JSON. In block 4 of `fig08_03.sh` the service was called `propio`; in your final state it must be called `prueba`, with `"ok": true` and `"codigo": 200`.
4. The table says `FALLA` with `lookup curso-docker-prueba on 127.0.0.11:53: no such host`, as in block 2 of `fig08_08.sh`: the `revisor` is on a network of yours, and the test service is on another.
5. `docker volume rm` refuses: `volume is in use`, with the container's identifier in brackets, and exits with code `1` (block 3 of `fig08_03.sh`).
6. After the `docker network connect`, `OK` (block 3 of `fig08_08.sh`).

### Solution 4

It is the script `fig08_09.sh`, which tests the option with `--mount` and with `-v`:

```bash
#!/usr/bin/env bash
# fig08_09.sh — Solución del Ejercicio 4: volume-nocopy. La imagen 1.5.0 trae
# /datos de 65532, pero si el volumen nuevo se monta con volume-nocopy, Docker no
# copia nada (ni el dueño) y vuelve el permission denied. Se prueba con --mount
# y con -v, que también admite la opción, pero con OTRO nombre: nocopy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0,
# tu contenedor curso-docker-revisor ni tus volúmenes, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}sin-copia-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
probar() {  # probar OPCIÓN-DE-MONTAJE…: corre el revisor con un volumen nuevo y mira /datos
  docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO "$@" \
    -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
  curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'
  docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
  docker rm -f "$NOMBRE" >/dev/null
  docker volume rm "$VOLUMEN" >/dev/null
}

echo "== 1. Con --mount …,volume-nocopy"
probar --mount type=volume,src="$VOLUMEN",dst=/datos,volume-nocopy

echo
echo "== 2. Con -v, el nombre de --mount no sirve"
salida=$(docker run --rm -v "$VOLUMEN":/datos:volume-nocopy "$IMAGEN" version 2>&1) && rc=0 || rc=$?
echo "$salida" | sed '/^$/d'
echo "[código de salida: $rc]"
docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true

echo
echo "== 3. Con -v …:nocopy"
probar -v "$VOLUMEN":/datos:nocopy
```

```text
$ ./fig08_09.sh
== 1. Con --mount …,volume-nocopy
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
drwxr-xr-x    2 0        0             4096 Oct 21 13:11 /datos

== 2. Con -v, el nombre de --mount no sirve
docker: Error response from daemon: invalid mode: volume-nocopy
Run 'docker run --help' for more information
[código de salida: 125]

== 3. Con -v …:nocopy
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
drwxr-xr-x    2 0        0             4096 Oct 21 13:11 /datos
```

It is the error from 8.3 with the good image. Image 1.5.0 brings `/datos` owned by `65532`, but `volume-nocopy` tells Docker not to copy anything into the new volume, and what is not copied includes the owner: the volume is born with its `root` folder, as when the image did not bring the folder (block 3 of `fig08_04.sh`). The lesson: the fix in 8.4 depends on the copy at the first mount. Anything that prevents it (`volume-nocopy` on the first mount, or a volume that already has content and therefore wins over the image) brings the `permission denied` back. A volume that existed beforehand but is empty does not prevent it: it was measured that it receives the folder just the same.

Extra question: with `-v`, the option is written `nocopy` (block 3). The `--mount` name does not work with `-v`: Docker 29.2.1 rejects it with `invalid mode: volume-nocopy` and code `125`, even though the volumes page documents it with that name (block 2). It is a good example of why the course runs each command instead of copying it from the documentation.

## How I know I got it

Check each item only if you can do it **without looking at the text again**:

- [ ] In your folder, `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.5.0` shows `REVISOR_REPORTE=/datos/reporte.json`, and `docker create` + `docker export` + `tar -tv --numeric-owner` show `datos/` owned by `65532/65532`.
- [ ] You trigger the `permission denied` with image 1.4.0 and a new volume, and explain it using the words *owner*, `0`, and `65532`.
- [ ] The report survives `docker rm -f curso-docker-revisor`: you read it with a read-only helper.
- [ ] You explain with an example when a folder's content is **copied** on mounting and when it is **hidden**, and why `--mount` is safer than `-v` for a *bind mount*.
- [ ] You run the `revisor` with a *bind mount* of a folder of yours and `--user "$(id -u):$(id -g)"`, and `stat` shows that the report is yours.
- [ ] A container with `--read-only` writes to a volume and to a `tmpfs` with `size`, and after `docker restart` the volume's file is still there and the `tmpfs`'s is not.
- [ ] You show the `no such host` on the default network and the `OK` on a network of yours, and say which DNS server each uses (`/etc/resolv.conf` of a helper).
- [ ] The final state from 8.10.3 is running: the test service only on `curso-docker-interna`, the `revisor` on both, the table at `OK`, and a helper on the internal network gets `bad address` when trying to reach out.
- [ ] You run the scripts in [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes) and your outputs match this lesson's, except for the timings, the dates, your machine's user and group numbers, and whatever the scripts mask in plain sight. (The scripts publish on `8081`, so they do not collide with your `revisor` on `8080`.) And when you finish, `docker ps -a --filter name=fig08`, `docker volume ls --filter name=fig08`, and `docker network ls --filter name=fig08` show nothing.

## Summary

Answer without looking at the lesson:

1. What is a container's writable layer, and what three problems does it have for saving the `revisor`'s report?
2. What is the difference between a named volume, a *bind mount*, and a `tmpfs`, in where the data lives and how long it lasts?
3. Why does a new volume mounted on a folder the image does not have give `permission denied` with an unprivileged user?
4. What does `COPY --chown=65532:65532` do, and why does the fix depend on the volume being new and empty?
5. When is a folder's content copied and when is it hidden when something is mounted on top?
6. What do `-v` and `--mount` each do when the host folder does not exist?
7. How do you fix the `permission denied` of a *bind mount* without `root` and without `777`?
8. Why can a container on the default network not find another by name, and what changes on a user-defined network?
9. What is `127.0.0.11`, and what does seeing that address in a `no such host` tell you?
10. What does an `--internal` network cut, what does it not cut, and why is the `revisor`'s port published through the other network?

## Sources

All consulted on October 21, 2026.

- [Docker, "Storage"](https://docs.docker.com/engine/storage/): that what is written in the container layer does not persist and is hard to get out; the mount types (including image mounts) and when to use each.
- [Docker, "Volumes"](https://docs.docker.com/engine/storage/volumes/): the copy of the image's content into an empty volume and the `volume-nocopy` option; that a volume with data hides what was there; that `--mount` is preferred; the path `/var/lib/docker/volumes/<name>/_data`; that volumes survive the container and anonymous ones are deleted with `--rm`.
- [Docker, "Bind mounts"](https://docs.docker.com/engine/storage/bind-mounts/): that they hide the existing content; that `-v` creates the folder and `--mount` does not, by default, with the text `bind source path does not exist`, and the `bind-create-src` option; that they give write access to the host by default; the `readonly` option.
- [`docker volume prune` reference](https://docs.docker.com/reference/cli/docker/volume/prune/): that by default it only deletes anonymous volumes and that `-a` deletes all those not in use.
- [Docker, "tmpfs mounts"](https://docs.docker.com/engine/storage/tmpfs/): that a `tmpfs` lives in memory and disappears when the container stops; that it is not shared; its default maximum size (50% of memory) and permission (`1777`); that `--mount` is preferred; the warning about swap.
- [Docker, "Networking"](https://docs.docker.com/engine/network/): the embedded DNS server at `127.0.0.11` and the forwarding of external queries; that containers on the default network receive a copy of the host's `/etc/resolv.conf`; internal networks for services with no external access.
- [Docker, `bridge` driver](https://docs.docker.com/engine/network/drivers/bridge/): the differences between the default network and user-defined ones (automatic DNS, isolation, connecting on the fly) and that the default network is a legacy detail not recommended for production.
- [`docker network create` reference](https://docs.docker.com/reference/cli/docker/network/create/): the `--internal` option and internal mode (no default route, traffic to other networks dropped, the gateway reachable, and the host that does reach the containers).
- [Docker, `host` driver](https://docs.docker.com/engine/network/drivers/host/): that the container has no network or IP address of its own and that published ports are discarded with a warning.
- [Docker, legacy links](https://docs.docker.com/engine/network/links/): that `--link` on the default network is deprecated and scheduled for removal in Engine 30.0.
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/): `COPY --chown` and the default owner `0`; the `VOLUME` instruction and its volume initialized with the image's content.
- [`docker run` reference](https://docs.docker.com/reference/cli/docker/container/run/): `-v`, `--mount`, `--tmpfs`, `--network`, and `--user`.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions and dates in "About the runs".
- [Colima](https://github.com/abiosoft/colima): the tool the programs were run with on macOS.

### Terms in this lesson

| | |
|---|---|
| ***bind mount*** | mount of a host folder or file inside the container; the container sees exactly that, with its owner and its permissions |
| **writable layer** | each container's own layer, on top of the image's; it is deleted with the container |
| **helper container** | disposable container (`--rm`) used to look at a volume or a network; here, `alpine:3.24.2` |
| **embedded DNS** | name server that Docker places at `127.0.0.11` inside the containers of user-defined networks |
| **user-defined network** | network created with `docker network create`; provides names through DNS and isolates from other containers |
| **internal network** | network created with `--internal`; its containers talk to each other, but do not reach other networks or the internet |
| **default network** (`bridge`) | the network Docker connects a container to if you say nothing else; no names, only IP addresses |
| **`tmpfs`** | mount that lives in memory, with a size, and disappears when the container stops |
| **named volume** | Docker-managed storage that survives containers; created, listed, and deleted with `docker volume` |
| **anonymous volume** | nameless volume, created by `VOLUME` or by `-v /path`; hard to recognize and easy to forget |

---

**Next:** [Lesson 9 — Compose: the complete system](09-compose.md)
