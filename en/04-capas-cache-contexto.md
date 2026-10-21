# Lesson 4 — Layers, Cache, and Context

It is 11:20 in the morning and at 12 there is a demo with the department that is going to use the `revisor`. One detail is left: the report table prints a column shifted by one space. It is a one-line change. You make it, build the image, and wait. Thirteen seconds. You test it, it is not right, you fix it again. Another thirteen. And another thirteen. On the fifth round you realize you have spent more time watching the terminal compile than thinking about the problem, and that every build compiles the **whole** program from scratch, even though you only touched one file. Meanwhile, your teammate, who works on her own copy of the project, asks why her build says it "uploaded" 62 MB when the `revisor`'s code weighs a few kilobytes. In her copy someone deleted the `.dockerignore`, and the folder holds a backup and the Git history. Both questions have the same answer, and it is not in the `revisor`'s code: it is in the order of four lines of the Dockerfile and in a file called `.dockerignore`. By the end of this lesson, that same one-line change rebuilds in under two seconds.

**Time:** 2 × 45 min

**What you build:** the same image as in Lesson 3, now as `curso-docker-revisor:1.1.0`, with a Dockerfile reordered to take advantage of the cache, a cache mount for the Go compilation, and a more complete `.dockerignore`. It does exactly the same as `1.0.0`; it rebuilds in seconds and its compilation layer weighs 100 MB less.

**What you learn:** that an image is a stack of layers and how to see them with `docker history`; how the builder decides whether a layer comes from the cache or is redone; why the **order** of instructions decides how much gets rebuilt; how to read a build with `--progress=plain`; what a cache mount (`RUN --mount=type=cache`) is and why its contents do not end up in the image; and what travels in the build context and what does not.

**Where you are coming from.** From [Lesson 3](03-primer-dockerfile.md) you bring your first Dockerfile: a single stage on `golang:1.27.3-trixie`, a `COPY . .` that brings in the whole project, a `RUN go build`, `USER 10001:10001`, and `CMD ["revisor"]` in *exec* form. You also bring its five-line `.dockerignore` and the image `curso-docker-revisor:1.0.0`, at 1.45 GB. There it was mentioned in passing that copying everything at once makes rebuilding slow; here you are going to measure it and fix it. From [Lesson 0](00-que-es-un-contenedor.md) you bring the idea that an image is made of read-only **layers**. Until now it was a sentence; in this lesson you are going to count them one by one.

**What this lesson does not do.** It does not really shrink the image: 1.32 GB is still huge, because the image still carries the Go compiler and an entire Debian. Separating compilation from the final image is the subject of [Lesson 5](05-multi-stage.md). Nor does it touch the `revisor`'s code, its configuration, or its secrets. And it does not teach "downloading the dependencies in a separate layer", a very common trick in Go tutorials, because the `revisor` has no external dependencies: it uses only the standard library. What it does have, and plenty of, is **compilation**, and that is the cache taught here. Section 4.8 tells you how to recognize the other trick when you see it.

**About the runs.** All outputs are real and were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4, the same base as Linux Mint 22, the course's reference system. The scripts were run **inside** that virtual machine, with Docker 29.2.1 (client and daemon) and Buildx v0.31.1. The course was planned with Docker Engine 29.8.2, and the most recent version published that day was 29.9.2, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)); nothing this lesson teaches changes between those versions. Three notes about these runs. First: the machine was busy with other builds at the same time, so the **times** are noisy; what holds across all runs is the **difference** between one Dockerfile and the other, not the exact milliseconds. Second: other lessons of the course were being written on that same machine, and they create images with the same names (`curso-docker-revisor:1.0.0`, `:1.1.0`). So as not to delete anything of theirs or overwrite one of their tags, this lesson's scripts were launched with a different name prefix, thanks to the `PREFIJO` variable they include, and the prefix was turned back into the course's normal one **in the command itself**, in plain view: the first line of each saved output says exactly how it was run, for example `PREFIJO=curso-docker-l04- ./fig04_03.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'`. On your machine, plain `./fig04_03.sh` prints the same thing without that `sed`. It is the only exception to "it is run as-is", and it exists only because of the shared machine. Third: the Mac used for the runs does not have Go 1.27.3 installed; that is why the Go error in Solution 3 was measured inside the `golang:1.27.3-trixie` image. What **does** change on your Mint: the times, the cache identifiers and, if your machine is Intel or AMD, the variant of the Go image that is downloaded (`amd64` instead of `arm64`), although the *digest* you will see on the `FROM` line is the same because it is that of the platform index. The programs are in [`programas/04-capas-cache-contexto/`](../programas/04-capas-cache-contexto), each with its output next to it, and `estado/` holds the `Dockerfile`, the `.dockerignore`, and `Dockerfile.leccion3` (the copy of Lesson 3's, only for comparison) as they stand at the end.

## By the end you will be able to

- List an image's layers with `docker history` and say which ones add files and which only add values.
- Predict, before building, which steps of a Dockerfile will come from the cache after a change, and verify it with `--progress=plain`.
- Reorder a Dockerfile so that a change in the code does not repeat the steps that do not depend on it.
- Add a cache mount to a compilation `RUN` and show that its contents live in the builder and not in the image.
- Measure with a 50 MB file what travels in the build context, with and without `.dockerignore`.
- Delete only your own compilation cache, without touching that of other projects on the same machine.

## The why before the how

Building an image is repeating a recipe. The first time, every step is done for real: the base is downloaded, the files are copied, the code is compiled. The second time, almost everything is the same as the first: the same base, the same `go.mod`, almost the same code. Repeating it all would be absurd. That is why the builder saves the result of each step and, the next time, if nothing that step uses has changed, it **reuses** the result instead of repeating it. That is called the **build cache**.

The problem is that the cache has rules, and they are not the ones people assume. It is not "reuse what did not change". It is "reuse **up to** the first step that changed, and from there on down, repeat everything". That difference is the opening scene. In Lesson 3's Dockerfile, the code comes in with a single `COPY . .` and the next line compiles. Any change, even a comment, changes that `COPY`, and since the `RUN go build` comes after it, the full compilation is repeated. With this lesson's Dockerfile, the same change rebuilds like this (you are going to measure it in section 4.5):

```text
## 3. Cambio un comentario en internal/reporte/tabla.go
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 13011 ms
...
curso-docker-revisor:1.1.0 (Dockerfile): 1847 ms
```

From thirteen seconds to under two, with the same code, the same change, and the same resulting image. On a less busy machine or in a larger project, the difference grows. And the second question in the opening scene, the one about the 62 MB, is the other side of the same coin: the builder also needs to know **which files** it can use, and if you send it all of them, it sends all of them.

The lesson has eight parts:

1. **An image is a stack of layers** (4.1): seeing them with `docker history`.
2. **How the cache decides** (4.2): the rules, with Lesson 3's Dockerfile as the bad example.
3. **Order matters** (4.3): the new Dockerfile, line by line.
4. **The cache that is not a layer** (4.4): `RUN --mount=type=cache`.
5. **Measuring** (4.5): the stopwatch and `--progress=plain`.
6. **What travels in the context** (4.6), with the lesson's error.
7. **Checking before building** (4.7).
8. **What you will see in other projects** (4.8).

## The concepts

### 4.1 An image is a stack of layers

#### 4.1.1 One layer per step

Docker's documentation defines a layer like this: "Each layer in an image contains a set of filesystem changes - additions, deletions, or modifications", and explains that this is useful because it "allows layers to be reused between images" ([Docker, "Understanding the image layers"](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/)). And the build cache page connects layers with your recipe: "Each instruction in this Dockerfile translates to a layer in your final image" ([Docker, "Docker build cache"](https://docs.docker.com/build/cache/)).

In Lesson 0 you saw the consequence of layers for containers: each container adds a layer of its own, on top, where it writes. Here the other half matters: how the layers underneath are stacked when you **build**. `FROM` does not add a layer of its own: it puts all the base image's layers underneath. After that, every `COPY` and every `RUN` leaves a layer with the files it added or changed, and `WORKDIR` also leaves a small one when it has to create the directory. Instructions that only record something, such as `USER`, `EXPOSE`, and `CMD`, leave a line in the history, but of zero bytes: they add values to the configuration, not files.

#### 4.1.2 Seeing them with `docker history`

`docker history` shows "the history of an image", one line per step, from most recent to oldest ([`docker image history`](https://docs.docker.com/reference/cli/docker/image/history/)). With `--format` you choose which columns to see: `.Size` is the size that step added and `.CreatedBy`, the command that created it. This is the history of the Lesson 3 image, taken from `fig04_03.sh` (the full script appears in 4.5; here only its section 5 is looked at):

```text
$ docker history curso-docker-revisor:1.0.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70
0B	CMD ["revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 10001:10001
110MB	RUN /bin/sh -c go build -o /usr/local/bin/re…
115kB	COPY . . # buildkit
8.19kB	WORKDIR /src
4.1kB	WORKDIR /go
```

This output is stable on an `arm64` machine; on `amd64` the sizes may differ slightly. The `head -7` keeps the top seven lines and the `cut -c1-70` trims each line to 70 characters so it fits; the `…` is Docker's, which also truncates long commands (with `--no-trunc` it does not).

Read it from bottom to top, which is the order in which it was built:

- `WORKDIR /go` **is not yours**. It is the last step of the Go image. If you remove the `head -7`, a dozen more lines appear below it, all from `golang:1.27.3-trixie`: in the course's reference run, the largest was a 290 MB layer with the Go installation and, further down, several of 281, 208, and 156 MB with the base Debian. Your image **starts** where the Go image ends.
- `WORKDIR /src`, 8.19 kB: your first step. It creates the directory.
- `COPY . . # buildkit`, 115 kB: the whole project. The `# buildkit` comment says the layer was created by BuildKit, the builder you met in Lesson 3.
- `RUN /bin/sh -c go build ...`, **110 MB**. Note: the `RUN` is executed with `/bin/sh -c`, because in the Dockerfile it is in *shell* form. For a `RUN` that is fine; the *exec* form rule was for `CMD` and `ENTRYPOINT`.
- `USER`, `EXPOSE`, `CMD`: zero bytes. Values only.

Now the question that opens this lesson: the compiled `revisor` weighs about 10 MB. What are the other 100 MB in that layer? The answer is in section 4.4, and it is the reason the new image weighs less.

> [!NOTE]
> 🔧 **Engineering observation 4.1**
> A layer is never deleted from above. If a `RUN` creates a 100 MB file and the next `RUN` deletes it, the image still weighs those 100 MB: the second layer only records "this file is no longer visible". What goes into a layer stays in the image. That is why what must not be in the image is kept out **before** it gets in, not cleaned up afterwards.

### 4.2 How the cache decides

#### 4.2.1 The three rules

The cache documentation explains them across two pages, and they fit in three rules:

1. **For `COPY` and `ADD`, the files count, except for their date.** The documentation says the builder "calculates a cache checksum from the file metadata" and that the cache is invalidated "if the metadata for any of the files involved has changed". In practice, which you are going to measure in Exercise 1: changing a file's contents invalidates it, and changing only its date does not. The documentation puts it this way: the modification time does **not** count; "If only the `mtime` of the copied files have changed, the cache is not invalidated" ([Docker, "Build cache invalidation"](https://docs.docker.com/build/cache/invalidation/)).
2. **For `RUN`, only the command text counts.** Aside from `ADD` and `COPY`, the cache check does not look at files; "only the command string itself is used to find a match" (same page). A `RUN go build` that was already executed on the same layer below comes from the cache even if, outside, a new version of something came out.
3. **Once something is invalidated, everything below is repeated.** "If a layer changes, all other layers that come after it are also affected. Even if they wouldn't build anything differently, they still need to re-run" ([Docker, "Docker build cache"](https://docs.docker.com/build/cache/)). The invalidation page says the same: once the cache is invalidated, the following commands generate new images and the cache is not used.

The third rule is the one that matters for order. The cache is not a map of "what changed"; it is a chain. Each link depends on the one above. If one breaks, all the ones below break.

#### 4.2.2 Lesson 3's Dockerfile, in light of the rules

Go over Lesson 3's Dockerfile with the three rules in hand:

```dockerfile
FROM golang:1.27.3-trixie
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

(It is a fragment: the full file is `estado/Dockerfile.leccion3`, identical to Lesson 3's.) The `COPY . .` depends on **all** the files in the context. You change a comment in `internal/reporte/tabla.go`: rule 1, the contents changed, the `COPY` is invalidated. Rule 3: the `RUN go build` comes after, so it is repeated. And since the `RUN` starts on a new layer, with nothing from the previous compilation, Go compiles **everything** from scratch: your program, each package in `internal/`, and each standard library package it uses.

This is how `fig04_03.sh` saw it (section 3), in the format explained in 4.5:

```text
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 13011 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY . .
  paso 4  DONE 10.1s RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

`CACHED` means "it came from the cache"; `DONE` with a time, "it was actually done". The `WORKDIR` came from the cache; the `COPY` and the compilation were redone. Step 1, the `FROM`, always says `DONE 0.0s`: the builder confirms it has the base image, which was already downloaded, and does nothing else.

### 4.3 Order matters

#### 4.3.1 The lesson's Dockerfile

Docker's optimization guide says it in one line: "Steps that change frequently should be placed towards the end of your Dockerfile" ([Docker, "Optimize cache usage"](https://docs.docker.com/build/cache/optimize/)). For the `revisor`, that gives this Dockerfile. It replaces Lesson 3's, in the root of the project, and it is called `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
# fig04_01.Dockerfile — Lección 4: la misma imagen que la 3, ordenada para la caché.
FROM golang:1.27.3-trixie

WORKDIR /src

# Primero lo que casi nunca cambia (la descripción del módulo)...
COPY go.mod ./
# ...después el código, que cambia en cada edición.
COPY cmd/ cmd/
COPY internal/ internal/

# La caché de compilación de Go vive en un montaje de caché: sobrevive entre
# construcciones, acelera la siguiente y NO queda dentro de la imagen.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -o /usr/local/bin/revisor ./cmd/revisor

USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

Compared with Lesson 3's, two things change: the `COPY . .` was split into three, and the `RUN` gained a `--mount` option. Everything else is the same, line by line, and the resulting image does the same thing.

#### 4.3.2 The three `COPY`s

**`COPY go.mod ./`.** The `go.mod` file describes the module: its name and the Go version it requires. In the `revisor` it has two lines and almost never changes. Copying it first, alone, creates a layer that survives any change to the code. In a project with dependencies, `go.sum` and the download step would also go here (4.8); in the `revisor`, the benefit is small, but the habit is the same: what changes least goes highest.

**`COPY cmd/ cmd/` and `COPY internal/ internal/`.** The code, in two layers. `cmd/revisor/` is the HTTP server; `internal/` holds the packages that come from the Go course (configuration, querying, reporting). Separating them does not change speed much, but it makes it clearer in `docker history` which part changed, and the order follows the rule: `internal/`, which changes more while you work on the report, goes below.

Notice a side effect that is worth its weight in gold and is measured in 4.6: with selective `COPY`s, **only those three paths** can get into the image. A `.env` forgotten in the folder does not get in even if the `.dockerignore` forgets it, because no `COPY` asks for it. The `.dockerignore` is still mandatory, but it is no longer the only barrier.

#### 4.3.3 The same change, with the new order

Now the same comment in `tabla.go`, with this Dockerfile. It is section 3 of `fig04_03.sh`, second half:

```text
curso-docker-revisor:1.1.0 (Dockerfile): 1847 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.8s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

The rules, again. `go.mod` did not change: cache. `cmd/` did not change: cache. `internal/` did change: it is redone, and by rule 3, so is the `RUN`. So far the order saved you little, because the compilation is still repeated. But look at the `RUN`'s time: **0.8 seconds**, versus 10.1 with the old Dockerfile. The compilation was repeated and yet it compiled almost nothing. The order did not do that. The `--mount` did, and it is the next section.

Before moving on, the proof that the new image does the same as the old one. Section 7 of `fig04_03.sh` runs `1.1.0` as in Lesson 3, with the `revisor` checking itself, and asks for its health from inside the container (the Go image includes `curl`; that way there is no need to publish a port):

```text
## 7. La imagen nueva hace lo mismo que la vieja
$ docker exec curso-docker-revisor curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"desarrollo"}
```

Same as `1.0.0`. The `"desarrollo"` is still there because the version is not yet stamped into the program; that comes in Lesson 6.

### 4.4 The cache that is not a layer: `RUN --mount=type=cache`

#### 4.4.1 Go already has its own cache

The Go compiler does not compile the same thing twice if it can avoid it. Its documentation puts it this way: "The go command caches build outputs for reuse in future builds", and by default it stores them in a directory called `go-build` inside the user's cache directory ([`go` documentation, "Build and test caching"](https://pkg.go.dev/cmd/go#hdr-Build_and_test_caching)). On Linux, for the `root` user, that directory is `/root/.cache/go-build`. If you change a file in `internal/reporte`, Go recompiles only that package and those that depend on it, and takes the rest from the cache.

On your machine, that cache works on its own. Inside a Docker build, it does not: each `RUN` starts on the layer the previous step left it, and in Lesson 3's Dockerfile that layer has no Go cache, because the `COPY` was just redone. Worse still: what Go writes to `/root/.cache/go-build` during the `RUN` **stays in the `RUN`'s layer**. Those are the extra 100 MB from 4.1.2.

#### 4.4.2 The cache mount

`RUN --mount` allows you "to create filesystem mounts that the build can access", and the `cache` type is used "to cache directories for compilers and package managers" ([Dockerfile reference, `RUN --mount=type=cache`](https://docs.docker.com/reference/dockerfile/#run---mounttypecache)). The optimization guide completes the picture: a cache mount is "a persistent cache location" for builds; the cache accumulates across builds and is shared among several of them ([Docker, "Optimize cache usage"](https://docs.docker.com/build/cache/optimize/)).

In plain terms: during that `RUN`, the `/root/.cache/go-build` directory is not part of the layer. It is a directory the **builder** keeps separately and mounts again on every build. Go finds there what it compiled the previous time, and what it writes there does not end up in the image.

The options the `revisor` uses:

- **`type=cache`**: the mount type.
- **`target=/root/.cache/go-build`**: where the directory appears inside the `RUN`. It is Go's default cache directory, so Go uses it without any configuration. Docker's guide uses this same path in its Go example.
- **`id=curso-docker-go-build`**: the cache's name. The reference says it is optional and is used "to identify separate/different caches"; if you do not give it, it defaults to the value of `target`. Further down you will see why it is worth giving it.

There are other options (`sharing`, `mode`, `uid`…), and the reference lists them; the `revisor` does not need them. One note: the mount is used at build time, when the user is still `root`; the `USER 10001:10001` comes afterwards and does not affect it.

#### 4.4.3 The cache lives in the builder, not in the image

Claims get verified. Section 6 of `fig04_03.sh` looks for the cache in the two places it could be:

```text
## 6. La caché de compilación vive en el constructor, no en la imagen
$ docker buildx du --filter 'description~=curso-docker-fig04-go-build'
ID                           RECLAIMABLE   SIZE      LAST ACCESSED
xq0we4j0a5g4a98ftg4xaezzc*   true          99.59MB   1 second ago
$ docker buildx du --verbose --filter 'description~=curso-docker-fig04-go-build' | grep -E '^(Description|Type):'
Description:  cached mount /root/.cache/go-build from exec /bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor with id "/curso-docker-fig04-go-build"
Type:         exec.cachemount
$ docker run --rm --name curso-docker-mira --user 0 curso-docker-revisor:1.1.0 sh -c 'du -sh /root/.cache/go-build 2>&1'
du: cannot access '/root/.cache/go-build': No such file or directory
[código de salida: 1]
$ docker run --rm --name curso-docker-mira --user 0 curso-docker-revisor:1.0.0 sh -c 'du -sh /root/.cache/go-build 2>&1'
95M	/root/.cache/go-build
```

The identifier on the first line and the "1 second ago" change; the sizes may vary by a few megabytes. `docker buildx du` shows what the builder takes up on disk (*disk usage*), and `--filter description~=...` keeps the records whose description contains that text. With `--verbose` it shows each record in full; the `grep` keeps its description and its type, which you will need in 4.4.5. The two `docker run`s enter each image as `root` (`--user 0`, only to be able to read `/root`) and measure the directory.

Three lines, three facts:

1. **In the builder** there is a 99.59 MB cache, of type `exec.cachemount` (cache mount), with the script's `id`. That is where what Go compiled lives.
2. **In image `1.1.0`**, the directory does not even exist. The cache did not travel.
3. **In image `1.0.0`**, Lesson 3's, the directory weighs 95 MB. That is where the extra 100 MB were.

And why does the script use `curso-docker-fig04-go-build` and not the Dockerfile's `curso-docker-go-build`? Because the script changes the `id` when it assembles its copy of the project, to have a cache **of its own**, truly start cold, and be able to delete it at the end without touching your project's. It is the same idea you will see in 4.4.5.

And section 5 of the same script confirms it from the images:

```text
$ docker history curso-docker-revisor:1.1.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70
0B	CMD ["revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 10001:10001
10MB	RUN /bin/sh -c go build -o /usr/local/bin/re…
77.8kB	COPY internal/ internal/ # buildkit
41kB	COPY cmd/ cmd/ # buildkit
12.3kB	COPY go.mod ./ # buildkit
8.19kB	WORKDIR /src
4.1kB	WORKDIR /go
$ docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^curso-docker-revisor:1\.[01]\.0 '
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.0.0 1.45GB
$ for i in curso-docker-revisor:1.0.0 curso-docker-revisor:1.1.0; do docker image inspect --format "$i {{.Size}}" $i; done
curso-docker-revisor:1.0.0 337298513
curso-docker-revisor:1.1.0 314341606
```

The `RUN` went from 110 MB to **10 MB**: now the layer contains only the executable. The three code layers add up to the same as the earlier `COPY . .`, split up. That is the solid number: **the layer slimmed down by 100 MB**, without removing anything the `revisor` needs.

The other two lines count the image's size in two ways, and it is worth not confusing them. `docker image inspect` gives the size of the **content**, compressed as it is stored and transferred: 337.3 MB versus 314.3 MB, 23 MB less. `docker image ls` gives 1.45 GB versus 1.32 GB, about 130 MB less. The difference between the two ways comes from Docker Engine 29's image store, which according to its documentation stores images "in both compressed and uncompressed format" ([Docker, "containerd image store"](https://docs.docker.com/engine/storage/containerd/)). The 130 MB add up with that explanation: about 100 MB of uncompressed layer plus about 23 MB compressed, with the gigabyte rounding. That sum is our own arithmetic, not a rule from the documentation; what is certain is the layer in `docker history`. It is a saving you were not looking for, and it came from doing right what you were looking for.

> [!NOTE]
> 🔧 **Engineering observation 4.2**
> There are two caches and it is worth not confusing them. The **layer cache** decides whether a step is repeated or not: it is all or nothing. The **cache mount** makes it so that, when a step is repeated, it is repeated cheaply. The Dockerfile's order works on the first; the `--mount`, on the second. With both together, the `RUN go build` is almost never skipped, but it almost never costs anything.

#### 4.4.4 The two caches are independent

A detail that will save you some confusion: they are two separate things, and they are managed separately. `--no-cache` asks the builder not to use the **layer** cache; for a cold measurement to be honest, section 1 of `fig04_03.sh` also deletes its **mount** before starting, with its own `id` (4.4.5). And the other way around: a step that comes from the layer cache does not execute its `RUN`, so it neither reads nor fills the mount. If you build once with everything in the layer cache, the mount stays as empty or as full as it was.

#### 4.4.5 An `id` of your own, and why never a broad deletion

The cache mount takes up disk space, and one day you are going to want to delete it. The command is `docker buildx prune`, which deletes builder cache, and its `--filter` option lets you choose what to delete: by age (`until`), by type (`type`, and one of the types is `exec.cachemount`, exactly the one for mounts), or by text in the description (`description`) ([`docker buildx prune`](https://docs.docker.com/reference/cli/docker/buildx/prune/)). You already saw in 4.4.3 what a cache mount's description looks like: `cached mount /root/.cache/go-build from exec … with id "/curso-docker-fig04-go-build"`. The `id` appears at the end, after a slash and between quotes. That is why the `id` matters: it is the label that lets you find **your** cache and only yours.

Here is the danger. A broad filter, such as `description~=go-build`, catches the compilation cache of **any** Go project on the machine that uses the default path. This is not hypothetical: on the machine used for these runs, while this lesson was being written, `docker buildx du --filter 'description~=go-build'` found two records, this lesson's and that of another project that was building at the same time. A `prune` with that filter would have deleted the other one's cache, and its next build would have been slow without anyone knowing why. On a shared machine (a build server, a team computer, or yours with several projects), a broad deletion is deleting other people's stuff.

This course's rule has two parts:

1. **Each project, its own `id`.** The `revisor` uses `curso-docker-go-build`. If tomorrow you package another Go project, you give it another one. Without an `id`, every project that uses `target=/root/.cache/go-build` shares the same cache, because the default `id` is the path.
2. **Delete with the full `id` and the type.** This is how this lesson's scripts do it on exit:

```bash
docker buildx prune -f --filter type=exec.cachemount \
  --filter "description~=[^a-z0-9-]curso-docker-fig04-go-build[^a-z0-9-]"
```

The `type=exec.cachemount` limits the deletion to cache mounts. The `~=` matches against a regular expression, and the `[^a-z0-9-]` on each side ("any character that is not a lowercase letter, digit, or hyphen") requires the `id` to appear **in full**: in the description, what surrounds the `id` is the slash before it and the quote after it, and both qualify. That way, a longer `id` that contains it, such as `curso-docker-fig04-go-build-viejo`, is not deleted by accident. Why not write the slash and the quotes directly in the filter? Because with the Buildx version of these runs (v0.31.1), a filter with spaces, quotes, or `/` found nothing: it was measured with `docker buildx du` before using it. It is a good habit: **test a filter with `du`, which only looks, before using it with `prune`, which deletes.**

A deletion that does not tell you whether it deleted anything proves nothing, so section 8 of `fig04_03.sh` deletes in plain view and then searches again:

```text
## 8. Borro SOLO mi caché de compilación y compruebo que ya no está
$ docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]curso-docker-fig04-go-build[^a-z0-9-]' | tail -1
Total:	99.59MB
$ docker buildx du --filter 'description~=curso-docker-fig04-go-build'
ID        RECLAIMABLE   SIZE      LAST ACCESSED
```

The `prune` reports what it freed (`Total: 99.59MB`, the same cache as in section 6), and the following `du` no longer finds anything: only the table header remains. For your project, the same command with `curso-docker-go-build` deletes the `revisor`'s cache and nothing else; the next build will be slow once and will fill it again.

### 4.5 Measuring: the stopwatch and `--progress=plain`

#### 4.5.1 Seeing what the builder does

When you build in a terminal, BuildKit draws a screen that redraws itself and uses color. It is fine for watching, but you cannot save it or search it. The `--progress` option decides the format. According to the `docker buildx build` reference, the default value is `auto`, which uses `tty` mode (the interactive one, "with color and redrawing") if the output is a terminal, and `plain` if not; `plain` "prints the raw build progress in a plaintext format" ([`docker buildx build`, `--progress`](https://docs.docker.com/reference/cli/docker/buildx/build/#progress)). On a build server, where there is no terminal, you always see `plain`, so it is worth knowing how to read it.

Plain text has this shape: each step is a number with `#` in front. First comes the line naming it, such as `#10 [5/6] COPY internal/ internal/`, and then the lines of what it did, all with the same number. A step normally ends with one of two lines: `#10 CACHED`, if it came from the cache, or `#10 DONE 0.5s`, if it was done, with its time. If it fails, it ends with `#10 ERROR: …`, as you will see in 4.6.2. The `[internal]` steps are the ones the builder does on its own: reading the Dockerfile, the `.dockerignore`, the context.

#### 4.5.2 The measurement script

`fig04_03.sh` builds both Dockerfiles in four situations, times each build, and summarizes the `--progress=plain` log in a table of steps. It is the lesson's longest script, and its sections 5 to 8 are the ones you already saw in 4.1.2, 4.3.3, 4.4.3, and 4.4.5:

```bash
#!/usr/bin/env bash
# fig04_03.sh — Capas y caché: el Dockerfile de la Lección 3 contra el de la
# Lección 4. Construye los dos en frío, otra vez sin cambios y después de
# cambiar un archivo; cronometra cada construcción, muestra qué pasos salieron
# de la caché (--progress=plain) y compara las capas con docker history.
# Borra al salir sus imágenes y su caché de compilación.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L3="${PREFIJO}revisor:1.0.0"
L4="${PREFIJO}revisor:1.1.0"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
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
t() { date +%s%3N; }
# construir ETIQUETA DOCKERFILE [opciones...]: construye con --progress=plain,
# guarda el registro en ../construccion.log e imprime cuánto tardó
construir() {
  local etiqueta="$1" archivo="$2" inicio fin; shift 2
  inicio=$(t)
  docker build --progress=plain "$@" -t "$etiqueta" -f "$archivo" . > ../construccion.log 2>&1
  fin=$(t)
  echo "$etiqueta ($archivo${*:+ $*}): $(( fin - inicio )) ms"
}
# pasos: de ../construccion.log, cada paso [n/m] con su estado final
pasos() {
  awk '
    /^#[0-9]+ \[([a-z0-9-]+ )?[0-9]+\/[0-9]+\]/ {
      if (!($1 in paso)) {
        l=$0; sub(/^#[0-9]+ \[([a-z0-9-]+ )?/, "", l); split(l, p, "/"); i=p[1]+0
        sub(/^[0-9]+\/[0-9]+\] /, "", l); sub(/--mount=[^ ]+ +/, "", l); paso[$1]=i; nombre[i]=l; if (i > k) k=i
      }
    }
    /^#[0-9]+ (CACHED|DONE)/ { if ($1 in paso) estado[paso[$1]]=$2 ($2=="DONE" ? " " $3 : "") }
    END { for (i=1; i<=k; i++) printf "  paso %d  %-10s %s\n", i, estado[i], substr(nombre[i], 1, 60) }
  ' ../construccion.log
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rm -f "${PREFIJO}revisor" >/dev/null 2>&1; docker rmi -f "$L3" "$L4" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "1. En frío: sin caché de capas y con la caché de compilación vacía"
borrar_cache
construir "$L3" Dockerfile.leccion3 --no-cache
pasos
construir "$L4" Dockerfile --no-cache
pasos

titulo "2. Otra vez, sin cambiar nada"
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "3. Cambio un comentario en internal/reporte/tabla.go"
echo "// cambio de prueba $(date +%s)" >> internal/reporte/tabla.go
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "4. Cambio un archivo que el .dockerignore deja fuera"
echo "notas de trabajo $(date +%s)" > NOTAS.md
construir "$L4" Dockerfile
pasos

titulo "5. Las capas de cada imagen: solo los pasos de la receta"
muestra "docker history $L3 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70"
muestra "docker history $L4 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70"
muestra "docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^${PREFIJO}revisor:1\.[01]\.0 '"
muestra "for i in $L3 $L4; do docker image inspect --format \"\$i {{.Size}}\" \$i; done"

titulo "6. La caché de compilación vive en el constructor, no en la imagen"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
muestra "docker buildx du --verbose --filter 'description~=${CACHE_ID}' | grep -E '^(Description|Type):'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L4 sh -c 'du -sh /root/.cache/go-build 2>&1'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L3 sh -c 'du -sh /root/.cache/go-build 2>&1'"

titulo "7. La imagen nueva hace lo mismo que la vieja"
docker run -d --name "${PREFIJO}revisor" -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$L4" >/dev/null
for _ in $(seq 40); do docker exec "${PREFIJO}revisor" curl -fsS -o /dev/null http://127.0.0.1:8080/salud 2>/dev/null && break; sleep 0.5; done
muestra "docker exec ${PREFIJO}revisor curl -s http://127.0.0.1:8080/salud"
docker rm -f "${PREFIJO}revisor" >/dev/null

titulo "8. Borro SOLO mi caché de compilación y compruebo que ya no está"
muestra "docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]' | tail -1"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
```

The helpers at the beginning are Lesson 3's (`titulo`, `muestra`, `t`), plus three new ones. `construir` builds with `--progress=plain`, saves the log to a file, and times it. `pasos` is a small `awk` program that reads that log and, for each numbered step `[n/m]`, prints its number, its name, and its final state; it strips the `--mount=...` option from the name so the line fits, and it numbers the steps itself because, when another build shares identical steps on the same machine, BuildKit may show the other build's step number. `borrar_cache` is the one from 4.4.5.

Three more details. The change includes the time (`$(date +%s)`) so that it is different on every run: if you always wrote the same text, the second time you ran the script that content would already be in the layer cache, and the "change" would come out `CACHED`. (It happened to the author of this lesson in a first version of the script, and it is a good example of how the cache remembers contents, not moments.) Section 7 uses `docker exec ... curl` to talk to the `revisor` from inside its container, without publishing ports. And the script, like those in Lesson 3, deletes on exit the images it created; if you want to keep `1.1.0`, build it afterwards in your project with `docker build -t curso-docker-revisor:1.1.0 .`.

#### 4.5.3 The numbers

Sections 1 and 2 of the output:

```text
$ PREFIJO=curso-docker-l04- ./fig04_03.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## 1. En frío: sin caché de capas y con la caché de compilación vacía
curso-docker-revisor:1.0.0 (Dockerfile.leccion3 --no-cache): 9909 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY . .
  paso 4  DONE 7.1s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor
curso-docker-revisor:1.1.0 (Dockerfile --no-cache): 12207 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 10.5s RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## 2. Otra vez, sin cambiar nada
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 1176 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY . .
  paso 4  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
curso-docker-revisor:1.1.0 (Dockerfile): 628 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

The times change on every run; the sequence of `CACHED` and `DONE` is stable. (The `WORKDIR /src` comes out `CACHED` even with `--no-cache`. It is a detail of how BuildKit treats that step, which adds no files from the context and executes nothing, and it does not change what matters: the `COPY`s and the `RUN` were indeed redone.)

**Cold**, both compile everything from scratch. The times in this run (9.9 and 12.2 s) depend mostly on the machine's noise: in earlier runs of the same script, with the same builds and the machine more or less busy, they came out at 12.5 versus 7.1 s, 18.6 versus 10.5 s, and 20.2 versus 23.0 s, sometimes one winning and sometimes the other. What is stable is the order of magnitude: **ten to twenty seconds**, the cost of compiling everything. No ordering removes that cost: the first build is always paid for.

**Without changes**, both come entirely from the cache in under a second. No difference here either: the cache works equally well with both Dockerfiles when nothing changed.

The difference appears in section 3, **with a change**, which is the one you saw in 4.2.2 and 4.3.3: 13.0 s versus 1.8 s, and the `RUN` at 10.1 s versus 0.8 s. And that is the case that matters, because it is the everyday one: you change something and build again.

Section 4 closes with a case that connects to what comes next:

```text
## 4. Cambio un archivo que el .dockerignore deja fuera
curso-docker-revisor:1.1.0 (Dockerfile): 790 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

A `NOTAS.md` was added to the folder and everything came from the cache. The file did not even reach the builder: the `.dockerignore` left it out (4.6). What does not travel cannot invalidate anything.

> [!NOTE]
> 🔧 **Engineering observation 4.3**
> A build time on its own, without the table of steps, tells you nothing useful: you do not know whether it was slow because it compiled, because it downloaded, or because the machine was busy. When a build takes longer than you expect, the first question is not "how long did it take?", but "which step was redone, and why?". `--progress=plain` gives you that answer step by step.

### 4.6 What travels in the context

#### 4.6.1 BuildKit only asks for what it needs

In Lesson 3 you saw that the context is the folder you give `docker build` and that the `.dockerignore` says what does not travel. One piece is missing: **BuildKit does not send the whole context**. Among the improvements its documentation lists over the previous builder are two you are about to see: "Incrementally transfer only the changed files in your build context between builds" and "Detect and skip transferring unused files in your build context" ([Docker, "BuildKit"](https://docs.docker.com/build/buildkit/)).

`fig04_04.sh` measures it. It plants a 50 MB backup and a fake 10 MB `.git` folder in the project folder, and builds three times:

```bash
#!/usr/bin/env bash
# fig04_04.sh — Qué viaja en el contexto. Siembra en la carpeta un respaldo de
# 50 MB y una carpeta .git falsa de 10 MB, y construye tres veces:
#   1) Dockerfile de esta lección (COPY selectivos), con .dockerignore;
#   2) Dockerfile de la Lección 3 (COPY . .), con .dockerignore;
#   3) Dockerfile de la Lección 3, SIN .dockerignore: falla a propósito.
# Borra al salir lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L4="${PREFIJO}revisor:1.1.0"
CON="${PREFIJO}revisor:con-ignore"
SIN="${PREFIJO}revisor:sin-ignore"

cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rmi -f "$L4" "$CON" "$SIN" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB"
head -c 52428800 /dev/urandom > respaldo.tar
mkdir -p .git && head -c 10485760 /dev/urandom > .git/objeto-falso
muestra "for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size \$f; done"

titulo "1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore"
muestra "docker build --progress=plain -t $L4 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore"
muestra "docker build --progress=plain -t $CON -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "3. Dockerfile de la Lección 3, SIN .dockerignore"
mv .dockerignore dockerignore.apartado
muestra "docker build --progress=plain -t $SIN -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"
grep -E -A4 '^#[0-9]+ ERROR|error obtaining' ../construccion.log | head -8
mv dockerignore.apartado .dockerignore
```

`head -c 52428800 /dev/urandom` writes 50 MB of random bytes: a file that weighs as much as a real backup and cannot be compressed. `du -sh --apparent-size` measures the size of each thing. From each build, the script saves the log and looks for the `transferring context` line, which says how much the client sent to the builder. It is `set -uo pipefail`, without `-e`, because the third build fails on purpose and the script has to continue. The three builds use three different tags (`1.1.0`, `con-ignore`, and `sin-ignore`) so that you can tell from the output which is which.

```text
$ PREFIJO=curso-docker-l04- ./fig04_04.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB
$ for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size $f; done
50M	respaldo.tar
10M	.git
15K	cmd
27K	internal
41	go.mod
61M	.

## 1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:1.1.0 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 0
#7 transferring context: 42.80kB done

## 2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:con-ignore -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 0
#7 transferring context: 1.00kB done
```

The step numbers (`#7`) and the times may change; the transferred sizes are stable if you run the script as-is.

The folder weighs **61 MB**, and the code, about 42 kB. In the first build, **42.80 kB** traveled: the code and nothing else. In the second, **1.00 kB** traveled, even though Lesson 3's Dockerfile asks for everything with `COPY . .`. The documentation's two sentences explain the two numbers:

- **"Skip unused files"**: in the first, the backup and the `.git` did not travel for two reasons at once. The `.dockerignore` excludes them, and moreover the `COPY`s only ask for `go.mod`, `cmd/`, and `internal/`.
- **"Only the changed files"**: in the second, the code was already on the builder's side from the first build, and had not changed. Only differences were sent. That is why the number on the `transferring context` line depends on what you built before in that same folder: the first time it sends the code; the following times, almost nothing.

#### 4.6.2 Without `.dockerignore`: the lesson's error

The third build is Lesson 3's Dockerfile, with `COPY . .`, **without** `.dockerignore`:

```text
## 3. Dockerfile de la Lección 3, SIN .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:sin-ignore -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 1
#6 transferring context: 62.93MB 0.1s done
#10 0.344 error obtaining VCS status: exit status 128
#10 0.344 	Use -buildvcs=false to disable VCS stamping.
#10 ERROR: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
------
 > [4/4] RUN go build -o /usr/local/bin/revisor ./cmd/revisor:
0.344 error obtaining VCS status: exit status 128
0.344 	Use -buildvcs=false to disable VCS stamping.
------
```

The step numbers and times (`0.344`, `0.1s`) change; the rest is stable.

Two things happened. The first, the one you expected: **62.93 MB** traveled, the backup, the `.git`, and the code. Those are the 62 MB from the opening scene: those of a folder without `.dockerignore`, with a backup and the Git history. On your machine it is a second; on a build server that sends the context over the network, on every build, it is noticeable. And what travels with `COPY . .` ends up inside the image, like the `.env` in Lesson 3.

The second is the surprise: **the build failed**, and not because of Docker. The `.git` reached `/src` inside the image, and Go, when compiling, saw it. By default, Go tries to stamp version control information into the executable (which *commit*, whether there were unsaved changes), and it does so when the main package, its module, and the current directory are in the same repository ([`go` documentation, `-buildvcs` flag](https://pkg.go.dev/cmd/go#hdr-Build_flags)). To do that it called the version control tool, and since the `.git` was fake, the tool failed: `exit status 128`. Go stopped and suggested `-buildvcs=false`.

You are going to see this error in real life with a real but incomplete `.git`, or in an image where the `git` tool cannot read the repository. And with a complete, healthy repository, it does not fail, but it does something worse without warning: it stamps data from your repository into the executable, and the image's contents depend on whether there were unsaved changes in your folder.

#### 4.6.3 The lesson's `.dockerignore`

The fix is not `-buildvcs=false`. It is keeping the `.git` from traveling. This is the `.dockerignore` the lesson ends with; it replaces Lesson 3's:

```text
# fig04_02.dockerignore
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

Lesson 3's five lines are still there, with their reasons. Three are added:

- **`*.md`**: notes, the `README.md`, the logbook. The `revisor` does not need any Markdown file to compile, and you already saw in section 4 of `fig04_03.sh` that, with this line, editing your notes invalidates nothing.
- **`compose.yaml`**: the file that describes the complete system, which you will write in Lesson 9. It describes how the image is **run**; it has no business being **inside** it.
- **`secretos/`**: the folder where, starting with Lesson 6, the files with fake tokens will live. It is excluded from today, before it exists, for the same reason that in Lesson 3 the `.env` was excluded before there was one: the day someone creates that folder, the `.dockerignore` will already be waiting for it.

With this file and the selective `COPY`s, there are two barriers between your folder and the image: what the `.dockerignore` lets travel, and of that, only what some `COPY` asks for.

> [!NOTE]
> 🔧 **Engineering observation 4.4**
> Selective `COPY`s make the `.dockerignore` look unnecessary: in build 1 nothing extra traveled. Do not get complacent. The day someone adds a `COPY . .` (in a hurry, or to copy a new file), the only barrier left is the `.dockerignore`. When two defenses back each other up, you write both.

### 4.7 Checking before building

The habit from Lesson 3 is not lost because the Dockerfile changed. `fig04_06.sh` checks the new Dockerfile with `docker build --check`, which runs the checks without building anything ([Docker, "Build checks"](https://docs.docker.com/build/checks/)):

```bash
#!/usr/bin/env bash
# fig04_06.sh — Revisar el Dockerfile de la lección antes de construir, como en
# la Lección 3. No construye nada ni crea contenedores.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
docker build --check . 2>&1 | tail -1
```

```text
$ ./fig04_06.sh
Check complete, no warnings found.
```

This output is stable. The `tail -1` keeps only the verdict; without it you would see the same `[internal]` steps as in Lesson 3. The `RUN --mount` does not bother the check: it is current Dockerfile syntax, and the `# syntax=docker/dockerfile:1` line at the top guarantees the builder understands it.

### 4.8 What you will see in other projects

- **`COPY go.mod go.sum ./` followed by `RUN go mod download`.** It is the best-known trick for Go projects with dependencies: download them in a layer that is only redone when the list changes. It is a good idea **when there are dependencies**. The `revisor` has none (which is why it has no `go.sum`), so that layer would have nothing to download. If you package a project with dependencies, that pair of lines goes exactly where `COPY go.mod ./` is here, and Docker's guide also uses a second cache mount, `target=/go/pkg/mod`, for the downloaded modules ([Docker, "Optimize cache usage"](https://docs.docker.com/build/cache/optimize/)).
- **Everything in one giant `RUN` with `&&`.** It makes sense for installing packages and cleaning up in the same layer (remember Observation 4.1: what is deleted in another layer still weighs). It does not make sense for mixing steps that change at different rates.
- **`DOCKER_BUILDKIT=0`.** It enables the builder that preceded BuildKit (the *legacy builder*), which has neither cache mounts nor the incremental transfers from 4.6. BuildKit is Docker Engine's default builder ([Docker, "BuildKit"](https://docs.docker.com/build/buildkit/)); if a tutorial asks you to turn it off, be wary of the tutorial. Do not confuse it with `docker builder`, which is just the command group for managing builds, such as `docker builder prune` ([`docker builder`](https://docs.docker.com/reference/cli/docker/builder/)).
- **`docker system prune -a` or `docker builder prune -a` "to free up space".** They delete the cache of **every** project on the machine. You already know why not (4.4.5).

## The error you will see

This lesson has one main error and a symptom that does not produce an error but costs time.

**1. The `.git` that breaks the compilation.**

```text
#10 0.344 error obtaining VCS status: exit status 128
#10 0.344 	Use -buildvcs=false to disable VCS stamping.
#10 ERROR: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

It reads from top to bottom: Go tried to obtain the version control status (*VCS status*), the tool failed with code 128, and Go suggests not stamping that information. The last line is Docker's: the `RUN` ended with code 1 and the build stopped. The cause is almost never in your code: it is that a `.git` reached the image. Check in this order: is the `.dockerignore` in the root of the context, next to the `Dockerfile`? Does it say `.git`? Is there a `COPY . .` in the Dockerfile? The fix is keeping the `.git` from traveling. `-buildvcs=false` also removes the error, but it leaves the `.git` traveling and getting into the image: it is silencing the alarm without putting out the fire.

**2. Everything rebuilds even though you changed little.** There is no error message; there is only waiting. You diagnose it with `--progress=plain`: look for the **first** step after the `FROM` that says `DONE` instead of `CACHED`. That is the step whose contents changed, and everything below was repeated because of rule 3. If that first step is a `COPY . .`, you already know the fix (4.3). If it is a `COPY` of a file you did not touch, look for what else changed in that path: a generated file, some notes, a backup. What must not invalidate the cache must not travel either: it goes in the `.dockerignore`.

## The security habit of the lesson

**The build context carries no `.git`, `.env`, backups, or secrets, and the Dockerfile check is always run.** The habit prevents two accidents. The first is the one in 4.6: a `.git`, a `.env`, or a backup that travels to a build server and, with a `COPY . .`, stays inside an image that is later published. The `.git`, moreover, can hold secrets that someone deleted from the code but not from the history. The second is quieter: the compilation cache with another project's `id`, or a broad deletion that takes everyone's. An `id` of your own and a deletion with the full `id` keep each project in its own lane.

And a security bonus that the cache mount brings: what the compiler leaves in its cache does not stay in the image. Fewer files inside means a smaller attack surface, and fewer things to explain on the day someone reviews what your image contains.

## What gets done wrong

**`COPY . .` and then compiling.** Any change, even a comment or a note, repeats the full compilation. Copy first what changes little and at the end what changes a lot.

**Trusting the cache to "notice" what changed.** The cache is a chain: it breaks at the first link that changes and everything below is repeated. The Dockerfile's order is your tool for putting that link as low as possible.

**Deleting the compilation cache with `rm -rf` at the end of the `RUN`.** It shrinks the layer, but it also throws away what speeds up the next build. The cache mount gives you both: the small layer and the live cache.

**Using `-buildvcs=false` to get rid of the `.git` error.** It removes the symptom and leaves the `.git` inside the image.

**Measuring only the total time.** A number without the table of steps does not say what was redone. `--progress=plain` does.

**Using the default `id` or a generic `id` for the cache mount.** Different projects end up sharing, and stepping on, the same cache.

**Cleaning up with `prune -a` or with a broad filter.** It takes the cache of other projects on the same machine. You delete with the type and the full `id`.

**Removing lines from the `.dockerignore` because "with selective `COPY`s it is no longer needed".** It is needed on the day someone writes `COPY . .` again.

## Exercises

Do them in order and write your prediction in your [logbook](bitacora.md) before running each one. When you finish, delete what you created: everything carries the `curso-docker-` prefix, and the exercises' compilation cache is deleted with the command from 4.4.5 and its own `id`.

### Exercise 1 — Predict the cache

With the lesson's Dockerfile and a previous build in the cache, predict for each change which steps will say `CACHED` and which `DONE`. Do it with pencil and paper, using the three rules from 4.2.1, and then check it with `fig04_05.sh`, which applies the four changes one after another:

a) You only change the date of `internal/reporte/tabla.go` with `touch`, without touching its contents.
b) You add a comment at the end of `cmd/revisor/main.go`.
c) You add a comment at the end of `go.mod`.
d) You add a comment (`# ...`) at the end of the `Dockerfile`.

And one more question: in case c, do you expect the `RUN go build` to take a long or a short time? Why?

### Exercise 2 — The `.dockerignore` as the only barrier (project)

Copy `programas/revisor/` to a folder of your own and give it the lesson's `.dockerignore` and, as `Dockerfile.leccion3`, Lesson 3's Dockerfile, the one with `COPY . .`. On purpose: with `COPY . .`, the `.dockerignore` is the only barrier. Build `curso-docker-revisor:1.0.0-ej2` once with `-f Dockerfile.leccion3 --progress=plain` and note down the `transferring context` line. Then create in the folder a `README.md`, a `secretos/` folder with a fake `token.txt` file, and a 5 MB `datos.json` file (`head -c 5242880 /dev/urandom > datos.json`). Before rebuilding, predict which of the three travel. Rebuild and look at the line again. Then add to the `.dockerignore` whatever is needed and rebuild a third time. The exercise is self-checking: you are done when the transferred context is back to a few kilobytes and `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src` shows only `cmd`, `go.mod`, and `internal`. At the end, `docker rmi curso-docker-revisor:1.0.0-ej2` and delete the folder.

### Exercise 3 — Fix the order

A teammate wrote this Dockerfile for the `revisor`. It works, but every change in the code repeats everything:

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
WORKDIR /src
COPY internal/ internal/
COPY cmd/ cmd/
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
COPY go.mod ./
USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

1. Before building: does this build work or fail? Think about what `go build` needs to compile a module.
2. Find the order and cache problems, and write the corrected version.
3. Build your version twice, the second time after changing a comment in `internal/reporte/tabla.go`, and verify with `--progress=plain` that `COPY go.mod ./` and `COPY cmd/ cmd/` say `CACHED`.

### Exercise 4 — Explain it to your teammate

Your teammate from the opening scene asks you: "If the `RUN go build` now says `DONE` every time I change code, what do we gain with the `--mount`? It still gets repeated." Answer her in five sentences at most, using the words *layer cache*, *cache mount*, *builder*, and *image*.

## Solutions

### Solution 1

The real output of `fig04_05.sh`:

```text
$ PREFIJO=curso-docker-l04- ./fig04_05.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## a) Solo cambia la fecha de un archivo (touch), no su contenido
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## b) Un comentario nuevo en cmd/revisor/main.go
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.4s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## c) Un comentario nuevo en go.mod
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.3s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## d) Un comentario nuevo en el Dockerfile
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

a) **All `CACHED`.** The modification date does not count for the cache (rule 1); only the contents do.
b) **From `COPY cmd/` down.** `cmd/` changed; `internal/` did not, but it comes after, so it is repeated because of rule 3 (that is why it says `DONE` even though nothing in it is different); and so is the `RUN`.
c) **From `COPY go.mod` down: everything.** `go.mod` is the first `COPY`, so a change there invalidates the whole chain. That is why only what almost never changes goes first.
d) **All `CACHED`.** The cache is calculated per instruction, and a comment is not an instruction: no step changed. (A change to an instruction, on the other hand, does invalidate that step and the ones below.)

The extra question: in case c the `RUN` is repeated, but it takes **little** time (0.3 s in this run), because the cache mount already has all the packages compiled and a comment in `go.mod` does not change what Go has to compile. The layer cache said "repeat the step"; Go's cache said "but there is almost nothing to do". If your times come out different, that is fine; what must match is the `CACHED` and `DONE` column.

### Solution 2

In the second build **`datos.json`** travels, and the `transferring context` line gives it away: it goes from kilobytes to about 5 MB. `README.md` does not travel (`*.md` excludes it), and neither does `secretos/` (it has its own line). With `COPY . .`, `datos.json` also gets into the image: `ls -A /src` shows it. The fix is one more line in the `.dockerignore`: `datos.json`, or `*.json` if the `revisor` does not need any JSON to compile, which is the case. With that, the third build again transfers a few kilobytes and `/src` is left with `cmd`, `go.mod`, and `internal`. If the number does not go down, check that the `.dockerignore` is in the root of the context, next to the Dockerfiles.

Notice that with the lesson's Dockerfile, the one with selective `COPY`s, `datos.json` would not have traveled even without that line, because no `COPY` asks for it. That is Observation 4.4 in action: with `COPY . .`, the `.dockerignore` is the only barrier; with selective `COPY`s, it is the second one. Write it anyway.

### Solution 3

1. **It fails.** `go build` needs the `go.mod` to know which module it is compiling, and in this Dockerfile the `go.mod` arrives **after** the `RUN`. Compiling without `go.mod` gives this error, measured inside the `golang:1.27.3-trixie` image with a minimal `main` package in `cmd/revisor`: `go: go.mod file not found in current directory or any parent directory; see 'go help modules'`. Inside the build you will see it in the format of a failing `RUN`, as in 4.6.2.
2. The problems: `go.mod` comes after the `RUN` (error) and should come first (cache); `internal/` comes before `cmd/`, the reverse of the lesson's order (less serious, but the one that changes more should go below); and the `RUN` has no cache mount, so every change compiles from scratch. The corrected version is `fig04_01.Dockerfile`.
3. With the corrected version, after the change in `tabla.go`, the table says `CACHED` for `WORKDIR`, `COPY go.mod ./`, and `COPY cmd/ cmd/`, and `DONE` for `COPY internal/ internal/` and the `RUN`, as in 4.3.3.

### Solution 4

One possible answer: "The **layer cache** decides whether a step is repeated, and since the code changed, the `RUN go build` is repeated: nothing prevents that. What the **cache mount** does is that, when it is repeated, Go finds there everything it compiled the previous time and only recompiles the package you touched. The **builder** keeps that cache separately, and it does not get into the **image**. That is why the `RUN` went from 10.1 to 0.8 seconds, and the compilation layer weighs 100 MB less. It gets repeated, yes, but almost for free."

## How I know I succeeded

Check each item only if you verified it on your machine:

- [ ] `docker build --check .` with the lesson's Dockerfile ends with `Check complete, no warnings found.`
- [ ] `docker history curso-docker-revisor:1.1.0` shows three separate `COPY` layers and a `RUN` of about 10 MB.
- [ ] `docker image ls curso-docker-revisor` shows `1.1.0` lighter than `1.0.0` (in these runs, 1.32 GB versus 1.45 GB).
- [ ] After changing a comment in `internal/`, `--progress=plain` shows `CACHED` for `COPY go.mod ./` and for `COPY cmd/ cmd/`, and the `RUN` takes less than a couple of seconds.
- [ ] Adding or editing a `.md` file in the folder invalidates no step.
- [ ] With a large file in the folder, the `transferring context` line stays in kilobytes.
- [ ] You know how to read the `error obtaining VCS status` error and you fix it with the `.dockerignore`, not with `-buildvcs=false`.
- [ ] You deleted your compilation cache with `docker buildx prune` filtering by `type=exec.cachemount` and by the full `id`, and `docker buildx du --filter 'description~=curso-docker-go-build'` no longer shows it.
- [ ] When you finish, `docker ps -a --filter name=curso-docker-` shows nothing, and of the `revisor`'s images only the one you want to keep remains.

## Summary

Answer without looking at the lesson:

1. What is a layer? Which instructions add files and which only values? With what command do you see them?
2. What does the cache look at to decide whether a `COPY` is repeated? And for a `RUN`? Does a file's date count?
3. What happens to the steps below when one is invalidated? What consequence does that have for the Dockerfile's order?
4. What does `RUN --mount=type=cache` do? Where does that cache live and why does it not end up in the image?
5. What is a cache mount's `id` for, and why is a `prune` with a broad filter dangerous?
6. What do `CACHED` and `DONE` mean in `--progress=plain`? When do you see `plain` even if you do not ask for it?
7. Which files does the client send to the builder? Why does the second build transfer less than the first?
8. What causes the `error obtaining VCS status` error and what is the correct fix?

## Sources

All consulted on October 21, 2026.

- [Docker, "Docker build cache"](https://docs.docker.com/build/cache/): one layer per instruction and chained invalidation.
- [Docker, "Build cache invalidation"](https://docs.docker.com/build/cache/invalidation/): the rules for `COPY`, `ADD`, and `RUN`, and that the modification date does not count.
- [Docker, "Optimize cache usage"](https://docs.docker.com/build/cache/optimize/): layer order, a small context, cache mounts, and their Go example.
- [Dockerfile reference, `RUN --mount=type=cache`](https://docs.docker.com/reference/dockerfile/#run---mounttypecache): the `id`, `target`, `sharing`, and other options, and the default `id`.
- [Docker, "Understanding the image layers"](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/): what a layer is and why it is reused.
- [`docker image history`](https://docs.docker.com/reference/cli/docker/image/history/): the command, `--format`, and `--no-trunc`.
- [`docker buildx build`, `--progress` option](https://docs.docker.com/reference/cli/docker/buildx/build/#progress): the `auto`, `tty`, `plain`, `quiet`, and `rawjson` modes.
- [`docker buildx prune`](https://docs.docker.com/reference/cli/docker/buildx/prune/): the `until`, `id`, `description`, and `type` filters, with the `exec.cachemount` type.
- [Docker, "BuildKit"](https://docs.docker.com/build/buildkit/): incremental context transfer and skipping unused files.
- [`docker builder`](https://docs.docker.com/reference/cli/docker/builder/): the command group for managing builds.
- [Docker, "containerd image store"](https://docs.docker.com/engine/storage/containerd/): that the store keeps images compressed and uncompressed.
- [Docker, "Build checks"](https://docs.docker.com/build/checks/): `docker build --check`.
- [`go` command documentation](https://pkg.go.dev/cmd/go): the build cache ("Build and test caching") and the `-buildvcs` flag.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions in "About the runs".
- [Colima](https://github.com/abiosoft/colima): the tool used to run the programs on macOS.

### Terms in this lesson

| | |
|---|---|
| **build cache** | the results of previous steps that the builder keeps so it does not repeat them |
| **layer cache** | the part of the cache that decides whether an entire step is repeated or comes already done |
| **layer** | the set of file changes a Dockerfile step leaves behind |
| **`CACHED`** | in `--progress=plain`, the step came from the cache |
| **build context** | the files the build can use; BuildKit only transfers those that are requested and those that changed |
| **`DONE`** | in `--progress=plain`, the step was actually done, with its time |
| **invalidate** | when a step can no longer come from the cache because something it uses changed |
| **cache mount** | a directory the builder keeps separately and mounts in a `RUN`; its contents do not stay in the image |
| **`--progress=plain`** | the plain-text format of a build, step by step |
| **VCS** (*version control system*) | the version control system, such as Git |

---

**Next:** [Lesson 5 — Multi-stage: from gigabytes to megabytes](05-multi-stage.md)
