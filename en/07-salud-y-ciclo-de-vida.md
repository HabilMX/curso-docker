# Lesson 7 — Health checks and lifecycle

It is 11:15 on a Friday night and the maintenance window closes at 11:30. The plan is simple: update the server where the `revisor` and nineteen other containers run, reboot it, and go home. Someone stops them one by one, with a `for … docker stop` loop, and the terminal hangs. Ten seconds. Another ten. Another ten. Three minutes later it finishes, and almost all of them ended up marked `Exited (137)`, which means "they killed it". The server comes back up at 11:24 and everything says `Up`. At 11:26 the monitoring dashboard is still red: one of the services is "up" but answers `503` to everything, and the container that depended on it keeps restarting, a little later each time. Nobody knows whether the containers that died with 137 managed to save what they were writing. Four minutes are left and the question is the usual one: what is running, what is healthy, and what is faking it? This lesson exists so you can answer it in seconds: a container that says how it is doing, that dies in an orderly way when you ask it to, and that, while it lives, cannot do more than it needs to.

**Time:** 2 × 45 min

**What you build:** a container that says how it is doing and dies well. The image `curso-docker-revisor:1.4.0` carries its own health check (`HEALTHCHECK`), built with the same binary and without `curl`, and declares its shutdown signal (`STOPSIGNAL`). And the container runs hardened: read-only file system, no `root` capabilities at all, unable to gain new privileges, with a tiny *init* as process number 1, with limits and with a restart policy. Lesson 9 carries those options over to Compose.

**What you learn:** what a signal is, why a container's process number 1 is special, and how to read the codes `0`, `1`, `137`, and `143`; the `docker stop` timeout and how to change it; what `--init` does and what a zombie is; `HEALTHCHECK` without `curl` and the difference between "running" and "healthy"; the four restart policies and what they **do not** do; `--read-only` with a `tmpfs` where one is needed; `--cap-drop ALL`; and `no-new-privileges`, with a *setuid* program that demonstrates it.

**Where you are coming from.** From [Lesson 6](06-configuracion-y-secretos.md) you bring the image `curso-docker-revisor:1.3.0`: multi-stage, 16.1 MB, without a *shell*, with user `65532`, its version stamped in, and nothing specific to any environment. From [Lesson 3](03-primer-dockerfile.md) you bring a measurement you will not forget: with `CMD` in *shell* form, `docker stop` took more than ten seconds and the container died with `137`, because the signal never reached the `revisor`. From [Lesson 2](02-contenedores-dia-a-dia.md) you bring the `(health: starting)` you saw in the test service without yet knowing where it came from, and the habit of setting memory, CPU, and process limits. And from [Lesson 0](00-que-es-un-contenedor.md) you bring the central idea: a container is a process on your machine, with the same kernel, and the `root` inside has fourteen capabilities that today you are going to take away.

**What this lesson does not do.** It does not explain mounts in depth: the `tmpfs` in section 7.7 is used here for a single folder, and [Lesson 8](08-volumenes-y-redes.md) explains volumes, *bind mounts*, and `tmpfs` in full. It does not use health to order the startup of several services (`depends_on` with `service_healthy`): that is [Lesson 9](09-compose.md). It does not touch *seccomp* or AppArmor profiles, or rootless Docker: those are layers Docker already applies by default or that require a different installation, and this course sticks to the options anyone can write in a `docker run`. And it does not restart the Docker daemon to test `unless-stopped` against `always`: that would shut down every container on the machine, and the difference is explained by the documentation.

**About the runs.** All the outputs are real and were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a virtual machine with Ubuntu 24.04.4, the same base as Linux Mint 22, the course's reference system, with kernel 6.8 and an `arm64` processor. The scripts were run **inside** that virtual machine, with Docker 29.2.1 (client and daemon), and with their working folder on Linux's own disk. To avoid colliding with other runs that used the same machine, the scripts were launched with a different name prefix and different ports (the `PREFIJO` and `PUERTO` variables they come with); no container or image name, nor the machine's port, appears in their outputs, so what you see is exactly what they printed. With their default values, the scripts use their own helper names containing `fig07` (the image `curso-docker-revisor:fig07`, the container `curso-docker-revisor-fig07`): that way they never touch your image `curso-docker-revisor:1.4.0` or your container `curso-docker-revisor`, and on exit they delete only what they created. The course was planned with Docker Engine 29.8.2, and the most recent version published that day was 29.9.2, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)); nothing in this lesson changes between those versions. What **does** change from one run to another, and is flagged where it appears: process numbers (masked with `<pid>` in the script itself; the scripts that use them stop if the container is not running, because a `0` would point to processes on your machine), the milliseconds of each `docker stop` and each restart, the seconds of `Up`, and the number of the report's temporary file (masked with `<n>`). The virtual machine was shared with other jobs, and in some runs it was loaded: that is why some timings came out longer than others, and where it matters it is said. The scripts publish on ports 8080 (`fig07_03.sh` and `fig07_06.sh`) and 9000 (`fig07_04.sh`) of your machine: if your `curso-docker-revisor` or your `curso-docker-prueba` are running, delete them first or launch the script with another port, for example `PUERTO=18080 ./fig07_03.sh`; otherwise the script stops with `port is already allocated`. One script, `fig07_05.sh`, uses `sudo` once, to kill a process from outside the way the kernel would; on your Mint it will ask for your password. The programs are in [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida), each with its output beside it, and `estado/` keeps the project's files as they stand at the end.

## By the end you will be able to

- Read a container's exit code (`0`, `1`, `137`, `143`) and say which signal ended it or whether it ended on its own.
- Explain why a program that dies with `SIGTERM` in your terminal ignores the same signal when it is process number 1 of a container, and fix it with `--init`.
- Measure how long `docker stop` takes and change its timeout and its signal with `-t`, `--stop-timeout`, `STOPSIGNAL`, and `--stop-signal`.
- Write a `HEALTHCHECK` in *exec* form for an image without a *shell* or `curl`, and read a container's health with `docker ps` and `docker inspect`.
- Choose a restart policy for a service and predict what Docker does when the process dies on its own, when you stop it yourself, and when it is `unhealthy`.
- Run the `revisor` with `--read-only`, `--cap-drop ALL`, and `--security-opt no-new-privileges`, and check in `/proc` that the kernel applies all three.

## The why before the how

Until now you have treated the container as something that starts. This lesson deals with everything else: how it **dies**, how it says **whether it is fine** while it lives, and **what it can do** in the meantime. They are three different questions, and all three appeared in the opening scene.

The first is shutdown. A container is not shut down like a machine: Docker sends a **signal** to its main process and waits. If the process handles the signal, it finishes what it was doing and exits; if not, when the timeout expires Docker kills it. You already saw it in Lesson 3 with the *shell* form. What is new is that writing the `CMD` correctly is not enough: there are programs that, being process number 1, do not receive the signal even when they are in *exec* form, and the lesson shows you one, measures what it costs, and fixes it.

The second is health. To Docker, a container is `Up` as long as its process exists. It does not know whether that process answers, whether it answers correctly, or whether it got stuck waiting for something that will never arrive. The course README puts it as one of its two principles: **a "running" container is not a healthy service**. A health check is the way for the container, from the inside, to tell Docker the difference. And the `revisor` image has no `curl` and no *shell*, so the check has to come from somewhere else.

The third is power. A container that works well can still be the entry point of an attack: if someone finds a flaw in the program, they inherit everything the process can do. Lessons 3 and 5 already took away `root` and the *shell*. Here three more things are taken away: the ability to write to its own file system, the `root` capabilities it does not use, and the ability to gain new privileges when executing another program.

With that destination in mind, here is what you will see in section 7.10, when the three answers come together. The `revisor` runs with everything in the lesson, the kernel confirms that it has no capabilities and cannot gain privileges, and even so it shuts down in an orderly way in a couple of tenths of a second:

```text
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
```

## The concepts

### 7.1 Process number 1 and signals

#### 7.1.1 What a signal is

A **signal** is a short notice that the Linux kernel delivers to a process. It carries no data: only a number, which says what happened or what is being asked. When you press `Ctrl+C` in the terminal, the kernel sends the program the `SIGINT` signal; when an administrator types `kill <pid>`, it sends `SIGTERM`. The Linux manual lists them with their number and their **default action**, which is what happens if the program did nothing special to handle them ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)):

| Signal | Number | What it asks | Default action |
|---|---|---|---|
| `SIGINT` | 2 | interrupt from the keyboard (`Ctrl+C`) | terminate |
| `SIGKILL` | 9 | die, now | terminate; **cannot be caught, blocked, or ignored** |
| `SIGTERM` | 15 | terminate, please | terminate |

A program can **install a handler** for a signal: a function that runs when the signal arrives, instead of the default action. That is what the `revisor` does: it asks the kernel to notify it of `SIGTERM` and `SIGINT`, and when one arrives it stops accepting new requests, waits up to five seconds for the ones in progress to finish, and exits with code 0. It is what you have been seeing in its logs since Lesson 3: `recibí terminated, apagando` and `apagado limpio`. For `SIGKILL` no handler is possible; the manual says so in so many words: "`SIGKILL` and `SIGSTOP` cannot be caught, blocked, or ignored".

#### 7.1.2 How to read the end of a container

When a process ends, it leaves an **exit code**. If it ended on its own, it is the number the program chose: `0` for "all good", anything else for "something failed" (the `revisor` uses `1` when configuration is missing). If a signal ended it, the convention of *shells*, which Docker follows, is **128 plus the signal number**. That gives the two numbers you will see most:

| Code | How to read it |
|---|---|
| `0` | ended on its own and well; with the `revisor`, after an orderly shutdown |
| `1` | ended on its own, with an error from the program itself |
| `137` | 128 + 9: `SIGKILL` killed it; nobody asked it |
| `143` | 128 + 15: `SIGTERM` ended it with the default action, without a handler |

Notice the difference between `0` and `143`. Both are shutdowns requested with `SIGTERM`; in the first, the program handled the signal and exited on its own; in the second, the kernel ended it because the program had no handler. Both are reasonable. The one that should worry you is `137` in a normal shutdown: it means the timeout ran out and Docker had to kill.

#### 7.1.3 Why number 1 is special

In Lesson 0 you saw that inside a container the main program is process number 1. That number gets special treatment in Linux, which the manual for process namespaces describes this way: to the "*init*" process of a namespace, only the signals **for which it has established a handler** can be sent; the others do nothing to it. And there is one exception: `SIGKILL` and `SIGSTOP` "are forcibly delivered when they come from an ancestor namespace" ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). The `docker run` reference sums it up in one sentence: a process running as PID 1 "ignores any signal whose action is the default one" ([`docker run` reference](https://docs.docker.com/reference/cli/docker/container/run/)).

Read it slowly, because it is the heart of this section. A program that has **not** installed a handler for `SIGTERM` dies from it in your terminal, because the default action is to terminate. The same program, being number 1 in a container, does **not** die: the default action no longer applies. The protection makes sense for a machine's *init*, which should never die by accident; in a container, the *init* is your program, and that protection becomes a problem.

#### 7.1.4 Measuring it with a program that does not know how to shut down

The `revisor` does install its handler, so it is no use for seeing the problem. To see it you need a program that does not, and there is one in every Debian image: `sleep`, which just waits the seconds you ask for. The script `fig07_02.sh` builds nothing; it uses the Go image you have had since Lesson 3:

```bash
#!/usr/bin/env bash
# fig07_02.sh — El proceso número 1 y las señales, con un programa que NO sabe
# apagarse: sleep. Mide cuánto tarda docker stop, con qué código muere el
# contenedor, qué cambia con -t y con --init, y quién recoge a los zombis.
# No construye nada: usa la imagen de Go que ya bajaste para el revisor.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor
# ni tu imagen curso-docker-revisor:1.4.0, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}fig07-sleep"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
# detener [opciones de docker stop]: detiene el contenedor, mide y dice cómo murió
detener() {
  local inicio fin
  inicio=$(t); docker stop "$@" "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop${*:+ $*} tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
  docker rm -f "$NOMBRE" >/dev/null
}

echo "== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
PID1=$(pid_de "$NOMBRE")
grep -E '^SigCgt' "/proc/$PID1/status"
detener

echo
echo "== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
detener -t 2

echo
echo "== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM"
sleep 300 & HIJO=$!
kill -TERM "$HIJO"; rc=0; wait "$HIJO" || rc=$?
echo "sleep en el equipo murió con código $rc"

echo
echo "== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep"
docker run -d --init --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
detener

echo
echo "== 5. Zombis: un hijo huérfano termina y nadie lo recoge"
# El subshell lanza «sleep 1» y se va; ese sleep queda huérfano y el núcleo se
# lo entrega al proceso 1. Después, exec convierte al shell en «sleep 300».
docker run -d --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- docker top:"
docker top "$NOMBRE" -o pid,stat,args | sed -E 's/^ *[0-9]+ /<pid> /'
echo "-- ps en el equipo, hijos del proceso 1 del contenedor:"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 6. Lo mismo con --init: el init recoge al huérfano"
docker run -d --init --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
```

```text
$ ./fig07_02.sh
== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM
PID                 PPID                COMMAND
<pid> <ppid>             sleep 300
SigCgt:	0000000000000000
docker stop tardó 11315 ms; ExitCode=137

== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)
docker stop -t 2 tardó 2707 ms; ExitCode=137

== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM
sleep en el equipo murió con código 143

== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep
PID                 PPID                COMMAND
<pid> <ppid>             /sbin/docker-init -- sleep 300
<pid> <ppid>             sleep 300
docker stop tardó 251 ms; ExitCode=143

== 5. Zombis: un hijo huérfano termina y nadie lo recoge
-- docker top:
PID                 STAT                COMMAND
<pid>             Ss                  sleep 300
-- ps en el equipo, hijos del proceso 1 del contenedor:
STAT COMMAND
Z    [sleep] <defunct>

== 6. Lo mismo con --init: el init recoge al huérfano
-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):
STAT COMMAND
S    sleep 300
```

There are new lines in the script. The function `detener` measures how long `docker stop` takes and reads the exit code with `docker inspect`, as you did in Lesson 3. The `sed` that follows `docker top` masks the process numbers with `<pid>` and `<ppid>`, because they change on every run. And the `grep` in block 1 reads a file that does not belong to the container but to the kernel: `/proc/<number>/status`, a process's state as seen from your machine. `docker inspect --format '{{.State.Pid}}'` gives the number that process has **on your machine**, which is not 1; 1 is the number it has inside.

Now blocks 1 to 3; the rest are read in 7.3.

1. **`sleep` is number 1 and handles nothing.** `docker top` shows a single process, `sleep 300`. The `SigCgt` line says which signals the process has **caught**, that is, for which ones it installed a handler, as a bit mask in hexadecimal: each set bit is a signal. All zeros: none. And `docker stop` took **11,315 ms** and left `ExitCode=137` (in a run with the machine less loaded, 10,097 ms: the timeout is 10,000, and the rest is Docker and the machine's load). The sequence is the one from Lesson 3: `SIGTERM` to number 1, which ignores it because it has no handler; ten seconds of waiting; `SIGKILL`, which arrives by force.
2. **The timeout can be changed.** With `docker stop -t 2`, the same `sleep` died in **2,707 ms**, also with `137` (2,124 in the less loaded run). The timeout changed; the ending did not. Shortening the timeout fixes nothing: it just makes them kill sooner.
3. **Outside the container, the same program does die.** The script launches `sleep 300` on your own machine, sends it `SIGTERM` with `kill`, and reads its code: `143`, which is 128 + 15. Same program, same signal, no handler: on your machine `sleep` is an ordinary process and the default action applies; in the container it was number 1 and it did not.

Compare this block 1 with the *shell* form from Lesson 3. There, number 1 was `/bin/sh` and the `revisor` was underneath; here there is no *shell* in between, the `CMD` is *exec*, and the same thing still happens. The *exec* form makes Docker launch your program directly, without a *shell* in the middle, and that is why it ends up as number 1; it does **not** guarantee that your program knows how to behave as such.

> [!NOTE]
> 🔧 **Engineering observation 7.1**
> Many programs do not install handlers because on a normal machine they do not need to: the default action of `SIGTERM` already ends them. *Shell* scripts, command-line tools, servers written in a hurry. When you put them in a container as number 1, every `docker stop` costs them the full timeout. Before deciding anything, look at your process's `SigCgt` line: if the `SIGTERM` bit (the value `4000` in hexadecimal) is off, that program needs help.

### 7.2 The `docker stop` timeout, and who decides the signal

#### 7.2.1 What `docker stop` does, step by step

The documentation describes it this way: the container's main process "receives `SIGTERM` and, after a grace period, `SIGKILL`". If the container has no other signal configured, `SIGTERM` is used. The timeout "is determined by the daemon" and is **10 seconds** for Linux containers (30 for Windows ones); with `-t` or `--timeout` you change it for that call, and with `-t -1` Docker waits forever ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

There are three places where the behavior can be changed, and it is worth knowing which one wins:

| Where | What it changes | Scope |
|---|---|---|
| `STOPSIGNAL` in the Dockerfile | the signal `docker stop` sends | all containers from that image |
| `docker run --stop-signal` | the signal, for that container | wins over the image's |
| `docker run --stop-timeout` | the timeout, for that container | stored in the container |
| `docker stop -t N` / `-s SIGNAL` | timeout and signal, for that call | wins over everything above |

The Dockerfile reference specifies that `STOPSIGNAL` only applies to the signals Docker sends (`docker stop` and the daemon itself); a `Ctrl+C` in a terminal attached to the container still sends `SIGINT` straight to the process ([Dockerfile reference](https://docs.docker.com/reference/dockerfile/)). If you pass neither `--stop-signal` when running nor `-s` when stopping, Docker uses the image's `STOPSIGNAL`, and if the image declares none, `SIGTERM` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

And there is `docker kill`, which does not wait: it sends a signal and that is it. Without `-s`, the signal is `SIGKILL` ([`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/)). It is used when something is hung and there is nothing to save; it is not the normal way to shut down.

#### 7.2.2 `STOPSIGNAL` in the `revisor`

This lesson's Dockerfile declares `STOPSIGNAL SIGTERM`. It is the default signal, so it does not change the behavior; the Dockerfile's comment says so: writing it documents the intent. Whoever reads the image, or inspects it with `docker image inspect --format '{{.Config.StopSignal}}'`, knows which signal the program expects without opening its code. Some programs expect another (some web servers do a graceful shutdown with `SIGQUIT` and an abrupt one with `SIGTERM`); there `STOPSIGNAL` stops being documentation and becomes necessary.

#### 7.2.3 Why the `revisor` waits five seconds and not ten

The `revisor`'s code has a constant, `PlazoApagado`, of five seconds: it is how long it waits for requests in progress before giving up. Its comment explains the number: it is less than the ten of `docker stop` "so that the process ends on its own and does not get killed". It is the rule worth following with any service: **your internal shutdown timeout has to fit inside the timeout of whoever shuts you down**. If your program needs twenty seconds to drain a queue, raise the container's timeout with `--stop-timeout 30`; do not expect Docker to guess.

### 7.3 `--init`: a tiny *init* for number 1

#### 7.3.1 What it does

If the program does not know how to be number 1, the clean way out is not to make it number 1. `docker run --init` first starts a small program, `docker-init`, which becomes number 1 and starts your program as its child. The `docker run` reference says that an *init* process ensures that "the usual responsibilities of an *init* system, such as reaping zombie processes, are performed inside the container", and that this `docker-init`, included in the standard installation, is built with [tini](https://github.com/krallin/tini). The tini project itself describes itself as a minimal *init* that starts a single child and waits for it to exit "reaping zombies and performing signal forwarding in the meantime", and notes that since Docker 1.13 it comes included in Docker, with nothing to install in the image.

Those are two jobs, and blocks 4 to 6 of `fig07_02.sh` show both.

#### 7.3.2 The first job: forwarding signals

Block 4 runs the same `sleep 300` with `--init`. `docker top` now shows two processes: `/sbin/docker-init -- sleep 300` and, beneath it, `sleep 300`. Number 1 is `docker-init`, which does have handlers for signals; when `docker stop` sends it `SIGTERM`, it forwards it to its child. To the child, `SIGTERM` is an ordinary signal, because it is **not** number 1, so the default action applies and it dies. `docker-init` sees its child die and exits with the same code. Result: **251 ms** instead of 11,315 (88 ms in the less loaded run), and `ExitCode=143`, the same 128 + 15 you got in your terminal in block 3. Without changing a line of the program.

#### 7.3.3 The second job: reaping zombies

When a process ends, it does not disappear entirely: a row stays in the process table with its exit code, waiting for its parent to read it. As long as nobody reads it, that process is a **zombie**: it does not run, it uses no memory, but it occupies a process number. If the parent dies before the child, the kernel assigns the orphan a new parent: the *init* of its namespace. So, inside a container, all orphans end up as children of number 1, and number 1 has to reap them.

Block 5 triggers it. The container runs `sh -c '(sleep 1 &); exec sleep 300'`: a *subshell* launches `sleep 1` in the background and leaves, so that `sleep 1` is orphaned and becomes a child of number 1; then `exec` replaces the *shell* with `sleep 300`, which becomes number 1. A second later the orphan ends, and its new parent, `sleep 300`, has no idea it must reap it. Look at the block's two views:

- **`docker top` does not show it.** Only `sleep 300` appears. `docker top` asks for the processes that belong to the container's control group, and a process that has already ended leaves that group even though its row is still in the table. It is a measurement worth remembering: if you are looking for zombies, `docker top` is not the tool.
- **`ps` on your machine does show it.** With `--ppid` you ask for the children of the container's number 1, and `Z    [sleep] <defunct>` appears: state `Z`, for zombie, and the word `defunct`.

Block 6 repeats the same with `--init`. Now the orphan is assigned to `docker-init`, which does know how to reap children. The children of number 1 are only the *shell* turned into `sleep 300`; of the zombie, nothing.

A zombie does no harm; thousands do. Each one occupies a process number, and in Lesson 2 you gave the container `--pids-limit 50`. A program that launches helper processes and does not reap them ends up, over time, unable to launch any more.

#### 7.3.4 And the `revisor`? It needs it less than it seems

Let us be precise, because it is easy to exaggerate here. The `revisor` installs its handler for `SIGTERM` (you will see it shut down in under a second without `--init` in section 7.4) and launches no child processes, so it leaves no zombies. Today it **does not need** `--init`. The course uses it anyway, for two reasons. The first: it costs almost nothing (one more tiny process, and four letters). The second: the day someone changes the program, or wraps it in a startup script, or adds a tool that launches processes, the image still shuts down well without anyone having to remember this lesson. It is cheap insurance, and that is why it goes in the hardened options that Lesson 9 copies to Compose.

### 7.4 `HEALTHCHECK` without `curl`

#### 7.4.1 The instruction

`HEALTHCHECK` tells Docker how to ask a container whether it is fine. Docker runs that command **inside** the container every so often and looks at its exit code. The Dockerfile reference defines three values: `0` is success ("the container is healthy and ready for use"), `1` is "unhealthy", and `2` is reserved: do not use it. The options, with their default values according to the same reference ([Dockerfile reference](https://docs.docker.com/reference/dockerfile/)):

| Option | What it is | Default | In the `revisor` |
|---|---|---|---|
| `--interval` | how often it is checked | `30s` | `10s` |
| `--timeout` | how long a check can take before counting as a failure | `30s` | `3s` |
| `--start-period` | startup time: failures here do not count | `0s` | `5s` |
| `--start-interval` | how often it is checked **during** the startup period | `5s` | (the default) |
| `--retries` | how many consecutive failures it takes to declare it unhealthy | `3` | `3` |

A Dockerfile can have only **one** `HEALTHCHECK`; if you write several, the last one applies. `HEALTHCHECK NONE` turns off the one inherited from its base image. Whatever the command writes to its output is stored alongside the result, and is read with `docker inspect`; only the first 4,096 bytes are kept.

With those options, the container goes through three health states: `starting` while there is no response that counts, `healthy` as soon as a check exits with `0`, and `unhealthy` when as many consecutive failures pile up as `--retries` says. Any success resets the streak of failures to zero.

#### 7.4.2 This lesson's Dockerfile

It is Lesson 6's with two new instructions at the end:

```dockerfile
# syntax=docker/dockerfile:1
# fig07_01.Dockerfile — Lección 7: la imagen dice cómo está (HEALTHCHECK) y muere bien.
# Parte de la de la Lección 6; lo nuevo está al final.

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
# La salud la revisa el propio binario: la imagen no tiene shell ni curl.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/revisor", "healthcheck"]
# Señal de apagado explícita (es la de omisión; escribirla documenta la intención).
STOPSIGNAL SIGTERM
ENTRYPOINT ["/revisor"]
```

What changed:

1. **`HEALTHCHECK ... CMD ["/revisor", "healthcheck"]`.** The check is done by the binary itself: the `revisor`'s `healthcheck` subcommand asks its own process for `GET /salud` on `127.0.0.1`, with a two-second limit; if it answers `200`, it prints `sano` and exits with `0`; if not, it prints `no sano: …` and exits with `1`. It is in *exec* form, with brackets, like the `ENTRYPOINT`: for the same reason as in Lesson 3, and for one more that you will see in a moment.
2. **The timings.** `--interval=10s` because the `revisor` does not need to be watched every five seconds, and thirty (the default) is too long to notice a problem. `--timeout=3s` leaves slack over the two seconds the subcommand itself allows. `--start-period=5s` gives it time to start, and during that time Docker asks every five seconds (`--start-interval`), so the first answer arrives quickly. `--retries=3` asks for three consecutive failures before declaring it unhealthy: one stumble is not enough.
3. **`STOPSIGNAL SIGTERM`**, which you saw in 7.2.2.

#### 7.4.3 Why not `curl`

The most common way to write a health check, the one you will find in almost every tutorial, is `HEALTHCHECK CMD curl -f http://localhost:8080/salud || exit 1`. It has two problems in the `revisor`'s image, and this section's script triggers them. The first is obvious: the image has no `curl`. The second is subtler: that line is in *shell* form, and *shell* form needs `/bin/sh`, which is not there either. The same happens with `docker run --health-cmd`, which is the way to set or change the check at run time: whatever you write there Docker runs with the *shell*.

The easy way out would be to add `curl` to the image. It is not a good idea: it is megabytes of a network tool, with its own history of vulnerabilities, put into the image that in Lesson 5 you left with nothing that was not needed, just to ask a question the program already knows how to ask. The good way out is the one the `revisor` has: a subcommand of the same binary. Zero extra bytes, and the check asks exactly what the program knows about itself. The test service does the same with its `servicio-prueba healthcheck`, and that is why since Lesson 2 it has health without having `curl`.

#### 7.4.4 Watching it fail and watching it work

The script `fig07_03.sh` builds the image, first tries to watch it with `curl`, and then runs it with its own check:

```bash
#!/usr/bin/env bash
# fig07_03.sh — HEALTHCHECK sin curl. Construye el revisor con fig07_01.Dockerfile,
# provoca primero el error de vigilarlo con curl (la imagen no tiene ni shell ni
# curl), lo corre con su propia revisión de salud y lo detiene midiendo el tiempo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

t() { date +%s%3N; }
# esperar_salud ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
# estado: lo que dice docker ps, sin el nombre
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
# bitacora_salud: las revisiones guardadas, una por renglón: código y salida
bitacora_salud() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{printf "%q" .Output}}{{println}}{{end}}' "$NOMBRE" | sed '/^$/d'
}
SERVICIOS='propio http://127.0.0.1:8080/salud'

echo "== 1. Construir y leer la revisión de salud que trae la imagen"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null
docker image inspect --format '{{json .Config.Healthcheck}}' "$IMAGEN"
docker image inspect --format 'StopSignal={{.Config.StopSignal}}' "$IMAGEN"

echo
echo "== 2. El error: vigilarlo con curl, como en los tutoriales"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  --health-cmd 'curl -fs http://127.0.0.1:8080/salud || exit 1' \
  --health-interval 2s --health-retries 2 --health-start-period 1ms "$IMAGEN" >/dev/null
inicio=$(t); esperar_salud unhealthy; fin=$(t)
estado
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud | tail -1
echo "-- y sin embargo, el servicio contesta:"
docker exec "$NOMBRE" /revisor healthcheck
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Con la revisión de la imagen: el propio binario se pregunta"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
estado
inicio=$(t); esperar_salud healthy; fin=$(t)
estado
echo "pasó a healthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud
docker inspect --format 'Status={{.State.Status}} Health={{.State.Health.Status}} FailingStreak={{.State.Health.FailingStreak}}' "$NOMBRE"

echo
echo "== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
```

```text
$ ./fig07_03.sh
== 1. Construir y leer la revisión de salud que trae la imagen
{"Test":["CMD","/revisor","healthcheck"],"Interval":10000000000,"Timeout":3000000000,"StartPeriod":5000000000,"Retries":3}
StopSignal=SIGTERM

== 2. El error: vigilarlo con curl, como en los tutoriales
Up 4 seconds (unhealthy)
pasó a unhealthy en 5 s
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
-- y sin embargo, el servicio contesta:
sano

== 3. Con la revisión de la imagen: el propio binario se pregunta
Up 1 second (health: starting)
Up 6 seconds (healthy)
pasó a healthy en 5 s
0 "sano\n"
Status=running Health=healthy FailingStreak=0

== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM
docker stop tardó 657 ms
ExitCode=0
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí terminated, apagando
revisor: apagado limpio
```

What is new in the script: `esperar_salud` asks every half second for `.State.Health.Status` until it says what is expected; `estado` shows the `STATUS` column of `docker ps` without the name; and `bitacora_salud` walks through `.State.Health.Log`, the list of the latest checks Docker keeps, with the code and output of each. The `printf "%q"` writes the output in quotes and with line breaks as `\n`, so you can see exactly what the command printed.

Block by block:

1. **The image carries its check.** `docker image inspect` shows it in JSON: the command in *exec* form (`"CMD"` followed by the list) and the timings in nanoseconds (`10000000000` is ten seconds). The shutdown signal is recorded: `StopSignal=SIGTERM`.
2. **With `curl`, `unhealthy`.** The script asked for a check every two seconds and two failures to give up, and after 5 seconds the container was already `(unhealthy)`: two failed checks, at 2 and 4 seconds, plus however long each one takes. Notice `--health-start-period 1ms`. A `--health-*` option set to `0s` does **not** disable the startup period: for Docker, a zero means "use the image's value", and the container would keep the Dockerfile's 5 seconds of startup. `1ms` is the way to ask for an almost nonexistent startup period; Exercise 2 shows you the difference, measured. The health log says why, and the code is not `1` but **`-1`**: Docker could not even run the check. The message is the one from Lesson 2 when you tried `docker exec ... sh`, worded differently: `exec: "/bin/sh": stat /bin/sh: no such file or directory`. And the most important part comes next: `docker exec ... /revisor healthcheck` answers `sano`. **The service was fine; the check was broken.** It is the most treacherous error in this lesson, because the `unhealthy` state accuses the program of something that is the fault of whoever wrote the check.
3. **With the image's check, `healthy` at 5 seconds.** First `(health: starting)`, then `(healthy)`. The five seconds are the `--start-interval`: the first question arrived at the end of the first startup interval, and came out fine. The Dockerfile reference says the first check arrives after one `--interval`, which here would be ten seconds; measured with Docker 29.2.1, during startup Docker uses `--start-interval`, and the first arrived at five. When the documentation and the measurement disagree, the measurement wins (you will see it again in 7.6.3). The log has one entry: code `0` and the output `sano\n`. The last line reads the same thing in pieces: the process is `running`, its health is `healthy`, and the failure streak (`FailingStreak`) is `0`.
4. **The shutdown.** Without `--init`, the `revisor` is number 1, but this time it **does** have a handler. `docker stop` took **657 ms** in this run, with the machine loaded (562 ms in Lesson 3, according to its saved output), and the code is `0`, not `143`: the program did not die from the signal, it handled it and exited on its own. The logs tell it in their own words (the `grep -v` leaves out the `GET /salud` from each check).

#### 7.4.5 In your folder

Your project has lived in `~/curso-docker/revisor` since Lesson 3. From the root of the course repository, put this lesson's Dockerfile there and build the image you are going to keep:

```bash
cp programas/07-salud-y-ciclo-de-vida/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.4.0 -t curso-docker-revisor:1.4.0 .
docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0
```

The last command must print the same JSON as block 1. The `.dockerignore` and the `secretos/` folder do not change. `Dockerfile.malo`, the one from Lesson 6, you no longer need; you can remove it from your folder or leave it, because the `.dockerignore` keeps it from traveling. The image is run hardened in section 7.10, once you know what each option does.

### 7.5 Running is not healthy

#### 7.5.1 What Docker does with health, and what it does not

A health check changes **a label**: the one you see in parentheses in `docker ps`. Nothing more. Docker does not restart an `unhealthy` container, does not cut off its traffic, and does not notify anyone. The information is there for someone to use: you, when looking at `docker ps`; Compose, which with `depends_on` and `condition: service_healthy` waits for a service to be healthy before starting the next one (Lesson 9); an orchestrator, which can replace the sick container. This section demonstrates it with the test service, which has a trick the `revisor` does not: it changes mode without restarting.

#### 7.5.2 The test service gets sick

The script `fig07_04.sh` builds a copy of the test service, starts it with `--restart always` (the most insistent policy, which you will see in 7.6), and puts it through its three modes:

```bash
#!/usr/bin/env bash
# fig07_04.sh — Corriendo no es sano. El servicio de prueba, con su propio
# HEALTHCHECK (cada 5 s, 2 reintentos), pasa a modo caído y a modo lento sin
# reiniciarse: el proceso sigue vivo y Docker lo marca unhealthy. Y una política
# de reinicio NO reinicia a un contenedor por estar unhealthy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-9000}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
resumen() {
  docker inspect --format '{{.State.Status}} / {{.State.Health.Status}} / racha={{.State.Health.FailingStreak}} / reinicios={{.RestartCount}}' "$NOMBRE"
}
ultima_revision() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{.Output}}{{end}}' "$NOMBRE" | sed '/^$/d' | tail -1
}

echo "== 1. Arranca sano, con --restart always"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:9000" --restart always "$IMAGEN" >/dev/null
esperar_salud healthy
estado

echo
echo "== 2. Modo caído: el proceso sigue vivo, pero responde 503"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/caido"
inicio=$(t); esperar_salud unhealthy; fin=$(t)
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
estado
resumen
ultima_revision

echo
echo "== 3. Diez segundos después, sigue unhealthy y nadie lo reinició"
sleep 10
resumen

echo
echo "== 4. De vuelta a sano, sin reiniciar nada"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/sano"
inicio=$(t); esperar_salud healthy; fin=$(t)
echo "volvió a healthy en $(( (fin - inicio + 500) / 1000 )) s"
resumen

echo
echo "== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/lento"
esperar_salud unhealthy
resumen
ultima_revision
echo "-- y sin embargo, contesta 200:"
curl -s -o /dev/null -w '%{http_code} en %{time_total}s\n' "http://127.0.0.1:$PUERTO/"
```

```text
$ ./fig07_04.sh
== 1. Arranca sano, con --restart always
Up 5 seconds (healthy)

== 2. Modo caído: el proceso sigue vivo, pero responde 503
modo: caido
pasó a unhealthy en 10 s
Up 15 seconds (unhealthy)
running / unhealthy / racha=2 / reinicios=0
1 no sano: GET / respondió 503

== 3. Diez segundos después, sigue unhealthy y nadie lo reinició
running / unhealthy / racha=4 / reinicios=0

== 4. De vuelta a sano, sin reiniciar nada
modo: sano
volvió a healthy en 5 s
running / healthy / racha=0 / reinicios=0

== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2
modo: lento
running / unhealthy / racha=2 / reinicios=0
1 no sano: Get "http://127.0.0.1:9000/": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
-- y sin embargo, contesta 200:
200 en 3.012887s
```

The test service has had its own `HEALTHCHECK` since Lesson 2: every 5 seconds, with 2 retries, and its check demands a `200` in under 2 seconds. With that:

1. **It starts healthy**, at 5 seconds.
2. **In down mode, `unhealthy` at 10 seconds.** Two failed checks, five seconds apart: that is the `--retries=2` times the `--interval=5s` of its Dockerfile. Now look at the `resumen` line: `running / unhealthy / racha=2 / reinicios=0`. The process **runs**; the health says it **is no good**; the failure streak is 2; and nobody restarted it. The last check explains the cause with the exact text from its code: `1 no sano: GET / respondió 503`.
3. **Ten seconds later, the same.** The streak went up to 4 and the restarts are still 0. Neither the health check nor `--restart always` did anything. This is what was happening in the opening scene: a container that was `Up`, `unhealthy`, and abandoned.
4. **Back to healthy in 5 seconds**, without restarting anything: one good check sets the streak to 0 and the health to `healthy`. Health is not a state you earn once: it is recalculated on every check.
5. **In slow mode, also `unhealthy`.** And here is the finest lesson. The service answers `200`, the "all good" code, but takes 3 seconds, and its check only waits 2: `context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, which is how Go says "time ran out waiting for the response". The `curl` at the end confirms it: `200 en 3.01s`. For the check, a service that answers late is a service that does not answer. That is a design decision: whoever writes the check decides what "healthy" means, and here it means "answers correctly **and** on time".

#### 7.5.3 What a good check asks

A health check answers a single question: **can this process serve?** For the `revisor`, `/salud` answers that the HTTP server is alive and serving, and nothing else. It does not check the services the `revisor` watches: if it did, a downed test service would make the `revisor` `unhealthy`, when it is perfectly fine doing its job, which is reporting the outage. Nor does it check whether it can write its report, and in 7.7 you will see what that means. A check that depends on other services turns one service's failure into everyone's failure; that is why it should ask about the process itself and be cheap: it is going to run every ten seconds for the whole life of the container.

### 7.6 Restart policies

#### 7.6.1 The four policies

A **restart policy** tells the daemon what to do when a container's process ends. It is chosen with `docker run --restart` and there are four, which the documentation describes this way ([Docker, "Start containers automatically"](https://docs.docker.com/engine/containers/start-containers-automatically/)):

| Policy | What it does |
|---|---|
| `no` | never restarts; it is the default |
| `on-failure[:max]` | restarts if the process exits with a code other than 0; with `:max`, only that many times. It does not restart the container when the daemon restarts |
| `always` | restarts whenever the process stops. If you stopped it yourself, it only starts again when the Docker daemon restarts or when you start it |
| `unless-stopped` | like `always`, except that if the container was stopped, it does not start again even when the daemon restarts |

Two more details from the documentation matter. One: if you stop a container by hand, its policy is ignored until the daemon restarts or you start it again; so there is no way to fight with Docker to shut something down. And two: between one restart and the next, Docker waits longer each time: double the previous one, starting at 100 milliseconds and capped at one minute; if the container manages to stay up for at least 10 seconds, the wait goes back to 100 ms ([`docker run` reference](https://docs.docker.com/reference/cli/docker/container/run/)). That keeps a broken container from restarting a thousand times a second.

#### 7.6.2 Measuring what each one does

The script `fig07_05.sh` builds the `revisor` and makes it die in several ways:

```bash
#!/usr/bin/env bash
# fig07_05.sh — Políticas de reinicio. Un revisor sin configuración muere con
# código 1 en cuanto arranca: con on-failure:3, Docker lo reintenta tres veces,
# cada vez esperando más. Y con always: qué hace Docker cuando el proceso muere
# solo, y qué hace cuando lo detienes tú. Usa sudo una vez, para matar al
# proceso desde fuera como lo haría el núcleo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}reinicios-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
resumen() {
  docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} RestartCount={{.RestartCount}}' "$NOMBRE"
}

echo "== 1. on-failure:3 con un revisor sin configuración"
desde=$(date +%s)
docker run -d --name "$NOMBRE" --restart on-failure:3 "$IMAGEN" >/dev/null
sleep 8
resumen
echo "-- lo que escribió en sus cuatro vidas:"
docker logs "$NOMBRE" 2>&1 | sort | uniq -c
echo "-- cuánto esperó Docker entre un arranque y el siguiente:"
docker events --since "$desde" --until "$(date +%s)" \
  --filter "container=$NOMBRE" --filter event=start --format '{{.TimeNano}}' |
  awk 'NR > 1 { printf "arranque %d: %d ms después del anterior\n", NR, ($1 - previo) / 1000000 } { previo = $1 }'
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. Sin política (no, la de omisión): muere y se queda muerto"
docker run -d --name "$NOMBRE" "$IMAGEN" >/dev/null
sleep 3
resumen
docker rm -f "$NOMBRE" >/dev/null

SERVICIOS='propio http://127.0.0.1:8080/salud'
echo
echo "== 3. --restart always con el revisor bien configurado"
docker run -d --name "$NOMBRE" --restart always -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
sleep 2
echo "-- el núcleo mata al proceso (como haría el asesino de memoria):"
PID1=$(pid_de "$NOMBRE")
sudo kill -KILL "$PID1"
sleep 3
resumen
echo "-- lo detienes tú, con docker stop:"
docker stop "$NOMBRE" >/dev/null
sleep 3
resumen
echo "-- lo vuelves a arrancar tú, y lo matas con docker kill:"
docker start "$NOMBRE" >/dev/null
sleep 2
docker kill "$NOMBRE" >/dev/null
sleep 3
resumen
```

```text
$ ./fig07_05.sh
== 1. on-failure:3 con un revisor sin configuración
Status=exited ExitCode=1 RestartCount=3
-- lo que escribió en sus cuatro vidas:
      4 revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
-- cuánto esperó Docker entre un arranque y el siguiente:
arranque 2: 181 ms después del anterior
arranque 3: 294 ms después del anterior
arranque 4: 490 ms después del anterior

== 2. Sin política (no, la de omisión): muere y se queda muerto
Status=exited ExitCode=1 RestartCount=0

== 3. --restart always con el revisor bien configurado
-- el núcleo mata al proceso (como haría el asesino de memoria):
Status=running ExitCode=0 RestartCount=1
-- lo detienes tú, con docker stop:
Status=exited ExitCode=0 RestartCount=1
-- lo vuelves a arrancar tú, y lo matas con docker kill:
Status=exited ExitCode=137 RestartCount=0
```

What is new in the script: `docker events` lists what the daemon did to a container over a time interval (here, only the starts, `event=start`), and `{{.TimeNano}}` gives the exact time of each in nanoseconds. The `awk` subtracts each start from the previous one and converts to milliseconds. And `sudo kill -KILL` sends `SIGKILL` to the container's process **from outside Docker**, the way the kernel would when a process exceeds its memory limit; `sudo` is needed because the process belongs to user `65532`, not yours.

1. **`on-failure:3` with a `revisor` without configuration.** It dies with `1` as soon as it starts. Docker started it three more times and gave up: `Status=exited ExitCode=1 RestartCount=3`. The logs are the proof: the same message four times, one per life. And the waits are the ones in the documentation, plus however long each start takes: **181, 294, and 490 ms**, which are the 100, 200, and 400 of the growing wait, plus some 80 to 90 ms of startup. In a run with the machine loaded by other jobs they came out at 530, 1,483, and 2,399 ms: the wait is set by Docker, but how long each start takes is set by the machine. The `revisor` could not be fixed (it is missing a variable), and that is why a cap is a good idea: three attempts are enough to know it is not a stumble.
2. **Without a policy, it stays dead.** `RestartCount=0`. It is what you want for something that runs once and finishes.
3. **`always` with the `revisor` properly configured.** Three ways to die, three results:
   - **The kernel kills it.** Docker started it again: `Status=running RestartCount=1`. That is what the policy exists for. (`ExitCode=0` belongs to the container that is running now; it has not ended yet, so it has no code of its own.)
   - **You stop it with `docker stop`.** It stays stopped, with `ExitCode=0` because it shut down in an orderly way. The policy respects your decision.
   - **You kill it with `docker kill`.** It also stays stopped, now with `137`. Docker counts `docker kill` as a manual stop, just like `docker stop`, even though the process dies with `SIGKILL`. And notice `RestartCount=0`: the count went back to zero when you started it with `docker start`.

#### 7.6.3 A sentence from the documentation worth reading carefully

The restart policies page says a policy "only takes effect after a container starts successfully", and that this means being up "at least 10 seconds". Block 1 contradicts it at first glance: the `revisor` without configuration did not last even a second and Docker restarted it three times. What the measurement shows is what the `docker run` reference says: the 10 seconds decide when the wait goes back to 100 ms, not whether a retry happens. When documentation and your measurement disagree, the measurement wins, and you note the version you measured with: Docker 29.2.1.

#### 7.6.4 Which one to choose for the `revisor`

`unless-stopped`. The `revisor` is a service that must always be up, so it needs to be restarted if the kernel kills it or if the machine reboots; that rules out `no` and `on-failure`, which does not bring it back after a daemon restart. Between `always` and `unless-stopped`, the difference appears only when the daemon restarts, for example when the machine reboots: with `always`, a container you had stopped on purpose comes back to life; with `unless-stopped`, the fact that you stopped it is respected. That was not measured here, because restarting the daemon shuts down all the containers on the machine; it is in the documentation's table. And remember what you saw in 7.5: none of the four restarts a container for being `unhealthy`. A restart policy deals with the death of the process, not with its health.

### 7.7 Read-only file system

#### 7.7.1 Why

The image has been read-only all along; what is written at run time goes to a new layer, belonging to the container, which you saw in Lesson 4. `--read-only` closes that layer: the container's root file system is mounted "as read-only" ([`docker run` reference](https://docs.docker.com/reference/cli/docker/container/run/)). The program can still read everything the image brings, but it cannot create, change, or delete any file.

The gain is one of security and of order. Of security, because whoever manages to take control of the process cannot leave a program of their own on disk, or change a configuration file, or replace the binary. Of order, because it forces you to know exactly **where your program writes**: each writable path becomes a decision, not an accident.

#### 7.7.2 Triggering it and fixing it

The script `fig07_06.sh` uses the `REVISOR_REPORTE` option, which tells the `revisor` where to save the latest report. The `revisor` writes it with a temporary file and a rename in the same folder, so that nobody ever reads a half-written report. Blocks 1 and 2 are this section; block 3, section 7.10:

```bash
#!/usr/bin/env bash
# fig07_06.sh — Solo lectura y el revisor endurecido completo. Primero el error:
# con --read-only, el revisor no puede guardar su reporte. Después el arreglo,
# un tmpfs solo donde hace falta escribir. Y al final, todas las opciones de la
# lección juntas: lo que Docker anotó, lo que el núcleo aplica y cómo se apaga.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
SERVICIOS='propio http://127.0.0.1:8080/salud'
# El número del archivo temporal cambia en cada corrida: se tapa a la vista.
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. --read-only, y el revisor guardando su reporte en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
echo "-- /salud no escribe nada, así que sigue contestando:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/salud"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El arreglo: un tmpfs pequeño solo en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=1m \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -o /dev/null -w '[%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker inspect --format '{{range $ruta, $opciones := .HostConfig.Tmpfs}}{{$ruta}} {{$opciones}}{{end}}' "$NOMBRE"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Todo junto: el revisor endurecido"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
echo "-- lo que Docker anotó:"
docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} SecurityOpt={{.HostConfig.SecurityOpt}} Init={{.HostConfig.Init}} Restart={{.HostConfig.RestartPolicy.Name}}' "$NOMBRE"
echo "-- los procesos:"
docker top "$NOMBRE" -o pid,ppid,user,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
echo "-- lo que el núcleo aplica al revisor (el hijo de docker-init):"
PID1=$(pid_de "$NOMBRE")
HIJO=$(pgrep -P "$PID1" | head -1)
grep -E '^(CapEff|CapBnd|NoNewPrivs)' "/proc/$HIJO/status"
echo "-- docker stop:"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
```

```text
$ ./fig07_06.sh
== 1. --read-only, y el revisor guardando su reporte en /tmp
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
-- /salud no escribe nada, así que sigue contestando:
{"estado":"vivo","version":"1.4.0"}
 [200]

== 2. El arreglo: un tmpfs pequeño solo en /tmp
[200]
/tmp rw,noexec,nosuid,size=1m

== 3. Todo junto: el revisor endurecido
Up 5 seconds (healthy)
-- lo que Docker anotó:
ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped
-- los procesos:
PID                 PPID                USER                COMMAND
<pid> <ppid>             65532               /sbin/docker-init -- /revisor
<pid> <ppid>             65532               /revisor
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí terminated, apagando
revisor: apagado limpio
```

1. **With `--read-only`, `500`.** The `revisor` tried to create its temporary file in `/tmp` and the kernel answered `read-only file system`. The `revisor` does not hide the error: it responds `500` and the exact cause. The temporary file's number changes on every run, and the script masks it with `<n>`. And look at the next line: **`/salud` still answers `200`**. The health check would say `healthy` while every query to `/api/estados` fails. It is what 7.5.3 anticipated: health says whether the process is serving, not whether every function works. That is why, when hardening a container, it is not enough to see that it starts and is healthy: you have to exercise what it does.
2. **With `--tmpfs /tmp`, `200`.** A **`tmpfs`** is a folder that lives in the machine's memory: according to the documentation, unlike volumes and *bind mounts*, "it is temporary and only persisted in the host memory", and when the container stops, what was written there disappears ([Docker, "tmpfs mounts"](https://docs.docker.com/engine/storage/tmpfs/)). It is exactly what a temporary file needs. The root file system stays read-only; only `/tmp` accepts writes, and with three options: `noexec` prevents running programs from there (whoever manages to write a file cannot run it), `nosuid` makes the *setuid* bit have no effect there (you will see what that is in 7.9), and `size=1m` caps it at one megabyte. Without `size`, the kernel caps it at half the machine's memory, and its permission is `1777`, writable by anyone (the documentation gives those values for `--mount type=tmpfs`; with `--tmpfs` they are the same, because the kernel sets them). Besides, the same page warns that what you write there counts against the container's memory limit: with Lesson 2's `--memory 64m`, an uncapped `tmpfs` could drive the `revisor` to its limit. The last line shows how it was recorded.

This fix is for this lesson. In Lesson 8 the report will be saved in a volume, because it has to outlive the container, and what lives in a `tmpfs` dies with it.

### 7.8 Capabilities out

#### 7.8.1 `root` broken into pieces

In Lesson 0 you saw that Docker does not give `root` all its power: it leaves it fourteen **capabilities**. The Linux manual explains the concept: Linux "divides the privileges traditionally associated with superuser into distinct units", called capabilities, which can be independently enabled and disabled ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Some of the ones Docker leaves by default, with the manual's definition:

| Capability | What it allows |
|---|---|
| `CAP_CHOWN` | make arbitrary changes to a file's user and group owner |
| `CAP_DAC_OVERRIDE` | bypass file read, write, and execute permission checks |
| `CAP_KILL` | bypass permission checks for sending signals |
| `CAP_SETUID` | make arbitrary changes to a process's user |
| `CAP_NET_BIND_SERVICE` | listen on ports below 1024 |

The `revisor` runs as `65532`, which is not `root`, so in principle it has none. Why remove them? Because the list a container runs with is not only that of its process: it is also the **ceiling** of what any process in that container could come to have (the manual's *bounding set*). If someone finds a way to become `root` inside the container, they inherit that ceiling. With `--cap-drop ALL`, the ceiling is zero: not even a `root` inside has any.

#### 7.8.2 Seeing it with a real `root`

To see what changes you need a container that runs as `root` and has tools, and the Go image has both. The script `fig07_07.sh` builds nothing and each container deletes itself:

```bash
#!/usr/bin/env bash
# fig07_07.sh — Capacidades y no-new-privileges, vistos en un contenedor que SÍ
# tiene shell y herramientas: la imagen de Go que ya bajaste. Qué puede hacer
# root con sus 14 capacidades, qué deja de poder sin ellas, y cómo un programa
# setuid convierte a un usuario normal en root… salvo con no-new-privileges.
# No construye nada y cada contenedor se borra solo (--rm).
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombre de apoyo con «fig07»: el guion nunca toca tus contenedores del curso.
NOMBRE="${PREFIJO}fig07-caps"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# correr [opciones de docker run] -- COMANDO: corre COMANDO con sh en un contenedor desechable
correr() {
  local opciones=()
  while [ "$1" != "--" ]; do opciones+=("$1"); shift; done
  shift
  docker run --rm --name "$NOMBRE" "${opciones[@]}" "$GO" sh -c "$1" 2>&1 || echo "[código de salida: $?]"
}
# La prueba: ¿puede root regalarle un archivo a otro usuario?
REGALAR='grep CapEff /proc/self/status; touch /tmp/a && chown 10001 /tmp/a && echo "chown: hecho"'

echo "== 1. root, con las capacidades que Docker deja por omisión"
correr -- "$REGALAR"

echo
echo "== 2. El mismo root, con --cap-drop ALL"
correr --cap-drop ALL -- "$REGALAR"

echo
echo "== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta"
correr --cap-drop ALL --cap-add CHOWN -- "$REGALAR"

# La otra prueba: un usuario normal ejecuta una copia de «id» con el bit setuid.
SETUID='cp /usr/bin/id /tmp/id-suid && chmod u+s /tmp/id-suid && ls -l /tmp/id-suid | cut -d" " -f1,3
setpriv --reuid 10001 --regid 10001 --clear-groups sh -c "id; /tmp/id-suid; grep NoNewPrivs /proc/self/status"'

echo
echo "== 4. Un programa setuid de root, ejecutado por el usuario 10001"
correr -- "$SETUID"

echo
echo "== 5. Lo mismo con --security-opt no-new-privileges"
correr --security-opt no-new-privileges -- "$SETUID"

echo
echo "== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80"
correr --user 10001:10001 --cap-drop ALL -- \
  'cat /proc/sys/net/ipv4/ip_unprivileged_port_start; perl -MIO::Socket::INET -e '"'"'IO::Socket::INET->new(LocalPort => 80, Listen => 1, ReuseAddr => 1) or die "no pude: $!\n"; print "escuchando en el 80\n"'"'"
```

```text
$ ./fig07_07.sh
== 1. root, con las capacidades que Docker deja por omisión
CapEff:	00000000a80425fb
chown: hecho

== 2. El mismo root, con --cap-drop ALL
CapEff:	0000000000000000
chown: changing ownership of '/tmp/a': Operation not permitted
[código de salida: 1]

== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta
CapEff:	0000000000000001
chown: hecho

== 4. Un programa setuid de root, ejecutado por el usuario 10001
-rwsr-xr-x root
uid=10001 gid=10001 groups=10001
uid=10001 gid=10001 euid=0(root) groups=10001
NoNewPrivs:	0

== 5. Lo mismo con --security-opt no-new-privileges
-rwsr-xr-x root
uid=10001 gid=10001 groups=10001
uid=10001 gid=10001 groups=10001
NoNewPrivs:	1

== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80
0
escuchando en el 80
```

The function `correr` assembles a `docker run --rm` with the options you pass before `--` and runs the command with `sh -c`. The test in the first three blocks is the same: show the `CapEff` line (the **effective** capabilities, the ones the process can use right now) and hand a file over to user `10001` with `chown`.

1. **`root` with the defaults.** `CapEff: 00000000a80425fb`, the same mask of the fourteen that you decoded in Lesson 0. `chown` works.
2. **`root` with `--cap-drop ALL`.** `CapEff` at zero, and `chown` fails with `Operation not permitted`, code 1. It is `root` (still user 0), but a `root` without capabilities cannot do what makes `root` special.
3. **`--cap-drop ALL --cap-add CHOWN`.** The mask is `1`: a single bit, that of `CAP_CHOWN`, which is capability number 0. `chown` works again. It is the pattern for a program that truly needs one: remove all and give back only that one, by name, in plain view of whoever reads the command.

#### 7.8.3 Low ports no longer need a capability

Block 6 answers a doubt you are going to have: if `CAP_NET_BIND_SERVICE` is the one that allows listening on ports below 1024, does a web server on port 80 need to keep it? In a Docker container, no. User `10001`, **with no capabilities at all**, opened port 80. The first line explains why: inside the container, the kernel setting `ip_unprivileged_port_start`, which says from which port an unprivileged user can listen, is `0`. Docker sets it this way by default since version 20.10, in every container with its own network ([moby/moby #41030](https://github.com/moby/moby/pull/41030)), and since that setting applies only to the container's network, it changes nothing on your machine. The `revisor` listens on 8080 and does not need it anyway, but now you know that `--cap-drop ALL` does not force you to move a service to another port.

### 7.9 `no-new-privileges`

#### 7.9.1 The *setuid* bit

In Linux, an executable file can have the ***setuid*** bit set: whoever runs it, whoever they are, runs it **as the file's owner**. That is how `passwd` or `su` work, which a normal user runs and which need to be `root` for a moment. The capabilities manual says of the case that matters: a *setuid* `root` program gains all capabilities, except those the ceiling (*bounding set*) does not allow ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). It is a legitimate door for raising privileges, and that is why it is the favorite of whoever tries to raise them without permission.

`--security-opt no-new-privileges` closes that door. It sets a kernel flag on the process, `no_new_privs`, which the kernel documentation defines this way: with it, `execve` (running another program) promises "to not grant privileges to do anything that could not have been done without the execve call"; specifically, "the setuid and setgid bits will no longer change the uid or gid", and a file's capabilities are not added. The flag is inherited by all children and **cannot be disabled** ([Linux, "No New Privileges Flag"](https://docs.kernel.org/userspace-api/no_new_privs.html)). The `docker run` reference puts it in practical terms: with this option, "commands that elevate privileges, such as `su` or `sudo`, no longer work".

#### 7.9.2 Seeing it

Blocks 4 and 5 of `fig07_07.sh` do the test. As `root`, the script copies the `id` program to `/tmp/id-suid` and sets its *setuid* bit (the `s` in `-rwsr-xr-x`, owner `root`). Then, with `setpriv`, a Debian tool that switches users, it becomes user `10001` and runs `id` twice: the normal one and the *setuid* copy.

4. **Without `no-new-privileges`.** The normal `id` says `uid=10001`. The copy says `uid=10001 ... euid=0(root)`: the **effective** user is `root`. An ordinary user ran a file and, while it runs, has `root`'s powers. `NoNewPrivs: 0`.
5. **With `no-new-privileges`.** Both say `uid=10001` and nothing more. The bit is still there (`-rwsr-xr-x`), but the kernel no longer pays attention to it. `NoNewPrivs: 1`.

Why does it matter in the `revisor`, which has no *setuid* programs? For the same reason as `--cap-drop ALL`: it is not for what is in the image today, but for what someone might put in or find tomorrow. And it combines with the rest: the `tmpfs` at `/tmp` carries `nosuid` and `noexec`, the root file system is read-only, and the capability ceiling is zero. To raise privileges, an attacker would need to write a program, run it, and have the *setuid* bit count; each of the three options closes one step.

### 7.10 All together: the hardened `revisor`

#### 7.10.1 The command

These are the options the `revisor` runs with from now on. Lesson 9 writes them into `compose.yaml` with their YAML equivalents (`read_only: true`, `cap_drop: [ALL]`, `security_opt`, `init: true`), not as command-line options:

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' \
  curso-docker-revisor:1.4.0
```

Each line comes from a lesson: the port on `127.0.0.1` and the limits, from 2; the image without `root` or a *shell*, from 3 and 5; the configuration through `-e`, from 6; and the second line and the restart policy, from this one. It carries no `--tmpfs` because here it is not asked to save the report; in Lesson 8 it will have a volume for that.

These options greatly reduce what an intruder can do, but they replace nothing else: a program that truly needs a specific capability or to write in a specific place asks for `--cap-add` or a volume, one by one, and the rest of the defense (what code runs, what gets mounted into it) remains your job.

#### 7.10.2 Checking it

Block 3 of `fig07_06.sh` runs exactly those options and asks each party for its own part:

1. **The health:** `(healthy)` at 5 seconds, with everything in place. None of the options got in the `revisor`'s way.
2. **What Docker recorded:** `ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped`. It is what you asked for, read from the container's configuration.
3. **The processes:** `docker-init` as number 1 and `/revisor` as its child, both with user `65532`.
4. **What the kernel applies**, read from the `/proc` of the child, which is the `revisor` (the script finds it with `pgrep -P`, which looks for a process's children): `CapEff` at zero (it has no capabilities), `CapBnd` at zero (it could not even gain them), and `NoNewPrivs: 1`. Of the three, `CapBnd` is the one that demonstrates `--cap-drop ALL`: the `revisor` runs as `65532`, and its `CapEff` would be zero even if you removed nothing; the ceiling, by contrast, would be the fourteen capabilities. This is more than Docker's word: it is what the kernel enforces. A badly written option could be recorded without being applied; `/proc` does not lie.
5. **The shutdown:** `docker stop` took **206 ms** and the code is `0`. `docker-init` passed the signal to the `revisor`, the `revisor` handled it and said goodbye in its logs. Fully hardened, and it dies just as well as with nothing.

In your folder, run the command from 7.10.1, wait a few seconds, and check with `docker ps --filter name=curso-docker-revisor` that it says `(healthy)`. When you see it `(healthy)`, delete it with `docker rm -f curso-docker-revisor` **before the exercises**, which use that name and that port; the image `curso-docker-revisor:1.4.0` stays for Lesson 8.

### 7.11 What you will find in old tutorials

- **`HEALTHCHECK CMD curl -f http://localhost/ || exit 1`.** It works in images that carry a *shell* and `curl`, and it forces you to put into the image two things you left out. In section 7.4.4 you saw how it fails in a minimal image: `unhealthy` with a healthy service. If your program is a server, give it a health subcommand.
- **Installing `tini` or `dumb-init` inside the Dockerfile** and putting it in the `ENTRYPOINT`. It was necessary before Docker shipped its own *init*; today `--init` does the same without touching the image. It still makes sense if the image will run somewhere you cannot ask for `--init`.
- **A startup script that ends in `revisor` instead of `exec revisor`.** It is Lesson 3's *shell* form hidden in a file: the *shell* stays as number 1 and the signal does not arrive.
- **`--restart always` on everything, "so it never goes down".** It does not fix a broken program (it restarts it over and over, later each time) and does nothing about a sick one that keeps running. Besides, according to the documentation, a container with `always` that you stopped on purpose comes back to life when the daemon restarts.
- **`--privileged` to "get rid of permission problems".** It is the opposite of this lesson: it gives the container all capabilities and access to the machine's devices. The `docker run` reference explains that, by default, Docker removes the most dangerous capabilities, such as `CAP_SYS_ADMIN`; `--privileged` gives them all back. If a program needs a capability, `--cap-add` with its name.

## The error you will see

This lesson has one main error and two that appear along with it.

**The main error: the health check that cannot be run.** It is the one from `fig07_03.sh`:

```text
Up 4 seconds (unhealthy)
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
```

This is how to read it. `-1` is not a code from the program: it is Docker saying it could not even start the check. `OCI runtime exec failed` says who failed, the component that runs processes inside the container. And the end says what it looked for and did not find: `/bin/sh`. The check was in *shell* form (or it was passed with `--health-cmd`, which is the same) and the image has no *shell*. It is fixed with a check in *exec* form that calls a program the image does have: `HEALTHCHECK CMD ["/revisor", "healthcheck"]`. If instead of `/bin/sh` the message says `curl`, the image has a *shell* but not `curl`; the fix is the same. And before blaming the program, ask it yourself: `docker exec <container> /revisor healthcheck`. If it answers `sano`, the problem is in the check, not in the service.

**The one that appears with it: read-only.** The one from `fig07_06.sh`:

```text
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
```

`read-only file system` is said by the kernel: the container runs with `--read-only` and the program tried to write. The question that solves it is "where does my program write, and why?". If it is something temporary, a `--tmpfs` on that folder; if it has to last, a volume (Lesson 8). What is not a fix: removing `--read-only`.

**The code that gives away a bad shutdown: `137` after `docker stop`.** If `docker stop` takes the full timeout and leaves `ExitCode=137`, the signal was of no use to process number 1: either there is a *shell* in the middle (Lesson 3), or it is a program that installed no handler (7.1.4). Look at `docker top` to know who number 1 is and at `SigCgt` to know what it handles. If you cannot change the program, `--init`.

## The security habit of the lesson

**The container runs with the minimum: read-only file system, zero capabilities, and no gaining privileges, and you check in `/proc` that the kernel applies it.** They are three options written together (`--read-only --cap-drop ALL --security-opt no-new-privileges`) and one check that is done once per image. Each takes a step away from whoever manages to take control of the process through a flaw in the program: it cannot write to disk, it has none of the parts of `root`'s power, and it cannot become `root` by running a *setuid* program. The accident it prevents is not hypothetical: almost every way of going from "I control a process" to "I control the machine" needs to write something, use a capability, or raise the user. And the half that gets forgotten is the second: writing the options is not enough, you have to see `CapBnd: 0000000000000000` (the ceiling: not even a `root` inside could gain capabilities) and `NoNewPrivs: 1`. `CapEff` at zero is not enough as proof: a user who is not `root`, like the `revisor`'s `65532`, already has it at zero without `--cap-drop ALL`. What you add afterwards, you add by name: a writable folder with `--tmpfs` or a volume, a capability with `--cap-add`.

## Common mistakes

**Shortening the `docker stop` timeout so that it "doesn't take so long".** With `-t 2`, a program that does not handle the signal dies in 2 seconds instead of 10, but it dies just as badly: `137`, without finishing what it was doing. The fix is for the signal to arrive (`--init`, *exec* form, a handler), not for them to kill sooner.

**An internal shutdown timeout longer than Docker's.** If your program waits 15 seconds for its requests and Docker gives it 10, the orderly shutdown never finishes. Adjust one or the other (`--stop-timeout`), but make it fit.

**Confusing `Up` with "works".** `docker ps` says `Up` as long as the process exists. If the container has no `HEALTHCHECK`, nobody is asking whether it serves.

**A health check that depends on other services.** If the `revisor`'s health depended on the services it checks, someone else's outage would make it `unhealthy`. The check asks about the process itself.

**An expensive check.** It runs every few seconds for the whole life of the container. A full database query, or an entire report, every ten seconds is load nobody asked for.

**Expecting `--restart` to cure an `unhealthy` container.** No policy looks at health. You saw it in 7.5: a streak of four failures, zero restarts.

**Removing `--read-only` because "the program needs to write".** The program needs to write in **one** place. Give it that place by name.

**`--privileged` or `--cap-add ALL` to get by.** It undoes the whole lesson. If something asks for a capability, find out which one and add only that one.

**Believing what `docker inspect` says without looking at `/proc`.** `docker inspect` shows what you asked for. `/proc/<pid>/status` shows what the kernel applies. Usually they match; when they do not, the kernel is the one in charge.

## Exercises

Do them in order. Before running each one, write in your [log](bitacora.md) what you think will happen; comparing it afterwards is half of the learning. When you finish, delete what you created: everything carries the prefix `curso-docker-`.

### Exercise 1 — Read the ending

Without running anything, say which `ExitCode` each container leaves and roughly how long `docker stop` would take when it applies. Use the table in 7.1.2.

1. The `revisor` 1.4.0, running well, stopped with `docker stop`.
2. The Go image running `sleep 300`, without `--init`, stopped with `docker stop`.
3. The same one, with `--init`, stopped with `docker stop`.
4. The `revisor` 1.4.0 without `REVISOR_SERVICIOS`, with no restart policy.
5. The `revisor` 1.4.0 running well, ended with `docker kill`.
6. An `(unhealthy)` container whose health log says `-1 "OCI runtime exec failed: ..."`. What code does the **container** have?

### Exercise 2 — How long does it take to get sick?

With the image `curso-docker-prueba:1.0.0` from Lesson 2, predict how long it takes a container that starts in down mode with these options to become `unhealthy`, and what its failure streak is at that moment:

```bash
docker run -d --name curso-docker-prueba -e PRUEBA_MODO=caido \
  --health-interval 2s --health-retries 5 --health-start-period 1ms \
  curso-docker-prueba:1.0.0
```

Then measure it: ask every half second with `docker inspect --format '{{.State.Health.Status}}' curso-docker-prueba` and count the seconds since you started it. The `--health-*` options of `docker run` override the image's for that container. Delete it with `docker rm -f curso-docker-prueba` and repeat with `--health-start-period 0s`. Before running it, predict: does it take the same? Hint: reread point 2 of 7.4.4. At the end, `docker rm -f curso-docker-prueba`.

### Exercise 3 — Another shutdown signal (project)

If the container from 7.10 is still running, delete it first with `docker rm -f curso-docker-revisor`. Then run your image with another shutdown signal:

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --stop-signal SIGINT \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.4.0
```

Before stopping it, predict three things: what its log will say when it shuts down (`docker logs curso-docker-revisor`), what code it will end with, and which signal `docker inspect --format '{{.Config.StopSignal}}' curso-docker-revisor` will show. Then stop it with `docker stop curso-docker-revisor`, measure the time with `time`, and compare. Hint: look at which signals the `revisor` handles in 7.1.1. Extra question: what would happen with `--stop-signal SIGHUP`, a signal the `revisor`'s code did not ask for? At the end, `docker rm -f curso-docker-revisor`.

### Exercise 4 — Harden the test service

Run the test service with the hardened options from 7.10.1 (without the port and without `-e`, which it does not need):

```bash
docker run -d --name curso-docker-prueba \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  curso-docker-prueba:1.0.0
```

First, predict: will it reach `healthy`? Does it need a `--tmpfs`? Who will be number 1 and with which user? What code will it end with when stopped? Then check it with `docker ps --filter name=curso-docker-prueba`, `docker top curso-docker-prueba -o pid,user,args`, `docker stop curso-docker-prueba`, `docker inspect --format '{{.State.ExitCode}}' curso-docker-prueba`, and `docker logs curso-docker-prueba`. At the end, `docker rm -f curso-docker-prueba`.

## Solutions

Solutions 2, 3, and 4 were measured with two scripts that do the same as the exercises, with `fig07` helper names and without publishing ports: `fig07_08.sh` (test service) and `fig07_09.sh` (`revisor`).

### Solution 1

1. **`0`**, in tenths of a second: the `revisor` handles `SIGTERM` and exits on its own (7.4.4).
2. **`137`**, in a little over 10 seconds: `sleep` is number 1, has no handler, the signal is ignored, and in the end `SIGKILL` arrives (7.1.4).
3. **`143`**, in tenths of a second: `docker-init` forwards the signal, `sleep` is no longer number 1 and dies with `SIGTERM`'s default action, 128 + 15 (7.3.2).
4. **`1`**: the `revisor` ends on its own, with its own error code, without anyone sending it anything. `docker stop` does not apply: it is already stopped.
5. **`137`**: `docker kill` sends `SIGKILL` without waiting. And, if it had an `always` policy, it would not start again, because it counts as a manual stop (7.6.2).
6. **None**, because the container is still running: `unhealthy` is a label, not a death. The `-1` is the code of the **check**, not of the container. Its `.State.ExitCode` is `0` while it runs.

### Solution 2

```bash
#!/usr/bin/env bash
# fig07_08.sh — Las soluciones de los Ejercicios 2 y 4, con el servicio de prueba:
# cuánto tarda en enfermarse con otros tiempos de salud, y cómo corre con las
# opciones endurecidas de la lección.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}

for arranque in 0s 1ms; do
  echo "== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period $arranque"
  inicio=$(t)
  docker run -d --name "$NOMBRE" -e PRUEBA_MODO=caido \
    --health-interval 2s --health-retries 5 --health-start-period "$arranque" "$IMAGEN" >/dev/null
  esperar_salud unhealthy; fin=$(t)
  echo "pasó a unhealthy a los $(( (fin - inicio) / 100 ))00 ms de arrancar"
  docker inspect --format 'racha={{.State.Health.FailingStreak}} StartPeriod={{.Config.Healthcheck.StartPeriod}}' "$NOMBRE"
  docker rm -f "$NOMBRE" >/dev/null
  echo
done

echo "== Ejercicio 4: el servicio de prueba con las opciones endurecidas"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
docker top "$NOMBRE" -o pid,user,args | sed -E 's/^ *[0-9]+ /<pid> /'
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1
```

```text
$ ./fig07_08.sh
== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period 0s
pasó a unhealthy a los 13400 ms de arrancar
racha=5 StartPeriod=5s

== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period 1ms
pasó a unhealthy a los 10900 ms de arrancar
racha=5 StartPeriod=1ms

== Ejercicio 4: el servicio de prueba con las opciones endurecidas
Up 5 seconds (healthy)
PID                 USER                COMMAND
<pid>             65532               /sbin/docker-init -- /servicio-prueba
<pid>             65532               /servicio-prueba
docker stop tardó 234 ms; ExitCode=0
servicio-prueba escuchando en :9000 en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: recibí terminated, apagando
```

With `--health-start-period 1ms`, it became `unhealthy` at **10.9 seconds**, with `racha=5`. The arithmetic is 5 failures with 2 seconds between checks, 10 seconds, plus however long each check takes (running a process inside the container is not free). The streak is exactly what you asked for in `--health-retries`: the health changes right at failure number 5.

With `--health-start-period 0s` it took **13.4 seconds**, and the `docker inspect` line says why: `StartPeriod=5s`. A zero in a `--health-*` option of `docker run` turns nothing off; it means "use the image's", and the test service's Dockerfile says `--start-period=5s`. During those 5 seconds Docker asks every `--start-interval` (5 s), so the first check arrived at 5 seconds, and the following ones every 2: at 5, 7, 9, 11, and 13. The fifth failure lands at 13. If your prediction was "about ten seconds" for the first and "about thirteen" for the second, you understood both the arithmetic and the trap. The exact times change from one run to another; the streaks do not.

### Solution 3

```bash
#!/usr/bin/env bash
# fig07_09.sh — La solución del Ejercicio 3: el revisor con otra señal de apagado.
# SIGINT, que el revisor atiende, y SIGHUP, que no pidió, sin y con --init.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

t() { date +%s%3N; }
SERVICIOS='propio http://127.0.0.1:8080/salud'

for prueba in "SIGINT" "SIGHUP" "SIGHUP --init"; do
  set -- $prueba
  echo "== --stop-signal $1 ${2:-sin --init}"
  docker run -d --name "$NOMBRE" --stop-signal "$1" ${2:-} -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
  sleep 1
  inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop tardó $(( fin - inicio )) ms"
  docker inspect --format 'ExitCode={{.State.ExitCode}} StopSignal={{.Config.StopSignal}}' "$NOMBRE"
  docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
  docker rm -f "$NOMBRE" >/dev/null
  echo
done
```

```text
$ ./fig07_09.sh
== --stop-signal SIGINT sin --init
docker stop tardó 102 ms
ExitCode=0 StopSignal=SIGINT
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí interrupt, apagando
revisor: apagado limpio

== --stop-signal SIGHUP sin --init
docker stop tardó 72 ms
ExitCode=129 StopSignal=SIGHUP
revisor 1.4.0 escuchando en :8080 (1 servicio(s))

== --stop-signal SIGHUP --init
docker stop tardó 87 ms
ExitCode=129 StopSignal=SIGHUP
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
```

With `SIGINT`: `interrupt` is how Go names `SIGINT`, just as `terminated` is `SIGTERM`. The `revisor` installed a handler for both, so it shuts down equally well with either: code `0`, in milliseconds. `--stop-signal` was recorded in the container's configuration (`StopSignal=SIGINT`) and wins over the image's `STOPSIGNAL SIGTERM`.

Extra question, with `SIGHUP`: it died in milliseconds with `ExitCode=129` (128 + 1), with and without `--init`, and its log stops at `escuchando`, with no `apagando` or `apagado limpio`. It did not wait the 10 seconds, even though without `--init` it is number 1, because every Go program comes with a built-in handler for that signal: Go's documentation says that "`SIGHUP`, `SIGINT`, or `SIGTERM` cause the program to exit" ([os/signal](https://pkg.go.dev/os/signal)). There is a handler, so the signal arrives; but that built-in handler ends the program abruptly, without the orderly shutdown the `revisor` performs only with `SIGTERM` and `SIGINT`. That the code comes out as `129` even with the `revisor` as number 1 depends on how Go's *runtime* ends the program; it is what Docker 29.2.1 measured with Go 1.27.3. The practical rule does not change: the shutdown signal is chosen by looking at the code, and `STOPSIGNAL` leaves it written down.

### Solution 4

It is the last block of `fig07_08.sh`. It reaches `healthy` without `--tmpfs`, because the test service writes no files. Number 1 is `docker-init` and its child is the service, both with `65532`, the user its Dockerfile sets. It stops in tenths of a second with `0`: it handles `SIGTERM`, like the `revisor`. It is the same line of options that Lesson 8 applies to the test service when it puts it on an internal network, and that is why you will not have to think it through again there.

## How I know I got it

Check each item only if you can do it **without looking at the text again**:

- [ ] In your folder, `docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0` shows `["CMD","/revisor","healthcheck"]` with an `Interval` of ten seconds.
- [ ] You explain in one minute why `sleep 300` dies with `SIGTERM` in your terminal and not as number 1 of a container, using the words *handler*, *default action*, and *number 1*.
- [ ] You measure `docker stop` of a `sleep` without and with `--init`, and get a little over 10 seconds with `137`, and tenths of a second with `143`.
- [ ] You see a zombie with `ps --ppid` on your machine, and explain why `docker top` does not show it.
- [ ] You put the test service in down mode and read in `docker inspect` `running / unhealthy`, the failure streak, and the cause `GET / respondió 503`, with zero restarts.
- [ ] You say what `no`, `on-failure:3`, `always`, and `unless-stopped` do when the process dies on its own, when you stop it with `docker stop`, and when the daemon restarts.
- [ ] You run the `revisor` with the options from 7.10.1, it reaches `(healthy)`, and in `/proc/<revisor's pid>/status` you read `CapBnd: 0000000000000000` and `NoNewPrivs: 1` (and explain why `CapEff` at zero proves nothing with a user who is not `root`).
- [ ] You trigger `read-only file system` with `REVISOR_REPORTE=/tmp/reporte.json` and fix it with a fixed-size `--tmpfs`, without removing `--read-only`.
- [ ] You run the scripts in [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida) (with another `PUERTO` if yours are taken) and your outputs match this lesson's, except for the milliseconds, the seconds of `Up` and of the waits, and the masked numbers. And when you finish, `docker ps -a --filter name=curso-docker-` shows no containers from this lesson.

## Summary

Answer without looking at the lesson:

1. What is a signal, and how do `SIGTERM` and `SIGKILL` differ?
2. How do you read an `ExitCode` of `137`? And one of `143`? And one of `0` after `docker stop`?
3. Why does a container's process number 1 not die from `SIGTERM` if it installed no handler?
4. What does `docker stop` do step by step, and with which options do you change its timeout and its signal?
5. What two jobs does `--init` do, and why does the course use it with the `revisor` even though it does not need it today?
6. What do the codes `0`, `1`, and `2` of a health check mean, and what does `-1` mean in its log?
7. Why is the `revisor`'s check a subcommand of the same binary and not `curl`?
8. What does Docker do with an `unhealthy` container? And a restart policy?
9. How do `always` and `unless-stopped` differ?
10. What do `--read-only`, `--cap-drop ALL`, and `--security-opt no-new-privileges` change, and where do you check that the kernel applies them?

## Sources

All consulted on October 21, 2026.

- [signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html): the signals `SIGINT`, `SIGKILL`, and `SIGTERM`, their numbers and default actions, and that `SIGKILL` and `SIGSTOP` cannot be caught, blocked, or ignored.
- [pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html): the *init* process of a namespace only receives the signals for which it has a handler, except `SIGKILL` and `SIGSTOP` from an ancestor namespace; and orphans become its children.
- [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html): what capabilities are, the definitions of `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_KILL`, `CAP_SETUID`, and `CAP_NET_BIND_SERVICE`, the ceiling (*bounding set*), and what a *setuid* `root` program gains.
- [Linux, "No New Privileges Flag"](https://docs.kernel.org/userspace-api/no_new_privs.html): what `no_new_privs` does with `execve`, the *setuid* and *setgid* bits, and that it is inherited and cannot be disabled.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM` and then `SIGKILL`, the 10-second timeout on Linux, `-t`, `-s`, and `-t -1`.
- [`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/): that it sends `SIGKILL` by default.
- [`docker run` reference](https://docs.docker.com/reference/cli/docker/container/run/): `--init` and `docker-init`, the PID 1 that ignores signals with a default action, `--stop-signal`, `--stop-timeout`, `--read-only`, `--tmpfs`, `no-new-privileges`, the `--health-*` options, the growing wait between restarts, and what Docker removes by default compared with `--privileged`.
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/): `HEALTHCHECK` (options, default values, codes 0, 1, and 2, one per Dockerfile, `NONE`, 4,096 bytes of output) and `STOPSIGNAL`.
- [Docker, "Start containers automatically"](https://docs.docker.com/engine/containers/start-containers-automatically/): the four restart policies and the manual stop.
- [Docker, "tmpfs mounts"](https://docs.docker.com/engine/storage/tmpfs/): that a `tmpfs` lives in memory and disappears with the container, its default maximum size, and its `1777` permission.
- [tini](https://github.com/krallin/tini): the minimal *init* behind `docker-init`: a single child, reaping zombies, and forwarding signals.
- [os/signal](https://pkg.go.dev/os/signal): that a Go program exits by default on `SIGHUP`, `SIGINT`, or `SIGTERM`.
- [moby/moby #41030](https://github.com/moby/moby/pull/41030): the change that sets `net.ipv4.ip_unprivileged_port_start=0` by default in containers, since Docker 20.10.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions and dates in "About the runs".
- [Colima](https://github.com/abiosoft/colima): the tool the programs were run with on macOS.

### Terms in this lesson

| | |
|---|---|
| **capability** | one of the parts Linux divides `root`'s power into; removed with `--cap-drop` and added with `--cap-add` |
| **exit code** | the number a process ends with; 128 + *n* if signal *n* ended it |
| **`HEALTHCHECK`** | instruction that tells Docker how to ask a container whether it is healthy |
| ***init*** | process number 1; with `--init`, a tiny program that forwards signals and reaps zombies |
| **handler** | function a program installs to handle a signal instead of the default action |
| **`no-new-privileges`** | kernel flag that prevents a process from gaining privileges by running another program |
| **timeout** (of `docker stop`) | what Docker waits between `SIGTERM` and `SIGKILL`; 10 seconds by default |
| **restart policy** | what the daemon does when a container's process ends |
| **signal** | short notice from the kernel to a process, identified by a number |
| ***setuid*** | bit of an executable that makes it run as the file's owner |
| **`tmpfs`** | folder that lives in memory and disappears with the container |
| **zombie** | process that has already ended and waits for its parent to read its exit code |

---

**Next:** [Lesson 8 — Volumes and networks](08-volumenes-y-redes.md)
