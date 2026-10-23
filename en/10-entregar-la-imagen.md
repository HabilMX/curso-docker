# Lesson 10 — Delivering the image

It is Friday, 5:20 in the afternoon. On Monday at 9:00 your team's Kubernetes course starts, and the instructor wants everyone to take **the same `revisor` image** to their cluster, the one you already tested. On Tuesday you sent your teammate Tomás the command `docker run curso-docker-revisor:1.6.0` and it worked for him. On Wednesday you found a small bug, rebuilt the image and pushed it again with the same tag, `1.6.0`, because "it's the same version, I only fixed a detail". Today, Friday, Tomás writes to you: "the report looks different on mine than on yours". You both have an image with exactly the same name. You check, and neither of you can say which of the two is the right one. And that is not all: the person who looks after the team's security asks three questions that you cannot answer with certainty. What is inside that image? What was it built with, and where did each component come from? Does it contain anything with a known flaw? It is 5:34. Tomás uses a different processor from yours, so you are not even sure that the image you built on your machine will *work* on his. The question is no longer how to build an image, but **how to deliver an image so that whoever receives it knows exactly which one it is, what it contains, where it comes from and on which machines it runs**. This lesson exists so that on Monday, instead of "I sent it to you, I think it's the right one", you can say: "here is its digest, here is its bill of materials, here is today's scan, and there is a binary for each processor, with proof that the `amd64` one starts".

**Time:** 2 × 45 min

**What you build:** the delivery of the `revisor` image, version 1.6.0, in five moves. A local registry that listens only on `127.0.0.1`. A `Dockerfile` that compiles the same binary for two processors (`linux/amd64` and `linux/arm64`) without emulation. A publication of that image with its **bill of materials** (SBOM) and its **provenance**, which you can read with a single command. A vulnerability scan with Trivy, done without giving Trivy the Docker *socket*. And the bridge to the next course: the image loaded into a `kind` cluster with `kind load docker-image`, and a pod that starts without trying to download anything.

**What you learn:** what a registry is and how an image reference is put together; the difference between a **tag**, which can be moved, and a ***digest***, which cannot; what an image index is and why a single tag can carry several processors; the three ways to build for several platforms and why cross-compilation is used here; what attestations are, and how to read an SBOM and a provenance (the `min` and `max` modes, and what `max` exposes); what you can and cannot expect from an "identical" rebuild; how to pull an image **by digest** and run it hardened; how to scan with Trivy, what a threshold is and why `UNKNOWN` also counts toward the exit code; how to accept a finding in writing or resolve it by renewing the base; and how to take the image to a `kind` cluster without a registry.

**Where you are coming from.** From [Lesson 9](09-compose.md) you bring the complete system in a `compose.yaml` and the state of [Lesson 8](08-volumenes-y-redes.md): an image of under twenty megabytes, with no shell, no `root`, which stores its report in `/datos`, a folder owned by user `65532`. From [Lesson 7](07-salud-y-ciclo-de-vida.md), the hardening it runs with (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`). From [Lesson 5](05-multi-stage.md), the habit of pinning the base by version and by *digest*: today you will see what that habit costs and how it is paid. From [Lesson 2](02-contenedores-dia-a-dia.md), publishing ports only on `127.0.0.1` and not handing the Docker *socket* to a container: that habit decides how you scan in this lesson. Your folder has `revisor/` with its `Dockerfile`, its `.dockerignore` and `secretos/`, and next to it `servicio-prueba/`.

**What this lesson does not do.** It does not publish anything to a public registry: neither Docker Hub nor any other. Everything happens in a registry that you start yourself, on your machine, reachable only from your machine, and that is deleted at the end. It does not set up a production registry: that needs TLS and access control, and the registry's own documentation demands it (section 10.1.1 quotes it). It does not sign images: a cryptographic signature answers the question "who published it?", and the lesson stays with the questions "which one is it?", "what does it contain?" and "how was it made?". It does not promise that a scanned image is a secure image: the scan checks what its databases know **today**, and section 10.10 explains what a "0" means and what it does not. It does not change the previous lesson's `compose.yaml`, which still builds 1.5.0: the 1.6.0 of this lesson is the image delivered to the next course, and the only difference from 1.5.0 is the `Dockerfile` that compiles for two processors. And it does not deploy anything to Kubernetes: the last move only takes the image to the cluster's entry point and checks that the pod starts; the rest is Hábil's [Kubernetes course with kind](https://www.habil.mx/en/courses/kubernetes/).

**About the runs.** All outputs are real and were obtained on October 21, 2026. Here is what you need to know about where they came from, so you can compare them with yours:

- **The machine.** A Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4 (the same base as Linux Mint 22, the course's reference system), kernel 6.8 and an `arm64` processor. The registry, build and scan scripts were run **inside** that virtual machine, with Docker 29.2.1 (client and daemon), Buildx v0.31.1 and BuildKit v0.27.1. The `kind` step (section 10.11) was run **on the Mac**, where `kind` v0.33.0 and `kubectl` v1.37.1 live, against the same daemon.
- **The course versions.** It was planned with Docker Engine 29.8.2 (measured on October 7), and on the day of the runs the latest published version was 29.9.2, from October 20 ([release notes](https://docs.docker.com/engine/release-notes/29/)). A fresh installation today therefore brings a newer Buildx and BuildKit than the ones in these runs: if an error text or a tool version differs, compare it by its meaning, and check yours with `docker version` and `docker buildx version`. The scanner is **Trivy 0.76.0**, published on October 14, 2026 ([release notes](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0)); the registry is the official image `registry:3.1.2`.
- **The image store.** This machine's Docker uses the *containerd* store (`docker info` says `Storage Driver: overlayfs` with `driver-type: io.containerd.snapshotter.v1`), and section 10.1.4 explains why that matters and how to check it on your machine.
- **Emulation.** On this machine, **compiling Go emulated for `amd64` did not work** (section 10.4 shows the failure and what it means), while **starting** the already compiled `amd64` binary did work (section 10.9.2). On your Mint with an `amd64` processor, the foreign platform would be `arm64` and may give you a different result.
- **The names.** So as not to touch yours, the scripts use helper names (the registry `curso-docker-registro-fig10`, the image `curso-docker-revisor:fig10`, the volume `curso-docker-trivy-cache-fig10`, the cluster `curso-docker-puente-fig10`), build with a tag of their own and on exit delete **by name**, never by identifier; the ones that publish a port check before starting that it is free and, if it is not (for example because you already have your registry), stop instead of pushing to a registry that is not theirs: `fig10_02.sh` checks 5000 and 8080; `fig10_04.sh`, `fig10_08.sh` and `fig10_09.sh` check only 5000, which is the only one they publish; `fig10_00.sh`, `fig10_05.sh`, `fig10_06.sh` and `fig10_07.sh` publish no fixed port and check none. This run also launched them with the prefix `curso-docker-l10-` and ports 18100 and 18101 because other lessons were working on the same machine; a `nombres` function, in plain view in each script, rewrites that prefix as `curso-docker-` and the ports as `5000` and `8080`. With the default values nothing changes. In your folder, the registry will be called `curso-docker-registro` and the image `curso-docker-revisor:1.6.0`.
- **What changes from one run to another**, and is flagged where it appears: the *digests* (they depend on the build time), the times (one second, sixty-five: they depend on what was in the cache), file sizes in tenths of a megabyte, the dates of Trivy's database, the versions of the tools that sign the SBOM (`syft` and BuildKit, in the `creators` field), the number of packages in the SBOM and the exact messages of the failed emulation.

The programs are in [`programas/10-entregar-la-imagen/`](../programas/10-entregar-la-imagen), each with its output next to it, and `estado/` keeps the project files as they end up when finished.

## By the end you will be able to

- Start a local registry only on `127.0.0.1`, publish an image to it and list what it contains with `curl` against its API.
- Explain, with a measurement of your own, why a tag does not identify an image and a *digest* does, and pull and run an image **by digest**.
- Convert Lesson 8's `Dockerfile` into one that compiles for `linux/amd64` and `linux/arm64` without emulation, and check which processor each binary ended up built for by reading its bytes.
- Publish a two-platform index with an SBOM and provenance in `max` mode, and read with `docker buildx imagetools inspect` the packages it contains, what it was built with, and which builder data ends up exposed.
- Scan the image with Trivy from a `docker save` file, without mounting the Docker *socket*, and read the result with its threshold and its exit code.
- Decide on a finding: accept it in writing in a `.trivyignore`, with a reason and a date, or resolve it by renewing the base's *digest*, and check the result.
- Load the image into a `kind` cluster with `kind load docker-image` and explain why the pod starts with `imagePullPolicy: Never`.

## The why before the how

Until now the image lived where you built it: in the image store of your own Docker. As long as that is so, "the image" is a matter between you and your machine. Delivering it means taking it out of there, and the moment it leaves, four problems appear that did not exist before.

The first is **the name that lies**. The scene at the beginning is not a rare slip: it is the direct consequence of `curso-docker-revisor:1.6.0` being a *tag*, a label stuck on an image, and of a label being something you can peel off and stick on another. Whoever receives the name receives no guarantee of anything. We need a way to refer to *that* image and not to "whichever one has this label right now". That way exists, it is called a *digest*, and you will measure it in section 10.3.

The second is **the processor**. An image contains an already compiled binary, and a binary compiled for `arm64` (the Mac in the scene, and many cloud servers) does not run on `amd64` (your teammate's Mint, and most servers). Lesson 8's image was built for the processor of whoever built it, and nothing else. Delivering it to another machine requires being able to say "here is one for each processor, under the same name". And building it twice carries its own risk: if one of the two builds runs emulated, it can be extremely slow or, as you will see, not work at all.

The third is **the black box**. An image is a file that someone hands you and that you are going to run with privileges on your machine and, later, on a shared cluster. Before running it you want to know what it contains (bill of materials), where each component came from and with which instructions it was put together (provenance), and whether any of its components has a known public flaw (scan). You do not need to distrust anyone to ask for those three things: asking for them is the normal way to work when something is going to run where it matters.

The fourth is **the cluster's entry point**. In the next course, the `revisor` has to reach a cluster. A cluster does not see your Docker's image store: it has its own. You have to decide how the image gets there, and in a local lab the answer is a single line (`kind load docker-image`), with a trap that you will trigger on purpose so that you can read it.

That the third problem is not a textbook exaggeration is shown by a public case. On April 1, 2021, a customer of Codecov, a test-coverage service, noticed that the *script* it downloaded from the company to upload its results did not have the same checksum (*shasum*) as the one published on GitHub. They raised the alarm, and the company discovered that someone had modified that *script* without authorization since January 31: the altered line sent the full environment of the continuous integration machines where it ran, with whatever credentials were there, to a third-party server. Among other things, the company recommended rotating the credentials of anyone who had used it without validating the checksum ([Codecov, "Bash Uploader Security Update"](https://about.codecov.io/security-update/)). It was not a container image, it was a *script*, but the mechanism that exposed it is exactly this lesson's: **compare the fingerprint of what you received with the fingerprint of what was published**. Anyone who compared the checksum with the one published on GitHub could detect the alteration; the customer who did so reported it on April 1, two months after the alterations began, and the affected users were notified on April 15. A *digest* works like that checksum, with a condition that the case makes visible: the fingerprint has to arrive through a different channel from the thing being downloaded. Codecov's checksum was on GitHub and the *script* was served from another site. With images the same applies: you give Tomás the *digest* through your own channel, and he does not take it from the same registry that serves him the image.

This lesson resolves all four with tools you already have. Almost everything is done by `docker buildx`, which came with Lesson 1's installation. A registry is just another program, and that is why it is started in a container. The only new program is Trivy, and it also runs in a container, with Lesson 2's habit: it is not given the Docker *socket*. With that destination in mind, this is what you will have at the end of section 10.9: the published image, pulled back **by its digest**, as a machine that did not build it would do (the script first deletes the local copies that the build left and checks that), running hardened:

```text
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"1.6.0"}
$ docker inspect --format '{{.Config.Image}}' curso-docker-revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'
localhost:5000/curso-docker-revisor@sha256:59e431fa44c7…
```

(This is the end of `fig10_02.sh`. The container was created with the reference `…@sha256:…`: no longer with a tag.) And this is the course goal that falls to this lesson, the sixth in the README: the published image is referenced by *digest*, passes Trivy's scan with the threshold you set, and is loaded into a `kind` cluster without a single download error.

## The concepts

### 10.1 What a registry is and how to read an image's name

#### 10.1.1 A registry is an image server

A **registry** is a service that stores images and hands them to whoever asks for them. You have used one without thinking about it: every time a `FROM golang:1.27.3-trixie` or a `docker pull` fetched something from the internet, a registry responded. The service speaks a standard HTTP protocol, and that is the reason this lesson can start one of its own in a container and talk to it with `curl`. The open-source project that implements it is called *Distribution*, and its official image is called `registry`. Its documentation presents a one-line command to start it (`docker run -d -p 5000:5000 --restart=always --name registry registry:3`) and a warning that deserves to be read in full: the first examples are "appropriate only for testing", and "a production-ready registry must be protected by TLS and should ideally use some access-control mechanism" ([Distribution, "Deploy a registry server"](https://distribution.github.io/distribution/about/deploying/)). That is why in this lesson the registry lives on `127.0.0.1` and is deleted at the end. If you ever publish toward other machines, you will need TLS, and that is an infrastructure topic this course does not cover.

#### 10.1.2 The parts of a reference

A **reference** to an image is the text you give Docker to point at one. It has up to four parts, and almost every "can't find my image" error is one part written wrong:

```text
localhost:5000 / curso-docker-revisor : 1.6.0
   registry         repository           tag

localhost:5000 / curso-docker-revisor @ sha256:59e431fa44c7…
   registry         repository          digest
```

- The **registry** is where it is: a machine name with an optional port. If you write none, Docker assumes Docker Hub. In this lesson it is always `localhost:5000`.
- The **repository** is the image's name inside the registry: `curso-docker-revisor`. A repository stores all the versions of an image.
- The **tag** is a readable name for a version: `1.6.0`. It is, as the Kubernetes documentation says, something that can change: "tags can be moved to point to other images, but *digests* are fixed" ([Kubernetes, "Images"](https://kubernetes.io/docs/concepts/containers/images/)).
- The ***digest*** is a fingerprint of the content, in the format `sha256:` followed by sixty-four hexadecimal characters. The same page defines it like this: "*digests* are hashes of the image's content, and they are immutable".

When a reference carries a tag **and** a *digest* at the same time, the Kubernetes page is explicit about which one rules: "only the *digest* will be used to pull". The tag stays as a comment for humans. That is why later, in a manifest or in a `compose.yaml` where it matters to know what is running, it pays to write `repository:1.6.0@sha256:…`: you read the version and the machine verifies the content.

#### 10.1.3 What a registry really stores

Before starting the registry it helps to know what you are going to send it, because it changes how the lesson's outputs are read. A registry does not store loose "images"; it stores **manifests** and **blobs**. A *blob* is an anonymous file identified by its *digest* (a compressed layer, or the image's configuration file). A **manifest** is a small document in JSON format that lists the blobs that make up an image. And above the manifests there can be an **index** (*image index*): according to the Open Container Initiative specification, it is "a higher-level manifest which points to specific image manifests", with a mandatory field `manifests` that is "a list of manifests for specific platforms", and each entry can carry a `platform` object with the architecture (`architecture`, using Go's `GOARCH` names) and the operating system (`os`, using those of `GOOS`) ([OCI, "Image Index"](https://github.com/opencontainers/image-spec/blob/main/image-index.md)). In everyday terms: a **tag** points to an **index**; the index says "for `amd64` look at this manifest, for `arm64` look at that one"; each manifest lists its layers. When you run `docker pull` on an `amd64` machine, Docker reads the index, picks the entry that matches its processor and downloads only that one. That structure is what you will see printed, for real, in section 10.5.

And there is a third kind of entry in the index, which is not an image but a *document about* an image: the **attestations**. They are explained in 10.6.

#### 10.1.4 Before starting: your Docker's image store

Almost everything that follows (publishing a two-platform index with attestations, saving one platform with `docker save --platform`, seeing the tree with `docker image ls --tree`) depends on one detail of your installation: which **image store** your Docker uses. Docker 29 has two: the classic one, with drivers such as `overlay2`, and the *containerd* one. The documentation says that the *containerd* one is the default storage of Docker Engine 29.0 and later **on new installations**, and that if you come from an earlier version your daemon "keeps using the legacy drivers (`overlay2`) until you enable" the *containerd* one; among its advantages it lists storing multi-platform images locally and working with images that carry attestations ([Docker, "containerd image store"](https://docs.docker.com/engine/storage/containerd/)). Check it like this:

```bash
docker info -f '{{ .DriverStatus }}'
```

On the runs' machine it answered `[[driver-type io.containerd.snapshotter.v1]]` (it is block 1 of `fig10_00.sh`, with its output next to it), which is what the documentation says appears when the *containerd* store is active. If that line does not appear on your machine (you will see something with `overlay2`), the same page says to enable it by adding `{"features": {"containerd-snapshotter": true}}` to `/etc/docker/daemon.json` and restarting the daemon with `sudo systemctl restart docker`. An honest warning: this lesson **did not test** its commands with the classic store, so if you stay with it, the steps in sections 10.5 and 10.9 may fail or give a different output; enable the *containerd* one before going on.

### 10.2 A local registry, only on `127.0.0.1`

#### 10.2.1 Starting it

It is a container like any other, with Lesson 2's habit: the port is published **only on `127.0.0.1`**, so that nobody else on your network can push to it or ask it anything. The first part of `fig10_02.sh` does exactly that, waits for it to respond and asks it which repositories it has:

```text
$ ./fig10_02.sh
== 1. Un registro local, publicado solo en 127.0.0.1
$ docker run -d --name curso-docker-registro-fig10 -p 127.0.0.1:5000:5000 registry:3.1.2 >/dev/null && echo registro arriba
registro arriba
$ curl -s http://127.0.0.1:5000/v2/_catalog
{"repositories":[]}
$ docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'
{"/var/lib/registry":{}}
```

Read it line by line. `-p 127.0.0.1:5000:5000` says "my machine's port 5000, only through the address `127.0.0.1`, leads to the container's port 5000". The image is pinned to `registry:3.1.2`, a specific version and not `registry:3` or `latest`, for the same reason as every image in this course: six months from now the floating tag would bring something else. The `>/dev/null` hides the long identifier that `docker run -d` prints, and the `echo` confirms that the command finished well. Then `/v2/_catalog` is an endpoint of the standard registry API that lists the repositories, and plain `/v2/` is the way to ask "are you alive and do you speak the protocol?" (the scripts use it to wait for startup). The answer `{"repositories":[]}` is that of a newborn registry: the JSON is valid, the array is empty. It has nothing because you have not pushed anything to it yet.

A cleanup detail worth knowing: the `registry` image declares a volume at `/var/lib/registry` (you can check with `docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'`, which answers `{"/var/lib/registry":{}}`). Since in Lesson 8 we do not name it, Docker creates an **anonymous** one, and a plain `docker rm` leaves it orphaned on the disk. That is why the scripts delete the registry with `docker rm -f -v`: the `-v` takes the anonymous volume away along with the container. It is the same kind of leftovers that Lesson 2 taught you not to leave behind.

#### 10.2.2 Publishing without TLS, and why it is allowed here

You will have noticed that pushing to `localhost:5000` asks for neither certificates nor a password. What **was measured** is exactly that: the `docker push` in the next section works against `localhost:5000` without configuring anything. Why is that allowed? Because the daemon's documentation says that local registries, "whose IP address falls in the `127.0.0.0/8` range, are automatically marked as insecure" (that is, they are allowed over HTTP without TLS), and adds that "relying on this is not recommended, because it may change in the future" ([Docker, `dockerd` reference](https://docs.docker.com/reference/cli/dockerd/)). It is a lab exception, and not an invitation to copy the habit: the registry's documentation says that skipping TLS is only for "testing", and that for the registry to be reachable from other machines it has to be protected with TLS first. A registry listening on `0.0.0.0` without TLS or authentication is an open door for anyone on your network to change what your servers download. In this course it stays on `127.0.0.1`.

### 10.3 Tag versus *digest*: the scene's measurement

#### 10.3.1 Triggering Friday's problem

The scene at the beginning can be reproduced in two minutes, and it is worth doing with your own hands because it is one of those ideas that are believed much more once measured. The script `fig10_02.sh` builds the image twice with the **same tag** and different versions, pushes it both times, and at the end asks the registry what each reference carries. For this to work you need this lesson's `Dockerfile`, which is explained in 10.4; for now it is enough to know that it builds the same image as Lesson 8 and that it accepts `--build-arg VERSION=…`, as always. The lines that matter:

```text
== 2. Construir la 1.6.0 y publicarla con la etiqueta fig10
$ docker build -q --build-arg VERSION=1.6.0 -t localhost:5000/curso-docker-revisor:fig10 . >/dev/null && docker push -q localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c"
$ curl -s http://127.0.0.1:5000/v2/_catalog; curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"repositories":["curso-docker-revisor"]}
{"name":"curso-docker-revisor","tags":["fig10"]}

== 3. Otra construcción (VERSION=1.6.1) con la MISMA etiqueta
$ docker build -q --build-arg VERSION=1.6.1 -t localhost:5000/curso-docker-revisor:fig10 . >/dev/null && docker push -q localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:f60d25f0809179fefc1966ea14609f73dd6caf3db196e40db52d7b55dc7f42a1"
$ curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"name":"curso-docker-revisor","tags":["fig10"]}
```

Let us go step by step. In block 2, `docker build -q` builds silently (the `-q` avoids the dozens of lines of the process) and returns the image identifier, which the script discards with `>/dev/null`; if the `build` succeeds, the `docker push -q` comes in, which pushes the image to the registry and, with `-q`, prints only the pushed reference. Notice the `-t localhost:5000/curso-docker-revisor:fig10`: to push to *your* registry, the image name has to **start** with the registry's address. That is the rule that explains nearly all of the beginners' "push access denied" and "repository does not exist" errors: without the prefix, Docker assumes you want to push to Docker Hub. Then `imagetools inspect` with `--format '{{json .Manifest.Digest}}'` asks the **registry** (not your local Docker) what the *digest* of whatever sits behind that tag is: `sha256:59e431fa…`. And the repository's tag list, `tags/list`, reports a single one: `fig10`.

In block 3 it is repeated with `VERSION=1.6.1`. Look at the output: **the tag list is still a single one, `fig10`**, but the *digest* is no longer `59e431fa…` but `f60d25f0…`. The tag moved from one image to another, without notice, without an error, without any message to alert anyone. The registry did exactly what it was asked. What was lost is the guarantee you thought you had when you said "1.6.0".

#### 10.3.2 Asking for each reference

Now the acid test: what does whoever asks by tag get, and what does whoever asks by *digest* get? Block 4 looks at what local copy the build left (with `docker image ls`), deletes it, looks again (so that the only thing left is what the registry says) and pulls both:

```text
== 4. Lo que trae cada referencia
(la copia local que dejó la construcción)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
localhost:5000/curso-docker-revisor:fig10
(y después de borrarla)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
(ninguna)
$ docker pull -q localhost:5000/curso-docker-revisor:fig10 && docker run --rm localhost:5000/curso-docker-revisor:fig10 version
localhost:5000/curso-docker-revisor:fig10
1.6.1
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c && docker run --rm localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c version
localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c
1.6.0
```

The image has had the `version` subcommand since Lesson 3: it prints the version that was baked in at compile time. Whoever asked for `:fig10` received **1.6.1**, the last thing pushed. Whoever asked for the first build's *digest* received **1.6.0**, which is what *that* reference delivers, as long as it exists in the registry. Both are healthy, neither is "wrong": they are two different images and the tag is a label that was passed from one to the other. With this, Friday's scene has an explanation and a fix: if you and Tomás had used the reference with a *digest*, or if you had published each correction under a new tag (`1.6.1`), there would have been nothing to argue about.

Three nuances so as not to draw too many conclusions. **One:** the *digest* is not "more secure" by itself. What it gives is *reference immutability*: what you ask for by *digest* you either receive identical or do not receive at all. It says nothing about whether the image has flaws; that is what the scan checks. **Two:** whoever publishes can delete a *digest* from the registry; the `pull` then fails instead of bringing something else, which is exactly the desired behavior. **Three:** an index's *digest* is different from that of each platform manifest it contains (in this exercise, `imagetools inspect` showed that of a single-platform image; the two levels are seen in 10.5). So far you have worked with just one platform; in 10.5 you will see both levels.

The practical rule that comes out of this fits in one line: **the tag is for people to talk with; the *digest* is for machines to verify**. Publish a new tag for each build you are going to deliver and do not reuse an already published version. And when a machine has to run exactly what you tested, give it the *digest*. Docker's best-practices documentation says the same about bases: pinning the image by *digest* gives the guarantee that "you will always use the same version of the image, even if the publisher replaces the tag with a new image" ([Docker, "Building best practices", pinned-bases section](https://docs.docker.com/build/building/best-practices/)). It is what Lesson 5 did with the `revisor`'s base, and today you apply it to the `revisor` image itself.

### 10.4 A single `Dockerfile` for two processors

#### 10.4.1 The problem: a binary belongs to one processor

The `revisor` is written in Go and compiles to a static binary. You already know what "static" means (Lesson 5): it carries everything it needs and asks for no system libraries. But it is still machine code for **one** processor. Two families dominate today: `amd64` (also called x86-64, the one in most servers and in machines running Linux Mint) and `arm64` (also called AArch64, the one in Macs with Apple's own chip and in many cloud servers). Docker names them `linux/amd64` and `linux/arm64`: operating system, slash, architecture. The architecture name is the same one Go uses, and that is why the following `Dockerfile` can pass a Docker name straight to the compiler.

To build an image that works on both, Docker's documentation lists three strategies ([Docker, "Multi-platform builds"](https://docs.docker.com/build/building/multi-platform/)): **emulation** with QEMU; a builder with **several native nodes** (a machine of each architecture); and **cross-compilation** with stages. About the first, the same page warns that emulation "can be much slower than native builds", especially for compute-intensive tasks such as compiling, and recommends native nodes or cross-compilation "if possible". With a compiler like Go's, the third is possible and is the best. Now you are going to measure why.

#### 10.4.2 Trying emulation (and having it not work)

The script `fig10_03.sh` takes Lesson 8's `Dockerfile`, **untouched**, and asks Docker for an image for `linux/amd64` from an `arm64` machine. Docker accepts: in `docker buildx inspect`, `linux/amd64` appears among the platforms it knows how to run, because it ships QEMU to pretend to be that processor. This is what happened on this machine:

```text
$ ./fig10_03.sh
== 1. Este equipo y lo que su constructor sabe correr
$ uname -m
aarch64
$ docker buildx inspect | grep -E '^Platforms:'
Platforms:        linux/arm64, linux/amd64, linux/amd64/v2, linux/386

== 2. El Dockerfile de la Lección 8, para linux/amd64: todo corre emulado (QEMU)
$ docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada.log 2>&1; echo "construcción: código $?"
construcción: código 1
(tardó 0 s)
$ { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110
fatal error: fault
$ grep -E '^ERROR' emulada.log
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 2
(el mismo intento, dos veces más, para ver si el fallo es siempre el mismo)
$ for n in 2 3; do docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada-$n.log 2>&1; echo "intento $n: código $?"; { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada-$n.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110; done
intento 2: código 1
fatal error: found pointer to free object
intento 3: código 1
fatal error: fault
```

Read it calmly, because it holds two lessons. `uname -m` says `aarch64`, the long name for `arm64`: it is an `arm64` machine, and the platform list confirms that its builder knows how to run four, three of them foreign to its processor (`amd64`, `amd64/v2` and `386`), thanks to emulation. The build command carries `--no-cache` (so that nothing is reused from a previous run) and `-o type=local,dest=salida-emulada`, which instead of creating an image **leaves the final files in a folder**: here it is used to check the result without filling the image store. `--platform linux/amd64` is requested.

The result: the build **fails**, with code 1, almost instantly (the script marked 0 s). The message is a `fatal error` from the Go program itself, and the last line says where it fired: in the `go test ./...` step, the one from Lesson 5's test stage, which on failing with `exit code: 2` stops everything. To find out whether the failure is constant or a coincidence, the script repeats the attempt two more times. **Different messages** came out in the three attempts of this run (`fault`, `found pointer to free object` and `fault` again), and in earlier runs of the same script I saw two others, `found bad pointer in Go heap` and `wirep: already in go`, which were not saved in the files. They are all messages that Go's garbage collector or scheduler prints when something it expected from the machine does not happen: they are not an error in your `Dockerfile` or in the `revisor`'s code. What points to emulation is that the same `Dockerfile`, with the same code, compiles fine on the native processor and with cross-compilation (10.4.3). **What was measured is the failure, not its cause**, and it is no guarantee that it will fail for you: on your `amd64` Mint emulating `arm64` the behavior may be different, and with other QEMU versions, too. What you can take as a rule is what the documentation says: emulation is the last option, not the first, and a different failure on each attempt is the signature of an emulation that cannot reproduce the processor properly. Stated as a measured condition and without promises: **on a Mac with an Apple chip, with Colima, emulated Go compilation for `amd64` failed in all three attempts of the saved run, and in earlier runs of this same script**; if something similar happens to you, do not insist or try to fix the emulation: compile on the native processor and let Go generate the binary for the other platform (cross-compilation), which is what comes next and what was measured successfully (code 0, 65 seconds, one binary per platform). Docker's documentation also mentions another way out, a builder with native nodes of each architecture, which this lesson did not test.

#### 10.4.3 Cross-compilation: three changes

The idea is simple. The compilation (which is the heavy work) runs **on the native processor of whoever builds**, and only the *result* is labeled for another processor. For that the `Dockerfile` changes in three places. Before replacing it, save Lesson 8's with `cp Dockerfile Dockerfile.leccion8`. This is the complete file, `fig10_01.Dockerfile`, which in your folder is called `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
# fig10_01.Dockerfile — Lección 10: la imagen que se entrega: la de la Lección 8,
# construida para varias plataformas SIN emulación. Go compila para otra
# arquitectura por sí mismo, así que las etapas de compilación corren en la
# plataforma de quien construye ($BUILDPLATFORM) y solo cambia el destino del binario.

FROM --platform=$BUILDPLATFORM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
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
# Las pone BuildKit solo: la plataforma para la que se está construyendo.
ARG TARGETOS TARGETARCH
# Un secreto de CONSTRUCCIÓN (por ejemplo, credenciales para módulos privados)
# se monta solo durante este RUN y no queda en ninguna capa. Este curso no usa
# módulos privados: el montaje es opcional (required=false) y queda como patrón.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    --mount=type=secret,id=netrc,target=/root/.netrc,required=false \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" \
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

It is Lesson 8's `Dockerfile` with **three different lines of code** (plus a new comment that explains them and the header comments); if you compare the two files with `diff`, the code changes only here:

1. `FROM --platform=$BUILDPLATFORM golang:…`. `BUILDPLATFORM` is a variable that BuildKit defines by itself: the platform of the machine doing the building (here, `linux/arm64`). With this option the compilation stage **runs natively**, regardless of which platform the final image is for. The documentation names it together with `TARGETPLATFORM`, `TARGETOS` and `TARGETARCH` as predefined build arguments ([Docker, "Multi-platform builds"](https://docs.docker.com/build/building/multi-platform/)).
2. `ARG TARGETOS TARGETARCH`. It declares, inside the `binario` stage, that you want to use the **target** operating system and architecture. BuildKit sets them by itself (`linux` and `amd64`, or `linux` and `arm64`, depending on the platform being assembled); declaring them with `ARG` is what makes them visible in the `RUN`.
3. `GOOS=$TARGETOS GOARCH=$TARGETARCH` in front of `go build`. They are the variables with which the Go compiler decides which system and processor to generate the binary for, and Docker's architecture names (`amd64`, `arm64`) match Go's, just like those in the index specification of section 10.1.3. With `CGO_ENABLED=0` (which was already there) the binary is static and does not need a C compiler for the other processor.

And one thing that does **not** change, on purpose: the `final` stage (`FROM gcr.io/distroless/…`) carries no `--platform`. That stage does have to be of the target platform, because it is the image that will be delivered; BuildKit picks the correct variant of the distroless base for each platform by itself, and that base is published for both. The two compilation stages (`compilacion` and `pruebas`) run natively **only once**, on the builder's processor. That has a limit worth stating: Go's tests validate the **code** on that processor; they do not execute the other platform's binary. For a pure Go service it is reasonable, but the `amd64` binary is only truly verified by running it on an `amd64`. In 10.9.2 you run it.

#### 10.4.4 Measuring cross-compilation

Block 3 of `fig10_03.sh` builds with that `Dockerfile` for **both platforms** at once:

```text
== 3. fig10_01.Dockerfile, para las DOS plataformas: compila cruzado
$ docker buildx build --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-cruzada cruzada > cruzada.log 2>&1; echo "construcción: código $?"
construcción: código 0
(tardó 65 s)
$ grep -oE '\[linux/[a-z0-9>-]+ (pruebas|binario) [0-9]/[0-9]\]' cruzada.log | sort -u
[linux/arm64 binario 1/1]
[linux/arm64 pruebas 1/1]
[linux/arm64->amd64 binario 1/1]
$ ls salida-cruzada
linux_amd64
linux_arm64
$ maquina salida-cruzada/linux_amd64/revisor; maquina salida-cruzada/linux_arm64/revisor
salida-cruzada/linux_amd64/revisor: 3e 00 = x86-64 (amd64)
salida-cruzada/linux_arm64/revisor: b7 00 = AArch64 (arm64)
```

The exit code is 0: **it worked**, and with `--no-cache`, no tricks. It took 65 seconds because it compiled from scratch (with the Go cache from earlier lessons, it would be much less; section 10.5 does it in seconds). The most interesting part is in the `grep`. The lines that BuildKit prints when executing each step carry between brackets **the platform on which the step runs**, and what you see is: `[linux/arm64 pruebas 1/1]`, the tests ran on `arm64`, the native one. `[linux/arm64 binario 1/1]`, the `arm64` binary was compiled on `arm64`. And `[linux/arm64->amd64 binario 1/1]`: the **`amd64`** binary was compiled *on* `arm64` (the arrow says "from here to there"). No step of the build was executed on `amd64`, not even emulated. It is the proof that the error of the previous section did not have to be solved by fixing QEMU, but by avoiding it.

The last part of the output is the check that matters: is each file really for the processor it claims? `ls` shows one folder per platform. And the script's `maquina` function **reads the bytes**: the header of a Linux executable (ELF format) stores in bytes 18 and 19 the `e_machine` field, which identifies the target processor, and `od -An -tx1 -j18 -N2` prints them in hexadecimal. `3e 00` is the x86-64 marker and `b7 00` the AArch64 one. That is, you do not trust the folder's name: you looked inside the file. (If you want the full table of codes, it is in the ELF format specification; the two you use here can be checked on any machine with your Mint's `file` command, which also writes them out by name.)

**When this technique is not enough.** Cross-compilation works because Go knows how to generate code for another architecture without anyone's help. If your service depended on a C library (with `CGO_ENABLED=1`), or if the build step had to *execute* programs of the target processor (installing packages with `apt` inside an `amd64` base, for example), cross-compilation would not be enough and you would go back to emulation or native nodes. That is not the case of the `revisor`, and it is one of the reasons the course chose a service written in Go.

### 10.5 Building for two platforms and publishing the index

#### 10.5.1 The complete command

You already have the `Dockerfile` and a registry. What is missing is the command that builds for the two platforms, attaches the bill of materials and the provenance, and pushes everything. It is long; read it in pieces:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg VERSION=1.6.0 \
  --sbom=true \
  --provenance=mode=max \
  -t localhost:5000/curso-docker-revisor:1.6.0 \
  --push .
```

- `docker buildx build` is Docker's modern builder (BuildKit). Today `docker build` is an alias of `docker buildx build` ([Docker, "docker build"](https://docs.docker.com/reference/cli/docker/build-legacy/)), so the two do the same; to publish several platforms what you need is BuildKit and a destination that stores indexes (a registry with `--push`, or the *containerd* store).
- `--platform linux/amd64,linux/arm64` requests **one image per platform**, separated by a comma.
- `--build-arg VERSION=1.6.0` is the same argument as in earlier lessons; it is baked into the binary and into the label `org.opencontainers.image.version`.
- `--sbom=true` adds the **bill of materials** (section 10.6) and `--provenance=mode=max` the **provenance** in its most detailed mode (section 10.7).
- `-t …:1.6.0` is the reference, which starts with your registry's address, as in 10.3.
- `--push` is the difference you have to understand. When you build for **one** platform, the image lands in your local store. A **multi-platform** image is an index, and Docker's classic store does not know how to store indexes, so historically `buildx` required sending them straight to a registry. With the *containerd* store (this machine's, see "About the runs") multi-platform images with attestations can now be stored locally ([Docker, "containerd image store"](https://docs.docker.com/engine/storage/containerd/)), but the delivery command does what you want anyway: build and publish in a single step. A measured warning: with that store, `--push` **also leaves the image on your machine** (section 10.9.1 shows it with `docker image ls`), so that local copy exists and should not be confused with the published one.

Docker's documentation describes attestations like this: the ones you attach with `--sbom` and `--provenance` end up "as a manifest in the image index", and their data is stored "as JSON blobs" ([Docker, "Build attestations"](https://docs.docker.com/build/metadata/attestations/)). You will see it with your own eyes in a few lines.

Block 2 of the script `fig10_04.sh` runs it and extracts from the build log the lines where BuildKit says what it wrote:

```text
$ ./fig10_04.sh
== 1. Registro local
$ docker run -d --name curso-docker-registro-fig10 -p 127.0.0.1:5000:5000 registry:3.1.2 >/dev/null && echo registro arriba
registro arriba

== 2. Construir para dos plataformas, con SBOM y procedencia max, y publicar
$ docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . > ../construccion.log 2>&1; echo "construcción: código $?"
construcción: código 0
(tardó 1 s)
$ grep -E 'exporting (manifest|attestation manifest|manifest list) sha256' ../construccion.log | sed -E 's/^#[0-9]+ //; s/ done$//; s/ [0-9.]+s$//' | sort -u
exporting attestation manifest sha256:d062f35ed5df81b21edeea621c65531f19c4d4075a27418745ba9b08c2080311
exporting attestation manifest sha256:d6939a710e122a030ac13e0b68b8aabc87da4d2f5a2eb4214a692e239613f6f0
exporting manifest list sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
exporting manifest sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
exporting manifest sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
```

(Here the tag is `fig10` instead of `1.6.0`, because of the helper names.) The code is 0 and it took **one second**: it no longer compiled from scratch because the Go cache and the layers from the earlier build were reused; section 10.4 measured the 65 seconds of the cold build. The `grep` looks for the lines where BuildKit reports what it *exported*, and five come out, read like this: two **manifests** (one per platform, `b99bf1ad…` and `959af91e…`), two **attestation manifests** (one per platform as well) and a **manifest list**, which is the old name for the index and which has the *digest* `a4246c5f…`. The line you need to remember is that last one, the index: **it is the *digest* that represents the whole "1.6.0"**, all platforms and all attestations.

#### 10.5.2 Reading the index

Now block 3 asks the registry how the tag ended up. It is the most important result of the section:

```text
== 3. El índice que quedó en el registro
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10
Name:      localhost:5000/curso-docker-revisor:fig10
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
           
Manifests: 
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/amd64
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/arm64
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:d6939a710e122a030ac13e0b68b8aabc87da4d2f5a2eb4214a692e239613f6f0
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.digest: sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
    vnd.docker.reference.type:   attestation-manifest
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:d062f35ed5df81b21edeea621c65531f19c4d4075a27418745ba9b08c2080311
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.type:   attestation-manifest
    vnd.docker.reference.digest: sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
```

Line by line. `docker buildx imagetools inspect` is the tool to see, **in the registry**, what is behind a reference; its documentation describes it as showing "the details of an image in the registry" ([Docker, `buildx imagetools inspect`](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/)). It is a remote read: it does not need the image to be on your machine.

- `MediaType: application/vnd.oci.image.index.v1+json` says that what is behind the tag is an **index** in OCI format (the one from 10.1.3), not a loose image.
- `Digest: sha256:a4246c5f…` is the index's *digest*: the same number as the `exporting manifest list` line of the previous section. What you write after `@` to identify "the 1.6.0" is this.
- Then, `Manifests` lists **four entries**, not two. The first two are the images: `Platform: linux/amd64` with its *digest* `b99bf1ad…` and `Platform: linux/arm64` with `959af91e…`. Each is an image manifest (`…image.manifest.v1+json`) with its layers. Those are the *digests* Docker looks at when, on an `amd64` machine, it resolves the tag: it picks the entry whose platform matches the machine's (on an `amd64`, it turns out to be the first).
- The other two have `Platform: unknown/unknown`. They are not images anyone can run: they are the **attestations**. The annotation `vnd.docker.reference.type: attestation-manifest` says so, and `vnd.docker.reference.digest` points to **which image they describe**. Notice that `d6939a71…` points to `b99bf1ad…` (the `amd64` one) and `d062f35e…` points to `959af91e…` (the `arm64` one): each platform has its own document. That annotation is the thread that ties a document to its image, and it is what allows `imagetools inspect --format '{{index .SBOM "linux/amd64"}}'` to find the right SBOM.

A consequence worth noting now in order to understand it in 10.9: the attestations **travel inside the index**, they are not a separate file. Whoever pulls the image by the index's *digest* gets, or can ask for, its attestations; whoever works with a loose platform manifest does not see them.

### 10.6 The bill of materials (SBOM)

#### 10.6.1 What it is and what it is for

A **software bill of materials** (SBOM) is, according to Docker's documentation, the "list of software artifacts that an image contains, or that were used to build it" ([Docker, "Build attestations"](https://docs.docker.com/build/metadata/attestations/)). It is the equivalent of the ingredient list on packaging. Its value shows up the day a public flaw comes out in a library: without a list, the question "does what I have running use that library?" forces you to open every image; with a list, it is a search. And it is the same list that scanners use to decide what to check.

The format that `--sbom=true` writes in this Docker is **SPDX**, "an open standard for communicating software bill of materials information" ([SPDX, "Overview"](https://spdx.dev/about/overview/)). The last two lines of the output below check it: the format version and which tools wrote the document.

#### 10.6.2 Reading it

Block 4 of `fig10_04.sh` asks the registry for the `linux/amd64` SBOM and walks through it with a Go template (`--format '{{…}}'`):

```text
== 4. La lista de materiales (SBOM) de linux/amd64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{range (index .SBOM "linux/amd64").SPDX.packages}}{{.name}} {{.versionInfo}}{{println}}{{end}}' | sort
base-files 13.8+deb13u7
ca-certificates 20250419
github.com/habil/revisor UNKNOWN
media-types 13.0.0
netbase 6.5
sbom <no value>
stdlib go1.27.3
tzdata 2026c-0+deb13u1
tzdata-legacy 2026c-0+deb13u1
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{(index .SBOM "linux/amd64").SPDX.spdxVersion}} {{(index .SBOM "linux/amd64").SPDX.creationInfo.creators}}'; echo
SPDX-2.3 [Organization: Anchore, Inc Tool: syft-v1.51.0 Tool: buildkit-v0.27.1]
```

The template: `.SBOM` is the map of SBOMs by platform; `index .SBOM "linux/amd64"` takes that platform's (the command's documentation explains that `index` is used precisely to choose a platform in multi-platform images); `.SPDX.packages` is the list of packages in the SPDX document; and `{{.name}} {{.versionInfo}}` prints each one's name and version, one package per line. The `| sort` orders them. There are **nine** lines, and each tells a story about the image:

- `base-files`, `media-types`, `netbase`, `tzdata`, `tzdata-legacy` and `ca-certificates` are the Debian packages that the distroless base brings. Some versions carry the suffix `+deb13u7`, which is that package's revision in Debian 13. `tzdata` is the time-zone database (`2026c`); `ca-certificates` is the list of trusted authorities that lets a program verify HTTPS certificates (the `revisor` needs it to query services over `https`). With no shell or package manager, the little there is in the image is this. Notice the version of `ca-certificates`: `20250419`. You will come back to it in 10.10.
- `stdlib go1.27.3` is the Go standard library with which the binary was compiled. It is not a Debian package but what the language leaves inside every program it generates: that is why the compiler's version (that of the `golang:1.27.3-trixie` stage) appears in the list, and why a scanner can say "this image carries Go 1.27.3" without running it.
- `github.com/habil/revisor UNKNOWN` is the program itself: its Go module, with version `UNKNOWN` (the scanner found no version to read; the lesson did not investigate why).
- `sbom <no value>` is an odd line, and it is worth saying out loud: it does not look like a package of the image: it is an element without a version that the generator adds to the document (the lesson did not investigate its origin), and the template prints `<no value>` when the field is missing. We leave it in the output on purpose so that it does not scare you when you see it.

And the last command answers the question "who wrote this?": format `SPDX-2.3`, made by **Syft** (from Anchore, version 1.51.0) through BuildKit v0.27.1. Your `Dockerfile` did not write it and nobody typed it: BuildKit launches a content scanner *inside* the build (in the next section's provenance you will see it as one more "material", `buildkit-syft-scanner`), reads the finished image and notes what it recognizes. That has a limit worth knowing: **an SBOM generated this way describes what the scanner recognizes**, and it recognizes system packages and modules of known languages. A file you copied into the image by hand without any package manager registering it does not appear. The list is a good inventory, not proof that there is nothing else.

### 10.7 Provenance: what it was built with

#### 10.7.1 What it is

The SBOM says **what** is inside. The **provenance** says **how it was made**. The SLSA standard defines it as "verifiable information about software artifacts describing where, when and how something was produced" ([SLSA, "Provenance"](https://slsa.dev/spec/v1.0/provenance)). For a Docker image, that includes: which builder put it together, for which platform, which base images it used (with their *digest*), which arguments it received, and at what time it started and finished.

#### 10.7.2 Reading it

Block 5 asks for three things from the `linux/amd64` provenance:

```text
== 5. La procedencia de linux/amd64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format 'tipo: {{(index .Provenance "linux/amd64").SLSA.buildType}}{{println}}construida EN: {{(index .Provenance "linux/amd64").SLSA.invocation.environment.platform}}'; echo
tipo: https://mobyproject.org/buildkit@v1
construida EN: linux/arm64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{range (index .Provenance "linux/amd64").SLSA.materials}}{{.uri}}{{println}}{{end}}' | cut -c1-100
pkg:docker/docker/buildkit-syft-scanner@stable-1?platform=linux%2Farm64
pkg:docker/docker/dockerfile@1
pkg:docker/golang@1.27.3-trixie?digest=sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965
pkg:docker/gcr.io/distroless/static-debian13@nonroot?digest=sha256:516757106de35205efb70b91ba03f6f12
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json (index .Provenance "linux/amd64").SLSA.invocation.parameters.args}}'; echo
{
  "build-arg:VERSION": "1.6.0",
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
```

- `tipo: https://mobyproject.org/buildkit@v1` is the build type: "this was put together by BuildKit, in the provenance format that BuildKit defines". It is just an identifier.
- `construida EN: linux/arm64` is **a second testimony of the cross-compilation**: BuildKit wrote it, not you. It is a declaration by the builder, unsigned: it confirms what you already measured, but does not replace an independent check. You asked for the provenance of the `linux/amd64` image and the document says it was built *on* `linux/arm64`. It is exactly what section 10.4 measured: the `amd64` image was built on an `arm64` machine, without emulating.
- The **materials** are everything that went into the build, with its package identifier (`pkg:docker/…`, in *purl* format, a standard for naming packages) and, when there is one, its *digest*. Four appear: the SBOM scanner (`buildkit-syft-scanner`), the Dockerfile frontend (`dockerfile@1`, which is what the first line `# syntax=docker/dockerfile:1` asked for), the build image (`golang@1.27.3-trixie`, with the *digest* `604106…` that Lesson 5 pinned) and the final base (`gcr.io/distroless/static-debian13@nonroot`, with `516757…`). The `cut -c1-100` in the command trims the lines so they fit; the full *digest* is in the document. Those two *digests* are the ones in your `Dockerfile`: the provenance is a second reading, written by BuildKit, that what was used was what was pinned (unsigned: anyone with permission to push to the registry could attach another).
- The arguments (`args`) are what the builder received: `build-arg:VERSION: 1.6.0`, the frontend command and its source.

A precision about the field names you just read (`invocation`, `materials`, `metadata`): by default Docker writes the provenance in version 0.2 of the SLSA schema, and 1.0 is enabled with `version=v1` (for example, `--provenance=mode=max,version=v1`) ([Docker, "SLSA provenance"](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). With `version=v1` the fields change place and this section's templates would not work as they are; this lesson did not measure it.

#### 10.7.3 `min` versus `max`: the warning

We set `--provenance=mode=max`. There are two modes, and the difference is not a matter of taste. The documentation says that `min` is the one added **by default** to images, which includes "timestamps, the frontend, the materials, the source repository and revision, the build platform and reproducibility", and that "the values of build arguments, the identities of secrets and rich layer metadata are **not** included in `mode=min`", so "it is safe for all builds". The `max` mode "includes everything from `min`" and adds the build's internal definition (LLB), **a copy of the Dockerfile encoded in base64** and source maps that link steps to layers. And it carries a warning that has to be read in full: `max` **exposes the values of build arguments**; if you are passing credentials as `--build-arg`, you have to rewrite the build to use secret mounts, because "secret mounts do not leak outside the build and are never included in provenance attestations" ([Docker, "SLSA provenance"](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)).

It is the kind of warning that is believed more when you see it. Block 6 builds the `arm64` image twice, once in each mode, **deliberately passing it an argument that the `Dockerfile` does not even declare**: `NOTA=curso-docker-nota-de-mentira`. The name says it is fake: it is a made-up text for the exercise, and it stands for whatever value someone passes by mistake in a `--build-arg`. The two builds are identical except for the provenance mode (the script repeats them in a loop with `mode=min` and `mode=max`):

```bash
docker buildx build -q --platform linux/arm64 \
  --build-arg VERSION=1.6.0 --build-arg NOTA=curso-docker-nota-de-mentira \
  --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10-max --push .
```

Then it asks the registry what each one stored:

```text
== 6. Modo min contra modo max, con un argumento que el Dockerfile ni declara
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-min --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo
{
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-min --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("campos:", sorted(d)); print("secretos:", d["invocation"]["parameters"].get("secrets", "(no aparecen)"))'
campos: ['buildType', 'builder', 'invocation', 'materials', 'metadata']
secretos: (no aparecen)
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo
{
  "build-arg:NOTA": "curso-docker-nota-de-mentira",
  "build-arg:VERSION": "1.6.0",
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("campos:", sorted(d)); print("secretos:", d["invocation"]["parameters"].get("secrets", "(no aparecen)"))'
campos: ['buildConfig', 'buildType', 'builder', 'invocation', 'materials', 'metadata']
secretos: [{'id': 'netrc', 'optional': True}]
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys,base64; d=json.load(sys.stdin); i=d["metadata"]["https://mobyproject.org/buildkit@v1#metadata"]["source"]["infos"][0]; print(i["filename"]); print("\n".join(base64.b64decode(i["data"]).decode().splitlines()[:3]))'
Dockerfile
# syntax=docker/dockerfile:1
# fig10_01.Dockerfile — Lección 10: la imagen que se entrega: la de la Lección 8,
# construida para varias plataformas SIN emulación. Go compila para otra
```

What you see, by comparing:

1. **The arguments.** In `min` only `cmdline` and `source` are there: **neither `VERSION` nor `NOTA`**. In `max` both appear with their value, including the "fake note". That is what the warning describes: whatever someone passes through `--build-arg` ends up written, readable, in a document that travels with the image and that anyone who can pull the image can read. If that note had been a token, the token would be there.
2. **The fields.** `min` has five fields (`buildType`, `builder`, `invocation`, `materials`, `metadata`); `max` adds `buildConfig`, which is the internal definition of the steps.
3. **The secrets.** In `min`, `(no aparecen)`: not even their identity is there. In `max` `[{'id': 'netrc', 'optional': True}]` appears: the **name** of the build secret (`--mount=type=secret,id=netrc`) and that it is optional (`required=false`, remember the `Dockerfile`), **but not its content**. It is the behavior the documentation promises: the secret mount does not leak the value; it does leave a record that the build asked for a secret with that name.
4. **The complete `Dockerfile`.** The last command decodes the base64 copy that `max` stores and shows its first lines: it is the `Dockerfile` that was used, with its comments, in plain sight of anyone. If your `Dockerfile` had a comment with something that must not be known, it would come out here.

The decision that follows and that the course adopts: **publish with `mode=max` because the full provenance is what makes the delivery useful, and keep the origin clean**: no secret goes through `ARG`, or `ENV`, or `--build-arg` (Lesson 6's habit), and when the build needs one, it enters through `--mount=type=secret`. With that `max` does not expose secrets, but it does publish the complete `Dockerfile` and the values of all `--build-arg`s: check both before publishing. If you work in a team where you cannot guarantee that, `min` is the safe mode, and the documentation itself says so. What is **not** acceptable is using `max` without knowing that this difference exists.

### 10.8 "Identical" is not "the same": what changes when you rebuild

A natural question after talking about *digests*: if I build the same version twice, with the same `Dockerfile` and the same code, do I get the same *digest*? You would expect so. What is measured is something else, and it is worth knowing before promising anyone "reproducibility". Block 7 rebuilds identically (with cache) and compares:

```text
== 7. Otra construcción idéntica: ¿qué digest cambia?
$ docker buildx build -q --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . >/dev/null 2>&1; echo "construcción: código $?"
construcción: código 0
antes:   índice sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:04c19cbec864dd3ff9ccf5d71d676244acecd31ae1e1d9c363006bfac903c571"
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --raw | python3 -c 'import json,sys; [print(m["platform"]["architecture"], m["digest"]) for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux"]'
amd64 sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
arm64 sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{(index .Provenance "linux/amd64").SLSA.metadata.buildStartedOn}}'; echo
2026-10-21T18:18:15.739444508-06:00
```

The **index**'s *digest* changed: from `a4246c5f…` to `04c19cbe…`. But those of **each platform** (with `--raw`, the index's raw JSON, filtered to the Linux entries) are **the same**: `b99bf1ad…` for `amd64` and `959af91e…` for `arm64`. Why did the index's change? Because the index includes, among its entries, the attestations, and the provenance carries inside it the time at which the build started (the last command shows it: `buildStartedOn`). A different time, a different provenance document, a different attestation *digest*, a different index. The images themselves did not change by a single bit. Practical consequence: **two deliveries of the same thing can have different indexes**, and if you pin by the index's *digest*, you also pin that time. It is correct (it identifies *this* delivery), but it is not what many people imagine when they read "the *digest* is the content's fingerprint".

Block 8 repeats the build with `--no-cache`, which forces every step to be redone:

```text
== 8. Y otra más, ahora SIN caché (--no-cache): ¿siguen iguales los de cada plataforma?
$ docker buildx build -q --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . >/dev/null 2>&1; echo "construcción: código $?"
construcción: código 0
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --raw | python3 -c 'import json,sys; [print(m["platform"]["architecture"], m["digest"]) for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux"]'
amd64 sha256:37dd082fe87a0b2779067a9098dab82e3c7d53e9924fa668d41638d8602dccfd
arm64 sha256:d9875545824d329af2bc6c206f52acc80145926a0cff399591bc1b4d6876e0c3
```

Now **those of each platform** also changed (`37dd082f…` and `d9875545…`). Without cache, nothing is reused, and the resulting image has a different *digest* even though the code, the `Dockerfile` and the version are the same. **What was measured is the fact; the cause was not investigated** (most likely some timestamp stored in the configuration or in the layers, but this lesson did not verify it, and you should not read it as a fact). The practical lesson is sober: **nobody is promised that rebuilding returns the same *digest***. What is promised is the opposite and more useful thing: *this* digest, once published, identifies *that* image as long as it exists in the registry. If the source has to be reproducible bit for bit, that is another topic (that of reproducible builds), which this lesson neither solves nor promises.

### 10.9 Pulling it by *digest* and running it as it should be run

#### 10.9.1 As on a machine that never built it

Publishing is of no use if you do not check that the image can be *received*. The honest test is done as if you were Tomás: a machine that does not have the image, that knows only the registry and a *digest*. (A warning so as not to mix up the numbers: the *digests* of `fig10_02.sh`, single-platform, and those of `fig10_04.sh`, a two-platform index, are of different images and therefore do not match.) In block 9 of `fig10_04.sh`, before downloading anything, the script **deletes the local copies** that the build left (with the *containerd* store, even with `--push` the image also stays on your machine) and checks it with `docker image ls` before and after, so that the only thing that exists is what the registry says. Then it is pulled by *digest*:

```text
== 9. Traerla por digest, no por etiqueta
(copias locales de localhost:5000/curso-docker-revisor que dejó la construcción)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10-min
localhost:5000/curso-docker-revisor:fig10-max
(y después de borrarlas)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
(ninguna)
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
$ docker run --rm localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 version
1.6.0
$ docker image inspect --format '{{json .RepoDigests}}' localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52; echo
["localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52"]
```

(This block's *digest* is that of the index that was left in the registry after the script's last build; it changes on each run.) The `docker pull -q` with `@sha256:…` downloaded **only what corresponds to this processor**. `docker run … version` prints `1.6.0`: the version that was baked in at compile time. And `RepoDigests` is the field of a local image that stores **which registry and which *digest* it came from**: it is the record that the local copy is not a build of your own but a download, and it is what lets you, months later, ask "where did what is running come from?".

It is worth saying what is expected to happen here even though the output does not print it. The Open Container Initiative's distribution specification, the document that defines how clients talk to registries, says that clients "SHOULD verify that the response body matches the requested digest" ([OCI, "Distribution Specification"](https://github.com/opencontainers/distribution-spec/blob/main/spec.md)). It is a recommendation to clients and this lesson did not measure it with an image deliberately altered; what you do have is the practical rule: asking by *digest* is asking for something that can be checked, and a reference with a *digest* that does not match must be a failure and not "another image".

#### 10.9.2 What came down, and what did not

Block 10 shows something that surprises you the first time: of the index's two platforms, your machine downloaded one.

```text
== 10. Lo que bajó a este equipo: solo su plataforma
$ docker image ls --tree localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 2>/dev/null | sed -E 's/@sha256:([0-9a-f]{12})[0-9a-f]+/@sha256:\1…/'
IMAGE                                                                                                              ID             DISK USAGE   CONTENT SIZE   EXTRA
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8…   6956d5334dc8       16.8MB         4.34MB        
├─ linux/amd64                                                                                                     37dd082fe87a           0B             0B        
└─ linux/arm64                                                                                                     d9875545824d       16.2MB         3.68MB        

$ docker save --platform linux/arm64 -o ../propia.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 && echo 'guardada: linux/arm64'
guardada: linux/arm64
$ docker save --platform linux/amd64 -o ../otra.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
Error response from daemon: no suitable export target found: image with reference localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 was found but does not provide the specified platform (linux/amd64)
[código de salida: 1]
```

And block 11, which pulls the other platform and tries to run it:

```text
== 11. Traer la OTRA plataforma, guardarla y probar a correrla (linux/amd64)
$ docker pull -q --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
$ docker save --platform linux/amd64 -o ../otra.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 && echo 'guardada: linux/amd64'
guardada: linux/amd64
$ docker run --rm --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 version 2>&1 | head -3
1.6.0
```

`docker image ls --tree` is the view that shows the index and its platforms. It reads like this: at the top, the reference with the index's *digest*; below, one row per platform with its own identifier. The `DISK USAGE` column holds the key: `linux/arm64` takes up **16.2 MB** on disk (the `revisor` image: the same size that Lessons 8 and 9 measured, 16.2 MB) and `linux/amd64` takes up `0B`. It is in the list because the index mentions it, but **its layers were not downloaded**. It is efficient (nobody downloads what they are not going to run), and it has a practical consequence that the last command triggers on purpose: `docker save --platform linux/arm64` works, and `docker save --platform linux/amd64` fails with `no suitable export target found … does not provide the specified platform`. The `docker image save` documentation says exactly that: `--platform` saves only the indicated platforms, and "an error is produced if the given platform is not present in the local image store" ([Docker, `docker image save`](https://docs.docker.com/reference/cli/docker/image/save/)). The moral of the error: **if you need the other platform's file, you have to pull it first**; saving does not download it. Block 11 does that, and in passing answers the question section 10.4 left open: does the other platform's binary really start?

Block 11 of the output above reads like this. `docker pull -q --platform linux/amd64 …@sha256:…` downloads the layers of the platform that was missing (the reference is the same; `--platform` picks the index entry). With it in the store, the same `docker save --platform linux/amd64` that had failed now answers `guardada: linux/amd64`. And the last command, `docker run --rm --platform linux/amd64 … version`, prints `1.6.0`: **the `amd64` binary started and answered**. It has to be said under what conditions this was measured, so as not to promise too much: this machine is `arm64`, so that binary ran **emulated** by QEMU; it is proof that the file is a valid `amd64` executable that starts, not proof of how it behaves on a real `amd64`, and starting a small static binary is a far smaller demand than compiling with Go (which was what the emulation could not withstand in 10.4.2).

**If your machine is `amd64` (like your Mint), this is the check that falls to you**, and it is the one that really counts: the same command, `docker run --rm --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:… version`, now runs natively. If your machine is `arm64`, the "other" platform is `linux/amd64` and the output above is the one you should get. In both cases the expected result is `1.6.0`.

This matters right away, because the next section's scan is done on a `docker save`, and it scans **one** platform. A two-platform index is scanned in two passes. In this lesson the script scans the one for your own processor, and that limitation is stated out loud in 10.10.

#### 10.9.3 Running it hardened: mounting `/datos` again

Lesson 8's image stores its report in `/datos`, and since Lesson 7 it is run with `--read-only`: the container's file system is read-only. That has a consequence you already measured in Lesson 8 and that is seen again here, with the image **pulled by *digest***, as another person would receive it: if you mount nothing on `/datos`, the healthy `revisor` cannot save its report. Block 5 of `fig10_02.sh` runs the image with all the measures and **without a volume**:

```text
== 5. La de digest, endurecida como en la Lección 8: sin nada en /datos
$ docker run -d --name curso-docker-revisor-fig10 -p 127.0.0.1:8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c >/dev/null && echo 'contenedor arriba'
contenedor arriba
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"1.6.0"}
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

The first command creates the container with the measures from Lessons 7 and 8 (`--read-only`, `--cap-drop ALL`, `--security-opt no-new-privileges`, `--init`) and the reference **by *digest***; the `>/dev/null && echo` only hides the identifier and confirms that it finished well. Then, `/salud` answers `vivo` and `1.6.0`: the process started and the image is the one you asked for. Next, `/api/estados` answers `500` with a message read from right to left, as in Lessons 6 and 8: `read-only file system` is said by the kernel (you cannot write there), `open /datos/.reporte-<n>.tmp` says which file (the temporary one the `revisor` writes before renaming it) and `no pude guardar el reporte` is added by the `revisor`, which prefers to answer `500` rather than pretend everything went well. It is not a defect of the delivered image: it is the read-only system working as requested. The fix is the usual one, **mount something writable on `/datos`**:

```text
== 6. La misma, con un volumen en /datos (un contenedor no recibe un volumen después: se borra y se crea otro)
$ docker rm -f curso-docker-revisor-fig10 >/dev/null && echo 'contenedor anterior borrado'
contenedor anterior borrado
$ docker run -d --name curso-docker-revisor-fig10 -p 127.0.0.1:8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init -v curso-docker-reportes-fig10:/datos -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c >/dev/null && echo 'contenedor arriba'
contenedor arriba
$ curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:8080/api/estados
[200]
$ docker inspect --format '{{.Config.Image}}' curso-docker-revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'
localhost:5000/curso-docker-revisor@sha256:59e431fa44c7…
```

A container cannot receive a volume after being created: that is why block 6 begins by deleting the previous one (`docker rm -f`) and creates another with the same recipe plus `-v curso-docker-reportes-fig10:/datos` (the script's helper volume; in your folder: `--name curso-docker-revisor` and `-v curso-docker-reportes:/datos`, Lesson 8's volume). This time `/api/estados` answers `200`. And the last line is the close of what the section "The why before the how" promised: `docker inspect` says the container was created **with a reference by *digest***. Nothing in its history depends on a tag still pointing where it used to. Remember that the new volume inherits the owner `65532` from the folder the image brings (Lesson 8); that is why neither `--user` nor `chmod` is needed here.

A remark about `-e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud'`: it is the service the `revisor` queries. Here it is **itself**, at its own `/salud`, so that the test does not depend on any other container. It is a way to test the image in isolation, and the same one the `kind` pod in section 10.11 uses.

### 10.10 Scanning what you deliver with Trivy

#### 10.10.1 What a scanner does, and what it does not

A **vulnerability scanner** takes the list of what is inside an image (system packages, language modules, the Go binary itself) and compares it with **databases of known flaws**. Each public flaw has an identifier (a CVE number, or the distribution's, like Debian's *DSA*s), a severity and, sometimes, a fixed version. **Trivy** is an open-source scanner, made by Aqua Security, that runs as a command-line program, and here you use it from its official image `aquasec/trivy:0.76.0`, published on October 14, 2026 ([0.76.0 release notes](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0)).

Two warnings up front. The first: **a scanner answers "what *known* problems does this have *today*?"**. It does not answer "is it secure?". A result of zero findings means "none of the flaws my database knows, today, in the packages I recognized"; tomorrow it may stop being zero without the image changing, because a new flaw will be published. The second: the quality of the result depends on the freshness of its database, and that is why block 6 of `fig10_05.sh` measures it.

#### 10.10.2 The error: asking for the image by its name

For this exercise start from a local image with a simple name: block 1 of `fig10_05.sh` builds it with `docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 .` (in your folder, `curso-docker-revisor:1.6.0`), and `docker image ls` confirms its 16.2 MB. The first instinct is the short command: `trivy image my-image`. Since Trivy runs inside a container, and the image is in your Docker, it does not find it. A long error comes out with a valuable lesson. Block 2 of `fig10_05.sh` triggers it and filters it:

```text
== 2. El error: pedirle a Trivy la imagen por su nombre, sin socket
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache aquasec/trivy:0.76.0 image --quiet curso-docker-revisor:fig10 2>&1 | grep -oE 'unable to find the specified image.*|^\s+\* [a-z]+ error: .*' | cut -c1-120
unable to find the specified image "curso-docker-revisor:fig10" in ["docker" "containerd" "podman" "remote"]: 4 erro
	* docker error: unable to inspect the image (curso-docker-revisor:fig10): failed to connect to the docker API at un
	* containerd error: containerd socket not found: /run/containerd/containerd.sock
	* podman error: unable to initialize Podman client: no podman socket found: stat podman/podman.sock: no such file or di
	* remote error: GET https://index.docker.io/v2/library/curso-docker-revisor/manifests/fig10: UNAUTHORIZED: authenti
[código de salida: 1]
```

Reading. The command mounts a volume (`-v curso-docker-trivy-cache-fig10:/root/.cache`) where Trivy stores its database so as not to download it on every run, and launches `image --quiet curso-docker-revisor:fig10`. The `grep -oE` keeps only the main error line and the four failed attempts; the `cut` trims each to 120 characters. The message says that Trivy **looked for the image in four places**, in this order: `docker` (talking to the daemon through its *socket*), `containerd`, `podman` and `remote` (a registry). It is the same order Trivy documents: it looks "first in the local Docker engine, then in *containerd*, *podman* and, finally, in a container registry" ([Trivy, "Container Image"](https://trivy.dev/latest/docs/target/container_image/)). It failed in each: the Docker *socket* is not inside the container (`failed to connect to the docker API`), there is no `containerd` or `podman`, and as a last resort it tried to download `curso-docker-revisor` from Docker Hub, where it does not exist (`UNAUTHORIZED`).

The "tutorial" fix for the first error is to mount the Docker *socket* inside Trivy's container (`-v /var/run/docker.sock:/var/run/docker.sock`). **Do not do it.** It is what Lesson 2 taught you not to do: whoever has the Docker *socket* controls Docker, and therefore controls your machine with `root` permissions. Giving it to a container so that it can "read" an image is handing the key to everything to a program that, on top of that, downloads data from the internet every time it runs. The right path gives the same result without handing over anything: **save the image to a file, and give Trivy the file**.

#### 10.10.3 Saving and scanning the file

Trivy accepts saved images: its documentation says so, with the example of `docker save` followed by `trivy image --input file.tar` ([Trivy, "Container Image"](https://trivy.dev/latest/docs/target/container_image/)), and the command reference describes `--input` as the "path to an input file instead of an image name" ([Trivy, `trivy image`](https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/)). Block 3 does both things:

```text
== 3. Guardar la imagen en un archivo y escanear el archivo
$ docker save --platform linux/arm64 -o revisor-1.6.0.tar curso-docker-revisor:fig10 && du -h revisor-1.6.0.tar | cut -f1
3.6M
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --severity HIGH,CRITICAL --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#'

Report Summary

┌──────────────────────────────────────────┬──────────┬─────────────────┬─────────┐
│                  Target                  │   Type   │ Vulnerabilities │ Secrets │
├──────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
├──────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ revisor                                  │ gobinary │        0        │    -    │
└──────────────────────────────────────────┴──────────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)
```

The first command saves the image to a 3.6 MB `.tar` file, **of your platform only** (`--platform linux/arm64`; on your Mint it would be `linux/amd64`). The 3.6 MB is the compressed image; the 16.2 MB that `docker image ls` showed is uncompressed. The second command, in pieces:

- `docker run --rm` launches Trivy and deletes it when done; `-v curso-docker-trivy-cache-fig10:/root/.cache` is the database cache (in your folder, `-v curso-docker-trivy-cache:/root/.cache`), in a **named volume** so that it survives between runs and can be deleted at the end.
- `-v "$PWD":/trabajo:ro` mounts your current folder at `/trabajo`, **read-only** (`:ro`): Trivy can read the `.tar`, but not write in your folder. It is least privilege applied to the scanner.
- `image --quiet --input /trabajo/revisor-1.6.0.tar` asks to scan the file, without the progress bar.
- `--severity HIGH,CRITICAL` sets the **threshold**: it reports only serious and critical flaws. The filtering documentation illustrates it with exactly this option ([Trivy, "Filtering"](https://trivy.dev/latest/docs/configuration/filtering/)).
- `--exit-code 1` tells Trivy which exit code to return "when it finds security issues" (that is how the command reference describes it). By default it exits with 0 even if it finds things (block 4b measures it); with `1`, a script or a *pipeline* can **fail** if there are findings. That is the trick that turns a report into a gate.
- The `sin_fechas` and the `sed` are presentation in the script: the first removes the timestamped notices that Trivy prints at the start of the line (so that the output can be compared between runs) and the second shortens `/trabajo/` to `./`. You do not need them when you run the command yourself.

The table reads from top to bottom. `Report Summary` is the header; each row is a scanned **target**. The first is `./revisor-1.6.0.tar (debian 13.7)`, of type `debian`: the base's system packages, with **0** findings. The second is `revisor`, of type `gobinary`: Trivy recognized that there is a Go binary inside the file, read the modules it carries and checked them too, with **0** findings. The `Secrets` column says `-`. Trivy looks for vulnerabilities and secrets by default (the `trivy image` reference gives `vuln,secret` as the value of `--scanners`), but for secrets it only records findings, so the documentation clarifies that the `-` in that column means "no findings" and does not distinguish between "not searched" and "searched and nothing was there" ([Trivy, "Reporting"](https://trivy.dev/latest/docs/configuration/reporting/)). Another reason not to read a zero as a guarantee. And the `0` in the legend says `Clean (no security findings detected)`. With the `HIGH,CRITICAL` threshold, the exit code was 0, and that is why the script does not print `[código de salida: …]`. Notice the legend's word: *detected*. It is the nuance of the earlier warning.

#### 10.10.4 The threshold decides what you see, and `UNKNOWN` also counts

Now the same image, **without** `--severity`, with the same `--exit-code 1`. Block 4 scans it with all severities and filters the result to leave the tables:

```text
== 4. El mismo archivo, con todas las severidades y el mismo --exit-code 1
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#' | grep -E 'Total|│' 
│                  Target                  │   Type   │ Vulnerabilities │ Secrets │
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
│ revisor                                  │ gobinary │        0        │    -    │
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
│     Library     │ Vulnerability │ Severity │ Status │ Installed Version │  Fixed Version   │               Title               │
│ ca-certificates │ DSA-6572-1    │ UNKNOWN  │ fixed  │ 20250419          │ 20250419+deb13u1 │ ca-certificates - security update │
[código de salida: 1]
```

**One finding** appears that the earlier threshold hid. Each column of the last table has to be read: `Library` is the package (`ca-certificates`, the one in 10.6's bill of materials); `Vulnerability` is the identifier (`DSA-6572-1`, a *Debian Security Advisory*); `Severity` is `UNKNOWN`; `Status` is `fixed`; `Installed Version` is `20250419`, the one the image has; `Fixed Version` is `20250419+deb13u1`, the Debian version that already fixes the flaw; and `Title` is the advisory's title. One line sums it up: `Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)`. There are five categories and that is how Trivy lists them in its summary: `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` ([Trivy, "Reporting"](https://trivy.dev/latest/docs/configuration/reporting/)). Four go from least to most severe; `UNKNOWN` is not "less severe than `LOW`": it is "unclassified". Trivy's documentation says that it is used when no source gave the finding a severity ("if no vendor has a severity, `UNKNOWN` will be used"; [Trivy, "Vulnerability"](https://trivy.dev/latest/docs/scanner/vulnerability/)). That is why it is not dismissed without looking.

Three lessons in this block:

1. **The threshold is your decision, not a detail.** With `HIGH,CRITICAL` the image "passes"; with all severities it has one finding. Neither is a lie, but they answer different questions. Choose the threshold before looking at the result, and write it down (in the *pipeline*, in the project's README) so that nobody adjusts it later to make it come out green.
2. **`UNKNOWN` counts.** The finding is of `UNKNOWN` severity, and even so `--exit-code 1` returned **1** (the `[código de salida: 1]` line). That is: without `--severity`, even what the scanner cannot classify breaks your gate. If you prefer that the unknown not fail, declare it with `--severity` listing the severities you do care about. What you should not do is not know it.
3. **A `fixed` finding is actionable.** The `fixed` status and the `Fixed Version` column say that there is a fixed version. The fix is not to forget it or turn off the scanner: it is to update the package. How a package of a distroless base that you pinned by *digest* is updated is the subject of section 10.12.

And the contrast that explains what `--exit-code` is for. Block 4b runs **the same scan without that option** and asks for Trivy's own exit code with `echo "código de Trivy: $?"`:

```text
== 4b. Lo mismo, sin --exit-code: ¿con qué código sale Trivy por omisión?
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código'
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 0
```

Same finding (`Total: 1`) and code **0**. Without `--exit-code`, Trivy reports but does not fail: a script that merely launches it would carry on with a serious finding without noticing. It was measured, not assumed: a scan in a *pipeline* without `--exit-code` is a decoration that says "fine" even when there are findings. It is the same kind of trap you already know from earlier lessons: the exit code is what the machine reads, and you have to check that it really changes when it should.

#### 10.10.5 `--ignore-unfixed`: an intuition that goes wrong

There is an option that looks like the easy way out: `--ignore-unfixed`, which the command reference describes as "display only fixed vulnerabilities" (*display only fixed vulnerabilities*, [Trivy, `trivy image`](https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/)) and which the filters page presents as the way to "skip all unfixed vulnerabilities" (*skip all unfixed vulnerabilities*, [Trivy, "Filtering"](https://trivy.dev/latest/docs/configuration/filtering/)). The intuition says: "let's ignore what has no fix, so that only what I can fix fails". Block 5 tests it, and the name has to be read carefully:

```text
== 5. ¿Y si se ignora lo que no tiene arreglo?
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignore-unfixed --exit-code 1 2>&1 | sin_fechas | grep -E '^Total'
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
[código de salida: 1]
```

The same finding remains and code 1 remains. And it is not a Trivy error: `--ignore-unfixed` hides what **has no** fixed version, and this finding **does have one** (`fixed`, `20250419+deb13u1`). The option does what it says; what it does not do is solve your problem, because your problem is one of those that do have a fix. It is a good example of why you test an option instead of assuming what it does from its name.

#### 10.10.6 What date is what it knows from?

The last block answers a question that should accompany every scan: against what date was it compared?

```text
== 6. ¿De cuándo es la base de datos de vulnerabilidades?
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache aquasec/trivy:0.76.0 version 2>&1 | sin_fechas
Version: 0.76.0
Vulnerability DB:
  Version: 2
  UpdatedAt: 2026-10-21 19:18:22.876313144 +0000 UTC
  NextUpdate: 2026-10-22 19:18:22.876312904 +0000 UTC
  DownloadedAt: 2026-10-22 00:17:14.540681058 +0000 UTC
```

`trivy version` prints the program's version and the data of its database: when the latest version was **published** (`UpdatedAt`: October 21, 19:18 UTC), when the next is expected (`NextUpdate`: one day later) and when it was **downloaded** to your cache (`DownloadedAt`). The last three lines are the ones you keep next to the scan result: a "0 findings" without a database date is a value with no age, and values with no age rot.

Two limits of the scan done this way, which the lesson already let you see and now come together. One: you scanned **one platform**, your machine's; the index's `amd64` was not checked. For a real delivery, you repeat the `docker save --platform` and the scan for each published platform. Two: the scanner checks what is *inside* the image; it does not check your `Dockerfile` or your execution permissions (that was covered by `docker build --check` in Lesson 3 and the measures of Lessons 7 and 8). It is one layer of defense, not the defense.

### 10.11 The bridge to Kubernetes: `kind load docker-image`

#### 10.11.1 Why the cluster does not see your image

The next course, the one on Kubernetes with `kind`, takes the image you leave here with. `kind` (*Kubernetes IN Docker*) starts a Kubernetes cluster inside Docker containers: each "node" of the cluster is a container. That has a surprising consequence: even though the node runs in your Docker, **it has its own image store** inside. What you built with `docker build` lives in your Docker's store, and the node does not see it. A pod that asked for `curso-docker-revisor:1.6.0` would try to pull it from a registry, and that image is only on your machine.

There are two ways to solve it: publish the image to a registry the cluster can reach, or **load it directly into the nodes**. In a local lab, the second is the short one, and it is the one this lesson uses. The `kind` documentation presents it like this: "you can load one or more images into your `kind` cluster" with `kind load docker-image my-app:latest`, and if the cluster has a name, you have to indicate it with `--name` ([kind, "Quick Start"](https://kind.sigs.k8s.io/docs/user/quick-start/)). The same page carries a warning with two conditions that are just what you are going to see: "Kubernetes' default pull policy is `IfNotPresent`, unless the tag is `:latest` or is not written"; for loaded images to work as you expect, **do not use the `:latest` tag** and/or specify `imagePullPolicy: IfNotPresent` or `imagePullPolicy: Never` in your container.

The `Never` policy is the one the test uses. Kubernetes' documentation defines it like this: "the kubelet does not try to fetch the image. If the image is already present locally, the kubelet tries to start the container; otherwise, startup fails" ([Kubernetes, "Images"](https://kubernetes.io/docs/concepts/containers/images/)). For a test it is the ideal policy, because it helps not to hide transport problems: if the image did not reach the node, the pod does not start and says so, instead of trying to download it from the internet and taking its time (or, worse, downloading *another* image with the same name). One limit: if the node already had an old image with that same tag, `Never` would start it without warning; that is why in tests you use a new cluster or a new version.

#### 10.11.2 Installing `kind` and `kubectl`

So far everything was done with Docker. This step needs two more programs that you did **not** install in the earlier lessons: `kind` and `kubectl`. If your machine is the course's Linux Mint, install them with the official guides, with the version pinned (those of this course, measured on October 21, 2026). `kind` is downloaded as a binary ([kind, "Quick Start"](https://kind.sigs.k8s.io/docs/user/quick-start/)); `kubectl`, from `dl.k8s.io`, with a check of its `sha256` checksum ([Kubernetes, "Install and Set Up kubectl on Linux"](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)):

```bash
# kind v0.33.0 (elige la línea de tu procesador; `uname -m` dice x86_64 o aarch64)
[ "$(uname -m)" = x86_64 ]  && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
[ "$(uname -m)" = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl v1.37.1
ARQ=amd64; [ "$(uname -m)" = aarch64 ] && ARQ=arm64
curl -LO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl"
curl -LO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

The first two `kind` lines are from the official guide: each one runs only if your processor is the one it names, so on your machine exactly one runs. The `sha256sum --check` line is the one that protects the download: it must answer `kubectl: OK`; if it answers `FAILED`, delete the file and download it again. `sudo install -o root -g root -m 0755` copies the program to `/usr/local/bin` with owner `root` and execute permission, which is the form the guide indicates. The download-and-verification sequence was tested inside the runs' virtual machine (Ubuntu 24.04, `arm64`), with the script `fig10_00.sh` (blocks 2 and 3, with their output next to them), without the installation into `/usr/local/bin` so as not to change the system, and it answered:

```text
$ ./kind version
kind v0.33.0 go1.26.7 linux/arm64
$ echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
kubectl: OK
$ ./kubectl version --client
Client Version: v1.37.1
Kustomize Version: v5.8.1
```

(The Go version `kind` was compiled with changes depending on the platform where you run it: on the runs' Mac it said `go1.27.0 darwin/arm64`.) Check your installation with `kind version` and `kubectl version --client`.

#### 10.11.3 The cluster and the image

The script `fig10_06.sh` is run on the **Mac** (not inside the virtual machine) because that is where `kind` and `kubectl` live; they talk to the same Docker daemon. It has a detail worth explaining before reading the output: it uses a **temporary `kubectl` configuration file of its own** (`export KUBECONFIG=…` inside the script). That way the cluster it creates does not modify your `kubectl` context or your `~/.kube/config` file. **On your machine, following the lesson, you want the opposite:** for `kind` to switch your context to the new cluster, and that is why the commands below carry no `KUBECONFIG`. Even so, and it is a habit worth having from today, **before each `kubectl` command check which cluster you are on** with `kubectl config current-context`: a `kubectl delete` in the wrong context is the kind of mistake that cannot be undone.

The first sections of the script:

```text
$ ./fig10_06.sh
== 1. Versiones
$ kind version
kind v0.33.0 go1.27.0 darwin/arm64
$ kubectl version --client | head -1
Client Version: v1.37.1

== 2. La imagen, para la plataforma de este equipo
$ docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 . >/dev/null && docker image ls curso-docker-revisor:fig10 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:fig10 16.2MB

== 3. Un clúster kind de un nodo
$ kind create cluster --name curso-docker-puente-fig10 --wait 120s 2>&1 | grep -E '^Creating|Ready after|Set kubectl context' | sed -E 's/Ready after [0-9]+s/Ready after Ns/; s/ +[^ -~]+//g'
Creating cluster "curso-docker-puente-fig10" ...
 Ready after Ns
Set kubectl context to "kind-curso-docker-puente-fig10"
$ kubectl config current-context
kind-curso-docker-puente-fig10
```

The versions are the course's: `kind` v0.33.0, which by default uses the node image `kindest/node:v1.37.0`, that is Kubernetes 1.37.0 ([kind, v0.33.0 release notes](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0)), and `kubectl` v1.37.1. Then, `docker build` builds the image **for this machine's platform** (here `arm64`). In your folder, the command is `docker build --build-arg VERSION=1.6.0 -t curso-docker-revisor:1.6.0 .`, which leaves the image in your Docker with the name the next course will use; the script uses the helper tag `fig10`. A plain `docker build` builds for the native platform and leaves the result in the local store, which is exactly what `kind load` is going to read. It weighs 16.2 MB. `kind create cluster --name … --wait 120s` creates the one-node cluster and waits up to two minutes for it to be ready; the script's `grep` and `sed` leave only the three lines that matter (the rest are progress indicators with symbols), and the real time (`Ready after Ns`) is masked because it changes from run to run. `kind` ended up setting the context: `kubectl config current-context` answers `kind-curso-docker-puente-fig10`. The context `kind` creates is called `kind-` plus the cluster's name (that is how it came out in the run), so the course prefix (`curso-docker-`) is inherited all the way to your context's name.

#### 10.11.4 Triggering the error before the solution

The concrete first: ask for the pod **before** loading the image and read what it says. This is block 4:

```text
== 4. El error: el pod ANTES de cargar la imagen
$ kubectl run revisor --image=curso-docker-revisor:fig10 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason
NOMBRE    ESTADO    RAZON
revisor   Pending   ErrImageNeverPull
$ kubectl get events --field-selector involvedObject.name=revisor,reason=ErrImageNeverPull -o custom-columns=MENSAJE:.message | head -2 | cut -c1-110
MENSAJE
Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace
```

`kubectl run revisor --image=… --image-pull-policy=Never --port=8080 --env=…` creates a pod with one container. `--image-pull-policy=Never` is the policy above; `--port=8080` declares the port it listens on; `--env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'` is the same variable as in earlier sections (the `revisor` queries itself, so that the test does not depend on another pod). Then, `kubectl get pod … -o custom-columns=…` prints a table with the columns you choose, with their paths inside the pod's object: the state (`phase`) is `Pending` and the waiting reason (`waiting.reason`) is **`ErrImageNeverPull`**. The name already tells the story: image error, with the `Never` policy, which did not try to download it. The event confirms it with a full sentence: `Container image "…" is not present with pull policy of Never`: the image is not present and the policy forbids downloading it. That is the error: the node does not have the image. Nothing is broken in the image or in the pod; the step that takes it there is missing. Before going on, the script deletes the failed pod (`kubectl delete pod revisor --wait=true`), because a pod does not change its policy by itself and starting from scratch is cleaner.

#### 10.11.5 Loading the image and asking for the pod again

```text
== 5. Cargar la imagen en el nodo (sin registro) y volver a pedir el pod
$ kind load docker-image curso-docker-revisor:fig10 --name curso-docker-puente-fig10
Image: "curso-docker-revisor:fig10" with ID "sha256:0c8af76b8a5fbea25ddafedf41bc49ad9ec5f7144117559da98afbd1da0d2eaa" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/curso-docker-revisor      fig10                dda2fbcae183b       3.68MB
$ kubectl run revisor --image=curso-docker-revisor:fig10 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=90s
pod/revisor condition met
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image,REINICIOS:.status.containerStatuses[0].restartCount
NOMBRE    ESTADO    IMAGEN                           REINICIOS
revisor   Running   curso-docker-revisor:fig10   0
$ kubectl logs revisor
revisor 1.6.0 escuchando en :8080 (1 servicio(s))
$ kubectl get events --field-selector involvedObject.name=revisor -o custom-columns=RAZON:.reason,MENSAJE:.message | cut -c1-110
RAZON               MENSAJE
Scheduled           Successfully assigned default/revisor to curso-docker-puente-fig10-control-plane
ErrImageNeverPull   Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
Failed              Error: ErrImageNeverPull
Scheduled           Successfully assigned default/revisor to curso-docker-puente-fig10-control-plane
Pulled              Container image "curso-docker-revisor:fig10" already present on machine and can be acc
Created             Container created
Started             Container started
```

`kind load docker-image curso-docker-revisor:fig10 --name curso-docker-puente-fig10` reads the image from your Docker and copies it to the node. It prints a single line, which reads: the image with that identifier (`ID "sha256:0c8af76b…"`) was **not yet present on the node** `curso-docker-puente-fig10-control-plane`, and is being loaded. (That identifier is that of the local image, not a registry *digest*.) Next comes the check that must not be skipped: asking the **node** which images it has, with `docker exec <node> crictl images` (`crictl` is the command-line tool of the container runtime that comes inside the node; the `kind` node is a Docker container, which is why `docker exec` gets into it). The `grep` leaves the header and the `revisor`'s rows. `docker.io/library/curso-docker-revisor` appears, tag `fig10`, 3.68 MB: the image **is** on the node, with the full name Kubernetes gives to a short name. That row is the evidence that the load worked, and it is better than trusting the `loading...` message, as you will see in 10.11.6. Then, the same `kubectl run` as before, and now:

- `kubectl wait --for=condition=Ready pod/revisor --timeout=90s` waits up to 90 seconds for the pod to be ready; the answer `condition met` is the fulfilled condition.
- The pod's table says `Running` with the image `curso-docker-revisor:fig10` and **0 restarts**.
- `kubectl logs revisor` shows what the `revisor` prints on startup: `revisor 1.6.0 escuchando en :8080 (1 servicio(s))`. It is the same line as in Lesson 3. The version `1.6.0` confirms that the image you built is the one running.
- The events are the proof that the bridge worked without downloading anything. The first three lines are from the earlier failed attempt (`ErrImageNeverPull`, `Failed`). Then, the new pod: `Scheduled` (assigned to the node), and then `Pulled` with the message **`Container image "…" already present on machine`**. Even though the event is called `Pulled` (downloaded), the text says there was no download: it found the image already on the node, where `kind load` left it. The message comes out trimmed by the script's `cut -c1-110` (`…and can be acc`, from "and can be accessed by the container"). Then `Created` and `Started`.

That phrase, `already present on machine`, is the proof that course goal 6 is looking for: **the pod started without any download attempt**. When the Kubernetes course begins, you will repeat this bridge with `curso-docker-revisor:1.6.0` and the cluster `curso-docker-puente`.

To leave clean what you did on your machine (your cluster, not a script's): `kind delete cluster --name curso-docker-puente`. It deletes the cluster and removes its context from your configuration; your Docker's image is not touched.

#### 10.11.6 If you did not build the image: the one that comes from a registry

There is a case the next course may run into: you do not build the image on your machine but **pull it from the registry** by its *digest*, as in 10.9. It would be natural to think that `kind load docker-image` accepts it with that same reference. It was measured, and it is not so. The script `fig10_09.sh` publishes a two-platform index, pulls it by *digest* to the Mac, creates the cluster and tries three paths:

```text
== 3. Cargar la imagen traída del registro, por su referencia con digest
$ kind load docker-image localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 --name curso-docker-puente-fig10
Image: "localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" with ID "sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               011d6bb2f3c70       3.68MB

== 4. Guardarla con docker save y cargar el archivo
$ docker save --platform linux/arm64 -o revisor.tar localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 && du -h revisor.tar | cut -f1
3.5M
$ kind load image-archive revisor.tar --name curso-docker-puente-fig10

== 5. ¿Qué nombres tiene la imagen dentro del nodo?
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120 | sed -E 's/([0-9a-f]{12})[0-9a-f]{52}/\1…/g'
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               011d6bb2f3c70       3.68MB
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB

== 6. Pedir el pod con la MISMA referencia con digest, sin descarga
$ kubectl run revisor --image=localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
error: timed out waiting for the condition on pods/revisor
[código de salida: 1]
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason
NOMBRE    ESTADO    RAZON
revisor   Pending   ErrImageNeverPull
```

And the two remaining paths (block 7 and block 8):

```text
== 7. Una etiqueta local sobre la misma imagen, y cargar esa etiqueta
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace
$ docker tag localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 curso-docker-revisor:fig10-registro
$ kind load docker-image curso-docker-revisor:fig10-registro --name curso-docker-puente-fig10
Image: "curso-docker-revisor:fig10-registro" with ID "sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/curso-docker-revisor      fig10-registro       011d6bb2f3c70       3.68MB
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB
$ kubectl run revisor --image=curso-docker-revisor:fig10-registro --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
pod/revisor condition met
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image
NOMBRE    ESTADO    IMAGEN
revisor   Running   curso-docker-revisor:fig10-registro
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace

== 8. Traer solo el manifiesto de la plataforma (no el índice) y cargarlo
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0
localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0
$ kind load docker-image localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0 --name curso-docker-puente-fig10
Image: "localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0" with ID "sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB
docker.io/library/curso-docker-revisor      fig10-registro       011d6bb2f3c70       3.68MB
$ kubectl run revisor --image=localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
error: timed out waiting for the condition on pods/revisor
[código de salida: 1]
```

It reads like this. **Path 1, load the reference with a *digest* (block 3).** `kind load` prints `not yet present on node … loading...` and gives no error. Then the script asks the node which images it has, with `crictl` (the command-line tool of the container runtime that comes inside the node), and the filter lets through the rows with `revisor` **and those with no name** (`<none>`). **There is no image called `revisor`, but there is one without a name:** `docker.io/library/import-2026-10-22`, tag `<none>`, 3.68 MB. The image **did** reach the node, without the name the pod asks for. The `import-` followed by the date is the placeholder name that `ctr images import` (the command with which `kind` imports, according to the reports cited below) gives to whatever it imports without a reference of its own ([containerd, `ctr images import`](https://github.com/containerd/containerd/blob/main/cmd/ctr/commands/images/import.go)); the date is that of the node's clock, which is in UTC, and that is why it says 22 even though the runs were on the 21st in Mexico City. **Path 2, save with `docker save --platform` and load the file with `kind load image-archive` (block 4):** the command ends without an error and without output; block 5 shows the same 3.68 MB row and a second nameless one of 2.32 kB (what it contains was not investigated). Block 6 is the consequence: a pod that asks for the reference with a *digest* stays `Pending` with `ErrImageNeverPull`, because on the node there is no image with that name even though its content is there. **Path 3, a local tag (block 7):** `docker tag <reference with digest> curso-docker-revisor:fig10-registro` gives a local name to the pulled image, `kind load docker-image` of that tag leaves the image on the node **with a name** (`crictl` shows it as `docker.io/library/curso-docker-revisor`, with the tag `fig10-registro` and 3.68 MB; the nameless 3.68 MB row is no longer there, because it was the same image: the same identifier, `011d6bb2f3c70`) and the pod starts: `Running`. Two observations. One: the node writes the full name, `docker.io/library/…`, but the pod that asks for `curso-docker-revisor:fig10-registro` finds it, because Kubernetes completes the short name in the same way. Two: **loading the reference of the platform manifest** (block 8, which pulls `…@sha256:7d76…`, the `arm64` manifest instead of the index) did not work either: the pod waits again with `ErrImageNeverPull`. So the problem is not the multi-platform index but the reference with a *digest*.

The practical rule: **`kind load` works with a tagged name; with a reference with a *digest* it answers "loading" and does not leave on the node an image that the pod can find by that reference.** If your image comes from a registry, first give it a local tag with `docker tag` and load that. **The source, stated exactly.** There is no `kind` page that describes this case as it is (loading by a reference with a *digest* and receiving no error). What does exist in the `kind` repository are neighboring reports, of the same origin: with Docker 29 and its *containerd* store, `docker save` keeps the full index of a multi-platform image even if only the layers of yours were pulled, and `kind load` (which imports with `ctr images import --all-platforms --digests`) fails with `content digest … not found`. The maintainers attribute it to `docker save` having "made breaking changes when using containerd-backed storage" and point as a short-term way out to not using that store ([kind, issue #4066, "kind unable to load images with docker 29"](https://github.com/kubernetes-sigs/kind/issues/4066), closed as a duplicate of the pinned issue, and still open, [#3795](https://github.com/kubernetes-sigs/kind/issues/3795); and [#4224](https://github.com/kubernetes-sigs/kind/issues/4224), which repeats the error on a Mac with an Apple processor and OrbStack and was resolved by importing with `ctr` without `--all-platforms`). The difference from what this lesson measured is the symptom: here there was **no error**, and the image reached the node **without a name** (`<none>`), so the pod does not find it. For that exact symptom: **measured, no official source.** Nor was it investigated why the local tag does leave the image with a name (untested hypothesis: the tag's image was pulled with only your platform's layers and the short name changes what `kind` exports). That is why the practical rule is to always check with `crictl images`, looking at the `<none>` rows too. (It is the most consequential warning for the next course: the convenient command fails silently, and the symptom, `ErrImageNeverPull`, shows up later, in the pod.)

### 10.12 The pinned base ages: renewing the *digest*

The finding from 10.10 is still pending: `ca-certificates`, version `20250419`, with a fix available in `20250419+deb13u1`. Where does that old version come from? From the image's **base**, `gcr.io/distroless/static-debian13:nonroot`, which since Lesson 5 has been pinned by *digest*: `@sha256:516757106de35…`. Pinning by *digest* gave you exactly what you were after, that the base does not change under your feet. And the other side of the same thing is that **the base does not receive fixes by itself either**. Docker's documentation says it in so many words: pinning to a *digest* means "opting out of automatic security fixes, which is probably something you want to receive", and that looking up and writing the new *digest* is "tedious"; it recommends automating the check, with Docker Scout (which reports whether your pinned base is no longer the current one) or with Dependabot (which opens scheduled pull requests to update tags and *digests*) ([Docker, "Building best practices"](https://docs.docker.com/build/building/best-practices/)).

What matters here is the procedure, which is short and can be done by hand: (1) ask the base's registry which *digest* the tag points to today; (2) change the *digest* in the `Dockerfile`; (3) rebuild; (4) scan again; (5) test again. Exercises 2 and 4 do it with measurements. A preview that is worth stating precisely, because it is easy to tangle up: what moved on the day of the runs was **the tag** `nonroot`, not your *digest*. At nine in the morning, Mexico City time, that tag already pointed to `sha256:d62067879de8…`, while the `Dockerfile` pins `sha256:516757106de3…`; and the pinned *digest* **still exists and still points to the same image as always** (Exercise 2 checks it by asking for it by its *digest*). That is what pinning promised: that the base does not change unless you decide it. The consequence is the other side of the same coin: the fixes that Debian publishes arrive only when you change the *digest*. This lesson's decision is to stay with the pinned base, because all the outputs you read were measured with it, and to present renewal for what it is, **a deliberate act** (Exercise 4 does it and measures that the scan goes down to 0 findings). The `1.6.0` image that the course delivers keeps its pinned base and its documented finding. In a real project, what you do is renew on purpose, with a new version.

There is a border that must not be crossed: **you do not renew for the sake of renewing.** A new base is a change: it can bring a different library, it can change the behavior of something. That is why the procedure ends with the `revisor`'s tests (which your `Dockerfile`'s `pruebas` stage already runs when building) and with running the image again. And it is done in a build with a **new version** (`1.6.1`), by the rule of 10.3: a published tag is not reused.

## The error you will see

This lesson has six messages worth recognizing, one per tool (two belong to the bridge to Kubernetes, the 1st and the 6th). All of them have already appeared; here they are gathered so that you can find them quickly.

**1. The pod that does not start: `ErrImageNeverPull`.** It is the one from `fig10_06.sh`:

```text
revisor   Pending   ErrImageNeverPull
Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
```

It reads from right to left like those of earlier lessons. "With pull policy of Never" says that the policy forbids downloading; "is not present" says that the node does not have the image. Together they mean: nobody loaded it. It is solved with `kind load docker-image <image> --name <cluster>`, checking that the name and tag are **exactly** those of the pod. If you load it and it still fails, it is usually a different tag: check with `kubectl get pod revisor -o custom-columns=IMAGEN:.spec.containers[0].image` which name the pod asks for (it is the same `IMAGEN` column you already used).

**2. Trivy that does not find the image.**

```text
unable to find the specified image "curso-docker-revisor:fig10" in ["docker" "containerd" "podman" "remote"]
```

It means it looked in those four places and did not find it. The fix is not to give it the Docker *socket*: it is to save the image with `docker save` and scan the file with `--input`.

**3. `docker save` with a platform you do not have.**

```text
Error response from daemon: no suitable export target found: image with reference … was found but does not provide the specified platform (linux/amd64)
```

The image exists in your store, but that platform was never downloaded. The fix: first pull that platform with `docker pull --platform linux/amd64 <reference>` and save again (block 11 of `fig10_04.sh` measured it: after the `pull`, the `save` answers `guardada: linux/amd64`).

**4. The emulated build that blows up.**

```text
fatal error: fault
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 2
```

It matches the emulation and not your code: the same `Dockerfile` compiles fine on the native processor and with cross-compilation. It is solved by avoiding emulation: cross-compilation with `--platform=$BUILDPLATFORM` in the compilation stages and `GOOS=$TARGETOS GOARCH=$TARGETARCH` in `go build`.

**5. The report's `500` with `read-only file system`.** It is Lesson 8's, which reappears with the image pulled by *digest*:

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

The image is fine and the read-only system works: a volume on `/datos` is missing.

**6. `kind load` that says "loading" and does not load.** It is the one from 10.11.6: when loading an image pulled from a registry by a reference with a *digest*, `kind` gives no error and does not leave on the node an image that the pod can find by that reference (it arrives nameless, as `<none>`), and the pod stays `Pending` with `ErrImageNeverPull`. It is solved by first giving it a local tag with `docker tag` and loading that tag; to check that it arrived, `docker exec <node> crictl images` must show the image with the name the pod asks for.

## The security habit of the lesson

This lesson installs four habits, and all four were practiced with measurements:

- **What is run is referenced by *digest*.** A tag moves and a *digest* does not; the accident it avoids is the one in the scene (two people with the "same" name and different contents) and the attack it makes harder is that of replacing in the registry an image that others already trust by name. Measured in 10.3.
- **What is published carries its bill of materials and its provenance, and the provenance is published clean.** `mode=max` exposes the values of build arguments, so no secret travels through `--build-arg`: it enters through `--mount=type=secret`. Measured in 10.7.
- **You scan without giving the Docker *socket* to anyone.** `docker save`, `--input`, folder mounted `:ro`. The accident it avoids is handing control of the daemon to a tool that downloads data from the internet. Measured in 10.10.
- **The scan has a written threshold and a database date.** A "zero" without a threshold and without a date is not a value. Measured in 10.10.4 and 10.10.6.

## Common mistakes

- **Reusing a published tag** ("it's the same version, I only fixed something"). It is the scene's mistake. Each build that is delivered carries a new tag; if something is corrected, it is `1.6.1`.
- **Publishing `latest`.** Kubernetes treats it differently (its default policy changes with that tag, and `kind`'s documentation asks not to use it with loaded images), and it does not say which version it is. The `latest` tag is not a version name: it is an arbitrary name that by convention moves.
- **Giving the Docker *socket* to Trivy** (or to any container) "so it can read the image". Whoever has the *socket* controls the daemon, and with it the machine. It is solved with `docker save` and `--input`.
- **Scanning once and forgetting.** The flaw database changes daily. A result is worth something with its date, and a delivery is scanned again before it is used.
- **Setting the threshold after seeing the result.** If the scan fails and you lower the threshold until it passes, the scan has stopped being useful. The threshold is written beforehand.
- **Ignoring a finding with no reason and no expiry date.** A `.trivyignore` with bare identifiers is a list of problems that someone decided to silence without leaving a why. Each line carries a comment with the reason and an `exp:` with the date on which the advisory expires (Exercise 3).
- **Pinning the base by *digest* and never looking at it again.** Pinning protects against unexpected changes, and also against expected fixes. Schedule a review (Docker Scout, Dependabot or a task of your own).
- **Passing secrets through `--build-arg` and publishing with `mode=max`.** The values end up written in the provenance that travels with the image. Build secrets enter through `--mount=type=secret`.
- **Building for another platform by emulation when you can cross-compile.** Slower, and on this machine it did not even work.
- **A registry on `0.0.0.0:5000` without TLS or authentication.** Anyone on your network can push or pull. It is published on `127.0.0.1`, or TLS and access control are added.
- **Sending an image over chat as a `.tar` file.** Whoever receives it does not know whose it is or what it carries. It is published to a registry and the *digest* is shared.
- **Taking "scanned" for "secure".** The scan checks what its databases know today in the packages it recognizes. It is a layer of review, not a guarantee.
- **Loading with `kind load` an image with the `latest` tag and expecting the pod not to download it.** With that tag the default policy is different. Write `imagePullPolicy` or use a version tag.

## Exercises

All four have their solution measured further below, with the script that produced it. Try each one before looking at it.

### Exercise 1 — Two tags, one *digest*

You have `1.6.0` published in your local registry. You want whoever asks for `1.6` (the 1.6 "line", without the last number) to receive **exactly the same image** as whoever asks for `1.6.0`, without rebuilding anything. Add the tag `1.6` to the already published image, check with the registry that there are now two tags, and show with `imagetools inspect` that both have the same *digest*. Hint: `docker buildx imagetools create -t <destination> <source>` creates a new tag from a reference that is already in the registry.

### Exercise 2 — What *digest* does the base have today?

Your `Dockerfile` pins the base `gcr.io/distroless/static-debian13:nonroot` by *digest*. Find out (a) the first twelve characters of the *digest* your `Dockerfile` carries and (b) those of the *digest* that same tag points to today in Google's registry. Decide in one sentence whether your base is up to date. Hint: `docker buildx imagetools inspect` also works for images from other registries.

### Exercise 3 — Accepting a finding in writing

Trivy reported `DSA-6572-1` (`UNKNOWN`) in `ca-certificates`. Suppose you cannot renew the base today. Write a `.trivyignore` file that accepts **that** finding, with a comment stating the reason and with an `exp:` that sets the expiry date, and show four things: without the file, Trivy exits with code 1; with the file, it exits with 0; if the file ignores a **different** identifier, it exits with 1 again (the file silences only what it says, not everything); and if the `exp:` has already passed, the finding comes back and Trivy exits with 1 once more.

### Exercise 4 — Renew the base and scan again

In your `Dockerfile`, change the base's *digest* to the one you found in Exercise 2 (b), rebuild the image, check that it still says `1.6.0` with `version`, save the image again with `docker save` and scan again **with all severities** and with `--exit-code 1`. What changed in the result? Write the answer in your logbook with the date: without the date, the result is of no use.

## Solutions

### Solution 1

It is the first part of `fig10_08.sh`. With `1.6.0` already pushed, `imagetools create` creates the new tag directly in the registry, from a reference that is already there. The result, as you will see, is another name for the same index.

```text
$ ./fig10_08.sh
== Ejercicio 1. Dos etiquetas, un digest
$ docker buildx imagetools create -t localhost:5000/curso-docker-revisor:1.6 localhost:5000/curso-docker-revisor:1.6.0 >/dev/null 2>&1 && echo 'etiqueta 1.6 creada'
etiqueta 1.6 creada
$ curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"name":"curso-docker-revisor","tags":["1.6","1.6.0"]}
$ for t in 1.6.0 1.6; do docker buildx imagetools inspect localhost:5000/curso-docker-revisor:$t --format '{{json .Manifest.Digest}}'; echo; done
"sha256:125ba52e53985a3e2e0b7618baf1edaa6c4b4e9a1afd93cd98459f245b433be8"
"sha256:125ba52e53985a3e2e0b7618baf1edaa6c4b4e9a1afd93cd98459f245b433be8"
```

It reads like this. `create -t …:1.6 …:1.6.0` says "create the tag `1.6` pointing to whatever `1.6.0` is today"; the `>/dev/null 2>&1` hides its progress output and the `&& echo` confirms that it finished well. The tag list now carries two, `1.6` and `1.6.0`. And the loop asks, for each tag, the index's *digest*: the two lines are **identical** (`125ba52e…`). Two names, one image. That is what is expected of a tag that follows the 1.6 line: a movable, readable name that, at this instant, points to the same thing as the fixed one. The counterpart, which you already know: `1.6` is a tag that **does** move (when you publish `1.6.1`, you would point it to that), so it is for humans and never for verifying.

### Solution 2

It is in `fig10_07.sh`. The first command extracts from the `Dockerfile` the first twelve characters of the *digest* it pins; the second asks Google's registry for the one behind the `nonroot` tag and trims the start:

```text
$ ./fig10_07.sh
== Ejercicio 2. ¿Qué digest tiene HOY la etiqueta nonroot de la base?
$ grep -oE 'static-debian13:nonroot@sha256:[0-9a-f]{12}' Dockerfile
static-debian13:nonroot@sha256:516757106de3
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot --format '{{json .Manifest.Digest}}' | cut -c2-20
sha256:d62067879de8
(y el digest que fija el Dockerfile, ¿sigue existiendo en el registro?)
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 --format '{{json .Manifest.Digest}}' | cut -c2-20
sha256:516757106de3
```

The `Dockerfile` pins `516757106de3…`; the registry says today `d62067879de8…`. **They do not match: the tag no longer points to what your `Dockerfile` pinned.** And the output's third line makes it clear: asking Google for the pinned *digest* (`…nonroot@sha256:516757106de3…`) answers with that same *digest*; it did not move or disappear. What changed is the tag's destination. The `grep -oE` with that pattern prints only what matches (`-o`) an extended regular expression (`-E`) that asks for the string `static-debian13:nonroot@sha256:` plus twelve hexadecimal characters. The `cut -c2-20` removes the opening quote of the JSON output and leaves the first 19 characters, that is `sha256:` plus twelve. That the tag changed destination does not say that the new one is better or that the old one is dangerous: it says that **there is something to look at**. It is the input for Exercise 4. (This measurement is from October 21; if you repeat it another day, you may get a different result, and that is normal: it is the reason it is measured.)

### Solution 3

Also in `fig10_07.sh`. The file, with its reason and its date, and the three runs:

```text
== Ejercicio 3. Aceptar el hallazgo por escrito, con razón y fecha
$ cat .trivyignore
# ca-certificates 20250419 en la base distroless fijada por digest.
# Debian ya lo corrigió (20250419+deb13u1); el arreglo llega al renovar el
# digest de la base (Ejercicio 4). Mientras tanto se acepta, por escrito.
# Revisado el 21-oct-2026. Borrar esta línea al renovar la base.
DSA-6572-1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
(el mismo archivo, con un identificador que NO es el del hallazgo)
$ sed -i.orig 's/^DSA-6572-1$/DSA-0000-1/' .trivyignore && tail -1 .trivyignore
DSA-0000-1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1

== Ejercicio 3 (continuación). La fecha que Trivy SÍ hace cumplir: exp:
$ sed -i.orig 's/^DSA-0000-1$/DSA-6572-1 exp:2026-11-21/' .trivyignore
$ tail -1 .trivyignore
DSA-6572-1 exp:2026-11-21
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
(la misma línea, con una fecha que ya pasó)
$ sed -i.orig 's/exp:2026-11-21/exp:2026-01-01/' .trivyignore
$ tail -1 .trivyignore
DSA-6572-1 exp:2026-01-01
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1
```

Read it in three beats. **Without** the file: the table counts 1 finding, there is `Total: 1` and the code is **1**. **With** `--ignorefile /trabajo/.trivyignore`: the table counts **0** for the base, there is no `Total` line anymore, and the code is **0**. And in the third run the script changed the file's identifier to a made-up one (`DSA-0000-1`): the real finding returns, `Total: 1`, code **1**. That is why the complete solution has the third run: it shows that the file is not a general switch but a list of specific identifiers. In the file's format, lines that start with `#` are comments and each identifier goes alone on its line ([Trivy, "Filtering"](https://trivy.dev/latest/docs/configuration/filtering/)). A comment with a date does not oblige anyone to look at the finding again; what does enforce a date is the `exp:` field that this same documentation shows in its examples (`CVE-2019-14697 exp:2023-01-01`). The second part of the solution, "continuación", measures it with this exercise's identifier: with `DSA-6572-1 exp:2026-11-21` (a future date) Trivy exits with code **0**; with `exp:2026-01-01` (a date already past) the finding **comes back** and the code is **1**. That is, the acceptance expires on its own. The `DSA-…` identifiers do not appear in the documentation's examples; the measurement shows that they work just like the `CVE-…` ones. The recommended practice is to combine both things: the comment with the reason and `exp:` with the review date. The `--ignorefile` option points to the file's path *inside the container* (`/trabajo/.trivyignore`, because `/trabajo` is your mounted folder), not to that of your machine; the command reference indicates that, by default, the option is `.trivyignore`, that is, a file with that name in the current folder. And the comment: it is not decoration. It is what lets someone two months from now, you included, know **why** that line is there and when it must be decided again.

### Solution 4

The second part of `fig10_08.sh`. It finds the tag's current *digest*, writes it into the `Dockerfile` with `sed`, rebuilds, checks the version, saves and scans:

```text
== Ejercicio 4. Renovar el digest de la base y volver a escanear
$ diff Dockerfile.viejo Dockerfile | cut -c1-120 | sed -E 's/sha256:([0-9a-f]{12})[0-9a-f]+/sha256:\1…/'; true
32c32
< FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de3…
---
> FROM gcr.io/distroless/static-debian13:nonroot@sha256:d62067879de8…
$ docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 . >/dev/null && docker run --rm curso-docker-revisor:fig10 version
1.6.0
$ docker save --platform linux/arm64 -o revisor-1.6.0.tar curso-docker-revisor:fig10 && du -h revisor-1.6.0.tar | cut -f1
3.6M
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
```

The `diff` shows that **only line 32 changes**, the final `FROM`'s, and only the *digest*. The build passes (and with it, the Go tests of the `pruebas` stage), `version` still says `1.6.0`, and the scan with **all severities** now gives **0 findings in the base and code 0**. That is: what the scanner saw in `ca-certificates` disappeared on renewing the base, without turning anything off or silencing any advisory. Two nuances for your logbook. One: **what was measured is the result, not the cause**: the new base's package list was not opened to check which version of `ca-certificates` it carries; the scan says there is no finding anymore, and the decision is made on that. Two: one platform was scanned, this machine's. For a real delivery, you would repeat the scan with the other one (block 11 of 10.9.2 leaves it saved). And the delivery would be published with **a new tag** (`1.6.1`), per the rule of 10.3, not on top of `1.6.0`.

## How I know I made it

Check each point with a command, not from memory:

1. **The registry listens only on `127.0.0.1`.** `docker port curso-docker-registro` answers `5000/tcp -> 127.0.0.1:5000` and nothing with `0.0.0.0`.
2. **The published image is a two-platform index.** `docker buildx imagetools inspect localhost:5000/curso-docker-revisor:1.6.0` shows `application/vnd.oci.image.index.v1+json` and entries `linux/amd64` and `linux/arm64`, plus two of type `attestation-manifest`.
3. **You can read its bill of materials and its provenance, and your Docker uses the *containerd* store.** `docker info -f '{{ .DriverStatus }}'` includes `io.containerd.snapshotter.v1`. With the templates of 10.6 and 10.7 you get the nine packages of the list and the `construida EN` line.
4. **You can show that a tag moves and a *digest* does not.** You repeat the measurement of 10.3 and see two different *digests* under the same tag.
5. **It runs by *digest*, on both platforms, and hardened.** On your `amd64` machine, `docker run --rm --platform linux/amd64 <reference> version` answers `1.6.0`.
6. **It runs hardened:** `docker run … --read-only --cap-drop ALL --security-opt no-new-privileges --init -v <volume>:/datos localhost:5000/curso-docker-revisor@sha256:…` answers `{"estado":"vivo","version":"1.6.0"}` at `/salud`, and `docker inspect --format '{{.Config.Image}}' <container>` shows a reference with `@sha256:`.
7. **The scan has a written threshold, an exit code and a date.** You run Trivy with `--input`, without the Docker *socket*, and keep next to the result the output of `trivy version` with the database's date.
8. **The pod starts without downloading anything.** `kubectl get events` shows `already present on machine` and `kubectl get pod revisor` says `Running` with `0` restarts.
9. **You left your machine clean.** Following the cleanup in the section "Course wrap-up", `docker ps -a`, `docker volume ls` and `kind get clusters` no longer show the registry, the helper containers, Trivy's cache or this lesson's cluster; only your image `curso-docker-revisor:1.6.0` remains, the one the next course will use.

## Summary

- A **tag** is a label that can be moved; a ***digest*** is a fingerprint of the content that does not move. You publish with a new tag per delivery and verify by *digest*.
- A tag points to an **index**; the index points to one manifest per platform and one attestation manifest per platform.
- To deliver to two processors without emulation you **cross-compile**: `--platform=$BUILDPLATFORM` in the compilation stages and `GOOS=$TARGETOS GOARCH=$TARGETARCH` in `go build`. On this machine emulation failed.
- `--sbom=true` adds the bill of materials (SPDX, written by Syft); `--provenance=mode=max` adds the full provenance, which **exposes the values of build arguments**; `mode=min` does not.
- Rebuilding "identically" does not guarantee the same *digest*: with cache the index's changed; without cache, that of each platform.
- Only the matching platform is pulled; `docker save --platform` fails if that platform was not pulled.
- Trivy is run **without the *socket***: `docker save` and `--input`, with the folder `:ro`. You set the threshold, `UNKNOWN` counts if you do not declare `--severity`, and without `--exit-code` Trivy exits with 0 even if it finds things.
- A finding with a fix is resolved by renewing the base or, in the meantime, accepted **in writing** in a `.trivyignore` with a reason and a date. Pinning by *digest* has the cost of renewing on purpose.
- `kind load docker-image` takes the image to the nodes; with `imagePullPolicy: Never`, the pod starts only if it arrived, and the `already present on machine` event proves it. With an image pulled from a registry, load it through a **local tag**: with a reference with a *digest* `kind` gives no error and does not leave on the node an image that the pod can find by that reference.
- The other platform's binary is verified by running it: `docker run --rm --platform linux/amd64 <reference> version` (here it ran emulated; on your `amd64`, natively).

## Course wrap-up: how you know you are done

The course README promises that it does not end when you read lesson 10 but when your project meets six things. With this lesson, all six have a way to be checked, and each was measured in the lesson that installs it:

1. **`docker compose up` starts everything from scratch** and the report shows the test service as down, `FALLA` (Lesson 9).
2. **The final image weighs tens of megabytes** —16.2 MB in the runs of Lessons 8 to 10—, with no shell or compiler, and does not run as `root` (Lessons 5 and 8).
3. **No secret appears** in `docker history`, in `docker inspect` or in the environment (Lesson 6).
4. **`docker stop` finishes in a few seconds** (in Lessons 3, 5, 7 and 9 between 137 and 321 milliseconds were measured with the *exec* form) and `docker ps` tells `(healthy)` from `(unhealthy)` (Lesson 7).
5. **The report survives `docker rm`** and the `revisor` finds the other container by its name (Lesson 8).
6. **The published image is referenced by *digest*, passes the scan with the threshold you set** and is loaded into a `kind` cluster **without a single download error** (this lesson).

There is a sentence worth stating precisely, because it is easy to exaggerate: your image leaves this course **with its scan reviewed**, not "secure" or "approved". It has a written threshold, a database date and a known finding, with its reason and the path to resolve it. That is what working with rigor means: not that there are no findings, but that you know which ones there are, from when they date and what you are going to do about them. The [Kubernetes course with kind](https://www.habil.mx/en/courses/kubernetes/) picks up from here: the image `curso-docker-revisor:1.6.0`, with the `kind load docker-image` bridge you have already walked.

Before closing the logbook, shut down and delete what you started in this lesson and that is yours, with the names you gave it, one by one (without `docker system prune` or `docker volume prune`, which would take away what belongs to others). First look at what there is with `docker ps -a`, `docker images` and `docker volume ls`, and delete only what you recognize:

```bash
docker rm -f -v curso-docker-registro curso-docker-revisor   # el registro (con su volumen anónimo) y el contenedor de 10.9
docker images --digests --format '{{.Repository}}@{{.Digest}}' | grep '^localhost:5000/curso-docker-revisor@' | xargs -r docker rmi   # lo traído por digest
docker volume rm curso-docker-trivy-cache   # la caché de Trivy de 10.10
kind delete cluster --name curso-docker-puente
```

(The volume `curso-docker-reportes` is **not** deleted here: it is Lesson 8's, it stores the reports you already generated and is cleaned up, if you want, when closing that lesson. Your local image `curso-docker-revisor:1.6.0`, the one you build in 10.11.3, stays: the next course uses it. The `rmi` above deletes by name the copies pulled by *digest*, never by identifier.)

## Sources

All were consulted on October 21, 2026.

- Docker, "Build attestations" (SBOM and provenance): <https://docs.docker.com/build/metadata/attestations/>
- Docker, "SLSA provenance" (`min` and `max` modes): <https://docs.docker.com/build/metadata/attestations/slsa-provenance/>
- Docker, "Multi-platform builds": <https://docs.docker.com/build/building/multi-platform/>
- Docker, `docker buildx imagetools inspect`: <https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/>
- Docker, `docker image save`: <https://docs.docker.com/reference/cli/docker/image/save/>
- Docker, `dockerd` reference (local registries marked as insecure): <https://docs.docker.com/reference/cli/dockerd/>
- Docker, "containerd image store": <https://docs.docker.com/engine/storage/containerd/>
- Docker, "Building best practices" (base pinned by *digest*): <https://docs.docker.com/build/building/best-practices/>
- Docker, Docker Engine 29 release notes (29.2.1 of February 2, 2026, with BuildKit v0.27.1): <https://docs.docker.com/engine/release-notes/29/>
- Distribution (registry), "Deploy a registry server": <https://distribution.github.io/distribution/about/deploying/>
- Distribution, 3.1.2 release notes: <https://github.com/distribution/distribution/releases/tag/v3.1.2>
- Open Container Initiative, "Distribution Specification": <https://github.com/opencontainers/distribution-spec/blob/main/spec.md>
- Open Container Initiative, "Image Index": <https://github.com/opencontainers/image-spec/blob/main/image-index.md>
- Trivy, "Container Image" (`--input`, source order): <https://trivy.dev/latest/docs/target/container_image/>
- Trivy, "Filtering" (`--severity`, `--ignore-unfixed`, `.trivyignore`): <https://trivy.dev/latest/docs/configuration/filtering/>
- Trivy, "Vulnerability" (when `UNKNOWN` is used): <https://trivy.dev/latest/docs/scanner/vulnerability/>
- Trivy, "Reporting" (table and levels): <https://trivy.dev/latest/docs/configuration/reporting/>
- Trivy, `trivy image` reference (`--exit-code`, `--input`, `--ignorefile`): <https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/>
- Trivy, 0.76.0 release notes (October 14, 2026): <https://github.com/aquasecurity/trivy/releases/tag/v0.76.0>
- kind, "Quick Start" (`kind load docker-image`): <https://kind.sigs.k8s.io/docs/user/quick-start/>
- kind, 0.33.0 release notes (node `kindest/node:v1.37.0`): <https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0>
- Kubernetes, "Install and Set Up kubectl on Linux": <https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/>
- Kubernetes, "Images" (`imagePullPolicy`, *digests*, `:latest`): <https://kubernetes.io/docs/concepts/containers/images/>
- SPDX, "Overview": <https://spdx.dev/about/overview/>
- SLSA, "Provenance" (v1.0): <https://slsa.dev/spec/v1.0/provenance>
- Codecov, "Bash Uploader Security Update" (the checksum case): <https://about.codecov.io/security-update/>

### Terms in this lesson

- **Registry**: a service that stores images and hands them out through a standard HTTP API.
- **Repository**: the name of an image inside a registry; it stores all its versions.
- **Reference**: the text that points to an image: registry, repository and tag or *digest*.
- **Tag**: a readable, movable name for a version of an image.
- ***Digest***: a `sha256:` fingerprint of the content of a manifest or a blob; it does not change.
- **Manifest**: a JSON document that lists an image's layers and configuration.
- **Index** (*image index*): a manifest that points to several manifests, one per platform, and to the attestations.
- **Platform**: operating system plus processor architecture, such as `linux/arm64`.
- **Emulation (QEMU)**: pretending to be another processor in software; slow and, on this machine, unstable.
- **Cross-compilation**: compiling on one processor a binary for another, without running anything foreign.
- **Attestation**: a document about an image that travels in its index; here, the SBOM and the provenance.
- **SBOM**: software bill of materials; what the image carries inside.
- **SPDX**: an open standard for bills of materials.
- **Provenance**: how, where and with what the image was built.
- **SLSA**: a framework and format for describing provenance.
- **Vulnerability**: a public security flaw, with an identifier (CVE, DSA…) and a severity.
- **Threshold**: the minimum severity that counts as a finding in your scan.
- **Exit code**: a number a program returns when it finishes; 0 is success.
- **`.trivyignore`**: a file with the identifiers of findings you accept.
- **`kind load docker-image`**: copies an image from the local Docker to the nodes of a `kind` cluster.
- **`imagePullPolicy: Never`**: a Kubernetes policy that forbids downloading the image.
