# Lesson 1 — Installing Docker on your Linux Mint

It is 9:40 on a Monday and the demo with the team is at 11. You are supposed to show the `revisor` running in a container, and your Linux Mint still has no Docker. You open the first tutorial that shows up, copy five commands, and the fourth answers in red: `E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.` You try another tutorial; that one installs a package called `docker.io` from the software store, and it seems to work, until `docker compose` says it does not exist. At 10:25 you find a third tutorial that recommends, to get rid of the `permission denied` you now get on every command, giving `777` permissions to the *socket* file. It works. And you have just handed `root` on your computer to any program that runs on it. None of the three tutorials told you why each thing happened. This lesson does the installation once, in order, with every error triggered on purpose and explained, so that next time it takes you twenty minutes and not a whole morning.

**Time:** 90 min

**What you build:** the course environment. Docker Engine installed on your Linux Mint from Docker's official repository, your user in the `docker` group knowing what that means, and your first container, `hello-world`. It comes with seven short diagnostic and verification programs in [`programas/01-instalacion/`](../programas/01-instalacion).

**What you learn:** which pieces you install and what each one is for; why Linux Mint is not an official Docker platform and what to do about it (the key word is `UBUNTU_CODENAME`); removing the packages that conflict with the official ones; how a repository is added to `apt` along with its key; how to verify that the installation works; and why joining the `docker` group is equivalent to having `root`.

**Where you are coming from.** From [Lesson 0](00-que-es-un-contenedor.md) you bring the map: a container is an isolated process running on your machine's kernel; Docker is two programs, the `docker` client and the `dockerd` daemon, which talk over a UNIX *socket* at `/var/run/docker.sock`; and the daemon runs as `root`. This lesson installs those pieces and makes you look that last sentence in the eye. In general, the course assumes you are comfortable with a terminal and know what `sudo` is. You do not need to have used `apt` beyond `apt install`: what you need from it is explained here.

**What this lesson does not do.** It does not teach Docker commands one by one: that is the subject of [Lesson 2](02-contenedores-dia-a-dia.md). It does not install Docker Desktop, Docker's desktop application, and section 1.1 says why. It does not install Docker in *rootless* mode (without `root`), although 1.9 explains what it is and when it would make sense. The `revisor` does not appear yet: this lesson prepares the machine where it will run, and packaging it starts in Lesson 3. And it does not cover other distributions: if you use Ubuntu, Debian, or Fedora, the [official documentation](https://docs.docker.com/engine/install/) has a guide for each one, and what you learn here will help you read it.

**About the runs.** This lesson differs from the others in one respect, and it is worth saying up front: **the installation itself was not run on a Linux Mint**, because the machine on which the course was written is a Mac. So as not to give you made-up output, every output block in this lesson says where it comes from, with one of these three labels:

| Label | What it means |
|---|---|
| **Real run · simulated Mint** | Actually run, on October 21, 2026, in an Ubuntu 24.04 container for `amd64` (the base of Mint 22, on the architecture of an Intel or AMD machine) that was given the `/etc/os-release` file **from Linux Mint 22.3**, taken from the official `base-files` package in the [Linux Mint repository](http://packages.linuxmint.com/) (version `13ubuntu10mint22.3.0`; the copy is in `programas/01-instalacion/os-release-mint-22.3.txt`). That file is the only thing that sets Mint apart in the installation steps, which is why the simulation is faithful where it matters. What is **not** the same: the container does not have Mint's own repositories, so your `apt update` runs will also show lines from `packages.linuxmint.com`; and packages that a full desktop already ships with (`curl`, for example) had to be installed in the container. Before running the scripts, `sudo` was installed in the container; your Mint already has it. |
| **Real run · virtual machine** | Actually run, the same day, in the Ubuntu 24.04.4 (arm64) virtual machine that [Colima](https://github.com/abiosoft/colima) starts on the Mac. On that machine, Docker 29.2.1 is installed **with the same official packages** you install (`docker-ce`, `containerd.io`, and company, from `download.docker.com`), so the post-installation checks look the same. What changes on your machine: the versions, and `arm64` will say `amd64`. |
| **From the documentation** | Not run: it is the text of the [official installation guide for Ubuntu](https://docs.docker.com/engine/install/ubuntu/) or of the [post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/), consulted on October 21, 2026. It is used only where there was no honest way to run it. |

The versions: the course was planned with Docker Engine 29.8.2 and Compose v5.6.0 (measured on October 7, 2026). On the day of these runs, the official repository offered **29.9.2**, from October 20, 2026 ([release notes](https://docs.docker.com/engine/release-notes/29/)), with Compose 5.6.0 and Buildx 0.38.1, and that is what you would have installed that day; the virtual machine used for the runs had 29.2.1. Nothing this lesson teaches changes between those versions, and in 1.7 you learn how to see yours. The programs are in [`programas/01-instalacion/`](../programas/01-instalacion), each with its saved output next to it.

## By the end you will be able to

- Read `/etc/os-release` and say which Ubuntu codename corresponds to your Mint, and why that one and not Mint's.
- Remove the packages that conflict with Docker Engine and explain why they conflict.
- Add Docker's official repository to `apt`, explaining what each line is for, including the key.
- Install the five Docker Engine packages and name what each one does.
- Verify with four commands that the service is running, which version you have, and that you can create a container.
- Read the error `permission denied while trying to connect to the docker API` and fix it by adding your user to the `docker` group.
- Show with one command why the `docker` group is equivalent to `root`, and name two alternatives.

## The why before the how

Installing a program on Linux is usually one line: `sudo apt install something`. Docker can be installed that way—your Mint offers a package called `docker.io`—and Docker's official guide asks you to do exactly the opposite: **remove it**. Why all the ceremony?

Because there are two sources of Docker packages and they are not the same. The first is your distribution: Ubuntu (and therefore Mint) packages Docker under its own names, at its own pace, and often in a version that lags behind. The second is Docker, the company, which publishes its packages in its own repository, `download.docker.com`, on the same day it releases each version. The official guide calls the former "unofficial" and asks you for the latter ([Docker, install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)). This course uses the official ones for a practical reason: everything it teaches—the Compose *plugin*, the Buildx builder, the versions mentioned—was measured with them, and what you read in Docker's documentation refers to them.

The second reason for the ceremony is Mint itself. Mint is built on Ubuntu, but it is not Ubuntu, and Docker does not officially support it. That does not mean it does not work: it means that, at one exact point in the installation, you have to tell `apt` to behave as if you were Ubuntu. It is a single line, and it is the one that broke the first tutorial in the opening scene.

And the third is security. Once installed, the daemon runs as `root` and listens on a *socket*. Whoever can write to that *socket* controls the daemon, and whoever controls the daemon controls your machine. That is why the installation ends with a decision that you make, knowing what you are deciding: who can talk to the daemon.

The lesson follows the order in which you would do the installation:

1. **What you are going to install** (1.1).
2. **Mint is not Ubuntu: the codename** (1.2).
3. **Before installing: the firewall** (1.3).
4. **Removing what conflicts** (1.4).
5. **The official repository**, with the Mint error triggered and fixed (1.5).
6. **Installing the packages** (1.6) and **verifying** (1.7).
7. **The `docker` group** (1.8) and **why it is equivalent to `root`** (1.9).
8. **Upgrading and uninstalling** (1.10).

With that destination in mind, this is what you will see at the end of 1.7, when everything is in place (real run · virtual machine):

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

## The concepts

### 1.1 What you are going to install

#### 1.1.1 The five pieces

The official guide installs five packages with a single command. It is worth knowing what each one is before installing them, because each one corresponds to a piece of the map from Lesson 0:

| Package | What it brings | On the map from Lesson 0 |
|---|---|---|
| `docker-ce` | the daemon, `dockerd` (*CE* stands for *Community Edition*, the free and open edition) | the server that does the work |
| `docker-ce-cli` | the client, the `docker` command you type | the client |
| `containerd.io` | `containerd`, which manages containers underneath the daemon, and `runc`, which creates them | the chain that ends in the `containerd-shim-runc-v2` you saw as a container's parent |
| `docker-buildx-plugin` | Buildx, the image builder | you will use it when you write your first Dockerfile |
| `docker-compose-plugin` | Compose, which starts several containers from a file | the `docker compose` subcommand |

The last two are *plugins*: they are not programs you call by name, but subcommands added to the client. That is why you write `docker compose`, with a space, and not `docker-compose`, with a hyphen. The hyphenated one is the old Compose, a separate program, and its package is on the list of those that must be removed (1.4).

Notice the name `containerd.io`. Docker Engine needs `containerd` and `runc`, and your distribution also offers them under those names. The official guide explains it: Docker bundles them together in a single package, `containerd.io`, and if you previously installed your distribution's versions, you have to remove them so they do not conflict ([Docker, install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

#### 1.1.2 What you are not going to install, and why

**Docker Desktop.** It is a Docker desktop application that also exists for Linux, and the guide presents it as "the easiest and quickest way to get started". The course does not use it for a reason you already know: according to its own documentation, "Docker Desktop on Linux runs a Virtual Machine" ([Docker Desktop for Linux](https://docs.docker.com/desktop/setup/install/linux/)). Remember 0.2: the reason for using Linux as the reference system is that containers run directly on your kernel, with no layer in between. Docker Desktop puts that layer back. If you install it one day, you will know why `ps` on your Mint does not show the containers' processes: they are inside another machine.

**The convenience script.** Docker publishes a script at `get.docker.com` that detects your distribution and installs everything in one go. The guide says it is "not recommended for production environments", that it installs dependencies and recommendations without asking, that it lets you choose almost nothing, and that it is not designed to upgrade an existing installation ([Docker, convenience script](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)). There is another, simpler reason: in a course, a script that does everything takes away exactly what you came to learn. If you find it in a tutorial, now you know what it is.

***Rootless* mode.** It is a way of running the daemon without `root`. You will see it in 1.9, as an alternative; the course uses the normal mode, which is what the guide installs and what you will find on almost any server.

### 1.2 Mint is not Ubuntu: the codename

#### 1.2.1 What Docker says about Mint

The official guide for Ubuntu lists the versions it supports: 26.10, 26.04, 24.04, and 22.04, all 64-bit. And below that it has this note: "Installation on Ubuntu derivative distributions, such as Linux Mint, is not officially supported (though it may work)" ([Docker, install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

"Not officially supported" has a precise meaning: Docker does not test its packages on Mint and does not publish a folder for Mint in its repository. What it does have is a folder for each Ubuntu version. And Mint 22 is built on the packages of Ubuntu 24.04. Linux Mint's own downloads page says so in the "Package base" column: Mint 22, 22.1, 22.2, and 22.3 are based on "Ubuntu Noble", supported until April 2029 ([Linux Mint, all versions](https://www.linuxmint.com/download_all.php)). *Noble* is the codename of Ubuntu 24.04. So here is the trick: on Mint 22 you use Docker's packages **for Ubuntu Noble**, because those are the ones that match the libraries your system has.

#### 1.2.2 The file that says it all: `/etc/os-release`

Every Linux distribution describes what it is in a text file, `/etc/os-release`. It is a file of *shell* variables: lines of the form `NAME=value` that any script can load. `fig01_01.sh` reads it and tells you which codename applies to you. It changes nothing on your machine; it only reads:

```bash
#!/usr/bin/env bash
# fig01_01.sh — ¿Qué sistema tengo y qué nombre en clave le toca en el
# repositorio de Docker? Solo lee archivos: no cambia nada en tu equipo.
# Uso: ./fig01_01.sh            (lee /etc/os-release, el de tu sistema)
#      ./fig01_01.sh ARCHIVO    (lee otro archivo con el mismo formato)
set -euo pipefail
ARCHIVO="${1:-/etc/os-release}"

# os-release es un archivo de variables de shell: «.» lo carga en este guion.
. "$ARCHIVO"

echo "== Lo que dice $ARCHIVO"
echo "NAME=$NAME"
echo "VERSION=${VERSION:-}"
echo "ID=$ID  ID_LIKE=${ID_LIKE:-}"
echo "VERSION_CODENAME=${VERSION_CODENAME:-(vacío)}"
echo "UBUNTU_CODENAME=${UBUNTU_CODENAME:-(no existe)}"
echo "DEBIAN_CODENAME=${DEBIAN_CODENAME:-(no existe)}"

echo
echo "== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)"
echo "Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}"

echo
echo "== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)"
dpkg --print-architecture
```

Real run · simulated Mint:

```text
$ ./fig01_01.sh
== Lo que dice /etc/os-release
NAME=Linux Mint
VERSION=22.3 (Zena)
ID=linuxmint  ID_LIKE=ubuntu debian
VERSION_CODENAME=zena
UBUNTU_CODENAME=noble
DEBIAN_CODENAME=(no existe)

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: noble

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
amd64
```

On your machine, if you have Mint 22, 22.1, or 22.2, `VERSION` and `VERSION_CODENAME` will say `wilma`, `xia`, or `zara`; everything else comes out the same. Before reading the output, the lines of the script that are not obvious. The lone dot (`. "$ARCHIVO"`) loads the file into the script, just like `source`: after that line, `$NAME` or `$UBUNTU_CODENAME` hold the values from the file. `${VERSION:-}` means "the value of `VERSION`, or nothing if it does not exist"; without that, `set -u` would stop the script when it hit a variable that is not set. And `dpkg --print-architecture` asks the package manager which processor your system is built for; since it asks your system and not the file, if you pass another `os-release` as an argument, that last block still shows your own machine's architecture.

Now the output, which holds the key to the whole lesson:

1. **Mint says it is Mint.** `NAME=Linux Mint`, `ID=linuxmint`. If a program asks "are you Ubuntu?" by looking at `ID`, the answer is no.
2. **But it says where it comes from.** `ID_LIKE=ubuntu debian` means "I resemble Ubuntu, and Ubuntu resembles Debian".
3. **There are two codenames.** `VERSION_CODENAME=zena` is Mint 22.3's. `UBUNTU_CODENAME=noble` is that of the Ubuntu version it is built on. The second one exists precisely for cases like this. (`DEBIAN_CODENAME` does not exist in Mint or in Ubuntu; in 1.2.3 you will see who has it.)
4. **The official guide's rule picks the right one.** The expression `${UBUNTU_CODENAME:-$VERSION_CODENAME}` reads "use `UBUNTU_CODENAME` if it exists; otherwise, `VERSION_CODENAME`". On Mint it exists, and you get `noble`. On a real Ubuntu, both variables have the same value, so it does not matter which one is used. That expression is, character for character, the one the official guide has in the repository's `Suites` line (1.5).
5. **The architecture is `amd64`**, that of 64-bit Intel and AMD processors, which is what almost any computer running Mint has. It is the value that goes in the repository's `Architectures` field.

So you can see the other side, this is the same script on the virtual machine used for the runs, which is a real Ubuntu (real run · virtual machine; it is in `fig01_01.salida-ubuntu.txt`):

```text
$ ./fig01_01.sh
== Lo que dice /etc/os-release
NAME=Ubuntu
VERSION=24.04.4 LTS (Noble Numbat)
ID=ubuntu  ID_LIKE=debian
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
DEBIAN_CODENAME=(no existe)

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: noble

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
arm64
```

On Ubuntu, the two codenames match. On Mint, they do not. The whole difference of installing on Mint fits in those two lines.

#### 1.2.3 What if you have LMDE?

Linux Mint has a second edition, **LMDE** (*Linux Mint Debian Edition*), which is not built on Ubuntu but on Debian. Mint's downloads page lists LMDE 7, "Gigi", based on "Debian Trixie" ([Linux Mint, all versions](https://www.linuxmint.com/download_all.php)). If your machine runs LMDE, this lesson works for you in everything except the repository: you have to follow the [official guide for Debian](https://docs.docker.com/engine/install/debian/), which uses `https://download.docker.com/linux/debian` (for the key too: `…/linux/debian/gpg`).

In its `Suites` line, the Debian guide uses `$VERSION_CODENAME`, which on LMDE 7 is `gigi`, a name Docker does not have: it is the same error as in 1.5.2, Debian edition. The guide only says that on a derivative distribution you may need to substitute the codename with that of the corresponding Debian version. You do not need to type it manually: LMDE ships a variable in its `/etc/os-release` made for this, `DEBIAN_CODENAME`, just as Mint ships `UBUNTU_CODENAME`. That is what the `os-release` from LMDE 7's official `base-files` package says (version `13.8+lmde1`, from the [Linux Mint repository](http://packages.linuxmint.com/); the copy is in `programas/01-instalacion/os-release-lmde-7.txt`). The line looks like this:

```text
Suites: $(. /etc/os-release && echo "${DEBIAN_CODENAME:-$VERSION_CODENAME}")
```

It is a fragment, not a program: it goes in place of the `Suites` line in the Debian guide's block. To find out which edition you have, `fig01_01.sh` tells you: `ID` is `linuxmint` in both, but on LMDE `NAME=LMDE`, `ID_LIKE=debian`, without `ubuntu`, and `DEBIAN_CODENAME` appears.

> [!WARNING]
> If you have LMDE, **do not run `fig01_03.sh` or `fig01_04.sh`**: both point to the Ubuntu repository, and `fig01_04.sh` would write `Suites: gigi` against it and leave `apt update` failing. Follow the Debian guide (including its own list of conflicting packages) with the `Suites` line above, and pick the lesson back up at 1.7. In the checks, where it says `noble`, you will see `trixie`, and in the package versions, `debian.13~trixie`.

> [!NOTE]
> 🔧 **Engineering observation 1.1**
> "Not officially supported" does not mean "does not work", nor does it mean "works the same". It means "nobody but you is going to check that it works". When you use something outside what the vendor supports, write down exactly what you did differently (here: a codename) so that, if something fails, you know where to start.

### 1.3 Before installing: the firewall

The official guide opens with a security warning, before any command, and it is worth reading it before installing rather than on the day it bites you: if you use **ufw** or **firewalld** to manage your firewall, "when you expose container ports using Docker, these ports bypass your firewall rules" ([Docker, install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

*ufw* (*Uncomplicated Firewall*) is the firewall tool that ships with Ubuntu, and you may have it enabled on your Mint. Docker's page on firewalls explains the mechanism: when you publish a container port, the traffic is diverted in the kernel's `nat` table, **before** it reaches the `INPUT` and `OUTPUT` chains that ufw uses; packets are routed before the firewall rules can be applied, "effectively ignoring your firewall configuration" ([Docker, packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw)).

What it means in practice: if you have `ufw deny 8080` and run a container that publishes port 8080 on all interfaces, that port is open to your network. ufw never finds out. That is why in this course, when you publish ports, they are published only on `127.0.0.1`, the address that only your own machine can reach: it does not depend on the firewall to stay closed, because it is never opened to the network. Lesson 2 is planned to show this with a port opened on purpose.

The same warning has a second, more technical point: Docker is only compatible with `iptables-nft` and `iptables-legacy`, and firewall rules written directly with `nft` are not supported on a system with Docker. If you manage rules manually, they are written with `iptables` or `ip6tables` and placed in the `DOCKER-USER` chain. If you do not know what this paragraph is talking about, it most likely does not affect you: it is for people who already have a hand-written firewall.

### 1.4 Removing what conflicts

#### 1.4.1 The conflicting packages

Before installing the official packages you have to remove the unofficial ones, because both sets ship files with the same names (the `docker` command, the daemon, `containerd`) and `apt` cannot have both at once. The guide gives the exact list ([Docker, install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)):

| Package | What it is |
|---|---|
| `docker.io` | the Docker packaged by Ubuntu |
| `docker-compose` | the old Compose, the hyphenated program |
| `docker-compose-v2` | the new Compose, packaged by Ubuntu |
| `docker-doc` | the documentation for Ubuntu's package |
| `docker-buildx` | Buildx, packaged by Ubuntu |
| `podman-docker` | an imitator: it makes the `docker` command call Podman, another container tool |
| `containerd`, `runc` | Ubuntu's versions of what `containerd.io` bundles together |

If you never installed anything Docker-related, you most likely have none of them. The guide warns about it: "`apt` might report that you have none of these packages installed".

#### 1.4.2 The command, piece by piece

`fig01_02.sh` first asks which ones you have and then runs the guide's command, copied verbatim:

```bash
#!/usr/bin/env bash
# fig01_02.sh — Quitar los paquetes que chocan con los oficiales de Docker.
# El segundo comando es, letra por letra, el de la guía oficial de Ubuntu.
set -uo pipefail
PAQUETES="docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc"

echo "== ¿Cuáles de los paquetes en conflicto tienes instalados?"
dpkg --get-selections $PAQUETES

echo
echo "== El comando de la guía oficial (quita los que encontró)"
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc | cut -f1)
echo "código de salida: $?"
```

Real run · simulated Mint (the freshly installed system, with nothing Docker-related):

```text
$ ./fig01_02.sh
== ¿Cuáles de los paquetes en conflicto tienes instalados?
dpkg: no packages found matching docker.io
dpkg: no packages found matching docker-compose
dpkg: no packages found matching docker-compose-v2
dpkg: no packages found matching docker-doc
dpkg: no packages found matching docker-buildx
dpkg: no packages found matching podman-docker
dpkg: no packages found matching containerd
dpkg: no packages found matching runc

== El comando de la guía oficial (quita los que encontró)
dpkg: no packages found matching docker.io
…
dpkg: no packages found matching runc

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Reading package lists...
Building dependency tree...
Reading state information...
0 upgraded, 0 newly installed, 0 to remove and 3 not upgraded.
código de salida: 0
```

The `…` replaces six lines identical to the ones above; the full output is in `fig01_02.salida.txt`. The number of packages to upgrade (`3 not upgraded`) depends on your machine.

The guide's command reads from the inside out:

1. `dpkg --get-selections <packages>` asks `dpkg`, the low-level package manager, about each package on the list. For those that are installed it writes a line with the name, a tab, and the word `install`. For those that are not, it complains on standard error: `no packages found matching …`. Those complaints are not a problem; they are the answer "you do not have it".
2. `| cut -f1` keeps the first column of each line, that is, just the names.
3. `$( … )` puts those names on the command line of `sudo apt remove`.

That way, `apt remove` receives only the packages you **do** have. If you have none, it receives an empty list and says `0 to remove`. If you had, for example, `docker.io`, it would show you what it is going to remove and ask whether you want to continue: read the list before answering yes.

The notice `WARNING: apt does not have a stable CLI interface` appears because, in that run, `apt`'s output was not going to a terminal but to a file: that is how the course's outputs were saved. `apt` is the tool for people, and it warns that its format may change when what reads its output is another program. If you run the script in your terminal you will not see it; instead you will see `Done` at the end of `Reading package lists...` and progress bars. For scripts there is `apt-get`, which is stable; we use it in 1.5.3.

#### 1.4.3 What `apt remove` does not remove

The guide warns about something that matters if you ever had Docker: the images, containers, volumes, and networks that live in `/var/lib/docker/` **are not deleted** when you uninstall. Uninstalling the package removes the programs; the data stays. If you really want to start from scratch, 1.10 explains how. If not, the new packages will find that data and use it.

### 1.5 The official repository

#### 1.5.1 What an `apt` repository is

`apt` does not download programs from just anywhere: it downloads them from a list of **repositories**, servers that publish packages with a signed index. Your Mint already has Ubuntu's and Mint's. Adding Docker's takes two things:

- **The key.** Docker signs its index with a cryptographic key. `apt` needs the public part of that key to verify that what it downloads comes from Docker and that nobody changed it along the way.
- **The source.** A file in `/etc/apt/sources.list.d/` that tells `apt` where the repository is, which part of it applies to you, and which key is used to verify it.

This is that part of the official guide, in full (from the documentation). **Do not type it yet**: in this lesson you are going to run it in two steps. `fig01_03.sh` does the key part exactly like the guide and writes the source with the Mint error; `fig01_04.sh` rewrites the source correctly. If you would rather not trigger the error on your machine, type this block as-is, skip section 1.5.2 and, in 1.5.3, read the output instead of running the script:

```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

Line by line:

- `sudo apt update` refreshes the indexes of the repositories you already have, so that the next `apt install` finds up-to-date versions.
- `ca-certificates` brings the certificates of the authorities that sign HTTPS sites, and `curl` downloads files. On a desktop Mint you almost certainly already have them; asking for them does no harm.
- `install -m 0755 -d /etc/apt/keyrings` creates the folder where the keys of external repositories live, with permissions `0755`: the owner (`root`) writes, everyone reads.
- `curl -fsSL … -o /etc/apt/keyrings/docker.asc` downloads Docker's public key. `-f` makes it fail if the server responds with an error, instead of saving an error page as if it were the key; `-s` and `-S` keep it quiet except for errors; `-L` follows redirects.
- `chmod a+r` makes the key readable by everyone, because `apt` reads it with an unprivileged user.
- `sudo tee … <<EOF` writes the source file. `tee` is used with `sudo` because a `>` redirection is performed by your *shell*, which is not `root`, and could not write to `/etc`. What goes between `<<EOF` and `EOF` is the content, and the `$( … )` are substituted **before** it is written.

The `docker.sources` file is in the **deb822** format: one named field per line. The `apt` manual describes it alongside the old one-line format (`deb [options] url version component`), and says the intention is for deb822 to gradually become the default format ([sources.list(5)](https://manpages.debian.org/trixie/apt/sources.list.5.en.html)). You will see tutorials with a one-line `docker.list` file; it works the same, it is the older form. The fields:

| Field | Value | What it means |
|---|---|---|
| `Types` | `deb` | precompiled packages (not source code) |
| `URIs` | `https://download.docker.com/linux/ubuntu` | where the repository is; note the `ubuntu` at the end |
| `Suites` | the codename | the Ubuntu version whose packages you want; **this is where the Mint issue lies** |
| `Components` | `stable` | only stable releases, not test ones |
| `Architectures` | `amd64` on your Mint | which processor |
| `Signed-By` | `/etc/apt/keyrings/docker.asc` | which key verifies **this** repository, and only this one |

That last field deserves one more line. In the past, the keys of external repositories were added with `apt-key` to a shared keyring, and one key could verify **any** repository: Docker's could have signed a package claiming to come from Ubuntu. `apt-key` is deprecated: the manual for the version of `apt` in Ubuntu 24.04, the base of Mint 22, says it will be available for the last time in Debian 12 and Ubuntu 24.04 ([apt-key(8), Ubuntu noble](https://manpages.ubuntu.com/manpages/noble/man8/apt-key.8.html)). Your Mint 22 still ships it, which is why an old tutorial with `apt-key add` seems to work: it does work, but it leaves Docker's key valid for all your repositories. With `Signed-By`, Docker's key is only valid for Docker's repository. If a tutorial tells you `apt-key add`, it predates the adoption of `Signed-By`, and you should not follow it.

#### 1.5.2 The Mint error, triggered

Now the error from the opening scene, on purpose. `fig01_03.sh` is the same step from the guide with **a single difference**: in `Suites` it uses `VERSION_CODENAME` instead of `${UBUNTU_CODENAME:-$VERSION_CODENAME}`. That is how many old guides for Ubuntu write it, with `$VERSION_CODENAME` or with `$(lsb_release -cs)`, which on Mint also returns Mint's name (it takes it from `DISTRIB_CODENAME` in `/etc/lsb-release`); and that is how the official guide **for Debian** writes it, which does not have the problem because Debian has no `UBUNTU_CODENAME` ([Docker, install on Debian](https://docs.docker.com/engine/install/debian/)). Anyone on Mint who copies from the wrong guide ends up here.

```bash
#!/usr/bin/env bash
# fig01_03.sh — EL ERROR DE MINT, provocado a propósito.
# Es el paso 1 de la guía oficial con UNA sola diferencia: «Suites» sale de
# VERSION_CODENAME (el nombre en clave de Mint) en vez de UBUNTU_CODENAME.
# Así lo escriben muchas guías viejas y la guía oficial de Debian.
set -uo pipefail

# Igual que la guía oficial: la llave con la que apt comprueba los paquetes.
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# La diferencia está en la línea Suites.
sudo tee /etc/apt/sources.list.d/docker.sources <<FIN
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
FIN

echo
echo "== apt update con ese repositorio"
sudo apt update
echo "código de salida: $?"
```

Real run · simulated Mint. This is the output from the line written by `tee` to the end; before it come the lines from `apt update` and the installation of `curl`, which are in full in `fig01_03.error-esperado.txt`:

```text
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: zena
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc

== apt update con ese repositorio

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Ign:1 https://download.docker.com/linux/ubuntu zena InRelease
Err:2 https://download.docker.com/linux/ubuntu zena Release
  404  Not Found [IP: 3.161.44.57 443]
Hit:3 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:4 http://archive.ubuntu.com/ubuntu noble InRelease
Hit:5 http://archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:6 http://archive.ubuntu.com/ubuntu noble-backports InRelease
Reading package lists...
E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.
código de salida: 100
```

The IP address in brackets is that of the Docker server that answered, and it changes from one run to the next. The `Hit:` lines are Ubuntu's repositories, which do respond; the order in which they appear may vary. The rest is stable, except for the codename if your Mint is not 22.3. In your terminal you will also see `Hit:` lines from Mint's repositories.

It reads from top to bottom:

1. `tee` shows what it wrote, and the problem is right there in plain sight: `Suites: zena`.
2. `apt update` asks Docker's server for the index of the Ubuntu version `zena`. First it looks for `InRelease` (the index with the signature inside) and ignores it (`Ign`) because it is not there; then it looks for `Release` and the server answers **404**, "not found".
3. The final error says it in words: the repository `… zena Release` does not have a `Release` file. In other words: **there is no Ubuntu version called `zena`**. And that is true: `zena` is Mint.
4. `apt` exits with code 100, its general error code.

A misleading detail: the key did download correctly and the server did respond. It is not a network problem, nor a permissions problem, nor a key problem. It is a wrong name in a text file.

#### 1.5.3 The fix

You fix it by rewriting the source with the official guide's line. `fig01_04.sh` does that (it does not download the key again: it uses the one `fig01_03.sh` left in `/etc/apt/keyrings/docker.asc`; without it, `apt update` would fail because of the missing key), refreshes the indexes and, instead of installing, asks: where would `docker-ce` come from, and in which version?

```bash
#!/usr/bin/env bash
# fig01_04.sh — El arreglo: el repositorio de Docker con el nombre en clave de
# Ubuntu, como lo escribe la guía oficial. Después pregunta qué versión se
# instalaría y SIMULA la instalación (apt-get -s no instala nada).
set -euo pipefail

# Letra por letra, la línea Suites de la guía oficial de Ubuntu:
# UBUNTU_CODENAME si existe (Mint, Ubuntu) y, si no, VERSION_CODENAME.
sudo tee /etc/apt/sources.list.d/docker.sources <<FIN
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
FIN

echo
echo "== apt update"
sudo apt update

echo
echo "== ¿De dónde saldría docker-ce, y en qué versión?"
apt-cache policy docker-ce | sed -n 1,6p

echo
echo "== Las versiones más recientes que ofrece el repositorio"
apt list --all-versions docker-ce 2>/dev/null | grep docker-ce | sed -n 1,3p

echo
echo "== Simulación: los paquetes de Docker que instalaría el comando de la guía"
SIMULACION=$(apt-get install -s docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
echo "$SIMULACION" | grep -E '^Inst (docker-|containerd)' | cut -d' ' -f2,3 | tr -d '('
echo "paquetes en total, contando dependencias: $(echo "$SIMULACION" | grep -c '^Inst')"
```

Real run · simulated Mint:

```text
$ ./fig01_04.sh
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc

== apt update

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
Hit:2 https://download.docker.com/linux/ubuntu noble InRelease
Hit:3 http://archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:4 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:5 http://archive.ubuntu.com/ubuntu noble-backports InRelease
Reading package lists...
Building dependency tree...
Reading state information...
3 packages can be upgraded. Run 'apt list --upgradable' to see them.

== ¿De dónde saldría docker-ce, y en qué versión?
docker-ce:
  Installed: (none)
  Candidate: 5:29.9.2-1~ubuntu.24.04~noble
  Version table:
     5:29.9.2-1~ubuntu.24.04~noble 500
        500 https://download.docker.com/linux/ubuntu noble/stable amd64 Packages

== Las versiones más recientes que ofrece el repositorio
docker-ce/noble 5:29.9.2-1~ubuntu.24.04~noble amd64
docker-ce/noble 5:29.9.1-1~ubuntu.24.04~noble amd64
docker-ce/noble 5:29.9.0-1~ubuntu.24.04~noble amd64

== Simulación: los paquetes de Docker que instalaría el comando de la guía
containerd.io 2.4.2-3~ubuntu.24.04~noble
docker-ce-cli 5:29.9.2-1~ubuntu.24.04~noble
docker-ce 5:29.9.2-1~ubuntu.24.04~noble
docker-buildx-plugin 0.38.1-1~ubuntu.24.04~noble
docker-ce-rootless-extras 5:29.9.2-1~ubuntu.24.04~noble
docker-compose-plugin 5.6.0-1~ubuntu.24.04~noble
paquetes en total, contando dependencias: 96
```

What changes on your machine: the versions (those in this block are from October 21, 2026), the number of packages to upgrade and, above all, the total on the last line. The simulation container is a minimal, almost empty Ubuntu, and it lacks dozens of pieces that your desktop Mint already has (`systemd`, `perl`, `git`…); on your machine the total will be much smaller. And these `apt update` lines are from the **second** time the script ran, with the indexes already downloaded (`Hit`). The first time, Docker's showed up as downloads: `Get:1 https://download.docker.com/linux/ubuntu noble InRelease [48.5 kB]` and, after that, the package list for `noble/stable amd64`.

What the output says:

1. **`Suites: noble`**. The same Mint, now with Ubuntu's name.
2. **`apt update` no longer complains**, and `https://download.docker.com/linux/ubuntu noble` appears among the repositories.
3. **`apt-cache policy`** answers the question "if I install `docker-ce`, which version and from where?". `Installed: (none)`: you do not have it. `Candidate`: the version that would be installed. And in the table, the origin: `download.docker.com`, `noble/stable`. If you saw an origin from `archive.ubuntu.com` instead, something went wrong: there is no `docker-ce` in Ubuntu, but there is a `docker.io`, which is why it is worth checking where each thing comes from before installing.
4. **The version number** reads like this: `5:` is the "epoch", a counter whose only purpose is to make `apt` sort versions correctly; `29.9.2` is the Docker version; `-1~ubuntu.24.04~noble` says which distribution it was packaged for.
5. **The simulation** shows six Docker packages, not five. The sixth, `docker-ce-rootless-extras`, you did not ask for: `apt` brings it in as a *recommendation* of `docker-ce`. These are the tools for *rootless* mode (1.9); they do no harm.

`apt-get install -s` (for *simulate*) computes everything an installation would do and prints it as `Inst` lines, without touching anything. It is a good habit before any large installation: see what is going to come in.

### 1.6 Installing the packages

With the repository in place, the installation is a single command (from the documentation):

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

`apt` will show you the list of packages, how much it is going to download and how much space it will use, and ask whether you want to continue. The output of this command **is not pasted here** because it was not run on a real Mint, and on your machine it depends on what you already have installed. What to look for in it: that the new packages include the six from the simulation above, and that at the end there are no lines starting with `E:`.

**Pinning a version.** The command above installs the most recent one. If you need an exact version—so that your machine matches a server, for example—the guide gives the recipe (from the documentation):

```bash
apt list --all-versions docker-ce
VERSION_STRING=5:29.8.2-1~ubuntu.24.04~noble
sudo apt install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
```

The first command lists the available versions, as `fig01_04.sh` did. The second stores the one you want in a variable, with its full number, epoch included. The third installs `docker-ce` and `docker-ce-cli` at that exact version: `package=version` is `apt`'s way of asking for a precise version. The 29.8.2 in the example is precisely the version this course was planned with; you do not need to pin it to follow along.

**What the installation does besides copying files.** On Debian and Ubuntu, the Docker service is configured to start automatically, now and every time you turn on the machine: the post-installation steps say so, "On Debian and Ubuntu, the Docker service starts on boot by default" ([Docker, post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)). And the `docker` group is created, empty. You verify both in 1.7 and 1.8.

### 1.7 Verifying

#### 1.7.1 What the guide asks for

The official guide ends with two checks (from the documentation):

```bash
sudo systemctl status docker
sudo docker run hello-world
```

`systemctl status docker` asks *systemd*, the program that starts and supervises the system's services, about the state of the `docker` service. If it were not running, the guide says to start it with `sudo systemctl start docker`. And `sudo docker run hello-world` creates your first container. Note the `sudo` in both: right after installation, your user cannot talk to the daemon yet. That gets fixed in 1.8, which is why this course's checks are done without `sudo`, afterwards.

#### 1.7.2 The course's checks

`fig01_05.sh` gathers everything you want to know about a fresh installation. Run it **after** 1.8, without `sudo`:

```bash
#!/usr/bin/env bash
# fig01_05.sh — Las comprobaciones al terminar la instalación.
# Córrelo SIN sudo, después de entrar al grupo docker (sección 1.8).
set -uo pipefail

echo "== 1. El servicio: ¿corre ahora y arrancará con el equipo?"
systemctl is-active docker
systemctl is-enabled docker

echo
echo "== 2. Los cinco paquetes instalados"
dpkg-query -W -f='${Package} ${Version}\n' \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo
echo "== 3. Versiones"
docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}  API: {{.Server.APIVersion}}'
docker compose version
docker buildx version | cut -d' ' -f1,2

echo
echo "== 4. El primer contenedor"
docker run --rm --name curso-docker-hola hello-world

echo
echo "== 5. El socket: dueño root, grupo docker"
ls -l /var/run/docker.sock | awk '{print $1, $3, $4, $NF}'

echo
echo "== 6. Basura: contenedores curso-docker- que quedaron"
docker ps -a --filter name=curso-docker- --format '{{.Names}}' | wc -l
```

Real run · virtual machine:

```text
$ ./fig01_05.sh
== 1. El servicio: ¿corre ahora y arrancará con el equipo?
active
enabled

== 2. Los cinco paquetes instalados
containerd.io 2.2.1-1~ubuntu.24.04~noble
docker-buildx-plugin 0.31.1-1~ubuntu.24.04~noble
docker-ce 5:29.2.1-1~ubuntu.24.04~noble
docker-ce-cli 5:29.2.1-1~ubuntu.24.04~noble
docker-compose-plugin 5.0.2-1~ubuntu.24.04~noble

== 3. Versiones
Cliente: 29.2.1  Daemon: 29.2.1  API: 1.53
Docker Compose version v5.0.2
github.com/docker/buildx v0.31.1

== 4. El primer contenedor
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
58dee6a49ef1: Pulling fs layer
c3bdf82c34d1: Download complete
58dee6a49ef1: Download complete
58dee6a49ef1: Pull complete
Digest: sha256:11a3eb1597e864c51b3f56733cb2e8a90bf0c284bfc05f9444d81c558bc848aa
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm64v8)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/


== 5. El socket: dueño root, grupo docker
srw-rw---- root docker /var/run/docker.sock

== 6. Basura: contenedores curso-docker- que quedaron
0
```

What changes on your machine: the versions (if you installed on October 21, 2026, you would see 29.9.2, Compose v5.6.0, and Buildx v0.38.1), the layer identifiers and the image *digest*, and `(arm64v8)`, which on your machine will say `(amd64)`. If you had already run `hello-world` before, you will not see the download block: the image is already on your machine.

Block by block:

1. **`active` and `enabled`.** `is-active` answers whether the service is running **now**; `is-enabled`, whether it will start **on its own** the next time you turn on the machine. They are different questions and it is worth asking both: a service may be running because you started it manually and not come back after a reboot.
2. **The five packages**, each with its version and the suffix `ubuntu.24.04~noble`, which says they come from the official repository for Noble. `dpkg-query -W` queries installed packages using whatever format you ask for.
3. **The versions.** `docker version` reports two, the client's and the daemon's, because they are two programs (Lesson 0, section 0.6). `API: 1.53` is the version of the language they speak to each other. `docker compose version` and `docker buildx version` confirm that both *plugins* are in place: if `docker compose` answered `docker: unknown command: docker compose`, `docker-compose-plugin` would be missing (with Docker 29.2.1, that is how the client responds to a subcommand it does not know: `docker noexiste` printed `docker: unknown command: docker noexiste`).
4. **The first container.** The daemon did not find the `hello-world` image on your machine (`Unable to find image … locally`), downloaded it from Docker Hub, created a container, ran it and, since you asked for `--rm`, deleted it when it finished. The text the container prints describes, in four steps, the path on the map from Lesson 0: the client talks to the daemon, the daemon downloads the image, creates a container, and sends you back its output. `hello-world` is the only image in this course used without a pinned version (`latest`), because it is the only tag it publishes.
5. **The *socket*.** `srw-rw----`: the `s` says it is a *socket*; `rw-` for the owner, `root`; `rw-` for the group, `docker`; and `---` for everyone else. That last column of dashes is what keeps a user outside the group from talking to the daemon (1.8).
6. **Zero course containers.** `--rm` did its job. All names in this course start with `curso-docker-` so that you can find and delete your own without touching anything else; it is a habit worth having from the very first container.

### 1.8 The `docker` group

#### 1.8.1 The permissions error

Right after installing Docker, if you type `docker ps` without `sudo`, you are going to see this section's error. `fig01_06.sh` triggers it without removing you from the group: it uses the `nobody` user, which exists on any Linux and does not belong to any useful group:

```bash
#!/usr/bin/env bash
# fig01_06.sh — El error de permisos: un usuario que NO está en el grupo docker.
# Usa al usuario «nobody», que existe en todo Linux y no pertenece a ningún
# grupo útil, para mostrar el error sin tener que sacarte a ti del grupo.
set -uo pipefail

echo "== ¿En qué grupos está nobody?"
id -nG nobody

echo
echo "== nobody intenta hablarle al daemon"
sudo -u nobody docker ps
echo "código de salida: $?"

echo
echo "== ¿Y tú? ¿Estás en el grupo docker?"
if id -nG | tr ' ' '\n' | grep -qx docker; then echo "sí"; else echo "no"; fi
```

Real run · virtual machine:

```text
$ ./fig01_06.sh
== ¿En qué grupos está nobody?
nogroup

== nobody intenta hablarle al daemon
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
código de salida: 1

== ¿Y tú? ¿Estás en el grupo docker?
sí
```

This output is stable. The last line will say `no` if you have not yet done what 1.8.2 describes, and that is the state in which you will see the error with your own user.

`sudo -u nobody` runs the command as the `nobody` user. That user is only in the `nogroup` group, so, facing the *socket* `srw-rw---- root docker`, it falls into the third column: no permission for anything. The message reads just like the one in Lesson 0, with a different cause at the end: the client **did** find the *socket* at `/var/run/docker.sock` (the daemon is there), but it does not have permission to open it. Compare it with Lesson 0's `no such file or directory`, which meant "there is no daemon at that path". Two different causes, two different fixes: here, restarting the service does not help.

#### 1.8.2 Joining the group

There are three ways to get rid of the error, and it is worth knowing them before choosing:

1. **Always using `sudo docker`.** It works and grants no new permission, but it is inconvenient, and the client's configuration files end up owned by `root` (you see this in 1.8.3).
2. **Joining the `docker` group.** It is what almost everyone does and what this course does. From that moment on, any program running as you can talk to the daemon.
3. **The on-demand group**, with a password (1.9.3).

Option 2 is three steps (from the documentation):

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

- `groupadd docker` creates the group. The guide warns that on some distributions the package already creates it at installation time; on Ubuntu and on Mint that is the case, and the command will tell you `groupadd: group 'docker' already exists`. It is not really an error: the group was already there.
- `usermod -aG docker $USER` adds you to the group. The `-a` (*append*) matters: without it, `-G` **replaces** all your groups with `docker`, and you would be locked out of `sudo`, among others. `$USER` is your username.
- The change does not apply to sessions you already have open, because a process's groups are set at login. The guide asks you to **log out and log back in** (and, if your Linux runs in a virtual machine, perhaps restart it). `newgrp docker` is the shortcut: it opens a new *shell* with the group already applied, only in that terminal.

Afterwards, `id -nG` must include the word `docker`, and `docker run hello-world` must work without `sudo`. That is the moment to run `fig01_05.sh`.

#### 1.8.3 The error that comes next: `config.json`

If before joining the group you ran commands with `sudo docker`, you may see this when using `docker` without `sudo` (from the documentation; `user` is your user):

```text
WARNING: Error loading config file: /home/user/.docker/config.json -
stat /home/user/.docker/config.json: permission denied
```

The client stores its configuration in the `.docker` folder in your home directory. When you ran it with `sudo`, that folder was created owned by `root`, and now you cannot read it. The guide gives two fixes: delete `~/.docker/` (it is recreated automatically, but you lose whatever configuration it had), or take back ownership of the folder:

```bash
sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
sudo chmod g+rwx "$HOME/.docker" -R
```

It is a good example of why `sudo docker` is not as innocent as it looks: it does not grant more power than the group, but it leaves traces of `root` where they should not be.

### 1.9 Why the `docker` group is equivalent to `root`

#### 1.9.1 The warning

The post-installation steps place this warning right before the commands in 1.8.2: "The `docker` group grants root-level privileges to the user" ([Docker, post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)). And the security guide explains why: the daemon requires `root`, and Docker lets you share a host directory with a container "without limiting the access rights of the container"; you can start a container where `/host` is the `/` directory of your machine, "and the container can alter your host filesystem without any restriction" ([Docker Engine security](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)).

A warning is forgotten; a demonstration is not. That is why this course does not ask you to take it on faith.

#### 1.9.2 Seeing it with your own eyes

`/etc/shadow` is the file where Linux stores users' hashed passwords. Only `root` can read it. `fig01_07.sh` tries to read it twice: first as you, without `sudo`; then by asking Docker's daemon to do it. So as not to print anything secret, it only counts the lines and shows the first user **name**:

```bash
#!/usr/bin/env bash
# fig01_07.sh — Por qué el grupo docker equivale a root.
# Córrelo SIN sudo, como tu usuario normal (que ya está en el grupo docker).
# Lee /etc/shadow, el archivo de contraseñas cifradas que solo root puede leer,
# y solo imprime cuántos renglones tiene y el primer NOMBRE de usuario: nada secreto.
set -uo pipefail
IMAGEN=debian:13.7-slim

echo "== 1. Tú, sin sudo, intentas leer /etc/shadow"
ls -l /etc/shadow | awk '{print $1, $3, $4, $NF}'
cat /etc/shadow > /dev/null
echo "código de salida: $?"

echo
echo "== 2. Lo mismo, pero se lo pides al daemon de Docker"
docker run --rm --name curso-docker-llave -v /etc:/anfitrion-etc:ro "$IMAGEN" sh -c '
  id
  echo "renglones de /etc/shadow que pude leer: $(wc -l < /anfitrion-etc/shadow)"
  echo "primer usuario de la lista: $(cut -d: -f1 /anfitrion-etc/shadow | head -1)"'
echo "código de salida: $?"
```

Real run · virtual machine:

```text
$ ./fig01_07.sh
== 1. Tú, sin sudo, intentas leer /etc/shadow
-rw-r----- root shadow /etc/shadow
cat: /etc/shadow: Permission denied
código de salida: 1

== 2. Lo mismo, pero se lo pides al daemon de Docker
Unable to find image 'debian:13.7-slim' locally
13.7-slim: Pulling from library/debian
ddc0c1e36a67: Pulling fs layer
d449c469d06c: Download complete
ddc0c1e36a67: Download complete
ddc0c1e36a67: Pull complete
Digest: sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad
Status: Downloaded newer image for debian:13.7-slim
uid=0(root) gid=0(root) groups=0(root)
renglones de /etc/shadow que pude leer: 26
primer usuario de la lista: root
código de salida: 0
```

What changes on your machine: the number of lines (one per user on your system), the download identifiers, and the entire download block if you already had the image. The rest is stable.

Read the two halves together:

1. **As you, the system says no.** `/etc/shadow` belongs to `root` and to the `shadow` group, and everyone else has no permission at all (`---`). `cat` fails with `Permission denied`, as it should.
2. **Asking the daemon, it says yes.** `-v /etc:/anfitrion-etc:ro` mounts your machine's `/etc` folder inside the container, at `/anfitrion-etc`. Inside, the process is `uid=0(root)`, and since the user namespace is not isolated by default (Lesson 0, section 0.3), it is the **same** user 0 as on your machine. It reads the file without any trouble: 26 lines, starting with `root`'s.

You did not use `sudo`. You did not type any password. Being in the `docker` group was enough. And the mount's `:ro` (read-only) is no protection: you put it there, and nothing stopped you from removing it and mounting all of `/` with write permission. That is what "equivalent to `root`" means: not that the `docker` group has a special permission, but that it gives access to a program that runs as `root` and does whatever you ask.

The same logic explains the other two things the opening scene warns against. Giving the *socket* `777` permissions puts **every** user and program on the machine in the `docker` group without asking them. And mounting the *socket* inside a container hands that key to whatever runs inside.

#### 1.9.3 The alternatives

The documentation offers three paths for those who do not want that power always available:

- **`sudo docker`**, every time. The power is the same, but you have to ask for it with a password, and it is logged.
- **The on-demand group.** Your user stays **out** of the `docker` group, the group is given a password (`sudo gpasswd docker`) and, when you need Docker, you open a *shell* with `newgrp docker` and type that password. The guide says what it is for and what it is not for: it reduces "ambient" access to the *socket*, because only the programs you launch from that *shell* have it, but it does not reduce privileges once access is granted, and it "is not a security boundary" against malicious code already running as your user ([Docker, post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/#access-the-docker-group-on-demand)).
- ***Rootless* mode.** The daemon and the containers run inside a user namespace, without `root` privileges, to mitigate potential vulnerabilities in the daemon and the container runtime ([Docker, *rootless* mode](https://docs.docker.com/engine/security/rootless/)). It is the only one of the three that changes the substance of the matter. It has its own prerequisites and limitations, and some details this course teaches would look different under it, which is why it is not the course's path.

The course uses the group, on a machine that is yours and where you are the one who decides what runs. The rule that matters: **adding someone to the `docker` group is giving them `root`**. If you would not give the `root` password to a person or a program, do not add them to the group either.

> [!NOTE]
> 🔧 **Engineering observation 1.2**
> The useful question is not "is this permission dangerous?", but "what can I do **through** this permission?". The `docker` group does not say `root` anywhere; the path to `root` goes through an intermediary that is `root`. Many security problems have that shape: a modest permission that opens the door to something with more power.

### 1.10 Upgrading and uninstalling

**Upgrading.** Since Docker lives in an `apt` repository, it is upgraded like everything else: `sudo apt update` and `sudo apt upgrade`, or by repeating the command from 1.6 with the new version you want ([Docker, install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/#upgrade-docker-engine)).

**Uninstalling.** It takes three steps, and each one removes something different (from the documentation):

```bash
sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm /etc/apt/sources.list.d/docker.sources
sudo rm /etc/apt/keyrings/docker.asc
```

The first removes the programs (`purge`, unlike `remove`, also removes their configuration). Note that the list includes `docker-ce-rootless-extras`, the sixth package you saw in the simulation in 1.5.3. The second pair **deletes all your images, containers, and volumes**, which the first left intact: it is irreversible, so before running it make sure there is nothing there you want to keep. The third pair removes the source and the key, so that `apt` stops querying Docker's repository. The guide adds that configuration files you edited manually must be deleted manually.

## The error you will see

This lesson has two main errors, both triggered in their sections, and a secondary one you already know.

**The Mint error: "does not have a Release file".** It is the one from `fig01_03.sh` (1.5.2):

```text
Err:2 https://download.docker.com/linux/ubuntu zena Release
  404  Not Found [IP: 3.161.44.57 443]
E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.
```

It reads like this: `apt` asked Docker's repository for the `zena` version and the server answered that it does not exist (404). The word that matters is the one between the address and `Release`: if a Mint name appears there (`wilma`, `xia`, `zara`, `zena`), the problem is the `Suites` line in `/etc/apt/sources.list.d/docker.sources`. You fix it by rewriting that file with the official guide's line, which uses `UBUNTU_CODENAME` (1.5.3), and running `sudo apt update` again. If instead of Mint's name `noble` appears and it still fails, the problem is something else (the network, or a mistyped URL); and if the name of an Ubuntu version Docker does not support appears, check the list in 1.2.1.

**The permissions error: "permission denied while trying to connect to the docker API".** It is the one from `fig01_06.sh` (1.8.1):

```text
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

It reads like this: the daemon **is** there (the *socket* exists), but your user does not have permission to open the *socket*. You fix it with `sudo usermod -aG docker $USER` and logging out (1.8.2), **knowing what that means** (1.9). What you do not do: `chmod 666` or `777` on the *socket*, which opens it to every user on the machine. Besides, *systemd* (the `docker.socket` unit) recreates the *socket* with its usual permissions, `root:docker` and `0660`, every time the machine boots, so the "fix" disappears on the next reboot, and the temptation is to repeat it.

**The secondary error: the daemon is not there.** You saw it in Lesson 0, triggered with a test path (real run from that lesson):

```text
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
```

On your Mint, with the service stopped, the path will be `/var/run/docker.sock` and the rest of the message the same. Now you can diagnose it end to end: `systemctl is-active docker` tells you whether the service is running; if not, `sudo systemctl start docker` starts it, and `sudo journalctl -u docker` shows you the service's log so you can find out why it stopped. If `is-enabled` says `disabled`, the service will not start on its own when the machine boots: `sudo systemctl enable docker` fixes that.

## The security habit of the lesson

**The `docker` group is equivalent to `root`: grant it knowing that, and only to someone you would give `root`.** This habit prevents two concrete accidents. The first is the one in the opening scene: "fixing" the permissions error by opening the *socket* to everyone, which lets any program on the machine—including one you downloaded without reviewing—ask the daemon to mount your disk. The second is quieter: adding to the group, "so they don't have to struggle", another person or a service account that only needed to look at some logs. In both cases the damage goes unnoticed until someone uses it.

Along with that habit comes another, smaller one that this lesson also instills: **a repository's key is valid only for that repository** (`Signed-By`), and nothing that asks you for `apt-key`, or a script downloaded and run without reading it, gets onto your machine.

## What gets done wrong

**Installing `docker.io` "because it's easier".** It is your distribution's package, not Docker's: a different version, a different update pace, and the *plugins* under different names. If you have it and also install the official ones, they conflict. This course was measured with the official ones.

**Copying the Debian installation guide, or an old guide, on Mint.** They use `VERSION_CODENAME`, which on Mint is Mint's name. The result is the error in 1.5.2.

**Hard-coding `noble` "because it works".** It works today, but it ties the command to a single version: if you pass it to someone with Mint 21 (`jammy`), or run it again the day your Mint moves to a new Ubuntu base, it writes the wrong name. The guide's expression takes the value from `/etc/os-release` at the moment it runs. Careful: in both cases the file stores the already-resolved name; if you change Mint versions one day, what you repeat is the command from 1.5.3, rather than editing the file by eye.

**`chmod 777 /var/run/docker.sock`.** It gives the whole machine what the `docker` group gives its members: `root`. And it does not even last, because *systemd* recreates the *socket* when the machine boots.

**Adding just anyone to the `docker` group.** It is giving them `root` (1.9).

**Using `apt-key add`.** It is deprecated (your Mint 22 still ships it, which is why it seems to work), and it puts the key in a keyring that is valid for all repositories.

**Running the `get.docker.com` script without reading it.** The guide itself asks you to review downloaded scripts before running them, and does not recommend it for production. A script that is downloaded and run with `sudo` has `root` on your machine, just like the `docker` group.

**Forgetting the `-a` in `usermod -aG`.** `usermod -G docker` leaves you **only** in the `docker` group, and locked out of `sudo`.

**Declaring the installation done without verifying it.** The fact that `apt` gave no error does not mean the service is running, nor that it starts on its own, nor that your user can use it. The checks in `fig01_05.sh` take two seconds.

## Exercises

Write your answers and predictions in your [logbook](bitacora.md) before looking at the solutions.

### Exercise 1 — Read your `os-release` (project)

Run `fig01_01.sh` on your Mint. Before running it, predict what `VERSION_CODENAME`, `UBUNTU_CODENAME`, and `Suites` will say. Then answer: if a teammate has LMDE 7, what would those three lines say on their machine, which installation guide applies to them, and which codename goes in their `Suites`? Hint: run `./fig01_01.sh os-release-lmde-7.txt` inside `programas/01-instalacion/` and look for a variable that Mint does not have. The last block will show your machine's architecture, not theirs.

### Exercise 2 — Diagnose without running anything

A teammate sends you three error messages, one per day. They are this lesson's errors as they would see them, with the name of their Mint version and the *socket* path on their machine. For each one, say what the cause is and which command or change fixes it:

1. `E: The repository 'https://download.docker.com/linux/ubuntu xia Release' does not have a Release file.`
2. `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`
3. `failed to connect to the docker API at unix:///var/run/docker.sock; check if the path is correct and if the daemon is running: dial unix /var/run/docker.sock: connect: no such file or directory`

### Exercise 3 — Where does each thing come from?

Without installing anything new, run these two commands on your Mint (with Docker already installed) and answer the questions:

```bash
apt-cache policy docker-ce docker.io | grep -E '^[a-z]|Installed|Candidate'
cat /etc/apt/sources.list.d/docker.sources
```

1. Which version of `docker-ce` do you have installed, and which one would be installed if you upgraded?
2. Do you have `docker.io` installed? Does any repository offer it?
3. What does the `Suites` line say, and why?

### Exercise 4 — The daemon's key

Without running it, answer: if in `fig01_07.sh` you changed `-v /etc:/anfitrion-etc:ro` to `-v /:/anfitrion` (without `:ro`), what could the container do? Name one concrete thing it could change on your machine. Then explain in two sentences why `chmod 777 /var/run/docker.sock` is worse than adding your user to the `docker` group.

## Solutions

### Solution 1

On a Mint 22.x: `VERSION_CODENAME` says your Mint's name (`wilma`, `xia`, `zara`, or `zena`), `UBUNTU_CODENAME` says `noble`, and `Suites` says `noble`, because the rule `${UBUNTU_CODENAME:-$VERSION_CODENAME}` prefers the first variable when it exists. If your `Suites` said something else, check that you have Mint 22 and not an earlier version: Mint 21 is built on Ubuntu Jammy and would say `jammy`, which is also a supported version.

On LMDE 7, `VERSION_CODENAME=gigi`, `UBUNTU_CODENAME` comes out `(no existe)`, and that is why `Suites: gigi`, a name Docker does not have. But its `os-release` has `DEBIAN_CODENAME=trixie`, the variable that Mint does not have, and it is the one that goes in the `Suites` line of the Debian guide: `${DEBIAN_CODENAME:-$VERSION_CODENAME}` (1.2.3). This is the output of the hint (real run · virtual machine, hence `arm64`; it is in `fig01_01.salida-lmde.txt`):

```text
$ ./fig01_01.sh os-release-lmde-7.txt
== Lo que dice os-release-lmde-7.txt
NAME=LMDE
VERSION=7 (gigi)
ID=linuxmint  ID_LIKE=debian
VERSION_CODENAME=gigi
UBUNTU_CODENAME=(no existe)
DEBIAN_CODENAME=trixie

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: gigi

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
arm64
```

### Solution 2

1. **Mint's codename in the repository.** `xia` is Mint 22.1. The `Suites` line in `/etc/apt/sources.list.d/docker.sources` has Mint's name; you rewrite the file with the official guide's line (`${UBUNTU_CODENAME:-$VERSION_CODENAME}`) and run `sudo apt update` (1.5.3).
2. **The user is not in the `docker` group.** The daemon is running; permission for the *socket* is missing. `sudo usermod -aG docker $USER`, log out and log back in (or `newgrp docker`), knowing that it is equivalent to giving them `root` (1.8 and 1.9).
3. **The daemon is not running.** There is no *socket* at that path. `systemctl is-active docker` confirms it; `sudo systemctl start docker` starts it, `sudo journalctl -u docker` says why it had stopped, and `sudo systemctl enable docker` makes it start automatically.

If you confused 2 with 3, read the end of each message again: `permission denied` versus `no such file or directory`. The cause is always in the last few words.

### Solution 3

1. In the `docker-ce` block, `Installed` is the version you have and `Candidate` the one that would be installed with `sudo apt upgrade`. If they are the same, you are up to date.
2. If you followed the lesson, `docker.io` will say `Installed: (none)`. Its `Candidate` probably shows a version: the package exists in the Ubuntu repositories your Mint uses, even if you do not install it. That is why it is worth knowing where each package comes from.
3. `Suites: noble`, because the guide's expression took the `UBUNTU_CODENAME` from your `/etc/os-release`: Docker's repository has folders per Ubuntu version, not per Mint version.

### Solution 4

With `/` mounted with write access, the container, as `root`, could change any file on your machine: for example, add a new user with administrator permissions by editing `/etc/passwd` and `/etc/sudoers`, delete `/etc/shadow`, or replace a program in `/usr/bin` with another one. It is the sentence from the security guide: the container "can alter your host filesystem without any restriction".

`chmod 777` is worse because it gives that power not only to your user, but to **every** user and program on the machine, without any of them having to be in a group or even knowing it. And besides, it does not last: *systemd* recreates the *socket* with its permissions when the machine reboots, so whoever relies on it gets used to repeating it.

## How I know I succeeded

Check each item only if it holds on **your** machine:

- [ ] `fig01_01.sh` shows `Suites: noble` (or, on LMDE, you know why not and which guide applies to you).
- [ ] `cat /etc/apt/sources.list.d/docker.sources` shows the six-field format from 1.5.1, with `Suites: noble` (on LMDE, `trixie` and the `linux/debian` URL) and `Signed-By: /etc/apt/keyrings/docker.asc`, and `sudo apt update` shows no `E:` line.
- [ ] `systemctl is-active docker` prints `active` and `systemctl is-enabled docker` prints `enabled`.
- [ ] `id -nG` includes `docker`, and `docker version` without `sudo` shows the client's version **and** the daemon's.
- [ ] `fig01_05.sh`, without `sudo`, ends with `Hello from Docker!` in block 4, `srw-rw---- root docker /var/run/docker.sock` in block 5, and `0` in block 6. What is not compared, because it changes: the versions, the identifiers and the *digest* of the download, and the architecture in parentheses.
- [ ] `fig01_06.sh` prints the `permission denied` for `nobody` and `sí` for you.
- [ ] `fig01_07.sh` prints `Permission denied` in block 1 and `uid=0(root)` in block 2, and you can explain out loud why.
- [ ] When you finish, `docker ps -a --filter name=curso-docker-` shows nothing.
- [ ] You wrote down in your logbook which version of Docker you installed and on what date.

## Summary

Answer without looking at the lesson:

1. Why does the course install the packages from `download.docker.com` and not `docker.io`?
2. What does `/etc/os-release` say on Mint that it does not say on Ubuntu, and why does it matter for installing Docker?
3. What does the expression `${UBUNTU_CODENAME:-$VERSION_CODENAME}` do?
4. Which five packages does the guide install, and which piece of the map from Lesson 0 is each one?
5. What is the `Signed-By` field for, and what was the problem with `apt-key`?
6. What does "does not have a Release file" mean when adding the repository on Mint?
7. What is the difference between `permission denied` and `no such file or directory` when talking to the daemon?
8. Why is the `docker` group equivalent to `root`, and what alternatives are there?
9. Why does ufw not protect the ports Docker publishes, and what does this course do about it?

## Sources

All consulted on October 21, 2026.

- [Docker, "Install Docker Engine on Ubuntu"](https://docs.docker.com/engine/install/ubuntu/): the supported Ubuntu versions, the note about Linux Mint, the firewall warning, the conflicting packages, the repository with its key, the five packages, how to pin a version, the convenience script, the checks, upgrading, and uninstalling.
- [Docker, "Install Docker Engine on Debian"](https://docs.docker.com/engine/install/debian/): the `Suites` line with `VERSION_CODENAME` and the note for derivative distributions (LMDE).
- [Docker, "Linux post-installation steps for Docker Engine"](https://docs.docker.com/engine/install/linux-postinstall/): the `docker` group, the warning that it is equivalent to `root`, the `config.json` error, the on-demand group with a password, and starting the service with *systemd*.
- [Docker Engine security, "Docker daemon attack surface"](https://docs.docker.com/engine/security/#docker-daemon-attack-surface): why whoever controls the daemon controls the host.
- [Docker, "Packet filtering and firewalls"](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw): why published ports bypass ufw.
- [Docker, "Rootless mode"](https://docs.docker.com/engine/security/rootless/): what the mode without `root` is.
- [Docker Desktop for Linux](https://docs.docker.com/desktop/setup/install/linux/): that Docker Desktop on Linux runs a virtual machine.
- [Docker Engine 29, release notes](https://docs.docker.com/engine/release-notes/29/): version 29.9.2 and its date.
- [Linux Mint, all versions](https://www.linuxmint.com/download_all.php): the Mint 22 versions, their Ubuntu Noble base, and LMDE 7 on Debian Trixie.
- [Linux Mint package repository](http://packages.linuxmint.com/): the `base-files` package `13ubuntu10mint22.3.0`, the source of the Mint 22.3 `/etc/os-release` used in the runs.
- [sources.list(5), `apt` manual](https://manpages.debian.org/trixie/apt/sources.list.5.en.html): the one-line and deb822 formats.
- [apt-key(8), `apt` manual on Ubuntu 24.04](https://manpages.ubuntu.com/manpages/noble/man8/apt-key.8.html): `apt-key` deprecated and until which version it will be available.
- [Colima](https://github.com/abiosoft/colima): the virtual machine used for the runs.

### Terms in this lesson

| | |
|---|---|
| **`apt`** | the package manager of Mint, Ubuntu, and Debian; it downloads and installs packages from repositories |
| **deb822** | the format of `apt`'s `.sources` files: one named field per line |
| **`dpkg`** | the low-level package manager that `apt` works on top of |
| **`docker` group** | the Linux group whose members can talk to the daemon without `sudo`; equivalent to `root` |
| **LMDE** | *Linux Mint Debian Edition*, the edition of Mint built on Debian rather than Ubuntu |
| **key (repository)** | the public part of a cryptographic key that `apt` uses to verify that packages come from whom they claim |
| **codename** | the short name of a distribution version: `noble` for Ubuntu 24.04, `zena` for Mint 22.3 |
| ***plugin*** | a program added to the `docker` client as a subcommand: `docker compose`, `docker buildx` |
| **repository** | a server that publishes packages with a signed index |
| ***rootless*** | mode in which the daemon and the containers run without `root` privileges |
| ***systemd*** | the program that starts and supervises the system's services; it is managed with `systemctl` |
| **ufw** | *Uncomplicated Firewall*, Ubuntu's firewall tool |

---

**Previous:** [Lesson 0 — What a container is and what it is NOT](00-que-es-un-contenedor.md) · **Next:** [Lesson 2 — Day-to-Day Containers](02-contenedores-dia-a-dia.md)
