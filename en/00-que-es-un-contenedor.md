# Lesson 0 — What a container is and what it is NOT

It is 2:14 in the morning and the alert goes off: the test server has stopped responding. You get in however you can, and the first thing you see is that the database, which lived on that same machine, is no longer running. The system log says the kernel killed it for lack of memory. Someone in the team chat writes, fully convinced: "It can't be the `revisor`, that one runs in a container; it's isolated, it's like a separate machine." Ten minutes later the culprit shows up: the `revisor`'s container, with no limit at all, had eaten the memory of the whole machine until the kernel had to choose whom to kill, and it chose the database. Nobody lied. What happened is that this person had a wrong idea of what a container is, and that idea cost a night. This lesson exists so that you do not have it.

**Time:** 90 min

**What you build:** nothing yet. It is a reading lesson: here you build the mental map that makes the rest of the course predictable. It comes with nine short programs so that you can see with your own eyes what the lesson claims.

**What you learn:** that a container is an isolated process and not a virtual machine; which components of the Linux kernel that isolation is built from (namespaces and control groups); the difference between an image and a container; that Docker is two programs, a client and a daemon; and what a container shares with the host machine and why that determines security.

**Where you are coming from.** You bring nothing from this course: you have not installed Docker yet. You do bring what the course takes for granted: you use a terminal comfortably, you know what a process is (a program that is running) and what an HTTP server is. Perhaps you already wrote the `revisor` in Hábil's Go, Rust or TypeScript course. If not, this is enough: it is a program that queries a list of services at once and hands you a report of which ones are up, which are slow and which are down. What you probably do not bring is a precise idea of what a container is on the inside, and that idea is the one you will need every time something fails.

**What this lesson does not do.** It does not install anything (that is [Lesson 1](01-instalacion.md)) and it does not teach the Docker commands one by one (that starts in [Lesson 2](02-contenedores-dia-a-dia.md)). The programs in this lesson are *bash* scripts of ten to thirty lines that call `docker` and standard Linux tools such as `ps` and `uname`. You do not need to understand every option yet, although each one is explained: what matters is what they **print**. You run them after Lesson 1, once you have Docker.

**About the runs.** The outputs in this lesson were obtained on October 21, 2026 on a Mac with [Colima](https://github.com/abiosoft/colima), which starts a Linux virtual machine so that containers can run. That virtual machine has Ubuntu 24.04.4, which is the same base as Linux Mint 22, so **the scripts were run inside it** and that is where the "host" in the outputs appears: on your Mint, the host is your own computer and the same commands are typed exactly the same once you have done Lesson 1; what changes are the values specific to your machine, listed below. The Docker version inside that machine was 29.2.1 (client and daemon). The course was planned with 29.8.2 and, on the day of this run, the latest release was 29.9.2, from October 20, 2026, according to the [official release notes](https://docs.docker.com/engine/release-notes/29/). The release notes from 29.2.1 to 29.9.2 record no changes to the default capabilities, to the format of `docker version` or to `docker context inspect`, which are the commands and values this lesson depends on, so what you see here should match what you get; if a later version changes something, what the documentation for your version says takes precedence. Lesson 1 teaches you to see which one that is. What **does** change from one run to another, and it is flagged where it happens: the process numbers (PIDs), the namespace numbers, the times and, if your computer has an Intel or AMD processor, the word `arm64`, which on yours will say `amd64`. The programs are in [`programas/00-que-es-un-contenedor/`](../programas/00-que-es-un-contenedor), in the course repository, each one with its saved output next to it.

## By the end you will be able to

- Show with `ps` that a running container is just one more process of the host machine, and find its process number from outside.
- Explain with an example why a container is not a virtual machine, using the word *kernel*.
- Name the namespaces that Docker isolates and the two that, by default, it does not isolate.
- Read in `/sys/fs/cgroup` the memory, CPU and process limits of a container, and say what happens when there are none.
- Tell an image from a container, and predict what happens to a file written inside a container when that container is deleted.
- Explain what the `docker` client and the `dockerd` daemon do, and how they talk to each other.
- Say what a container shares with the host and why that turns "root inside the container" into a security matter.

## The why before the how

Imagine you finish the `revisor` and someone asks you to run it on a server. The most direct way is to copy the executable and launch it. It works, until it stops working: the server has a different version of some library, or port 8080 is already used by another program, or the `revisor` has a bug that makes it consume memory endlessly and drags down everything else that runs there. And when you finally discover that on your machine it did work, the phrase "it works on my machine" is no use to anyone.

Containers were born to solve that: to deliver a program **together with everything it needs to run**, and to run it **set apart** from the others, with limits. That is true and very useful. The problem begins when that description turns into a wrong mental image: "a container is a little computer inside mine." With that image, the opening scene is impossible: how could a little computer kill a program of the big one? With the right image, the scene is obvious.

The right image is this one, and it is the one Docker's own documentation uses: a container is an **isolated process** ([Docker, "What is a container?"](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)). It is not another computer. It is a program that runs on **your** computer, on **your** Linux kernel, around which the kernel puts up walls (so that it does not see what it should not) and a budget (so that it does not spend what it should not). If the walls are well built, the process believes it is alone. If there is no budget, it can spend everything.

The lesson has seven parts, in this order:

1. **A container is a process** (0.1): you look at it from inside and from outside.
2. **It is not a virtual machine** (0.2): the shared kernel and what that implies.
3. **The walls: namespaces** (0.3).
4. **The budget: control groups** (0.4), with the error of this lesson.
5. **Image versus container** (0.5).
6. **The client and the daemon** (0.6).
7. **What is shared and security** (0.7), and a little history for context (0.8).

With that destination in mind, this is what you will see in section 0.4, when a container with a memory limit tries to exceed it. It is what the container in the scene lacked:

```text
voy a comer memoria...
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

(`voy a comer memoria...` is "I'm going to eat memory..."; `código de salida` is "exit code"; `Lo que Docker anotó` is "What Docker noted down".)

## The concepts

### 0.1 A container is a process

#### 0.1.1 Looking at it from inside and from outside

The fastest way to get rid of the "little computer" idea is to start a container and look for it with the usual tools. The program `fig00_01.sh` starts a container that does nothing but sleep for five minutes (`sleep 300`), looks at it from inside, looks at it from outside and deletes it at the end:

```bash
#!/usr/bin/env bash
# fig00_01.sh — Un contenedor es un proceso del equipo anfitrión.
# Arranca un contenedor que solo duerme, lo mira desde dentro y desde fuera,
# y lo borra al final.
set -euo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-dormilon
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" "$IMAGEN" sleep 300 >/dev/null

echo "== 1. Desde DENTRO del contenedor: todos sus procesos"
docker exec "$NOMBRE" ps -o pid,user,args

echo
echo "== 2. Desde FUERA: el mismo proceso, visto por Docker"
PID_ANFITRION=$(docker inspect --format '{{.State.Pid}}' "$NOMBRE")
echo "PID en el anfitrión: $PID_ANFITRION"

echo
echo "== 3. Desde FUERA: el mismo proceso, visto por el sistema operativo"
ps -o pid,ppid,user,args -p "$PID_ANFITRION"

echo
echo "== 4. Quién es su padre en el anfitrión"
PPID_ANFITRION=$(ps -o ppid= -p "$PID_ANFITRION" | tr -d ' ')
ps -o pid,user,comm -p "$PPID_ANFITRION"
```

```text
$ ./fig00_01.sh
== 1. Desde DENTRO del contenedor: todos sus procesos
PID   USER     COMMAND
    1 root     sleep 300
    7 root     ps -o pid,user,args

== 2. Desde FUERA: el mismo proceso, visto por Docker
PID en el anfitrión: 836426

== 3. Desde FUERA: el mismo proceso, visto por el sistema operativo
    PID    PPID USER     COMMAND
 836426  836402 root     sleep 300

== 4. Quién es su padre en el anfitrión
    PID USER     COMMAND
 836402 root     containerd-shim
```

The numbers `836426` and `836402` change on every run; everything else comes out the same. Before reading the output, the lines of the script that matter. `set -euo pipefail` makes the script stop at the first error, instead of going on as if nothing had happened. `trap ... EXIT` schedules that, whatever happens, the container is deleted on exit: that way nothing is left behind on your machine, a habit that Lesson 2 turns into a rule. `docker run -d` starts the container "in the background" (*detached*) and gives it a name with `--name`; all the names in this course start with `curso-docker-` so that you can tell at a glance what is yours. `docker exec` runs a command **inside** a container that is already running, and `docker inspect` asks for data about a container; here, its process number on the host.

Now the output, block by block:

1. **From inside**, the container sees only two processes: `sleep 300`, which has number **1**, and the `ps` you just launched. It does not see your browser, or your terminal, or anything else that runs on your machine. From its point of view, it is the first process of the system.
2. **From outside**, Docker tells you that this same process has number 836426 on the host.
3. And **the host's operating system** confirms it with a normal `ps`, the same one you would use for any other program: there is `sleep 300`, running as `root`. There is no other computer. There is one more process in your machine's list.
4. Its parent is `containerd-shim`, a small program that Docker starts to look after each container, so that the container does not depend on the daemon staying up in order to keep running. (The full name is `containerd-shim-runc-v2`; `ps` cuts it short because the `comm` field only holds 15 characters. `containerd` and `runc` are placed in 0.6 and 0.8.)

🔑 **Read that again: the same process has two numbers.** Inside it is 1; outside it is 836426. They are not two processes: it is a single one, seen from two places. That it has two numbers is the first clue to how isolation works, and section 0.3 explains it.

#### 0.1.2 What it means that it is a process

That a container is a process is not a technical detail; it has consequences you will feel throughout the course:

- **It starts in milliseconds**, because starting a process is fast. There is no operating system to boot.
- **It dies like a process.** If the main program ends, the container ends. If the kernel kills it, the container dies. In Lessons 3 and 7 you will see that this includes signals: `docker stop` sends that process number 1 the same signal you would send with `kill`.
- **It spends like a process.** It uses your machine's memory and CPU, from the same pool as every other program. If nobody puts a limit on it, it has no limit.
- **You see it with your usual tools.** `ps`, `top` and the system monitor show it. That is useful for diagnosing and it is a warning: whoever has power over the host's processes has power over the containers.

> [!NOTE]
> 🔧 **Engineering note 0.1**
> You can tell a good mental image because it makes predictions. With "it is a little computer," you cannot predict that the container will show up in the host's `ps`. With "it is an isolated process," you predict it before running the program. Throughout the course, when something surprises you, first ask yourself what a normal process would do in that situation.

### 0.2 It is not a virtual machine

#### 0.2.1 Two distributions, a single kernel

A **virtual machine** is a program that imitates a complete computer: a processor, memory, disk and network card that are fake. Inside that fake computer an entire operating system boots, **with its own kernel**. That is why in a virtual machine you can run Windows on Linux or Linux on a Mac.

The **kernel** is the part of the operating system that is in charge of the hardware: it divides up the memory, decides which process uses the CPU at each instant, talks to the disk and the network. Everything else—the *shell*, `ls`, the package manager, the libraries—runs on top of it and asks it for things. That "on top" part is usually called **user space**.

A container does not bring a kernel. It brings only user space. `fig00_02.sh` proves it: it asks for the distribution and the kernel version on the host and in two containers of different distributions:

```bash
#!/usr/bin/env bash
# fig00_02.sh — Dos imágenes de dos distribuciones distintas, un solo núcleo.
set -euo pipefail
ALPINE=alpine:3.24.2
DEBIAN=debian:13.7-slim

distro() { grep '^PRETTY_NAME=' "$1" | cut -d= -f2 | tr -d '"'; }

echo "== El anfitrión"
echo "distribución: $(distro /etc/os-release)"
echo "núcleo:       $(uname -r)"

for IMAGEN in "$ALPINE" "$DEBIAN"; do
  echo
  echo "== Un contenedor de $IMAGEN"
  docker run --rm --name curso-docker-distro "$IMAGEN" sh -c '
    echo "distribución: $(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d "\"")"
    echo "núcleo:       $(uname -r)"'
done
```

```text
$ ./fig00_02.sh
== El anfitrión
distribución: Ubuntu 24.04.4 LTS
núcleo:       6.8.0-100-generic

== Un contenedor de alpine:3.24.2
distribución: Alpine Linux v3.24
núcleo:       6.8.0-100-generic

== Un contenedor de debian:13.7-slim
distribución: Debian GNU/Linux 13 (trixie)
núcleo:       6.8.0-100-generic
```

On your Mint, the first line will say `Linux Mint 22...` and the kernel will be your machine's; what matters is that **the three kernel numbers will be equal to each other**. The `/etc/os-release` file is where each distribution writes its name, and `uname -r` asks the kernel for its version. The `--rm` option asks Docker to delete the container as soon as it finishes.

Look at what happened. Inside the Alpine container, the file says you are on Alpine 3.24. Inside the Debian one, that you are on Debian 13. But when you ask **the kernel**, all three answer the same: `6.8.0-100-generic`, the host's. The files belong to Alpine or Debian; the kernel is a single one, shared. It is exactly what the documentation says: "if you run multiple containers, they all share the same kernel" ([Docker, "What is a container?"](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)).

From here comes a rule worth memorizing: **a "Debian image" is not Debian**. It is Debian's user space—its programs, its libraries, its package manager—running on whatever kernel you have. Almost always that is enough, because the Linux kernel's interface changes very little between versions. But if a program needs a feature from a newer kernel than yours, the image is not going to bring it.

#### 0.2.2 The proof in reverse: why a Mac needs a virtual machine

If a Linux container needs a Linux kernel, what happens on a computer that does not have one? What you saw in "About the runs" happens: one has to be provided. On macOS, Colima starts a Linux virtual machine and Docker runs inside it. Docker Desktop, Docker's desktop application, does the same with its own virtual machine: according to its documentation, "the Docker daemon and containers run in a lightweight Linux VM managed by Docker" ([Docker Desktop, Mac permission requirements](https://docs.docker.com/desktop/setup/install/mac-permission-requirements/)).

That virtual machine is not an accident; it is the confirmation of everything above. If containers brought their own kernel, they would not need it. Your Mint does not need it: the Linux kernel is already there, and containers run directly on it. That is one of the reasons the course uses Linux as its reference system: what you see is what is actually there, with no layer in between.

#### 0.2.3 The full comparison

| | Virtual machine | Container |
|---|---|---|
| What it is | a computer imitated by software | a process with walls and a budget |
| Kernel | its own | the host's, shared |
| What it boots | a complete operating system | a program |
| Startup time | seconds to minutes | milliseconds |
| Can run another operating system | yes (Windows on Linux, for example) | no: a Linux container needs a Linux kernel |
| What separates it from the host | the hypervisor, which imitates hardware | the kernel, which puts up the walls |
| If something escapes the isolation | it reaches the imitated machine | it reaches the kernel that everyone shares |

The last row is the one that matters for security, and we come back to it in 0.7.

As for startup time, you do not have to believe it: it is measured. `fig00_09.sh` creates, runs and deletes a container that does nothing (`true` is a program that ends immediately), five times in a row:

```bash
#!/usr/bin/env bash
# fig00_09.sh — Cuánto tarda en nacer, trabajar y morir un contenedor.
# Cinco veces seguidas, con una imagen que ya está descargada.
set -euo pipefail
IMAGEN=alpine:3.24.2
for i in 1 2 3 4 5; do
  inicio=$(date +%s%N)
  docker run --rm --name curso-docker-rapido "$IMAGEN" true
  fin=$(date +%s%N)
  echo "corrida $i: $(( (fin - inicio) / 1000000 )) ms"
done
```

```text
$ ./fig00_09.sh
corrida 1: 136 ms
corrida 2: 154 ms
corrida 3: 431 ms
corrida 4: 347 ms
corrida 5: 507 ms
```

These numbers always change: they depend on your machine and on what else it is doing at that moment. On another run on the same machine they came out between 135 and 194 ms. What is stable is the order of magnitude: **tenths of a second**, to create the container, start the process, wait for it and delete everything. A virtual machine takes that long just to begin loading its kernel.

### 0.3 The walls: namespaces

#### 0.3.1 What a namespace is

Back to the clue from 0.1: the same process is number 1 inside and 836426 outside. How can a process have two numbers? Because the Linux kernel has a feature called **namespaces**. A namespace is a private "view" of some system resource. Processes that are inside a namespace see their own version of that resource, and do not see the others'.

Docker says it bluntly: it uses "a technology called namespaces to provide the isolated workspace called the container" ([Docker, "What is Docker?"](https://docs.docker.com/get-started/docker-overview/)). There are eight kinds, and each one isolates a different thing. The list comes from the Linux manual ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)):

| Type | Name in `/proc` | What it isolates | What you see in a container |
|---|---|---|---|
| PID | `pid` | process numbers | its program is number 1 and it does not see the host's processes |
| Mount | `mnt` | mount points | it sees its own file tree, the image's, and not yours |
| Network | `net` | interfaces, addresses, ports | it has its own network and its own port 8080 |
| UTS | `uts` | the machine's name | it has its own *hostname* |
| IPC | `ipc` | communication between processes through shared memory | it does not mix with other programs' shared memory |
| Cgroup | `cgroup` | the root of the control groups | it sees its own group as if it were the root (0.4) |
| User | `user` | user and group numbers | **by default, it is not isolated**; it can be enabled (`userns-remap`, *rootless*; see below) |
| Time | `time` | certain system clocks | **by default, it is not isolated**; the `docker run` reference lists no option to isolate it |

The Network row explains something you will use from Lesson 2: two containers can listen on port 8080 at the same time without conflict, because each one has its own network. The Mount row explains why the Debian container saw Debian files even though your machine is Mint.

#### 0.3.2 Seeing it with your own eyes

Every Linux process has a `/proc/<number>/ns/` folder with one link for each type of namespace. What that link contains is the type and a number, for example `pid:[4026531836]`. The manual explains it like this: if two processes are in the same namespace, that number is the same ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)). So it is enough to compare numbers. That is what `fig00_03.sh` does: it reads the eight links of the host and of a container and puts them side by side:

```bash
#!/usr/bin/env bash
# fig00_03.sh — Los espacios de nombres (namespaces) del anfitrión y de un contenedor.
# Si el número entre corchetes coincide, los dos procesos comparten ese espacio.
set -euo pipefail
IMAGEN=alpine:3.24.2
TIPOS="cgroup ipc mnt net pid time user uts"

LISTA='for n in '"$TIPOS"'; do echo "$n $(readlink /proc/self/ns/$n)"; done'

ANFITRION=$(sh -c "$LISTA")
CONTENEDOR=$(docker run --rm --name curso-docker-ns "$IMAGEN" sh -c "$LISTA")

printf '%-7s %-20s %-20s %s\n' TIPO ANFITRION CONTENEDOR ¿IGUAL?
for n in $TIPOS; do
  a=$(echo "$ANFITRION"  | awk -v t="$n" '$1==t {print $2}')
  c=$(echo "$CONTENEDOR" | awk -v t="$n" '$1==t {print $2}')
  if [ "$a" = "$c" ]; then igual="sí, compartido"; else igual="no, aislado"; fi
  printf '%-7s %-20s %-20s %s\n' "$n" "${a#*:}" "${c#*:}" "$igual"
done
```

```text
$ ./fig00_03.sh
TIPO    ANFITRION            CONTENEDOR           ¿IGUAL?
cgroup  [4026531835]         [4026532382]         no, aislado
ipc     [4026531839]         [4026532379]         no, aislado
mnt     [4026531841]         [4026532377]         no, aislado
net     [4026531840]         [4026532383]         no, aislado
pid     [4026531836]         [4026532380]         no, aislado
time    [4026531834]         [4026531834]         sí, compartido
user    [4026531837]         [4026531837]         sí, compartido
uts     [4026531838]         [4026532378]         no, aislado
```

The numbers in brackets change from one machine to another and the container's change on every run; the `¿IGUAL?` ("EQUAL?") column comes out the same whenever you use Docker's default configuration (`sí, compartido` is "yes, shared"; `no, aislado` is "no, isolated"; `ANFITRION` is "HOST"; `CONTENEDOR` is "CONTAINER"). `/proc/self` is a shortcut that always points to the process reading it, and `readlink` shows where a link points.

Six walls and two gaps. The container has its own processes, its own file tree, its own network, its own machine name, its own shared memory and its own view of the control groups. But it shares with the host the clocks (`time`) and, above all, **the users** (`user`). That the user namespace is the same means that user number 0, `root`, is **the same `root`** inside and outside. You already saw it in 0.1: the `sleep 300` appeared on the host as belonging to `root`. Docker supports isolating users too, but it does not do so by default ([Docker Engine security](https://docs.docker.com/engine/security/)). All this holds for Docker in its normal mode, the one Lesson 1 installs: the daemon runs as `root` and without user remapping. There are two modes that change the story. With [`userns-remap`](https://docs.docker.com/engine/security/userns-remap/), the `root` inside is, on the host, a high, unprivileged user number; in [*rootless* mode](https://docs.docker.com/engine/security/rootless/), the daemon and its containers run inside an unprivileged user namespace. In both, the `user` row of the table would say "no, isolated." The machine used for these runs uses the normal mode: `docker info --format '{{.SecurityOptions}}'` printed `[name=apparmor name=seccomp,profile=builtin name=cgroupns]`, with neither `rootless` nor `userns`, and that is how you can check yours. That is half of the security story of 0.7.

> [!NOTE]
> 🔧 **Engineering note 0.2**
> A namespace **hides**; it does not **limit**. That the container does not see the host's processes does not stop it from spending all of its memory. The first is the work of namespaces; the second, of control groups. The opening scene is the confusion between the two.

### 0.4 The budget: control groups

#### 0.4.1 What a control group is

**Control groups** (almost always abbreviated *cgroups*) are the other half of the work. They are a kernel mechanism for placing processes into groups and distributing the system's resources among those groups—memory, CPU, number of processes, disk reads and writes—in a controlled way ([kernel documentation, cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)). Docker's security guide sums it up in one sentence: control groups "implement resource accounting and limiting" ([Docker Engine security](https://docs.docker.com/engine/security/)).

Each container lives in its own group. The kernel keeps count of how much that group spends and, if it has a limit, does not let it go past it. The limits can be read as text files in `/sys/fs/cgroup`. Three of them will appear throughout the course:

- `memory.max`: how much memory the group can use. If it reaches that limit and cannot free anything, the kernel calls the "out-of-memory killer" (*OOM killer*) **inside that group** ([cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)).
- `cpu.max`: two numbers, "how much time" and "how often." By default it is `max 100000`, which means no cap in each period of 100,000 microseconds (one tenth of a second).
- `pids.max`: how many processes the group can have at most.

#### 0.4.2 Without a limit there is no limit

The most important thing in this section is what Docker does **if you ask it for nothing**. The documentation is explicit: "by default, a container has no resource constraints" and can use as much as the kernel's scheduler allows ([Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/)). `fig00_04.sh` reads the three files in a container without limits and in another with limits:

```bash
#!/usr/bin/env bash
# fig00_04.sh — Los grupos de control (cgroups): lo que el núcleo deja gastar.
# Primero sin límites, después con límites de memoria, CPU y procesos.
set -euo pipefail
IMAGEN=alpine:3.24.2
LEER='for f in memory.max cpu.max pids.max; do printf "%-11s %s\n" "$f" "$(cat /sys/fs/cgroup/$f)"; done'

echo "== Sin límites (lo que Docker hace si no le pides nada)"
docker run --rm --name curso-docker-sin-limites "$IMAGEN" sh -c "$LEER"

echo
echo "== Con --memory 64m --cpus 0.5 --pids-limit 50"
docker run --rm --name curso-docker-con-limites \
  --memory 64m --cpus 0.5 --pids-limit 50 \
  "$IMAGEN" sh -c "$LEER"
```

```text
$ ./fig00_04.sh
== Sin límites (lo que Docker hace si no le pides nada)
memory.max  max
cpu.max     max 100000
pids.max    max

== Con --memory 64m --cpus 0.5 --pids-limit 50
memory.max  67108864
cpu.max     50000 100000
pids.max    50
```

This output is stable, with two conditions. The first, version 2 of the control groups, which is the one Ubuntu 24.04, the base of Mint 22, has (the machine used for these runs reports it: `stat -fc %T /sys/fs/cgroup` prints `cgroup2fs`). The second, that the `memory`, `cpu` and `pids` *controllers* are enabled, which are the kernel components that keep each count: in version 2 they are enabled one by one, and a file such as `memory.max` only appears in a group if its controller is enabled ([kernel documentation, cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)). On a normal Mint installation they are; to check, `cat /sys/fs/cgroup/cgroup.controllers` must include those three words (on the machine used for these runs it printed `cpuset cpu io memory hugetlb pids rdma misc`). If one is missing, Docker may warn about it with a `WARNING` at the end of `docker info` ([Docker, resource constraints](https://docs.docker.com/engine/containers/resource_constraints/)), the corresponding file does not exist inside the container and your output will not look like this one. Without limits, the three files say `max`: the container can use all of the machine's memory, all of its CPU and create as many processes as it wants. That was the container in the scene.

With limits, each `docker run` option turns into a number that the kernel enforces:

- `--memory 64m` became `67108864`, which is 64 × 1024 × 1024 bytes: exactly 64 MiB.
- `--cpus 0.5` became `50000 100000`: in each tenth of a second, the group can use the CPU for half of it, 50,000 microseconds. That is half a CPU.
- `--pids-limit 50` became `50`.

Notice the chain of responsibilities. You write an option in `docker run`; Docker translates it and writes it into a kernel file; the kernel is the one that enforces it. Docker does not watch the container: the one that watches is the kernel. That is why the limit is enforced even if the program inside is broken and burns through memory or processes without restraint. Mind what the limit does **not** promise: it bounds what the group consumes, but it does not protect the group, or you, from an attack aimed at the shared kernel; the layers in 0.7 take care of that.

#### 0.4.3 What happens when the limit is reached

A limit that is never reached teaches nothing. `fig00_05.sh` starts a container with 32 MiB of memory and no swap space, and asks it for something it cannot fulfill: `tail /dev/zero` reads an infinite file of zeros looking for the end of the last line, and since a line break never arrives, it keeps everything in memory without stopping:

```bash
#!/usr/bin/env bash
# fig00_05.sh — El error de esta lección: el núcleo mata al proceso que pasa su límite.
# El contenedor intenta llenar la memoria; tiene un tope de 32 MiB y sin swap.
set -uo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-gloton
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run --name "$NOMBRE" --memory 32m --memory-swap 32m \
  "$IMAGEN" sh -c 'echo "voy a comer memoria..."; tail /dev/zero'
echo "código de salida: $?"

echo
echo "== Lo que Docker anotó"
docker inspect --format 'OOMKilled={{.State.OOMKilled}}  ExitCode={{.State.ExitCode}}' "$NOMBRE"
```

```text
$ ./fig00_05.sh
voy a comer memoria...
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

This output is stable. `--rm` is not used here, on purpose: if Docker deleted the container when it finished, you could not ask it afterwards what happened to it. `--memory-swap 32m` sets the total of memory plus swap to the same value as the memory, that is, zero swap; without that, Docker lets the container use as much swap as memory (with `--memory 32m`, another 32 MiB, as long as the host has swap configured), so the process would survive longer and the OOM would arrive later ([Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/)).

The container printed its message, started eating memory and, on reaching 32 MiB, the kernel killed it inside its own group. The kernel did not have to pick anyone else: the scene's database, had it been there, would not have been the one chosen. The number **137** is the convention for saying "this process died from a signal": it is 128 plus the signal number, and signal 9 is `KILL`, the one that can be neither caught nor ignored. The convention was not invented by Docker: it is the shell's, whose manual says that, when a command ends because of signal N, *bash* uses 128+N as the exit code ([Bash manual](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html)); you can check it in any *bash*: `bash -c 'kill -9 $$'; echo $?` prints `137`. Docker records the same number in `ExitCode`, and `docker run` returns it as is, because any code other than 125, 126 and 127 is the container command's ([Docker, exit codes](https://docs.docker.com/engine/containers/run/)). And `OOMKilled=true` is Docker confirming that it was due to lack of memory. The section "The error you will see" tells you how to read this when it shows up without your having triggered it.

Now you can rewrite the scene precisely. The `revisor`'s container was in its own namespace—it did not see the database—but in a control group with no limit—it spent from the same pool. When the pool ran dry, the kernel had to kill someone **across the whole machine**, not only in the container's group, and it chose another. With `--memory`, the killer would have acted **inside the group** of the `revisor`, and only the `revisor` would have died. Lesson 2 sets limits from the first container for this reason.

### 0.5 Image versus container

#### 0.5.1 The template and the live copy

So far you have used two words as if they were interchangeable, and they are not. Docker's documentation defines them like this: an **image** is "a read-only template with instructions for creating a container," and a **container** is "a runnable instance of an image" ([Docker, "What is Docker?"](https://docs.docker.com/get-started/docker-overview/)).

A comparison that helps, if you come from programming: the image is like an executable on disk and the container is like the process that runs from it. From the same executable you can launch ten processes; from the same image you can create ten containers. If the process writes something in its memory, the executable on disk does not change.

The missing piece is where a container writes when it creates a file. The answer, according to Docker's storage documentation: an image is made of read-only **layers**, and when a container is created a thin **writable** layer is added on top, called the container layer. Everything the container changes goes into that layer. Several containers can share the same image, each with its own layer. And when the container is deleted, its layer is deleted with it, while the image underneath "remains unchanged" ([Docker, "Storage drivers"](https://docs.docker.com/engine/storage/drivers/)).

#### 0.5.2 Seeing it with your own eyes

`fig00_06.sh` creates two containers from the same image, writes a file in one, checks whether the other sees it, asks what changed in each and, at the end, deletes the first:

```bash
#!/usr/bin/env bash
# fig00_06.sh — Imagen contra contenedor: una plantilla, dos copias vivas.
set -euo pipefail
IMAGEN=alpine:3.24.2
A=curso-docker-uno
B=curso-docker-dos
trap 'docker rm -f "$A" "$B" >/dev/null 2>&1 || true' EXIT

echo "== La imagen antes de empezar"
docker image inspect --format 'id={{.Id}}' "$IMAGEN" | cut -c1-22

docker run -d --name "$A" "$IMAGEN" sleep 300 >/dev/null
docker run -d --name "$B" "$IMAGEN" sleep 300 >/dev/null

echo
echo "== Escribo un archivo en el contenedor uno"
docker exec "$A" sh -c 'echo "hola desde uno" > /tmp/nota.txt && cat /tmp/nota.txt'

echo
echo "== ¿Lo ve el contenedor dos?"
docker exec "$B" cat /tmp/nota.txt || echo "(el contenedor dos no tiene ese archivo)"

echo
echo "== Lo que cambió en cada contenedor respecto de su imagen (docker diff)"
echo "-- uno:"; docker diff "$A"
echo "-- dos:"; docker diff "$B"; echo "(nada)"

echo
echo "== Borro el contenedor uno y miro la imagen otra vez"
docker rm -f "$A" >/dev/null
docker image inspect --format 'id={{.Id}}' "$IMAGEN" | cut -c1-22
docker run --rm --name curso-docker-tres "$IMAGEN" sh -c 'cat /tmp/nota.txt 2>&1 || true'
```

```text
$ ./fig00_06.sh
== La imagen antes de empezar
id=sha256:294b683cb724

== Escribo un archivo en el contenedor uno
hola desde uno

== ¿Lo ve el contenedor dos?
cat: can't open '/tmp/nota.txt': No such file or directory
(el contenedor dos no tiene ese archivo)

== Lo que cambió en cada contenedor respecto de su imagen (docker diff)
-- uno:
C /tmp
A /tmp/nota.txt
-- dos:
(nada)

== Borro el contenedor uno y miro la imagen otra vez
id=sha256:294b683cb724
cat: can't open '/tmp/nota.txt': No such file or directory
```

The identifier `294b683cb724` is that of the `alpine:3.24.2` image for 64-bit ARM processors; on an Intel or AMD machine it will be different, but it will be **the same at the beginning and at the end** of the run, which is what matters. `docker diff` shows what a container changed with respect to its image: `A` means added and `C`, changed; the `/tmp` folder appears as changed because it now contains something new.

Read the output as a story in four moments:

1. The image has an identifier, a fingerprint of its content.
2. Container one writes `/tmp/nota.txt` and reads it without problems. Container two, made **from the same image**, does not have it: each one writes in its own layer.
3. `docker diff` confirms it: one added a file; two changed nothing.
4. Container one is deleted. The image has **the same identifier**: nothing the container did touched it. And a new container from that image does not have the note either. The file went away with the container.

There are two consequences for the rest of the course, and both matter. The first: **what is written inside a container is disposable**. If the `revisor` saves its report inside the container and someone deletes it, the report is gone. That is why Lesson 8, with volumes, exists. The second: **an image is not fixed by going into the container**. If you go in with `docker exec` to correct something, you correct that live copy, not the template; the next container is born without your fix. Images are changed by rebuilding them from their recipe, the `Dockerfile`, which is what you learn in Lesson 3.

### 0.6 The client and the daemon

#### 0.6.1 Two programs, not one

When you type `docker run`, it looks as if a single program does everything. It does not. Docker uses a **client-server** architecture: the `docker` program you type is only a **client**, and the real work is done by a **daemon** called `dockerd`, a program that runs in the background all the time. According to the documentation, the daemon "listens for Docker API requests and manages Docker objects"—images, containers, networks and volumes—and client and daemon talk to each other "using a REST API, over UNIX sockets or a network interface" ([Docker, "What is Docker?"](https://docs.docker.com/get-started/docker-overview/)).

A **UNIX socket** is a special file that lets two programs on the same machine send each other messages. The Docker daemon's is, by default, at `/var/run/docker.sock`. And you already saw whose job it is to create the containers: the `containerd-shim` that appeared as the parent of `sleep` in 0.1 is part of the chain the daemon sets in motion. You ask the client; the client asks the daemon; the daemon, with the help of other components, asks the kernel for the namespaces and the control groups.

`fig00_07.sh` shows both halves and what happens when the client cannot find the daemon:

```bash
#!/usr/bin/env bash
# fig00_07.sh — El cliente y el daemon son dos programas distintos.
set -uo pipefail

echo "== Las dos versiones: la del cliente y la del daemon"
docker version --format 'cliente: {{.Client.Version}} ({{.Client.Os}}/{{.Client.Arch}})
daemon:  {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})'

echo
echo "== Por dónde habla el cliente con el daemon"
docker context inspect --format '{{.Endpoints.docker.Host}}'

echo
echo "== El cliente apuntando a un daemon que no existe"
DOCKER_HOST=unix:///tmp/curso-docker-no-hay-daemon.sock docker ps
echo "código de salida: $?"
```

```text
$ ./fig00_07.sh
== Las dos versiones: la del cliente y la del daemon
cliente: 29.2.1 (linux/arm64)
daemon:  29.2.1 (linux/arm64)

== Por dónde habla el cliente con el daemon
unix:///var/run/docker.sock

== El cliente apuntando a un daemon que no existe
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
código de salida: 1
```

On your machine the versions change and, if it is Intel or AMD, it will say `amd64`. `docker context inspect` shows which daemon the client points to, and the `DOCKER_HOST` environment variable lets you point it at another; here, on purpose, at one that does not exist.

Three things learned from this output:

1. **`docker version` reports two versions**, because there are two programs. They almost always match, but they do not have to: on the Mac used for these runs, the macOS client was 29.8.2 and the virtual machine's daemon, 29.2.1. When a command behaves oddly, the first question is which of the two versions is causing it.
2. **The client and the daemon talk through the *socket***. It is an entry point, and whoever can open it controls the daemon.
3. **Without a daemon, the client cannot ask Docker for anything.** The commands that do not need the daemon, such as `docker --version` or `docker context ls`, do respond. The message says that: it could not connect to the Docker API at that path; check that the path is correct and that the daemon is running. On your Mint you will see this message with the path `/var/run/docker.sock` the day the Docker service is stopped.

#### 0.6.2 Why it matters to know this

It may seem like an architectural curiosity, but it is not. The daemon runs as `root`: the security guide says it "requires `root` privileges," unless you enable *rootless* mode, and that is why "only trusted users" should be allowed to control it ([Docker Engine security](https://docs.docker.com/engine/security/)). If you can ask the daemon for things, you can ask it to create a container with your machine's root folder mounted inside, and it will do it as `root`. That is why the installation documentation warns that the `docker` group "grants root-level privileges" to the user ([Docker, Linux post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)). Lesson 1 puts you in that group and makes you look at the consequence head on. And Lesson 2 forbids you, with this same argument, from mounting the daemon's *socket* inside a container: that would give the container the key to your machine.

### 0.7 What is shared and why it determines security

#### 0.7.1 Root inside is root outside

You now have all the components for the most serious question of the lesson: how separate is a container from the host? `fig00_08.sh` asks who the user is inside, who owns the process as seen from outside, and what powers it has:

```bash
#!/usr/bin/env bash
# fig00_08.sh — Lo que el contenedor comparte con el anfitrión: el usuario y el núcleo.
set -euo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-quien
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== Dentro del contenedor, ¿quién soy?"
docker run --rm --name curso-docker-id "$IMAGEN" id

echo
echo "== Y desde el anfitrión, ¿de quién es ese proceso?"
docker run -d --name "$NOMBRE" "$IMAGEN" sleep 300 >/dev/null
PID=$(docker inspect --format '{{.State.Pid}}' "$NOMBRE")
ps -o uid,user,args -p "$PID"

echo
echo "== Las capacidades efectivas de ese root (máscara en hexadecimal)"
echo "$(docker run --rm --name curso-docker-cap1 "$IMAGEN" grep CapEff /proc/self/status | cut -f2)  contenedor, por omisión"
echo "$(docker run --rm --name curso-docker-cap2 --cap-drop ALL "$IMAGEN" grep CapEff /proc/self/status | cut -f2)  contenedor, con --cap-drop ALL"
echo "$(grep CapEff /proc/1/status | cut -f2)  proceso 1 del anfitrión (root)"
```

```text
$ ./fig00_08.sh
== Dentro del contenedor, ¿quién soy?
uid=0(root) gid=0(root) groups=0(root),0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)

== Y desde el anfitrión, ¿de quién es ese proceso?
  UID USER     COMMAND
    0 root     sleep 300

== Las capacidades efectivas de ese root (máscara en hexadecimal)
00000000a80425fb  contenedor, por omisión
0000000000000000  contenedor, con --cap-drop ALL
000001ffffffffff  proceso 1 del anfitrión (root)
```

This output is stable with Docker's default configuration. The last line depends on how many capabilities your kernel knows; with one from the 6.8 series it comes out the same.

The first two blocks say the same thing from both sides: inside the container you are user 0, `root`, and outside that process **also** belongs to user 0. It is not a toy `root` with the same name: since the user namespace was not isolated (0.3), it is the same user number for the same kernel. If that process managed to get out of its walls—through a kernel bug, through a host folder mounted carelessly, through the daemon's *socket*—it would reach the host as `root`.

#### 0.7.2 A trimmed root: capabilities

So, is a container as dangerous as a program running as `root` on your machine? Not quite, and the third block explains why. Linux divides `root`'s powers into separate units called **capabilities**, which can be enabled and disabled one by one ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Changing a file's owner is one; opening a port below 1024, another; loading modules into the kernel, another.

The `CapEff` line of `/proc/<pid>/status` says which capabilities a process has in effect, as a bit mask in hexadecimal. The host's process 1, which is a real `root`, has `000001ffffffffff`: the 41 capabilities this kernel knows, all enabled. The container's `root` has `00000000a80425fb`, which is **14**. Decoding that mask with the host's `capsh` tool gives exactly the fourteen that Docker's documentation lists as allowed by default: `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `FSETID`, `KILL`, `SETGID`, `SETUID`, `SETPCAP`, `NET_BIND_SERVICE`, `NET_RAW`, `SYS_CHROOT`, `MKNOD`, `AUDIT_WRITE` and `SETFCAP` ([Docker, "Running containers"](https://docs.docker.com/engine/containers/run/)). Docker uses a list of what is allowed, not of what is forbidden: it removes everything and leaves only that ([Docker Engine security](https://docs.docker.com/engine/security/)). And with `--cap-drop ALL` you can take away even those fourteen, as the second line shows; Lesson 7 teaches you to remove the ones the `revisor` does not use.

The opposite option exists and is worth recognizing so you know to avoid it: `--privileged` "gives all capabilities to the container" and also access to all of the host's devices ([Docker, "Running containers"](https://docs.docker.com/engine/containers/run/)). With it, hardly any wall is left.

#### 0.7.3 The map of what is shared

| What the container has of its own, by default | What it shares with the host, by default |
|---|---|
| its processes and its process numbers | **the kernel**, the same for all containers |
| its file tree (its image's and its layer) | **the users**: `root` inside is user 0 outside |
| its network, its ports, its machine name | the system clocks |
| its view of the control groups | **the memory, the CPU and the disk**, if you put no limits |
| | **what you mount or publish to it**: folders, ports, the *socket* |

The right-hand column is the list of what you have to look after. Each lesson of the course closes one part: Lesson 2 sets limits and publishes ports only on `127.0.0.1`; 3 stops using `root` with `USER`; 7 removes capabilities and makes the file system read-only; 8 looks after what is mounted. It is not paranoia: it is the difference between a process with walls and a process with paper walls.

> [!NOTE]
> 🔧 **Engineering note 0.3**
> In a virtual machine, to escape you have to break the hypervisor, which imitates simple hardware. In a container, to escape it is enough to find a bug in the kernel, which is enormous and which all containers share. That is why containers are hardened with several layers at once (no `root`, no unneeded capabilities, with limits) and no single one is trusted.

### 0.8 Where all this came from

Docker did not invent any of the above. The components belong to the Linux kernel and arrived little by little. Docker's security guide recounts it: namespaces entered the kernel between versions 2.6.15 and 2.6.26, the latter from July 2008, and control groups began in 2006 and were merged in version 2.6.24 ([Docker Engine security](https://docs.docker.com/engine/security/)). For years there were tools that used them, but they were hard to use.

What changed in 2013 was the **way of using them**. On March 15 of that year, in a five-minute lightning talk at the PyCon conference, Solomon Hykes explained that at his company they used Linux containers, that it was complicated and that this was why they had not talked about it, "until now: Docker" ([PyCon US 2013, "The future of Linux Containers"](https://pyvideo.org/pycon-us-2013/the-future-of-linux-containers.html)). Docker put together the kernel's components with two ideas of its own: an image format that can be shared and commands that anyone understands.

Two years later, on June 22, 2015, Docker, CoreOS and other companies founded the **Open Container Initiative** (OCI), and Docker donated to it its format and its program for creating containers, `runc` ([OCI, "About"](https://opencontainers.org/about/overview/)). Today the OCI maintains three specifications: the runtime one, the image format one and the distribution one. For you that means something practical: the image you build in this course is not "a Docker image" locked inside Docker, it is an OCI image, and that is why the Kubernetes cluster of the next course can run it without Docker. Incidentally, `runc` is the program that appears at the end of the name `containerd-shim-runc-v2` that you saw in 0.1.

### 0.9 What comes in the rest of the course

With this lesson's map, each following lesson is a piece whose place you already know:

- **Lesson 1** installs the client, the daemon and the components in between on your Mint.
- **Lesson 2** handles isolated processes: starting them, looking at them, giving them a budget (0.4) and deleting them.
- **Lessons 3, 4 and 5** build the `revisor`'s **image** (0.5): its recipe, its layers and how to make it small.
- **Lesson 6** separates configuration and secrets from the image.
- **Lesson 3** measures what happens to the `docker stop` signal depending on how the `CMD` is written; **Lesson 7** deals with process number 1 (0.1) and with trimming its powers (0.7).
- **Lesson 8** solves the container layer being disposable (0.5) and connects containers over a network (0.3).
- **Lesson 9** describes all of that in a single file, and **10** delivers the OCI image (0.8) ready for Kubernetes.

## The error you will see

This lesson has one main error, that of the container the kernel kills, and one secondary, that of the client without a daemon. Both come from earlier sections.

**The main error: code 137 and `OOMKilled=true`.** It is the one from `fig00_05.sh`:

```text
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

It reads like this: the process did not end on its own; signal 9 killed it (`137 = 128 + 9`), and Docker noted that the cause was lack of memory. The treacherous part is that in real life the container **does not warn you**: it prints nothing, it simply disappears, and if it has a restart policy it starts again and dies again and again. When you see a 137, the first question is `docker inspect --format '{{.State.OOMKilled}}' <container>`. If it says `true`, there are two possible fixes, depending on the case: raise the memory limit, if the program really needs more; or fix the program, if it is spending too much. What you do **not** do is remove the limit "so that it does not die": that does not fix it, it only changes who dies, as in the scene.

**The secondary error: the client that cannot find the daemon.**

```text
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
```

It reads from left to right: the client could not connect to the Docker API at that path; it suggests you check the path and that the daemon is running; and at the end comes the technical cause, that the *socket* file does not exist. On your Mint, with the path `/var/run/docker.sock`, it almost always means the Docker service is stopped. If instead of `no such file or directory` it says `permission denied`, the daemon is there, but your user does not have permission to talk to it: that is a matter for Lesson 1.

## The security habit of the lesson

**Know what a container shares with the machine, and do not trust what it does not isolate.** The container shares the kernel, the users and, if you put no limits on it, the memory and the CPU. This habit prevents two concrete accidents. The first is the scene's: a container with no limit that brings down other programs on the same machine. The second is more serious: treating a container as if it were a separate machine and giving it things from the host—the daemon's *socket*, the root folder mounted, `--privileged`—thinking that "it's harmless in there." What runs inside is a `root` process on your own kernel. Whatever you give it, you give to that process.

## Common mistakes

**Saying "it is like a lightweight virtual machine."** It is the most repeated phrase and the one that does the most harm, because it leads you to expect an isolation that does not exist. A container is an isolated process; a virtual machine is an imitated computer. They look alike from outside and differ in what matters when something fails.

**Running containers with no limits "because my machine has plenty of memory."** By default there is no limit, and what is plentiful today is not plentiful the day the program has a bug. The limit is not for the normal case; it is for the bad day.

**Going into the container to "fix" something.** What you change with `docker exec` lives in the container layer and goes away with it. The fix is made in the image's recipe and rebuilt.

**Saving important data inside the container.** For the same reason: the container layer is disposable. Data that must survive goes in volumes (Lesson 8).

**Assuming `root` inside is harmless.** It is user 0 of the same kernel, with 14 capabilities enabled. Less than the host's `root`, but much more than a normal user. From Lesson 3 on, the `revisor` does not run as `root`.

**Believing that an Ubuntu or Debian image brings that complete operating system.** It brings its user space. The kernel is yours. If your kernel does not support something, neither does the image.

**Confusing the client with the daemon.** When a command fails, knowing whether the problem is in the client (version, configuration, `DOCKER_HOST`) or in the daemon (stopped, no permissions, another version) saves hours of looking in the wrong place.

## Exercises

The exercises in this lesson do not need Docker to be answered: the first and the fourth are reasoning, and the second and the third are answered **before** running anything and checked after Lesson 1. Write your predictions in the [logbook](bitacora.md) before looking at the solutions; comparing them is half of the learning.

### Exercise 1 — The `revisor`'s night (project)

Go back to the opening scene. Answer in your own words, using what you learned:

1. Why did the `revisor`'s container not "see" the database, yet manage to kill it?
2. Which `docker run` option would have prevented the database from dying, and who would have died in its place?
3. If at that moment you had run `docker inspect` on the `revisor`'s container, what would you expect to see in `OOMKilled`? Think carefully: who killed whom?

### Exercise 2 — Same or different?

For each pair, predict whether the value comes out **the same** or **different**. Assume Docker's default configuration.

1. `uname -r` on your Mint and inside a `debian:13.7-slim` container.
2. `cat /etc/os-release` on your Mint and inside that same container.
3. `readlink /proc/self/ns/net` on your Mint and inside a container.
4. `readlink /proc/self/ns/user` on your Mint and inside a container.
5. The process number of the main program seen inside the container, and seen from the host.
6. The identifier of an image before and after deleting a container that wrote files.

### Exercise 3 — Predict the `memory.max`

Predict which number appears in `/sys/fs/cgroup/memory.max` inside each of these containers, and then check it by changing the options of `fig00_04.sh`:

1. `docker run --rm alpine:3.24.2 cat /sys/fs/cgroup/memory.max`
2. `docker run --rm --memory 128m alpine:3.24.2 cat /sys/fs/cgroup/memory.max`
3. `docker run --rm --memory 1g alpine:3.24.2 cat /sys/fs/cgroup/memory.max`

And one on CPU: what will `cpu.max` say with `--cpus 1.5`?

### Exercise 4 — Explain it in five sentences

A colleague tells you: "I installed Docker to have an Ubuntu virtual machine inside my Mint." Explain to them in five sentences at most what they actually have, using the words *process*, *kernel*, *namespace*, *control group* and *image*. Without looking at the lesson.

## Solutions

### Solution 1

1. Because the container was in its own **namespaces**: with the process one (`pid`) it did not see the host's processes, the database among them. But seeing and spending are different things: without a limit in its **control group**, it spent from the same memory as the whole machine. When it ran out, the kernel had to kill someone across the whole system, and it chose the database.
2. `--memory` (for example, `--memory 256m`; the number depends on how much the `revisor` really needs). With that limit, on reaching the cap the kernel would have acted **inside the group** of the container, and the one that would have died is the `revisor` itself, with code 137 and `OOMKilled=true`. The database would not even have found out.
3. Most likely `false`. With no limit of its own, the container did not reach a cap of **its** group: what ran out was the memory of the whole machine, and the kernel killed the database, which is not a container. The `revisor` stayed alive. It is exactly what makes the scene deceptive: the culprit does not carry the mark, the victim does (and in the system log, not in Docker).

### Solution 2

1. **Same.** The kernel is a single one, shared (fig00_02).
2. **Different.** The file comes from the image, which brings Debian's user space (fig00_02).
3. **Different.** The network is isolated: each container has its own `net` namespace (fig00_03).
4. **Same.** By default, Docker does not isolate users (fig00_03). That is why `root` inside is user 0 outside (fig00_08).
5. **Different.** Inside it is 1; outside, any number, like the 836426 of fig00_01. It is the same process seen from two process namespaces.
6. **Same.** What the container wrote lived in its own layer and went away with it; the image did not change (fig00_06).

If you got 4 wrong, it is the most common mistake and the most important one: it is the reason for the whole security block of the course.

### Solution 3

Values checked on the same machine and the same Docker version as the lesson:

1. `max`: without `--memory` there is no limit.
2. `134217728`, which is 128 × 1024 × 1024.
3. `1073741824`, which is 1024 × 1024 × 1024. Docker interprets the `g` as gibibytes (powers of 1024), just like the `m` as mebibytes.

With `--cpus 1.5`, `cpu.max` says `150000 100000`: in each period of 100,000 microseconds, the group can use 150,000 microseconds of CPU, spread among the processor's cores. One and a half CPUs.

### Solution 4

One possible answer: "You do not have a virtual machine; you have a program that creates isolated **processes**. Those processes run on your Mint's **kernel**, the same one for all of them, and that is why they start in tenths of a second. **Namespaces** put walls around them so that they see their own processes, files and network, and **control groups** give them a memory and CPU budget, if you ask for it. The "Ubuntu" part comes from the **image**: it brings Ubuntu's programs and libraries, but not its kernel. And since the `root` user inside is the same user number as the one outside, it has to be treated with care."

## How I know I got it

There is nothing to build in this lesson, so the list mixes understanding and, after Lesson 1, checking. Tick each point only if you can do it **without looking at the text again**:

- [ ] You explain in one minute why a container is not a virtual machine, and the word *kernel* appears in your explanation.
- [ ] You name the six namespaces that Docker isolates by default and the two that it does not.
- [ ] You say what `memory.max` and `cpu.max` contain without limits, and what `50000 100000` means.
- [ ] You explain what code 137 and `OOMKilled=true` mean, and what you must **not** do when they appear.
- [ ] You explain what happens to a file written inside a container when that container is deleted, and why the image does not change.
- [ ] You draw the path of `docker run`: client → *socket* → daemon → kernel.
- [ ] You say why the `docker` group is equivalent to `root`.
- [ ] After Lesson 1, you run the nine scripts in [`programas/00-que-es-un-contenedor/`](../programas/00-que-es-un-contenedor) and your outputs match those in this lesson in what each section marks as stable. What is not compared, because it changes from one machine or one run to another: process numbers, namespace numbers, times, versions and architecture; and, if your Docker runs in *rootless* mode or with user remapping, or lacks some control group controller, the differences that 0.3 and 0.4.2 told you to expect. And when you finish, `docker ps -a --filter name=curso-docker-` shows nothing: you left nothing behind.
- [ ] You wrote down in your logbook what you believed a container was before this lesson.

## Summary

Answer without looking at the lesson:

1. What is a container, in three words? Why does it appear in the host's `ps`?
2. What does a virtual machine have that a container does not? Why does a Mac need a virtual machine to run Linux containers?
3. What does a namespace do? Give three examples of what it isolates.
4. What does a control group do? What limit does a container have if you ask for none?
5. What do 137 and `OOMKilled=true` mean?
6. What is an image and what is a container? Where does a container write its files and what happens to them when it is deleted?
7. What do the `docker` client and the `dockerd` daemon do, and how do they talk to each other?
8. Why is `root` inside a container a security matter, and what trims it?

## Sources

All consulted on October 21, 2026.

- [Docker, "What is a container?"](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/): the definition of a container as an isolated process and the comparison with virtual machines.
- [Docker, "What is Docker?"](https://docs.docker.com/get-started/docker-overview/): the client-server architecture, the daemon, the definitions of image and container, and the use of namespaces.
- [Docker Engine security](https://docs.docker.com/engine/security/): namespaces, control groups, the daemon's attack surface, capabilities and user namespaces; also the dates in 0.8.
- [Docker, "Resource constraints"](https://docs.docker.com/engine/containers/resource_constraints/): that a container has no limits by default, and the `--memory`, `--memory-swap` and `--cpus` options.
- [Docker, "Running containers"](https://docs.docker.com/engine/containers/run/): the fourteen capabilities allowed by default and what `--privileged` does.
- [Docker, "Storage drivers"](https://docs.docker.com/engine/storage/drivers/): the read-only layers and the container layer.
- [Docker, Linux post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/): the warning about the `docker` group.
- [Docker Desktop, Mac permission requirements](https://docs.docker.com/desktop/setup/install/mac-permission-requirements/): Docker Desktop's Linux virtual machine.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): the versions and dates in "About the runs."
- [namespaces(7), Linux manual](https://man7.org/linux/man-pages/man7/namespaces.7.html): the eight types of namespaces and the `/proc/<pid>/ns` links.
- [capabilities(7), Linux manual](https://man7.org/linux/man-pages/man7/capabilities.7.html): privileged processes and capabilities.
- [Control Group v2, Linux kernel documentation](https://docs.kernel.org/admin-guide/cgroup-v2.html): `memory.max`, `cpu.max` and `pids.max`.
- [Open Container Initiative, "About"](https://opencontainers.org/about/overview/): the founding of the OCI and its three specifications.
- [PyCon US 2013, "The future of Linux Containers"](https://pyvideo.org/pycon-us-2013/the-future-of-linux-containers.html): the talk in which Docker was presented.
- [Colima](https://github.com/abiosoft/colima): the tool with which the programs were run on macOS.

### Terms in this lesson

| | |
|---|---|
| **host** (*anfitrión*) | the machine where the containers run; in the course, your Linux Mint |
| **layer** (*capa*) | each of the read-only parts of an image; the container adds a layer of its own to write in |
| **capability** (*capacidad*) | each of the powers into which Linux divides the `root` user |
| **client** | the `docker` program you type; it sends requests to the daemon |
| **container** | an isolated process created from an image |
| **daemon** | a program that runs in the background; Docker's is called `dockerd` |
| **namespace** (*espacio de nombres*) | a private view of a system resource (processes, network, files...) |
| **user space** (*espacio de usuario*) | everything that runs on top of the kernel: programs, libraries, *shell* |
| **control group** (*cgroup*, *grupo de control*) | a kernel mechanism that counts and limits the resources of a group of processes |
| **image** | a read-only template from which containers are created |
| **virtual machine** (*máquina virtual*) | a computer imitated by software, with its own kernel |
| **kernel** (*núcleo*) | the part of the operating system that is in charge of the hardware |
| **OCI** | *Open Container Initiative*, the open standard for images and containers |
| **OOM killer** | the part of the kernel that kills processes when memory runs out |
| **UNIX *socket*** | a special file through which two programs on the same machine send each other messages |

---

**Next:** [Lesson 1 — Installing Docker on your Linux Mint](01-instalacion.md)
